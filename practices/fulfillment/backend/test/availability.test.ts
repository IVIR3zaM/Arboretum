// ATP_SOURCE is left unset here on purpose: these tests exercise the
// snapshot resolver branch against never-reserved seed SKUs, where the
// snapshot's on-hand figure and true ATP agree.

import { test } from "node:test";
import assert from "node:assert/strict";
import { availableToPromise, checkAvailability } from "../src/availability.ts";

test("availableToPromise: seed SKU-1001 (snapshot)", () => {
  assert.equal(availableToPromise("SKU-1001", "DC-WEST"), 50);
});

test("availableToPromise: seed SKU-1006 (snapshot)", () => {
  assert.equal(availableToPromise("SKU-1006", "DC-WEST"), 25);
});

test("checkAvailability: reports in-stock with the right ATP for SKU-1001", () => {
  const result = checkAvailability("SKU-1001", "DC-WEST");
  assert.deepEqual(result, { sku: "SKU-1001", location: "DC-WEST", atp: 50, inStock: true });
});

test("checkAvailability: reports in-stock with the right ATP for SKU-1006", () => {
  const result = checkAvailability("SKU-1006", "DC-WEST");
  assert.deepEqual(result, { sku: "SKU-1006", location: "DC-WEST", atp: 25, inStock: true });
});
