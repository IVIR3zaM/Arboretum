// The single seam both browse (GET /availability) and confirm (POST /orders)
// go through to answer "how many of this SKU can we promise right now?".
//
// ATP_SOURCE selects where that answer comes from:
//   - "live"      -> query the ERP feed directly (erpFeed.ts)
//   - unset/other -> fall back to the local availability snapshot
//                    (fixtures/availability-snapshot.json), a stale
//                    point-in-time import used for local/offline dev.
//
// Active cart holds (reservations.ts) are subtracted from that figure for
// every cart except the one asking. Per the ERP lead: the ERP number is
// queried fresh on every call and never stored; holds only ever subtract from
// it, so we are never less conservative than the ERP's own promise.
// reservations.ts imports this module back for placeHold; the cycle is safe
// because neither module uses the other at load time.

import * as erpFeed from "./erpFeed.ts";
import { heldQty } from "./reservations.ts";
import * as snapshot from "./snapshot.ts";
import type { Availability, Location, Sku } from "./types.ts";

function source(): "live" | "snapshot" {
  return process.env.ATP_SOURCE === "live" ? "live" : "snapshot";
}

function sourceAtp(sku: Sku, location: Location): number {
  if (source() === "live") {
    const rec = erpFeed.getRecord(sku, location);
    // Live ERP availability per reference/atp-spec.md: ATP is on-hand net of
    // reservations and allocations, plus inbound arriving within the lead-time window.
    const eligibleInbound = rec.inbound
      .filter((line) => line.arrivesInDays <= rec.leadTimeDays)
      .reduce((sum, line) => sum + line.qty, 0);
    return rec.on_hand - rec.reserved - rec.allocated + eligibleInbound;
  }
  return snapshot.onHand(sku);
}

/** What can be promised to `cartId` (or to a shopper with no cart): ATP less everyone else's active holds. */
export function availableToPromise(sku: Sku, location: Location, cartId?: string): number {
  return sourceAtp(sku, location) - heldQty(sku, location, cartId);
}

export function checkAvailability(sku: Sku, location: Location, cartId?: string): Availability {
  const atp = availableToPromise(sku, location, cartId);
  return { sku, location, atp, inStock: atp > 0 };
}
