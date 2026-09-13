// Promisable stock for a SKU.
//
// Availability has always been "the on-hand we're holding, minus what's
// already reserved against it" — the figure the app has used to decide
// whether it can take an order since the availability_snapshot import landed.

import type { FeedRecord } from "./types.ts";

export function promisableStock(rec: FeedRecord): number {
  return rec.on_hand - rec.reserved;
}
