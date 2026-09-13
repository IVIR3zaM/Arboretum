import { test } from "node:test";
import assert from "node:assert/strict";
import { place, active, all, placeHold } from "../src/reservations.ts";

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

test("placeHold: not implemented yet", () => {
  assert.throws(() => placeHold("SKU-1001", "DC-WEST", 1, "cart-3", 60_000), /not implemented/);
});
