// In-memory hold/reservation store backing the cart-hold feature: a shopper
// adding a SKU to their cart gets a short-lived hold on quantity so it isn't
// sold out from under them while they check out.
//
// The cart-hold feature itself is not implemented yet (see placeHold below);
// this module just provides the store it will sit on top of.

import type { Hold, Sku } from "./types.ts";

const holds = new Map<Sku, Hold[]>();

export function place(hold: Hold): void {
  const existing = holds.get(hold.sku);
  if (existing) {
    existing.push(hold);
  } else {
    holds.set(hold.sku, [hold]);
  }
}

export function active(sku: Sku): Hold[] {
  return holds.get(sku) ?? [];
}

export function all(): Map<Sku, Hold[]> {
  return holds;
}

/**
 * Reserve quantity against a SKU for the duration of a cart session.
 * Not implemented yet — the storefront cart-hold flow is still on the
 * roadmap; availability and order confirmation do not depend on it.
 */
export function placeHold(_sku: Sku, _qty: number, _ttlMs: number): Hold {
  throw new Error("not implemented: cart holds are not yet wired up");
}
