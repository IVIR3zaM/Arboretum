# Generation spec — Context "Alder" v1

The contract an AI agent follows to generate a **new practice** in a different domain and tech
stack that trains the **same points** as the Context. The agent reads this file plus
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
- **coverage** — which disciplines/failure modes to train (default: the core disciplines in
  goals.md, including model-before-delegation; **FM-13 is required by default** — see invariant 9).

## Required output (the fixed practice shape)
```
<practice>/
  src/            # 5–8 small source files, the size of the tier (see below)
  test/           # a GREEN unit suite; the primary bug is invisible to it
  _solutions/     # hidden: acceptance grader, trap-manifest, feature Q&A, rubric, FIX
  TICKET.md       # the bug as a SYMPTOM — never a file+line, never a method
  FEATURE-REQUEST.md  # 2–3 sentences, underspecified; 6–8 held-back questions in _solutions
  README.md       # the learner's briefing: the 5-phase flow + the time & token estimate
  practice.json   # metadata + trainingPoints coverage (validates against templates/)
```
The first four go into the assistant's clone; the last three do **not**. `_solutions/` is the
answer key, `README.md` is the *learner's* briefing and `practice.json` names every planted
trap — an assistant that reads them has been coached by the instrument measuring it (invariant
10, and `AGENTS.md` rule 3).

## Invariants every generated practice MUST satisfy
1. **The unit suite is green and the primary bug is invisible to it** (FM-01). The hidden
   acceptance grader starts failing and passes only after the correct fix.
2. **The bug is a silent, subset-only failure** (FM-02) keyed on an ambient variable the author
   didn't parameterize (timezone, locale, currency, encoding, clock). Graded across ≥3 values.
3. **The feature is underspecified, reads as easy, and misleads.** A straight "implement this"
   prompt trips a real trap — an invariant it violates, state not yet materialized, or a
   plausible-but-wrong rule the brief quietly leans toward. The gate scores the rules **only
   elicitation surfaces**, so handing the brief over raw *fails* it and an elicited build *passes*
   it — defeatable by read-**and-ask**-before-delegate, not by delegation. (Proven by the paired
   naive-vs-elicited build in Validation.)
4. **≥5 ranked latent defects** drawn from FM-03..FM-08, *findable* from the code, not recited.
5. **The grader is runnable with zero/minimal deps**, invoked via the practice's **declared
   command** (`practice.json` → `commands.grade`) — stack-appropriate, never assumed to be
   `npm`. It reports a worst-case score across the ambient-variable values (a fix that only works
   locally does not count).
6. **Every planted item maps to a failure-mode ID** in the trap manifest. No orphan traps, no
   uncovered required discipline.
7. **It is solvable at the stated altitude in the stated time** — not a production system.
8. **`practice.json` declares the stack's commands** — `commands.install`, `commands.test`,
   `commands.grade` — so the harness runs the practice **without knowing the language**. A Rust
   kata declares `cargo test` / `cargo run --bin grade`; a Go kata `go test ./...`; a Python kata
   `pytest` / `python grade.py`. **The harness and AGENTS.md read these; they hardcode nothing.**
   A practice whose grader can only be invoked as `npm run grade` is a stack leak — fix it here.
9. **An assistant-targeted over-reliance trap (FM-13) is present** — a place engineered so an
   *autopilot* run (vague prompt, delegate-before-understand, accept-the-first-suggestion)
   provably loops instead of converging: the objective grader tests the **root** behaviour, so a
   symptom-patch at a call site leaves it red; and the "obvious" fix the assistant proposes (a
   constant or special-case where the correct answer varies per case) passes the visible suite
   but fails a case that needs genuine understanding. Only *model-before-delegation* and
   *comprehension-as-ownership* converge. Distinct from the feature trap (#3, which targets
   reading the code): this one targets *delegating before understanding the goal*.
10. **Nothing the assistant can read coaches it.** Everything in the clone reads as the working
    repo of a team that does not yet know it has a bug. Concretely: the **ticket** reports a
    symptom and states the rule the customer was promised, then stops — it does not prescribe
    method ("reproduce first", "fix the root cause"), does not hint at the mechanism, and never
    mentions that a grader exists or how it is invoked. The **feature request** is the PM's ask
    plus the expected surface — it does not warn that the obvious implementation trips an
    invariant, or that there is a trap at all. **Source and test comments** state intent and
    contract, and may leave the *evidence* a careful reader needs; they never narrate the planted
    defect or confess the suite's own blind spot. The **grade command** is not runnable from
    inside the clone and nothing in the clone refers to it. The learner's briefing and the
    manifest stay outside the clone (see the practice shape above). The discipline under test is
    the *learner's* to bring: a workdir that tells the assistant to reproduce before fixing has
    already spent the thing it was measuring. **Coaching belongs to the learner's briefing and to
    the trainer — never to the workdir.**

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
- Unit suite green; grader fails pre-fix and passes post-fix across all ambient values — run via
  the declared `commands.test` / `commands.grade`, never an assumed `npm`.
- `practice.json` validates, declares `commands.{install,test,grade}`, and every
  `trainingPoints.failureModes` id exists in `failure-modes.md` and appears in the trap manifest.
- **Autopilot check (FM-13):** a symptom-patch and a plausible first-suggestion fix are both
  verified to leave the grader red; only the root, understanding-based fix reaches full marks.
  The trap must bite an autopilot run, not just a careless one.
- **Feature-trap discrimination — a paired build.** The feature trap is proven not by the control
  run alone but by **two** builds scored through the declared grade command: a **naive one-shot**
  (fresh executor that has not done any research pass, brief handed over raw) and an **elicited**
  build (the feature after its questions were asked and answered). The trap counts only if **naive
  fails the feature gate and elicited passes.** Naive-also-passes means the gate is a completion
  floor, not a trap — tighten it until only understanding clears it; elicited-also-fails means it is
  impossibly hard. Both scores are recorded, both are genuine captured output.
- **Robustness probes (examiner-only, non-blocking).** The gate's blind vectors — state handed out
  by reference, a guard placed at one entry point instead of on the invariant, a degenerate-quantity
  case — are covered by probes shipped in `_solutions/` **beside** the gate, never wired into the
  grade command and never changing its pass/fail. Each probe's expected result was captured from a
  real build (the reference fix and a stub), not asserted by hand.
- **Manifest completeness.** Every claimed failure mode is planted where a run actually reaches it
  (count planted *instances*, not modes); a mode named in `practice.json` but unreachable is not
  covered. Emergent (unplanted) findings and the reference fix's known limitations are recorded in
  a labelled section, excluded from the planted count.
- **Control run (invariant 10) — the one that actually settles it.** Clone the practice exactly
  as the harness would, hand a *fresh* assistant nothing but that clone and one casual, uncoached
  prompt ("here's a ticket and a feature request — fix the bug and implement the feature"), let it
  finish, and grade the result. Record the score in the proof. A trap that a control run walks
  past unharmed is not a trap, and the two ways that happens have different fixes: if the material
  told it what to do, that is an invariant-10 leak, so cut the coaching; if the material said
  nothing and the trap still failed to bite, the trap is too weak for the assistants of the day,
  so make the graded case one that only genuine understanding reaches. Verifying the trap's
  mechanism by hand is not a substitute — mechanisms hold while the prose quietly gives the
  answer away.
- A reviewer agent (fresh context) confirms each required discipline is genuinely reachable and
  the exercise is solvable at the stated altitude/time — not over-scoped.
