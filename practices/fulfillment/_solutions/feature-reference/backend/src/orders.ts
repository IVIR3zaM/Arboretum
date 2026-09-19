// Order confirmation: the root the storefront checkout calls to try to confirm
// a customer's order against current availability.

import { availableToPromise } from "./availability.ts";
import { consume } from "./reservations.ts";
import type { Order, OrderResult } from "./types.ts";

// Keyed on the orderId, the business entity: the mobile client mints a fresh
// requestId on every tap (platform), so a requestId key would confirm a
// double-tapped order twice. A repeat of an order returns its first result.
const processed = new Map<string, OrderResult>();

export function confirmOrder(order: Order): OrderResult {
  const cached = processed.get(order.orderId);
  if (cached) {
    return { ...cached };
  }

  // Re-checked live on every confirm; the cart's own hold is not counted
  // against it. Whole units only, and exactly the last unit is promisable (PM).
  const atp = availableToPromise(order.sku, order.location, order.cartId);
  const accepted = Number.isInteger(order.qty) && order.qty >= 1 && order.qty <= atp;

  const result: OrderResult = {
    orderId: order.orderId,
    status: accepted ? "confirmed" : "rejected",
    sku: order.sku,
    location: order.location,
    qty: order.qty,
  };

  if (accepted && order.cartId) {
    // Only the units bought leave the hold; the rest stay held on their timer.
    consume(order.sku, order.location, order.cartId, order.qty);
  }

  processed.set(order.orderId, result);
  return { ...result };
}
