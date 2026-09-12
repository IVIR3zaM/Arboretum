// Available-to-promise (ATP) calculation, per reference/atp-spec.md:
//
//   ATP = on_hand - reserved - allocated + eligible_inbound
//
// where eligible_inbound sums inbound.qty for lines arriving within the
// SKU's lead-time window.

import type { FeedRecord } from "./types.ts";

export function computeAtp(rec: FeedRecord): number {
  const eligibleInbound = rec.inbound
    .filter((line) => line.arrivesInDays < rec.leadTimeDays)
    .reduce((sum, line) => sum + line.qty, 0);

  return rec.on_hand - rec.reserved - rec.allocated + eligibleInbound;
}
