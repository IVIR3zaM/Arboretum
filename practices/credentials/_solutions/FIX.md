# FIX — both tickets (phase 2)

> Spoiler / answer key. Examiner-only; stripped from the learner clone. The reference fixes are
> `reference-fix/ticket-1.patch` and `reference-fix/ticket-2.patch`, each a `git apply` patch against
> the practice root. The phase-3 feature has its own answer key: `FEATURE-FIX.md` and the overlay in
> `feature-reference/`.

Apply to a copy of the shipped tree and grade:

```
git apply _solutions/reference-fix/ticket-1.patch
git apply _solutions/reference-fix/ticket-2.patch
cp -R _solutions/feature-reference/. .          # the phase-3 reference build
bash _solutions/grade.sh                         # → axis a PASS 26/26 · axis a2 PASS 17/17 · axis b PASS 7/7 · worst-case: PASS
```

Measured 2026-09-27 on the shipped tree plus the two patches and the overlay. The shipped tree
alone scores `axis a: FAIL 6/26`, `axis a2: FAIL 4/17`, `axis b: FAIL 0/7`, with both visible
suites green (backend 68 tests, wallet 20 tests). The patches are independent: each applies to the
shipped tree or on top of the other, and `ticket-2.patch` touches only `backend/src/notifier.rs`.

---

## Ticket 1 — resolve the issuer's current did:web document, at the root

### The fix (`ticket-1.patch`, 28 changed lines in two files)

1. **`backend/src/verifier.rs`, `Verifier::resolve_issuer` (lines 196-202).** Delete the early
   return `if let Some(issuer) = self.store.onboarded_issuer(did) { return Ok(issuer.document); }`,
   leaving `Ok(self.resolver.resolve(did)?)`. The resolver already does the real did:web fetch
   through the injected transport; onboarding (`issuer::onboard`) already uses it. Every
   verification now checks the issuer's proof against the document the issuer serves *now*
   (`reference/did-web-method.md` §3.3 and §4: "the document currently served at the URL **is**
   the DID document"; "a key that no longer appears in the document ... is not a key of the DID").
2. **`backend/src/resolver.rs`, `did_web_url` (lines 94-100).** Only a bare-domain DID gets
   `/.well-known`: `did:web:host` → `https://host/.well-known/did.json`, but
   `did:web:host:p1:p2` → `https://host/p1/p2/did.json` (§3.2 steps 4-6, and the object-key table in
   `reference/infra/did-hosting.md`). The shipped builder put every path under `/.well-known`, so the
   path-based Northfield DID resolved to an object the bucket does not hold. The doc comment
   (lines 78-81), which described the wrong mapping as intended, is rewritten to the spec's.

The onboarding snapshot (`backend/data/onboarded-issuers.json`) stays: it is the onboarding record,
not a source of keys. Nothing else changes; the visible suite stays green.

### Why each half is needed

Removing only the early return turns Northfield (`did:web:guild.northfield.example:chapters:north`)
from "refused by the key check" into "fails to resolve" (`Transport(NotFound)` at
`.../.well-known/chapters/north/did.json`): an earlier cold run's verifier-only diff (recorded before the path mapping was planted), replayed on the shipped tree, scored
`axis a: FAIL 17/26` (S3, R2, V3, V7, N5, N6, W2, W4, W5 red). Fixing only the URL
builder changes nothing a verifier sees, because the snapshot early return is taken first for every
onboarded issuer. Only both converge: `axis a: PASS 26/26`.

### Why the autopilot fix plateaus (FM-13)

| Attempt | What it does | axis (a) | Why it stays red |
|---|---|---|---|
| Symptom patch | special-cases the failing issuer (Cedar Rowing) inside `verify_credential`, leaving `resolve_issuer` alone | **FAIL 9/26** | the grader calls the root (`resolve_issuer`) directly: V2 still returns Cedar Rowing's stale `#key-1` snapshot, and every other rotated issuer is untouched |
| Re-pin | overwrites Cedar Rowing's onboarding snapshot with its hosted `did.json` | **FAIL 8/26** | fixes that issuer today (S2 `ok`, visible suite green), then fails the other rotated issuers, the grader's next rotation of every issuer (N1-N7) and the path mapping (W2, W4, W5) |
| Reference | fetch the current document at the root, with the §3.2 mapping | **PASS 26/26** | any rotation, now or later, resolves |

The re-pin is the plausible first suggestion: the ticket names a re-approved batch, the snapshot
file is right there, and the hosted documents in `reference/` hold the new key. It passes everything
a local check can see and plateaus on the next rotation.

### The caching aside (named, not built)

The method spec permits HTTP caching of the document within the `Cache-Control` lifetime the host
returns (`did-hosting.md`: `max-age=300`). A cache is an optimisation with its own invalidation
questions, not part of this ticket; a learner who raises it and defers it out loud has matched the
altitude. Building one is over-scope (FM-10), and a cache keyed without an expiry reintroduces the
bug.

### Known limitations of the reference fix (the grader cannot see them)

- **Credentials signed with a retired key are now refused.** Correct per §4, and what the grader
  asserts (R1-R3, N2, N4, N6), but it has an operational consequence the ticket does not mention:
  members holding in-date credentials signed before their club rotated will be turned away until
  re-issued. A good run surfaces this before deploying (the cold opus run did, unprompted).
- **No trust-registry check** (latent #6) and **the proof-type fall-through** (latent #7) are left
  as shipped: they are phase-4 findings, not Ticket 1.

---

## Ticket 2 — the webhook fan-out incident: all four axes, in `backend/src/notifier.rs`

### The four axes and the convergent fix (`ticket-2.patch`)

| Axis | Shipped (line) | Fix |
|---|---|---|
| **A1** silent timeout | the fan-out is wrapped in `tokio::time::timeout(DISPATCH_BUDGET, …)` and on expiry only `eprintln!`s (152-154); a call that never completes produces no event | report every call that fails to answer: a per-call timeout records `Outcome::Failed { reason: "no answer within 5s" }`, and a fan-out overrun records a `Failed` event for subscription `*` |
| **A2** head-of-line | `for sub in … { self.dispatch(…).await }` — sequential, one shared budget, no per-call limit (141-149) | dispatch every subscription side by side (a std-only `join_all`, no new crate) with a per-call `CALL_TIMEOUT` of 5 s |
| **A3** unindexed scan | `subscriptions` pages through **every** setting of the tenant and filters `kind == "webhook"` (158-169); 50 ms per page of 100, so > 20,000 settings blow the 10 s budget before any call | read through the `tenant-kind` index: `self.settings.query_kind(tenant, WEBHOOK_KIND)` (the method already exists, `settings.rs:100-111`; the index is declared in `reference/infra/webhook-config.yaml`) |
| **A4** the canary lies | `CANARY_URL = "https://example.com/webhooks/status"` (29) — an RFC 2606 name; the canary is platform subscriber 0 (118) and is dispatched **before** the tenant lookup (141-146), so it is acknowledged whatever happens to the real subscribers | a loopback stub the platform serves (`http://127.0.0.1/webhooks/canary`); the canary goes out *after* the lookup, alongside the tenant's subscribers; `canary_ok` is reset at the start of every change, so a change whose fan-out never reaches the calls leaves the canary red |

The budget itself is not raised: the 10 s is the runtime's hard kill
(`webhook-config.yaml: function.timeout_seconds: 10`), and the grader imposes it from outside the
notifier, so editing `DISPATCH_BUDGET` buys nothing.

### Why every single-axis fix plateaus (FM-13, operational edition)

The grader (`grader/src/a2.rs`, 17 cases) scores worst-case across
`{small tenant, large tenant} × {all healthy, first subscriber hangs}` plus a delivery-path failure,
asserting: every healthy subscriber delivered within 10 s (D1-D4), the canary healthy when everything
is reachable (C1, C3), the hanging endpoint's timeout reaches the sink (O2, O4), canary healthy ⇒
every healthy subscriber delivered (K1-K4), no call to a reserved name (R1-R4), and the canary turns
red when the tenant's subscriptions cannot be read within the budget (P1).

| Tree (shipped + `ticket-1.patch` +) | axis (a2) | What stays red |
|---|---|---|
| nothing | FAIL 4/17 | all but D1, K1 (small tenant, all healthy) and C1, C3 (the canary reports healthy) |
| A1 alone | FAIL 4/17 | the large tenant never gets past the scan; one hang still starves the rest; the canary still calls example.com first |
| A2 alone | FAIL 6/17 | the large tenant still times out in the scan (D3, D4); the canary still lies (K, R, P1) |
| A3 alone | FAIL 6/17 | one hanging endpoint still starves the rest (D2, D4); no timeout signal (O2, O4); the canary still lies |
| A4 alone | FAIL 11/17 | delivery is still broken for the large tenant and behind a hang (D2-D4, O2, O4), and now the canary honestly goes red (C3) |
| all but A1 / A2 / A3 / A4 | FAIL 15 / 13 / 13 / 12 of 17 | every axis is necessary |
| all four (`ticket-2.patch`) | **PASS 17/17** | — |

A cold opus run given only `TICKET-2.md` fixed A3 and A2, reported per-call timeouts (A1's per-call
half), and moved the canary after the lookup, but deferred the canary's `example.com` target as a
question for Platform: `axis a2: FAIL 13/17` (R1-R4 red). Three and a half axes do not close the
incident.

### Known limitations of the reference fix (the grader cannot see them)

- **The fan-out overrun event fires at the runtime's own kill time.** `DISPATCH_BUDGET` stays 10 s,
  the same as `function.timeout_seconds`. In production the runtime terminates the invocation at
  10 s, so the `*` overrun event would race the kill and may never be recorded. The per-call timeout
  (5 s) is what makes a hanging endpoint observable in practice; a margin below the hard limit (the
  cold run chose 8 s) would make the overrun event reliable too. The grader imposes the budget from
  outside with a paused clock and sees the per-call events, so it cannot tell.
- **The reserved-name rule is enforced at one entry point.** The fix changes the canary's URL; it does
  not stop the notifier from calling a *tenant* subscription registered at a reserved name, which
  `reference/infra/reserved-domains.md` forbids for every outbound call. Robustness probe N2 catches
  it (the reference build fails it).
- **No retries and no re-send of missed changes.** `webhook-config.yaml` sets
  `maximum_retry_attempts: 0` and no failure destination; a relying party that is briefly down misses
  the change until the next status-list refresh, and the revocations the large tenant already missed
  are not re-sent. Both are product/platform decisions beyond this ticket; a good run names them.
- **The canary is still one platform subscriber.** It now shares the tenant's path, so a passing
  canary implies the lookup and the fan-out ran; it does not prove any one relying party's endpoint
  answered. That is what the per-subscription sink events are for.
