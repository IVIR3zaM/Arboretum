# BUILD-LEDGER — `fulfillment` practice build

> **Spoiler / build-only.** Lives in `_solutions/` because it references the fix and is stripped
> from learner clones (AGENTS.md placement rule 2). This is the **single source of truth for build
> progress**. On resume: read this, continue from the first node not `done` (re-verify the last
> `doing` node).

## Run config (confirmed)
- **Repo / branch:** `IVIR3zaM/Arboretum`, integrate + push to **`main`** (sole durable history).
- **Grade gate:** **FULL DUAL** — `grade.sh` ANDs backend acceptance AND a real React web
  integration test; exit 0 only if both pass at worst-case.
- **Toolchain:** Node v22.22 (native `.ts` strip). Backend = zero runtime deps, `node --test` on
  `.ts`. Web = React + Vite + Vitest/RTL via `npm ci` (network only at install; grade is hermetic).
- **Model tiers:** orchestrator = thread model; builders/verifier = sonnet; N9 reviewer = opus.
- **Isolation:** each sub-agent runs `isolation: worktree` on a local `build/<node>` branch; I
  integrate its diff onto main, update this ledger, commit, push, then the worktree is discarded.

## The practice in one paragraph (so any node's packet is self-contained)
Commerce fulfillment. A storefront (`web/`) asks an order/availability service (`backend/`) whether
a SKU can be shipped and confirms orders against a warehouse/ERP's **available-to-promise (ATP)**.
The repo migrated `stock_count` → nightly `availability_snapshot` → **live ATP**, but a
long-untouched availability/confirm path still reads `availability_snapshot.on_hand` instead of
issuing the **live ATP query**. That path is correct on local seed (SKUs with **zero
reservations** → snapshot == ATP) and green to the whole unit suite, but **oversells in prod**
(SKUs with reservations/allocations/inbound). The true reserved/allocated/inbound numbers live
**only** in read-only `reference/`. Fix = implement the real live ATP query at the resolver root:
`ATP = on_hand − reserved − allocated + inbound-within-lead-time` (per `reference/atp-spec.md`).

## DAG / status
| Node | Goal | Agent | Deps | Status | Commit | ESCALATE |
|---|---|---|---|---|---|---|
| N0 | ledger + per-node constraint packets | orch | — | doing | — | none |
| N1 | `reference/` external truth + hermetic file resolver | builder | N0 | todo | — | — |
| N2 | `backend/` src (stale-snapshot bug behind resolver seam) | builder | N1 | todo | — | — |
| N3 | `web/` src (product page, badge, cart-hold stub, checkout) | builder | N2 | todo | — | — |
| N4 | GREEN unit suites (backend + web); bug invisible | builder | N2,N3 | todo | — | — |
| N5 | hidden graders + `grade.sh` (dual, worst-case); FAILS now | builder | N1,N2,N4 | todo | — | — |
| N6 | `_solutions/` docs (FIX, feature-qa, trap-manifest, rubric, context-map, doc-drift) | builder | N2,N5 | todo | — | — |
| N7 | learner docs + `practice.json` + plant stale docs | builder | N6 | todo | — | — |
| N8 | traps-bite verification (autopilot check) | verifier | N5,N6,N7 | todo | — | — |
| N9 | fresh-context review vs acceptance checklist | reviewer | N7,N8 | todo | — | — |
| N10 | proof: train run + `proof-train-<date>.html` | orch+exec | N9 | todo | — | — |

Legend: todo · doing · done · blocked.

---

## Per-node constraint packets (what each sub-agent is told; they read ONLY their node's files)

### N1 — `reference/` (read-only external truth) + hermetic resolver
Create under `practices/fulfillment/reference/`:
- `erp-availability-contract.md` — sibling ERP service contract: availability is a **live query**
  keyed on **(SKU, location)**; returns **ATP**, not on-hand; names the authoritative location set.
- `atp-spec.md` — the calc spec: `ATP = on_hand − reserved − allocated + inbound-within-lead-time`;
  inbound counts only within the SKU's **lead-time window**; **on-hand alone is not promisable**.
- `infra/erp-availability/*.json` — the cloud-hosted feed, one file per SKU (or one feed file),
  each with `on_hand`, `reserved`, `allocated`, `inbound[] {qty, arrivesInDays}`, `location`.
  Cover **≥3 SKU states**: (a) never-reserved (matches local seed: reserved=allocated=0),
  (b) open reservations/allocations (ATP < on_hand), (c) backordered + inbound (on_hand low,
  inbound within lead time lifts ATP). Add SKUs that also exercise the latent-defect boundaries
  (exactly-zero ATP; inbound just inside vs just outside the lead-time window; an unknown location).
- Fixtures are **static JSON read from disk** — hermetic, **no network**. Also provide the local
  **snapshot** seed fixtures used by dev/CI (same SKUs but with reserved=allocated=0 so
  snapshot.on_hand == ATP for the seed set only).
Constraints: `reference/` is read-only truth the learner distills into `research-notes.md`; do NOT
put any fix or answer text here. Keep it plausible production infra config.

### N2 — `backend/` source (TS/Node, zero runtime deps, node>=22.18)
Package `practices/fulfillment/backend/` with `package.json` (type module, engines node>=22.18,
scripts: test=`node --test test/*.test.ts`), `src/`:
- `types.ts` — SKU, Sku availability record, Reservation/Hold, Order, error classes.
- `feed.ts` / `snapshot.ts` — snapshot store (reads local snapshot fixtures) AND a live-ATP source
  that reads `reference/infra/erp-availability/*.json` and computes ATP per `atp-spec.md`.
- `resolver.ts` — **the resolver seam**: `availabilityFor(sku, location)` selects the source by an
  env var (e.g. `ATP_SOURCE=snapshot|live`, default snapshot for dev/CI). **PLANT THE BUG HERE**:
  the confirm/availability **root** used by order placement reads `snapshot.on_hand` as if it were
  promisable, instead of the live ATP query. Idiomatic, no comment admitting it. Under the seed
  (0 reservations) snapshot==ATP so it's correct-by-accident.
- `reservations.ts` — reservation/hold store (holds map — see latent defects).
- `orders.ts` — order confirm root: checks availability then confirms; this is what the grader
  calls directly (root-tested, so a checkout-handler symptom-patch stays red).
- `catalog.ts` — product/catalog listing.
- Plant the **ranked latent defects** (each idiomatic, each traceable to an FM; full list lives in
  N6 trap-manifest): FM-06 idempotency on transport `requestId` not `orderId`; FM-05 store returns
  internal object by reference; FM-07 unbounded holds map (no TTL eviction); FM-04 ATP compared
  with strict `>`/`>=` at exactly 0; FM-03 inbound "within 30 days"≈month OR unknown-SKU
  fall-through to available; FM-08 free-form location code trusted without validating against the
  ERP's authoritative set.
- Cart-hold = a **stub** that throws "not implemented" (the phase-3 feature).
- Keep the diff/impl idiomatic and tier-sized; the ONLY defects are the planted ones.

### N3 — `web/` source (React + Vite + TS)
Package `practices/fulfillment/web/` with Vite+React+TS, `package.json` (scripts: dev, build,
test). Components: product page, **stock badge** (in-stock/sold-out from `GET /availability`),
add-to-cart **hold stub**, checkout. It calls the backend availability/confirm contract. The hold
is a stub for phase 3. Must **build** and be testable by RTL/Vitest (needed for the dual gate).
Keep it minimal — no router zoo, no state-management library; the smallest correct storefront.

### N4 — GREEN unit suites (both packages)
`backend/test/*.test.ts` + `web/**/*.test.tsx`. All green. The **primary bug is invisible**: unit
tests use the **local seed** SKUs (0 reservations) so snapshot==ATP, and test availability away
from the contended boundary. Cover the happy paths and the still-working subset only. Do NOT test
the confirm root against the reference feed here (that's the grader's job). `commands.test` green.

### N5 — hidden graders + `grade.sh` (FULL DUAL, worst-case) — must FAIL now
In `_solutions/`:
- `backend-acceptance.test.ts` — calls the availability/confirm **root** directly with the resolver
  pointed at the **live `reference/` feed**, across ≥3 SKU states + `reference/`-derived
  **conformance vectors**. Asserts no oversell. FAILS with the stale-snapshot bug present.
- web integration test (RTL or Playwright component) — storefront produces a request the backend
  **accepts** for a promisable SKU and **rejects** (no oversell) for a contended one.
- `grade.sh` at `practices/fulfillment/grade.sh` — the wrapper `commands.grade` invokes (bash, NOT
  `npm run grade`): runs backend acceptance (worst-case across SKU states + vectors) AND the web
  integration gate; ANDs them; prints a worst-case score; exit 0 only if both pass. Hermetic.
- **Do NOT weaken the grader to pass.** It must be RED pre-fix and GREEN only after the reference
  fix (implement the live ATP query at the resolver root). Builder verifies the flip on a THROWAWAY
  copy (apply fix → green → discard fix), reports both numbers, leaves the shipped tree bug-present.

### N6 — `_solutions/` docs
- `FIX.md` — the real live ATP query at the resolver root; why re-import/hard-code plateaus; the
  caching/TTL aside is **named, not built** (restraint).
- `feature-qa.md` — the 6–8 held-back cart-hold questions + answers + minimal correct behaviour
  (reserve against live ATP, keyed on business entity, TTL release, re-checked at confirm; defer
  the rest out loud).
- `trap-manifest.md` — every planted item → FM id + location + (for assistant traps) the autopilot
  move it punishes + the discipline that beats it. ≥5 ranked latent defects. Leaves room for N8's
  verified-to-bite notes.
- `rubric.md` — objective gate (both stacks, worst-case) + driving axis incl. research pass (FM-16)
  and doc reconciliation (FM-15).
- `context-map.md` — golden cross-boundary contract: current method = live ATP; hosted-feed truth;
  the one load-bearing fact **on-hand ≠ promisable**.
- `doc-drift-ledger.md` — every planted contradiction (README says `stock_count`; comment says
  "nightly snapshot"; field-name drift available/on_hand/atp; web says `GET /stock`; "DB constraint
  prevents oversell" claim) → its authoritative source and why.

### N7 — learner docs + metadata
- `README.md` — lift the graphical domain primer **verbatim** from DESIGN.md (the 3 mermaid
  diagrams + prose) into Background; add the 5-phase flow (research pass inside *understand*) + the
  time/token estimate. Point at `_solutions/` as spoiler.
- `TICKET.md` — the symptom only (no file/line): "green on staging/every dev machine; in prod a
  handful of SKUs we started pre-selling let customers order more than we can ship."
- `FEATURE-REQUEST.md` — 2–3 sentences (10-min cart hold), with the hint to read how confirm
  decides availability first.
- `practice.json` — finalize from the DESIGN draft; **drop `status`**; declare
  `commands.{install,test,grade}` (grade = `bash grade.sh`); estimates per the spec method
  (XL ~1,200–1,600 LOC → ~135 min, ~60,000 tokens).
- **Plant the stale docs (FM-15):** `backend/README.md` says stock decremented from `stock_count`
  (two migrations stale); a `backend/src` comment near the stale resolver references "the nightly
  snapshot"; `web/README.md` says `GET /stock`; a README line claims a DB constraint prevents
  oversell. No doc anywhere admits the live-ATP truth.

### N8 — traps-bite verification (throwaway worktree; discard bad edits)
Prove, with real command outcomes: (1) symptom-patch the checkout handler → grader still RED;
(2) re-import/hard-code the one failing SKU → unit suite green + that SKU passes but the grader
**plateaus** on the next reserved SKU; (3) a no-`reference/` run makes the local assumption and
**fails the conformance vectors**; (4) local-green vs prod-red demonstrated (seed passes, reference
feed fails) and the real live-ATP fix reaches full marks. Only the verified-to-bite NOTES are
written to `_solutions/trap-manifest.md`; the deliberately-wrong code is discarded, never merged.

### N9 — fresh-context review (opus, read-only)
Fresh agent (≠ any builder). Confirm vs `generator/CONTRACT.md` Acceptance checklist +
`generation-spec.md` validation: solvable at XL altitude, not over-scoped; every required
discipline reachable **without reading `_solutions/`**; grader flips red→green; FM-13/15/16 traps
present and biting; `practice.json` valid. Return pass/fail with failing items only.

### N10 — proof (orch + executor)
Drive the practice end-to-end once (train mode) per AGENTS.md harness rules (clone → strip
`_solutions/` → execute learner prompts in `work/` → examiner grades from golden context). Capture
**real** baseline→final unit + grader numbers. Write `_solutions/proof-train-<YYYY-MM-DD>.html`
(mirror the `deliveries/` proof shape: harness/mode/date/model, per-phase prompt → behaviour →
designed trap → examiner output → real command outcome). Refresh if the practice changed.

## Checkpoint log (append one line per integrated node)
- (N0) ledger created — pending first commit.
