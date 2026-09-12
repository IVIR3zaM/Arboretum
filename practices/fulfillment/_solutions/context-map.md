# context-map — the golden cross-boundary contract

> Spoiler / answer key. Examiner-only; stripped from the learner clone. This is what
> `research-notes.md` (written by the learner inside `work/`, per AGENTS.md rule 8) should
> converge on distilling from `reference/` — the examiner's copy of the ground truth to grade
> that research pass against.

## The one load-bearing fact

**On-hand ≠ promisable.** The physical unit count sitting in a warehouse right now says nothing
about units already spoken for (reservations, allocations) or supply not yet arrived (inbound).
Every other fact below exists to make this operational. A fix, a feature, or a piece of review
that treats `on_hand` as the number safe to sell is wrong regardless of how it's arrived at.

## Current method: live ATP, not a snapshot

The system of record for "can we promise this SKU to a customer" is a **live query** against the
ERP availability service (`reference/erp-availability-contract.md`), not a cached or batch
snapshot. This is a deliberate design choice on the ERP side, not an implementation detail the
storefront/backend happened to pick: "the same SKU/location pair can return a different `atp`
moments later as reservations, allocations, and inbound shipments change," and consumers are
told not to persist `atp` as a durable fact or derive it from any other feed/cache.

The repo's own history moved through three stages — `stock_count` (a mutable local counter) →
`availability_snapshot` (a nightly point-in-time import) → **live ATP** (the current, correct
method) — and the primary bug is exactly one stale code path that never made the final hop (see
`doc-drift-ledger.md`). The local `snapshot.ts` fixture that still exists in the backend is
legitimate **only** as a dev/CI convenience (`ATP_SOURCE` unset/anything-but-`live`) — it is not
a second source of truth, and nothing should be built that treats it as one.

## Availability is keyed on (SKU, location)

Every query — live or snapshot — is keyed on the pair `(sku, location)`, never SKU alone: "the
same SKU can have different ATP at different locations." The authoritative location set is
exactly `{DC-WEST, DC-EAST}` (`reference/erp-availability-contract.md`); a query for anything
else is supposed to be rejected as unknown, not silently defaulted or coerced (see
`trap-manifest.md`'s FM-08 entry for where the local code doesn't yet enforce this).

## Where reservations / allocations / inbound truth lives

The **only** place the reserved/allocated/inbound components of ATP exist is the hosted ERP feed
— locally mirrored, for this practice, as static JSON at
`reference/infra/erp-availability/<SKU>.json`, one record per SKU (`on_hand`, `reserved`,
`allocated`, `inbound[] {qty, arrivesInDays}`, `location`, `leadTimeDays`). The live ATP response
itself never surfaces these components — "there is no separate `on_hand` field in the response"
— they are exposed only via the hosted feed, "for reference and testing purposes." Nothing in the
local repo (backend or web) independently derives or caches these numbers; the ERP is the single
source of truth for them, and the formula that turns them into `atp` is
`reference/atp-spec.md`'s:

```
ATP = on_hand − reserved − allocated + eligible_inbound
eligible_inbound = sum(line.qty for line in inbound if line.arrivesInDays <= leadTimeDays)
```

(inclusive boundary — see `trap-manifest.md`'s FM-03 entry for where the shipped `computeAtp`
implements this one comparison strictly instead, currently harmless for every shipped SKU).

## What a research pass should come away with

A `research-notes.md` that reconciles the local repo against this map should state, in the
learner's own words, at minimum:
- availability is a live query, not a cache, keyed on `(sku, location)`;
- on-hand alone is not promisable — ATP nets out reserved + allocated and adds back only
  in-window inbound;
- the reserved/allocated/inbound truth lives only in `reference/`, never locally derived;
- the authoritative location set is `{DC-WEST, DC-EAST}`;
- which local code path currently honors this (`atp.ts`'s `computeAtp`) and which one doesn't
  (`availability.ts`'s stale `live` branch) — i.e., the research pass should connect the external
  contract back to the specific place in the local repo it's being violated, not stop at
  restating the contract in isolation.
