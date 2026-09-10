# Practice file skeletons

Copy these shapes when generating a practice. The seed kata
[`practices/deliveries/`](../../../practices/deliveries/) is the worked reference — mirror its
structure and register, changing only domain and stack.

## `TICKET.md` (phase 2) — a symptom, never a location
```
# Support ticket #<n> — "<customer's words>"
**Severity:** <low|medium> — <recurring? who's affected?>
> <the customer symptom, in plain language. what they saw, when, that it's
>  only *some* users/inputs/environments, and that the suite is green.>
**What we know:** <the intended rule, stated plainly — no file, no line>
**Your job:** reproduce first (a failing test), then fix for EVERY case. `npm run grade` checks it.
```

## `FEATURE-REQUEST.md` (phase 3) — 2–3 sentences, underspecified
```
# Feature request — "<short name>"
From the PM:
> <2–3 sentences. A real ask with the hard decisions left out.>
Expected surface: `<Service.method(...)>` (currently a stub). Build the smallest correct version.
> ⚠️ There is a real constraint in the code the obvious implementation trips over. Read <X> first.
```
The 6–8 held-back requirement questions + answers go in `_solutions/feature-qa.md`.

## `README.md` (learner-facing)
Mirror the seed: a one-paragraph domain intro, a setup block, the **estimate table** (time +
tokens + stack + context version), the **five phases in order**, and the note that `_solutions/`
is the answer key and opening it defeats the kata.

## `_solutions/`
- `acceptance.test.ts` (or stack equivalent) — the hidden grader; starts failing.
- `grade.<ext>` — runs the grader across ≥3 ambient values, reports worst-case.
- `trap-manifest.md` — every planted item → a failure-mode ID + its location.
- `feature-qa.md` — the held-back requirements with answers.
- `rubric.md` — the objective gate + the how-you-drove axis.
- `FIX.md` — the reference fix and why.

## `practice.json`
Fill [`practice.template.json`](practice.template.json); every `failureModes` id must exist in
`../failure-modes.md` and appear in the trap manifest.
