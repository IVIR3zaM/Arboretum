# Held-back requirements — "Skip my next box"

The PM brief is three sentences on purpose. These are the eight questions a strong learner
surfaces; the facilitator (or the grading agent) answers them **only when asked**. Leaving
them unasked is the requirements-gathering miss the feature is designed to catch.

1. **Does skipping shift the whole cadence, or just drop that one box?**
   → Drop that one box. The following deliveries stay on the original cadence dates.
2. **Can a box be skipped after its cutoff has passed?**
   → No. Skipping is only allowed while the box is still changeable (before cutoff).
3. **Is there a limit on consecutive skips?**
   → Out of scope for v1. Do not build a limit; note it as a follow-up.
4. **Does a skipped box still count toward billing?**
   → Out of scope for v1 (billing is a different service). Don't model it.
5. **What happens to an already-queued / in-flight delivery for that date?**
   → If it's already `delivered`, skip is rejected. If `queued`, it may still be skipped
     before cutoff.
6. **Can a skip be undone before cutoff?**
   → Not required for v1. Don't build un-skip; note it.
7. **Should skip be idempotent (skipping an already-skipped box)?**
   → Yes. Skipping an already-skipped box is a no-op, not an error.
8. **Does "skip" mean this one delivery, or pause the whole subscription?**
   → This one delivery only. Pause/resume is a separate, larger feature — out of scope.

**Minimal correct behaviour:** resolve the next changeable delivery date (before cutoff),
materialize it if needed, set its status to `skipped`, and return it; a second call is a no-op.
Anything beyond that (limits, billing, un-skip, pause) is correctly **deferred out loud**, not
built.
