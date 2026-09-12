# Practice file skeletons — Cedar

Copy these shapes when generating a Cedar practice. They extend Alder's skeletons with the
multi-package layout, the read-only `reference/`, the learner's research artifact, and the extra
`_solutions/` files for the two Cedar failure modes. Mirror the structure and register of an
existing Cedar practice under [`practices/`](../../../practices/), changing only domain and stack.
Do not name a specific practice or its domain here — these skeletons stay domain-agnostic.

## Repository layout (multi-package + read-only reference)
```
<practice>/
  <package-a>/        # e.g. backend/  (its own src/ + test/)
  <package-b>/        # e.g. app/      (its own lib/ + test/ + integration_test/)
  reference/          # READ-ONLY external truth — never the working repo (see below)
  _solutions/         # hidden answer key (see below)
  TICKET.md  FEATURE-REQUEST.md  README.md  practice.json
  grade.sh            # the wrapper commands.grade points at, runs every package's grader
```

## `reference/` — read-only external truth (Cedar)
The world the repo talks to but does not own. Shape it as the *authoritative snapshot* a real
research pass would produce, not as a second codebase:
```
reference/
  README.md               # "This is external truth. Read-only. Your repo depends on it; it does not depend on you."
  <method-or-protocol>.md  # the spec the current system follows (the one the local docs lag)
  infra/                  # cloud config the truth lives in — e.g. hosted documents, a KMS/key policy
  <sibling-service>.md     # the contract of the other service (interface + the one invariant your change depends on)
```
Invariant 11: the authoritative contract for ≥1 defect lives **only** here; the local repo's
obvious assumption is wrong and nothing local states the truth.

## `research-notes.md` (learner-produced, in the workdir — not shipped)
```
# Research notes — <what I had to leave the repo to learn>
## What the local repo implies (and where it's stale)
## What reference/ actually says (the current contract)
## The load-bearing fact my change depends on
## Assumptions I discarded after reading reference/
```

## `README.md` (learner-facing) — lead with a domain primer for a niche domain
Match a learner-facing register, and for an unfamiliar domain **open with a short, visual Background
section** (plain language + mermaid diagrams) that teaches the domain *without pointing at the
bug* — scaffolding, not a hint. Then the setup block, the **estimate table** (time + tokens +
stack + context version), the **five phases in order** (the research pass is called out inside
*understand*), and the note that `_solutions/` is the answer key and opening it defeats the kata.

## `TICKET.md` (phase 2) — a symptom, never a location
```
# Support ticket #<n> — "<customer's words>"
**Severity:** <low|medium> — <recurring? who's affected?>
> <the customer symptom, in plain language. what they saw, when, that it's
>  only *some* users/inputs/environments, and that the suite is green.>
**What we know:** <the intended rule, stated plainly — no file, no line>
**Your job:** reproduce first (a failing test), then fix for EVERY case. The grade command
(declared in `practice.json` → `commands.grade`) checks it.
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

## `_solutions/` (hidden — harness strips it from the learner clone)
- `acceptance.<ext>` (per gradable package) — the hidden grader; starts failing. Calls the **root**
  behaviour directly so a symptom-patch can't pass; includes the **reference-derived conformance
  vectors** (FM-16).
- `grade.sh` wrapper + any per-package `grade.<ext>` — runs across ≥3 ambient values, reports
  combined worst-case (all packages must pass).
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

## `practice.json`
Fill [`practice.template.json`](practice.template.json); `contextVersion` is `cedar@1.0.0`; every
`failureModes` id must exist in `../failure-modes.md` and appear in the trap manifest; a Cedar
practice includes `FM-15` and `FM-16`, declares the multi-package `stack`, the wrapper
`commands.grade`, and the `reference` + `researchArtifact` fields.
