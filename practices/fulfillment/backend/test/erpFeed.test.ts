import { test } from "node:test";
import assert from "node:assert/strict";
import { getRecord } from "../src/erpFeed.ts";
import { computeAtp } from "../src/atp.ts";
import { UnknownSkuError } from "../src/types.ts";

test("getRecord: reads a simple SKU's raw feed fields", () => {
  const rec = getRecord("SKU-1001", "DC-WEST");
  assert.equal(rec.sku, "SKU-1001");
  assert.equal(rec.on_hand, 50);
  assert.equal(rec.reserved, 0);
  assert.equal(rec.allocated, 0);
  assert.deepEqual(rec.inbound, []);
});

test("getRecord: reads a contended SKU's raw feed fields", () => {
  const rec = getRecord("SKU-1003", "DC-EAST");
  assert.equal(rec.on_hand, 8);
  assert.equal(rec.reserved, 15);
  assert.equal(rec.inbound.length, 1);
});

test("getRecord + computeAtp together reproduce the ATP spec's worked example", () => {
  const rec = getRecord("SKU-1003", "DC-EAST");
  assert.equal(computeAtp(rec), 13);
});

test("getRecord: unknown SKU raises UnknownSkuError", () => {
  assert.throws(() => getRecord("SKU-9999", "DC-WEST"), UnknownSkuError);
});
