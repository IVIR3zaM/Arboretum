import { test } from "node:test";
import assert from "node:assert/strict";
import { onHand } from "../src/snapshot.ts";
import { UnknownSkuError } from "../src/types.ts";

test("onHand: returns the snapshot's on-hand figure for a known SKU", () => {
  assert.equal(onHand("SKU-1001"), 50);
  assert.equal(onHand("SKU-1006"), 25);
});

test("onHand: unknown SKU raises UnknownSkuError", () => {
  assert.throws(() => onHand("SKU-9999"), UnknownSkuError);
});
