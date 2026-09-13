import { test } from "node:test";
import assert from "node:assert/strict";
import { promisableStock } from "../src/atp.ts";
import type { FeedRecord } from "../src/types.ts";

function record(overrides: Partial<FeedRecord>): FeedRecord {
  return {
    sku: "SKU-TEST",
    location: "DC-WEST",
    on_hand: 0,
    reserved: 0,
    allocated: 0,
    inbound: [],
    leadTimeDays: 30,
    ...overrides,
  };
}

test("promisableStock: with nothing reserved, it's all on-hand", () => {
  assert.equal(promisableStock(record({ on_hand: 50 })), 50);
});

test("promisableStock: subtracts what's reserved against the SKU", () => {
  assert.equal(promisableStock(record({ on_hand: 40, reserved: 12 })), 28);
});

test("promisableStock: SKU-1006-style seed record", () => {
  assert.equal(promisableStock(record({ sku: "SKU-1006", on_hand: 25 })), 25);
});
