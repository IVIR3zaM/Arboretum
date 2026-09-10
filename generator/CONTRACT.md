# Generator contract

How **any AI agent** turns a Context version + a target (domain, stack, difficulty) into a new
practice that trains the same points as the seed. This is a documented contract — a prompt an
agent follows — not a coded tool (a coded runner is Phase 3). It works with Claude Code, the
Agent SDK, or any capable assistant.

## Inputs
`context` (e.g. `alder@1.0.0`) · `domain` · `stack` · `difficulty` (S|M|L) · optional
`time budget` and `coverage`. Read the whole Context first:
[`goals.md`](../context/alder/goals.md), [`best-practices.md`](../context/alder/best-practices.md),
[`failure-modes.md`](../context/alder/failure-modes.md),
[`generation-spec.md`](../context/alder/generation-spec.md), and the
[`templates/`](../context/alder/templates/).

## Procedure
1. **Pick the carrier.** Choose a small domain whose natural rules have room for the required
   failure modes (an ambient-variable bug, an invariant a feature can trip, places for latent
   defects). Sanity-check it maps to every required discipline in `goals.md`.
2. **Map failure modes → concrete traps.** For each required FM, instantiate its *trap recipe*
   in this domain. Write the mapping down first (it becomes `_solutions/trap-manifest.md`).
3. **Design the primary bug** as a silent, subset-only failure (FM-01+FM-02) keyed on an
   ambient variable (timezone, locale, currency, clock, encoding). Decide the correct rule and
   the buggy shipped version.
4. **Write the source** (tier-sized, zero/minimal deps), shipping the bug and the ranked latent
   defects. Keep everything else genuinely correct and idiomatic — the traps must be the only
   defects, and each must trace to the manifest.
5. **Write the green unit suite** so the primary bug is invisible to it (test away from the
   boundary / at a single ambient value).
6. **Write the hidden grader** that fails pre-fix and passes only after the correct fix, scored
   across ≥3 ambient values (worst-case). Add `FIX.md` with the reference fix. Declare how it is
   invoked in `practice.json` → `commands.grade` (stack-appropriate — `cargo run --bin grade`,
   `go test ./...`, `pytest`, `npm run grade`…; never assume npm). The harness reads this.
7. **Write the feature** as a stub + a 2–3 sentence underspecified `FEATURE-REQUEST.md`, with a
   real trap (an invariant the naive implementation trips) and 6–8 held-back questions in
   `_solutions/feature-qa.md`.
8. **Write `TICKET.md`** as a symptom, `README.md` with the five-phase flow, `rubric.md`, and
   `practice.json` (fill the template — including `commands.{install,test,grade}` for the stack;
   compute the time/token estimate per `generation-spec.md`).
9. **Self-validate** against the invariants in `generation-spec.md`, then run the acceptance
   checklist below. If anything fails, fix before shipping — never relax an invariant.

## Acceptance checklist (gate — all must hold)
- [ ] Unit suite green; primary bug invisible to it.
- [ ] Grader fails pre-fix, passes post-fix, across all ambient values (worst-case scored).
- [ ] Feature is underspecified + has a real trap defeatable by read-before-delegate.
- [ ] ≥5 ranked latent defects, each mapped to an FM id in the trap manifest.
- [ ] Every required discipline is genuinely reachable; none requires reading `_solutions/`.
- [ ] `practice.json` validates, declares `commands.{install,test,grade}` for the stack, and its
      estimates use the spec's method; the grader is invoked via `commands.grade` (never npm-assumed).
- [ ] A fresh-context reviewer agent confirms solvable at the stated altitude/time — not
      over-scoped (guard against FM-10 in the *practice itself*).

## Worked example — how Alder would have produced the seed
> **Inputs:** `alder@1.0.0`, domain "subscription-box delivery scheduling", stack
> TypeScript/Node 22 zero-dep, tier M.
> **Carrier:** cutoffs + cadence + at-least-once retries give a natural home for an ambient bug
> and an idempotency defect.
> **Primary bug:** cutoff computed in the host timezone, not the customer's (FM-01+FM-02);
> graded under UTC / LA / Tokyo.
> **Feature:** "skip my next box" — trips the duplicate-delivery invariant + lazy
> materialization (read-before-delegate); 8 held-back questions.
> **Latent defects:** idempotency on eventId (FM-06), state leaked by reference (FM-05),
> unbounded processed set (FM-07), strict `<` boundary (FM-04), 30-day month (FM-03), silent
> fall-through (FM-03), unvalidated timezone (FM-08).
> **Result:** 15/15 unit green, grader 0/7 → 7/7 after the reference fix. See
> [`practices/deliveries/`](../practices/deliveries/).

To generate another, change only `domain` and `stack` and run the procedure — the training
points, the shape, and the gate stay identical. (Generating a second practice is **Phase 2**,
out of scope for this phase; this contract is the spec that Phase 2 executes.)
