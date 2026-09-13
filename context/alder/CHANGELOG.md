# Context "Alder" — changelog

Tree-name rationale: **Alder** is a nitrogen-fixing pioneer species — the first tree to
establish on bare ground, enriching the soil for everything that grows after. Fitting for the
first, foundational Context. See [`../../docs/TREE-NAMING.md`](../../docs/TREE-NAMING.md).

## 1.2.0 — the workdir stops coaching
A control run — a fresh assistant given a cloned practice and one casual, uncoached prompt —
cleared the objective gate outright, including the traps the practice claimed an autopilot could
not pass. The traps themselves were sound when checked by hand; the learner-facing prose was
handing over the method, and the material the harness left in the clone was handing over the
rest. A practice is an instrument for measuring how someone drives, and this one was coaching the
subject it was measuring.
- **Generation spec:** new **invariant 10** — *nothing the assistant can read coaches it*. The
  ticket is a symptom and a broken promise, with no method, no mechanism and no mention of the
  grader; the feature request is the PM's ask with no warning that a trap exists; source and test
  comments leave evidence but never narrate the defect or confess the suite's blind spot; the
  grade command is neither runnable from nor referenced inside the clone.
- **The practice shape is now three layers,** not two: the work items and service repo (cloned),
  the exercise material (`README.md`, `practice.json` — *not* cloned, because the briefing names
  the phases under test and the manifest names every trap), and `_solutions/` (hidden). Coaching
  belongs to the learner's briefing and to the trainer, never to the workdir.
- **Validation:** added the **control run** — clone it as the harness would, hand a fresh
  assistant one uncoached prompt, grade what comes back, and record the score in the proof. A
  trap a control run walks past is not a trap; verifying its mechanism by hand proves nothing
  about prose that gives the answer away.
- **Templates:** the `TICKET.md` and `FEATURE-REQUEST.md` skeletons no longer prescribe the
  method or flag the trap (they previously ended with "reproduce first… the grade command checks
  it" and a ⚠️ pointing at the invariant); `README.md` is documented as the out-of-clone briefing
  where coaching belongs.
- **The calibration kata** re-aligned to `alder@1.2.0` and re-proved against a recorded control
  run.

## 1.1.0 — over-reliance, review, and delegation discipline
- **New failure modes:** **FM-13** — delegation before comprehension (the unconvergent prompt
  loop): the over-reliance failure where work is delegated before a mental model exists, so
  prompting loops, symptoms get patched, and code is owned that can't be debugged. **FM-14** —
  review without triage or intent: AI makes code cheap to write and expensive to review, and the
  review step becomes the bottleneck.
- **New disciplines:** *model-before-delegation* and *comprehension-as-ownership* (core);
  *review-with-triage+intent* and *incremental-reversible-change* (optional).
- **Best practices:** added *model before you delegate*, *tests first — and validate the test's
  intent*, and *small, reversible steps*; extended adversarial review with **intent + triage**.
- **Generation spec:** every practice must now plant an **assistant-targeted over-reliance trap**
  (invariant 9) so an *autopilot* run provably loops; **FM-13 required by default**; added the
  autopilot validation check.
- **The calibration kata** re-aligned to `alder@1.1.0`: FM-13/FM-14 coverage, an explicit
  over-reliance trap, and an added acceptance case that a plausible autopilot fix fails (only an
  understanding-based fix converges).

## 1.0.0 — first version
- **Goals:** the six core disciplines (+ three optional) a practice must train.
- **Best practices:** Anthropic prompt-engineering, *Building Effective Agents*, Claude Code
  discipline, and the altitude/restraint lessons of process-graded rounds.
- **Failure modes:** FM-01..FM-08 (codebase-plantable) + FM-09..FM-12 (driving/harness).
- **Generation spec:** the fixed practice shape, invariants, difficulty tiers, and the
  time/token estimation method.
- **Calibrated against** a first M-tier kata, tagged `alder@1.0.0`, proving the Context can
  describe a real, runnable practice.

### Known gaps (candidates for v2, the next tree-name)
- Some FM-* entries still need fresh public citations (search outage during authoring).
- FM-11 (prompt injection) and FM-12 (security) are documented but not yet exercised by a
  generated practice — a v2 Context would add agent-harness and security-focused traps.
- The time/token model is a first estimate; Phase-2 runner actuals will re-calibrate it.
