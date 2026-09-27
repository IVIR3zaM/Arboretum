# N09 — Ticket 2 plant: webhook notifier + canary (consumed by N12 grader)

Paths relative to `practices/credentials/`. Line numbers as shipped by N09.
`cargo test --offline --locked` green: 68 tests (N06's 58 untouched + `tests/notifier.rs` 6 +
`tests/settings.rs` 4). New dependency: `tokio = "=1.53.1"` (lib: `rt`, `time`; dev: `+ macros,
test-util`), pulls `tokio-macros 2.7.2`; both checked live on index.crates.io (not yanked),
Cargo.lock updated by `cargo fetch` (only those two packages added). N06's API is unchanged; the
new modules are `notifier`, `settings`, `webhook` (all `pub` in `src/lib.rs`).

## Root entry point

`backend/src/notifier.rs:136` — `pub async fn Notifier::notify(&self, change: &StatusChange)`.
Tenant = `change.issuer` (the issuer DID). Built with
`Notifier::new(settings: Arc<SettingsStore>, transport: Arc<dyn WebhookTransport>, sink: Arc<dyn DeliverySink>)`
(notifier.rs:113). Health check: `Notifier::canary_healthy(&self) -> bool` (notifier.rs:130) —
whether the canary acknowledged the most recent change; `false` before the first notify.
Hook into revocation: `let change = status::revoke_credential(&store, id)?; notifier.notify(&change).await;`.
Payload: `notifier::payload(&StatusChange) -> Vec<u8>` (JSON: type, credential_id, issuer,
status_list, status_index, revoked).

## The four axes

| Axis | Where | What |
|---|---|---|
| A1 silent timeout | `backend/src/notifier.rs:23` (`DISPATCH_BUDGET = 10 s`, hardcoded) and `:152-154` | the whole fan-out is wrapped in `tokio::time::timeout(DISPATCH_BUDGET, …)`; on expiry it only `eprintln!`s. Nothing reaches the sink for the subscriptions that never ran. |
| A2 head-of-line | `backend/src/notifier.rs:141-149` (the loops; `:147` is `for sub in self.subscriptions(tenant).await { self.dispatch(…).await }`) | sequential `dispatch(...).await` sharing the one budget; no per-call timeout. One hanging endpoint starves every subscription after it. |
| A3 unindexed scan | `backend/src/notifier.rs:158-169` (`subscriptions`, `:162` `self.settings.query(tenant, cursor)`) | pages through **all** the tenant's settings and filters `kind == "webhook"`. `SettingsStore::query` (settings.rs:80-81) costs `PAGE_READ_LATENCY` = 50 ms per page of `PAGE_SIZE` = 100 (settings.rs:17,20). The keyed alternative already exists: `SettingsStore::query_kind(tenant, kind)` (settings.rs:100-111), one page per 100 matches (1 page for any realistic subscriber count). Budget crossed at > 20 000 settings (200 pages); the demo's large tenant (30 020 settings) scans for 15.05 s. |
| A4 canary lies | `backend/src/notifier.rs:29` (`CANARY_URL = "https://example.com/webhooks/status"`), `:118` (`platform: vec![Subscription::canary()]` — index 0), `:141-146` (platform subscribers dispatched **before** the tenant lookup; `canary_ok` set from that call) | the canary is reached before the scan and before any real subscriber, so it is acknowledged in every case, and its target is an RFC 2606 name. `HermeticTransport::new()` (webhook.rs:84-86) answers the canary's host with an in-process stub (200, zero latency) — nothing goes over the network. |

Reference truth: `reference/infra/webhook-config.yaml` (`function.timeout_seconds: 10` — hard
kill; `async_invocation.maximum_retry_attempts: 0`; `tables.tenant-settings` with
`tenant-kind-index`; `monitoring.alarms: []`), `reference/infra/reserved-domains.md` (RFC 2606 §3
names must never be live endpoints, incl. health probes). FM-15 drift: `backend/README.md`
"Notifications" paragraph — "Status notifications are delivered concurrently to every subscriber,
with failed deliveries retried." (code: sequential, no retry).

## The sink (A1's observability surface)

```rust
// backend/src/notifier.rs:67-69
pub trait DeliverySink: Send + Sync { fn record(&self, event: DeliveryEvent); }
// notifier.rs:52-64 (Outcome :52, DeliveryEvent :60)
pub enum Outcome { Delivered { status: u16 }, Failed { reason: String } }
pub struct DeliveryEvent { pub tenant: String, pub subscription: String, pub outcome: Outcome }
pub struct MemorySink;  // Default; .events() -> Vec<DeliveryEvent>
```
Today the notifier records `Delivered` on 2xx and `Failed` on non-2xx / transport error, one event
per completed call (canary's `subscription` is `"canary"`; tenant subscriptions use the setting key
after `webhook/`). A call that never completes produces no event. Suggested grader assertion: when a
real subscription is not delivered, some event for that tenant has an outcome that is not
`Outcome::Delivered` — written as `!matches!(e.outcome, Outcome::Delivered { .. })` so a learner who
adds a variant (e.g. `TimedOut`) or reuses `Failed` both pass.

## Injecting the transport and the clock

- **Transport:** `webhook::HermeticTransport` (webhook.rs) implements `WebhookTransport`
  (`fn post<'a>(&'a self, url: &'a str, body: &'a [u8]) -> PostFuture<'a>`, returns HTTP status).
  `transport.route(url, Endpoint)` / `route_host(host, Endpoint)`; `Endpoint::ok()` (200 after
  `Endpoint::TYPICAL_LATENCY` = 150 ms), `Endpoint::status(code)`, `Endpoint::slow(d)`,
  `Endpoint::Hang` (never answers). Unrouted URL → `Err(WebhookError::Unreachable)`.
  `transport.received(url) -> Vec<Vec<u8>>` = bodies the endpoint answered. A grader may
  implement `WebhookTransport` itself (e.g. to refuse reserved names).
- **Clock:** tokio's paused clock. `#[tokio::test(start_paused = true)]` (needs dev feature
  `test-util`, present) or `tokio::time::pause()`. All latency is `tokio::time::sleep`, so large
  tenants and hanging endpoints run in milliseconds of wall time.
- **Tenants:** `settings::SettingsStore::new()` + `put(Setting::new(tenant, key, kind, value))`;
  a subscription is `Setting::new(tenant, "webhook/<id>", notifier::WEBHOOK_KIND, json!({"url": …}))`.
  Keys sort, so `pref/*` settings are scanned before `webhook/*`.

## Single-axis plateau (verified, `t2-demo.txt` part 2)

Worst case over {small (12 prefs + 3 subs), large (30 000 prefs + 20 subs)} × {all healthy, first
subscriber hangs}, pass = every healthy real sub delivered within 10 s ∧ timeout observable ∧
(canary healthy ⇒ all healthy real subs delivered). Each single-axis fix is RED; "all but A1/A2/A3"
are RED. **"All but A4" is GREEN on these four cases** — once delivery works, the old canary is
never wrong about it. N12 needs one more A4 probe, e.g. (a) a grader transport that does *not*
stub reserved names (answers `example.com` / RFC 2606 names as unreachable) and asserts the canary
is healthy in the all-healthy case, and/or (b) asserts no call went to a reserved name; or
(c) a case where the tenant's real delivery path fails (e.g. a settings store that errors/hangs
for the tenant) and asserts `!canary_healthy()`.

## Notes for N12

- The budget is a constant a learner can edit. Impose the real 10 s
  (`webhook-config.yaml: function.timeout_seconds`) **outside** the notifier
  (`tokio::time::timeout(Duration::from_secs(10), notifier.notify(&change))`), otherwise raising
  `DISPATCH_BUDGET` "fixes" A2/A3 sequentially for a slow-but-finite endpoint (a hanging one still
  starves).
- Use `Endpoint::Hang` for the slow endpoint and place it first among the tenant's subscribers.
- The visible suite never builds a large tenant nor a slow/hanging endpoint.
