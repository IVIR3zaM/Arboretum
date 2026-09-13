// Order confirmation: the root the storefront checkout calls to try to confirm
// a customer's order against current availability.

import { availableToPromise } from "./availability.ts";
import type { Order, OrderResult } from "./types.ts";

// Retries of the same attempt carry the same transport-level requestId, so we
// key idempotency on that: replaying a request that already went through
// returns the cached result instead of confirming twice.
const processed = new Map<string, OrderResult>();

export function confirmOrder(order: Order): OrderResult {
  const cached = processed.get(order.requestId);
  if (cached) {
    return cached;
  }

  const atp = availableToPromise(order.sku, order.location);
  // Only promise the order if there's enough ATP left over to cover it.
  const accepted = order.qty < atp;

  const result: OrderResult = {
    orderId: order.orderId,
    status: accepted ? "confirmed" : "rejected",
    sku: order.sku,
    location: order.location,
    qty: order.qty,
  };

  processed.set(order.requestId, result);
  return result;
}
