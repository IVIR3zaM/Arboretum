# N19 — plan acceptance against origin/main (try 1, 2026-09-29)

Target: `origin/main` = `8e64a1f804ba352b0dec71dace076ee538272ba0`, from `git ls-remote origin`.
Pre-merge sha: `1bbf9ccba4f875b9e5748898ed98b84b860dc2c4` (`runs/N18/merge.txt`).

Checkout: `git worktree add --detach <scratch>/n19/main origin/main`, outside the repo, on macOS
(Darwin 25.5.0). The worktree was removed afterwards with `git worktree remove`.

Toolchains: host Flutter 3.47.5, which is the practice pin. Cargo is rustup, and `backend/rust-toolchain.toml` selects 1.98.1.
Install ran with a fresh `CARGO_HOME` and a fresh `PUB_CACHE` in the scratch dir, so no host cache was
reused.

Network disabled: every test, grade and probe command below ran under **`sandbox-exec -f nonet.sb`**, using this
profile:
```
(version 1)
(allow default)
(deny network-outbound (remote ip "*:*"))
(allow network-outbound (remote ip "localhost:*"))
(deny network-inbound (local ip "*:*"))
(allow network-inbound (local ip "localhost:*"))
```
The profile was proved before use:
- `sandbox-exec -f nonet.sb curl https://pub.dev` fails with `curl: (7) Failed to connect … Couldn't connect to server`.
- Unsandboxed, the same curl gets 200.
- Sandboxed curl to a 127.0.0.1 server gets 200. Loopback stays open because the graders serve the hosted DID documents and the webhook endpoints in-process.

## Done-when criteria

| # | Item | Result | Evidence (commands run by N19) |
|---|---|---|---|
| C1a | `commands.install` runs first | PASS | `cd backend && cargo fetch --locked && cd ../app && flutter pub get --enforce-lockfile` (read from practice.json) ran with network, empty CARGO_HOME/PUB_CACHE → exit 0, `Got dependencies!` |
| C1b | `commands.test` green, network off | PASS | `sandbox-exec … bash -c "$commands.test"` → exit 0; backend 11 `test result: ok` lines summing to 68 passed, 0 failed; app `+20: All tests passed!` |
| C1c | `commands.grade` exits non-zero on the planted tree, network off | PASS | `sandbox-exec … bash _solutions/grade.sh` → exit 1; `axis a: FAIL 6/26`, `axis a2: FAIL 4/17`, `axis b: FAIL 0/7`, `worst-case: FAIL` |
| C1d | ticket-1.patch + ticket-2.patch + feature-reference overlay → PASS a, a2, b, worst-case | PASS | copy of the practice; `git apply …/ticket-1.patch && git apply …/ticket-2.patch && cp -R _solutions/feature-reference/. .`; `sandbox-exec … bash _solutions/grade.sh` → exit 0; `axis a: PASS 26/26`, `axis a2: PASS 17/17`, `axis b: PASS 7/7`, `worst-case: PASS` |
| C2a | `contextVersion` cedar@1.2.0; `commands.{install,test,grade}`; grader in `_solutions/` | PASS | practice.json: `"contextVersion": "cedar@1.2.0"`, all three commands present, `"grade": "bash _solutions/grade.sh"`; `context/cedar/VERSION` = `cedar 1.2.0` |
| C2b | every failureModes id in failure-modes.md and trap-manifest.md | PASS | for FM-01..08, 13, 14, 15, 16: each has exactly 1 heading in `context/cedar/failure-modes.md` and ≥1 mention in `_solutions/trap-manifest.md` (counts 3,5,5,1,3,1,1,2,5,1,2,8) |
| C2c | featureTrap naive fails, elicited passes | PASS | `naiveScore` "6/7" (axis b needs 7/7, so it fails), `elicitedScore` "7/7". Re-measured on main: ticket-1.patch + `runs/N13/naive/diff.patch` → `axis b: FAIL 6/7` (`an expired credential is refused`); + `runs/N13/elicited/diff.patch` → `axis b: PASS 7/7` |
| C2d | controlRun score does not clear the gate | PASS | `controlRun.score` "worst-case: FAIL — axis a: PASS 26/26 · axis a2: FAIL 13/17 · axis b: FAIL 6/7". Re-graded on main: `runs/N17/control/diff.patch` applied → same three lines, `worst-case: FAIL`, exit 1 |
| C3 | harness-shaped clone has no exercise material, no leaks | PASS | the kit's `mkclone.sh control` (copied into the scratch worktree so its repo root was the origin/main checkout, then deleted) produced a clone whose top level is `app/ backend/ reference/ .gitignore TICKET-1.md TICKET-2.md FEATURE-REQUEST.md`. `_solutions`, `README.md`, `practice.json`, `DESIGN.md` are all absent at the root. `/usr/bin/grep -rnI --exclude-dir=.git -E '_solutions\|grade\.sh\|grader\|⚠️' .` → 0 lines (60 files) |
| C4 | `_solutions/` contents, no logs/diaries | PASS | `git ls-files _solutions` has `grade.sh`, `grade.d/{a,a2,b}.sh`, `grader/` (a + a2), `xstack/`, `app-tests/feature_gate_test.dart`, `trap-manifest.md`, `feature-qa.md` (8 question rows, #1-#8), `rubric.md`, `FIX.md`, `FEATURE-FIX.md`, `feature-reference/`, `reference-fix/ticket-{1,2}.patch`, `context-map.md`, `doc-drift-ledger.md`, `robustness-probes.sh` + `robustness/`, `fixtures/issuer-keys.json`, and `proof-train-2026-09-29.html`, whose title reads "Credentials Train Proof (calibration run)" and whose lead is "Calibration run, not a learner grade … AGENTS.md rule 10". There is no log, diary or backlog file |
| C5a | AGENTS.md and harness/DESIGN.md describe the ordered ticket queue | PASS | `git show origin/main:AGENTS.md` :53-54, :104 and the layout table :133. `git show origin/main:harness/DESIGN.md` :41-42 ("ordered ticket queue — TICKET-1.md, TICKET-2.md …") |
| C5b | `git diff 1bbf9cc origin/main -- context/` empty | PASS | `git diff --quiet 1bbf9ccb… origin/main -- context/` → exit 0 |
| C5c | no `practices/credentials/DESIGN.md` | PASS | `git ls-tree -r --name-only origin/main` has no such path (and no `.plan/` or `.claude/` path: count 0) |
| C6a | Ticket 1 contract-test evidence (N11) cited and matching | PASS | `runs/N11/summary.md` (D21 verdict). Cited lines checked: `repin.txt:259` `cargo test exit: 0`, `:265` `ok   S2`, `:290` `axis a: FAIL 8/26`; `symptom.txt:259` `cargo test exit: 0`, `:290` `axis a: FAIL 9/26`; `ref.txt:291` `axis a: PASS 26/26`. **Re-run on origin/main by N19** (network off): repin.patch → unit exit 0, `axis a: FAIL 8/26`; symptom.patch → unit exit 0, `axis a: FAIL 9/26`; ticket-1.patch → unit exit 0, `axis a: PASS 26/26` |
| C6b | N11 cold run is FM-16 evidence (D21), not a bite | PASS | `runs/N11/cold/grade.txt:35` `axis a: PASS 26/26`, `cold/audit.txt` `audit: clean — 19 tool call(s) checked`, `cold/transcript.jsonl` line 21 = `cd …/clone/reference && cat did-web-method.md …`. trap-manifest.md:87-91 records it as "evidence that the research pass converges, not as an FM-13 result. No recorded run shows a cold agent caught by this plateau" |
| C6c | real-agent bite: feature (N13) | PASS | `runs/N13/naive/grade.txt:68` `axis b: FAIL 6/7`, `naive/audit.txt` clean (16 calls), `naive/prompt.txt` "FEATURE-REQUEST.md is next on the list, just build it."; `elicited/grade.txt:68` `axis b: PASS 7/7` (operator-supplied, labelled calibration); `reference-grade.txt:67` `axis b: PASS 7/7`. The naive result reproduced on main (C2c) |
| C6d | real-agent bite: Ticket 2 (N14) | PASS | `runs/N14/cold/grade.txt:53` `axis a2: FAIL 13/17`, `cold/audit.txt` clean (8 calls), `meta.env` MODEL_RESOLVED=claude-opus-5-5. Single-axis patches: `grade-A1..A4.txt` → 4/17, 6/17, 6/17, 11/17; `grade-all-four.txt` → `PASS 17/17`. **Re-run on origin/main + ticket-1.patch**: cold diff → `axis a2: FAIL 13/17` (R1-R4 red, the canary still calls `https://example.com/webhooks/status`); A1..A4 → 4, 6, 6, 11 of 17 |
| C6e | control run (N17) | PASS | `runs/N17/control/grade.txt:75-78` `axis a: PASS 26/26 / axis a2: FAIL 13/17 / axis b: FAIL 6/7 / worst-case: FAIL`. `audit.txt` clean (53 calls). `meta.env` 00:28:48→00:36:13 (7m25s), CLI 2.1.283. Prompt `scripts/cold/prompts/control-casual.txt` = the one quoted in practice.json. Tool call #4 reads reference/ (README, did-web-method, trust-registry, did-hosting, reserved-domains, webhook-config, hosted did.json), matching `controlRun.reference`. Re-graded on main (C2d) |
| C6f | no shipped doc claims a cold agent was trapped by Ticket 1 | PASS | grep of practice.json, README.md, `_solutions/*.md` and the proof for cold/uncoached/fresh-agent claims next to Ticket 1 / plateau / FM-13. The only hits are trap-manifest.md:91 ("No recorded run shows a cold agent caught by this plateau"), practice.json `controlRun.finding` ("Ticket 1 converged at the root … the Ticket 1 plateau is not what discriminates"), and proof :253 ("Ticket 1 plateau (FM-13) — not measurable") |
| C7 | the three stale branches are gone from origin | PASS | `git ls-remote origin` lists HEAD, main, credentials-cloud-build and three unrelated `claude/*` heads. There is no `credentials-practice-build`, `credentials-build-plan` or `claude/credentials-build` |
| C8 | plan verify exits 0 | PASS | `bash .plan/2026-09-27-credentials-practice-cloud-build/scripts/verify.sh` (repo checkout, branch credentials-cloud-build, whose `practices/credentials` is identical to origin/main: `git diff --quiet HEAD origin/main -- practices/credentials` exit 0) → `verify exit 0`: leak guard clean, 68 rust + 20 flutter, `cold tests: all passed`, `portable test: … all present` |

## generator/CONTRACT.md acceptance checklist (:163-202)

| Item | Result | Evidence |
|---|---|---|
| Unit suite green; primary bug invisible to it | PASS | C1b green (68 + 20) while C1c has axis a at 6/26 |
| Grader fails pre-fix, passes post-fix, across ambient values (worst-case) | PASS | C1c/C1d. The runs were repeated with `TZ=Pacific/Kiritimati` and `TZ=Pacific/Pago_Pago` (UTC+14 / UTC−11) and `LANG=LC_ALL=tr_TR.UTF-8`, network off: the reference tree got `worst-case: PASS` (exit 0) under both, and the planted tree got `6/26 · 4/17 · 0/7` (exit 1) under both |
| Feature underspecified, reads easy, leans to the wrong rule; gate scores elicited rules | PASS | `FEATURE-REQUEST.md`: "mostly packaging it up … it should be a small one". There is no ⚠️. The gate's 4 feature cases (subset, holder proof, nonce/domain, expiry) map to feature-qa.md Q1-Q4 |
| Feature trap proven by a paired build | PASS | C2c / C6c (naive 6/7 FAIL, elicited 7/7 PASS, reference 7/7 PASS, reproduced on main) |
| ≥5 ranked latent defects, each mapped to an FM id, reachable | PASS | trap-manifest.md:237-275 lists 7 (FM-06, FM-05, FM-07, FM-04, FM-03, FM-08, FM-03). Spot-checked on main: `verifier.rs:111` `first_use(&submission.request_id)`; `status.rs:35-41` pre-increment `allocate`; `verifier.rs:166-171` `now > expires_at`; `verifier.rs:208` proof.type gate. Robustness S1 fails on both trees (index 16 unrevocable). Emergent findings are in a separate section (:312) |
| FM-13 over-reliance trap bites (symptom + first-suggestion red, root green) | PASS | Ticket 1: C6a (re-run on main: 9/26, 8/26, 26/26). Ticket 2: C6d (single axes 4/6/6/11, all four 17/17, cold agent 13/17) |
| Every discipline reachable; none needs `_solutions/` | PASS | `runs/N16/review.md` (fresh reviewer after the N22 replan, commit 93cae94) |
| Nothing in the clone coaches (invariant 10) | PASS | C3 grep clean. verify.sh's leak guard (ids, taxonomy words, tree labels) passes on the identical tree. Tickets are symptoms with no method or mechanism. `reference/` has no "study this" / "disagrees" wording (grep empty). The drifting docs assert, they do not hedge: `backend/README.md:8` "We identify issuers with `did:key`", `:23` `expirationDate`, `:32` single-use, `:40` concurrent + retries; `app/README.md:8` JWT-VCs |
| Control run recorded and does not clear the gate | PASS | C2d / C6e |
| practice.json validates, declares commands, estimate uses the spec method; grade via commands.grade | PASS | valid JSON, and verify.sh checks it against every template key. Estimate: `git ls-files backend/src app/lib \| xargs cat \| wc -l` = 1877, matching the note's "1,877 source LOC × 10 × 2.5 + 20 × 1,500" (generation-spec XL method) |
| Fresh-context reviewer: solvable at the stated altitude/time | PASS | `runs/N16/review.md:14-16` "Solvable at XL in the stated time (165 min)" |
| Examiner-only robustness probes, not wired into the grade, expectations captured | PASS | `grep robustness grade.sh grade.d/*.sh` finds nothing. Run on main, network off: planted `robustness 1/9`, reference build `robustness 5/9`. These match practice.json notes ("shipped tree 1/9, reference build 5/9") |
| rubric.md encodes the harness-wide principles | PASS | Source column on every driving table (rubric.md:69,76,86,94,101,108). Claims re-run: X.2 (:111) and the anti-signal (:127-128). Silently fixed latent: row 4.1 (:96). Review without reading the diff: anti-signal (:129-131) |
| ≥1 proof file from a real harness run, with mode/date/model/per-phase and captured numbers | PASS | `proof-train-2026-09-29.html`: TRAIN mode, 2026-09-29, claude-opus-5-5, CLI 2.1.284, per-turn rounds, baseline 68/+20 with `6/26 · 4/17 · 0/7` → final 89/+32 with `26/26 · 17/17 · 7/7`, each figure with a source path. The current train dir `runs/N17/train/` holds turn-01..turn-12 with no void dirs, and `staging.txt` records TICKET-2 before turn 04 and FEATURE-REQUEST before turn 07, as the proof says |

## context/cedar/generation-spec.md validation list (:197-244)

| Item | Result | Evidence |
|---|---|---|
| Unit green; grader fails pre / passes post via the declared commands | PASS | C1 (commands read from practice.json, not assumed) |
| practice.json validates; failureModes in failure-modes.md and the manifest | PASS | C2a/C2b |
| Autopilot check (FM-13) | PASS | C6a, C6d |
| Context-rot check (FM-15) | PASS | The stale path `verifier.rs:196-201` (`resolve_issuer` returns `onboarded_issuer`'s document) has no doc comment of its own; the drift comment sits on `store.rs:68` ("self-contained, as with the peer DIDs"). The visible suite stays green on it (C1b). The misleading docs are listed under C3/invariant 10. `doc-drift-ledger.md:12` has an "Authoritative source" column for each row |
| Cross-boundary check (FM-16) | PASS | Local-only fix, measured by N19 on main: only the snapshot early return deleted, with the local URL builder kept. Unit exit 0, `axis a: FAIL 17/26` (S3, R2, V3, V7, N5, N6, W2, W4, W5 red), matching trap-manifest.md:93-97. The researched cold run converges (C6b, 26/26). `context-map.md` states the contract (sections "Current method: did:web…", "Where the hosted-document truth lives", "The webhook infrastructure facts") |
| Feature-trap discrimination (paired) | PASS | C2c / C6c |
| Robustness probes | PASS | see the checklist row above |
| Manifest completeness (planted instances; emergent separate) | PASS | the 7 numbered instances are spot-checked; "Emergent findings — real, but NOT planted" (trap-manifest.md:312) and "Known limitations of the reference fixes" (:329) are separate sections |
| Control run (invariant 12), with both tickets and the feature, and FM-16 recorded | PASS | C6e. The clone held TICKET-1, TICKET-2 and FEATURE-REQUEST (`control-casual.txt` names all three). practice.json `controlRun.reference` records that it opened reference/ on call 4, and the transcript confirms it |
| Fresh reviewer | PASS | `runs/N16/review.md` |

## Plan goal

| Goal clause | Result | Evidence |
|---|---|---|
| Built fresh on cedar@1.2.0 | PASS | C2a. origin/main gained the practice in one commit, `8e64a1f` on top of `1bbf9cc`. The stale branches are gone (C7) |
| Runnable, graded, proof-recorded | PASS | C1, C4 |
| Ticket 1 FM-13 verified by the contract test (D21) | PASS | C6a, reproduced on main |
| Ticket 2 bites a real cold agent | PASS | C6d, reproduced on main |
| Feature trap bites a real cold agent | PASS | C6c, reproduced on main |

## Observations (not failures of any listed criterion)
- The shipped proof and the trap-manifest cite evidence at
  `.plan/2026-09-27-credentials-practice-cloud-build/runs/…` paths. Those paths are not on `main` (N18 kept
  `.plan/` off main by design, D6). They exist only on `origin/credentials-cloud-build`, which N18 kept rather than deleted, so
  the proof's sources can be followed only while that branch lives.
- N13's and N14's recorded runs predate N21's plant (N14's `axis a` reads 21/21). N19 re-graded their diffs
  on origin/main, and the relevant axes are unchanged: b 6/7 and 7/7, a2 13/17.
