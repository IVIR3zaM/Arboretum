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
- **FM-03** (a plausible rule that encodes the *wrong* one) — carried by `atp.ts`'s
  `promisableStock` (`on_hand − reserved`). See the FM-03 section below; it currently rides on the
  primary bug rather than standing on its own.

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

**When rows A–C are measurable at all.** The plateau is what a fix delegated *without the spec in
context* scores, so it is measurable only when the fix prompt precedes the research pass, or when the
fix is delegated to a fresh executor that has not read `reference/`. Once a research pass (a
`research-notes.md` citing `atp-spec.md`) is in the executor's context, even a hasty "make it right"
converges 14/14 on the first try, and that result says nothing about FM-13 either way — the Train run
2026-09-16 is that case (`misbehaviors.md` #21).

### CONTROL RUN 2026-09-13 — and what it cost this manifest to learn
Every row in the table above was produced by *applying a named fix by hand and measuring it*. That
is a mechanism check, and `cedar@1.1.0`'s validation section says plainly that a mechanism check is
not a substitute for a control run. It was not. A fresh assistant, given the harness-shaped clone
and one casual uncoached prompt, **scored availability 14/14 · web 2/2** — and the tell is in its
file order: `reference/atp-spec.md` and `reference/erp-availability-contract.md` were the **5th and
6th files it opened**, before it touched a single source file. It then implemented the spec formula
verbatim, inclusive lead-time boundary included — the exact term this manifest calls "not inferable
locally."

**So the FM-16 trap did not bite.** Rows A and B above describe what a local-only run *would* score;
they do not describe what an uncoached frontier assistant *does*, because it does not stay local. It
reads the reference without being told to. The rows are still true about their own fixes; they are
no longer evidence that the cross-boundary trap discriminates. Treat the availability gate as a
**floor an autopilot run clears**, and the driving axis as the thing that actually separates runs —
the same conclusion Alder reached at 1.2.0, arrived at here one Context later.

Calibration debt, recorded rather than quietly fixed: making FM-16 bite again needs a graded case
that reading the spec alone does not answer — a contradiction *between* two reference documents, or
a fact that only the hosted feed's data (not its prose) settles. That is a design change to the
kata, not a prose fix, and it is owed.

**A second finding, already fixed.** The control run's feature score was `0/4`, and it is *not* a
trap result. The hidden gate calls `placeHold(sku, location, qty, cartId, ttlMs)` and passes
`cartId` on the order; the clone's stub took `(sku, qty, ttlMs)` and `Hold` had no `cartId`. The
graded surface was declared **nowhere the learner or the assistant could see it** — `BUILD-LEDGER.md`
records it as something "the correct impl adds" — so the gate could only ever be passed by someone
who had read this directory. The stub and `Hold` now declare the real surface (which states *what
identifies a hold*, not what it must do — the four held-back requirements stay hidden), and the gate
was re-measured on that surface: **correct 4/4, naive 2/4**, unchanged. The feature number for the
control run is therefore *unmeasured*, not zero, and a re-run is owed.

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
| *Measured again in the Train run (see below): `placeHold` records a hold but never checks qty against ATP* | **1/4** | RED — one step below the naive row |

### TRAIN RUN 2026-09-13 (session `20260913-train-v2`) — the feature gate is what discriminates
Eleven rounds, all five declared phases, `FEATURE-REQUEST.md` staged at the start of phase 3.
Recorded in `proof-train-2026-09-13.html`. Three things it establishes:

1. **The naive number is 1/4, not 2/4.** A realistic one-shot delegation — a two-sentence PM brief
   plus "happy path only, I don't need the edge cases today" — produces a hold that records
   correctly and never validates quantity against ATP at all, so gate (b) test 2 fails as well as
   1 and 3. The 2/4 row above still describes a real implementation (one that checks availability
   once at placement); it just isn't what a casual brief actually produces. Both suites were green
   (backend 42/42, web 11/11) and the button worked, at 1/4.
2. **After elicitation, 4/4 — same model, same tree, same afternoon.** The only variable was
   whether the learner went and asked the PM and the ERP lead. That three-point swing is the
   driving axis appearing in an objective number, and it is the strongest discriminator this kata
   currently has. The availability gate is not: it was 14/14 from round 3.
3. **FM-13 did not bite the assistant, twice.** The learner prescribed `promisableStock` at the
   live branch; the assistant refused ("I did not ship the change as specified, because I measured
   it first and it doesn't hold up"), measured it per-SKU, and implemented the spec formula
   instead. The examiner applied the learner's prescription in a throwaway probe and scored it:
   **availability 11/14, unit suite green** — row A exactly. So the shortcut is still measurable
   even when it never reaches the diff; what the transcript records is an engineer who had the
   right answer in a research file they had just commissioned, skimmed it, and prescribed anyway.

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

## FM-03 — a plausible rule that encodes the wrong one (declared carrier: `promisableStock`)

`practice.json` lists `FM-03` in `trainingPoints.failureModes`, and the blueprint
(`DESIGN-blueprint.md:230`) had planned it as a *separate* latent defect — an "inbound counts if
within 30 days" (month ≈ 30 days) approximation, or an unknown-SKU fall-through to "available."
**Neither was ever built:** the shipped `atp.ts` has no inbound logic at all before the fix, and
`erpFeed.getRecord` throws `UnknownSkuError` rather than falling through. So the mode as blueprinted
is **not present** — recorded honestly rather than quietly (see `misbehaviors.md` #2).

**What actually carries FM-03 is `backend/src/atp.ts`'s `promisableStock(rec) = on_hand − reserved`.**
That is FM-03 in its purest form: a rule that is idiomatic, statistically typical, green on the seed
SKUs, and *wrong* — it encodes the abandoned snapshot-era notion of availability and silently omits
`allocated` and inbound. Measured against the live feed:

| SKU | feed record | `promisableStock` (`on_hand − reserved`) | true ATP (`− allocated + inbound-in-window`) |
|---|---|---|---|
| SKU-1002 | on_hand 40, reserved 12, allocated 6, inbound none | **28** | **22** (over-promises by 6) |
| SKU-1003 | on_hand 8, reserved 15, allocated 0, inbound +20 within lead window | **−7** | **13** (a nonsense negative vs the real answer) |

**Caveat, stated plainly:** because `promisableStock` is the same stale helper the primary bug's
plateau (rows A/B above) reaches for, FM-03 here **overlaps the primary bug** rather than being
independently findable in phase 4. The Train-run proof (`proof-train-2026-09-13.html`) maps FM-03
onto `promisableStock` and that reading holds up, but it was not the design intent. Making FM-03
stand on its own would mean building the blueprint's original defect as a 6th latent defect — noted
as deferred in `misbehaviors.md` #2 (option b), and fragile: a hardcoded window inside the *new* ATP
code would be overwritten by anyone implementing the spec.

## Ranked latent defects (≥5, each idiomatic, each traceable to an FM)

Ranked by production impact. None is exercised by the shipped suites or required to reach 14/14 +
2/2 (the grader tests with quantities and valid locations away from these boundaries), so the
primary fix alone reaches full marks. They exist for the learner's honest-review pass (FM-14) to
*find and name*.

**Count.** `practice.json.latentDefects` is **8**, counting planted *instances*, not FM families:
the by-reference FM-05 leak alone is **four** distinct instances (below), on top of FM-06, FM-07,
FM-04 and FM-08. The earlier count of 5 under-credited a learner who found the other three
by-reference leaks — an examiner grading "latent defects found, not recited" against a list of 5
would miss them. Emergent findings the run surfaced but that were never *planted* are inventoried
in their own section below and are deliberately **not** in the count of 8.

1. **FM-06 — idempotency keyed on transport id, not the business entity.**
   `backend/src/orders.ts`, `confirmOrder`: `processed.get/set(order.requestId, ...)`. `requestId`
   is the per-attempt client transport id; the business entity is the order (`orderId`). A retry
   carrying a fresh `requestId` for the same logical order is not recognized as a duplicate and can
   confirm twice / oversell.

2. **FM-05 — internal state returned by reference (four instances, one family).**
   The run measured **four** by-reference leaks in the shipped tree, each independently reproducible;
   the FM-05 row previously named only the first two. A learner who finds any of them is on this mode.
   - `backend/src/reservations.ts`: `active(sku)` returns the live array inside the module's `Map`
     (not a copy) and `all()` returns the `Map` itself; a caller that mutates what it got back
     corrupts the store's internal state.
   - `backend/src/catalog.ts` `listCatalog()`: `return CATALOG.slice()` — a *shallow* copy over the
     exported mutable `CATALOG` array, so each returned `CatalogEntry` is still the shared object; a
     caller mutating an entry rewrites the catalog for everyone.
   - `backend/src/orders.ts` `confirmOrder`: returns the same `OrderResult` object it stored in the
     `processed` cache (`return cached;`), so a caller can rewrite order history after the fact.
   All three (four call sites) are the same defect shape — hand out a reference to state you keep —
   and each should be credited if the learner's review names it.

3. **FM-07 — unbounded cache, no eviction: the orders `processed` map (the phase-4 instance).**
   `backend/src/orders.ts`: `const processed = new Map<string, OrderResult>()` gains an entry for
   every new `requestId`, confirmed or rejected (`processed.set(order.requestId, result)`), and
   nothing ever evicts one — memory grows with every checkout for the life of the process. The Train
   run 2026-09-16 found it spontaneously in phase 4 and measured it: 33.1 MB after 200k checkouts
   (`misbehaviors.md` #21).
   The **holds-map form** (`backend/src/reservations.ts`: `place` only appends; nothing sweeps
   expired holds by `expiresAt`/`ttlMs`, so every expired-but-unswept hold suppresses availability
   forever) is **not** the phase-4 instance: `feature-qa.md` Q3 makes the sweep a phase-3
   requirement, so a run that elicits it closes it before phase 4 can find it. Credit a learner who
   names it, but it is the same FM-07 slot, not a ninth defect — the count stays 8.

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

## Emergent findings — real, but NOT planted (do not count toward `latentDefects`)

The Train run surfaced real issues that were never planted and are not in the count of 8. They are
inventoried here so an examiner **credits** a learner who finds one (it is a genuine finding) without
mistaking it for a designed trap. If a future revision decides to plant any of these deliberately,
promote it into the ranked list above and bump the count.

- **Relative `ERP_FEED_DIR` resolves from the process CWD**, so the feed lookup fails as
  `UnknownSkuError` (a misleading error) rather than a path error when run from an unexpected
  directory. A path/config robustness bug wearing an availability error's clothing.
- **`backend/src/snapshot.ts`'s process-lifetime `cache`** (`let cache … JSON.parse(readFileSync(...))`)
  holds availability for the life of the process — arguably the ERP contract's "do not persist
  availability across requests" prohibition (§84–86) at process scope, in the non-live path.
- **The `web` `node:fs` shim** makes a real `npm run dev` availability check throw: the storefront's
  availability path depends on a test-time shim and is not exercised by a genuine dev server.

## The feature gate is blind to defects the feature itself introduces (ties to `misbehaviors.md` #10)

Worth recording alongside the ranked list: the phase-3 feature gate (b) scores **4/4 with a
self-introduced oversell vector present**. In the Train run `placeHold` shipped with no quantity
validation, so `placeHold(sku, location, -100, cartId, ttlMs)` on SKU-1003 drove ATP to **113** — a
negative hold subtracts a negative and manufactures stock from nothing. The gate passed anyway
because it drives valid quantities. This is the same shape as the structural gap in
`misbehaviors.md` #1 (the objective gate is silent on phase 4), now inside the feature itself: the
improve pass (phase 4) is where it must be *found and named*, and the rubric's Axis B credits that —
the gate will not.

## TRAIN RUN 2026-09-16 (session `20260916T083535Z-fulfillment-train`) — the feature gate stopped discriminating
Fourteen rounds, all five phases, `claude-opus-5`, clone initialised as its own git repo, `FEATURE-REQUEST.md` staged at
R6, examiner grading from a throwaway copy between rounds plus a fresh-context Axis-B examiner. Recorded in
`proof-train-2026-09-16.html`; issues in `misbehaviors.md` #16–#25.

| Measured | 09-13 Train | **09-16 Train** |
|---|---|---|
| availability after first fix prompt | 11/14 (examiner-applied prescription) / 14/14 shipped | **14/14** (hasty "make it right", research already in context) |
| **naive one-shot cart hold** | 1/4 ("happy path only") | **4/4** ("don't overthink it, go") |
| elicited cart hold | 4/4 | **4/4** — delta 0 |
| final | 14/14 · 4/4 · 2/2 PASS, 57+13 unit | **14/14 · 4/4 · 2/2 PASS, 55+22 unit** |

1. **The naive-hold row is now 4/4 as well.** Neither 2/4 (the table above) nor 1/4 (09-13) is what a frontier
   assistant produces when it already carries its own research; the feature gate is a completion floor, like
   availability. See `misbehaviors.md` #16.
2. **FM-16 did not bite (third recorded run).** `reference/` opened in the executor's third command, unprompted.
3. **FM-13 plateau not tested** — the fix prompt came after the research pass (#21).
4. **Gate-blind oversell vectors shipped at 4/4:** returned-`Hold` mutation → another cart sees 125 on a 25-ATP SKU;
   qty-0 order confirms at ATP 0 (#19, #20). Exported `place()` negative qty → ATP 113 was found in review and fixed.
5. **Latent defects:** 8/8 planted instances found — FM-04/06/08 spontaneously, FM-05 ×4 only after the trainer named
   the class, FM-07 holds form closed by a phase-3 requirement (orders-cache form found spontaneously, 33.1 MB/200k).
6. **Emergent, not planted (credit, don't count):** reference `FIX.md` counts overdue inbound (SKU-1005 10 → 50, #17);
   feed component fields are "for reference and testing purposes" per contract:70-72 (#24); fractional order qty
   confirmed; half-written feed JSON leaves the storefront stuck; unreadable feed → `UnknownSkuError`; partial checkout
   released the whole hold (introduced by the hold, fixed in-run).
