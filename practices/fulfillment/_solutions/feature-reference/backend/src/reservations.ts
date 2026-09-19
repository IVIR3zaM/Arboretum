// In-memory hold/reservation store backing the cart-hold feature: a shopper
// adding a SKU to their cart gets a short-lived hold on quantity so it isn't
// sold out from under them while they check out.
//
// One hold per (SKU, location, cart). Holds count against availability for
// every other cart (availability.ts subtracts them) until they expire or are
// drawn down by that cart's confirmed orders (orders.ts). In-process memory
// only: a single server-side instance for v1 (platform), no shared store yet.

import { availableToPromise } from "./availability.ts";
import type { Hold, Location, Sku } from "./types.ts";
import { HoldRefusedError } from "./types.ts";

/** How long a cart hold lasts: 10 minutes. */
export const HOLD_TTL_MS = 10 * 60 * 1000;

const holds = new Map<Sku, Hold[]>();

function assertWholeUnits(qty: number): void {
  if (!Number.isInteger(qty) || qty < 1) {
    throw new RangeError(`quantity must be a whole number of at least 1, got ${qty}`);
  }
}

function isLive(hold: Hold, now: number): boolean {
  return hold.expiresAt > now;
}

// Store-wide, on every placeHold: expired holds must not sit in memory until
// their own SKU happens to be read again. No background timer (engineering).
function sweepExpired(now: number): void {
  for (const [sku, list] of holds) {
    const live = list.filter((hold) => isLive(hold, now));
    if (live.length > 0) {
      holds.set(sku, live);
    } else {
      holds.delete(sku);
    }
  }
}

export function place(hold: Hold): void {
  assertWholeUnits(hold.qty);
  const stored = { ...hold };
  const existing = holds.get(hold.sku);
  if (existing) {
    existing.push(stored);
  } else {
    holds.set(hold.sku, [stored]);
  }
}

/** Unexpired holds on a SKU, as copies. */
export function active(sku: Sku, now: number = Date.now()): Hold[] {
  return (holds.get(sku) ?? []).filter((hold) => isLive(hold, now)).map((hold) => ({ ...hold }));
}

/** Every stored hold, as copies. */
export function all(): Map<Sku, Hold[]> {
  return new Map([...holds].map(([sku, list]) => [sku, list.map((hold) => ({ ...hold }))]));
}

/** Units of a SKU at a location held by active holds, not counting `excludeCartId`'s own. */
export function heldQty(sku: Sku, location: Location, excludeCartId?: string, now: number = Date.now()): number {
  return (holds.get(sku) ?? [])
    .filter((hold) => isLive(hold, now) && hold.location === location && hold.cartId !== excludeCartId)
    .reduce((sum, hold) => sum + hold.qty, 0);
}

/**
 * Draw a cart's hold down by `qty` units it has just bought. The rest stays
 * held on its original timer; buying at least what is held ends the hold.
 */
export function consume(sku: Sku, location: Location, cartId: string, qty: number): void {
  const list = holds.get(sku);
  if (!list) return;
  const remaining = list
    .map((hold) =>
      hold.location === location && hold.cartId === cartId ? { ...hold, qty: hold.qty - qty } : hold,
    )
    .filter((hold) => hold.qty > 0);
  if (remaining.length > 0) {
    holds.set(sku, remaining);
  } else {
    holds.delete(sku);
  }
}

/**
 * Hold `qty` units of a SKU at a location for one cart, for `ttlMs`.
 *
 * `qty` is the cart's line total for this SKU, not an increment: placing again
 * replaces the cart's hold and restarts its timer, so a double-click or a retry
 * never reserves twice (PM). The hold is granted if `qty` fits within what is
 * promisable to this cart right now — exactly the last unit included —
 * otherwise HoldRefusedError. Returns a copy; the stored hold is not handed out.
 */
export function placeHold(
  sku: Sku,
  location: Location,
  qty: number,
  cartId: string,
  ttlMs: number = HOLD_TTL_MS,
): Hold {
  assertWholeUnits(qty);
  if (!cartId) {
    throw new RangeError("a hold needs the shopper's cart id");
  }
  if (!(ttlMs > 0)) {
    throw new RangeError(`hold TTL must be positive, got ${ttlMs}`);
  }
  const now = Date.now();
  sweepExpired(now);

  const available = availableToPromise(sku, location, cartId);
  if (qty > available) {
    throw new HoldRefusedError(sku, location, qty, available);
  }

  const others = (holds.get(sku) ?? []).filter((hold) => !(hold.location === location && hold.cartId === cartId));
  const hold: Hold = { sku, location, qty, cartId, createdAt: now, ttlMs, expiresAt: now + ttlMs };
  holds.set(sku, [...others, hold]);
  return { ...hold };
}
