# rubric — grading `fulfillment`

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Grade from three inputs
> per AGENTS.md rule 5: this golden context, the learner's prompt transcript, and the result in
> the cloned folder (diff + the declared `commands.test` / `commands.grade`, run by the examiner).

## Axis A — objective gate (mechanical, run the commands)

Pass/fail, worst-case. This axis does not require reading the transcript.

1. **Backend unit suite stays green.** `commands.test` for `backend/` (`node --test`) still
   23/23 after the learner's changes — a fix that breaks existing coverage to pass the grader is
   not acceptable.
2. **Web unit suite stays green.** `commands.test` for `web/` (Vitest/RTL) still 10/10.
3. **`bash _solutions/grade.sh` exits 0** — the whole-ticket gate, three parts, all at full marks:
   (a) **availability acceptance** (`_solutions/backend-acceptance.test.ts`, worst-case across all
   SKU states + conformance vectors, **14/14**); (b) **feature acceptance**
   (`_solutions/feature-acceptance.test.ts`, the cart hold driven through its public surface,
   **10/10**); (c) **web integration** (`_solutions/web-integration.test.tsx`, **2/2**). Anything
   short of all three at full marks is a FAIL on this axis regardless of how good the transcript
   looks. Verified baseline availability 6/14 · feature 0/10 · web 1/2 → post-solution 14/14 · 10/10 ·
   2/2 (see `FIX.md`, `FEATURE-FIX.md` and `trap-manifest.md`).
4. **Feature is objectively gated, and the gate discriminates.** `FEATURE-REQUEST.md` looks easy
   and five of its lines lure an assistant onto the wrong rule. Gate (b) holds 10 tests: 1–4 check
   that the hold reserves at all (live ATP net of other carts, keyed on `(SKU, cart)`, re-checked at
   confirm, own hold not counted), and 5–10 check the rules only elicitation returns (last unit,
   whole quantities, orderId identity, partial checkout, re-place/restart, store-wide sweep —
   `feature-qa.md` Q3, Q4, Q10–Q13). Measured 2026-09-19: the 2026-09-16 naive one-shot hand-off
   **5/10**, that run's elicited build `444ab3b` **8/10** (its meeting never asked Q11 or Q13), the
   reference elicited build **10/10** (`FEATURE-FIX.md`). 10/10 is required. A red gate names the
   rule it caught, so it tells you which question went unasked: read that against the transcript
   in Axis B's requirements-elicitation row. TTL release is gated too (tests 9 and 10). Until
   2026-09-19 the gate held tests 1–4 only and a naive hand-off could score 4/4. Runs graded before
   then are graded against that gate.
5. **Robustness probes — non-blocking, not part of the 26-point gate.** From the practice root of the
   graded copy, run `node --test --test-reporter=tap _solutions/robustness-probes.test.ts` and report
   **`robustness n/5`** (`# pass` over `# tests`) next to the gate result. The file is not wired into
   `grade.sh`, and it never changes this axis's pass/fail or the grade exit code: a gate PASS with a low
   robustness score is still a PASS. The five probes drive oversell vectors gate (b) cannot see:
   (1) a caller mutating the `Hold` that `placeHold` returns; (2) the store's exported `place()` taking
   `qty <= 0`; (3) an order for 0 units confirmed at ATP 0; (4) a partial checkout releasing the whole
   hold; (5) a second confirm for the same `orderId` under a new `requestId`.
   Since the 2026-09-19 redesign probes (3), (4) and (5) overlap gate (b) tests 6, 8 and 7, so on a
   gate PASS they hold; (1) and (2) are code-shape defects no stakeholder states, and stay probe-only. Each uses its own SKU, so a probe run alone (`--test-name-pattern="robustness <k>:"`) scores as
   it does in the full file. The shipped stub scores 0/5. The Train run 2026-09-16 final tree (444ab3b)
   scored **robustness 2/5** at the then 20-point gate's 20/20: only (2) and (4) held. Read a failing probe as a defect the
   change introduced that phase 4/5 did not close. It is evidence for Axis B's "Caught defects the change
   itself introduced" row, not a score of its own.

## Axis B — driving axis (scored from the transcript; requires reading it)

Score **every** row below as `present` / `absent` / `partial` with a one-line justification citing
the actual prompt text, **and a Source column** saying where the move came from: `spontaneous` (the
learner or their assistant, unasked), `trainer-prompted` (it followed a Trainer interjection — see
`harness/DESIGN.md` §3, Mode TRAIN) or `operator-supplied` (the prompt carries content only the
golden context could have supplied — see `AGENTS.md` rule 10). A row whose move has more than one
origin names each part (e.g. `reference opened spontaneous; cited notes trainer-prompted`). **Fill in every row, including for phases the learner skipped** — a skipped
phase must show as a run of `absent` rows, not as silence. This matters because the objective gate
(Axis A) covers only phases 2–3, so this checklist is the
*only* record of how phases 1, 4 and 5 were driven. No credit for the *right answer appearing in the
diff* if the transcript shows it was reached by luck (e.g. pasting a formula guessed from the local
field names without ever reading `reference/atp-spec.md` or articulating why the `live` branch was
wrong).

### Phase 1 — understand / research
- [ ] **Research pass (FM-16).** Did the learner open `reference/` before delegating a fix, and
  produce a `research-notes.md` inside `work/` distilling the cross-boundary contract (live query,
  `(sku, location)` key, ATP ≠ on-hand, the authoritative location set, the lead-time formula)?
  Absence of `research-notes.md` (or one that just restates the ticket without citing
  `atp-spec.md`/`erp-availability-contract.md`) is a clear miss.
- [ ] **Reconcile-docs (FM-15).** Did the learner notice and call out the stale
  `backend/README.md`/`web/README.md` claims (or the misleading "nightly snapshot" comment) rather
  than trusting them, or worse, "fixing" toward what the stale docs describe (patching something
  `stock_count`-shaped)? Quoting a stale doc as current truth without flagging it fails this row
  even if the final diff is correct.

### Phase 2 — fix the bug
- [ ] **Reproduce-before-fix (FM-01).** Did the learner establish the failure *before* proposing a
  change — e.g. running the confirm/availability path against a contended SKU under
  `ATP_SOURCE=live`, or otherwise demonstrating the oversell — rather than editing on the strength
  of the ticket text alone?
- [ ] **Model-before-delegation (FM-13).** Did the learner reach a concrete understanding of *why*
  `availableToPromise`'s `live` branch was wrong — in their own words — before asking for the fix?
  Anti-signal: two or more non-converging rounds (a symptom-patch, then a hard-coded-SKU attempt,
  each declared "fixed" without checking the grader) before landing on the root cause — the thrash
  loop of `trap-manifest.md`'s Traps A/B.

### Phase 3 — build the feature
- [ ] **Requirements elicitation.** Did the learner ask or answer (even in their own planning,
  stated in the transcript) something close to `feature-qa.md`'s held-back questions —
  decrement-vs-advisory, the `(SKU, cart)` key, TTL release, re-check-at-confirm, and the lure
  lines (last unit, valid quantities, partial checkout, re-placing, what makes two confirms the
  same order) — before prompting for an implementation? Did they take the answers to the people who
  own them (PM, platform, ERP lead) rather than accept the assistant's picks? A one-shot "implement
  the cart hold" prompt with no elicitation is the anti-pattern. Credit questions the learner had
  the assistant draft and then took to stakeholders. Cross-check with gate (b): each red test names
  a rule whose question was not asked or not answered.
- [ ] **Cross-boundary contradiction raised (FM-16, `feature-qa.md` Q9).** Did the learner (or its
  assistant) notice that a local hold layered over ERP ATP contradicts
  `erp-availability-contract.md` §89–90, and that the contract is query-only, and **pause for a
  human decision** rather than silently ignoring the contract or silently abandoning the feature?
  **Credit the pause — do not read it as a failure to deliver.** Resolving it unilaterally in either
  direction is the miss; surfacing it is the success.

### Phase 4 — improvements
- [ ] **Latent defects found, not recited.** Did the learner's own review (not a request to "list
  bugs") surface any of the ranked latent defects in `trap-manifest.md` (idempotency key choice, the
  by-reference returns — now four instances, the orders `processed` cache that never evicts, boundary
  comparisons, the unvalidated location) as something *they noticed reading the diff/code*, versus
  generic concerns that map to nothing in this codebase? Credit emergent (unplanted) findings too — see
  the manifest's emergent section. **A latent defect fixed silently before phase 4 is neither "found"
  nor "missed"** — it was never looked for, so it cannot count on this row either way. Score it on the
  restraint row below.
- [ ] **Caught defects the change itself introduced.** Did phase 4 catch oversell/robustness vectors
  the feature *added* — above all state handed out by reference (mutating the `Hold` that
  `placeHold` returns changes another cart's availability) and the exported `place()` accepting
  qty ≤ 0? This is the FM-14/verify muscle applied to the learner's own diff, and the objective gate
  is blind to both (robustness probes 1–2). Quantity validation on
  `placeHold` itself is gated since 2026-09-19 (gate (b) test 6), so it is no longer evidence here.

### Phase 5 — review
- [ ] **Honest review with intent (FM-14).** Does the final review show triage — distinguishing what
  needed careful scrutiny (the resolver root, the idempotency key) from what was safe to skim
  (catalog listing, types) — anchored to the task's intent (fix the oversell; ship a minimal cart
  hold), with a human/learner decision recorded about what to act on now versus flag for later,
  rather than a blanket "LGTM" or an unfiltered dump of every possible nit?
- [ ] **New tests actually discriminate (order-independence).** Did the review check that the
  learner's *new* tests fail when the new code is broken and pass in isolation — not just that the
  suite is green as a whole? **Examiner action:** run the learner's new tests individually
  (`node --test --test-name-pattern=…`) and report any that pass only positionally. In the Train run
  `holds.test.ts` depended on holds placed by earlier tests (module-singleton store, no reset) and
  one test's *name* described behaviour it did not assert; a green suite hid both.

### Cross-phase behaviours (score once, over the whole transcript)
- [ ] **Restraint / altitude-match (FM-10).** Is the cart hold kept to the minimal surface
  (`feature-qa.md`), with anything extra (configurable TTL, multi-SKU holds, a caching layer) *named
  and explicitly deferred* rather than silently built or silently ignored? Same for the primary fix:
  did the learner raise the caching/TTL-on-live-ATP question (`FIX.md`'s aside) without building it?
  A planted latent defect fixed silently before phase 4 is scored **here**, not on the phase-4 row:
  the unasked fix is the over-build, and splitting it back out and deferring it out loud is the
  recovery. In the Train run 2026-09-16 a hasty "make it right" fix prompt came back as a 13-file diff
  that pre-fixed the boundary comparison and the location check inside the bug fix; only the
  learner's revert kept them findable in phase 4.
- [ ] **Structural choices surfaced as questions, not disclosed after the fact.** When the change
  needed a structural decision (e.g. altering `active()`'s signature to be expiry-aware, or adding a
  module to break an import cycle), did the learner have the assistant *ask before acting* rather
  than decide-then-disclose? Both such moves in the Train run were defensible but surfaced only
  because a standing "tell me instead of doing it" instruction was in play — the mild end of FM-10
  restraint, invisible to the gate.
- [ ] **Verify-output: claims re-run, not summarised (FM-01, one level up).** Did the learner ever
  require a measurement to be *re-run* rather than accept a summary of it, and did that produce a
  correction? Worked example from the Train run: the assistant asserted "the original bug caused 6
  failures," the learner demanded the real runs pasted, and the true number was **10** — right about
  the conclusion, wrong about the evidence, the hardest case to catch. Second data point, the
  under-count direction (Train run 2026-09-16, R10): the assistant reported "web tests 14/14" while its
  own pasted run in the same reply read `1 failed | 18 passed (19)` and the examiner's `commands.test`
  gave `19 passed (19)`; the learner's R11 "don't tell me — re-run" got "The 14 … was stale" and a
  real `22 passed (22)`. The single most valuable behaviour a run can exercise, and it moves no
  objective score.
- [ ] **No leaning on non-discriminating green tests.** Did the learner avoid (or catch) an argument
  that rests on a test passing when it *could not have failed*? A test green under both the old and
  the new behaviour is not evidence of compatibility — it is evidence the test is weak. The Train
  run's assistant justified a semantics change under a kept name this way and retracted it two rounds
  later. Same shape as the primary bug, one level up.

### Anti-signals (any of these pulls Axis B down regardless of the final diff's quality)
- Declaring victory after the local unit suite goes green, without ever running (or asking to run)
  the hidden grader / `bash _solutions/grade.sh`.
- Quoting `backend/README.md`'s `stock_count` line or `web/README.md`'s `GET /stock` as current
  fact in a prompt or in the delivered summary.
- A fix that special-cases a SKU id (string-compares `order.sku === "SKU-1002"` or similar) anywhere
  in the delivered diff.
- A cart-hold implementation with no expiry/sweep path, or one that checks availability once at
  "add to cart" and never again at confirm.
- Treating the assistant's first plausible-looking diff as done without reading it — no comment in
  the transcript on *why* the diff is correct, only that it "looks right" or "the tests pass."
- Accepting a summarised measurement (a failure count, a "tests pass") without ever requiring the
  underlying command to be re-run, or leaning on a green test that could not have gone red.
- A review answered from a summary or ticket list without reading the diff. Train run 2026-09-16,
  R12: asked "is it good to merge? just a yes/no", the assistant made one tool call
  (`git status --short; git log --oneline 41055ac..HEAD; sed -n 5,9p TICKETS-TODO.md`) and answered
  "Not yet, as one PR" with real blockers — never opening the diff, and never declining to sign off on
  code it wrote. Not a rubber stamp, and not a review.
