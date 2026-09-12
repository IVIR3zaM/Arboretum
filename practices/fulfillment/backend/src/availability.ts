// The single seam both browse (GET /availability) and confirm (POST /orders)
// go through to answer "how many of this SKU can we promise right now?".
//
// ATP_SOURCE selects where that answer comes from:
//   - "live"      -> query the ERP feed directly (erpFeed.ts)
//   - unset/other -> fall back to the local availability snapshot
//                    (fixtures/availability-snapshot.json), a stale
//                    point-in-time import used for local/offline dev.

import * as erpFeed from "./erpFeed.ts";
import * as snapshot from "./snapshot.ts";
import type { Availability, Location, Sku } from "./types.ts";

function source(): "live" | "snapshot" {
  return process.env.ATP_SOURCE === "live" ? "live" : "snapshot";
}

export function availableToPromise(sku: Sku, location: Location): number {
  if (source() === "live") {
    const rec = erpFeed.getRecord(sku, location);
    // Live ERP availability; mirrors the nightly availability_snapshot's
    // on-hand figure.
    return rec.on_hand;
  }
  return snapshot.onHand(sku);
}

export function checkAvailability(sku: Sku, location: Location): Availability {
  const atp = availableToPromise(sku, location);
  return { sku, location, atp, inStock: atp > 0 };
}
