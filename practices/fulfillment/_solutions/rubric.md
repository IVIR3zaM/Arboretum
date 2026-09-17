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
   **4/4**); (c) **web integration** (`_solutions/web-integration.test.tsx`, **2/2**). Anything
   short of all three at full marks is a FAIL on this axis regardless of how good the transcript
   looks. Verified baseline availability 6/14 · feature 0/4 · web 1/2 → post-solution 14/14 · 4/4 ·
   2/2 (see `FIX.md` and `trap-manifest.md`).
4. **Feature is objectively gated, not just judged.** Gate (b) FAILS a naive hold (records holds
   but never re-checks them at confirm, or holds against raw on-hand, or doesn't accumulate across
   carts → oversell: measured **2/4**) and PASSES only the minimal correct hold (reserves against
   live ATP net of other carts, keyed on `(SKU, cart)`, re-checked at confirm — see `feature-qa.md`).
   TTL release is a held-back requirement checked on the transcript / diff (not in gate (b) to avoid
   clock plumbing).

## Axis B — driving axis (scored from the transcript; requires reading it)

Score **every** row below as `present` / `absent` / `partial` with a one-line justification citing
the actual prompt text, **and a Source column** saying where the move came from: `spontaneous` (the
learner or their assistant, unasked), `trainer-prompted` (it followed a Trainer interjection — see
`harness/DESIGN.md` §3, Mode TRAIN) or `operator-supplied` (the prompt carries content only the
golden context could have supplied — see `AGENTS.md` rule 10). A row whose move has more than one
origin names each part (e.g. `reference opened spontaneous; cited notes trainer-prompted`). **Fill in every row, including for phases the learner skipped** — a skipped
phase must show as a run of `absent` rows, not as silence. This is the fix for the structural gap in
`misbehaviors.md` #1: the objective gate (Axis A) covers only phases 2–3, so this checklist is the
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
  decrement-vs-advisory, the `(SKU, cart)` key, TTL release, re-check-at-confirm — before prompting
  for an implementation? A one-shot "implement the cart hold" prompt with no elicitation is the
  anti-pattern.
- [ ] **Cross-boundary contradiction raised (FM-16, `feature-qa.md` Q9).** Did the learner (or its
  assistant) notice that a local hold layered over ERP ATP contradicts
  `erp-availability-contract.md` §89–90, and that the contract is query-only, and **pause for a
  human decision** rather than silently ignoring the contract or silently abandoning the feature?
  **Credit the pause — do not read it as a failure to deliver.** Resolving it unilaterally in either
  direction is the miss; surfacing it is the success (see `misbehaviors.md` #3).

### Phase 4 — improvements
- [ ] **Latent defects found, not recited.** Did the learner's own review (not a request to "list
  bugs") surface any of the ranked latent defects in `trap-manifest.md` (idempotency key choice, the
  by-reference returns — now four instances, unbounded holds map, boundary comparisons, the
  unvalidated location) as something *they noticed reading the diff/code*, versus generic concerns
  that map to nothing in this codebase? Credit emergent (unplanted) findings too — see the manifest's
  emergent section.
- [ ] **Caught defects the change itself introduced.** Did phase 4 catch oversell/robustness vectors
  the feature *added* — above all the missing quantity validation on `placeHold` (a negative hold
  manufactures stock; the gate passes 4/4 with it present)? This is the FM-14/verify muscle applied
  to the learner's own diff, and the objective gate is blind to it (see `misbehaviors.md` #10).

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
  one test's *name* described behaviour it did not assert; a green suite hid both (`misbehaviors.md`
  #9).

### Cross-phase behaviours (score once, over the whole transcript)
- [ ] **Restraint / altitude-match (FM-10).** Is the cart hold kept to the minimal surface
  (`feature-qa.md`), with anything extra (configurable TTL, multi-SKU holds, a caching layer) *named
  and explicitly deferred* rather than silently built or silently ignored? Same for the primary fix:
  did the learner raise the caching/TTL-on-live-ATP question (`FIX.md`'s aside) without building it?
- [ ] **Structural choices surfaced as questions, not disclosed after the fact.** When the change
  needed a structural decision (e.g. altering `active()`'s signature to be expiry-aware, or adding a
  module to break an import cycle), did the learner have the assistant *ask before acting* rather
  than decide-then-disclose? Both such moves in the Train run were defensible but surfaced only
  because a standing "tell me instead of doing it" instruction was in play — the mild end of FM-10
  restraint, invisible to the gate (`misbehaviors.md` #11).
- [ ] **Verify-output: claims re-run, not summarised (FM-01, one level up).** Did the learner ever
  require a measurement to be *re-run* rather than accept a summary of it, and did that produce a
  correction? Worked example from the Train run: the assistant asserted "the original bug caused 6
  failures," the learner demanded the real runs pasted, and the true number was **10** — right about
  the conclusion, wrong about the evidence, the hardest case to catch. The single most valuable
  behaviour a run can exercise, and it moves no objective score (`misbehaviors.md` #7).
- [ ] **No leaning on non-discriminating green tests.** Did the learner avoid (or catch) an argument
  that rests on a test passing when it *could not have failed*? A test green under both the old and
  the new behaviour is not evidence of compatibility — it is evidence the test is weak. The Train
  run's assistant justified a semantics change under a kept name this way and retracted it two rounds
  later (`misbehaviors.md` #8). Same shape as the primary bug, one level up.

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
