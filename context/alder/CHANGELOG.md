# Context "Alder" — changelog

Tree-name rationale: **Alder** is a nitrogen-fixing pioneer species — the first tree to
establish on bare ground, enriching the soil for everything that grows after. Fitting for the
first, foundational Context. See [`../../docs/TREE-NAMING.md`](../../docs/TREE-NAMING.md).

## 1.3.0 — the feature trap must discriminate, and grading gets disciplined
Driving a practice end-to-end through the harness surfaced a gap the earlier control run did not
catch: a feature request could be handed to an assistant raw — *"just build it"* — and still clear
the feature gate, because the gate scored "a feature exists" rather than "the rules only
elicitation surfaces." A gate that an autopilot feature build passes is a completion floor, not a
trap. The same run exposed that some grading rested on the assistant's own self-reported numbers
and on raw-byte output comparison, and that gate-blind robustness vectors had nowhere to be
recorded. The fixes are folded up out of the one practice into the Context and the harness.
- **Generation spec:** invariant 3 now requires the feature to **read as easy and mislead** — lean
  the obvious build onto the wrong rule — and the gate to score the elicitation-only rules.
  Validation gains a **paired naive-vs-elicited build**: the feature trap counts only if a naive
  one-shot (fresh executor) *fails* the feature gate and an elicited build *passes*. Added
  **examiner-only robustness probes** (gate-blind vectors covered beside the frozen gate, never
  inside it, each expectation captured from a real build) and **manifest completeness** (claimed
  modes planted where a run reaches them; emergent findings and a reference fix's known limitations
  recorded separately from the planted count).
- **Generator contract:** the feature, proof and acceptance steps carry the paired-build
  requirement; the manifest and grader steps carry emergent-findings and known-limitation
  recording; the rubric step requires the harness-wide grading columns.
- **Templates:** `practice.template.json`'s `featureTrap` becomes an object recording the lure and
  the naive/elicited scores.
- **Harness & operator docs (repo-level):** `harness/DESIGN.md` §2 states the grading principles
  that apply to every practice — compare grade output **normalised**, never raw bytes; **check
  self-reported counts against real command output**; a **latent defect fixed silently before its
  phase** is scored on restraint, not found/missed. `AGENTS.md`'s setup block creates the session
  dir before cloning, and its rules header points at DESIGN §0–§3.

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
- **Work items are staged, one phase at a time.** A learner never holds a bug report and a feature
  brief at once — work does not arrive that way, and a clone carrying both lets the assistant read
  ahead and plan around a brief nobody has given it, blunting the phase it has not reached.
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
