# Generation spec — Context "Alder" v1

The contract an AI agent follows to generate a **new practice** in a different domain and tech
stack that trains the **same points** as the seed. The agent reads this file plus
[`goals.md`](goals.md), [`best-practices.md`](best-practices.md), and
[`failure-modes.md`](failure-modes.md); the step-by-step an agent executes is in
[`../../generator/CONTRACT.md`](../../generator/CONTRACT.md).

## Inputs
- **domain** — the business story (e.g. "hotel room inventory", "metering & billing", "feature
  flags"). Picks the vocabulary and the natural home for the planted bugs.
- **stack** — language + runtime + test runner. Zero-dependency or pinned-minimal preferred so
  a learner can run it with no setup.
- **difficulty tier** — `S` | `M` | `L` (drives size and the time/token estimate).
- **time budget** — optional override of the tier default.
- **coverage** — which disciplines/failure modes to train (default: the core six in goals.md).

## Required output (the fixed practice shape)
```
<practice>/
  src/            # 5–8 small source files, the size of the tier (see below)
  test/           # a GREEN unit suite; the primary bug is invisible to it
  _solutions/     # hidden: acceptance grader, trap-manifest, feature Q&A, rubric, FIX
  TICKET.md       # the bug as a SYMPTOM — never a file+line
  FEATURE-REQUEST.md  # 2–3 sentences, underspecified; 6–8 held-back questions in _solutions
  README.md       # the 5-phase flow + the time & token estimate
  practice.json   # metadata + trainingPoints coverage (validates against templates/)
```

## Invariants every generated practice MUST satisfy
1. **The unit suite is green and the primary bug is invisible to it** (FM-01). The hidden
   acceptance grader starts failing and passes only after the correct fix.
2. **The bug is a silent, subset-only failure** (FM-02) keyed on an ambient variable the author
   didn't parameterize (timezone, locale, currency, encoding, clock). Graded across ≥3 values.
3. **The feature is underspecified with a real trap** a straight "implement this" prompt trips
   (an invariant it violates, state not yet materialized) — defeatable by read-before-delegate.
4. **≥5 ranked latent defects** drawn from FM-03..FM-08, *findable* from the code, not recited.
5. **The grader is runnable with zero/minimal deps** and reports a worst-case score across the
   ambient-variable values (a fix that only works locally does not count).
6. **Every planted item maps to a failure-mode ID** in the trap manifest. No orphan traps, no
   uncovered required discipline.
7. **It is solvable at the stated altitude in the stated time** — not a production system.

## Difficulty tiers
| Tier | Source files | ~LOC | Phases | Time |
|---|---|---|---|---|
| S | 3–4 | ~200 | understand · fix · review | ~30 min |
| M | 5–6 | ~450 | all five | ~60 min |
| L | 7–8 | ~800 | all five + a second bug | ~90 min |

## Estimation method (every practice reports both)
- **Time** = sum of phase budgets for the tier. M split ≈ understand 12 · fix 15 · feature 18 ·
  improve 10 · review 5 (minutes).
- **Tokens** = `repo_read_tokens × read_passes + expected_rounds × avg_round_tokens`, where
  `repo_read_tokens ≈ LOC × 10`, `read_passes ≈ 2`, `avg_round_tokens ≈ 1,500`, and
  `expected_rounds` ≈ 8 (S) / 10 (M) / 14 (L). Worked example (M, ~450 LOC): `450×10×2 +
  10×1,500 = 9,000 + 15,000 = 24,000` → report **~25,000**. The Phase-2 runner records
  *actuals* (time always; tokens where the tool exposes usage).

## Validation (before a generated practice is accepted)
- Unit suite green; grader fails pre-fix and passes post-fix across all ambient values.
- `practice.json` validates and every `trainingPoints.failureModes` id exists in
  `failure-modes.md` and appears in the trap manifest.
- A reviewer agent (fresh context) confirms each required discipline is genuinely reachable and
  the exercise is solvable at the stated altitude/time — not over-scoped.
