# FIX — reference fix for the primary bug

> Spoiler. Examiner-only; stripped from the learner clone.

## Where the bug lives

`backend/src/availability.ts`, `availableToPromise(sku, location)`, the `live` branch:

```ts
export function availableToPromise(sku: Sku, location: Location): number {
  if (source() === "live") {
    const rec = erpFeed.getRecord(sku, location);
    // Live ERP availability; mirrors the nightly availability_snapshot's
    // on-hand figure.
    return rec.on_hand;
  }
  return snapshot.onHand(sku);
}
```

This is the single seam both `GET /availability` (`checkAvailability`) and `POST /orders`
(`orders.ts` → `confirmOrder`) go through — the resolver root. `rec` is the full `FeedRecord` read
from `reference/infra/erp-availability/<SKU>.json` (`on_hand`, `reserved`, `allocated`,
`inbound[]`, `leadTimeDays`). The `live` branch returns the raw `on_hand` field as if on-hand
*were* promisable — the abandoned "availability = the on-hand number we already hold" assumption
from an earlier era (`stock_count` → nightly `availability_snapshot` → live ATP; see
`context-map.md` and `doc-drift-ledger.md`).

## The correct rule lives only in `reference/` — this is the load-bearing point (FM-16)

There is **no correct ATP function in the local repo.** The only availability helper the codebase
carries is `backend/src/atp.ts`:

```ts
// Availability has always been "the on-hand we're holding, minus what's
// already reserved against it" ...
export function promisableStock(rec: FeedRecord): number {
  return rec.on_hand - rec.reserved;
}
```

`promisableStock` is **stale and incomplete** — a snapshot-era notion that subtracts reservations
but knows nothing about `allocated` units or lead-time-eligible `inbound`. It is *plausible* (it
does subtract demand) and its unit tests are green (they only assert never-reserved seed values and
its documented `on_hand − reserved` behaviour), which is exactly why trusting it is a trap.

The authoritative rule exists **only** in `reference/atp-spec.md`:

```
ATP = on_hand − reserved − allocated + Σ(inbound.qty where arrivesInDays ≤ leadTimeDays)
```

You cannot derive the `allocated` term or the inbound lead-time window from anything in the local
repo — you have to read the spec (the research pass). The feed records *carry* `allocated` and
`inbound` fields, but nothing local tells you they belong in the availability calculation.

## The fix

In `backend/src/availability.ts`, replace the stale `on_hand` return with the ATP computation from
the spec (a handful of lines — still "small in the fix"):

```diff
   if (source() === "live") {
     const rec = erpFeed.getRecord(sku, location);
-    // Live ERP availability; mirrors the nightly availability_snapshot's
-    // on-hand figure.
-    return rec.on_hand;
+    // Live ERP availability per reference/atp-spec.md: ATP is on-hand net of
+    // reservations and allocations, plus inbound arriving within the lead-time window.
+    const eligibleInbound = rec.inbound
+      .filter((line) => line.arrivesInDays <= rec.leadTimeDays)
+      .reduce((sum, line) => sum + line.qty, 0);
+    return rec.on_hand - rec.reserved - rec.allocated + eligibleInbound;
   }
```

(Equivalently, correct `promisableStock` into a full `computeAtp` and call it — the point is the
*rule*, not where it lives. `checkAvailability` and `confirmOrder` both call `availableToPromise`
and inherit the fix, which is why the bug was planted at this seam.)

**Known limitation — overdue inbound.** The filter bounds `arrivesInDays` from above only, so an
inbound line that is already late (negative `arrivesInDays`) still counts toward ATP.
`reference/atp-spec.md` is silent on overdue lines and no vendored feed record has one, so the grader
neither requires nor rejects it; this fix follows the spec as written and is left unchanged. The Train
run 2026-09-16 measured it: `SKU-1005` with a 50-unit line 20 days overdue reads 50, not 0. A learner
who finds it should take the question to the ERP owner — see `trap-manifest.md`, "Emergent findings".

## Why the stale path is correct on local seed and wrong in prod

The unit-suite seed set is `SKU-1001` and `SKU-1006` — both **never-reserved** in the canonical
feed, so on-hand, `promisableStock`, and true ATP all coincide, and the local `snapshot.ts`
fixture (on-hand copied from the feed, reservations dropped) agrees too. The stale branch is
*correct by accident* for exactly the SKUs the tests touch. It only breaks once a SKU carries
reservations/allocations or lead-time inbound — the SKUs the business started pre-selling — which
is the ticket's symptom.

## Why the realistic "fix it" attempts plateau (FM-13 × FM-16) — measured

These are genuine `bash _solutions/grade.sh` outcomes, each applied at the resolver root then reverted. The
trap is not a strawman symptom-patch; it is what a competent engineer who **delegates the fix
without doing the research pass** actually produces:

| Attempt (what an autopilot naturally writes) | backend | web | result |
|---|---|---|---|
| Baseline — reads `on_hand` | 6/14 | 1/2 | RED |
| **A**: subtract what's reserved (the obvious local notion / `promisableStock`) | **11/14** | 2/2 | RED |
| **B**: also subtract `allocated` (a better guess, still no spec) | **12/14** | 2/2 | RED |
| **Correct**: full formula incl. inbound-within-lead-time (from `reference/atp-spec.md`) | **14/14** | 2/2 | GREEN |

Each honest guess climbs but **plateaus**: A misses `allocated` (fails `SKU-1002`) *and* inbound
(fails `SKU-1003`); B closes the allocation gap but still fails the backorder+inbound SKU
(`SKU-1003`, true ATP 13 — its 20 units of inbound arrive in 7 days, inside the 30-day lead window,
so they count). The only way to close the last two points is to **read `reference/atp-spec.md`**
and learn the two terms the local code never had. A symptom-patch in the checkout handler is worse
still: the grader calls the root directly, so it stays at 6/14.

## An aside, deliberately not built: caching / TTL

Once you understand "availability is a live query, not a cached value"
(`reference/erp-availability-contract.md`), a natural question is whether to cache the live ATP
query. **This practice does not build that** — it's named only so a strong learner surfaces it as a
scoped-out concern (restraint / altitude-match). Building a cache here would reopen a staleness bug
of exactly the kind this fix closes.

## Verified numbers

Verified on a throwaway copy (edits reverted; the shipped tree keeps the bug):

| | backend acceptance | web integration |
|---|---|---|
| Pre-fix (bug present) | 6/14 | 1/2 |
| Naive `on_hand − reserved` | 11/14 | 2/2 |
| Naive `− reserved − allocated` | 12/14 | 2/2 |
| Correct (full ATP from the spec) | 14/14 | 2/2 |

`_solutions/grade.sh` ANDs both suites and exits 0 only at 14/14 + 2/2. The grader was not weakened; the fix
was applied, verified, and reverted.
