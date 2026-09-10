// Cadence math: turn a subscription into its series of delivery dates, and pick
// the next one a customer can still act on.

import type { Cadence, Subscription } from "./types.ts";
import { shiftDate, isBeforeCutoff } from "./cutoff.ts";

function step(date: string, cadence: Cadence): string {
  switch (cadence) {
    case "weekly":
      return shiftDate(date, 7);
    case "biweekly":
      return shiftDate(date, 14);
    case "monthly":
      // Approximate a month as 30 days.
      return shiftDate(date, 30);
  }
}

/** The first `count` delivery dates at or after `from`, walking the cadence from the anchor. */
export function upcomingDeliveries(sub: Subscription, from: string, count: number): string[] {
  let date = sub.anchorDate;
  while (date < from) {
    date = step(date, sub.cadence);
  }
  const out: string[] = [];
  for (let i = 0; i < count; i++) {
    out.push(date);
    date = step(date, sub.cadence);
  }
  return out;
}

/**
 * The next delivery the customer can still change — the earliest upcoming
 * delivery whose cutoff has not yet passed as of `now`.
 */
export function nextDeliveryDate(sub: Subscription, now: Date): string {
  const today = nowToIsoDate(now);
  const candidates = upcomingDeliveries(sub, today, 6);
  for (const date of candidates) {
    if (isBeforeCutoff(now, date, sub)) {
      return date;
    }
  }
  // All cutoffs in the window have passed; fall through to the last candidate.
  return candidates[candidates.length - 1];
}

function nowToIsoDate(now: Date): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}
