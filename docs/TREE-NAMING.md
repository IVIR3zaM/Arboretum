# Tree-naming scheme for Context versions

Each Context version gets a **tree name** chosen for what's inside it — not a sequential
codename. The name is a mnemonic for the Context's maturity and breadth.

## The rule
Pick a tree whose character matches the version's contents:
- **Early, foundational, fast-moving** → a **pioneer species** (first to colonize bare ground,
  enriches the soil for what follows): Alder, Birch, Willow, Rowan, Aspen.
- **Broad, stable, widely-relied-on** → a **canopy / long-lived species**: Oak, Beech, Maple.
- **Comprehensive, deep, slow-changing** → an **ancient / giant species**: Sequoia, Redwood,
  Cedar, Yew.

A new tree name signals a **meaningful jump** in what the Context knows (new failure-mode
families, a re-calibrated estimation model, new disciplines) — not a patch. Patches bump the
semver *within* a tree (`alder@1.0.0` → `alder@1.1.0`).

## Assigned
| Version | Tree | Why this tree |
|---|---|---|
| v1 | **Alder** | Nitrogen-fixing pioneer — the first tree on bare ground, enriching the soil for everything after. The foundational Context: core disciplines, FM-01..FM-14, the generation spec, one calibrated kata. |
| v2 | **Cedar** | Rot-resistant giant — its timber stands for decades where ordinary wood rots. The Context about resisting **context rot**: doc/invariant drift (FM-15) and single-scope assumptions across repos / external systems (FM-16). Inherits all of Alder and adds the two disciplines, section-F best practices, the multi-repo shape (a read-only `reference/`), the dual grade gate, and the XL tier. First designed kata: `credentials` (Flutter + Rust, decentralized identity). |

## Candidates for later versions (not yet assigned)
- **Rowan / Birch** — a second pioneer pass: more plantable failure modes, more stacks, the
  first generated (non-seed) practices.
- **Oak** — the Context has broad, stable coverage and a re-calibrated time/token model from
  real runner data; exercises prompt-injection and security traps (FM-11, FM-12) directly.
- **Sequoia / Redwood** — a deep, comprehensive Context spanning many domains, difficulty
  tiers, and a first-class multi-workdir agent-harness runner (beyond Cedar's read-only
  `reference/` convention).

The seed kata pins the exact version it was built for (`practice.json` → `contextVersion:
alder@1.1.0`), so a practice always declares which Context it trains to.
