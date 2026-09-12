import { test } from "node:test";
import assert from "node:assert/strict";
import { computeAtp } from "../src/atp.ts";
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

test("computeAtp: no reservations, no inbound", () => {
  const atp = computeAtp(record({ on_hand: 50 }));
  assert.equal(atp, 50);
});

test("computeAtp: reservations and allocations reduce ATP below on-hand", () => {
  const atp = computeAtp(record({ on_hand: 40, reserved: 12, allocated: 6 }));
  assert.equal(atp, 22);
});

test("computeAtp: inbound within the lead-time window counts", () => {
  const atp = computeAtp(
    record({ on_hand: 8, reserved: 15, inbound: [{ qty: 20, arrivesInDays: 7 }] }),
  );
  assert.equal(atp, 13);
});

test("computeAtp: inbound outside the lead-time window is excluded", () => {
  const atp = computeAtp(
    record({ on_hand: 30, reserved: 25, inbound: [{ qty: 50, arrivesInDays: 45 }] }),
  );
  assert.equal(atp, 5);
});

test("computeAtp: ATP can be zero", () => {
  const atp = computeAtp(record({ on_hand: 10, reserved: 10 }));
  assert.equal(atp, 0);
});

test("computeAtp: on the shipped SKU-1003 feed record", () => {
  const atp = computeAtp(
    record({
      sku: "SKU-1003",
      location: "DC-EAST",
      on_hand: 8,
      reserved: 15,
      inbound: [{ qty: 20, arrivesInDays: 7 }],
    }),
  );
  assert.equal(atp, 13);
});
