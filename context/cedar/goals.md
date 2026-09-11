# Training goals — Context "Cedar" v1

What every practice generated from this Context must train. These are **disciplines** — the
behaviours that keep AI-assisted work correct — not topics to read about. Each is defeated-by
for one or more [`failure-modes.md`](failure-modes.md) and taught-by one or more
[`best-practices.md`](best-practices.md) entries.

Cedar inherits every Alder discipline and adds two core disciplines for working across boundaries
and against drifting documentation (the last two rows).

| Discipline | The learner can… | Beats | Taught by |
|---|---|---|---|
| **reproduce-before-fix** | turn a symptom into a failing test before touching the fix | FM-01, FM-02 | B2, D1 |
| **requirements-elicitation** | extract the held-back requirements from an underspecified ask before delegating | FM-03 (spec-level) | B3, D3 |
| **read-before-delegate** | map module boundaries and invariants before asking the AI to change code | FM-05, feature traps | B1 |
| **model-before-delegation** | form a concrete *HOW* of their own before delegating execution; recognize an unconvergent prompt loop and stop to build the model | FM-13 | B1, B3, E |
| **comprehension-as-ownership** | understand a change well enough to debug it before owning or merging it | FM-13, FM-05 | B1, D5 |
| **verify-output** | check AI output against the real rule, not just that it runs/compiles | FM-03, FM-06, FM-12 | B4, D1, D5 |
| **restraint / altitude-match** | build the smallest correct thing; surface concerns without building them | FM-10 | E (all) |
| **reject-on-camera** | push back on eager/over-built AI output, on the record, with the trade-off named | FM-10 | B4 |
| **establish-cross-boundary-context** | recognize when the local repo is not the whole story; gather the external references (a sibling service, cloud infra, a method spec) into an explicit context/notes file and validate assumptions against them **before** delegating | FM-16 | F1, B1 |
| **reconcile-docs / trust-code-over-prose** | treat READMEs, comments, and contracts as potentially stale; verify each invariant against the current code and the authoritative reference; flag and reconcile contradictions instead of following the most convenient doc, and never treat a large green suite as proof | FM-15 | F2, D5 |
| **idempotency-on-business-key** *(optional)* | key retried work on the business entity, not the transport event | FM-06 | — |
| **validate-external-input** *(optional)* | validate identifiers/packages against an authoritative set; never trust a hallucinated symbol | FM-08 | D5 |
| **manage-context** *(optional)* | keep the source of truth in files, re-state constraints, clear between tasks | FM-09 | D4 |
| **review-with-triage+intent** *(optional)* | triage what needs human judgment vs. what's safe to skim, anchor any review on the task's intent, and stay accountable for the merge | FM-14 | D5 |
| **incremental-reversible-change** *(optional)* | make small, testable, reversible changes and keep the working state reproducible and shared | FM-10, FM-13 | D, E |

## The shape that trains them
A practice that trains the core disciplines gives the learner, in order:
1. an **unfamiliar codebase** to understand (read-before-delegate),
2. a **symptom, not a location** (reproduce-before-fix),
3. an **underspecified feature** with held-back requirements and a trap the naive prompt trips
   (requirements-elicitation, read-before-delegate),
4. **latent defects** to find rather than recite (verify-output),
5. an **eager assistant** that will happily over-build (restraint, reject-on-camera),
6. a **runnable hidden grader** so "looks done" is never the only signal (verify-output),
7. a **trap for autopilot** — a place where delegating without a model provably loops:
   symptom-patching leaves the grader red, and the "obvious" fix the assistant proposes passes
   the visible suite but misses a case that needs real understanding. The learner escapes only
   by *model-before-delegation* and by owning what they merge (comprehension-as-ownership).
8. **truth that lives across a boundary, wrapped in drifting docs** — the authoritative contract
   for at least one defect lives only in a read-only `reference/` (a sibling service, cloud infra,
   a method spec), while the repo's own docs contradict the current code from a half-finished
   migration and a long-untouched code path still encodes an abandoned assumption no doc mentions.
   The learner escapes only by a **research pass** that distills the reference into their own
   notes (establish-cross-boundary-context) and by **reconciling the docs against the code**
   rather than trusting either the convenient README or the green suite (reconcile-docs).

Elements 1–7 are the same five-phase flow every kata runs (understand → fix → feature → improve →
review). Element 8 is Cedar's addition: it does **not** add a phase — the **research pass lives
inside `understand`**, an explicit expectation that before touching code whose truth spans a
boundary the learner first gathers the reference into `research-notes.md`. The domain and stack
change; these goals do not.
