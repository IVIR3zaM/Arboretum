// EXAMINER-ONLY robustness probes (non-blocking). Stripped from the learner
// clone with the rest of _solutions/. NOT wired into grade.sh: the 20-point
// gate and its exit code are unchanged by this file. The examiner runs
//
//   node --test --test-reporter=tap _solutions/robustness-probes.test.ts
//
// from the practice root of the graded copy and reports "robustness n/5"
// (n = `# pass`) next to the gate result (rubric.md, Axis A item 5).
//
// Each probe targets an oversell vector the feature gate is blind to — a run
// can ship every one of them at feature 4/4 (misbehaviors.md #16, #19, #20):
//   1. mutating the Hold object placeHold returns changes another cart's availability;
//   2. the exported store's place() accepts qty <= 0 and so manufactures stock;
//   3. an order for 0 units confirms on a SKU with nothing to promise;
//   4. a partial checkout releases the whole hold instead of the ordered units;
//   5. a second confirm for the same orderId under a new requestId confirms again.
//
// Drives only what the shipped reservations/orders modules already export
// (placeHold, the store's place, confirmOrder), against the live ERP feed, and
// reads availability the way the feature gate does: by whether another cart's
// order is confirmed. Every probe uses its own SKU and its own cart / order /
// request ids, so module-level state (the holds store, the processed map)
// never leaks between probes and any probe run alone (--test-name-pattern)
// gives the same result as the full file. Modules are imported inside each
// test, so a tree without a working hold (the shipped stub) fails each probe
// cleanly instead of crashing the file.
//
// Live ATP from reference/infra/erp-availability/: SKU-1001 50 (DC-WEST),
// SKU-1003 13 (DC-EAST), SKU-1004 5 (DC-EAST), SKU-1005 0 (DC-WEST),
// SKU-1006 25 (DC-WEST).

import { fileURLToPath } from "node:url";
import { test } from "node:test";
import assert from "node:assert/strict";

process.env.ATP_SOURCE = "live";
process.env.ERP_FEED_DIR = fileURLToPath(
  new URL("../reference/infra/erp-availability/", import.meta.url),
);

const TTL = 600_000;

async function load() {
  try {
    const reservations = await import("../backend/src/reservations.ts");
    const orders = await import("../backend/src/orders.ts");
    return { ...reservations, ...orders };
  } catch (err) {
    assert.fail(`backend modules failed to load: ${(err as Error).message}`);
  }
}

function attempt<T>(label: string, fn: () => T): T {
  try {
    return fn();
  } catch (err) {
    assert.fail(`${label} threw: ${(err as Error).message}`);
  }
}

// A rejection may be a "rejected" status or a thrown error; both refuse the order.
function refused(fn: () => { status: string }): boolean {
  try {
    return fn().status !== "confirmed";
  } catch {
    return true;
  }
}

test("robustness 1: mutating the Hold returned by placeHold does not change another cart's availability", async () => {
  const m = await load();
  const hold = attempt("placeHold", () => m.placeHold("SKU-1006", "DC-WEST", 4, "rp1-cart-A", TTL));
  const order = (orderId: string, requestId: string) => () =>
    m.confirmOrder({ orderId, requestId, sku: "SKU-1006", location: "DC-WEST", qty: 22, cartId: "rp1-cart-B" });
  assert.ok(refused(order("rp1-o1", "rp1-r1")), "precondition: A's hold of 4 leaves 21 of 25, so B's 22 must be refused");
  try {
    (hold as { qty: number }).qty = -100; // a copy or a frozen object both defeat this
  } catch {
    // frozen: the store is protected
  }
  assert.ok(refused(order("rp1-o2", "rp1-r2")), "B confirmed 22 after the caller mutated A's returned hold: the store was handed out by reference");
});

test("robustness 2: exported place() with qty <= 0 throws or does not raise availability", async () => {
  const m = await load();
  attempt("placeHold", () => m.placeHold("SKU-1003", "DC-EAST", 3, "rp2-cart-A", TTL));
  const order = (orderId: string, requestId: string) => () =>
    m.confirmOrder({ orderId, requestId, sku: "SKU-1003", location: "DC-EAST", qty: 11, cartId: "rp2-cart-B" });
  assert.ok(refused(order("rp2-o1", "rp2-r1")), "precondition: A's hold of 3 leaves 10 of 13, so B's 11 must be refused");
  for (const qty of [0, -100]) {
    const now = Date.now();
    try {
      m.place({ sku: "SKU-1003", location: "DC-EAST", qty, cartId: `rp2-cart-q${qty}`, createdAt: now, ttlMs: TTL, expiresAt: now + TTL });
    } catch {
      continue; // refused at the store: the invariant holds
    }
    assert.ok(refused(order(`rp2-o-q${qty}`, `rp2-r-q${qty}`)), `B confirmed 11 after place() accepted a hold of qty ${qty}: the store manufactured stock`);
  }
});

test("robustness 3: confirmOrder for 0 units on a zero-ATP SKU is rejected", async () => {
  const m = await load();
  assert.ok(
    refused(() => m.confirmOrder({ orderId: "rp3-o1", requestId: "rp3-r1", sku: "SKU-1005", location: "DC-WEST", qty: 0 })),
    "an order for 0 units confirmed on SKU-1005 (ATP 0)",
  );
});

test("robustness 4: a partial checkout releases only the ordered units", async () => {
  const m = await load();
  attempt("placeHold", () => m.placeHold("SKU-1004", "DC-EAST", 2, "rp4-cart-A", TTL));
  const partial = attempt("confirmOrder", () =>
    m.confirmOrder({ orderId: "rp4-o1", requestId: "rp4-r1", sku: "SKU-1004", location: "DC-EAST", qty: 1, cartId: "rp4-cart-A" }));
  assert.equal(partial.status, "confirmed", "precondition: cart A checks out 1 of its 2 held units");
  assert.ok(
    refused(() => m.confirmOrder({ orderId: "rp4-o2", requestId: "rp4-r2", sku: "SKU-1004", location: "DC-EAST", qty: 5, cartId: "rp4-cart-B" })),
    "B confirmed all 5 while A still holds 1: the partial checkout released the whole hold",
  );
});

test("robustness 5: a second confirm for the same orderId under a new requestId does not confirm again", async () => {
  const m = await load();
  const first = attempt("confirmOrder", () =>
    m.confirmOrder({ orderId: "rp5-o1", requestId: "rp5-r1", sku: "SKU-1001", location: "DC-WEST", qty: 5 }));
  assert.equal(first.status, "confirmed", "precondition: the first confirm of 5 of 50 goes through");
  let second: { status: string; qty: number };
  try {
    second = m.confirmOrder({ orderId: "rp5-o1", requestId: "rp5-r2", sku: "SKU-1001", location: "DC-WEST", qty: 7 });
  } catch {
    return; // refused as a duplicate order
  }
  assert.ok(
    !(second.status === "confirmed" && second.qty === 7),
    "orderId rp5-o1 was confirmed a second time (qty 7) because idempotency is keyed on the requestId",
  );
});
