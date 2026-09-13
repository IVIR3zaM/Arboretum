# Practice file skeletons

Copy these shapes when generating a practice. Mirror the structure and register of an existing
worked practice under [`practices/`](../../../practices/), changing only domain and stack. Do not
name a specific practice or its domain here — these skeletons stay domain-agnostic.

> **These two files go into the assistant's clone, so they are held to invariant 10: they are
> written by people who do not know where the bug is, and they coach nobody.** No method ("reproduce
> first", "fix the root"), no hint at the mechanism, no mention that a grader exists or how it is
> invoked, no ⚠️ pointing at the trap. Say what happened and what was promised; stop there.

## `TICKET.md` (phase 2) — a symptom, never a location, never a method
```
# Support ticket #<n> — "<customer's words>"
**Reporter:** <who escalated it> · **Severity:** <low|medium> — <recurring? who's affected?>
> <the customer symptom, in plain language: what they saw, when, that it's only *some*
>  users/inputs/environments, that nobody on the team can reproduce it, and that the
>  suite is green.>
**What support has confirmed:** <what was promised to the customer — the intended rule, stated
plainly in product language. No file, no line, no mechanism.>
**Your job:** <the outcome the business wants, in one sentence — "get it doing X for every
customer, not just the ones who complained". Never how to go about it.>
```

## `FEATURE-REQUEST.md` (phase 3) — 2–3 sentences, underspecified
```
# Feature request — "<short name>"
From the PM:
> <2–3 sentences. A real ask with the hard decisions left out.>
That's the whole brief — <and the PM is reachable if you need more>.
Expected surface: `<Service.method(...)>` (currently a stub).
```
The 6–8 held-back requirement questions + answers go in `_solutions/feature-qa.md`. Nothing here
announces the trap or tells the reader to go looking for it: the point is to find out whether the
learner reads the code and asks the questions on their own.

## `README.md` (the learner's briefing — NOT part of the clone)
This is where the coaching lives, because the learner reads it before the session and the
assistant never sees it. It has: a one-paragraph domain intro, a setup block, the **estimate
table** (time + tokens + stack + context version), the **five phases in order** with the
discipline each one trains, a note that the hidden grader is run **by the harness, not by the
learner or the assistant**, and the note that `_solutions/` is the answer key and opening it
defeats the kata.

## `_solutions/`
- `acceptance.test.ts` (or stack equivalent) — the hidden grader; starts failing.
- `grade.<ext>` — runs the grader across ≥3 ambient values, reports worst-case.
- `trap-manifest.md` — every planted item → a failure-mode ID + its location.
- `feature-qa.md` — the held-back requirements with answers.
- `rubric.md` — the objective gate + the how-you-drove axis.
- `FIX.md` — the reference fix and why.

## `practice.json` (the manifest — NOT part of the clone)
Fill [`practice.template.json`](practice.template.json); every `failureModes` id must exist in
`../failure-modes.md` and appear in the trap manifest. It names the planted bug and every trap,
so like the README it stays out of the assistant's clone — the harness reads it from the
practice, and the examiner gets a copy in `golden/`.

## Nothing in the clone names the grade command
Declare it in `practice.json` → `commands.grade` as something the harness can run **against a
copy that still has `_solutions/`** (`node _solutions/grade.mjs`, `cargo run --bin grade`,
`pytest _solutions/`…). Do not wire it into a manifest the learner's clone keeps — a
`"grade": …` script sitting in `package.json` (or a `Makefile` target, or a `[tool.poetry.scripts]`
entry) tells the assistant that a hidden grader exists and that the visible suite is not the bar.
