# Practice file skeletons — Cedar

Copy these shapes when generating a Cedar practice. They extend Alder's skeletons with the
multi-package layout, the read-only `reference/`, the learner's research artifact, and the extra
`_solutions/` files for the two Cedar failure modes. Mirror the structure and register of an
existing Cedar practice under [`practices/`](../../../practices/), changing only domain and stack.
Do not name a specific practice or its domain here — these skeletons stay domain-agnostic.

> **The layout below is in three layers, and which layer a file sits in is load-bearing.**
> Everything in the cloned layer is held to invariant 12: it is written by people who do not know
> where the bug is, and it coaches nobody. No method ("reproduce first", "read the spec"), no hint
> at the mechanism, no mention that a grader exists or how it is invoked, no ⚠️ pointing at the
> trap. Say what happened and what was promised; stop there.

## Repository layout (multi-package + read-only reference)
```
<practice>/
  ── cloned ──────────────────────────────────────────────────────────────────
  <package-a>/        # e.g. backend/  (its own src/ + test/)
  <package-b>/        # e.g. app/      (its own lib/ + test/ + integration_test/)
  reference/          # READ-ONLY external truth — never the working repo (see below).
                      # In the clone from the start; never staged.
  TICKET.md           # handed over at the start
  FEATURE-REQUEST.md  # handed over when phase 3 begins, not before
  ── exercise material (NOT cloned) ──────────────────────────────────────────
  README.md  practice.json
  ── hidden (NOT cloned) ─────────────────────────────────────────────────────
  _solutions/         # hidden answer key, incl. the grade wrapper (see below)
```

## `reference/` — read-only external truth (Cedar)
The world the repo talks to but does not own. Shape it as the *authoritative snapshot* a real
research pass would produce, not as a second codebase:
```
reference/
  README.md               # what this directory is, and that it is read-only. Nothing more.
  <method-or-protocol>.md  # the spec the current system follows (the one the local docs lag)
  infra/                  # cloud config the truth lives in — e.g. hosted documents, a KMS/key policy
  <sibling-service>.md     # the contract of the other service (interface + the one invariant a consumer depends on)
```
Invariant 11: the authoritative contract for ≥1 defect lives **only** here; the local repo's
obvious assumption is wrong and nothing local states the truth.

Invariant 12 applies here too — this is cloned material. `reference/README.md` says what the
directory is and that it must not be edited; it does **not** tell the reader to study it, distill
it, compare it with the local repo, or hint that the two disagree. The spec states the method the
way a vendor's spec states a method: it never points at the local implementation and never notes
that anything local is wrong. A `reference/` that instructs the reader to research it has handed
over the FM-16 judgement it exists to measure.

## `research-notes.md` (learner-produced, in the workdir — not shipped)
```
# Research notes — <what I had to leave the repo to learn>
## What the local repo implies (and where it's stale)
## What reference/ actually says (the current contract)
## The load-bearing fact my change depends on
## Assumptions I discarded after reading reference/
```

## `TICKET.md` (phase 2) — a symptom, never a location, never a method
```
# Support ticket #<n> — "<customer's words>"
**Reporter:** <who escalated it> · **Severity:** <low|medium|high> — <recurring? who's affected?>
> <the customer symptom, in plain language: what they saw, when, that it's only *some*
>  SKUs/users/inputs/environments, that nobody on the team can reproduce it, and that the
>  suite is green.>
**What support has confirmed:** <what was promised to the customer — the intended rule, stated
plainly in product language. No file, no line, no mechanism, no pointer at the reference.>
**Your job:** <the outcome the business wants, in one sentence — "get it doing X for every
customer, not just the ones who complained". Never how to go about it.>
```

## `FEATURE-REQUEST.md` (phase 3) — 2–3 sentences, underspecified
```
# Feature request — "<short name>"
From the PM:
> <2–3 sentences. A real ask with the hard decisions left out.>
That's the whole brief — <and the PM is reachable if you need more>.
Expected surface: `<Service.method(...)>` (currently a stub)<, plus the control on the storefront>.
```
The 6–8 held-back requirement questions + answers go in `_solutions/feature-qa.md`. Nothing here
announces the trap or tells the reader to go looking for it: the point is to find out whether the
learner reads the code and asks the questions on their own.

## `README.md` (the learner's briefing — NOT part of the clone)
This is where the coaching lives, because the learner reads it before the session and the
assistant never sees it. Match a learner-facing register, and for an unfamiliar domain **open with
a short, visual Background section** (plain language + mermaid diagrams) that teaches the domain
*without pointing at the bug* — scaffolding, not a hint. Then the setup block, the **estimate
table** (time + tokens + stack + context version), the **five phases in order** with the discipline
each one trains (the research pass is called out inside *understand*), a note that the hidden
grader is run **by the harness, not by the learner or the assistant**, and the note that
`_solutions/` is the answer key and opening it defeats the kata.

## `_solutions/` (hidden — harness strips it from the learner clone)
- `acceptance.<ext>` (per gradable package) — the hidden grader; starts failing. Calls the **root**
  behaviour directly so a symptom-patch can't pass; includes the **reference-derived conformance
  vectors** (FM-16).
- `grade.sh` wrapper + any per-package `grade.<ext>` — runs across ≥3 ambient values, reports
  combined worst-case (all packages must pass). It lives **here**, not at the practice root: the
  root is cloned, and a wrapper sitting there tells the assistant a hidden gate exists.
- `trap-manifest.md` — every planted item → a failure-mode ID + its location; the FM-13 plateau,
  the FM-15 stale path + contradicting doc, and the FM-16 reference-only cause each **verified to
  bite** (a symptom-patch / a first-suggestion fix / a no-research run all left red).
- `feature-qa.md` — the held-back requirements with answers.
- `rubric.md` — the objective gate + the how-you-drove axis (adds items for the research pass and
  doc reconciliation).
- `FIX.md` — the reference fix and why; and why the plausible autopilot fix plateaus.
- `context-map.md` — the golden cross-boundary contract: the true current design (which method /
  which service / which hosted state), what `reference/` establishes, and the one fact the fix
  depends on (FM-16).
- `doc-drift-ledger.md` — every doc/code/reference contradiction, the authoritative source for
  each, and the stale no-doc-trace path (FM-15).
- `proof-<mode>-<YYYY-MM-DD>.html` — the recorded end-to-end harness run (generator CONTRACT step
  10); refreshed whenever the practice changes.

## `practice.json` (the manifest — NOT part of the clone)
Fill [`practice.template.json`](practice.template.json); `contextVersion` is `cedar@1.2.0`; every
`failureModes` id must exist in `../failure-modes.md` and appear in the trap manifest; a Cedar
practice includes `FM-15` and `FM-16`, declares the multi-package `stack`, the wrapper
`commands.grade`, the `reference` + `researchArtifact` fields, the measured `controlRun`, and the
`featureTrap` object recording the lure and the paired **naive** (must fail) and **elicited** (must
pass) feature-gate scores. It
names the planted bug, the doc-drift trap and the cross-boundary trap outright, so like the README
it stays out of the assistant's clone — the harness reads it from the practice, and the examiner
gets a copy in `golden/`.

## Nothing in the clone names the grade command
Declare it in `practice.json` → `commands.grade` as something the harness can run **against a copy
that still has `_solutions/`** (`bash _solutions/grade.sh`). Do not wire it into anything the
learner's clone keeps — a `"grade": …` script in a package manifest, a `Makefile` target, or a
wrapper at the practice root all tell the assistant that a hidden grader exists and that the
visible suite is not the bar.
