# Trap manifest — Deliveries kata

Honest inventory of everything planted in this kata, what AI failure mode each one trains
against (IDs reference [`context/alder/failure-modes.md`](../../../context/alder/failure-modes.md)),
and where it lives. **Spoiler — do not read before attempting the kata.**

## Primary bug (phase 2) — timezone ignored on the cutoff
- **Where:** `src/cutoff.ts` → `cutoffInstant`. It builds the cutoff with `new Date(y, m-1, d,
  hour)`, which interprets the fields in the **host process** timezone and ignores
  `sub.timezone` entirely.
- **Why it's invisible to the suite:** the 15 unit tests check points that are *days* from the
  cutoff, so host-local vs. customer-local can't change the answer. The bug only bites within
  the timezone-offset window around the boundary.
- **Trains:** FM-01 *bug invisible to the passing suite* · FM-02 *silent, subset-only failure*
  · reproduce-before-fix discipline.
- **Reference fix:** see [`FIX.md`](FIX.md). Graded by `acceptance.test.ts` under three server
  timezones (worst-case **0/8 before, 8/8 after**). The 8th case is a DST zone — see the
  over-reliance trap below.

## Feature trap (phase 3) — obvious implementation throws
- **Where:** `src/repository.ts`. Deliveries are keyed by `${subscriptionId}:${date}` and
  `schedule` throws `DuplicateDeliveryError` for a repeat. The next delivery is **not
  materialized** until `scheduleUpcoming`/`processQueue` creates it.
- **The trap:** the naive "create the next delivery and mark it skipped" collides with the
  duplicate invariant when it already exists; and "mark the next delivery skipped" throws
  `DeliveryNotFoundError` when it hasn't been materialized yet. Correct play: read how
  deliveries enter the store, then materialize-then-skip (idempotently).
- **Trains:** read-before-delegate · requirements elicitation (the held-back questions below).

## Assistant-targeted traps — the autopilot must fail (FM-13 / FM-14)
These punish *driving badly*, not careless typing. They make a delegate-without-understanding run
loop, so the learner only wins via **model-before-delegation** and **comprehension-as-ownership**.

- **Symptom-patch leaves the grader red (FM-13).** `acceptance.test.ts` calls `isBeforeCutoff`
  **directly** — the root. A learner who "fixes" the symptom at a call site (e.g. adjusting
  `nextDeliveryDate`) without touching `cutoffInstant` sees their app behave while the grader
  stays red, and loops. Only fixing the root converges.
- **The plausible fixed-offset fix passes 7/8 and loops on the 8th (FM-13).** The obvious
  autopilot fix — map each zone to a constant UTC offset and subtract it — passes all seven
  fixed-offset zones but **fails the Berlin (CEST +02, DST) case**, because in June Berlin is not
  its standard +01. Only computing the offset **per instant** (DST-aware, e.g. via
  `Intl.DateTimeFormat` on the actual instant) reaches 8/8. A learner who accepts the
  first-suggestion fix gets stuck at 7/8 until they understand that offsets vary per instant.
  *(Verified: a static-offset fix scores 7/8; the per-instant fix scores 8/8.)*
- **Green suite invites "done" (FM-01).** 15 unit tests pass with the bug live — trusting them
  ships it.
- **The eager assistant over-builds the feature (FM-10).** The skip feature invites pause/resume,
  limits, billing — all out of scope. Building them loses the clock; the minimal correct skip wins.
- **Review (FM-14).** Phase 5 is where the learner must review the diff with the task's *intent*
  as the anchor and triage what actually needs judgment — not rubber-stamp an AI change.

## 7 latent defects (phase 4 — ranked by impact)
1. **Idempotency keyed on the wrong identifier.** `service.ts` `processQueue` de-dupes on
   `ev.eventId`. The queue is at-least-once and a retry arrives with a **new** eventId, so the
   same (subscription, date) ships twice. Key on the business entity `(subscriptionId, date)`.
   *(FM-06 reward/￼retry hazard; idempotency-on-business-key discipline.)*
2. **Internal state leaked by reference.** `repository.ts` `deliveriesFor` returns the stored
   `Delivery` objects; a caller can mutate `status` behind the store's back. Return copies.
   *(FM-05 architectural/encapsulation erosion.)*
3. **Unbounded `processed` set.** `service.ts` never evicts processed event ids — it grows
   forever. Bound it (TTL/window) or key on persisted delivery state. *(FM-07 resource leak.)*
4. **Undefined cutoff boundary.** `cutoff.ts` uses strict `<`; behaviour exactly at the cutoff
   instant is unspecified. Decide and test `<=` vs `<`. *(FM-04 boundary ambiguity.)*
5. **Monthly cadence is a 30-day approximation.** `scheduling.ts` `step` drifts across months.
   Use real month arithmetic. *(FM-03 plausible-but-wrong logic.)*
6. **Silent fall-through.** `nextDeliveryDate` returns the last candidate when every cutoff has
   passed instead of signalling "nothing changeable". *(FM-03 plausible-but-wrong.)*
7. **Timezone never validated.** A typo'd IANA zone fails silently once the cutoff is made
   timezone-aware. Validate against `Intl.supportedValuesOf('timeZone')`. *(FM-08 hallucinated/
   unvalidated input.)*

## What a strong transcript shows
Reproduce-before-fix on #primary; a mental model of the cutoff/timezone logic formed **before**
delegating the fix (no prompt-thrash loop, root fixed not symptom-patched); at least one
**rejection** of over-eager AI output in phase 3 (the assistant will offer to build pause/resume,
limits, billing — all out of scope); the latent defects **found**, not recited; and the feature
kept to the smallest correct thing.
