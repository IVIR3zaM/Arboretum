# Generator contract

How **any AI agent** turns a Context version + a target (domain, stack, difficulty) into a new
practice that trains the same points as the seed. This is a documented contract — a prompt an
agent follows — not a coded tool (a coded runner is Phase 3). It works with Claude Code, the
Agent SDK, or any capable assistant.

## Inputs
`context` (e.g. `alder@1.3.0`, `cedar@1.2.0`) · `domain` · `stack` · `difficulty` (S|M|L, +XL from
Cedar) · optional `time budget` and `coverage`. Read the whole Context first — the paths below
point at Alder; substitute `context/<tree>/` for whichever version you were given:
[`goals.md`](../context/alder/goals.md), [`best-practices.md`](../context/alder/best-practices.md),
[`failure-modes.md`](../context/alder/failure-modes.md),
[`generation-spec.md`](../context/alder/generation-spec.md), and the
[`templates/`](../context/alder/templates/).

> **Invariant numbering.** This contract says "invariant 10" for *nothing the assistant can read
> coaches it*, which is its number in Alder. **In Cedar it is invariant 12** — 10 and 11 were
> already spent on context rot and the cross-boundary cause. Same rule, different number; read
> your Context's own spec for the authoritative list.

## Procedure
1. **Pick the carrier.** Choose a small domain whose natural rules have room for the required
   failure modes (an ambient-variable bug, an invariant a feature can trip, places for latent
   defects). Sanity-check it maps to every required discipline in `goals.md`.
2. **Map failure modes → concrete traps.** For each required FM, instantiate its *trap recipe*
   in this domain. Write the mapping down first (it becomes `_solutions/trap-manifest.md`). The
   manifest must **name a defect instance a run can actually reach** — a mode claimed in
   `practice.json` but not planted where a run hits it is not covered (count planted *instances*,
   not modes, and if one mode has several by-reference/boundary instances, list them all). Note for
   any FM-13 plateau row that it is measurable **only when the fix prompt precedes the research
   pass, or in a fresh executor** — a run that fixes with research already in context converges on
   the first try and never exercises the plateau. As runs expose them, the manifest also records
   **emergent (unplanted) findings** in a clearly-labelled section (excluded from the planted
   count, so an examiner credits them without treating them as planted) and the **reference fix's
   known limitations** (a case `FIX.md` does not handle and the grader cannot see) — see step 6.
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
   `package.json` survives the strip and tells the assistant a hidden grader exists. If the
   reference fix has a **known limitation** — a case it does not handle that no fixture exercises,
   so the grader is blind to it — record it in `FIX.md` and in the manifest's emergent section
   (step 2); do not quietly ship a `FIX.md` you know to be incomplete.
   **6a. Robustness probes for gate-blind vectors (examiner-only, non-blocking).** A frozen gate is
   blind to oversell/robustness vectors it was not built to see (state handed out by reference, a
   guard placed at one entry point instead of on the invariant, a degenerate-quantity case). Ship
   these as a **separate probe file in `_solutions/`** that sits *beside* the gate — never wired
   into `commands.grade`, never changing its pass/fail — and have the examiner report `robustness
   n/m` next to the gate result. Probes go beside the gate, not inside it, precisely so the gate
   stays frozen and comparable across runs. **Verify each probe's expectation against a real
   recorded build** (the reference build and a stub), not by hand — a probe whose expected number
   you never captured is a guess.
7. **Write the feature so it *looks easy and leans the wrong way*.** The `FEATURE-REQUEST.md` is a
   2–3 sentence PM ask over a stub — and it must read as a small job while quietly luring the
   obvious implementation onto the *wrong* rule (a "same rules as X" aside, a "we already handle Y"
   reassurance, a plausible-but-wrong default). This is the point of the feature phase: handing the
   brief to an assistant raw — *"just build this"* — must **fail** the feature gate, and it passes
   only when the learner understands the ask, asks the right questions, and hands over clear
   context. So the gate scores the *rules only elicitation surfaces*, not just "does a feature
   exist." Put the answer to each lure in `_solutions/feature-qa.md` (6–8 held-back questions),
   each naming **the stakeholder who owns it** (PM, platform, the service on the other side of a
   boundary) plus an operator note to answer only what was asked. Ship a **reference elicited
   build** in `_solutions/` (`FEATURE-FIX.md` + a reference build dir) that clears the whole gate,
   so the gate is provably passable. The naive-vs-elicited proof that this discriminates is step 10
   and the acceptance checklist.
8. **Write `TICKET.md`** as a symptom with no method and no mention of the grader, `README.md`
   (the learner's briefing, which the harness keeps out of the clone — this is where the coaching
   goes), `rubric.md`, and `practice.json` (fill the template — including
   `commands.{install,test,grade}` for the stack, invoked so that nothing inside the clone
   advertises the grader; compute the time/token estimate per `generation-spec.md`). The
   **`rubric.md`** encodes the harness-wide grading principles rather than re-inventing them — see
   `harness/DESIGN.md` §2. Concretely it must carry:
   - a **Source column** on every driving-axis row (`spontaneous` / `trainer-prompted` /
     `operator-supplied`), recording where each move came from — the record that a calibration run
     is not a learner grade (`AGENTS.md` rule 10, `harness/DESIGN.md` §3);
   - a row that credits **claims re-run, not summarised** (self-reported counts checked against real
     output) and the **restraint** scoring of a latent defect fixed silently before its phase
     (`harness/DESIGN.md` §2);
   - the anti-signal **"review answered from a summary or ticket list without reading the diff"**
     alongside the other autopilot anti-signals;
   - the non-blocking **robustness report** (step 6a) read as evidence for the "caught defects the
     change introduced" row, never folded into the objective gate.
   Fill every row for every phase — a skipped phase reads as `absent` rows, not silence.
9. **Self-validate** against the invariants in `generation-spec.md`, then run the acceptance
   checklist below. If anything fails, fix before shipping — never relax an invariant. Finish with
   the **control run**: a fresh assistant, the clone, one casual uncoached prompt. What it scores
   is the practice's real difficulty; everything else is what you hoped it was. For the feature
   phase, this control run is one half of the **naive-vs-elicited proof** the feature trap requires
   (below and step 10).
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

    **The feature trap's proof is a *paired* measurement — naive vs elicited.** Because the feature
    request is meant to look easy and mislead (step 7), a proof that the trap discriminates is not
    the single control run alone; it is **two** builds, both scored through `commands.grade` and
    both recorded: a **naive one-shot** build (the brief handed over raw, *"just build it"*) and an
    **elicited** build (the same feature after the questions were asked and answered). The trap only
    counts if the **naive build fails the feature gate and the elicited build passes it.** If naive
    also passes, the gate is a completion floor, not a trap — tighten it (add the elicitation-only
    rules) until only understanding clears it; if elicited also fails, the gate is impossibly hard —
    the reference elicited build (step 7) is what proves it is passable. Run naive with a *fresh*
    executor that has not done the research pass, so "prompt shape" is not confounded with "context
    already carried." Record both scores in the proof and in `practice.json`.

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
- [ ] Feature is underspecified, reads as easy, and **leans toward the wrong rule**; the gate
      scores the rules only elicitation surfaces.
- [ ] **The feature trap discriminates — proven by a paired build.** A naive one-shot build (fresh
      executor, brief handed over raw) **fails** the feature gate; an elicited build (or the
      reference elicited build in `_solutions/`) **passes** it. Both scores recorded; both real.
- [ ] ≥5 ranked latent defects, each mapped to an FM id in the trap manifest, and **each a defect
      instance a run can actually reach** (claimed-but-unplanted modes do not count; emergent
      findings are listed separately and excluded from the count).
- [ ] An **assistant-targeted over-reliance trap (FM-13) bites** — a symptom-patch and a
      plausible first-suggestion fix both leave the grader red; only a root, understanding-based
      fix passes. Verified, not assumed.
- [ ] Every required discipline is genuinely reachable; none requires reading `_solutions/`.
- [ ] **Nothing in the clone coaches the assistant** (invariant 10): the ticket carries no method,
      no mechanism and no reference to the grader; the feature request flags no trap; code and
      test comments leave evidence but never narrate the defect or the suite's blind spot; no
      manifest inside the clone exposes a grade command and no grade wrapper sits at the practice
      root (it belongs in `_solutions/`); `README.md` and `practice.json` are kept out of the clone
      entirely. *Cedar also:* the drifting doc misleads rather than hedges, and `reference/` reads
      as a vendor snapshot — it never tells the reader to study it or hints that the local repo
      disagrees with it.
- [ ] **A control run is recorded** — a fresh assistant, the clone, one casual uncoached prompt —
      and it does **not** clear the gate. If it does, the practice is not calibrated: cut the
      coaching, or strengthen the graded case until only understanding reaches it.
- [ ] `practice.json` validates, declares `commands.{install,test,grade}` for the stack, and its
      estimates use the spec's method; the grader is invoked via `commands.grade` (never npm-assumed).
- [ ] A fresh-context reviewer agent confirms solvable at the stated altitude/time — not
      over-scoped (guard against FM-10 in the *practice itself*).
- [ ] **Examiner-only robustness probes** for the gate's blind vectors ship in `_solutions/`,
      beside the frozen gate (not wired into `commands.grade`); each probe's expected result was
      captured from a real build (reference + stub), not guessed.
- [ ] **`rubric.md` encodes the harness-wide grading principles** (`harness/DESIGN.md` §2): a
      Source column on every driving row, the claims-re-run / silently-fixed-defect rows, and the
      review-without-reading-the-diff anti-signal; every row filled for every phase.
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
> **Proof:** [`practices/deliveries/_solutions/proof-train-2026-09-13.html`](../practices/deliveries/_solutions/proof-train-2026-09-13.html)
> — the recorded control runs and what they scored, the verified trap mechanisms, and the
> Train-mode session. Note what it records honestly: the control run clears the gate one-shot, so
> the gate is the floor and the transcript is the verdict.

To generate another, change only `domain` and `stack` and run the procedure — the training
points, the shape, and the gate stay identical. (Generating a second practice is **Phase 2**,
out of scope for this phase; this contract is the spec that Phase 2 executes.)
