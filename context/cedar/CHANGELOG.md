# Context "Cedar" — changelog

Tree-name rationale: **Cedar** is an ancient, long-lived giant whose timber is prized for being
**rot-resistant** — it stands for decades in weather that rots ordinary wood. Fitting for the
Context whose headline lesson is resisting **context rot**: the slow, silent drift of docs,
comments, and invariants away from the code as an AI-grown repo accretes, and the wrong
assumptions a single-repo assistant makes when the truth lives across a boundary it never loaded.
Cedar is the giant-species jump beyond the Alder pioneer: deeper, multi-repo, production-shaped.
See [`../../docs/TREE-NAMING.md`](../../docs/TREE-NAMING.md).

Cedar **inherits the whole of Alder** — every discipline in [`goals.md`](goals.md), every entry
FM-01..FM-14 in [`failure-modes.md`](failure-modes.md), and best practices A–E — and extends it.
A practice pins the exact Context it trains to via `practice.json` → `contextVersion`; a Cedar
practice declares `cedar@1.1.0`.

## 1.1.0 — the workdir stops coaching, across a boundary
Cedar 1.0.0 branched from `alder@1.1.0` and shipped before Alder learned its hardest lesson. Alder
1.2.0's control run — a fresh assistant, a cloned practice, one casual uncoached prompt — showed
that the material in the clone was handing over the method, and Cedar inherited none of the fix:
its spec still claimed "invariants 1–9 are Alder's", its ticket skeleton still ended with
"reproduce first… the grade command checks it", its feature-request skeleton still carried a ⚠️
pointing at the trap, and its layout still put the grade wrapper at the practice root, inside the
clone. This version carries Alder 1.2.0 forward and works out what it means when the truth lives
across a boundary.
- **Generation spec:** Alder's invariant 10 arrives as Cedar's **invariant 12** — *nothing the
  assistant can read coaches it* — numbered 12 because 10 (context rot) and 11 (cross-boundary
  cause) were taken when Cedar branched. Three Cedar-specific clauses: the FM-15 drifting doc must
  **mislead, not confess** (a doc that hedges "may be out of date" hands over the reconciliation);
  `reference/` reads as a **vendor snapshot, not a hint sheet** (it never tells the reader to study
  it, distill it, or compare it with the local repo); and a module citing the spec it consumes is
  **evidence, not coaching** — the line is between citing a source and interpreting it.
- **The practice shape is now three layers,** not two: the cloned repo + work items,
  the exercise material (`README.md`, `practice.json`), and `_solutions/`. The **grade wrapper moves
  into `_solutions/`** — at the practice root it was cloned, and it announced the hidden gate.
- **Work items are staged, one phase at a time** — the ticket first, the feature request at phase 3
  — **but `reference/` is not.** It is in the clone from the start: it is the external
  documentation an engineer already has on day one, most Cedar packages read it at runtime, and
  handing it over at the moment the research pass is due *is* the coaching, because it announces
  that the local repo is not the whole story — the exact judgement FM-16 exists to measure. The
  trap is not that `reference/` is hidden; it is that a single-scope run never opens it.
  `AGENTS.md` and `harness/DESIGN.md` corrected to match.
- **Validation:** added the **control run**, and made it do double duty — for a Cedar practice,
  what an uncoached run does with `reference/` sitting in front of it *is* the cross-boundary
  measurement, and the transcript must say which.
- **Templates:** the `TICKET.md` and `FEATURE-REQUEST.md` skeletons no longer prescribe the method
  or flag the trap; `README.md` is documented as the out-of-clone briefing where coaching belongs;
  `practice.template.json` gains `controlRun` (with a `reference` field recording whether the run
  opened it) and `proof`.
- **The first Cedar practice** re-aligned to `cedar@1.1.0`: the grade wrapper moved out of the
  clone, a source comment that named the grader and two test comments that confessed the suite's
  blind spot removed, and a control run recorded.

## 1.0.0 — multi-repo, external truth, and context rot
- **New failure modes:** **FM-15** — documentation & invariant drift ("context rot"): as an
  AI-grown repo accretes, docs/comments/contracts drift from the code and from each other, and a
  stale code path can encode an abandoned assumption that no doc mentions and a large green suite
  never re-checks; the assistant treats the stale prose (or the stale path) as ground truth.
  **FM-16** — single-scope assumptions across repos / external systems: a harness started over one
  repo cannot see the truth that lives in a sibling service or cloud infra, so it fabricates
  assumptions that pass locally but violate the real cross-boundary contract.
- **New disciplines:** *establish-cross-boundary-context* and *reconcile-docs / trust-code-over-prose*
  (both core).
- **Best practices:** added **section F — Working across boundaries**: a research/context-priming
  pass into a durable notes file before delegating; treat docs as stale/untrusted and verify
  against code + an authoritative source; distill external repos/infra into a compact local
  reference rather than assume.
- **Generation spec:** added **invariant 10** (plant context rot in both forms — a no-doc-trace
  stale code path *and* a doc/code contradiction from a partial migration) and **invariant 11**
  (the true cause of ≥1 defect lives only in a read-only `reference/`, defeatable only by a
  research pass that writes `research-notes.md`); **extended invariant 2** so the ambient variable
  may be cross-boundary / externally-hosted state, not only process-local env; added the
  **multi-repo practice shape** (multiple package dirs + read-only `reference/`), the **dual grade
  gate** (both stacks graded via a wrapper `commands.grade`), and a new **XL difficulty tier** with
  a provisional re-calibrated estimate.
- **First Cedar practice designed** as a multi-package, dual-stack XL blueprint (see the
  `practices/` directory). The runnable kata and its recorded proof are a follow-up build; this
  version ships the Context and the blueprint.

### Known gaps (candidates for the next version)
- The XL time/token model is a first estimate; Phase-2 runner actuals will re-calibrate it.
- The dual (Rust + Flutter) grade gate is heavier than Alder's single-runner katas; the generation
  spec records a Rust-only fallback if the Flutter gate proves too costly for CI.
- The read-only `reference/` is a documentation convention over the existing single-clone harness;
  a future tree may add a first-class multi-workdir runner.
