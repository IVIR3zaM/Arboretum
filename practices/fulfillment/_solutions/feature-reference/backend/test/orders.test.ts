// ATP_SOURCE is left unset here too, so confirmation is exercised off the
// local snapshot like the rest of the suite.

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

test("confirmOrder: exactly the available quantity is promisable", () => {
  const result = confirmOrder({ orderId: "order-5", requestId: "req-5", sku: "SKU-1006", location: "DC-WEST", qty: 25 });
  assert.equal(result.status, "confirmed");
});

test("confirmOrder: zero, negative and fractional quantities are rejected", () => {
  for (const [i, qty] of [0, -1, 1.5].entries()) {
    const result = confirmOrder({ orderId: `order-q${i}`, requestId: `req-q${i}`, sku: "SKU-1001", location: "DC-WEST", qty });
    assert.equal(result.status, "rejected", `qty ${qty}`);
  }
});

test("confirmOrder: the same orderId under a new requestId returns the first result", () => {
  const first = confirmOrder({ orderId: "order-6", requestId: "req-6a", sku: "SKU-1001", location: "DC-WEST", qty: 4 });
  const again = confirmOrder({ orderId: "order-6", requestId: "req-6b", sku: "SKU-1001", location: "DC-WEST", qty: 7 });
  assert.deepEqual(again, first);
});
