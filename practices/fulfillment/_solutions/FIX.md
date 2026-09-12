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
(`orders.ts` → `confirmOrder`) go through to answer "how many of this SKU can we promise right
now?" — the resolver root. `rec` is the full `FeedRecord` read from
`reference/infra/erp-availability/<SKU>.json` (via `erpFeed.getRecord`): `on_hand`, `reserved`,
`allocated`, `inbound[]`, `leadTimeDays`. The `live` branch already has everything it needs to
compute true ATP — it just doesn't. It returns the raw `on_hand` field instead, as if on-hand
*were* promisable.

This is the abandoned "availability = the on-hand number we already hold" assumption from an
earlier era of the repo (`stock_count` → nightly `availability_snapshot` → live ATP; see
`context-map.md` and `doc-drift-ledger.md`). The comment above the `return` — "mirrors the
nightly availability_snapshot's on-hand figure" — is not a lie about *what the code does* (it's
an accurate description of the `live` branch's behaviour); it is a stale description of *what
the code should be doing at this point in the migration*, left behind when the live path was
added and never rewired to the real ATP computation.

The correct computation already exists, fully implemented and unit-tested, one file over:
`backend/src/atp.ts`, `computeAtp(rec): number`, which implements
`ATP = on_hand − reserved − allocated + eligible_inbound` per `reference/atp-spec.md`. The stale
resolver path simply never calls it.

## The fix (two lines)

In `backend/src/availability.ts`:

```diff
 import * as erpFeed from "./erpFeed.ts";
 import * as snapshot from "./snapshot.ts";
+import { computeAtp } from "./atp.ts";
 import type { Availability, Location, Sku } from "./types.ts";
 ...
   if (source() === "live") {
     const rec = erpFeed.getRecord(sku, location);
-    // Live ERP availability; mirrors the nightly availability_snapshot's
-    // on-hand figure.
-    return rec.on_hand;
+    return computeAtp(rec);
   }
```

(Removing the stale comment is good hygiene but not required for correctness; the comment itself
is a doc-drift artifact — see `doc-drift-ledger.md`.)

Nothing else needs to change. `checkAvailability` and `confirmOrder` both call
`availableToPromise` and inherit the fix automatically — that's exactly why the bug was planted
at this seam rather than in a caller: fixing the root fixes every consumer at once.

## Why the stale path is correct on local seed and wrong in prod

The unit-suite seed set is `SKU-1001` and `SKU-1006` — both **never-reserved**
(`reserved = 0`, `allocated = 0`, no eligible inbound) in the canonical feed. For those two SKUs,
`computeAtp(rec) === rec.on_hand` by construction: `on_hand − 0 − 0 + 0 = on_hand`. The stale
branch is *correct by accident* for exactly the SKUs the tests touch, and the local
`snapshot.ts` fixture is built the same way (on-hand copied from the feed, reservations
dropped), so `ATP_SOURCE` unset (snapshot, the dev/CI default) agrees with `ATP_SOURCE=live` too
— for the seed set only.

The moment a SKU carries open reservations/allocations or lead-time-eligible inbound —
`SKU-1002` (reserved 12, allocated 6 → true ATP 22 vs on_hand 40), `SKU-1003` (backorder +
inbound-in-window), `SKU-1004` (inbound outside the lead-time window — a red herring: it *looks*
like it should lift ATP but the spec's `<=` boundary excludes it at 45 days vs a 30-day lead
time), `SKU-1005` (on-hand fully consumed by reservations → true ATP exactly 0) — the stale
branch overpromises. Concretely: `SKU-1002` qty 30 against the bug returns `confirmed` (bug reads
on_hand 40 ≥ 30); against the fix it correctly returns `rejected` (true ATP is 22 < 30). None of
this shows up against local seed data or in staging traffic that happens to hit only
never-reserved SKUs — it only bites once a SKU the business has started pre-selling accumulates
reservations, which is exactly the ticket's symptom ("a handful of SKUs we started pre-selling
let customers order more than we can ship").

## Why the "obvious" autopilot fixes plateau (FM-13)

Two shapes of shallow fix are strongly likely from a prompt that doesn't investigate the root:

1. **Symptom-patch the call site.** Add a check in the checkout handler / `POST /orders` HTTP
   layer that re-queries something or clamps the requested quantity, without touching
   `availability.ts`. The hidden grader (`backend-acceptance.test.ts`) calls
   `availableToPromise` / `confirmOrder` **directly at the root**, not through an HTTP handler, so
   a call-site patch that never changes what the root returns leaves the grader red — the root
   still reports `on_hand` as ATP for every consumer, including the grader's direct calls.
2. **Re-import or hard-code the one failing SKU.** A prompt that reproduces only the ticket's
   most obvious repro (say, `SKU-1002`) and is satisfied once *that* SKU passes will often
   special-case it — hard-code its corrected number, or add a lookup table keyed on that one SKU
   id — rather than deriving the general rule. That passes the visible unit suite (which never
   exercised `SKU-1002` under `ATP_SOURCE=live` in the first place) and even passes the grader's
   `SKU-1002` vector, but **plateaus** on the next contended SKU (`SKU-1003`'s backorder+inbound
   case, or `SKU-1005`'s exactly-zero boundary) because the special case doesn't generalize — it
   never implemented the rule, just memorized one answer. The grader's worst-case scoring across
   all contended SKU states (see `rubric.md`) exposes this immediately.

Only implementing the live ATP query itself — calling `computeAtp(rec)` at the resolver root —
converges, because it's the only change that makes the root produce the *correct number* for
every SKU/location pair, not just the one that was reported.

## An aside, deliberately not built: caching / TTL

A natural next question once you understand "availability is a live query, not a cached value"
(`reference/erp-availability-contract.md`) is whether the live ATP query should be cached or
given a short TTL to cut ERP round-trips. **This practice does not build that.** It is named here
only so a strong learner surfaces it explicitly (or an assistant conversation raises it) as a
scoped-out concern — restraint / altitude-match: the fix is "call `computeAtp` at the root," not
"redesign the availability layer's caching strategy." Building a cache here would also reopen a
staleness bug of exactly the kind this fix just closed. See `rubric.md`'s restraint criterion and
`feature-qa.md`'s parallel note on the cart-hold feature.

## Verified numbers

Orchestrator-verified on a throwaway copy (see `BUILD-LEDGER.md` N5 checkpoint):

| | backend acceptance | web integration |
|---|---|---|
| Pre-fix (bug present) | 6/14 | 1/2 |
| Post-fix (`computeAtp` at the root) | 14/14 | 2/2 |

`grade.sh` ANDs both suites and exits 0 only at 14/14 + 2/2 (worst-case across SKU states and
conformance vectors). The grader was not weakened to produce this flip — the shipped tree still
has the bug; the fix was applied, verified, and reverted.
