import { test } from "node:test";
import assert from "node:assert/strict";
import { place, active, all, placeHold } from "../src/reservations.ts";
import { availableToPromise } from "../src/availability.ts";
import { confirmOrder } from "../src/orders.ts";

// ATP_SOURCE is left unset: the snapshot answers SKU-1001 = 50, SKU-1006 = 25.
// Each test uses its own carts; SKU-1001 carries cart-1's 2-unit hold from the first test.

test("place + active: a placed hold shows up as active for its SKU", () => {
  const hold = {
    sku: "SKU-1001",
    location: "DC-WEST",
    qty: 2,
    cartId: "cart-1",
    createdAt: Date.now(),
    ttlMs: 60_000,
    expiresAt: Date.now() + 60_000,
  };
  place(hold);
  const holds = active("SKU-1001");
  assert.equal(holds.length, 1);
  assert.equal(holds[0].qty, 2);
});

test("active: a SKU with no holds returns an empty list", () => {
  assert.deepEqual(active("SKU-1006"), []);
});

test("all: reflects placed holds", () => {
  const hold = {
    sku: "SKU-1002",
    location: "DC-WEST",
    qty: 1,
    cartId: "cart-2",
    createdAt: Date.now(),
    ttlMs: 60_000,
    expiresAt: Date.now() + 60_000,
  };
  place(hold);
  assert.ok(all().has("SKU-1002"));
});

test("place: refuses a hold that is not a whole number of units", () => {
  const now = Date.now();
  for (const qty of [0, -3, 0.5]) {
    assert.throws(() => place({ sku: "SKU-1002", location: "DC-WEST", qty, cartId: "cart-x", createdAt: now, ttlMs: 1, expiresAt: now + 1 }), RangeError);
  }
});

test("placeHold: reserves for other carts, not for the holding cart", () => {
  placeHold("SKU-1006", "DC-WEST", 10, "cart-3", 60_000);
  assert.equal(availableToPromise("SKU-1006", "DC-WEST", "cart-4"), 15);
  assert.equal(availableToPromise("SKU-1006", "DC-WEST", "cart-3"), 25);
});

test("placeHold: placing again replaces the cart's hold with the new total", () => {
  placeHold("SKU-1006", "DC-WEST", 3, "cart-3", 60_000); // cart-3 had 10
  assert.equal(availableToPromise("SKU-1006", "DC-WEST", "cart-4"), 22);
});

test("placeHold: the last units can be held, one more cannot", () => {
  placeHold("SKU-1006", "DC-WEST", 22, "cart-5", 60_000); // 25 - cart-3's 3
  assert.throws(() => placeHold("SKU-1006", "DC-WEST", 1, "cart-6", 60_000), /cannot hold/);
});

test("placeHold: the returned hold is a copy", () => {
  const hold = placeHold("SKU-1001", "DC-WEST", 5, "cart-7", 60_000);
  hold.qty = 500;
  assert.equal(availableToPromise("SKU-1001", "DC-WEST", "cart-8"), 50 - 2 - 5);
});

test("confirmOrder: a partial checkout keeps the rest of the hold", () => {
  placeHold("SKU-1001", "DC-WEST", 10, "cart-9", 60_000);
  const before = availableToPromise("SKU-1001", "DC-WEST", "cart-8");
  assert.equal(confirmOrder({ orderId: "res-o1", requestId: "res-r1", sku: "SKU-1001", location: "DC-WEST", qty: 4, cartId: "cart-9" }).status, "confirmed");
  assert.equal(availableToPromise("SKU-1001", "DC-WEST", "cart-8"), before + 4);
});

test("placeHold: expired holds stop reserving and are swept store-wide", async () => {
  placeHold("SKU-1001", "DC-WEST", 1, "cart-10", 20);
  await new Promise((resolve) => setTimeout(resolve, 60));
  placeHold("SKU-1006", "DC-WEST", 1, "cart-3", 60_000); // any placeHold sweeps
  const cart10 = [...all().values()].flat().filter((hold) => hold.cartId === "cart-10");
  assert.deepEqual(cart10, []);
});
