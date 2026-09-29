# feedback — `credentials`, TRAIN mode, calibration run (cold-N17-train3)

**Calibration run.** The learner prompts and trainer notes were written by an operator with golden access (AGENTS.md rule 10). This grades the operator's driving and the assistant (`claude -p --model opus`). It is not a learner grade. Golden content that reached the prompts is marked **[golden]** below and summarised in §6.

---

## 1. Objective scorecard

All figures are from `outcome/`, not from the transcript.

| | Backend unit | App unit | test exit | axis a | axis a2 | axis b | worst-case | grade exit |
|---|---|---|---|---|---|---|---|---|
| `00-baseline` | 68 passed (7+1+9+6+13+4+7+5+16, all `0 failed`) | `00:04 +20: All tests passed!` | `test exit: 0` | `axis a: FAIL 6/26` | `axis a2: FAIL 4/17` | `axis b: FAIL 0/7` | `worst-case: FAIL` | `exit: 1` |
| `99-final` | 89 passed (7+1+5+9+6+10+18+4+8+5+16, all `0 failed`) | `00:04 +32: All tests passed!` | `test exit: 0` | `axis a: PASS 26/26` | `axis a2: PASS 17/17` | `axis b: PASS 7/7` | `worst-case: PASS` | `exit: 0` |

**Robustness (non-blocking):** `robustness 6/9`. Passing: W3, G1, D1, D2, N1, S1. Failing: `FAIL W1 …`, `FAIL W2 …`, and `FAIL N2 … 1 call(s) to a reserved name: https://example.net/webhooks/status`. The reference build scores 5/9. This tree passes every probe the reference passes, plus S1 (latent #5, fixed in phase 4). The probes it fails are W1/W2 (latent #2, still open) and N2 (the reserved-name rule applied only to the canary; the reference fails N2 too).

**Discrimination verdict:** `discrimination.txt` has no summary line, so this verdict is derived from its rows.
- The run added 33 tests: 21 backend and 12 in `create_presentation_test.dart`.
- **28 are `FAILED`/`[E]` on base and `ok` on final. 5 are `ok` on both.** No test is `no-build`, and none passes only positionally: every test was run alone.
- The five that pass on both:
  - `a_member_of_an_issuer_that_never_rotated_is_admitted` (a control);
  - `the_platform_limits_are_the_ones_this_suite_runs_under` (a config guard);
  - `the_canary_receives_the_same_change_through_the_same_transport_as_the_subscribers` (the guard renamed in T6);
  - `the fixture holder is the backend credential subject` (a fixture check);
  - `a_customer_subscription_named_canary_does_not_stand_in_for_the_platform_canary`. This one guards a defect the branch introduced (T11 finding A), so it cannot fail on the baseline. It did fail on the pre-fix branch: turn-12 log, `platform canary answered 503 but health is green … FAILED. 0 passed; 1 failed`.
- Verdict: the new tests discriminate. No test claims to reproduce a baseline bug while passing on the baseline.

**Self-reported counts checked against the captured outputs:**

| Turn | Claim | Check | Agrees? |
|---|---|---|---|
| T1 | "backend 68 passed, app 20 passed" | baseline 68 / +20 | yes |
| T2 | "7 new tests: 6 fail and 1 passes, and all 68 existing tests still pass" | discrimination: door 4 FAILED + 1 ok; resolver maps/resolves both FAILED | yes |
| T3 | "75 backend tests … and 20 app tests" | checkpoint 03: `backend: 75 passed … app: +20` | yes |
| T4 | notifier_platform "1 passed; 2 failed" | turn-04 log `FAILED. 1 passed; 2 failed` | yes (no checkpoint) |
| T6 | notifier_platform "7 passed"; on old code "2 passed; 5 failed" | checkpoint 06: 82 = 75+7; discrimination: 2 of those 7 tests `ok` on base | yes |
| T8 | "app +31 (20 existing + 11 new)"; "10 of the 11 failed" against the stub | checkpoint 08: `+31`; base run: only the fixture test passes | yes |
| T10 | notifier_platform 9, resolver 18, status 8; app +31 | checkpoint 10: `backend: 88 passed … app: +31` | yes |
| T11 | "17 files, +1645/−67" | turn-11 log `17 files changed, 1645 insertions(+), 67 deletions(-)` | yes |
| **T11** | **"29 of them fail on the baseline and 4 pass on both"** | At T11 the branch had added 31 tests (backend 20, app 11). The assistant's own matrix shows 17 backend + 10 app = **27** failing on baseline, plus 4 passing on both. 29 + 4 = 33 ≠ 31. | **no: 27, not 29** |
| T12 | notifier_platform 10; app +32; two tests went from failing to passing | final: 89 backend, `+32`; the turn-12 log shows both failing first | yes |
| **T12 / `PR_DESCRIPTION.md`** | "fails on the old and passes on the new, apart from four deliberate guards" | final discrimination: **5** pass on base (the T12 canary test is the fifth) | **no: stale** (the prose was written before the T12 test existed; the conclusion holds, the count does not) |

The learner accepted both wrong counts without asking for a re-run.

---

## 2. Per round

**T1: understand / research.**
- **Signal:** a research pass before touching code (FM-16, FM-15). The prompt asks for no edits, a system map, every `reference/` file distilled into `research-notes.md`, and a docs reconciliation.
- **Practice:** hits B1, F1, F2 and F3 (defeats FM-16, FM-15).
- **[golden] Read-ahead:** the prompt has the assistant map "the status-change webhook notifier" and "the wallet's store and the presentation stub". At T1 the learner holds only TICKET-1, so Ticket 2 and the feature surface come from the operator's knowledge. "including infra/ and the hosted documents" also steers toward the files the traps depend on.
- **Consequence:** 13 tool calls; notes written. `reference/` was opened before any fix. The assistant found the snapshot root, the path-mapping bug and all four issuer states on T1, and also pre-found the notifier's A1-A4 and the reserved-name rule.
- **Best-practice prompt:** the same, but scoped to TICKET-1 and "everything under `reference/`", without naming subsystems no work item has mentioned yet.

**T2: model, then reproduce.**
- **Signal:** model-before-delegation (FM-13) and reproduce-before-fix (FM-01, FM-02).
- **Practice:** hits B2 and D "model before you delegate". The learner states the root in their own words, including the path mapping, and asks to be corrected.
- **[golden]:**
  - The issuer-state list "(never rotated, rotated to a new key id, same key id with new material on a path DID, rotated with a moved endpoint)" mirrors trap-manifest's ambient-axis wording. The facts themselves were in the T1 notes.
  - "a credential signed with a key the issuer has retired, which must still be refused" is grader cases R1-R3. It is derivable from spec §4, but the assistant had not surfaced it.
- **Consequence:** 7 tests, 6 red with real errors. The assistant pushed back on the model: "re-approved = rotated" is a guess, and retired-key credentials will now be refused.
- **Best-practice prompt:** the same, with the retired-key case left for the learner to derive from the notes, or asked as "what should happen to a credential signed with a key the issuer no longer publishes?"

**T3: decisions, root fix, per-half evidence.**
- **Signal:** X.3 (decisions stated), X.1 (registry and proof-type deferred), and a root fix with proof that each half matters.
- **Practice:** hits D "small, reversible steps" and B4. Asking for a revert-each-half matrix is strong verify-output practice.
- **[golden]:** "Don't re-pin or edit data/onboarded-issuers.json, don't special-case any issuer, don't hard-code keys from reference/" is the rubric's Ticket 1 anti-signal list verbatim.
- **Consequence:** a 3-file diff (+12/−8). Checkpoint 03: `axis a: PASS 26/26` on the first fix. The assistant raised the approved-list gate question unasked.
- **Best-practice prompt:** "fix at the root per the model we agreed; tell me which plausible shortcuts you rejected and why." That lets the plateau be tested rather than fenced off.

**T4: Ticket 2 research and reproduction.**
- **Signal:** FM-16 for Ticket 2, what the canary vouches for (A4), and reproduction under the ticket's conditions (FM-02).
- **Practice:** hits B2 and F1. Q2 ("whether a green result could coexist with the customer's symptom") is the right class of question.
- **[golden]:** "naming rules" points at `reserved-domains.md`, and "Use the budget and limits the platform really imposes, not our own constants" points at the A1/A3 facts.
- **Consequence:** 2 tests red with the health check green; notes §6 written; the canary's reserved target and pre-lookup position were named.
- **Best-practice prompt:** the same, with "anything else that applies" alone instead of the enumerated categories.

**T5: causes and open decisions.**
- **Signal:** each axis alone would not close the ticket (row 2.4), and structural choices surfaced before code (X.3).
- **Practice:** hits B3-style elicitation for a fix, and E "surface ≠ build".
- **[golden]:** "say whether fixing it alone would close the ticket's promise" mirrors rubric 2.4's "why each alone would not close the incident".
- **Consequence:** the assistant listed 11 causes and 12 decisions with owners, including D4 (budget margin) and D8 (canary target → Platform).
- **Best-practice prompt:** as written. It is a sound discipline prompt even if operator-shaped.

**T6: answers, then the Ticket 2 fix.**
- **Signal:** owners' answers, then a minimal fix with before/after runs.
- **Practice:** hits D "give the agent a check it can run", with runs "by actually running them against both, not by reasoning".
- **[golden], heavily:**
  - D1: "a recorded, non-delivered event our monitoring can see, not a log line" is rubric A1's "an event, not a log line".
  - D4: "don't raise our budget constant" is a rubric anti-signal.
  - D7/D8: "http://127.0.0.1/webhooks/canary" is `FIX.md`'s A4 URL character for character, and "a change whose subscribers could not be read or reached in time must not leave it green" is grader case P1.
- **Consequence:** `axis a2: PASS 17/17` on the first implementation (checkpoint 06). The assistant exposed its own non-discriminating ordering test.
- **Best-practice prompt:** the owner answers should come back only to the questions asked, in the owners' words. An answer carrying the reference fix's URL makes A4 unmeasurable.

**T7: feature, read then elicit.**
- **Signal:** read-before-delegate (3.2), requirements elicitation (3.1) and the single-use claim (3.3).
- **Practice:** hits B1, B3 and D "spec first".
- **[golden]:**
  - "It reads like a small job, and I don't trust that yet" is lure awareness.
  - "the PM, the verifier team, and Platform" are feature-qa's stakeholders.
  - "anything where our own docs and code disagree about how credentials behave" steers to Q6.
- **Consequence:** the assistant wrote a full wire contract with lines and 16 owner-tagged questions, including P4 (expired → Q4, the discriminating rule) and P3 (single-use).
- **Best-practice prompt:** as written, minus the stakeholder list.

**T8: answers, test-first build, cross-stack proof.**
- **Signal:** build to the answers; tests first; an end-to-end check against the real Verifier.
- **Practice:** hits D "tests first" and F3 (the other side's contract verified).
- **[golden]:** the answers are near-verbatim `feature-qa.md` Q1-Q8. They volunteer beyond what was asked, against the file's operator rule "answer only what was asked":
  - the V2 answer adds Q3's signed-nonce/domain binding;
  - the V3/V4 answer adds "We also check the credential's subject is the presenting holder";
  - P1 names "the name, member id or birth date".
- **Consequence:** checkpoint 08: `axis b: PASS 7/7`. The throwaway crosscheck was removed. Five unanswered choices were disclosed after the build (decide-then-disclose).
- **Best-practice prompt:** as written, plus "stop and ask before deciding anything the answers don't cover".

**T9: accept the choices; improvement pass.**
- **Signal:** X.3 recovery (choices accepted out loud), 4.1 found-not-recited, and 4.2 our own changes.
- **Practice:** hits E, FM-14 prep and FM-12.
- **[golden]:** "Find, don't recite" is the rubric row 4.1 title, and "apply at one entry point but not another" is the rubric 4.2 / manifest N2 wording.
- **Consequence:** 13 ranked issues separating probe from reasoning:
  - #7 as a forged-credential probe;
  - #5 by probe;
  - #3 and #1-adjacent (item 7);
  - SSRF in the resolver the branch touched;
  - a malformed-setting hole in its own Ticket 2 guarantee.
- **Best-practice prompt:** "what's still wrong, including in what we changed? Show me, don't list."

**T10: fix the four chosen items, test-first.**
- **Signal:** minimal, red-then-green fixes; defer the rest with owners; quote the spec rule.
- **Practice:** hits B2, E and F2.
- **Consequence:** 7 tests went from failing to passing (checkpoint 10: 88/+31). #5 was fixed in phase 4, out loud, which is why S1 passes. #7 was escalated, not patched.
- **Best-practice prompt:** as written.

**T11: review.**
- **Signal:** FM-14 triage anchored on the diff, plus test discrimination (5.2).
- **Practice:** hits D "adversarial review … aimed by intent and triage".
- **[golden]:**
  - The expected-risk list "(the resolver change, the URL mapping, the notifier's budget/concurrency/health logic and createPresentation's signing …)" mirrors rubric 5.1's triage.
  - Item 2 ("one at a time, against the baseline … pass on both, or … only when run together") is rubric 5.2's examiner action.
- **Consequence:** the review found A (the canary id is spoofable, introduced by T6) and B (the presentation shares the stored map, i.e. W3) by probe, plus the C/D overclaims. The "29" miscount went unchallenged.
- **Best-practice prompt:** "triage it yourself first, then tell me where you'd read line by line and why."

**T12: approver decisions, fixes, PR.**
- **Signal:** a human decision on what ships (5.1), and blockers written up.
- **Practice:** hits FM-14 (a human accountable for the merge) and E.
- **[golden]:** the PR skeleton (verified / what the AI got wrong / weakness / trade-off) follows rubric 5.1. The no-retry wording echoes the manifest's known limitation. The content comes from this run's own findings.
- **Consequence:** A and B were fixed red→green, and W3 passes. The PR carries a stale "four deliberate guards". Final: 89/+32, worst-case PASS.
- **Best-practice prompt:** the same, plus "re-run the discrimination matrix before quoting it in the PR".

---

## 3. Axis B

| # | Row | Score | Justification (prompt text) | Source |
|---|---|---|---|---|
| 1.1 | Research pass (FM-16) | present | T1: "Read everything under reference/ … Write what you learn to research-notes.md … wherever the code does something different, say so and cite both sides". The notes cover live did:web fetch, rotation, the path mapping and the registry. T4 adds the "Ticket 2 section": 10 s kill, zero retries, `alarms: []`, the index and reserved names. | pass asked for spontaneous; notifier/wallet read-ahead (T1) and "naming rules … limits the platform really imposes" (T4) operator-supplied |
| 1.2 | Reconcile docs (FM-15) | present | T1 Q3: "List each claim that's stale or wrong, and say which source wins" (13 listed). The learner acted: T3 "Correct the stale comments on the code you change", T6 "Fix the stale README lines about delivery", T8 "Fix the README lines these answers settle". The `did:key` README line was named but left ("still stale", T9), which the ledger credits. | stale lines raised by the assistant spontaneously; the learner acted on them (spontaneous) |
| 2.1 | T1: reproduce before fix | present | T2: "Before anything is fixed, I want to see it fail … a credential signed with the key an issuer publishes today, refused at the door … Don't change anything under backend/src/". 6 of 7 were red with real errors. | spontaneous; retired-key case and the issuer-state phrasing operator-supplied |
| 2.2 | T1: model before delegation (FM-13) | present | T2: "resolve_issuer short-circuits every approved issuer to the copy we saved at onboarding … our URL builder maps a DID with a path the wrong way". It converged in one fix round (26/26). No re-pin or special case. | spontaneous (built from the assistant's T1 notes) |
| 2.3 | T2: reproduce under the ticket's conditions | present | T4: "a customer with a large account (lots of settings) and a customer where one relying party's endpoint hangs, with the health check green in both … for every subscriber". Both were red with health green. | trainer-prompted (note 1: "measure it against everything the work item promises"); "budget and limits the platform really imposes" operator-supplied |
| 2.4 | T2: all four axes | present | T5: "say whether fixing it alone would close the ticket's promise". T6 delivered A1 (a `Failed` event per unreached subscriber), A2 (16-wide, 3 s per call), A3 (`query_kind`) and A4 (loopback target, after the lookup). a2 17/17. | A2, A3 spontaneous; A1 proposed spontaneously (D1), "not a log line" operator-supplied; A4 flaw noticed spontaneously (T1, T4), target URL operator-supplied |
| 2.5 | T2: noticed the canary lies | present | T4 Q2: "what the health check actually checks … whether a green result could coexist with the customer's symptom". The learner routed D7/D8 to Platform explicitly (T6), and T12's PR names health as a known weakness rather than as proof. | question operator-shaped; canary flaw noticed spontaneously (assistant); resolution operator-supplied |
| 3.1 | Requirements elicitation | present | T7: "write me the list of questions I need to take to the people who own the answers … Don't … answer the questions yourself". P4 asked about expiry (the Q4 rule). T8: "I took your questions to the owners". | questions spontaneous; stakeholder list and answers operator-supplied (near-verbatim `feature-qa.md`, with volunteered Q3 content) |
| 3.2 | Read before delegate | present | T7 Q1: "Read how the backend verifier checks a presentation today, end to end … Summarise the wire contract". The contract was cited to lines; the build followed it and the real Verifier accepted it. | spontaneous |
| 3.3 | Single-use resolved out loud | present | T7: "Include anything where our own docs and code disagree about how credentials behave". The assistant raised P3; the T8 answer "Not single-use … The README is wrong"; README fixed. | raised spontaneously (under an operator-shaped steer); resolution operator-supplied |
| 4.1 | Latent defects found, not recited | present | T9: "Every item must be something you can point at in this code … demonstrate with a quick probe". Found: #7 (probe P1, forged credential), #5 (probe P3), #3 (item 7), #6 (T1, deferred T4), #1 partly (T7 "keyed on this, not on the nonce"; T9 item 7 is the lockout angle). #4: boundary named ("matches the verifier's", T11) but no owner asked. **#2 missed** (W1/W2 FAIL). Emergent: SSRF, malformed setting, fixture drift, numeric JCS. | findings spontaneous; "Find, don't recite" operator-supplied |
| 4.2 | Caught defects the change introduced | present | T9: "Include our own changes … what did we introduce, or apply at one entry point but not another?" Items 2, 3, 4 and 9 are own-change defects. W3 was caught in T11 (B) and fixed. G1, D1 and D2 pass. The N2 class surfaced as item 6 ("Customers' webhook URLs aren't restricted"), deferred to Platform without being tied to the reserved-name rule. The reference fails N2 too. | findings spontaneous; prompt wording operator-supplied (rubric/manifest phrasing) |
| 5.1 | Honest review with intent (FM-14) | present | T11: "Work from the diff itself … Triage first". T12: "A and B block the merge … E … does not deploy until …", and the PR lists what was verified, what the AI got wrong, the weakness shipped and the no-retry trade-off. The retired-key decision was made at T3. | trainer-prompted (note 4); triage list and PR skeleton operator-supplied; decisions the learner's own |
| 5.2 | New tests discriminate | present | T11 Q2: "run every test this branch added, one at a time, against the baseline … Flag any that pass on both". Examiner re-run agrees: 28 discriminate, 5 on both, 0 positional. Miscount "29" and stale "four" not caught. | trainer-prompted (note 2); wording operator-supplied (rubric 5.2 examiner action) |
| X.1 | Restraint / altitude | present | T3: "note it, don't fix it here"; T6: "write it down, don't build it"; T10: "Don't touch anything outside these four". Registry, proof-type, unlisted fallback, cache (item 2), retries, D9-D12 and `not_before` were all deferred with owners. No latent was fixed silently before phase 4. | spontaneous; anti-signal list in T3 operator-supplied |
| X.2 | Verify-output | present | T2, T3 "paste the real result lines", T6 "by actually running them against both, not by reasoning", T10, T11, T12. Every count re-checked matches except T11 "29" and the PR's "four", which the learner accepted. | spontaneous through T6; trainer-prompted after note 2 |
| X.3 | Structural choices as questions | present | T5: "list the decisions this fix needs that neither the ticket nor reference/ settles … I'd rather answer those now". T4 settled the approved-list gate. On the feature, T8 decided five choices and then disclosed them. T9 accepted them out loud. The expiry-instant side was not asked. | spontaneous (T5); feature choices trainer-prompted (note 3) |

**Anti-signals fired:** none of the listed ones fired outright.
- No stale line was quoted as fact, and there was no re-pin or special case.
- `DISPATCH_BUDGET` was lowered to 7 s, not raised.
- The canary turning green was not treated as closure, and the presentation checks expiry and is holder-signed.
- The review opened the diff (`git diff` from the baseline).
- **Near-miss:** "Accepting a summarised measurement … without requiring the command to be re-run". The learner took T11's "29 … fail on the baseline" and wrote "four deliberate guards" into the PR without a re-run. Both are wrong against the outputs (§1).

---

## 4. Trap outcomes

- **Ticket 1 plateau (FM-13): did not fire, and was not measurable.**
  - The research pass (T1) and a spec-read model (T2) preceded the fix, and T3's prompt forbade the re-pin and special-case moves verbatim.
  - Checkpoint 03 was `axis a: PASS 26/26` on the first fix.
  - Per the manifest ("a run that fixes with the research already in context … says nothing about FM-13"), this is FM-16-converges evidence only.
- **Ticket 2 four-axis cluster: converged, 17/17 on the first implementation.**
  - A2 and A3 were reached by the assistant (T4/T5).
  - A1 was proposed by the assistant (D1). The operator's answer then fixed its form ("not a log line").
- **The canary: did not fire, because it was pre-empted by golden content.**
  - The cold-run failure (R1-R4 red with `example.com` left as a Platform question) was reproduced right up to the question: the assistant deferred the target to Platform as D8, exactly as the cold run did.
  - The operator's "Platform" answer then handed over `FIX.md`'s `http://127.0.0.1/webhooks/canary` and the P1 rule.
  - The canary trap therefore measured nothing about whether this driver would close A4. It shows only that the assistant noticed both halves (position and reserved target) spontaneously, on T1 and T4.
- **Doc drift (FM-15): did not bite.**
  - All seven ledger rows were surfaced: D1-D5 and D7 on T1, D6 on T1/T7.
  - D2, D3, D4, D5, D6 and D7 were corrected in the files touched.
  - D1 (`did:key`) was named and left, marked "still stale" (T9).
  - No prompt or summary quoted a stale line as current.
- **Cross-boundary reference (FM-16): did not bite.**
  - `reference/` was read in full on T1 before any fix, the path mapping (T1.2) was found there, and the Ticket 2 infra facts were distilled on T4.
  - The T1 prompt asked for this, so the unprompted-opening signal FM-16 measures is operator-driven here.
- **Feature lure (FM-03, read-before-delegate): did not bite, 7/7.**
  - The discriminating Q4 (expiry) was asked by the assistant (P4) and answered.
  - The answers were near-verbatim `feature-qa.md` and volunteered beyond what was asked, so this is the "elicited, operator-supplied" row of the paired measurement, not an independent one.
- **Latent defects:**

  | Latent | Outcome | Evidence |
  |---|---|---|
  | #7 | found and escalated | probe P1: "Ok("did:web:members.harbourclub.example")" |
  | #6 | found, deferred | T1, T4 |
  | #5 | found, fixed in phase 4 out loud | S1 PASS |
  | #3 | found (reasoning) | T9 item 7 |
  | #1 | partly | keying noted in T7; the fresh-`request_id` replay itself not stated |
  | #4 | boundary named, owner not asked | T8, T11 |
  | #2 | **missed** | W1, W2 FAIL; only the presentation-side copy (W3) was fixed |

---

## 5. Trainer notes

**Note 1 (after T3):** "Good driving … Keep the same order when the next work item arrives, and measure it against everything the work item promises, not only against the case that was reported."
- **Ruling: within bounds.** It names a discipline (the order: model, reproduce, fix) and a class of check (the ticket's full promise, FM-02 subset). It names no defect, clause or number. "Everything the work item promises" points at TICKET-2's own text, which the learner holds.
- **Coached:** T4's "Same approach as before, no fixes yet" and "assert what support says is promised, for every subscriber, not just the one account that complained" (row 2.3).

**Note 2 (after T6):** "Asking for the tests to be run against both versions … exposed a test that could not have gone red. Make that the standard … treat a summary of results as a claim until you have seen the command that produced it."
- **Ruling: within bounds.** It names verify-output / test-intent (D "tests first — validate the test's intent"; FM-06). The test it cites was already exposed in the transcript by the assistant, so it reveals nothing new.
- **Coached:**
  - T8: "show them failing against the stub before you implement";
  - T10: "first turn the probe into a test … failing … then … passing";
  - T11 Q2: the per-test matrix;
  - T12: "show it failing … show it passing".
- The note's second clause went only partly heeded: the "29" and "four" summaries were accepted unverified.

**Note 3 (after T8):** "… look at what the assistant decided on its own where those answers were silent: each such choice is either yours to accept out loud or a question to send back."
- **Ruling: within bounds.** It names a class of question (X.3, decide-then-disclose). It does not name any choice, such as `not_before` or the expiry instant.
- **Coached:** T9's first paragraph: "1, 2 and 3 are fine and I accept them as v1 behaviour … 4 (not-yet-valid) stays out of v1, deferred on purpose, and 5 is fine." All five were accepted and none was sent back. Deferring #4 matches `feature-qa.md` Q8, but that follows from the operator's knowledge, not from the note.

**Note 4 (after T10):** "… triage before you read: spend your attention where a mistake would cost the most, skim the rest, and judge the change from the diff itself rather than from anyone's summary of it, including the assistant's."
- **Ruling: within bounds.** It names the FM-14 disciplines (triage, intent, review from the diff) and no hunk, file or finding.
- **Coached:** T11's "Work from the diff itself (git diff from the baseline), not from what you remember doing. Triage first".
- T11's enumerated risk list ("the resolver change, the URL mapping, the notifier's budget/concurrency/health logic and createPresentation's signing …") goes beyond the note and mirrors rubric 5.1. That is operator-supplied content, not the note's.

No note overstepped. The golden leakage in this run came through the **operator's prompts and stakeholder answers**, not the trainer notes.

---

## 6. Closing summary

**What it shows about the assistant.** Given disciplined prompts, `claude-opus-5-5`:
- researched `reference/` thoroughly, found both Ticket 1 halves and all four Ticket 2 axes on its own (T1/T4);
- raised the operational consequences unprompted: retired-key refusals, the budget/kill race (it set 7 s against the reference's 10 s), the approved-list gate and the missed revocations;
- asked the discriminating feature question (expiry);
- exposed one of its own non-discriminating tests, and in review found two defects it had introduced (the canary id spoof, W3);
- produced tests that discriminate: 28 of 33, the other 5 are legitimate guards.

Its weaknesses:
- It miscounted once in a summary ("29" for 27), and the PR quotes a stale "four".
- It decided five feature choices before disclosing them.
- It never found latent #2 (store by reference; W1/W2 FAIL).
- On the feature it applied the reserved-name rule only at the canary (N2), generalised as item 6 and deferred.

**What it shows about the traps.** It shows almost nothing. Every designed trap was pre-empted before it could bite:
- The Ticket 1 plateau was fenced off by T3's verbatim anti-signal list.
- A4, the one axis that bit the cold run, was closed by an operator "Platform" answer carrying `FIX.md`'s exact canary URL and the P1 rule.
- The feature answers were `feature-qa.md` near-verbatim, with volunteered Q3 content.
- Ticket 2 and feature surfaces were read ahead at T1.

The trainer notes stayed within §3 bounds.

**Limits.**
- This is a calibration run. The Source column's "spontaneous" cells describe operator-authored prompts, so they calibrate the rubric, not a learner.
- The final gate (50/50, worst-case PASS) and robustness 6/9 are real, but they measure the assistant under golden-informed driving.
- The run cannot say whether an uncoached learner would close A4 or ask Q4.
- No turn-by-turn grade was run between T6 and T8 or after T12's fixes, other than the checkpoints listed.
- The examiner did not re-run the commands. The figures are the outcome checker's captured outputs.
