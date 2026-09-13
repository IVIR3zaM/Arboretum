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
  timezones — 8 cutoff cases of the grader's 13 (worst-case **0/13 before, 13/13 after**). The
  8th cutoff case is a DST zone — see the over-reliance trap below.

## Feature trap (phase 3) — obvious implementation throws
- **Where:** `src/repository.ts`. Deliveries are keyed by `${subscriptionId}:${date}` and
  `schedule` throws `DuplicateDeliveryError` for a repeat. The next delivery is **not
  materialized** until `scheduleUpcoming`/`processQueue` creates it.
- **The trap:** the naive "create the next delivery and mark it skipped" collides with the
  duplicate invariant when it already exists; and "mark the next delivery skipped" throws
  `DeliveryNotFoundError` when it hasn't been materialized yet. Correct play: read how
  deliveries enter the store, then materialize-then-skip (idempotently).
- **Graded, not just asserted.** Five of the grader's 13 cases cover the minimal agreed behaviour
  from [`feature-qa.md`](feature-qa.md), through the public surface only (no error class is
  named, so any sensible refusal counts). Measured against a correct cutoff fix: *"mark the next
  one skipped"* scores **9/13** (`DeliveryNotFoundError`), *"create it, then skip it"* **11/13**
  (`DuplicateDeliveryError`), the reference shape **13/13**. Two of the five pin answers that are
  not deducible from the repo — skip is idempotent, and an already-shipped box is refused — so a
  learner who never asks the PM can still lose them.
- **Trains:** read-before-delegate · requirements elicitation (the held-back questions below).

## Assistant-targeted traps — the autopilot must fail (FM-13 / FM-14)
These punish *driving badly*, not careless typing. They make a delegate-without-understanding run
loop, so the learner only wins via **model-before-delegation** and **comprehension-as-ownership**.

- **Symptom-patch leaves the grader red (FM-13).** `acceptance.test.ts` calls `isBeforeCutoff`
  **directly** — the root. A learner who "fixes" the symptom at a call site (e.g. compensating for
  the zone inside `nextDeliveryDate`) without touching `cutoffInstant` sees their app behave while
  the grader stays red, and loops. Only fixing the root converges. *(Verified 2026-09-13: a
  call-site compensation keeps the unit suite at 15/15 and the grader at **0/13**.)*
- **The plausible fixed-offset fix plateaus and loops on the DST case (FM-13).** The obvious
  autopilot fix — map each zone to a constant UTC offset and subtract it — passes all seven
  fixed-offset zones but **fails the Berlin (CEST +02, DST) case**, because in June Berlin is not
  its standard +01. Only computing the offset **per instant** (DST-aware, e.g. via
  `Intl.DateTimeFormat` on the actual instant) clears the cutoff half. A learner who accepts the
  first-suggestion fix sits on that plateau until they understand that an offset is a property of
  an instant, not of a zone. *(Verified 2026-09-13: a static-offset fix scores **7/13**; the
  per-instant fix clears all 8 cutoff cases.)*
- **Green suite invites "done" (FM-01).** 15 unit tests pass with the bug live — trusting them
  ships it.
- **The eager assistant over-builds the feature (FM-10).** The skip feature invites pause/resume,
  limits, billing — all out of scope. Building them loses the clock; the minimal correct skip wins.
- **Review (FM-14).** Phase 5 is where the learner must review the diff with the task's *intent*
  as the anchor and triage what actually needs judgment — not rubber-stamp an AI change.

## What the control run actually showed (2026-09-13) — read this before trusting the traps

> The complementary evidence is [`proof-train-2026-09-13.html`](proof-train-2026-09-13.html): a
> staged Train-mode run where a casual engineer takes the shortcut in all five phases and **every
> trap below fires**. Read the two together — the control run is the ceiling (what an assistant
> reaches with no learner at all), the Train run is the thing being measured (how a learner
> drives).

The mechanisms above are real, and every number in them is measured. They are still not what
decides a run. On 2026-09-13 this kata was given to a **fresh frontier assistant with one casual,
uncoached prompt** — *"here's a ticket and a feature request, fix the bug and implement the
feature"* — in a harness-shaped clone, with no follow-up. It was run twice:

| Control run | Material the clone carried | Grader |
|---|---|---|
| **A** | the practice as it shipped before this date | **13/13** |
| **B** | the same code with every coaching line cut out | **13/13** |

Both runs fixed the root in `cutoffInstant` with a per-instant `Intl` conversion, both handled
the DST gap and fold deliberately, both wrote timezone regression tests first, and both got the
feature right *around* the store's invariant — materialize-then-skip, idempotent, refusing a
shipped box. Run B, with nothing to go on but the ticket, also named the fall-through in
`nextDeliveryDate` and the 30-day month as pre-existing issues it was deliberately leaving alone.

Two conclusions, and the second one is the important one:

1. **Run A exposed a leak, and it has been fixed.** The material was doing the learner's job: the
   ticket prescribed the method ("reproduce it first"), named the mechanism ("regardless of where
   our servers run") and named the grade command; the feature request flagged its own trap with a
   ⚠️; the README described the fixed-offset plateau; `practice.json` stated the planted bug in a field the
   clone carried; `package.json` advertised a hidden grader; the unit suite confessed its own
   blind spot in a header comment. An assistant that reads any of that has been coached by the
   instrument measuring it. All of it is out of the clone now (Context `alder@1.2.0` invariant 10).
2. **Cutting the coaching did not make the traps bite.** Run B scored the same 13/13. For a
   frontier assistant the objective gate is a **floor, not a discriminator** — and the honest
   response is to say so here rather than to invent a subtler timezone gotcha until the score
   comes out flattering. `README.md` no longer claims the traps are "invisible to a naive prompt";
   what it claims is what is true.

**So what still separates a good run from a bad one?** Exactly the things the control run could
not do, all of them on the driving axis:
- **It could not ask.** Idempotency and the shipped-box refusal are not deducible from the repo —
  run B guessed both, then flagged idempotency as "the ambiguity I'd most want confirmed", which
  is precisely the question a learner is supposed to have asked the PM *before* writing the code.
  The learner who asks gets the answer; the learner who guesses is betting.
- **It did not hold scope.** Asked to fix a cutoff and add a skip, both runs also rewrote the
  "today" computation in `scheduling.ts` and `service.ts`, and one edited `demo.ts`. Plausible
  changes, none of them requested — FM-10 in its natural habitat, and the failure a 60-minute
  exercise is supposed to punish.
- **Nobody reviewed it.** Both runs handed back a diff with a confident summary. Phase 5 exists
  because that summary is the cheapest thing in the transcript and the easiest to rubber-stamp.

The practice's value for a strong assistant is therefore the **transcript**, not the score. Grade
accordingly: a 13/13 with no questions asked, unrequested modules touched and a rubber-stamp
review is a **worse** run than a 12/13 that asked, stayed inside the ask, and named its own
weakness.

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
