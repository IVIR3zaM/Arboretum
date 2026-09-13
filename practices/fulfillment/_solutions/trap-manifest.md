# trap-manifest — everything planted, honestly inventoried

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Cross-reference
> `context/cedar/failure-modes.md` for each FM's full definition.

## Primary bug (phase 2)

**Location:** `backend/src/availability.ts`, `availableToPromise(sku, location)`, the `live`
branch — `return rec.on_hand;` should compute true ATP from the feed record (see `FIX.md`).

**The load-bearing design point:** there is **no correct ATP function in the local repo**. The only
availability helper is `backend/src/atp.ts` `promisableStock(rec) = on_hand − reserved` — a stale,
snapshot-era notion that subtracts reservations but knows nothing about `allocated` units or
lead-time-eligible `inbound`. The authoritative rule
(`ATP = on_hand − reserved − allocated + Σ(inbound within leadTimeDays)`) lives **only** in
`reference/atp-spec.md`. So the fix genuinely requires the research pass — you cannot derive the
`allocated` term or the inbound lead-time window from anything the local code shows you.

**Why it is invisible to the shipped suites (23/23 backend + 10/10 web, both green):** the unit
suites exercise the seed SKUs `SKU-1001`/`SKU-1006`, both never-reserved
(`reserved = allocated = 0`, no inbound), for which `on_hand`, `promisableStock`, and true ATP all
coincide. The local `snapshot.ts` fixture is built the same way, so even flipping `ATP_SOURCE`
doesn't expose the gap under seed data. The bug only produces a wrong answer for SKUs with open
reservations, allocations, or lead-time inbound — none of which the unit suites touch. It is caught
only by the hidden dual grader (`_solutions/backend-acceptance.test.ts` +
`_solutions/web-integration.test.tsx`, wired through `_solutions/grade.sh`), which calls the resolver root
directly with `ATP_SOURCE=live` against the full `reference/` feed. Verified flip: backend 6/14 →
14/14, web 1/2 → 2/2 (see `FIX.md`).

**FM coverage:**
- **FM-15** (context rot) — a stale code path (`return rec.on_hand`) plus a stale, incomplete
  helper (`promisableStock`) encoding the abandoned "availability = on-hand we hold" era, with a
  misleading comment and no local doc admitting the live-ATP truth. See the FM-15 section and
  `doc-drift-ledger.md`.
- **FM-01 × FM-02** — bug invisible to a large green suite (FM-01); silent/subset-only: correct for
  never-reserved SKUs, wrong for contended ones (FM-02, Cedar's cross-boundary extension of the
  ambient variable — the varying condition is which SKU/location record you query).
- **FM-16** (cross-boundary) — the true reserved/allocated/inbound numbers *and the formula that
  uses them* live only in `reference/`; a fix reasoned from the local repo alone plateaus (below).

## Assistant-targeted trap (FM-13, required) — the plausible fix plateaus

FM-13 is "delegation before comprehension." The trap here is **not** a strawman symptom-patch that
no engineer would write. It is what a competent engineer who pastes the ticket and delegates "fix
the oversell" — **without** doing the research pass — naturally produces: a plausible ATP formula
built from what the local code already shows (reservations), which gets *closer* with each guess but
cannot converge until the spec is read.

**The autopilot moves it punishes**, and why each fails (all measured, see VERIFIED-TO-BITE):
- **Subtract what's reserved** (`on_hand − reserved`, i.e. reach for the local `promisableStock`
  helper, or the obvious "net out demand" notion): **11/14**, still RED. Misses `allocated`
  (fails `SKU-1002`) and inbound (fails `SKU-1003`).
- **Also subtract `allocated`** (a better guess, still no spec): **12/14**, still RED. Now only the
  backorder+inbound SKU (`SKU-1003`) is wrong — its 20 inbound units arrive in 7 days, inside the
  30-day lead window, so they count toward ATP, but nothing local says so.
- **Symptom-patch the checkout handler** (special-case the ticketed SKU in `orders.ts`
  `confirmOrder` instead of the resolver): **7/14**, still RED — the grader calls
  `availableToPromise` at the **root**, so a call-site patch never changes what the root returns.

**The discipline that beats it:** *establish-cross-boundary-context* — open `reference/atp-spec.md`
and learn the two terms (`allocated`, inbound-within-lead-time) the local repo never had — plus
*model-before-delegation* (fix the resolver root, not the symptom) and *reconcile-docs* (don't trust
the stale `promisableStock`/READMEs). Only implementing the full spec formula at the root converges,
correct for every SKU at once (**14/14**).

### VERIFIED-TO-BITE (real captured `bash _solutions/grade.sh` outcomes)
Reproduced 2026-09-13 against the shipped (bug-present, strengthened) tree; every fix attempt was
applied at the root, measured, then reverted, so the shipped tree keeps the bug. Baseline:
**backend 6/14, web 1/2, exit 1 (RED)**.

| # | Fix attempt (what a realistic "fix it" delegation writes) | `grade.sh` result | What it proves |
|---|---|---|---|
| A | **`on_hand − reserved`** — the obvious local notion / the stale `promisableStock` helper | **backend 11/14, web 2/2 → FAIL** | Subtracts reservations but misses `allocated` (SKU-1002) and inbound (SKU-1003). Plausible, green unit suite, still red grader. |
| B | **`on_hand − reserved − allocated`** — a better guess, still without the spec | **backend 12/14, web 2/2 → FAIL** | Closes the allocation gap; still fails the backorder+inbound SKU (SKU-1003) — the lead-time-window rule isn't inferable locally. |
| C | **Symptom-patch** the ticketed SKU in `orders.ts` `confirmOrder` (call site, not root) | **backend 7/14, web 2/2 → FAIL** | The web gate and the one SKU's confirm pass, but the root-tested conformance vectors stay red. FM-13 symptom-patch. |
| D | **local-green vs prod-red** (no edit) | unit `23/23` + `10/10` GREEN, `grade.sh` RED | The "works on my machine" axis: the whole unit suite is green on the seed while the live feed oversells (FM-01). |
| E | **Correct** — full ATP formula from `reference/atp-spec.md` (incl. inbound-within-lead-time) at the root | **backend 14/14, web 2/2 → PASS** | Only implementing the rule the spec states converges, for every SKU at once. |

Net: every fix that stays inside the local repo (A 11/14, B 12/14, C 7/14) plateaus RED; only the
one that reads `reference/atp-spec.md` reaches 14/14 · 2/2. The trap bites a realistic delegation,
not just a careless one.

### Review (FM-14) — trained by phase 5, not planted in code
Phase 5 asks the learner to review the diff as a teammate's PR. FM-14 is defeated by anchoring the
review on the ticket's intent (no oversell against live ATP), triaging the load-bearing resolver
fix apart from the feature, and naming a real trade-off with the condition to revisit it — not
rubber-stamping the AI's change. The rubric's driving axis scores this; nothing to plant in source.

## Feature trap (phase 3) — the cart hold, objectively graded

`FEATURE-REQUEST.md` is a thin PM ask ("let shoppers hold an item for 10 minutes"). The held-back
requirements — the hold must **reserve against live ATP net of other carts**, be keyed on
**(SKU, cart)**, be released on **TTL**, and be **re-checked at confirm** — are not stated. A
straight "implement the hold" delegation (read-before-delegate / requirements-elicitation miss)
builds a hold *store* and a `placeHold` that checks availability once and records the hold, but
never wires it into `confirmOrder` and never accumulates across carts. It looks done — unit suites
green, the button works — and it **oversells**: two carts hold the same units and both confirm.

This is now **objectively gated** (not just rubric-judged) by
`_solutions/feature-acceptance.test.ts`, driven through the public surface (`placeHold` +
`confirmOrder`) against the live feed, and wired into `_solutions/grade.sh` as gate (b). Measured
(2026-09-13, each impl applied on a fixed base then reverted):

| Cart-hold implementation | feature acceptance | result |
|---|---|---|
| Stub (`placeHold` throws) | **0/4** | RED — feature not built |
| Naive: records holds, checks ATP once, **confirm not re-checked**, no accumulation | **2/4** | RED — oversells (cart A holds 15, cart B still confirms 10 on a 22-ATP SKU; holds don't accumulate) |
| Correct: reserve vs live ATP net of other carts, keyed (SKU,cart), re-checked at confirm | **4/4** | GREEN |

The whole ticket (`bash _solutions/grade.sh`) is GREEN only when the bug fix (availability 14/14) **and** the
correct hold (feature 4/4) **and** web (2/2) all pass — "fix and deliver." Defeated by
*requirements-elicitation* + *read-before-delegate* (read how confirm decides availability before
building the hold) and *restraint* (build the minimal correct hold; defer un-hold/limits/billing).
Note the feature also inherits the primary bug's dependency: a correct hold on an unfixed base still
fails, because it would reserve against the wrong ATP.

## FM-15 — context rot (detail)

**The stale code paths:** (a) `availability.ts`'s `live` branch, `return rec.on_hand;`, with a
comment claiming it "mirrors the nightly availability_snapshot's on-hand figure"; and (b)
`atp.ts`'s `promisableStock` (`on_hand − reserved`), whose comment frames it as how availability
"has always" been computed. Both encode earlier stages of the `stock_count` → `availability_snapshot`
→ live-ATP migration; neither computes true ATP, and **no local doc says so**. The live-ATP truth
appears only in `reference/atp-spec.md` and `reference/erp-availability-contract.md`.

**The contradicting docs:** see `doc-drift-ledger.md` — `backend/README.md`'s "stock is decremented
from `stock_count`" (two migrations stale) and `web/README.md`'s `GET /stock` route name (the real
route is `GET /availability`) are prose that lags the migration and steers a doc-trusting prompt to
the wrong model.

## FM-16 — cross-boundary (detail)

The authoritative reserved/allocated/inbound numbers **and the formula that combines them** exist
only in `reference/` — `reference/infra/erp-availability/*.json` (the feed),
`reference/erp-availability-contract.md` (live query, keyed on `(sku, location)`, returns `atp`,
never `on_hand`), and `reference/atp-spec.md` (the formula, with the inclusive `<=` lead-time
boundary). A fix attempted without opening `reference/` can only see the local `on_hand` snapshot
and the stale `promisableStock`, so it guesses a formula that misses `allocated` and/or the inbound
window — and the grader's conformance vectors, derived directly from the feed, catch it (attempts A
and B above). This is why the research pass (`research-notes.md`) is the load-bearing discipline.

## Ranked latent defects (≥5, each idiomatic, each traceable to an FM)

Ranked by production impact. None is exercised by the shipped suites or required to reach 14/14 +
2/2 (the grader tests with quantities and valid locations away from these boundaries), so the
primary fix alone reaches full marks. They exist for the learner's honest-review pass (FM-14) to
*find and name*.

1. **FM-06 — idempotency keyed on transport id, not the business entity.**
   `backend/src/orders.ts`, `confirmOrder`: `processed.get/set(order.requestId, ...)`. `requestId`
   is the per-attempt client transport id; the business entity is the order (`orderId`). A retry
   carrying a fresh `requestId` for the same logical order is not recognized as a duplicate and can
   confirm twice / oversell.

2. **FM-05 — reservations store returns internal state by reference.**
   `backend/src/reservations.ts`: `active(sku)` returns the live array inside the module's `Map`
   (not a copy) and `all()` returns the `Map` itself; a caller that mutates what it got back
   corrupts the store's internal state.

3. **FM-07 — unbounded holds map, no TTL eviction.**
   `backend/src/reservations.ts`: `place` only appends; nothing sweeps expired holds by
   `expiresAt`/`ttlMs`. Once the cart-hold feature is wired up, every expired-but-unswept hold
   suppresses availability forever — a slow ATP leak.

4. **FM-04 — strict boundary comparison at exactly-zero / exactly-ATP.**
   `backend/src/orders.ts`, `confirmOrder`: `order.qty < atp` (strict `<`, so ordering *exactly*
   the remaining ATP is rejected) and `availability.ts` `checkAvailability`: `inStock: atp > 0`.
   Neither the spec nor a test pins which side is correct; `SKU-1005`'s exactly-zero-ATP record
   exists to exercise this once a learner probes boundaries.

5. **FM-08 — location not validated against the authoritative set.**
   `backend/src/erpFeed.ts` `getRecord(sku, location)` and `availability.ts`: `location` is threaded
   through every call but never checked against `reference/erp-availability-contract.md`'s
   authoritative set (`{DC-WEST, DC-EAST}`). `UnknownLocationError` is defined in `types.ts` but
   never thrown; a typo'd/unprovisioned location doesn't fail as the ERP contract specifies — the
   feed lookup proceeds keyed by SKU id alone and can silently serve the wrong location context.
