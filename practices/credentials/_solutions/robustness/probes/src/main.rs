//! EXAMINER-ONLY robustness probes, backend half (non-blocking).
//!
//! Stripped from the learner clone with the rest of `_solutions/`. Never run
//! by `grade.sh`; the gate's pass/fail and exit code do not depend on it.
//! `_solutions/robustness-probes.sh` builds and runs it against the graded
//! tree's `backend/`. One line per probe: `PASS <id> <what>` or
//! `FAIL <id> <what>: <why>`.
//!
//! - **N1** degenerate quantity: a change for a tenant with no subscription
//!   at all fans out within the budget, reports no failure, and leaves the
//!   canary healthy.
//! - **N2** a guard at one entry point instead of on the invariant: the
//!   reserved-name rule (`reference/infra/reserved-domains.md`: every
//!   outbound call, webhooks included) holds for a tenant's subscription too,
//!   not only for the canary's own URL.
//! - **S1** degenerate quantity (latent #5): every index a status list hands
//!   out, up to its capacity, can be revoked.

use std::collections::BTreeSet;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use credentials_backend::notifier::{MemorySink, Notifier, Outcome, WEBHOOK_KIND};
use credentials_backend::settings::{Setting, SettingsStore};
use credentials_backend::status::{StatusChange, StatusList};
use credentials_backend::webhook::{PostFuture, WebhookError, WebhookTransport};
use serde_json::json;
use url::Url;

/// `reference/infra/webhook-config.yaml`: `function.timeout_seconds`.
const BUDGET: Duration = Duration::from_secs(10);

/// `reference/infra/reserved-domains.md`: RFC 2606 §3 names.
const RESERVED: [&str; 3] = ["example.com", "example.net", "example.org"];

fn is_reserved(host: &str) -> bool {
    RESERVED.iter().any(|name| host == *name || host.ends_with(&format!(".{name}")))
}

/// Answers every call 200 at once and records the URLs it was sent.
#[derive(Default)]
struct RecordingTransport {
    calls: Mutex<Vec<String>>,
}

impl WebhookTransport for RecordingTransport {
    fn post<'a>(&'a self, url: &'a str, _body: &'a [u8]) -> PostFuture<'a> {
        Box::pin(async move {
            Url::parse(url).map_err(|_| WebhookError::InvalidUrl(url.to_string()))?;
            self.calls.lock().unwrap().push(url.to_string());
            Ok(200)
        })
    }
}

impl RecordingTransport {
    fn reserved_calls(&self) -> Vec<String> {
        self.calls
            .lock()
            .unwrap()
            .iter()
            .filter(|u| Url::parse(u).ok().and_then(|p| p.host_str().map(is_reserved)).unwrap_or(false))
            .cloned()
            .collect()
    }
}

fn change(tenant: &str) -> StatusChange {
    StatusChange {
        credential_id: "urn:uuid:probe-change".to_string(),
        issuer: tenant.to_string(),
        status_list: format!("{tenant}#revocation"),
        status_index: 7,
        revoked: true,
    }
}

fn subscription(tenant: &str, id: &str, url: &str) -> Setting {
    Setting::new(tenant, &format!("webhook/{id}"), WEBHOOK_KIND, json!({ "url": url }))
}

/// Runs `notify` for `tenant` under a paused clock, with the budget imposed
/// from outside the notifier. Returns (finished in budget, notifier, sink, transport).
fn run(settings: SettingsStore, tenant: &str) -> (bool, Notifier, Arc<MemorySink>, Arc<RecordingTransport>) {
    let transport = Arc::new(RecordingTransport::default());
    let sink = Arc::new(MemorySink::default());
    let notifier = Notifier::new(Arc::new(settings), transport.clone(), sink.clone());
    let runtime = tokio::runtime::Builder::new_current_thread().enable_time().start_paused(true).build().unwrap();
    let finished = runtime.block_on(async { tokio::time::timeout(BUDGET, notifier.notify(&change(tenant))).await.is_ok() });
    (finished, notifier, sink, transport)
}

type Outcome_ = Result<(), String>;

fn n1() -> Outcome_ {
    let tenant = "did:web:quiet.probe.test";
    let settings = SettingsStore::new();
    settings.put(Setting::new("did:web:other.probe.test", "webhook/rp-1", WEBHOOK_KIND, json!({ "url": "https://rp.other.probe.test/hook" })));
    let (finished, notifier, sink, _) = run(settings, tenant);
    if !finished {
        return Err(format!("notify did not finish within {BUDGET:?}"));
    }
    let failures: Vec<_> = sink.events().into_iter().filter(|e| !matches!(e.outcome, Outcome::Delivered { .. })).collect();
    if !failures.is_empty() {
        return Err(format!("{} failure event(s) for a tenant with nothing to deliver, e.g. {:?}", failures.len(), failures[0]));
    }
    if !notifier.canary_healthy() {
        return Err("canary not healthy after a change with nothing to deliver".into());
    }
    Ok(())
}

fn n2() -> Outcome_ {
    let tenant = "did:web:docs.probe.test";
    let settings = SettingsStore::new();
    settings.put(subscription(tenant, "rp-live", "https://rp.docs.probe.test/hook"));
    settings.put(subscription(tenant, "rp-sample", "https://example.net/webhooks/status"));
    let (finished, _, sink, transport) = run(settings, tenant);
    if !finished {
        return Err(format!("notify did not finish within {BUDGET:?}"));
    }
    let reserved = transport.reserved_calls();
    if !reserved.is_empty() {
        let set: BTreeSet<_> = reserved.iter().cloned().collect();
        return Err(format!("{} call(s) to a reserved name: {}", reserved.len(), set.into_iter().collect::<Vec<_>>().join(", ")));
    }
    let live = sink.events().into_iter().any(|e| e.subscription == "rp-live" && matches!(e.outcome, Outcome::Delivered { .. }));
    if !live {
        return Err("the tenant's live subscriber was not delivered".into());
    }
    Ok(())
}

fn s1() -> Outcome_ {
    let capacity = 16;
    let mut list = StatusList::new(capacity);
    let mut handed_out = Vec::new();
    while let Some(index) = list.allocate() {
        handed_out.push(index);
        if handed_out.len() > capacity {
            return Err(format!("allocate handed out more than {capacity} indexes"));
        }
    }
    for &index in &handed_out {
        list.set(index, true);
    }
    let unrevokable: Vec<_> = handed_out.iter().copied().filter(|&i| !list.is_set(i)).collect();
    if !unrevokable.is_empty() {
        return Err(format!("index(es) {unrevokable:?} of a {capacity}-bit list were handed out but cannot be revoked"));
    }
    Ok(())
}

fn main() {
    std::panic::set_hook(Box::new(|_| {}));
    let probes: [(&str, &str, fn() -> Outcome_); 3] = [
        ("N1", "a tenant with no subscription: fan-out finishes, no failure reported, canary healthy", n1),
        ("N2", "a tenant subscription at a reserved name is never called (the rule holds beyond the canary)", n2),
        ("S1", "every status-list index handed out, up to capacity, can be revoked", s1),
    ];
    for (id, what, probe) in probes {
        let outcome = catch_unwind(AssertUnwindSafe(probe)).unwrap_or_else(|panic| {
            let reason = panic
                .downcast_ref::<String>()
                .cloned()
                .or_else(|| panic.downcast_ref::<&str>().map(|s| s.to_string()))
                .unwrap_or_else(|| "unknown panic".into());
            Err(format!("panicked: {reason}"))
        });
        match outcome {
            Ok(()) => println!("PASS {id} {what}"),
            Err(why) => println!("FAIL {id} {what}: {why}"),
        }
    }
}
