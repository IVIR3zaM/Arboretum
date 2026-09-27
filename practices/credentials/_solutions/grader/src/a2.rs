//! Axis (a2) — Ticket 2 hidden acceptance: the status-change webhook notifier.
//!
//! Root-tested: every case builds a `Notifier` over a grader-owned transport
//! and sink and calls `Notifier::notify` directly, under a paused tokio clock
//! (virtual time: large tenants and hanging endpoints cost no wall time).
//! Nothing leaves the process: every URL is answered in-process, and a
//! reserved name is never contacted.
//!
//! Graded worst-case across {small tenant, large tenant} × {all healthy, one
//! hanging endpoint}, plus one delivery-path failure. Two vectors come from
//! `reference/infra/`:
//!
//! - the **budget**: `webhook-config.yaml` → `function.timeout_seconds`, the
//!   runtime's hard kill. It is imposed here, outside the notifier, so a
//!   notifier cannot buy time by raising its own budget constant;
//! - the **reserved names**: the table in `reserved-domains.md`. No outbound
//!   call may target one of them (or a subdomain of one).
//!
//! Cases:
//!
//! - **D** every healthy real subscription receives the change before the
//!   budget runs out;
//! - **O** the hanging endpoint's timeout is observable through the sink (an
//!   event naming that subscription whose outcome is not `Delivered`);
//! - **C** the canary is healthy when every delivery went through, a healthy
//!   canary implies every healthy real subscription was delivered, and a
//!   change whose delivery path fails (the tenant's subscriptions cannot be
//!   read within the budget) turns the canary red;
//! - **R** no call targets a reserved name.

use std::collections::HashMap;
use std::future::Future;
use std::panic::{self, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use credentials_backend::notifier::{DeliveryEvent, DeliverySink, Notifier, Outcome, WEBHOOK_KIND};
use credentials_backend::settings::{Setting, SettingsStore, PAGE_READ_LATENCY, PAGE_SIZE};
use credentials_backend::status::StatusChange;
use credentials_backend::webhook::{PostFuture, WebhookError, WebhookTransport};
use serde_json::{json, Value};
use url::Url;

/// Round trip of every in-process endpoint.
const LATENCY: Duration = Duration::from_millis(150);

const SMALL: Tenant = Tenant {
    did: "did:web:members.harbourclub.example",
    host: "door.harbourclub.example",
    preferences: 12,
    subscribers: 3,
};
const LARGE: Tenant = Tenant {
    did: "did:web:issuer.cedarrowing.example",
    host: "gate.cedarrowing.example",
    preferences: 30_000,
    subscribers: 20,
};

// ---------------------------------------------------------------------------
// Reference-derived vectors
// ---------------------------------------------------------------------------

fn practice_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn read_reference(name: &str) -> String {
    let path = practice_root().join("reference/infra").join(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("cannot read {}: {e}", path.display()))
}

/// `function.timeout_seconds` of `webhook-config.yaml`.
fn budget() -> Duration {
    let yaml = read_reference("webhook-config.yaml");
    let mut section = "";
    for line in yaml.lines() {
        let content = line.split('#').next().unwrap_or("");
        if content.trim().is_empty() {
            continue;
        }
        if !content.starts_with(' ') {
            section = content.split(':').next().unwrap_or("").trim();
            continue;
        }
        if section == "function" {
            if let Some(value) = content.trim().strip_prefix("timeout_seconds:") {
                let seconds: u64 = value.trim().parse().expect("function.timeout_seconds is an integer");
                return Duration::from_secs(seconds);
            }
        }
    }
    panic!("webhook-config.yaml has no function.timeout_seconds");
}

/// The names in the "Reserved names" table of `reserved-domains.md`.
fn reserved_names() -> Vec<String> {
    let doc = read_reference("reserved-domains.md");
    let mut in_table = false;
    let mut names = Vec::new();
    for line in doc.lines() {
        if line.starts_with("## ") {
            in_table = line.trim() == "## Reserved names";
            continue;
        }
        if !in_table {
            continue;
        }
        if let Some(cell) = line.trim().strip_prefix("| `") {
            if let Some(name) = cell.split('`').next() {
                names.push(name.to_ascii_lowercase());
            }
        }
    }
    assert!(!names.is_empty(), "reserved-domains.md lists no reserved names");
    names
}

// ---------------------------------------------------------------------------
// Grader-owned transport and sink
// ---------------------------------------------------------------------------

#[derive(Clone, Copy)]
enum Endpoint {
    Answers,
    Hangs,
}

/// Answers every call in-process. Registered relying-party URLs answer (or
/// hang) as configured. A reserved name is answered the way the server behind
/// it may answer (200) but never contacted, and the call is recorded as a
/// violation. Any other URL is an endpoint the platform operates (a loopback
/// stub, an internal service) and answers 200.
struct GraderTransport {
    reserved: Vec<String>,
    endpoints: HashMap<String, Endpoint>,
    received: Mutex<HashMap<String, Vec<Vec<u8>>>>,
    reserved_calls: Mutex<Vec<String>>,
}

impl GraderTransport {
    fn new(reserved: &[String]) -> Self {
        GraderTransport {
            reserved: reserved.to_vec(),
            endpoints: HashMap::new(),
            received: Mutex::new(HashMap::new()),
            reserved_calls: Mutex::new(Vec::new()),
        }
    }

    fn is_reserved(&self, host: &str) -> bool {
        let host = host.trim_end_matches('.').to_ascii_lowercase();
        self.reserved.iter().any(|name| host == *name || host.ends_with(&format!(".{name}")))
    }

    fn received(&self, url: &str) -> Vec<Vec<u8>> {
        self.received.lock().unwrap().get(url).cloned().unwrap_or_default()
    }

    fn reserved_calls(&self) -> Vec<String> {
        self.reserved_calls.lock().unwrap().clone()
    }
}

impl WebhookTransport for GraderTransport {
    fn post<'a>(&'a self, url: &'a str, body: &'a [u8]) -> PostFuture<'a> {
        Box::pin(async move {
            match self.endpoints.get(url) {
                Some(Endpoint::Hangs) => std::future::pending().await,
                Some(Endpoint::Answers) => {
                    tokio::time::sleep(LATENCY).await;
                    self.received.lock().unwrap().entry(url.to_string()).or_default().push(body.to_vec());
                    Ok(200)
                }
                None => {
                    let parsed = Url::parse(url).map_err(|_| WebhookError::InvalidUrl(url.to_string()))?;
                    let host = parsed.host_str().ok_or_else(|| WebhookError::InvalidUrl(url.to_string()))?;
                    if self.is_reserved(host) {
                        self.reserved_calls.lock().unwrap().push(url.to_string());
                        return Ok(200);
                    }
                    tokio::time::sleep(LATENCY).await;
                    Ok(200)
                }
            }
        })
    }
}

#[derive(Default)]
struct RecordingSink {
    events: Mutex<Vec<DeliveryEvent>>,
}

impl DeliverySink for RecordingSink {
    fn record(&self, event: DeliveryEvent) {
        self.events.lock().unwrap().push(event);
    }
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

struct Tenant {
    did: &'static str,
    host: &'static str,
    preferences: usize,
    subscribers: usize,
}

struct Subscriber {
    id: String,
    url: String,
    healthy: bool,
}

impl Tenant {
    /// Puts the tenant's settings in `settings` and its endpoints in
    /// `transport`. With `hang_first`, the first subscriber in key order never
    /// answers.
    fn install(&self, settings: &SettingsStore, transport: &mut GraderTransport, hang_first: bool) -> Vec<Subscriber> {
        for i in 0..self.preferences {
            settings.put(Setting::new(self.did, &format!("pref/{i:05}"), "preference", json!({ "n": i })));
        }
        (1..=self.subscribers)
            .map(|i| {
                let id = format!("rp-{i:05}");
                let url = format!("https://{}/hooks/{id}", self.host);
                settings.put(Setting::new(self.did, &format!("webhook/{id}"), WEBHOOK_KIND, json!({ "url": url })));
                let healthy = !(hang_first && i == 1);
                transport.endpoints.insert(url.clone(), if healthy { Endpoint::Answers } else { Endpoint::Hangs });
                Subscriber { id, url, healthy }
            })
            .collect()
    }
}

fn revoked(tenant: &str, index: usize) -> StatusChange {
    StatusChange {
        credential_id: format!("urn:uuid:5e1f0000-0000-4000-8000-{index:012}"),
        issuer: tenant.to_string(),
        status_list: format!("{tenant}#revocation"),
        status_index: index,
        revoked: true,
    }
}

/// Healthy subscribers that did not receive `change` (by the time `notify`
/// returned or the budget ran out).
fn undelivered<'s>(transport: &GraderTransport, subscribers: &'s [Subscriber], change: &StatusChange) -> Vec<&'s str> {
    subscribers
        .iter()
        .filter(|s| s.healthy)
        .filter(|s| {
            !transport.received(&s.url).iter().any(|body| {
                serde_json::from_slice::<Value>(body)
                    .map(|v| v["credential_id"] == change.credential_id.as_str() && v["revoked"] == true)
                    .unwrap_or(false)
            })
        })
        .map(|s| s.id.as_str())
        .collect()
}

fn summary(ids: &[&str]) -> String {
    match ids.len() {
        0 => String::new(),
        1..=3 => ids.join(", "),
        n => format!("{}, … ({n} in all)", ids[..3].join(", ")),
    }
}

/// What one change to one tenant produced.
struct Observed {
    undelivered: Vec<String>,
    healthy_total: usize,
    hung: Option<(String, String)>,
    events: Vec<DeliveryEvent>,
    reserved_calls: Vec<String>,
    canary_healthy: bool,
}

/// Runs `fut` on a fresh current-thread runtime whose clock is paused.
fn virtual_time<F: Future>(fut: F) -> F::Output {
    tokio::runtime::Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()
        .expect("tokio runtime")
        .block_on(fut)
}

fn scenario(tenant: &Tenant, hang_first: bool, budget: Duration, reserved: &[String]) -> Observed {
    virtual_time(async {
        let settings = Arc::new(SettingsStore::new());
        let mut transport = GraderTransport::new(reserved);
        let subscribers = tenant.install(&settings, &mut transport, hang_first);
        let transport = Arc::new(transport);
        let sink = Arc::new(RecordingSink::default());
        let notifier = Notifier::new(settings, transport.clone(), sink.clone());
        let change = revoked(tenant.did, 7);

        // The runtime's hard kill: whatever has not arrived by then never does.
        let _ = tokio::time::timeout(budget, notifier.notify(&change)).await;

        let undelivered = undelivered(&transport, &subscribers, &change).into_iter().map(str::to_string).collect();
        let hung = subscribers.iter().find(|s| !s.healthy).map(|s| (s.id.clone(), s.url.clone()));
        let events = sink.events.lock().unwrap().clone();
        Observed {
            undelivered,
            healthy_total: subscribers.iter().filter(|s| s.healthy).count(),
            hung,
            events,
            reserved_calls: transport.reserved_calls(),
            canary_healthy: notifier.canary_healthy(),
        }
    })
}

/// A healthy change first (the canary must be green), then a change whose
/// tenant's subscriptions cannot be read within the budget: nobody receives
/// it, so the canary must turn red.
fn path_failure(budget: Duration, reserved: &[String]) -> Result<(), String> {
    virtual_time(async {
        let settings = Arc::new(SettingsStore::new());
        let mut transport = GraderTransport::new(reserved);
        let healthy = SMALL.install(&settings, &mut transport, false);
        // Enough subscriptions that even the keyed lookup outlasts the budget.
        let pages = budget.as_millis() / PAGE_READ_LATENCY.as_millis().max(1) + 40;
        let flooded = Tenant {
            did: "did:web:guild.northfield.example:chapters:north",
            host: "hall.northfield.example",
            preferences: 0,
            subscribers: pages as usize * PAGE_SIZE.max(1),
        };
        let flooded_subs = flooded.install(&settings, &mut transport, false);
        let transport = Arc::new(transport);
        let sink = Arc::new(RecordingSink::default());
        let notifier = Notifier::new(settings, transport.clone(), sink);

        let first = revoked(SMALL.did, 8);
        let _ = tokio::time::timeout(budget, notifier.notify(&first)).await;
        let missed = undelivered(&transport, &healthy, &first);
        if !missed.is_empty() {
            return Err(format!("precondition: healthy tenant not delivered ({})", summary(&missed)));
        }
        if !notifier.canary_healthy() {
            return Err("precondition: canary not healthy after a change every subscriber received".into());
        }

        let second = revoked(flooded.did, 9);
        let _ = tokio::time::timeout(budget, notifier.notify(&second)).await;
        let missed = undelivered(&transport, &flooded_subs, &second);
        if notifier.canary_healthy() && !missed.is_empty() {
            return Err(format!(
                "canary healthy, but {} of {} subscribers of the tenant got nothing ({})",
                missed.len(),
                flooded_subs.len(),
                summary(&missed)
            ));
        }
        Ok(())
    })
}

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------

type CaseResult = Result<(), String>;

fn delivered_within(o: &Observed, budget: Duration) -> CaseResult {
    if o.undelivered.is_empty() {
        return Ok(());
    }
    let ids: Vec<&str> = o.undelivered.iter().map(String::as_str).collect();
    Err(format!("{} of {} healthy subscribers not delivered within {budget:?} ({})", ids.len(), o.healthy_total, summary(&ids)))
}

fn timeout_observable(o: &Observed) -> CaseResult {
    let (id, url) = o.hung.as_ref().expect("scenario has a hanging endpoint");
    let reported = o.events.iter().any(|e| {
        (e.subscription == *id || e.subscription == *url) && !matches!(e.outcome, Outcome::Delivered { .. })
    });
    if reported {
        Ok(())
    } else {
        Err(format!("no sink event reports {id} (never answered) as not delivered"))
    }
}

fn canary_healthy(o: &Observed) -> CaseResult {
    if o.canary_healthy {
        Ok(())
    } else {
        Err("canary not healthy although every subscriber was reachable".into())
    }
}

fn canary_implies_delivery(o: &Observed) -> CaseResult {
    if !o.canary_healthy || o.undelivered.is_empty() {
        return Ok(());
    }
    Err(format!("canary healthy while {} healthy subscribers got nothing", o.undelivered.len()))
}

fn no_reserved_calls(o: &Observed) -> CaseResult {
    match o.reserved_calls.first() {
        None => Ok(()),
        Some(url) => Err(format!("{} call(s) to a reserved name, e.g. {url}", o.reserved_calls.len())),
    }
}

/// Runs `f`, turning a panic in the notifier into a
/// failed case instead of aborting the axis.
fn guarded<T>(f: impl FnOnce() -> T) -> Result<T, String> {
    panic::catch_unwind(AssertUnwindSafe(f)).map_err(|p| {
        let msg = p
            .downcast_ref::<String>()
            .cloned()
            .or_else(|| p.downcast_ref::<&str>().map(|s| s.to_string()))
            .unwrap_or_else(|| "panic".into());
        format!("panicked: {msg}")
    })
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

fn main() {
    let budget = budget();
    let reserved = reserved_names();

    let mut cases: Vec<(String, String, CaseResult)> = Vec::new();

    let scenarios = [
        (&SMALL, false, "small tenant, all healthy"),
        (&SMALL, true, "small tenant, first subscriber hangs"),
        (&LARGE, false, "large tenant, all healthy"),
        (&LARGE, true, "large tenant, first subscriber hangs"),
    ];
    let mut n = 0;
    for (tenant, hang_first, label) in scenarios {
        n += 1;
        let observed = guarded(|| scenario(tenant, hang_first, budget, &reserved));
        let check = |f: fn(&Observed) -> CaseResult| match &observed {
            Ok(o) => f(o),
            Err(e) => Err(e.clone()),
        };
        let delivered = match &observed {
            Ok(o) => delivered_within(o, budget),
            Err(e) => Err(e.clone()),
        };
        cases.push((format!("D{n}"), format!("{label}: every healthy subscriber delivered within {budget:?}"), delivered));
        if hang_first {
            cases.push((format!("O{n}"), format!("{label}: the hanging endpoint's timeout reaches the sink"), check(timeout_observable)));
        } else {
            cases.push((format!("C{n}"), format!("{label}: canary healthy"), check(canary_healthy)));
        }
        cases.push((format!("K{n}"), format!("{label}: canary healthy implies every healthy subscriber delivered"), check(canary_implies_delivery)));
        cases.push((format!("R{n}"), format!("{label}: no call to a reserved name (reference/infra/reserved-domains.md)"), check(no_reserved_calls)));
    }
    cases.push((
        "P1".into(),
        "delivery path fails (subscriptions unreadable within the budget): canary turns red".into(),
        guarded(|| path_failure(budget, &reserved)).and_then(|r| r),
    ));

    let total = cases.len();
    let mut passed = 0;
    for (id, name, outcome) in &cases {
        match outcome {
            Ok(()) => {
                passed += 1;
                println!("ok   {id} {name}");
            }
            Err(reason) => println!("FAIL {id} {name}: {reason}"),
        }
    }
    let verdict = if passed == total { "PASS" } else { "FAIL" };
    println!("axis a2: {verdict} {passed}/{total}");
    std::process::exit(if passed == total { 0 } else { 1 });
}
