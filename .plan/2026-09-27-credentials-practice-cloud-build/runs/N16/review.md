# N16 — fresh-context review of practices/credentials (cedar@1.2.0, XL)

Reviewer: fresh context, read as a briefed learner (practices/credentials/README.md + the
clone-visible tree = every git-shippable file except `_solutions/`, `README.md`, `practice.json`;
60 files, list from `git ls-files --cached --others --exclude-standard`). `_solutions/` was opened
only to size the fixes (reference-fix patches, feature-reference) and to locate the planted lines.
Date 2026-09-28. Plan verify (`bash .plan/.../scripts/verify.sh`): exit 0.

## Verdict

**Solvable at XL in the stated time (165 min, per practice.json) — but NOT clean on invariant 12:
one leak (L1 below).** Size deviates from the XL row on file count (19 vs 10-14) and physical LOC
(1,877 vs ~1,200-1,600); code-only LOC (1,451) is inside the band, four of the 19 files are <=22
lines of boilerplate, and every phase's required change is small. No over-scope that the D17
fallback (demote the cross-stack check) would need to address; the fallback is not recommended.

## C1 — disciplines -> where a learner reaches them (no `_solutions/` needed)

| Discipline (practice.json) | Phase | Where (file / artefact) |
|---|---|---|
| reproduce-before-fix | 2 | `TICKET-1.md` ("nobody can make it happen on their own machine, and the test suite is green") and `TICKET-2.md` (same), against a green `backend/tests/` suite; the learner's failing test in `backend/tests/verifier.rs` / `backend/tests/notifier.rs` (the latter's `small_tenant` fixture shows only small, healthy tenants are exercised) |
| requirements-elicitation | 3 | `FEATURE-REQUEST.md` ("That's the whole brief — and the PM is reachable"), stub `app/lib/src/wallet_service.dart:50-57` |
| read-before-delegate | 1, 3 | phase 1 map of `backend/src/*` and `app/lib/src/*`; phase 3 reading `backend/src/verifier.rs` `verify_presentation` (nonce/domain, holder proof, disclosures) before building the holder side |
| model-before-delegation | 2 (T1) | the issuer-key decision path: `backend/src/verifier.rs:196-202` `resolve_issuer` -> `backend/src/store.rs:68-73` `onboarded_issuer` + `backend/data/onboarded-issuers.json` vs `backend/src/resolver.rs:78-101` `did_web_url` and `reference/infra/hosted-dids/` |
| comprehension-as-ownership | 2, 5 | explaining why the re-approved batch fails (onboarding snapshot vs hosted, rotated `did.json`; path-DID mapping) before accepting a fix; phase 5 review of own diff |
| verify-output | 2 (T2), 4 | `backend/src/notifier.rs` `canary_healthy` + `backend/src/webhook.rs:60-88` (HermeticTransport always answers the canary host) — a green health check that proves nothing; phase 4 "find, not recite" issues in `verifier.rs`, `status.rs`, `credential_store.dart` |
| restraint-altitude-match | 3, 4 | smallest correct `createPresentation` in `app/lib/src/wallet_service.dart`; phase 4 fix-in-scope / defer-out-loud |
| reject-on-camera | 5 | the whole-diff review (README phase 5) |
| establish-cross-boundary-context | 1 (research pass), 2 | `reference/` -> `research-notes.md` in the clone: `did-web-method.md` §3.2/§4, `infra/did-hosting.md`, `infra/hosted-dids/`, `infra/webhook-config.yaml` (10 s hard limit, 0 retries, tenant-kind-index, alarms []), `infra/reserved-domains.md`, `trust-registry.md` |
| reconcile-docs | 1 | `backend/README.md:8-11` (did:key), `:23` (expirationDate vs `expires_at`), `:32-33` (single-use), `:40-42` (concurrent delivery with retries); `app/README.md:8-10` (JWT-VCs); `backend/src/store.rs:68-70` comment; `backend/src/resolver.rs:78-81` comment vs §3.2 |

All ten are reachable from the briefing + clone alone.

## C2 — measured size

Tool: `find ... | xargs wc -l` (physical) and a python line classifier (blank / `//`-comment / code).

| Package | Files | Physical LOC | Code LOC (non-blank, non-comment) |
|---|---|---|---|
| backend/src (Rust) | 11 | 1,561 | 1,206 |
| app/lib (Dart) | 8 | 316 | 245 |
| **source total** | **19** | **1,877** | **1,451** |
| backend/tests (excluded) | 10 | 1,000 | 832 |
| app/test (excluded) | 7 | 304 | 255 |

Per file, backend/src: credential 148, issuer 152, lib 22, notifier 182, resolver 238, settings
114, status 103, store 117, transport 100, verifier 256, webhook 129. app/lib: credentials_app 11,
credential_list 68, credential_store 16, held_credential 74, holder_key 30, issuer_client 10,
presentation_request 49, wallet_service 58.

Changed lines (`git apply --numstat`, `diff`):

| Phase change | Files | +/− (all) | +/− code only |
|---|---|---|---|
| `reference-fix/ticket-1.patch` | resolver.rs 10/10, verifier.rs 5/3 | +15 / −13 | +5 / −10 |
| `reference-fix/ticket-2.patch` | notifier.rs 50/21 | +50 / −21 | +35 / −20 (incl. a 19-line local `join_all`) |
| `feature-reference/` | wallet_service.dart +70/−1; new dcql_selection.dart 91 | +161 / −1 | +131 / −1 |

Comparison: XL row (generation-spec.md:184) = 10-14 files, ~1,200-1,600 LOC, ~135 min.
- Files 19: **above** the row (+5). lib.rs, credentials_app.dart, credential_store.dart,
  issuer_client.dart are 10-22 lines each; excluding them, 15.
- LOC: physical 1,877 **above** the ~1,600 ceiling; code-only 1,451 inside the band.
  practice.json's 1,877 matches the physical count.
- Time: practice.json 165 = XL split 135 + 30 for the second ticket; stated, not hidden.
- Tokens: practice.json 77k by the spec formula; the README warns the other XL kata ran ~5x.
- Invariant 7: Ticket 1 is a 3-line deletion + a 6-line URL builder; Ticket 2 is ~55 code lines in
  one file; the feature is ~130 code lines in the one stubbed surface, and a naive fresh executor
  produced 6/7 of it in one prompt (trap-manifest). Every phase's required change is small.

## C3 — invariant-12 verdicts (generation-spec.md:118-150)

Prose files:

| File | Verdict |
|---|---|
| TICKET-1.md | OK — symptom + promised rule + template "not just the clubs that complained"; no method, mechanism or grader |
| TICKET-2.md | OK (borderline) — the promise's conditions ("whatever the size of the customer's account and however any one relying party's endpoint is behaving", "a green health check means callbacks are reaching customers") are stated as the rule, not as mechanism |
| FEATURE-REQUEST.md | OK — PM ask + surface; lure intact; no warning, no ⚠️ |
| backend/README.md | OK — drift written as belief (did:key, expirationDate, single-use, concurrent+retries), no hedge |
| app/README.md | OK — JWT-VC drift, no hedge |
| reference/README.md | OK — vendor snapshot, read-only; does not tell the reader to study or compare |
| reference/did-web-method.md | OK — states the method; never points at local code |
| reference/trust-registry.md | OK — contract + records; no local reference |
| reference/infra/did-hosting.md | OK — hosting facts |
| reference/infra/hosted-dids/*/did.json (4) | OK — data |
| reference/infra/webhook-config.yaml | OK — deploy config comments state facts (hard limit) |
| reference/infra/reserved-domains.md | OK (borderline) — "an endpoint the platform operates, reached over the same path as the traffic it vouches for" is pointed but reads as a platform standard; names nothing local |
| app/.metadata, analysis_options.yaml, pubspec.yaml, Cargo.toml, .gitignore | OK — no grade script, no answer-key mention (verify leak guard green) |

Comment blocks near planted paths:

| Location | Verdict |
|---|---|
| verifier.rs:195 `resolve_issuer` doc ("The DID document an issuer's credentials are checked against.") | OK — contract, no narration |
| store.rs:68-70 "self-contained, as with the peer DIDs" | OK — misleading drift, no hedge |
| resolver.rs:1-10 module doc (method history) | OK — evidence |
| resolver.rs:78-81 `did_web_url` doc | OK — describes planted mapping as intended |
| notifier.rs:1-10, :22, :129, :134-135, :157, :171 | OK — intent only |
| settings.rs:1-7, :16-20, :99 (tenant-kind index exists, page cost) | OK — evidence |
| webhook.rs:60-63 (canary host answered by local stub) | OK — evidence, not a confession |
| status.rs:34 `allocate` doc | OK |
| wallet_service.dart:50-51 stub doc | OK |
| backend/tests/notifier.rs:26-27 `small_tenant` doc | OK — describes the fixture |
| **backend/tests/did_document.rs:1-5** "This proves the crate is a real, pinned, non-vendored dependency (FM-08)" | **LEAK (L1)** |
| **app/test/smoke_test.dart:1-3** "proving the deps are real, pinned, and wired up (FM-08)" | **LEAK (L1)** |

L1: two clone-visible test files tag their comments with the Context's failure-mode id `FM-08`
(one of this practice's declared failureModes, the category of trap A4 and latent defect #6). A
working team's repo does not cite an exercise taxonomy; the tag announces to the assistant that
it is inside an annotated kata, contrary to "everything in the clone reads as the working repo of
a team that does not yet know it has a bug". No other practice has an FM id in clone-visible
source (`grep -rn 'FM-0' practices/*/` outside `_solutions/`). The verify leak guard does not scan
for FM ids, so it is green despite this.

## C4 — solvability

Solvable at XL in the stated 165 min. Deviations recorded: 19 source files (> 14), 1,877
physical LOC (> ~1,600). These are fog, not fix size; the D17 fallback (demote the cross-stack
check to test level) does not bear on them and is not needed. Risk carried: the estimate is
provisional and unmeasured; the only other XL Cedar kata measured coached runs at ~5x.
