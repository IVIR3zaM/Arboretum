// HIDDEN acceptance suite (the grader). 13 cases:
//   · 8 timezone-sensitive cutoff cases — the phase-2 bug (7 fixed-offset zones + 1 DST zone
//     that a plausible fixed-offset fix gets wrong);
//   · 5 phase-3 feature cases — the minimal agreed behaviour of `skipNextDelivery` from
//     `feature-qa.md`, including the two shapes the duplicate-delivery invariant punishes.
//
// Each customer lives in a fixed-offset timezone and `now` sits inside the gap
// between the true (timezone-aware) cutoff instant and the instant the code
// computes when it ignores the customer's timezone. Under the planted bug these
// all fail when the host process is not in the customer's zone; the grader runs
// the file under three server timezones so at least one run exposes every case.
//
// Learners do not read this file. The harness runs it via `practice.json` → `commands.grade`.

import { test } from "node:test";
import assert from "node:assert/strict";

import { isBeforeCutoff } from "../src/cutoff.ts";
import { DeliveryService } from "../src/service.ts";
import { fixedClock } from "../src/clock.ts";
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

// DST trap: Berlin in June is CEST (+02), not its standard CET (+01). The cutoff is 18:00 local
// = 16:00Z, so at 16:30Z the box is already locked. A fix that hardcodes a single/standard
// offset (+01 → 17:00Z) answers "still open" here and fails. Only computing the offset PER
// INSTANT (DST-aware) gets it right — the plausible fixed-offset fix cannot pass this case.
test("Berlin (CEST +02, DST): cutoff passed at 16:30 UTC", () => {
  assert.equal(isBeforeCutoff(new Date("2026-06-16T16:30:00Z"), DELIVERY, sub("Europe/Berlin")), false);
});

// ---------------------------------------------------------------------------
// Phase 3 — "skip my next box". The minimal agreed behaviour from feature-qa.md.
//
// These assert BEHAVIOUR ONLY through the public surface: no error class is named, so any
// sensible way of refusing counts. What they do pin is the shape of the trap — the store
// materializes the next delivery lazily and rejects a duplicate, so both of the obvious
// implementations ("mark the next one skipped" / "create the next one and skip it") throw on
// one of the first two cases. They also pin the two answers a learner can only get by asking
// the PM: skip is idempotent, and an already-shipped box is refused.
// ---------------------------------------------------------------------------

const SKIP_ANCHOR = "2026-06-04"; // weekly: 06-04, 06-11, 06-18, 06-25, …
const NEXT_BOX = "2026-06-11";    // its cutoff is 06-09 18:00 Tokyo = 06-09T09:00Z

function skipSub(): Subscription {
  return { ...sub("Asia/Tokyo"), id: "sub-skip", customerId: "cust-skip", anchorDate: SKIP_ANCHOR };
}

/** A service whose "now" is 2026-06-09T00:00Z — before the cutoff of the 06-11 box. */
function serviceBeforeCutoff(): DeliveryService {
  const svc = new DeliveryService(fixedClock("2026-06-09T00:00:00Z"));
  svc.subscribe(skipSub());
  return svc;
}

test("skip materializes the next box when it does not exist yet", () => {
  const svc = serviceBeforeCutoff();
  const skipped = svc.skipNextDelivery("sub-skip");
  assert.equal(skipped.date, NEXT_BOX);
  assert.equal(skipped.status, "skipped");
  assert.equal(svc.deliveriesFor("cust-skip").filter((d) => d.date === NEXT_BOX).length, 1);
});

test("skip works when the next box has already been materialized", () => {
  const svc = serviceBeforeCutoff();
  svc.scheduleUpcoming("sub-skip", 3);
  const skipped = svc.skipNextDelivery("sub-skip");
  assert.equal(skipped.date, NEXT_BOX);
  assert.equal(skipped.status, "skipped");
  assert.equal(svc.deliveriesFor("cust-skip").length, 3); // no duplicate row
});

test("skipping twice is a no-op, not a second skip", () => {
  const svc = serviceBeforeCutoff();
  svc.skipNextDelivery("sub-skip");
  const again = svc.skipNextDelivery("sub-skip");
  assert.equal(again.date, NEXT_BOX);
  assert.equal(again.status, "skipped");
  assert.equal(svc.deliveriesFor("cust-skip").filter((d) => d.status === "skipped").length, 1);
});

test("the skipped box is not shipped and the cadence does not shift", () => {
  const svc = serviceBeforeCutoff();
  svc.skipNextDelivery("sub-skip");
  const shipped = svc.processQueue([{ eventId: "e1", subscriptionId: "sub-skip", date: NEXT_BOX }]);
  assert.deepEqual(shipped, []);
  assert.equal(svc.deliveriesFor("cust-skip").find((d) => d.date === NEXT_BOX)?.status, "skipped");
  svc.scheduleUpcoming("sub-skip", 3);
  assert.deepEqual(
    svc.deliveriesFor("cust-skip").map((d) => d.date).sort(),
    [NEXT_BOX, "2026-06-18", "2026-06-25"],
  );
});

test("a box that has already shipped cannot be skipped", () => {
  const svc = serviceBeforeCutoff();
  svc.scheduleUpcoming("sub-skip", 3);
  svc.processQueue([{ eventId: "e1", subscriptionId: "sub-skip", date: NEXT_BOX }]);
  assert.throws(() => svc.skipNextDelivery("sub-skip"));
  // …and the refusal has to be about *this* box: a method that throws unconditionally
  // (the unimplemented stub included) does not pass this case.
  const open = serviceBeforeCutoff();
  assert.equal(open.skipNextDelivery("sub-skip").status, "skipped");
});
