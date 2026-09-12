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
practice declares `cedar@1.0.0`.

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
