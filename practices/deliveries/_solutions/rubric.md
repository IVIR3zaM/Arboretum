# Rubric — Deliveries kata

Two axes. The objective gate is necessary but not sufficient; the driving axis is what this
platform is actually teaching.

## A. Objective gate (the oracle)
- [ ] `node --test test/*.test.ts` still green after the fix (no regressions).
- [ ] `node _solutions/grade.mjs` → **13/13 worst-case** across all three server timezones: 8
      cutoff cases (incl. the DST case) + 5 for the skip feature.
- [ ] Feature: `skipNextDelivery` implements the minimal agreed behaviour — materializes the next
      box if needed, is idempotent, and refuses a box that has already shipped.

**This gate is a floor, not a verdict.** A frontier assistant clears all 13 from one uncoached
prompt (measured — see [`trap-manifest.md`](trap-manifest.md)). A clean score with a bad
transcript is a bad run; score axis B honestly and let it decide.

## B. How you drove (scored from the transcript)
Each worth noting; a strong run shows most of them.

1. **Reproduce before fixing.** A failing test demonstrating the wrong cutoff decision was
   written *before* any fix. (Miss: jumping straight to a patch.)
2. **Timezone correctness, not machine correctness.** The fix converts the customer's wall-
   clock cutoff to an instant using `sub.timezone` — not the host offset, not a hardcoded one.
3. **Requirements gathered before delegating the feature.** Several of the eight held-back
   questions were asked before code was written. (Miss: implementing an assumed spec.)
4. **Restraint / altitude match.** The feature is the smallest correct thing. Out-of-scope
   work (limits, billing, pause/resume, un-skip) was **named and deferred**, not built.
   (Miss: over-engineering — the most common failure on this kata.)
5. **Rejected eager AI output at least once.** When the assistant offered more than the spec
   asked, it was pushed back on, on the record.
6. **Read before delegating.** The repository's duplicate-delivery invariant was understood
   before the feature was implemented (no "why does it throw?" surprise).
7. **Latent defects found, not recited.** Phase-4 issues were surfaced from the code with
   evidence, not listed from general knowledge.
8. **Honest review.** A real weakness in the candidate's own change was named, with the
   trade-off and the condition that would make them revisit it.
9. **Model before delegation (FM-13).** Built an understanding of the cutoff/timezone logic
   before delegating the fix — fixed the *root*, didn't thrash-loop on symptom patches, and
   didn't settle for a fixed-offset shortcut that stalls at 7/13.
10. **Review with intent and triage (FM-14).** In phase 5, reviewed the diff against the task's
    *intent* and triaged what actually needed human judgment — not a rubber-stamp.

## Anti-signals (the failure classes this kata exists to catch)
- **A full score with nothing on axis B.** No question asked about the two rules the brief does
  not state (is skip idempotent? can a shipped box be skipped?), modules touched that nobody
  asked about, and a review that rubber-stamps the assistant's own summary. This is what an
  uncoached one-shot looks like, and it is the run this kata exists to distinguish from a good
  one.
- Over-engineering a 60-minute exercise to production altitude (building for cases the spec
  didn't ask for). **This is the headline failure.**
- Accepting a green `npm test` as "done" without the timezone reproduction.
- Pasting AI output unread; never rejecting anything.
- A feature that throws on the duplicate invariant because the store wasn't read first.
- Cycling prompts without a model — a "just fix it" loop that patches symptoms or hardcodes an
  offset and never reaches 13/13 (delegation before comprehension).
