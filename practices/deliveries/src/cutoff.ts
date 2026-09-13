// Cutoff logic.
//
// The cutoff for a delivery is `cutoffHour` local time, `cutoffDaysBefore` days
// before the delivery date, expressed in the subscription's timezone. After
// that instant the box is locked.

import type { Subscription } from "./types.ts";

/** Shift an ISO date string (YYYY-MM-DD) by a whole number of days. Pure calendar math, no timezone. */
export function shiftDate(isoDate: string, days: number): string {
  const [y, m, d] = isoDate.split("-").map(Number);
  // Anchor on UTC noon so daylight-saving transitions can never roll the calendar day.
  const base = Date.UTC(y, m - 1, d, 12, 0, 0);
  const shifted = new Date(base + days * 86_400_000);
  return toIsoDate(shifted);
}

export function toIsoDate(d: Date): string {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/**
 * The instant after which the box for `deliveryDate` is locked.
 *
 * It is `cutoffHour:00` on the cutoff day, interpreted in the subscription's
 * timezone, returned as an absolute instant (a Date).
 */
export function cutoffInstant(deliveryDate: string, sub: Subscription): Date {
  const cutoffDay = shiftDate(deliveryDate, -sub.cutoffDaysBefore);
  const [y, m, d] = cutoffDay.split("-").map(Number);
  // Construct the wall-clock cutoff time and return it as an instant.
  return new Date(y, m - 1, d, sub.cutoffHour, 0, 0, 0);
}

/** True if `now` is still before the cutoff for `deliveryDate` (the box is still open). */
export function isBeforeCutoff(now: Date, deliveryDate: string, sub: Subscription): boolean {
  return now.getTime() < cutoffInstant(deliveryDate, sub).getTime();
}
