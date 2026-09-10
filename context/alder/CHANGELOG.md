# Context "Alder" — changelog

Tree-name rationale: **Alder** is a nitrogen-fixing pioneer species — the first tree to
establish on bare ground, enriching the soil for everything that grows after. Fitting for the
first, foundational Context. See [`../../docs/TREE-NAMING.md`](../../docs/TREE-NAMING.md).

## 1.0.0 — first version
- **Goals:** the six core disciplines (+ three optional) a practice must train.
- **Best practices:** Anthropic prompt-engineering, *Building Effective Agents*, Claude Code
  discipline, and the altitude/restraint lessons of process-graded rounds.
- **Failure modes:** FM-01..FM-08 (codebase-plantable) + FM-09..FM-12 (driving/harness).
- **Generation spec:** the fixed practice shape, invariants, difficulty tiers, and the
  time/token estimation method.
- **Calibrated against** the `deliveries` kata (M tier), which is tagged `alder@1.0.0` and
  proves the Context can describe a real, runnable practice.

### Known gaps (candidates for v2, the next tree-name)
- Some FM-* entries still need fresh public citations (search outage during authoring).
- FM-11 (prompt injection) and FM-12 (security) are documented but not yet exercised by a
  generated practice — a v2 Context would add agent-harness and security-focused traps.
- The time/token model is a first estimate; Phase-2 runner actuals will re-calibrate it.
