# Generator contract

How **any AI agent** turns a Context version + a target (domain, stack, difficulty) into a new
practice that trains the same points as the seed. This is a documented contract — a prompt an
agent follows — not a coded tool (a coded runner is Phase 3). It works with Claude Code, the
Agent SDK, or any capable assistant.

## Inputs
`context` (e.g. `alder@1.2.0`) · `domain` · `stack` · `difficulty` (S|M|L) · optional
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
   `go test ./...`, `pytest _solutions/`, `node _solutions/grade.mjs`…; never assume npm). The
   harness reads this and runs it against a copy that still has `_solutions/`. Invoke it directly
   rather than through a script entry in a manifest the clone keeps — a `"grade"` script in
   `package.json` survives the strip and tells the assistant a hidden grader exists.
7. **Write the feature** as a stub + a 2–3 sentence underspecified `FEATURE-REQUEST.md`, with a
   real trap (an invariant the naive implementation trips) and 6–8 held-back questions in
   `_solutions/feature-qa.md`.
8. **Write `TICKET.md`** as a symptom with no method and no mention of the grader, `README.md`
   (the learner's briefing, which the harness keeps out of the clone — this is where the coaching
   goes), `rubric.md`, and `practice.json` (fill the template — including
   `commands.{install,test,grade}` for the stack, invoked so that nothing inside the clone
   advertises the grader; compute the time/token estimate per `generation-spec.md`).
9. **Self-validate** against the invariants in `generation-spec.md`, then run the acceptance
   checklist below. If anything fails, fix before shipping — never relax an invariant. Finish with
   the **control run**: a fresh assistant, the clone, one casual uncoached prompt. What it scores
   is the practice's real difficulty; everything else is what you hoped it was.
10. **Record a proof.** Drive the finished practice end-to-end through the harness at least once
    (a `train` run is ideal) and capture the run as **at least one proof file** placed inside the
    practice at `_solutions/proof-<mode>-<YYYY-MM-DD>.html` (it belongs in `_solutions/` because it
    necessarily reveals the fix, so the harness strips it from the learner's clone). The proof must
    record the **harness/mode, date, and model used**; the **control run** and what it scored —
    the honest measure of the traps, reported whether or not it flatters them; and for
    each phase: the learner prompt, how the assistant behaved, the trap that fired *by design*,
    the trainer/examiner output, and the **real** command outcome (baseline unit + grader, final
    unit + grader). Every terminal figure
    must be a genuine captured output — a proof that isn't reproducible from the practice is not a
    proof. Show only the designed traps; do not include defects you had to fix in the practice
    itself. Refresh the proof whenever the practice changes.

## Assistant-targeted traps — make the autopilot fail (required)
A practice only *trains* if **driving it badly fails.** Plant at least one trap aimed at the
assistant's default behaviour, so a human who merely delegates loses and a human who applies the
disciplines wins. Recipes, by the failure mode each punishes:

- **FM-13 — delegation before comprehension (required in every practice).** Engineer the code so
  an *autopilot* run provably loops instead of converging:
  - the objective grader tests the **root** behaviour, so a **symptom-patch** at a call site
    leaves it red — punishing *fix-without-a-model*;
  - the **"obvious" fix the assistant will propose** — a constant, a single special case, an
    offset read once — passes the visible suite but fails a case where the correct answer
    **varies per case** — punishing *accept-the-first-suggestion*. Only understanding the real
    model converges.
  The learner escapes only by *model-before-delegation* and by being able to debug what they own
  (*comprehension-as-ownership*).
- **FM-01 — green-suite trust.** The unit suite is green with the bug present, so "tests pass →
  done" ships the defect.
- **FM-10 — over-build.** An eager path (extra config, abstraction, a second feature) is
  available and eats the clock; the minimal correct path is smaller. Over-building is a losing move.
- **FM-03 — plausible-but-wrong.** A natural-looking implementation encodes a subtly wrong rule.

Record every assistant-targeted trap in `_solutions/trap-manifest.md` with **the autopilot move
it punishes** and **the discipline that beats it**, then **verify it bites** (the autopilot
validation check in `generation-spec.md`): a symptom-patch and a plausible first-suggestion fix
must both leave the grader red.

**Then check that nothing in the clone defuses it** (`generation-spec.md` invariant 10). A trap
is only as strong as the prose around it: a ticket that says "reproduce it first, and it must hold
on any server" hands over both the method and the mechanism, and a feature request that warns "the
obvious implementation trips a constraint" hands over the trap. Hand-verifying the mechanism does
not catch this — only the **control run** does: clone the practice as the harness would, give a
fresh assistant one casual uncoached prompt, and grade what comes back.

## Acceptance checklist (gate — all must hold)
- [ ] Unit suite green; primary bug invisible to it.
- [ ] Grader fails pre-fix, passes post-fix, across all ambient values (worst-case scored).
- [ ] Feature is underspecified + has a real trap defeatable by read-before-delegate.
- [ ] ≥5 ranked latent defects, each mapped to an FM id in the trap manifest.
- [ ] An **assistant-targeted over-reliance trap (FM-13) bites** — a symptom-patch and a
      plausible first-suggestion fix both leave the grader red; only a root, understanding-based
      fix passes. Verified, not assumed.
- [ ] Every required discipline is genuinely reachable; none requires reading `_solutions/`.
- [ ] **Nothing in the clone coaches the assistant** (invariant 10): the ticket carries no method,
      no mechanism and no reference to the grader; the feature request flags no trap; code and
      test comments leave evidence but never narrate the defect or the suite's blind spot; no
      manifest inside the clone exposes a grade command; `README.md` and `practice.json` are kept
      out of the clone entirely.
- [ ] **A control run is recorded** — a fresh assistant, the clone, one casual uncoached prompt —
      and it does **not** clear the gate. If it does, the practice is not calibrated: cut the
      coaching, or strengthen the graded case until only understanding reaches it.
- [ ] `practice.json` validates, declares `commands.{install,test,grade}` for the stack, and its
      estimates use the spec's method; the grader is invoked via `commands.grade` (never npm-assumed).
- [ ] A fresh-context reviewer agent confirms solvable at the stated altitude/time — not
      over-scoped (guard against FM-10 in the *practice itself*).
- [ ] At least one **proof file** ships in `_solutions/` (`proof-<mode>-<YYYY-MM-DD>.html`) from a
      real end-to-end harness run — recording harness/mode, date, model, and per-phase
      prompt → assistant behaviour → designed trap → trainer output → real outcome, with the
      baseline→final unit and grader numbers captured, not asserted.

## Worked example — how Alder would have produced the seed
> **Inputs:** `alder@1.2.0`, domain "subscription-box delivery scheduling", stack
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
> **Assistant trap (FM-13):** the grader tests the roots, so a call-site symptom-patch stays at
> 0/13 with a green suite; a fixed-offset fix plateaus at 7/13 on the per-instant/DST case; and
> both obvious skip implementations trip the store's invariant (9/13, 11/13).
> **Result:** 15/15 unit green, grader 0/13 → 13/13 after the per-instant fix and the minimal
> skip. See [`practices/deliveries/`](../practices/deliveries/).
> **Proof:** [`practices/deliveries/_solutions/proof-control-2026-09-13.html`](../practices/deliveries/_solutions/proof-control-2026-09-13.html)
> — the recorded control runs and what they scored, the verified trap mechanisms, and the
> Train-mode session. Note what it records honestly: the control run clears the gate one-shot, so
> the gate is the floor and the transcript is the verdict.

To generate another, change only `domain` and `stack` and run the procedure — the training
points, the shape, and the gate stay identical. (Generating a second practice is **Phase 2**,
out of scope for this phase; this contract is the spec that Phase 2 executes.)
