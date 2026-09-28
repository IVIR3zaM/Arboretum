# N16 — fresh-context review of practices/credentials (cedar@1.2.0, XL)

Reviewer: a fresh context (N16 try 1 after the N22 replan), 2026-09-28. I read the practice the way
a briefed learner would: `practices/credentials/README.md` plus the clone-visible tree. That tree
is every git-shippable file except `_solutions/`, `README.md` and `practice.json`, which is 60
files (`git ls-files --cached --others --exclude-standard`). I opened `_solutions/` only to size the
fixes (`reference-fix/*.patch`, `feature-reference/`) and to locate the planted lines
(`trap-manifest.md`). I did not rely on the previous review. Every number below was re-measured.

Plan verify (`bash .plan/2026-09-27-credentials-practice-cloud-build/scripts/verify.sh`): **exit 0**.
The backend and wallet suites were green, the jail cases were ok, the cold tests and the portable
test passed, and the leak guard passed.

## Verdict

**Solvable at XL in the stated time (165 min, practice.json `estimate.minutes`).**

- **Invariant 12:** clean. No clone-visible file coaches (see C3).
- **Size:** above the XL row on two counts.
  - Source file count is 19 against the row's 10-14.
  - Physical source LOC is 1,877 against ~1,200-1,600. Code-only LOC is 1,453, which is inside the
    band.
- **Why that is not over-scope:**
  - Four of the 19 files are boilerplate of at most 22 lines: `lib.rs` 22, `credentials_app.dart`
    11, `credential_store.dart` 16 and `issuer_client.dart` 10.
  - The Ticket 2 modules (`notifier.rs`, `settings.rs`, `webhook.rs`, 425 LOC) are the second
    staged ticket. The estimate already prices that ticket at +30 min over the tier's 135.
  - Without those modules the practice is 16 files and ~1,450 physical LOC, which fits the row.
- **Phase changes:** every phase's required change is small and local (see C2). This matches
  invariant 7's "complex in the fog, not in the fix".

No over-scope needs the D17 fallback, so the cross-stack check stays graded.

## C1 — each discipline, and where a learner reaches it (no `_solutions/` needed)

The table covers the ten disciplines in `practice.json` → `trainingPoints.disciplines`.

| Discipline | Phase | Where the learner meets it (file / artefact) |
|---|---|---|
| reproduce-before-fix | 2 | `TICKET-1.md` and `TICKET-2.md`: "Nobody on the team can make it happen on their own machine, and the test suite is green". That sits against a green `backend/tests/` suite. The learner's artefact is a failing test in `backend/tests/verifier.rs` (the suite verifies only Harbour Club, `tests/common/mod.rs:3-5`) or in `backend/tests/notifier.rs` (the `small_tenant` fixture at `:26-39`: 12 settings, 3 healthy subscribers). |
| requirements-elicitation | 3 | `FEATURE-REQUEST.md` ("mostly packaging it up … a small one"; "the PM is reachable if you need more"), against the stub at `app/lib/src/wallet_service.dart:66-73`. The artefact is the learner's questions to the PM. |
| read-before-delegate | 1, 3 | Phase 1: map `backend/src/*` and `app/lib/src/*`. Phase 3: read `backend/src/verifier.rs:103-152` `verify_presentation` (nonce, domain, holder proof, `_sd` disclosures) and `app/lib/src/presentation_request.dart` (DCQL query, `domain` = `client_id`) before building the holder side. |
| model-before-delegation | 2 (T1) | The issuer-key decision path. `backend/src/verifier.rs:196-202` `resolve_issuer` goes to `backend/src/store.rs:68-73` `onboarded_issuer` and `backend/data/onboarded-issuers.json`. The alternatives are `resolver.rs` `resolve_web` / `did_web_url` (`:78-101`) and `reference/infra/hosted-dids/`. |
| comprehension-as-ownership | 2, 5 | Explaining why only the re-approved clubs fail: the onboarding snapshot against the rotated hosted `did.json` for Cedar Rowing, Northfield and Kestrel, plus the path-DID mapping. Then owning the whole diff in the phase-5 review. |
| verify-output | 2 (T2), 4 | `backend/src/notifier.rs:129-146`: `canary_healthy` is set from the first call, whose target is `CANARY_URL` (`:29`, example.com). `backend/src/webhook.rs:60-88`: the in-process transport always answers the canary host. So the health check is green but proves nothing (`TICKET-2.md`: "A green health check means callbacks are reaching customers"). In phase 4 the learner checks the assistant's "find, not recite" list against the code. |
| restraint-altitude-match | 3, 4 | The smallest correct `createPresentation` in `app/lib/src/wallet_service.dart`, and phase 4's fix-in-scope / defer-out-loud across 7 latent issues (e.g. `verifier.rs:111`, `status.rs:35-41`, `credential_store.dart:8-15`). |
| reject-on-camera | 5 | The whole-diff review (README phase 5). The artefact is the transcript. |
| establish-cross-boundary-context | 1 (research pass), 2 | The learner distills `reference/` into `research-notes.md` in the clone. Sources: `did-web-method.md` §3.2 steps 4-5 and examples, §3.3, §4; `infra/did-hosting.md` object keys; `infra/hosted-dids/*/did.json`; `infra/webhook-config.yaml` (`timeout_seconds: 10` hard limit, `maximum_retry_attempts: 0`, `tenant-kind-index`, `alarms: []`); `infra/reserved-domains.md`; `trust-registry.md`. |
| reconcile-docs | 1 | `backend/README.md:8-11` (did:key), `:23` (`expirationDate`, but the code uses `expires_at`), `:32-33` (single-use), `:40-42` ("concurrently … retried"); `app/README.md:8-10` (JWT-VCs, but the fixtures and `held_credential.dart` hold JSON-LD); the `backend/src/store.rs:68-70` comment; the `backend/src/resolver.rs:78-81` comment against spec §3.2. |

All ten can be reached from the briefing and the clone alone.

## C2 — measured size

Tools:
- `wc -l` for physical lines.
- A python classifier (blank / `//`-or-`/* */`-comment / code) for code-only lines.
- `git apply --numstat` for the patches.
- `diff` for `feature-reference/`.

### Source, by package (tests excluded)

| Package | Files | Physical LOC | Code | Comment | Blank |
|---|---|---|---|---|---|
| `backend/src` (Rust) | 11 | 1,561 | 1,208 | 166 | 187 |
| `app/lib` (Dart) | 8 | 316 | 245 | 22 | 49 |
| **Source total** | **19** | **1,877** | **1,453** | 188 | 236 |

Per file:
- `backend/src`: credential 148, issuer 152, lib 22, notifier 182, resolver 238, settings 114,
  status 103, store 117, transport 100, verifier 256, webhook 129.
- `app/lib`: credentials_app 11, credential_list 68, credential_store 16, held_credential 74,
  holder_key 30, issuer_client 10, presentation_request 49, wallet_service 58.

### Tests, shown separately

| Package | Files | Physical LOC | Code |
|---|---|---|---|
| `backend/tests` | 10 | 999 | 833 |
| `app/test` | 7 | 304 | 255 |

### Changed lines per phase (reference fixes)

| Change | Files | +/− (all lines) | +/− code only |
|---|---|---|---|
| `_solutions/reference-fix/ticket-1.patch` | `backend/src/resolver.rs` +10/−10, `backend/src/verifier.rs` +5/−3 | **+15 / −13** | +5 / −10 |
| `_solutions/reference-fix/ticket-2.patch` | `backend/src/notifier.rs` +50/−21 | **+50 / −21** | +35 / −20 |
| `_solutions/feature-reference/` | `app/lib/src/wallet_service.dart` +70/−1; new `app/lib/src/dcql_selection.dart` 91 (77 code) | **+161 / −1** | +131 / −1 |

Both patches pass `git apply --check` against a copy of the shipped `backend/`.

### Comparison with the XL row and the estimate

The XL row (`context/cedar/generation-spec.md:184`) is 10-14 source files, ~1,200-1,600 LOC, all
five phases plus a research pass, `reference/` and a dual grade, ~135 min.

- **Files: 19, above the row by 5.** Four files are at most 22 lines of wiring or boilerplate.
  Three files (notifier, settings, webhook) exist for the second ticket. Without the second
  ticket's modules the count is 16, which is still 2 over. Those two are the trivial
  `issuer_client.dart` / `credentials_app.dart`. This is a real but cosmetic deviation, with no
  reading cost to speak of.
- **LOC: physical 1,877 is above the band by ~17%. Code-only 1,453 is inside it.** Most of the
  excess is the Ticket 2 subsystem (425 physical LOC).
- **Time: practice.json says 165 = the tier's 135 + 30 for the second staged ticket.** This follows
  the spec's method: understand 30 · fix 25 · feature 30 · improve 20 · review 15 · slack 15, plus
  Ticket 2 at 30.
- **Tokens: 1,877 × 10 × 2.5 = 46,925, plus 20 rounds × 1,500 = 30,000, so ~77k.** This matches my
  measured physical LOC exactly.

Every phase's required change is small, so invariant 7 holds:

- **Ticket 1:** 28 changed lines in 2 functions. One is the early return in
  `Verifier::resolve_issuer`; the other is the `/.well-known` placement in `did_web_url`. It fits
  25 min once the model is built.
- **Ticket 2:** 71 changed lines, all in one function body in `notifier.rs`. The four axes are
  a per-call timeout plus a surfaced timeout, concurrent dispatch, `query_kind` instead of the
  paged scan (that API already exists at `settings.rs:99-111`), and the canary target and order.
  This is the largest bug diff, but it is local, and the ticket has its own 30 min.
- **Feature:** ~130 code lines, and most of the work is done by the pinned packages: `ssi`
  (`JcsUtil`, `HolderKey.sign`, `keyId` already in `holder_key.dart`) and `dcql` (query evaluation).
  The reference's separate 91-line selection helper is one way to do it, not a requirement. A
  simpler selection over `HeldCredential.disclosures` would meet the same surface. This is
  reachable in 30 min once the PM's answers are in hand. The practice.json `featureTrap` records a
  raw-brief build reaching 6/7, so the build itself is not the bottleneck; elicitation is.
- **Improve:** 7 seeded issues, each a one- to few-line local fix (e.g. `status.rs:39-40`,
  `verifier.rs:111`, `verifier.rs:169`). "Fix in scope, defer the rest" bounds the phase at 20 min.
- **Review:** no code change.

The fog is real, but it sits in the understand phase and is reading, not building. The learner
must read ~1,450 code LOC across two languages, plus ~190 lines of `reference/` prose and 4 hosted
documents, in 30 + 15 slack min. That is tight but achievable when the assistant does the reading
and the learner directs it.

## C3 — invariant 12, file by file

The rule (generation-spec.md:120-150): tickets state a symptom and the promised rule, with no
method and no mechanism. The feature request gives the ask and the surface, with no trap warning.
Comments state intent and contract, may leave evidence, and never narrate the defect or confess a
blind spot. Nothing refers to a grader. Drifting docs mislead without hedging. `reference/` reads
as a vendor snapshot. Citing a source is fine; interpreting it is not.

### Clone-visible prose files

| File | Verdict | Why |
|---|---|---|
| `TICKET-1.md` | OK — no leak | A customer symptom ("re-approved last month gets rejected"), the rule as promised ("in date and not revoked, is accepted … still holds after a club has been re-approved"), and "not just the clubs that complained". It gives no method, names no file, and says nothing of DID methods, snapshots or `reference/`. "Nobody … can make it happen on their own machine, and the test suite is green" is a symptom statement, required by the template (FILES.md:69-70). |
| `TICKET-2.md` | OK — no leak | A symptom (green health check; the account "with a lot of settings" gets nothing; revoked members still admitted). The rule is stated as promised ("whatever the size … however any one relying party's endpoint is behaving"; "A green health check means callbacks are reaching customers"). These are customer-visible facts and the stated promise. They name no mechanism: they do not mention timeouts, sequential loops, the index, example.com or reserved names. The ticket gives no method and never mentions a grader. |
| `FEATURE-REQUEST.md` | OK — no leak | The PM's ask, the lure ("mostly packaging it up … a small one"), "the PM is reachable", and the expected surface `WalletService.createPresentation(credentialId, request)`. It gives no warning and does not mention subset, holder proof, nonce or expiry. |
| `backend/README.md` | OK — no leak (drift misleads, no hedge) | It states did:key (`:8-11`), `expirationDate` (`:23`), single-use (`:32-33`) and concurrent delivery with retries (`:40-42`) as plain fact, with no "may be out of date" and no TODO. It is a believable stale README. |
| `app/README.md` | OK — no leak (drift misleads) | "Credentials are JWT-VCs" (`:8-10`) is stated flatly. No hedge. |
| `reference/README.md` | OK — no leak | It says what the directory is ("vendor snapshot … synced from them") and that it is read-only, and gives a contents table. It gives no instruction to study, distill or compare, and does not say the local repo disagrees. |
| `reference/did-web-method.md` | OK — no leak | The method stated as a spec states it: §3.2 mapping and examples, §3.3 "the document currently served … is the DID document", §4 verification against the current document, §5. The "Unlike `did:key` and `did:peer`" line is ordinary spec comparison (it mirrors the W3C text). It never points at the local implementation. |
| `reference/trust-registry.md` | OK — no leak | A service contract (TRQP, `POST /authorization`, the "MUST NOT keep their own list" invariant, a records export). It makes no mention of this repo's verifier. |
| `reference/infra/did-hosting.md` | OK — no leak | A bucket and distribution config table, object keys for root and path DIDs, and rotation semantics. It reads as ops docs. |
| `reference/infra/reserved-domains.md` | OK — no leak | A platform standard (PI-STD-014): the rule, the RFC 2606 names, what to use instead, and enforcement. It never names the notifier or its canary. |
| `reference/infra/webhook-config.yaml` (comments) | OK — no leak | Deploy-config comments ("Hard limit. The runtime terminates the invocation …", "this service never writes settings"). They are factual config commentary, with no reference to local code. |
| `reference/infra/hosted-dids/*/did.json` (4) | OK — data | DID documents only. |
| `backend/data/onboarded-issuers.json` | OK — data | Onboarding records with snapshot documents. It carries no comments. |
| `.gitignore` | OK — no leak | Build-output comments. "Lockfiles ARE committed (D9)" carries a bare decision label from the build. It reads as an internal ADR number and says nothing about the exercise, its traps or a grader. It is neutral, not coaching. |
| `app/.metadata`, `app/analysis_options.yaml`, `backend/rust-toolchain.toml` | OK | Stock Flutter/Rust tool boilerplate. |

### Package manifest name and description fields

| Manifest | Fields | Verdict |
|---|---|---|
| `app/pubspec.yaml` | `name: credentials_app`, `description: "Credentials wallet app skeleton."` | OK. "skeleton" describes an early-stage app and does not hint at an exercise or a trap. There is no `grade` script (Dart manifests have none). |
| `backend/Cargo.toml` | `name = "credentials-backend"`. There is no `description` field. | OK. There is no grade bin or `[[bin]]` target and no reference to one. |

### Comment blocks near the planted paths (Ticket 1, Ticket 2, feature, latents)

| Location | Comment (gist) | Verdict |
|---|---|---|
| `backend/src/verifier.rs:196` (T1.1 `resolve_issuer`) | "The DID document an issuer's credentials are checked against." | OK — intent only. The early return at 198-200 has no comment at all, so nothing narrates the snapshot. |
| `backend/src/store.rs:68-70` (`onboarded_issuer`, T1.1's source) | "Issuer documents are self-contained, as with the peer DIDs issuers first onboarded with … the copy recorded at onboarding is all verification needs." | OK — the FM-15 drift. It is written as a belief, without a hedge, so it misleads rather than confesses. |
| `backend/src/store.rs:13`, `:50` | "An issuer approved to issue …", "A store holding every issuer in data/…" | OK — contract. |
| `backend/src/resolver.rs:1-10` (module doc) | Methods the service has used, oldest first (did:key → did:peer:0 → did:peer:2 → did:web, "fetched through a DocumentTransport"). | OK — history as evidence. It does not say anything is wrong. |
| `backend/src/resolver.rs:78-81` (T1.2 `did_web_url`) | "did.json under the host's /.well-known/ directory, with any further segments … as subdirectories." | OK — describes the local (wrong) design as intent. It neither cites nor contradicts §3.2 and does not hedge. |
| `backend/src/transport.rs:1-6`, `:29-31`, `:42` | "published to the document bucket … (see reference/infra/hosted-dids/)"; the mirror is laid out as the bucket keys its objects. | OK — this is citing, which is explicitly allowed (a pointer to external truth). It does not interpret the source. |
| `backend/src/notifier.rs:1-10` (module doc) | What the notifier does; "The canary is a platform subscription … canary_healthy is the notifier's health check". | OK — contract. |
| `backend/src/notifier.rs:22` (A1 `DISPATCH_BUDGET`) | "How long one status change may take to fan out." | OK — intent. It says nothing about log-only expiry or the config's hard kill. |
| `backend/src/notifier.rs:28-29` (A4 `CANARY_URL`) | No comment. | OK. |
| `backend/src/notifier.rs:107`, `:123`, `:129`, `:134-135`, `:157`, `:171` | "Subscribers to every tenant's changes", "Whether the canary acknowledged the most recent change", "Sends change to the platform subscribers and to every subscriber of the issuing tenant", "The tenant's webhook subscriptions", "POSTs body … true if delivered". | OK — contract. Nothing narrates the sequential loop, the scan or the canary ordering. |
| `backend/src/settings.rs:1-7`, `:16`, `:19`, `:79`, `:99` (A3 cost model) | "every page read takes PAGE_READ_LATENCY. The tenant-kind index answers 'settings of this kind for this tenant' directly"; "What one page read costs"; "…through the tenant-kind index". | OK — evidence a careful reader needs, stated as API contract. It does not say the notifier should use the index. |
| `backend/src/webhook.rs:1-5`, `:60-63` (A4 test double) | "HermeticTransport … The canary's host is answered by a local stub that acknowledges every call." | OK — describes the test double's contract (evidence). It does not say that this keeps the health check green or hides anything. |
| `backend/src/verifier.rs:46-52` (latent #1) | "Set by the scanner's transport for each upload." (`request_id`) | OK — evidence, not narration. |
| `backend/src/verifier.rs:103`, `:154` (latent #4 window) | "Verifies a presentation against the nonce and domain …", "Verifies a credential: issuer proof, validity window and status." | OK. |
| `backend/src/verifier.rs:205` (latent #7 `check_proof`) | "Checks document's proof against a key signer lists under relationship." | OK — intent. It does not confess the unknown-type fall-through. |
| `backend/src/status.rs:1-6`, `:14-15`, `:34` (latent #5 `allocate`) | "Bit 0 is the most significant bit …", "Reserves the next unused index". | OK — states the contract that the code violates. No narration. |
| `app/lib/src/credential_store.dart:4` (latent #2) | "In-memory wallet storage: held credentials by id, and the holder key." | OK. |
| `app/lib/src/wallet_service.dart:50-51` (feature stub) | "Builds a presentation of the held credential [credentialId] in answer to [request], ready to send to the requester." | OK — the surface. No requirement list and no warning. |
| `app/lib/src/presentation_request.dart:3-4`, `:40` | "OpenID4VP shape … a nonce, and a DCQL query", "The domain a presentation … is addressed to." | OK — contract (evidence for the feature). |
| `backend/src/credential.rs:1-6`, `:77-81`; `backend/src/lib.rs:1-11`; `backend/src/issuer.rs:*`; `app/lib/**` other docs | Wire format / JCS / module map / field docs. | OK — contract. |

### Test-file header comments

| Test file | Header comment | Verdict |
|---|---|---|
| `backend/tests/common/mod.rs` | "Shared fixtures for the backend suite. Harbour Club is the issuer these tests sign with …; Holders are generated per test from a fixed seed byte." | OK — it describes the fixture. It is evidence that only one issuer is exercised, but it does not confess a blind spot. |
| `backend/tests/did_document.rs` | "Smoke test: builds a DID Document type … no resolver behaviour is exercised here, and nothing touches the network." | OK — describes scope. |
| `app/test/smoke_test.dart` | "Smoke test: imports the pinned Affinidi packages ssi and dcql … No did:web resolution, no I/O." | OK — describes scope. |
| `backend/tests/{credential,issuer,notifier,resolver,settings,status,store,verifier}.rs` | No header comment. | OK. The in-file `notifier.rs:26-27` fixture doc ("A tenant as most clubs look: a handful of preferences and a few relying parties") describes the fixture and does not confess. `resolver.rs` has only section dividers (`// --- did:web ---`). |
| `app/test/{credential_list,credential_store,holder_key,wallet_service}_test.dart`, `fake_issuer_client.dart`, `fixtures.dart` | No header comment. Item docs only ("Seed of the holder key …", "A door-scanner request, shaped like an OpenID4VP authorization request"). | OK. |

### My own grep over all 60 clone-visible files

Command:

```
git ls-files --cached --others --exclude-standard . | grep -v '^_solutions/' | grep -vx README.md | grep -vx practice.json \
  | xargs grep -nIE '<pattern>'
```

| Pattern | Hits | Judgement |
|---|---|---|
| `\b(FM\|BP)-[0-9]+\b` | **0** | — |
| Context tree names (`ls context/` → `alder`, `cedar`), case-insensitive, as substrings | `alder` **0**; `cedar` **20 lines in 4 files**: `backend/data/onboarded-issuers.json` (9: `"name": "Cedar Rowing Association"` plus 8 `did:web:issuer.cedarrowing.example…` / `https://cedarrowing.example/`); `reference/infra/hosted-dids/issuer.cedarrowing.example/.well-known/did.json` (7, DID/key ids and its path); `reference/trust-registry.md:72` (the Cedar Rowing registry row); `backend/tests/notifier.rs:10,90,94` (`const CEDAR`, `let cedar`, `gate.cedarrowing.example`) | **Not a leak.** Every hit is the fictional customer "Cedar Rowing Association" and its domain. It is a proper noun in the business data, next to Harbour Club, Northfield Guild and Kestrel League. None of it names the Context version, a tier, a practice, or anything about the exercise. The plan's leak guard (label form `cedar practice/context/tier`, `cedar@`) correctly does not fire. |
| `failure[ -]?mode\|best[ -]?practice\|kata\|learner\|examiner\|trap\|planted\|golden\|arboretum` (case-insensitive) | **0** | — |
| Extra sweep: `grader\|\bgrade\b\|_solutions\|rubric\|hint\|coach\|exercise\|practice\.json\|research-notes\|oracle\|hidden` | 2: `app/test/smoke_test.dart:2` "exercises one offline … call"; `backend/tests/did_document.rs:4` "no resolver behaviour is exercised here" | **Not a leak.** The English verb "exercise" (a test exercises code). Nothing mentions a grader, `_solutions`, a rubric, research notes or a hidden gate. |

Build caches: the gitignored `app/.dart_tool/`, `app/build/` and `backend/target/` sit in the working
tree and would be copied by a `cp -R` clone. A grep of them for the exercise words, `_solutions` and
`arboretum` returned nothing.

**C3 result: no verdict is a leak.**

## C4 — solvability verdict

**Solvable at XL in the stated time (165 min).** The size deviation is on file count (19 against
10-14) and physical LOC (1,877 against ~1,600). It comes from four boilerplate files and the
second-ticket subsystem that the estimate prices at +30 min. Code-only LOC is in the band, and
every phase's required change is small and local. There is no over-scope, so the D17 fallback
(demoting the cross-stack check to test level) is **not** needed. The feature cases and the
cross-stack cases stay graded.

## C5 — plan verify

`bash .plan/2026-09-27-credentials-practice-cloud-build/scripts/verify.sh` → exit 0 (run by this
reviewer, 2026-09-28).
