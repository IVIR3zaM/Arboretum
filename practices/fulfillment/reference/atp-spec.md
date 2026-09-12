# Available-to-Promise (ATP) — Calculation Spec

**Owner:** Fulfillment Platform team (ERP side)
**Applies to:** the ERP availability service described in `erp-availability-contract.md`

## Why not just use on-hand?

On-hand is the physical unit count sitting in a location right now. It is **not** promisable on
its own, because it says nothing about units that are already spoken for:

- **Reserved** units are held against orders that have been placed but not yet picked/allocated
  for shipment.
- **Allocated** units are already picked, staged, or otherwise committed to an outbound shipment
  and are physically leaving even though they may still be counted as on-hand until the shipment
  event posts.

A location can show a healthy on-hand count while having zero — or negative — capacity to accept
a new promise, because reservations and allocations already exceed on-hand. Promising against raw
on-hand risks overselling. This is why the ERP availability service never returns on-hand to
consumers; it returns ATP.

## The formula

```
ATP = on_hand − reserved − allocated + eligible_inbound
```

Where `eligible_inbound` is the sum of `qty` for every inbound shipment line whose
`arrivesInDays` falls within the SKU's lead-time window:

```
eligible_inbound = sum(
  line.qty
  for line in inbound
  if line.arrivesInDays <= leadTimeDays
)
```

`leadTimeDays` is a per-SKU attribute representing how far out the business is willing to look
when promising against incoming supply — a customer placing an order today should only be
promised inventory that will plausibly be on the shelf in time to fulfill that order within the
SKU's normal fulfillment horizon. Inbound supply arriving **beyond** the lead-time window is real,
but it is not counted toward today's ATP: it is too far out to promise against yet, and will be
picked up in a later ATP calculation once it falls inside the window.

Note the boundary is inclusive: an inbound line with `arrivesInDays` exactly equal to
`leadTimeDays` **is** counted.

## Inputs

| Field | Type | Meaning |
|---|---|---|
| `on_hand` | integer | Physical units currently in the location. |
| `reserved` | integer | Units held against placed-but-not-yet-allocated orders. |
| `allocated` | integer | Units already picked/staged/committed to outbound shipments. |
| `inbound` | array of `{qty, arrivesInDays}` | Expected incoming supply lines, each with a quantity and days-until-arrival. |
| `leadTimeDays` | integer | The SKU's promising horizon, in days. |

## Worked examples

### Example A — no reservations, no inbound

Inputs: `on_hand = 50`, `reserved = 0`, `allocated = 0`, `inbound = []`, `leadTimeDays = 30`.

```
eligible_inbound = 0   (no inbound lines)
ATP = 50 − 0 − 0 + 0 = 50
```

The full on-hand count is promisable because nothing is held against it.

### Example B — reservations and allocations reduce ATP below on-hand

Inputs: `on_hand = 40`, `reserved = 12`, `allocated = 6`, `inbound = []`, `leadTimeDays = 30`.

```
eligible_inbound = 0
ATP = 40 − 12 − 6 + 0 = 22
```

Even with no inbound activity, ATP (22) is well below on-hand (40) — this is the case that makes
on-hand unsafe to promise against directly.

### Example C — inbound within the lead-time window counts

Inputs: `on_hand = 8`, `reserved = 15`, `allocated = 0`,
`inbound = [{qty: 20, arrivesInDays: 7}]`, `leadTimeDays = 30`.

```
7 <= 30, so the inbound line is eligible
eligible_inbound = 20
ATP = 8 − 15 − 0 + 20 = 13
```

On-hand alone (8) is already short of the 15 reserved, but supply arriving in 7 days — well
inside the 30-day lead-time window — brings ATP up to a promisable 13.

### Example D — inbound outside the lead-time window is excluded

Inputs: `on_hand = 30`, `reserved = 25`, `allocated = 0`,
`inbound = [{qty: 50, arrivesInDays: 45}]`, `leadTimeDays = 30`.

```
45 > 30, so the inbound line is NOT eligible
eligible_inbound = 0
ATP = 30 − 25 − 0 + 0 = 5
```

The 50 units arriving in 45 days are real and will eventually count, but they fall outside this
SKU's 30-day promising horizon, so today's ATP is only 5 — not 55.

### Example E — ATP can be zero

Inputs: `on_hand = 10`, `reserved = 10`, `allocated = 0`, `inbound = []`, `leadTimeDays = 30`.

```
eligible_inbound = 0
ATP = 10 − 10 − 0 + 0 = 0
```

Every on-hand unit is already reserved; nothing further can be promised until reservations clear
or new supply arrives inside the window.

## Summary

ATP is the single number that should ever drive a promise decision. It is always computed live,
always keyed to a specific SKU/location, and always nets reservations and allocations out of
on-hand while adding back only the inbound supply that is close enough in time to count.
