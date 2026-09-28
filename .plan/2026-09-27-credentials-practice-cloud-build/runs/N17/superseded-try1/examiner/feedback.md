# feedback — `credentials`, TRAIN mode, cold-N17 (calibration run)

Examiner: fresh context, graded only from the files in this directory. The learner prompts and trainer
notes were written by an operator with golden access (`transcript.md` line 3, AGENTS.md rule 10). The
run is graded as written. The Source column says where each move came from.

---

## 1. Axis A — objective gate

### Unit suites (`commands.test` = `cd backend && cargo test --offline --locked && cd ../app && flutter test --no-pub`, one `&&` chain, so one exit code)

| | Backend | App | Exit |
|---|---|---|---|
| Baseline (`outcome/00-baseline/unit.txt`) | per-binary `test result: ok.` lines: 0, 7, 1, 9, 6, 13, 4, 7, 5, 16, 0 passed, all `0 failed`. Checkpoint line: `backend: 68 passed, 0 failed · app: +20: All tests passed! · test exit: 0` | `00:03 +20: All tests passed!` | `test exit: 0` |
| Final (`outcome/99-final/unit.txt`) | per-binary lines: 0, 7, 1, 10 (issuer), 6, 13, 4, 10 (status), 5, 5 (ticket_4127), 10 (ticket_4163), 16, 0 passed, all `0 failed`. Checkpoint line: `backend: 87 passed, 0 failed · app: +41: All tests passed! · test exit: 0` | `00:03 +41: All tests passed!` | `test exit: 0` |

Both suites are still green. Backend went from 68 to 87 tests and app from 20 to 41; nothing that existed before was removed.

### Grade (`bash _solutions/grade.sh`)

Baseline (`outcome/00-baseline/grade.txt`):
```
axis a: FAIL 6/26
axis a2: FAIL 4/17
axis b: FAIL 0/7
worst-case: FAIL
exit: 1
```
Final (`outcome/99-final/grade.txt`):
```
axis a: PASS 26/26
axis a2: PASS 17/17
axis b: PASS 7/7
worst-case: PASS
exit: 0
```
Axis A passes. All three axes are at full marks, the same as the reference build.

### Robustness (non-blocking, `outcome/99-final/robustness.txt`)
```
robustness 6/9
```
Failing probes: `FAIL W1`, `FAIL W2` (latent #2, the store hands out held state by reference; the reference build fails these too) and `FAIL N2` (`1 call(s) to a reserved name: https://example.net/webhooks/status`; the reference build fails this too). Passing: W3, G1, D1, D2, N1, S1. The reference build scores 5/9 (`rubric.md` item 5), so this tree is one probe higher, because S1 (latent #5) was fixed in phase 4.

### Assistant's self-reported counts, checked against the checkpoints

| Turn | Claim | Checkpoint / file | Verdict |
|---|---|---|---|
| 1 | "68 backend tests … and 20 app tests" | `00-baseline`: 68 / +20 | agrees |
| 2 | "The other 68 backend tests still pass"; `0 passed; 4 failed` | no checkpoint | unverifiable (consistent with baseline) |
| 3 | "full backend suite is 73/73 … app suite is 20/20" | `03-ticket-1`: 73 / +20 | agrees |
| 4 | six failing ticket_4163 tests | no checkpoint | unverifiable |
| **5** | **"Full backend suite: 86/86 pass"** | **`05-ticket-2`: `backend: 81 passed`** | **DISAGREES** (the assistant admitted "I misadded" in turn 6) |
| 5 | "App suite: 20/20" | `05-ticket-2`: +20 | agrees |
| 6 | "81 tests before this turn, not the 86 … now **82**"; app 20/20 | `06-ticket-2-rework`: 82 / +20 | agrees |
| 8 | "app suite is 42/42 (20 existing + 22 new) … backend … 82/82" | `08-feature`: 82 / +42 | agrees |
| 9 | "app suite is 38/38 … backend is 82/82" | `09-feature-rework`: 82 / +38 | agrees |
| 11 | "backend 85/85 … app 40/40" | `11-improve`: 85 / +40 | agrees |
| 12 | "Backend is 86/86 and app 41/41" | no checkpoint after turn 12 (the next one follows turn 13's revert) | unverifiable |
| 13 | "85 passed" (app not re-run) | `13-improve-rework`: 85 / +41 | agrees |
| **14** | discrimination table: "`ticket_4163` (9) — 9 fail on baseline" | `discrimination.txt`: every `ticket_4163` test is `no-build` on base. The assistant ran them against a shim that defined `ALL_SUBSCRIPTIONS` locally, which it disclosed | **DISAGREES with the checker's method**: on the real baseline source these tests do not compile, so they never went red there |
| **14** | "app `create_presentation_test` (21) — 21 fail on baseline" | `discrimination.txt` base: `+0 -1: loading … create_presentation_test.dart [E]` / `Some tests failed.` | **DISAGREES in form**: this is one load failure, not 21 individual reds. The assistant itself said "The app's baseline failures prove little" |
| 14 | "status (2 new): 1 fail on baseline, 1 pass on both (`the_published_form_of_a_list_is_unchanged`)" | `discrimination.txt`: `every_index…` FAILED/ok; `the_published_form…` ok/ok | agrees |
| 15 | "backend 87/87 … app 41/41" | `99-final`: 87 / +41 | agrees |
| 15 | PR: `ticket_4163.rs` (10), `create_presentation_test.dart` (21), `status.rs` (+3), `issuer.rs` (+1) | final unit.txt: ticket_4163 10; +41 − 20 = 21; status 10 vs 7; issuer 10 vs 9 | agrees |
| **15** | PR: "every new test fails there and passes here, except `the_published_form_of_a_list_is_unchanged` … None depends on being run together" | `discrimination.txt`: `status ok ok a_full_list_hands_out_distinct_indexes` (passes on base too); every `ticket_4163` test `no-build` on base, including turn 15's new `a_subscriber_that_never_answers_has_a_recorded_outcome` | **DISAGREES**: the claim misses a second pass-on-both test and the ten no-build tests |

---

## 2. Per round

**Turn 1: understand and research, no edits.**
- **Signal sought:** a map of both packages, a research pass over `reference/` written into `research-notes.md` with a citation for each point, and a reconciliation of the docs against the code.
- **Practice:** textbook B1 "Understand (no writes)" + F1 "research before you delegate; write the context down" + F2 "docs are stale until verified". This defeats FM-16 and FM-15 in advance.
- **Consequence:** 13 clean tool calls; call 3 dumped every `reference/` file. The notes and reply surfaced the snapshot early return, the `/.well-known` path bug (probed: Northfield resolves to a URL that "returns NotFound"), all four Ticket 2 axes, and latents #1, #5, #6 and #7, and flagged every one of D1–D7 as stale. No code changed.
- **Best-practice prompt:** this one. At most, it could have asked for open questions to be separated from facts, and the notes did that anyway.

**Turn 2: reproduce Ticket 1 and state the model.** Follows trainer note 1.
- **Signal sought:** see the failure for every approved issuer before any fix, and have the learner's own model corrected.
- **Practice:** B2 "reproduce before fixing" (defeats FM-01/FM-02) and "model before you delegate" (FM-13). The path-DID "second problem" restates what the assistant surfaced in turn 1; it is not operator-supplied.
- **Consequence:** `ticket_4127.rs` with 4 tests, `0 passed; 4 failed`, covering Cedar, Northfield and Kestrel with Harbour as a built-in control. The assistant sharpened the model: it explained the two error shapes, noted that onboarding is also broken for Northfield, and raised retired-key refusal as a product decision and the missing registry check. It did not fix any of these.
- **Best-practice prompt:** this one.

**Turn 3: decisions, then the root fix.** Follows trainer note 2.
- **Signal sought:** decide what is the learner's call, route the rest, fix at the root for every issuer and the next rotation, and show red → green.
- **Practice:** E "surface ≠ build" (FM-10), X.3 decisions made before acting, and "give the agent a check it can run". The "Partner Success" answer is an operator-authored stakeholder reply to a question the assistant raised in turn 2. That is a legitimate routing move, but the reply was not obtained in-session.
- **Consequence:** `resolve_issuer` always resolves; `did_web_url` follows §3.2. A fifth test covers the next rotation. Checkpoint `axis a: PASS 26/26` on the first try. The FM-13 plateau was not measurable because the research came first (`trap-manifest.md`). There is a 14-item follow-up list.
- **Best-practice prompt:** this one.

**Turn 4: Ticket 2 research and reproduction under the ticket's conditions.** Follows trainer note 3.
- **Signal sought:** extend the notes; reproduce with a large tenant and a slow or hung endpoint; prove what the health check measures by a run.
- **Practice:** F1 again, B2 under FM-02's affected condition, and FM-01 "green ≠ correct" attacked directly (item 3: "show me … not by reading").
- **Consequence:** 6 failing tests, including "health check green while callbacks are missing … canary_healthy() == true, 3 of 3 subscribers not told". There were five causes, each mapped to a promise it breaks. No code changed.
- **Best-practice prompt:** this one.

**Turn 5: decisions and the Ticket 2 fix.** Follows trainer note 4.
- **Signal sought:** all causes fixed at the root, the canary brought to the standard with its endpoint routed to Platform, no retries, budget not raised, an outcome recorded for every subscriber, and why each cause alone would not close the ticket.
- **Practice:** strong on scope and ownership (X.3, FM-10). It still accepted a green run under the code's own deadline as proof (FM-01 one level up).
- **Consequence:** `notifier.rs` rewritten with the index lookup, concurrency, an 8 s deadline, per-subscriber outcomes and the canary on the same path. The assistant misreported "86/86". Checkpoint `axis a2: FAIL 16/17`. The checkpoint summary does not name the red case; turn 6's fix covered the unbounded list read under the runtime kill.
- **Best-practice prompt:** the same, plus: "one of your tests must run `notify` under the runtime's 10 s hard kill from `webhook-config.yaml`, not under our own deadline. Show it red first."

**Turn 6: re-run the count; test under production's conditions.** Follows trainer note 5.
- **Signal sought:** refuse the summarised count; make the outside environment a test condition.
- **Practice:** X.2 verify-output; "tests first — validate the test's intent". Narrowing to "the hard runtime limit above all" restates the assistant's turn 1/4/5 findings, steered by the trainer note.
- **Consequence:** the assistant admitted "not the 86 I reported; I misadded" and pasted per-binary lines summing to 82. The new `invoke()` test showed stale-green after a runtime kill; the fix bounds the list read. Checkpoint `axis a2: PASS 17/17`. One assertion was loosened after its red run, and the assistant disclosed it.
- **Best-practice prompt:** this one.

**Turn 7: feature, read the other side and elicit.** Follows trainer note 6.
- **Signal sought:** the verifier's wire contract first; open questions grouped by owner, with "I'd pick" kept as a question; the docs checked.
- **Practice:** B3 "spec a feature", read-before-delegate (FM-03), F1/F3 across the boundary.
- **Consequence:** a contract table for `verify_presentation`. Questions went to PM, the verifier team and Platform, including expiry (PM Q5), single-use (PM Q7), claims, proof suite and domain. No code changed.
- **Best-practice prompt:** this one.

**Turn 8: owners' answers, then the build.**
- **Signal sought:** build the smallest thing the answers require, with tests that go red per rule, an end-to-end run and a deferred list.
- **Practice:** good delegation shape: minimal, mutation-checked, end-to-end. The answers are **operator-supplied** from `feature-qa.md`. They respond to questions asked in turn 7, but carry more detail than some questions asked for, such as the full proof recipe.
- **Consequence:** 22 tests and M1–M7 mutation runs. The build also carried six unrequested refusal rules, one of which was "never creates" a holder key. The gate wallet has no stored key and injects `newKey` (`feature_gate_test.dart:34-38`), so checkpoint `axis b: FAIL 0/7`.
- **Best-practice prompt:** the same, plus: "anything you decide that no answer settles, list it before building and follow the existing code's behaviour unless an owner says otherwise."

**Turn 9: separate owner rules from assistant calls; revert departures.** Follows trainer note 7.
- **Signal sought:** list every self-made call, compare each with the repo's convention, and revert unjustified departures.
- **Practice:** FM-10 recovery (SURFACE ≠ BUILD) and FM-03 read-against-the-rule.
- **Consequence:** 18 calls tabulated and six reverted, including holder-key creation. Checkpoint `axis b: PASS 7/7 … worst-case: PASS`. Aliasing was relabelled from "deferred" to "existing convention".
- **Best-practice prompt:** this one.

**Turn 10: phase 4 findings, shown, including today's changes.** Follows trainer note 8.
- **Signal sought:** ranked findings, each demonstrated, including defects the session's own changes introduced.
- **Practice:** 4.1/4.2 exactly, and FM-14's "find, not recite".
- **Consequence:** 13 findings, 7 attributed to today's changes. Latents #7 and #6 (as #1), #1 and #3 (as #2), and #5 (as #4) were shown by probe. Emergent findings: SSRF through `did_web_url`, JCS number formatting, an unbounded fan-out, a `*` id collision, and a short holder key.
- **Best-practice prompt:** this one.

**Turn 11: calls on scope; fix five plus the aliasing.** Follows trainer note 9.
- **Signal sought:** fix the small in-scope items red-first; hold the assistant to its earlier "deferred" label on aliasing; defer the rest by owner into `FOLLOW-UPS.md`.
- **Practice:** X.1 (named deferrals, "a document cache is a new feature, not a fix") and 4.2 (W3). "Small" was not checked for public-surface reach (FM-05).
- **Consequence:** #9 changed `DeliveryEvent.subscription` to `Option<String>` and removed `ALL_SUBSCRIPTIONS`. Checkpoint `axis a2: FAIL 0/0`: the grader no longer compiled. #4 also changed the published list format by one byte.
- **Best-practice prompt:** "fix each without changing any public type, constant, error type or published format; if a fix can't, stop and ask."

**Turn 12: blast-radius audit and redo.** Follows trainer note 10 (the gate regression was relayed through it).
- **Signal sought:** list every externally visible surface this turn touched, redo the fixes that can preserve it, and bring back the ones that can't.
- **Practice:** B4 "reject and redo" and X.3.
- **Consequence:** #4 and the presentation copy were redone with surfaces preserved, each red first. #9 and #8 were brought back for a decision with options (a), (b) and (c).
- **Best-practice prompt:** this one.

**Turn 13: the calls on #9 and #8.** Follows trainer note 11.
- **Signal sought:** a human decision with reasons: revert #9 and defer to Platform; keep the `FormatException`.
- **Practice:** X.3 and X.1, and "small, reversible steps" with a scope proof (`git diff --stat` plus hashes).
- **Consequence:** checkpoint `axis a2: PASS 17/17 … worst-case: PASS`.
- **Best-practice prompt:** this one.

**Turn 14: review.** Follows trainer note 12.
- **Signal sought:** review from the diff, triaged on the tickets' promises; test discrimination checked in isolation against the baseline; the weakest part, the AI's errors, and a trade-off.
- **Practice:** FM-14 defeated, and 5.2 asked for explicitly.
- **Consequence:** tool calls 1–2 ran `git diff` on src, app and tests. Two untested load-bearing behaviours were found (N1, the per-call deadline; N2, distinct indexes). The discrimination table overstates baseline reds for `ticket_4163` (a compile shim) and the app file (a load error); see §1.
- **Best-practice prompt:** the same, plus "report a test that does not compile against the baseline as such, not as a failure."

**Turn 15: the learner's own review statement and merge decision.** Follows trainer note 13.
- **Signal sought:** in the learner's words: what they verified, the weakness, the AI's mistakes, the trade-off, ship-now versus later; plus the two missing tests shown red against the broken copy.
- **Practice:** 5.1 in full. The learner did not re-check the PR's "every new test fails there" line.
- **Consequence:** 87 / 41 green. `a_full_list_hands_out_distinct_indexes` passes on the baseline (`discrimination.txt`); it discriminates only against the deliberately broken copy, which the PR's blanket claim hides.
- **Best-practice prompt:** the same, plus "and re-run the discrimination for the two new tests against the baseline too, not only against the broken copy."

---

## 3. Axis B — the driving axis

| Row | Score | Source | Justification |
|---|---|---|---|
| 1.1 Research pass (FM-16) | present | spontaneous (turn 1, before any trainer note); Ticket 2 extension trainer-prompted (note 3, "Same discipline") | T1: "there's a reference/ folder next to the code. read all of it and write what you learn into a research-notes.md … cite the file". Turn-01 call 3 dumps all of `reference/`. The notes cover live did:web resolution, rotation, the §3.2 path mapping and the trust registry. T4 appends a section with "hard 10 s runtime limit, zero retries … the `tenant-kind` index, no alarms, and PI-STD-014". No fact was named in a prompt before it was read. |
| 1.2 Reconcile docs (FM-15) | present | spontaneous (asked in T1); acted on partly with operator-supplied answers (T8) | T1 item 3: "tell me which claims match … and which are stale. quote the line and say how you know". It flagged the README's `did:key`, the "peer DIDs" comment, `expirationDate`, single-use, "concurrently … retried", JWT-VCs and the resolver comment. The learner acted: "the spec wins" (T3); single-use resolved with its owner (T8). The READMEs were never edited, only deferred ("stale docs", PR F17–F19). |
| 2.1 T1 reproduce before fix | present | trainer-prompted (note 1: "you have not seen the symptom happen yet") | T2: "write test(s) that reproduce TICKET-1 … a credential signed with the key a club publishes now … refused. cover every approved issuer". Result: `0 passed; 4 failed` before any source edit. |
| 2.2 T1 model before delegation (FM-13) | present | trainer-prompted (note 1: "say the cause back in your own words"); the path-DID half restates the turn 1 finding | T2: "the door checks the club's key against the copy … saved at onboarding, but for did:web the key that counts is whatever the club's domain serves now … a second problem … for clubs whose DID has a path". No non-converging rounds (26/26 first try); the plateau was not measurable because research came first. |
| 2.3 T2 reproduce under the ticket's conditions | present | trainer-prompted (note 3: "see it fail under the conditions the ticket describes") | T4: "a customer with a lot of settings, and a relying party whose endpoint is slow or never answers — as failing tests". 6 red, with the canary shown green (`canary_healthy() == true, 3 of 3 subscribers not told`). |
| 2.4 T2 all four axes | present | A2, A3 and A4 decided after the T4 diagnosis (trainer-prompted, note 4); A1 "recorded outcome, not just a log line" spontaneous; the runtime-kill closure of A1/P1 trainer-prompted (note 5) | T5: "all five causes are in scope … a subscriber that isn't reached has to show up as a recorded outcome, not just a log line … canary has to target something the platform operates". It asked "why fixing only that one would not have closed the ticket". First fix 16/17; T6 closed it to 17/17. |
| 2.5 T2 canary lies | present | trainer-prompted (note 3: "treat any green signal as unproven") | T4: "show me (with a test or a run, not by reading) whether it stays green". T5: "it should only be green when the real delivery path actually ran … I've asked Platform which endpoint they want". T15 calls the health check "narrower than what ticket 2 promised". |
| 3.1 Requirements elicitation | present | questions trainer-prompted (note 6: "work out who owns the answers … your assistant is not one of them"); answers **operator-supplied** (`feature-qa.md` content in T8) | T7: "list the questions … grouped by who has to answer them (PM, the verifier team, platform) … I'll take the list to the people". Expiry was asked (PM Q5). T8 relays the answers "as they gave them". |
| 3.2 Read before delegate | present | trainer-prompted (note 6: "read what the other side of the boundary actually checks") | T7: "read how the backend verifier checks a presentation … summarise the contract … with file:line". The build signs exactly as the backend does (the signature-equality test). |
| 3.3 Single-use resolved out loud | present | raised spontaneous (assistant, T1 and T7 PM Q7); resolution operator-supplied (T8) | T8 verifier team: "single-use: no, not in v1 … the wallet must not delete or 'consume' the credential". The build tests "the credential is kept and can be presented to a fresh request". |
| 4.1 Latent defects found, not recited | present | trainer-prompted (note 8: "Ask for findings … each one shown happening in this code") | T10: "each one shown, not recited: a failing test, a probe run, or a file:line". Shown by probe: #7 and #6 (finding 1), #1 and #3 (finding 2: "`request_id` is marked as used before verification … never pruned"), #5 (finding 4). #2 was shown in T11 (A1–A4 probe). #4 (expiry instant) was noticed only as a design call in T8, not routed. W1/W2 are still open but deferred out loud (F20). |
| 4.2 Caught defects the change introduced | present | trainer-prompted (note 8: "point the same scrutiny at today's changes"; note 9 for the aliasing reclassification) | T10: "include everything we changed today". T11: "a presentation we hand to a caller must not be able to change what the wallet holds … show it with a failing test". `robustness 6/9`: W3, G1, D1 and D2 all `PASS`, so no probe the reference passes fails here. N2 fails, as it does on the reference: the reserved-name rule still applies only to the canary. The related URL-validation finding (#10/F7) was deferred to Platform. |
| 5.1 Honest review with intent (FM-14) | present | trainer-prompted (notes 12 and 13) | T14: "work from the diff itself … triage … anchored on what the tickets promised"; turn-14 calls 1–2 run `git diff`. T15: "weakest part … the notifier's health check … trade-off I'm signing: live issuer resolution with no cache … decision: the product code merges once the two missing tests … the canary host goes to Platform as a deploy blocker". |
| 5.2 New tests discriminate | present | trainer-prompted (note 12: "make the tests prove they can fail on the old code") | T14 item 3 asked for runs "against the shipped code … flag any that pass on both or only pass when run together". Examiner's `discrimination.txt`: issuer 1 and `every_index…` FAILED→ok; ticket_4127 5/5 FAILED→ok. **Pass on both:** `the_published_form_of_a_list_is_unchanged` (a disclosed format guard) and `a_full_list_hands_out_distinct_indexes` (discriminates only against the broken copy; the PR did not flag it). **No-build on base:** all 10 `ticket_4163` tests. **App file:** base `loading … [E]`, final 21 pass. |
| X.1 Restraint / altitude (FM-10) | present | trainer-prompted (note 2 "named and deferred out loud"; notes 7 and 10 for the recoveries) | Deferrals were named each phase and consolidated in `FOLLOW-UPS.md` with owners. No latent was fixed silently before phase 4. Over-builds were recovered: the six invented refusal rules (T8→T9) and the #9 public-type change (T11→T13). `DISPATCH_BUDGET` was not raised (replaced by an 8 s `DELIVERY_DEADLINE`, disclosed in the PR). |
| X.2 Verify-output | present | spontaneous for red→green evidence (T2, T3 "paste the real output"); trainer-prompted for re-running a count (note 5) | T6: "you told me the full backend suite was a certain count. re-run it now and paste the real per-binary 'test result' lines". That caught 86 vs 81. Against it: the T5 "86/86" was accepted until the note, and the T15 PR's "every new test fails there" was not re-run (§1). |
| X.3 Structural choices surfaced as questions | partial | retired-key: raised spontaneous (assistant), decided trainer-prompted (note 2); #9: trainer-prompted (note 10) | Asked before acting: retired-key refusal (T2 point 4 → T3 decision) and #9/#8 (T12: "tell me and we'll decide together"). Decided, then disclosed: the canary endpoint (T5: "pick one … flag it as their decision"), the 8 s margin, and the expiry instant (T8: "a credential is still presentable at its exact expiry second", matching the verifier, never taken to an owner). |

---

## 4. Anti-signals

| Anti-signal | Occurred? | Evidence |
|---|---|---|
| Declaring victory on local suites without the grade or other issuers/tenants | No | Every phase closed on the harness "release check". Ticket 1 tests cover all four registry issuers plus a next rotation; Ticket 2 tests cover large and hung tenants. |
| Quoting a stale doc line as current fact | No | T8 relays "the backend README's expirationDate is out of date". No prompt or PR presents `did:key`, "peer DIDs" or "concurrently … retried" as true. |
| T1 special-case, re-pin or hard-coded key | No | `diff.patch` touches `verifier.rs`, `resolver.rs` and `store.rs` (comment); `data/onboarded-issuers.json` is not in the diff. Test key swaps are in the test file only. |
| T2 raises `DISPATCH_BUDGET`, or treats a green canary as closure | No | `-pub const DISPATCH_BUDGET: Duration = Duration::from_secs(10);` → `+pub const DELIVERY_DEADLINE: Duration = Duration::from_secs(8);`. T5 prompt: "don't raise the 10 s budget". |
| Presentation with no expiry check, all claims, or unsigned | No | `axis b: PASS 7/7`; robustness D1 and D2 pass. |
| First plausible diff treated as done without reading | Partly, recovered | Every fix turn asked "walk me through the diff". The T5 and T8 builds were accepted as done until the gate went red (notes 5 and 7). |
| Accepting a summarised measurement | Yes, twice | T5 "86/86" (real: 81) stood until trainer note 5. The T15 PR claim "every new test fails there … except `the_published_form…`" was never re-run and is contradicted by `discrimination.txt`. |
| Review answered without reading the diff | No | turn-14 call 1: `git diff --stat … && git diff -- backend/src`; call 2: `git diff -- app/lib … backend/tests`. |

---

## 5. Designed traps

| Trap | Fired? When | What closed it |
|---|---|---|
| **Ticket 1: stale snapshot (T1.1) and path mapping (T1.2)** | Both surfaced in T1: the snapshot vs hosted key probe, and "Northfield resolves to …/.well-known/chapters/north/did.json, which returns NotFound". Reproduced red in T2. | The T3 root fix: checkpoint 03 `axis a: PASS 26/26`, first try. The FM-13 plateau was **not measurable**, because the fix prompt followed the research pass (`trap-manifest.md`, "When the plateau is measurable"). |
| **Ticket 2: four-axis cluster (A1–A4)** | All four were visible in T1 and reproduced in T4. The first fix (T5) scored `axis a2: FAIL 16/17`, so the cluster bit partially. The phase-4 #9 change regressed it to `axis a2: FAIL 0/0` (checkpoint 11). | T6 runtime-kill test and bounded list read → `PASS 17/17`. T13 revert of #9 → `PASS 17/17`. A4's reserved target was fixed in T5 (R1–R4 green). |
| **Feature trap ("mostly packaging it up")** | The lure did not bite: no wrap-all, holder-signed, bound, expiry refused. A different miss fired: T8's unrequested "never creates a holder key" rule gave `axis b: FAIL 0/7`. | T9 revert to the repo's `holderKey()` convention (after note 7) → `axis b: PASS 7/7`. |
| **Doc drift (D1–D7)** | All seven were flagged in T1's reconciliation. | D2 (the `store.rs` comment) and D7 (the `resolver.rs` comment) were corrected in the T3 diff. D1, D3, D4, D5 and D6 were never edited and are deferred as stale docs (F17–F19 in the PR). D4 was resolved with its owner in T8. |
| **Cross-boundary reference (FM-16)** | Opened unprompted by the learner's own request in T1 (turn-01 call 3). Used for §3.2, the 10 s kill, zero retries, the index and PI-STD-014. | Research notes in T1 and T4. The gate's reference-derived V/W and R cases are all green. |
| **Review phase (FM-14)** | T14–T15. | A diff-based review triaged on the tickets' promises. It found two load-bearing behaviours with no pinning test, which were added red→green in T15. The learner's own merge decision and deploy blocker are in T15. |
| **Ranked latent defects** | #7 proof-type fall-through: T1 probe, T10 #1, deferred F1. #6 no registry check: T1–T2, T10 #1, deferred F1. #1 replay on `request_id`: T1, T7, T10 #2, deferred F2. #2 store by reference: T8 (as deferred), T9 (as convention), T11 probe A1–A4, deferred F20 (W1/W2 `FAIL`). #5 status-list off-by-one: T1 (read), T10 #4 (probe), fixed T11 and redone format-preserving in T12 (S1 `PASS`). #3 unbounded guard: T10 #2 ("never pruned"), deferred with F2. #4 expiry instant: only as a T8 design call ("presentable at its exact expiry second", matching `verifier.rs:169`); never framed as an unspecified rule for an owner. | Every latent except #4 was named and either fixed in phase or deferred to an owner. |

---

## 6. Trainer notes against `harness-DESIGN.md` §3 ("Name the discipline, not the answer")

- Notes 1, 2, 3, 4, 6, 7, 9, 11, 12 and 13 (after turns 1, 2, 3, 4, 6, 7, 9, 12, 13 and 14) name disciplines only: see it fail, say the model back, route decisions, reproduce under the ticket's conditions, read the other side, elicit from owners, show findings, review from the diff, make tests prove themselves. **They do not cross the line.**
- **Note 5 (after turn 5) crosses the line.** "the suite count you were handed in that summary is not what the harness counted when it re-ran the suite" states a finding the learner had not seen: that a specific figure is wrong. It does not give the right number. The discipline alone ("a count in a summary is a claim until you watch it being produced") would have been enough. Its second half ("what your research notes say the production environment imposes from the outside") is a class-of-question pointer and stays inside the line.
- **Borderline, not counted as crossing:**
  - **Note 8 (after turn 8):** "ask whether it follows what the surrounding code already does or quietly departs from it" describes the class of the defect that caused `0/7` without naming the holder-key rule.
  - **Note 10 (after turn 10):** "a finding that quietly changed category between turns deserves a second look" fits exactly one finding, the aliasing. It names no finding, but it aims closely.
  - **Note 11 (after turn 11):** "a closed ticket regressed … which of this turn's changes reached beyond their own function bodies" relays a gate result and names a blast-radius discipline, not #9.
- **Gate status.** The header lines of notes 5, 8 and 11 ("the harness gate has not closed/accepted …", "red again") pass gate results to the learner. The learner prompts repeat them as "the release check says …" in turns 6, 9 and 12. These are outcomes, not findings, clauses or numbers. They are the channel through which three of the recoveries were started.

---

## 7. Verdict

**Calibration run (operator-driven with golden access; not a learner grade).** The run ends at `worst-case: PASS` (26/26 · 17/17 · 7/7) with both suites green (backend 87, app 41) and `robustness 6/9`, one probe above the reference build. Driving was strong in every phase: an unprompted research pass, red-first reproduction for both tickets, and elicitation routed by owner. It also included a diff-based review, and the learner's own merge decision records what they verified and the trade-off they signed. Three recoveries were started by the gate plus trainer notes rather than found by the learner: Ticket 2 at 16/17, the feature at 0/7, and the phase-4 regression to `axis a2: FAIL 0/0`. The feature answers were operator-supplied. One trainer note (after turn 5) disclosed a wrong figure. The weak spots are the unchecked self-reports: the "86/86" count and the PR's "every new test fails there", which `discrimination.txt` contradicts for `a_full_list_hands_out_distinct_indexes` and the ten no-build `ticket_4163` tests. The other weak spot is the expiry-instant and canary-margin choices, which were decided and then disclosed rather than asked.
