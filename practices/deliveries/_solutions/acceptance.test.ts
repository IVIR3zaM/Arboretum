// HIDDEN acceptance suite (the grader). 7 timezone-sensitive cutoff cases.
//
// Each customer lives in a fixed-offset timezone and `now` sits inside the gap
// between the true (timezone-aware) cutoff instant and the instant the code
// computes when it ignores the customer's timezone. Under the planted bug these
// all fail when the host process is not in the customer's zone; the grader runs
// the file under three server timezones so at least one run exposes every case.
//
// Learners do not read this file. Run it via `npm run grade`.

import { test } from "node:test";
import assert from "node:assert/strict";

import { isBeforeCutoff } from "../src/cutoff.ts";
import type { Subscription } from "../src/types.ts";

const DELIVERY = "2026-06-18"; // cutoff day is 2026-06-16 (cutoffDaysBefore = 2)

function sub(timezone: string): Subscription {
  return {
    id: "s",
    customerId: "c",
    timezone,
    cadence: "weekly",
    anchorDate: "2026-06-04",
    cutoffHour: 18,
    cutoffDaysBefore: 2,
    active: true,
  };
}

// now is AFTER the true cutoff (box locked) — positive-offset zones.
test("Tokyo (+09): cutoff passed by noon UTC", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T12:00:00Z"), DELIVERY, sub("Asia/Tokyo")), false);
});

test("Kolkata (+05:30): cutoff passed", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T15:00:00Z"), DELIVERY, sub("Asia/Kolkata")), false);
});

test("Brisbane (+10): cutoff passed", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T11:00:00Z"), DELIVERY, sub("Australia/Brisbane")), false);
});

test("Dubai (+04): cutoff passed", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T16:00:00Z"), DELIVERY, sub("Asia/Dubai")), false);
});

test("Singapore (+08): cutoff passed", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T13:00:00Z"), DELIVERY, sub("Asia/Singapore")), false);
});

// now is BEFORE the true cutoff (box still open) — negative-offset zones.
test("Honolulu (-10): box still open at 22:00 UTC", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T22:00:00Z"), DELIVERY, sub("Pacific/Honolulu")), true);
});

test("Phoenix (-07): box still open at 22:00 UTC", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T22:00:00Z"), DELIVERY, sub("America/Phoenix")), true);
});
