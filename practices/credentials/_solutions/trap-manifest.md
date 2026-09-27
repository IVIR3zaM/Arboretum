# trap-manifest — everything planted, honestly inventoried

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Cross-reference
> `context/cedar/failure-modes.md` for each FM's full definition. Paths are relative to the practice
> root; line numbers are the shipped tree's. Every score below is a real `bash _solutions/grade.sh`
> (or axis-script) outcome captured on 2026-09-27 while the kata was built; the model for every agent
> run is `claude-opus-5-5` through `claude -p --model opus`, one fresh session per run, in a
> harness-shaped clone, with a jail audit of every tool call (a run that touched anything outside its
> clone was voided and replaced once).

## The gate, in one table

`bash _solutions/grade.sh` ANDs three axes, worst-case (`grader.max` 50):

| Axis | What it grades | Cases | Shipped tree | Reference build |
|---|---|---|---|---|
| (a) `grade.d/a.sh` → `grader/src/main.rs` | Ticket 1 at the verification root | 26 | FAIL 6/26 | PASS 26/26 |
| (a2) `grade.d/a2.sh` → `grader/src/a2.rs` | Ticket 2 at the notifier root | 17 | FAIL 4/17 | PASS 17/17 |
| (b) `grade.d/b.sh` → `app-tests/feature_gate_test.dart` + `xstack/` | the phase-3 feature, wallet + cross-stack | 7 | FAIL 0/7 | PASS 7/7 |

Both visible suites are green on the shipped tree (backend 68 tests, wallet 20). The reference build
is the shipped tree + `reference-fix/ticket-1.patch` + `reference-fix/ticket-2.patch` +
`feature-reference/`.

---

## Ticket 1 — the did:web stale snapshot (phase 2, first ticket)

**Symptom** (`TICKET-1.md`): members of re-approved clubs are refused at the door; others are fine;
nobody can reproduce it; the suite is green.

**Planted instances**

| # | Location | What | FM |
|---|---|---|---|
| T1.1 | `backend/src/verifier.rs:196-202`, `Verifier::resolve_issuer` (the early return at 198-200) | for every onboarded issuer, returns the document recorded at onboarding (`backend/data/onboarded-issuers.json`) instead of `self.resolver.resolve(did)`, the working did:web fetch | FM-15 (stale path, no doc trace), FM-01, FM-02 |
| T1.2 | `backend/src/resolver.rs:94-100`, `did_web_url` (doc comment 78-81) | maps a path DID under `/.well-known` (`https://host/.well-known/p1/p2/did.json`); §3.2 of the method spec gives `https://host/p1/p2/did.json`. Northfield's document is then not found. The snapshot early return hides this on the shipped tree | FM-16 (only `reference/did-web-method.md` §3.2 and the object key in `reference/infra/did-hosting.md` / `hosted-dids/` reveal it), FM-02 |

**Ambient axis (Cedar's extended FM-02): the issuer's hosted-document state**, graded worst-case:
never rotated (Harbour Club) · rotated key with a new id (Cedar Rowing, `#key-1` → `#key-2`) · rotated
key material under the same id on a path DID (Northfield, `#signing`) · rotated key and moved
LinkedDomains endpoint (Kestrel) — plus a grader-only next rotation of every issuer that no
`reference/` file holds. The visible suite verifies only Harbour Club, for which snapshot == hosted.

**Axis (a) cases** (26): S1-S4 current key accepted per issuer state · R1-R3 retired keys rejected by
the key check (not by a resolution failure) · V1-V7 conformance vectors derived from `reference/`
(`resolve_issuer` returns the hosted document; id mismatch and deactivation fail; a ported path DID
resolves) · N1-N7 the grader-only next rotation · W1-W5 `did_web_url` against the §3.2 examples and
Northfield.

### FM-13 — the Ticket 1 plateau (verified by the contract test)

The autopilot moves it punishes, and the discipline that beats them:

- **Symptom patch** — special-case the failing issuer inside `verify_credential`, leave the root
  alone. Punishes *fix-without-a-model*: the grader calls `resolve_issuer` directly.
- **Re-pin** (the plausible first suggestion) — refresh the complaining issuer's onboarding snapshot
  from its hosted `did.json`, or hard-code its new key. Punishes *accept-the-first-suggestion*: it
  passes the visible suite and the re-pinned issuer, then fails every other rotated issuer and the
  next rotation of each.
- **Beats it:** *model-before-delegation* (the door must check the key the issuer publishes now) and
  *establish-cross-boundary-context* (§3.2-§4 of the method spec), fixing `resolve_issuer` and the
  URL mapping at the root.

**VERIFIED-TO-BITE** — the contract's FM-13 test (`generator/CONTRACT.md`, acceptance checklist): a
symptom patch and a plausible first-suggestion fix both leave the grader red, and only the root fix
passes. Each patch applied to a fresh copy of the shipped tree; the visible suite stays green in all
three.

| Patch | axis (a) | Evidence |
|---|---|---|
| Re-pin: Cedar Rowing's onboarding snapshot := its hosted `did.json` | **FAIL 8/26** | `ok S2` (the re-pinned issuer verifies); red S3, S4, R2, R3, V3-V7, N1-N5, N7, W2, W4, W5 |
| Symptom: Cedar Rowing special-cased in `verify_credential` | **FAIL 9/26** | `ok S2`; V2 shows `resolve_issuer` still returns Cedar Rowing's stale `#key-1` snapshot |
| Root fix: `reference-fix/ticket-1.patch` | **PASS 26/26** | — |

Before the path-DID plant the grader had 21 cases; on that tree the same moves measured: shipped
5/21, re-pin one issuer 7/21, **re-pin all three rotated issuers 12/21** (the grader-only next
rotation still fails every one of them), root fix 21/21 — and 21/21 with an empty `CARGO_HOME`
after `cargo fetch --locked`, run `--offline`. Superseded by the 26-case numbers above, kept because
the re-pin-all row is the strongest form of the plateau.

**When the plateau is measurable.** This row is measurable **only when the fix prompt precedes the
research pass, or in a fresh executor** that has not read `reference/`. A run that fixes with the
research already in context converges on the first try and never exercises the plateau; its result
says nothing about FM-13 either way.

**FM-16 evidence — a researched run converges.** A cold run given one casual prompt about
`TICKET-1.md` opened `reference/` early, read `did-web-method.md` itself on its 6th tool call, checked the
hosting layout against the URL builder, removed the snapshot early return, fixed the path mapping
unprompted, and scored **`axis a: PASS 26/26`** (clean audit, 19 tool calls, 2m11s). It is recorded
as evidence that the research pass converges, not as an FM-13 result. No recorded run shows a cold
agent caught by this plateau; the plateau is verified by the two adversary patches above. The run
also named three latent defects (#7 the proof-type skip, #6 no trust-registry client, #1 replay keyed
on `request_id`) as asides and fixed none of them.

**FM-16 — what the local repo alone supports.** A fix that removes the snapshot but keeps the local
URL builder — everything the repo itself shows — turns Northfield from "refused" into
`Transport(NotFound)`: an earlier cold run's verifier-only diff (recorded on the tree before the path
mapping was planted) replayed on the shipped tree scores **`axis a: FAIL 17/26`** (S3, R2, V3, V7,
N5, N6, W2, W4, W5 red). The only statement of the correct mapping and the only `chapters/north`
object key are under `reference/`.

---

## Ticket 2 — the webhook fan-out incident (phase 2, second ticket)

**Symptom** (`TICKET-2.md`): the health check is green, but the largest customer's revocation
callbacks never arrive; others are fine. Staged in only once Ticket 1 lands.

**Planted instances** — four linked axes in `backend/src/notifier.rs`, graded as one cluster (not
re-counted as latents):

| Axis | Location | What | FM |
|---|---|---|---|
| **A1** silent timeout | `notifier.rs:23` (`DISPATCH_BUDGET` = 10 s) and `:152-154` | the whole fan-out sits under one `tokio::time::timeout`; on expiry it only `eprintln!`s, and a call that never completes produces no sink event. The real budget (a hard kill) and the empty alarm list live only in `reference/infra/webhook-config.yaml` | FM-01, observability gap, FM-16 |
| **A2** head-of-line | `notifier.rs:141-149` (`:147` `for sub in … { self.dispatch(…).await }`) | sequential dispatch sharing the one budget, no per-call timeout: one hanging endpoint starves every subscriber after it | FM-05 (local shape, global failure), FM-02 (the subset behind the slow one) |
| **A3** unindexed scan | `notifier.rs:158-169` (`:162` `self.settings.query(tenant, cursor)`); cost model `settings.rs:17,20,80-81` | pages through every setting of the tenant (50 ms per 100) and filters `kind == "webhook"`; > 20,000 settings blow the budget before any call. The keyed lookup already exists (`settings.rs:100-111`, `query_kind`), and the index is declared in `webhook-config.yaml` | FM-02 (large tenants), FM-03 (idiomatic-looking scan), FM-16 |
| **A4** the canary lies | `notifier.rs:29` (`CANARY_URL` = `https://example.com/webhooks/status`), `:118` (platform subscriber 0), `:141-146` (dispatched before the tenant lookup; `canary_ok` set from that call) | the health check is acknowledged before the real path runs, and its target is an RFC 2606 reserved name (`reference/infra/reserved-domains.md`); `webhook.rs:84-86` stubs that host in-process for tests | FM-01 (green ≠ correct), FM-08 (a misused reserved external resource), FM-16 |

**Ambient axis:** tenant size × endpoint health — `{small (12 settings, 3 subscribers), large (30,000
settings, 20 subscribers)} × {all healthy, first subscriber hangs}` — plus a delivery-path failure
(24,000 subscriptions unreadable within the budget even through the index). The visible suite builds
only small tenants with healthy endpoints; the canary is always green in it.

### FM-13 — the four-axis plateau, operational edition (verified to bite)

**Axis (a2) cases** (17): D1-D4 every healthy subscriber delivered within 10 s · C1, C3 canary
healthy when all is reachable · O2, O4 the hanging endpoint's timeout reaches the sink as a
non-`Delivered` event · K1-K4 canary healthy ⇒ every healthy subscriber delivered · R1-R4 no call to
a reserved name · P1 the canary turns red when the tenant's subscriptions cannot be read in time. The
budget (`function.timeout_seconds`) and the reserved names are read from `reference/infra/` at run
time and imposed from outside the notifier; editing either reference file moves the result
(10 → 3 s: 15/17; adding the fix's loopback address to the reserved table: 13/17), and the gate
passes inside a no-network namespace. Three consecutive runs of the fixed tree hash identically.

Each axis patch applied alone to shipped + `ticket-1.patch`:

| Tree | axis (a2) |
|---|---|
| shipped + ticket-1 only | FAIL 4/17 |
| A1 alone | **FAIL 4/17** |
| A2 alone | **FAIL 6/17** |
| A3 alone | **FAIL 6/17** |
| A4 alone | **FAIL 11/17** |
| all but A1 / all but A2 / all but A3 / all but A4 | FAIL 15/17 / 13/17 / 13/17 / 12/17 |
| all four (`reference-fix/ticket-2.patch`) | **PASS 17/17** (axis a PASS) |

Measured twice with independent splits of `ticket-2.patch` (once while writing the grader, once
against the cold run below): identical scores. Only catching all four converges.

**Verified against a real cold agent.** A cold run given `TICKET-2.md` (Ticket 1 already fixed) and
one casual prompt — "TICKET-2.md just came in, can you handle it? Thanks." — scored
**`axis a2: FAIL 13/17`** (clean audit, 8 tool calls). It opened `reference/infra/webhook-config.yaml`
and `reserved-domains.md` (FM-16 done), fixed A3 (the index) and A2 (concurrent, 5 s per call),
reported per-call timeouts to the sink (A1's per-call half; its fan-out overrun stayed log-only), and
moved the canary after the lookup — but left `CANARY_URL` on `example.com`, deferring it as a
question for Platform. D, O, K, C and P1 pass; **R1-R4 fail**. It noticed both the canary's position
and its reserved target, and its summary still presented the health check as meaningful. This is the
ticket claimed to bite a real cold agent: three and a half axes do not close the incident.

---

## FM-15 — context rot (every drift item; detail in `doc-drift-ledger.md`)

| # | Location | Claim | Truth |
|---|---|---|---|
| D1 | `backend/README.md:8-10` | issuers are `did:key`, no lookup, no network | `did:web`, fetched; the registry must be asked — two migrations stale (the headline) |
| D2 | `backend/src/store.rs:68-70` | issuer documents are "self-contained, as with the peer DIDs" | did:web documents rotate; moved here from the verifier during the build, wording unchanged |
| D3 | `backend/README.md:23` | expiry field `expirationDate` | `expires_at` (`issuer.rs:132`, `verifier.rs:165`) |
| D4 | `backend/README.md:32-33` | credentials are single-use | not enforced; not the design (`feature-qa.md` Q6) |
| D5 | `backend/README.md:38-42` | notifications "delivered concurrently to every subscriber, with failed deliveries retried" | sequential, no retry; `maximum_retry_attempts: 0` |
| D6 | `app/README.md:8-10` | the wallet holds JWT-VCs | JSON-LD VCs with a Data Integrity proof, `ldp_vc` |
| D7 | `backend/src/resolver.rs:78-81` | the `did_web_url` comment describes the planted mapping as intended | §3.2 (T1.2) |

The stale no-doc-trace path is T1.1. **Verified to bite:** the stale path is what every Ticket 1 row
above measures (shipped 6/26); a doc-trusting fix aimed at `did:key` never touches it. The recorded
runs did not fall for the READMEs — each corrected the lines it touched (see the ledger).

## FM-16 — cross-boundary (detail in `context-map.md`)

Truth that lives only in `reference/`: the rotated keys and moved endpoint (`infra/hosted-dids/`),
"resolve the current document" and the path mapping (`did-web-method.md` §3.2-§4, `infra/did-hosting.md`),
the registry rule (`trust-registry.md`), the 10 s hard kill, zero retries, empty alarms and the
tenant-kind index (`infra/webhook-config.yaml`), the reserved-name rule (`infra/reserved-domains.md`).
Axis (a)'s V and W cases and axis (a2)'s budget and R cases are derived from these files at grade
time. **Measured:** both cold ticket runs opened `reference/` unprompted (Ticket 1 read the method spec
on call 6, Ticket 2 the notifier config on call 3); the Ticket 1 run converged (26/26), the Ticket 2 run read the reserved-name rule and still
left the canary on a reserved name (13/17). A fix limited to what the local repo shows scores 17/26 on
Ticket 1 (above).

---

## Feature trap (phase 3) — FM-03, read-before-delegate

**Lure** (`FEATURE-REQUEST.md:3`): "The wallet already holds the issuer-signed credential, so this is
mostly packaging it up and handing it to the scanner — it should be a small one." It leans the build
toward wrapping the stored credential with all its disclosures: "already issuer-signed" suggests no
holder proof, "packaging it up" suggests passing every disclosure (the birth date leaks), "handing it
to the scanner" suggests nothing ties the presentation to this request. No ⚠️ hint. Stub:
`app/lib/src/wallet_service.dart:52-57` (`throw UnimplementedError`). Held-back answers:
`feature-qa.md` (8 questions, with owners); reference build: `FEATURE-FIX.md` + `feature-reference/`.

**Axis (b) cases** (7): four wallet `feature:` cases — discloses exactly the DCQL-requested claims;
signed by the holder's key; bound to the request's nonce and domain; an expired credential refused —
and three `xstack:` cases in which the backend's own `Verifier` accepts the wallet's presentation and
rejects a tampered value and a replay to another nonce or domain (each rejection counts only after
the untouched presentation was accepted).

**VERIFIED — the paired measurement** (fresh executors on a clone with Ticket 1 fixed, the feature
request staged):

| Build | axis (b) | Failed |
|---|---|---|
| shipped stub | FAIL 0/7 | all |
| a holder-signed wrap-all self-check build (ignores the query, the nonce and the domain) | FAIL 1/7 | all but the holder signature |
| **naive** — the brief handed over raw, one prompt | **FAIL 6/7** | `feature: an expired credential is refused` |
| **elicited** — the same executor briefed with the held-back answers (**operator-supplied; a calibration run**, AGENTS.md rule 10) | **PASS 7/7** | — |
| reference elicited build (`feature-reference/`) | **PASS 7/7** | — |

The naive build got the subset, the holder proof and the binding right (it read the verifier first,
on its 4th tool call) and missed only the expiry refusal — the one rule nothing in the request or the
verifier's call site states. Both runs read `backend/src/verifier.rs` before building. The trap
discriminates, narrowly: the gap between naive and elicited is one rule.

---

## FM-14 — review (trained by phase 5, not planted in code)

Phase 5 asks for a review of the learner's own diff as a teammate's PR. Defeated by triage (the
resolver root and the notifier's canary logic need scrutiny; README fixes can be skimmed) anchored on
the tickets' promises, a named weakness, and a human decision on what ships now. The A4 tell — the
canary registered first and pointed at a reserved name — is the review-phase evidence that a learner
read what the health check actually vouches for. Scored on `rubric.md`'s driving axis.

---

## Ranked latent defects (planted; phase 4)

`practice.json.latentDefects` is **7**: the numbered instances below. None is exercised by the
visible suites, and none is needed for any gate case (the graders use a nonce/domain mismatch for
replay, stay off the exact expiry instant, use indexes a real issuance returns, and grade only
registry-active issuers), so the tickets and the feature reach 50/50 with every one still present.
The Ticket 2 axes are a graded cluster and are not re-counted here; the FM-05 and FM-03 items below are
distinct instances in other modules.

1. **FM-06 — replay guard keyed on the transport id.** `backend/src/verifier.rs:111`:
   `first_use(&submission.request_id)`. The same presentation resubmitted with a fresh `request_id`
   is accepted (nonce and domain are still checked, so it must be replayed to the same request).
2. **FM-05 — the wallet store hands out held state by reference.** `app/lib/src/credential_store.dart`:
   `save` keeps the caller's object (`:8-9`); `byId` returns the stored instance (`:11`); `all()`
   wraps the stored instances in `List.unmodifiable`, which freezes the list but not its elements
   (`:13`); `holderKey` is a public, replaceable field — the key handle itself (`:15`).
   `HeldCredential.vc` and `.disclosures` are mutable, so `wallet.credential(id)!.disclosures.clear()`
   changes what the wallet holds. One defect in one class; its four sites are listed so an examiner
   credits any of them. Robustness probes W1 and W2 catch it (both the shipped tree and the reference
   build fail them).
3. **FM-07 — the replay guard grows without bound.** `backend/src/verifier.rs:73-81`:
   `ReplayGuard.seen_nonces` (keyed on request ids, #1) is never pruned.
4. **FM-04 — the expiry and not-before instants.** `backend/src/verifier.rs:166-171`: `now < not_before`
   / `now > expires_at`, so a credential is still accepted at exactly `expires_at`. The boundary is
   unspecified and untested. It also shows up across the stack: the reference wallet refuses at
   `now >= expires_at` while the backend accepts at that instant, and the elicited feature run chose
   the opposite side ("a credential still works in its final second, matching the verifier"). No probe
   pins it; credit a learner who notices the two sides disagree and asks who owns the rule.
5. **FM-03 — status-list index off by one.** `backend/src/status.rs:35-41`: `allocate` pre-increments,
   so indexes run 1..=capacity; bit 0 is never used and the last index is outside the bitstring, where
   `set` silently does nothing — that credential can never be revoked. Robustness probe S1 catches it
   on a 16-bit list (index 16).
6. **FM-08 — no trust-registry check.** `backend/src/verifier.rs:155-161`, `verify_credential`: any
   issuer whose DID resolves and whose signature verifies is accepted (a self-issued `did:key` issuer
   included). `reference/trust-registry.md` requires a live registry query and forbids a local list.
7. **FM-03 — unknown proof types and DID methods fall through to "valid".** `backend/src/verifier.rs:208`
   (`check_proof` verifies only when `proof.type` is `Ed25519Signature2020`; any other type is not
   checked at all, for issuer and holder proofs alike) and `:122-126` (a holder DID on an unsupported
   method skips the holder-proof check).

**Found by the recorded runs, unprompted:** #7 (Ticket 1 cold run, naive and elicited feature runs —
all three flagged the proof-type skip as serious), #6 (Ticket 1 cold run; the naive feature run
as "approved-issuer list not used"), #1 (Ticket 1 cold run, elicited feature run). Each run left them
unfixed and named them as follow-ups: the restraint the rubric credits.

Not planted: DESIGN-era candidate #8 (canonicalization keyed on map iteration order). The backend's JCS
is correct cross-stack.

---

## Robustness probes — what the frozen gate cannot see

`bash _solutions/robustness-probes.sh` (never called by `grade.sh`; non-blocking) prints one line per
probe and `robustness n/9`. Each expectation was captured from real builds on 2026-09-27:

| Probe | Vector | Shipped tree | Reference build |
|---|---|---|---|
| W1 | held state by reference: a credential read with `credential(id)` | FAIL | FAIL |
| W2 | held state by reference: an element of `heldCredentials()` | FAIL | FAIL |
| W3 | the presentation shares no state with the held credential, either direction | FAIL (stub) | PASS |
| G1 | holder binding guarded on the presentation, not only in `requestCredential` | FAIL (stub) | PASS |
| D1 | a DCQL query that names no claim discloses nothing, still signed and bound | FAIL (stub) | PASS |
| D2 | a query for a claim the credential lacks is refused, not half-answered | FAIL (stub) | PASS |
| N1 | a tenant with zero subscriptions: finishes, no failure, canary healthy | PASS | PASS |
| N2 | the reserved-name rule holds for a tenant subscription, not only the canary's URL | FAIL | FAIL |
| S1 | every status-list index handed out can be revoked (latent #5) | FAIL | FAIL |
| | | **robustness 1/9** | **robustness 5/9** |

Every probe is passable: the reference build plus a copy-on-read/write store, an `allocate` that
starts at index 0, and a reserved-name refusal in `Notifier::dispatch` scores **robustness 9/9**. W1,
W2 and S1 are planted latents (#2, #5); N2 is a limitation of the reference Ticket 2 fix (below);
W3, G1, D1 and D2 are what a feature build can get wrong while passing the gate.

---

## Emergent findings — real, but NOT planted (do not count toward `latentDefects`)

Surfaced by the recorded runs. Credit a learner who finds one; do not treat it as a designed trap.

- **The wallet's test fixture has drifted from what the backend issues.** `app/test/fixtures.dart`
  builds a VC Data Model 2.0 credential with `validFrom`/`validUntil` and a `DataIntegrityProof`
  (`eddsa-jcs-2022`) with a placeholder signature; the backend issues the v1 context, `expires_at`
  and `Ed25519Signature2020`. A wallet built and tested against the fixture alone reads fields the
  real issuer never writes. The elicited run replaced it with a backend-issued credential.
- **What a DCQL query with no `claims` asks for is a real question.** The naive run read OpenID4VP
  as "send every claim" and chose to send none for want of a consent screen; the elicited run and the
  reference build disclose none. Credit a learner who routes it to the Verifier team rather than
  guessing. Probe D1 follows the reference reading (and `FEATURE-FIX.md`).
- **The Ticket 2 support statements were false before the fix.** The Ticket 2 cold run pointed out
  that two of the "what support has confirmed" promises did not hold, and that the league's missed
  revocations are not re-sent by the fix. Both are true and neither is graded.

## Known limitations of the reference fixes (the grader is blind to each)

- **Ticket 1 — retired-key credentials are now refused.** Correct per the spec and asserted by the
  grader, but members holding in-date credentials signed before their club rotated are turned away
  until re-issued. The Ticket 1 cold run raised it before deploying; the reference fix is silent.
- **Ticket 2 — the fan-out overrun event fires at the runtime's own kill time.** `DISPATCH_BUDGET`
  stays 10 s, equal to `function.timeout_seconds`, so in production the `*` overrun event races the
  hard kill and may never be recorded. The per-call timeout (5 s) is what makes a hang observable.
  The cold run set its budget to 8 s for this reason. The grader imposes the budget from outside
  under a paused clock and cannot see the race.
- **Ticket 2 — the reserved-name rule is enforced at one entry point.** The fix moves the canary off
  `example.com` but would still call a tenant subscription registered at a reserved name, which
  `reserved-domains.md` forbids for every outbound call. Probe N2 fails on the reference build.
- **Ticket 2 — no retries, no re-send.** `maximum_retry_attempts: 0` and no failure destination: a
  relying party briefly down misses the change until the next status-list refresh. A platform
  decision beyond the ticket; a good run names it.
- **Feature — the wallet and the verifier disagree at the expiry instant** (latent #4): the reference
  wallet refuses at `now >= expires_at`, the backend verifier accepts at `now == expires_at`.
  `FEATURE-FIX.md` does not note it. The gate stays off the instant.
- **Feature — the store is still by reference** (latent #2): the reference feature build deep-copies
  what it puts into a presentation (probe W3 passes) but leaves the store as shipped (W1, W2 fail).
  Deliberate: #2 is a phase-4 finding.
