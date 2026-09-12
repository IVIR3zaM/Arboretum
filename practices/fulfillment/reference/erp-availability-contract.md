# ERP Availability Service — Integration Contract

**Owner:** Fulfillment Platform team (ERP side)
**Consumers:** Storefront order/availability services
**Status:** Stable, v1

## Overview

The ERP availability service is the system of record for whether a given SKU can be promised to
a customer at a given warehouse location. Consumers do not read warehouse stock directly; they
query this service, which computes and returns **available-to-promise (ATP)** for the requested
SKU/location pair in real time.

This is a deliberate design choice: raw on-hand counts are not sufficient to answer "can we
promise this to a customer?" On-hand ignores units already committed to other orders
(reservations), units already picked or staged for outbound shipments (allocations), and inbound
supply that has not yet arrived. ATP nets all of these out. See `atp-spec.md` for the exact
calculation.

## Query model

Availability is obtained via a **live query**, not a cached or batch snapshot. Every query is
keyed on the pair:

- `sku` — the SKU identifier (string, e.g. `SKU-1003`)
- `location` — the fulfillment location code (string)

The service does not support querying by SKU alone; a location must always be supplied, because
the same SKU can have different ATP at different locations (different on-hand, different open
reservations, different inbound schedules).

### Authoritative location set

The ERP recognizes exactly two fulfillment locations:

| Location code | Description |
|---|---|
| `DC-WEST` | West-region distribution center |
| `DC-EAST` | East-region distribution center |

A query for any location code outside this set is **rejected as unknown** — the service returns
an error, it does not silently fall back to a default location or coerce the code to the nearest
match. Callers integrating a new location must have it provisioned on the ERP side first.

## Response shape

A successful query returns a JSON object. The field consumers care about is `atp`:

```json
{
  "sku": "SKU-1003",
  "location": "DC-EAST",
  "atp": 13,
  "asOf": "2026-09-12T14:03:11Z"
}
```

- `sku` (string) — echoes the queried SKU.
- `location` (string) — echoes the queried location.
- `atp` (integer) — the computed available-to-promise quantity at the time of the query. This is
  the only quantity consumers should treat as "how many can I promise right now." It is **not**
  on-hand.
- `asOf` (string, ISO-8601 timestamp) — when the ERP computed this figure. Because ATP is
  computed live at query time, this will typically be the current time; it is provided for
  logging/audit purposes, not for staleness checks by the caller (the service does not serve
  cached results).

There is no separate `on_hand` field in the response. If a consumer needs to reason about the
underlying inventory mechanics (reservations, allocations, inbound), see `atp-spec.md`, which
describes the components the ERP nets together to arrive at `atp`. The hosted feed backing this
service (`infra/erp-availability/<SKU>.json`) exposes those component fields for reference and
testing purposes, but the live query response only ever surfaces `atp`.

## Error responses

| Condition | Behavior |
|---|---|
| Unknown SKU | 404, `{"error": "unknown_sku"}` |
| Unknown location (not `DC-WEST` or `DC-EAST`) | 422, `{"error": "unknown_location"}` |
| Missing `sku` or `location` | 400, `{"error": "missing_parameter"}` |

## Integration notes for consumers

- Treat every availability check as a fresh, live query. Do not persist `atp` values across
  requests as if they were durable facts about inventory — the same SKU/location pair can return
  a different `atp` moments later as reservations, allocations, and inbound shipments change.
- Always query with the location the order will actually ship from. A SKU that is unpromisable at
  `DC-WEST` may still be promisable at `DC-EAST`, and vice versa.
- Do not attempt to derive ATP from any other feed or cache your storefront maintains separately.
  This service is the single source of truth for promise decisions.
