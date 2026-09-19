// HIDDEN feature-acceptance grader (phase 3 — the cart hold). Examiner-only;
// stripped from the learner clone. Drives only the PUBLIC feature surface
// (placeHold + confirmOrder, plus the holds store's existing all() export)
// against the live ERP feed, and asserts the held-back requirements a naive
// "implement the hold" delegation misses. Every assertion below is the answer
// to a question in feature-qa.md — a learner who asks it gets the rule; one who
// hands FEATURE-REQUEST.md over raw gets the assistant's guess, and the request
// is written so that the guess goes the wrong way.
//
//   1-4 (the hold reserves at all):
//   - a hold must REDUCE what OTHER carts can confirm (re-checked at confirm);
//   - a hold must reserve against LIVE ATP, not raw on-hand;
//   - holds accumulate against ATP across carts (no double-promise);
//   - a cart is not blocked by its OWN hold at confirm.
//   5-10 (the rules the request leaves out — feature-qa Q4, Q10-Q13, Q3):
//   - the last units are holdable and buyable (exactly-ATP is promisable);
//   - re-placing a cart's hold sets the line's new total and restarts the timer;
//   - a partial checkout releases only the units ordered;
//   - holds and orders take positive whole quantities only;
//   - an order is identified by its orderId: a new requestId does not confirm it twice;
//   - expired holds stop reserving and are swept from the whole store.
//
// This must FAIL while placeHold is the stub (feature not built) AND while the
// primary availability bug is unfixed (ATP wrong), and PASS only once the bug
// is fixed AND the hold follows the elicited rules. There is no release/reset
// export to lean on, so state carries between tests: each test uses its own
// carts and order ids, and where a SKU is reused the expected numbers account
// for the holds the earlier tests leave behind (noted at each test). Probe
// orders come from carts that hold nothing, so a probe changes no hold state.
// node:test runs the tests of one file in order.

import { fileURLToPath } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";
import { test } from "node:test";
import assert from "node:assert/strict";

process.env.ATP_SOURCE = "live";
process.env.ERP_FEED_DIR = fileURLToPath(
  new URL("../reference/infra/erp-availability/", import.meta.url),
);

const reservations = await import("../backend/src/reservations.ts");
const { placeHold } = reservations;
const { confirmOrder } = await import("../backend/src/orders.ts");

// A refusal may be a "rejected" status or a thrown error; both refuse the order.
function refused(fn: () => { status: string }): boolean {
  try {
    return fn().status !== "confirmed";
  } catch {
    return true;
  }
}

// An order from a cart that holds nothing: reads what is promisable to everyone
// else without changing any hold.
let probeSeq = 0;
function probe(sku: string, location: string, qty: number): () => { status: string } {
  probeSeq += 1;
  const id = `probe-${probeSeq}`;
  return () => confirmOrder({ orderId: id, requestId: id, sku, location, qty, cartId: `probe-cart-${probeSeq}` });
}

// SKU-1002 true ATP = 22. A hold by one cart must reduce what another can confirm.
// Leaves: cart-A holds 15 of SKU-1002.
test("feature: a hold blocks another cart from overselling the remainder", () => {
  placeHold("SKU-1002", "DC-WEST", 15, "cart-A", 600_000);
  const tooBig = confirmOrder({ orderId: "o1", requestId: "r1", sku: "SKU-1002", location: "DC-WEST", qty: 10, cartId: "cart-B" });
  assert.equal(tooBig.status, "rejected"); // only 22 - 15 = 7 promisable to cart-B
  const ok = confirmOrder({ orderId: "o2", requestId: "r2", sku: "SKU-1002", location: "DC-WEST", qty: 5, cartId: "cart-B" });
  assert.equal(ok.status, "confirmed");
});

// SKU-1004 true ATP = 5 but on_hand = 30. A hold within ATP succeeds; a hold that
// exceeds ATP (but fits under on_hand) must be refused — a naive check against raw
// on_hand would wave the 12 through. The valid 3-unit hold first also means the
// stub (which throws on any call) fails this test rather than false-passing it.
// Leaves: cart-C1 holds 3 of SKU-1004.
test("feature: a hold reserves against live ATP, not raw on-hand", () => {
  placeHold("SKU-1004", "DC-EAST", 3, "cart-C1", 600_000); // within ATP 5 → ok
  assert.throws(() => placeHold("SKU-1004", "DC-EAST", 12, "cart-C2", 600_000)); // 12 > ATP 5, though < on_hand 30
});

// SKU-1003 true ATP = 13. Holds by different carts accumulate against ATP.
// Leaves: cart-D holds 8 of SKU-1003.
test("feature: holds accumulate against ATP across carts (no double-promise)", () => {
  placeHold("SKU-1003", "DC-EAST", 8, "cart-D", 600_000);
  assert.throws(() => placeHold("SKU-1003", "DC-EAST", 8, "cart-E", 600_000)); // only 13 - 8 = 5 left
});

// SKU-1006 true ATP = 25. A cart is not blocked by its own hold at confirm.
// Leaves: cart-F holds 10 of SKU-1006 (20 held, 10 checked out — see test 8).
test("feature: a cart is not blocked by its own hold at confirm", () => {
  placeHold("SKU-1006", "DC-WEST", 20, "cart-F", 600_000);
  const ok = confirmOrder({ orderId: "o3", requestId: "r3", sku: "SKU-1006", location: "DC-WEST", qty: 10, cartId: "cart-F" });
  assert.equal(ok.status, "confirmed"); // own hold excluded → sees full ATP 25
});

// feature-qa Q4. SKU-1004 has 5 - 3 (cart-C1) = 2 left for everyone else. Holding
// exactly what is left is allowed, and so is buying it: exactly-ATP is promisable.
// Checkout's inherited `qty < atp` would refuse both.
test("feature: the last units can be held and then bought", () => {
  const hold = placeHold("SKU-1004", "DC-EAST", 2, "cart-G", 600_000); // exactly the 2 left
  assert.equal(hold.qty, 2);
  assert.ok(refused(probe("SKU-1004", "DC-EAST", 1)), "another cart confirmed a unit while every unit was held");
  const buy = confirmOrder({ orderId: "o5", requestId: "r5", sku: "SKU-1004", location: "DC-EAST", qty: 2, cartId: "cart-G" });
  assert.equal(buy.status, "confirmed", "the cart holding the last units could not buy them");
});

// feature-qa Q11. SKU-1003 has 13 - 8 (cart-D) = 5 left. Quantities are whole
// units, at least one, for holds AND orders; anything else is refused, never
// confirmed and never held.
test("feature: holds and orders take positive whole quantities only", () => {
  for (const qty of [0, -1, 1.5]) {
    assert.throws(() => placeHold("SKU-1003", "DC-EAST", qty, `cart-q${qty}`, 600_000), `a hold of ${qty} was accepted`);
  }
  // SKU-1005 has nothing to promise (ATP 0): an order for 0 or -1 units must not confirm.
  assert.ok(refused(probe("SKU-1005", "DC-WEST", 0)), "an order for 0 units confirmed on a SKU with ATP 0");
  assert.ok(refused(probe("SKU-1005", "DC-WEST", -1)), "an order for -1 units confirmed on a SKU with ATP 0");
  assert.ok(refused(probe("SKU-1001", "DC-WEST", 1.5)), "an order for 1.5 units confirmed");
});

// feature-qa Q13. The mobile client mints a fresh requestId on every tap; the
// orderId is what identifies the order. SKU-1003 still has 5 left for others.
test("feature: a second confirm of the same orderId under a new requestId does not confirm again", () => {
  const first = confirmOrder({ orderId: "o7", requestId: "r7-tap1", sku: "SKU-1003", location: "DC-EAST", qty: 2 });
  assert.equal(first.status, "confirmed", "precondition: 2 of the 5 left confirm");
  let second: { status: string; qty: number } | undefined;
  try {
    second = confirmOrder({ orderId: "o7", requestId: "r7-tap2", sku: "SKU-1003", location: "DC-EAST", qty: 3 });
  } catch {
    return; // refused as a duplicate order
  }
  assert.ok(
    !(second.status === "confirmed" && second.qty === 3),
    "order o7 was confirmed a second time (qty 3) because the duplicate check is keyed on the requestId",
  );
});

// feature-qa Q12. SKU-1002 has 22 - 15 (cart-A) = 7 left. cart-H holds 6 and
// checks out 2: the other 4 stay held, so 3 remain for everyone else.
test("feature: a partial checkout releases only the units ordered", () => {
  placeHold("SKU-1002", "DC-WEST", 6, "cart-H", 600_000);
  const partial = confirmOrder({ orderId: "o8", requestId: "r8", sku: "SKU-1002", location: "DC-WEST", qty: 2, cartId: "cart-H" });
  assert.equal(partial.status, "confirmed", "precondition: cart-H checks out 2 of its 6 held units");
  assert.ok(refused(probe("SKU-1002", "DC-WEST", 4)), "another cart confirmed 4 while cart-H still holds 4: the checkout released the whole hold");
  assert.ok(!refused(probe("SKU-1002", "DC-WEST", 2)), "another cart could not confirm 2 of the 3 left");
});

// feature-qa Q10 + Q3. SKU-1001 true ATP = 50, untouched so far. Placing again for
// the same cart and SKU sets the line's NEW TOTAL (it neither stacks a second hold
// nor adds to the first) and restarts the timer from the latest placement; once the
// timer runs out the units are promisable again. Timing margins are >= 300 ms.
test("feature: re-placing a hold sets the new total and restarts the timer; expiry releases it", async () => {
  const ttl = 1_500;
  placeHold("SKU-1001", "DC-WEST", 20, "cart-R", ttl); // expires at ~1500 unless restarted
  await sleep(900);
  placeHold("SKU-1001", "DC-WEST", 40, "cart-R", ttl); // new total 40, expires at ~2400
  assert.ok(refused(probe("SKU-1001", "DC-WEST", 11)), "40 of 50 are held by cart-R, yet another cart confirmed 11");
  assert.ok(!refused(probe("SKU-1001", "DC-WEST", 9)), "another cart could not confirm 9 of the 10 left: the hold stacked instead of being replaced");
  await sleep(900); // ~1800: past the first placement's expiry, before the restarted one's
  assert.ok(refused(probe("SKU-1001", "DC-WEST", 11)), "the hold lapsed on the first placement's timer: re-placing did not restart it");
  await sleep(900); // ~2700: past the restarted expiry
  assert.ok(!refused(probe("SKU-1001", "DC-WEST", 49)), "cart-R's hold outlived its TTL and still reserves stock");
});

// feature-qa Q3. Expiry must be swept from the whole store on every placeHold, not
// only when the expired hold's own SKU happens to be read again. After a short
// hold on SKU-1006 expires, a hold on a different SKU leaves no expired hold
// anywhere in the store (cart-R's lapsed SKU-1001 hold from test 9 included).
// SKU-1002 still has 3 left for others, so the 1-unit hold is granted.
test("feature: expired holds are swept from the whole store", async () => {
  placeHold("SKU-1006", "DC-WEST", 1, "cart-S", 30);
  await sleep(120);
  placeHold("SKU-1002", "DC-WEST", 1, "cart-T", 600_000);
  assert.equal(typeof reservations.all, "function", "the holds store no longer exports all()");
  const now = Date.now();
  const stale: string[] = [];
  for (const [key, value] of reservations.all()) {
    for (const hold of (Array.isArray(value) ? value : [value]) as Array<{ cartId: string; expiresAt: number }>) {
      if (hold.expiresAt <= now) stale.push(`${String(key)}/${hold.cartId}`);
    }
  }
  assert.deepEqual(stale, [], `expired holds still in the store after a placeHold: ${stale.join(", ")}`);
});
