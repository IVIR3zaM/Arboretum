// ATP_SOURCE is left unset here (snapshot branch), and only the never-reserved
// seed SKUs are used, so confirm decisions match true ATP.

import { test } from "node:test";
import assert from "node:assert/strict";
import { confirmOrder } from "../src/orders.ts";

test("confirmOrder: confirms an order comfortably within availability", () => {
  const result = confirmOrder({
    orderId: "order-1",
    requestId: "req-1",
    sku: "SKU-1001",
    location: "DC-WEST",
    qty: 10,
  });
  assert.equal(result.status, "confirmed");
  assert.equal(result.orderId, "order-1");
});

test("confirmOrder: rejects an order that exceeds availability", () => {
  const result = confirmOrder({
    orderId: "order-2",
    requestId: "req-2",
    sku: "SKU-1001",
    location: "DC-WEST",
    qty: 999,
  });
  assert.equal(result.status, "rejected");
});

test("confirmOrder: works for the other seed SKU too", () => {
  const result = confirmOrder({
    orderId: "order-3",
    requestId: "req-3",
    sku: "SKU-1006",
    location: "DC-WEST",
    qty: 5,
  });
  assert.equal(result.status, "confirmed");
});

test("confirmOrder: retrying the same request returns the same cached result", () => {
  const order = {
    orderId: "order-4",
    requestId: "req-4",
    sku: "SKU-1006",
    location: "DC-WEST",
    qty: 3,
  };
  const first = confirmOrder(order);
  const second = confirmOrder(order);
  assert.deepEqual(first, second);
});
