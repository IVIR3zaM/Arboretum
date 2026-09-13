// Unit suite for the delivery-scheduling service.

import { test } from "node:test";
import assert from "node:assert/strict";

import { shiftDate } from "../src/cutoff.ts";
import { isBeforeCutoff } from "../src/cutoff.ts";
import { upcomingDeliveries, nextDeliveryDate } from "../src/scheduling.ts";
import { Repository } from "../src/repository.ts";
import { DeliveryService } from "../src/service.ts";
import { fixedClock } from "../src/clock.ts";
import {
  DuplicateDeliveryError,
  UnknownSubscriptionError,
  type Subscription,
} from "../src/types.ts";

const sub: Subscription = {
  id: "sub-1",
  customerId: "cust-1",
  timezone: "UTC",
  cadence: "weekly",
  anchorDate: "2026-03-06",
  cutoffHour: 18,
  cutoffDaysBefore: 2,
  active: true,
};

// --- calendar math -----------------------------------------------------------

test("shiftDate adds days within a month", () => {
  assert.equal(shiftDate("2026-03-06", 7), "2026-03-13");
});

test("shiftDate crosses a month boundary", () => {
  assert.equal(shiftDate("2026-03-30", 7), "2026-04-06");
});

test("shiftDate handles negative offsets", () => {
  assert.equal(shiftDate("2026-03-06", -2), "2026-03-04");
});

// --- cadence -----------------------------------------------------------------

test("weekly cadence lists the right dates", () => {
  assert.deepEqual(upcomingDeliveries(sub, "2026-03-06", 3), [
    "2026-03-06",
    "2026-03-13",
    "2026-03-20",
  ]);
});

test("biweekly cadence steps 14 days", () => {
  const s = { ...sub, cadence: "biweekly" as const };
  assert.deepEqual(upcomingDeliveries(s, "2026-03-06", 2), ["2026-03-06", "2026-03-20"]);
});

test("monthly cadence steps ~30 days", () => {
  const s = { ...sub, cadence: "monthly" as const };
  assert.deepEqual(upcomingDeliveries(s, "2026-03-06", 2), ["2026-03-06", "2026-04-05"]);
});

test("upcomingDeliveries skips dates before the window start", () => {
  assert.deepEqual(upcomingDeliveries(sub, "2026-03-15", 2), ["2026-03-20", "2026-03-27"]);
});

// --- cutoff -----------------------------------------------------------------

test("before cutoff when now is several days early", () => {
  // Delivery 2026-03-20, cutoff day 2026-03-18. Three days before: open.
  assert.equal(isBeforeCutoff(new Date("2026-03-15T00:00:00Z"), "2026-03-20", sub), true);
});

test("after cutoff when now is a day past it", () => {
  // Cutoff day 2026-03-18; by noon on the 19th the box is closed.
  assert.equal(isBeforeCutoff(new Date("2026-03-19T12:00:00Z"), "2026-03-20", sub), false);
});

// --- repository --------------------------------------------------------------

test("schedule then find returns the delivery", () => {
  const repo = new Repository();
  repo.addSubscription(sub);
  repo.schedule("sub-1", "2026-03-20");
  assert.equal(repo.find("sub-1", "2026-03-20")?.status, "scheduled");
});

test("scheduling the same date twice throws", () => {
  const repo = new Repository();
  repo.addSubscription(sub);
  repo.schedule("sub-1", "2026-03-20");
  assert.throws(() => repo.schedule("sub-1", "2026-03-20"), DuplicateDeliveryError);
});

test("unknown subscription throws", () => {
  const repo = new Repository();
  assert.throws(() => repo.getSubscription("nope"), UnknownSubscriptionError);
});

test("deliveriesFor returns a customer's deliveries newest-first", () => {
  const repo = new Repository();
  repo.addSubscription(sub);
  repo.schedule("sub-1", "2026-03-13");
  repo.schedule("sub-1", "2026-03-20");
  assert.deepEqual(
    repo.deliveriesFor("cust-1").map((d) => d.date),
    ["2026-03-20", "2026-03-13"],
  );
});

// --- service -----------------------------------------------------------------

test("scheduleUpcoming materializes the next deliveries", () => {
  const svc = new DeliveryService(fixedClock("2026-03-10T09:00:00Z"));
  svc.subscribe(sub);
  const made = svc.scheduleUpcoming("sub-1", 2);
  assert.deepEqual(made.map((d) => d.date), ["2026-03-13", "2026-03-20"]);
});

test("processQueue de-duplicates a repeated event id and ships once", () => {
  const svc = new DeliveryService(fixedClock("2026-03-10T09:00:00Z"));
  svc.subscribe(sub);
  const ev = { eventId: "e1", subscriptionId: "sub-1", date: "2026-03-13" };
  svc.processQueue([ev]);
  const second = svc.processQueue([ev]);
  assert.equal(second.length, 0);
  assert.equal(svc.deliveriesFor("cust-1")[0].status, "delivered");
});
