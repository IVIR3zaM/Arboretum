import { test } from "node:test";
import assert from "node:assert/strict";
import { listCatalog } from "../src/catalog.ts";

test("listCatalog: lists all six SKUs", () => {
  const catalog = listCatalog();
  assert.equal(catalog.length, 6);
  assert.ok(catalog.some((entry) => entry.sku === "SKU-1001"));
  assert.ok(catalog.some((entry) => entry.sku === "SKU-1006"));
});

test("listCatalog: each entry has a location from the authoritative set", () => {
  const catalog = listCatalog();
  for (const entry of catalog) {
    assert.ok(entry.location === "DC-WEST" || entry.location === "DC-EAST");
  }
});
