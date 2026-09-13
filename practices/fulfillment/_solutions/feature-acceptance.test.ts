// HIDDEN feature-acceptance grader (phase 3 — the cart hold). Examiner-only;
// stripped from the learner clone. Drives only the PUBLIC feature surface
// (placeHold + confirmOrder) against the live ERP feed, and asserts the
// held-back requirements a naive "implement the hold" delegation misses:
//
//   - a hold must REDUCE what OTHER carts can confirm (i.e. the hold is
//     re-checked at confirm — not just recorded in a store);
//   - a hold must reserve against LIVE ATP, not raw on-hand;
//   - holds accumulate against ATP across carts (no double-promise);
//   - a cart is not blocked by its OWN hold at confirm.
//
// This must FAIL while placeHold is the stub (feature not built) AND while the
// primary availability bug is unfixed (ATP wrong), and PASS only once the bug
// is fixed AND the hold reserves against live ATP and is re-checked at confirm.
// Each test uses a distinct SKU so module-level hold state doesn't leak between
// tests (no reliance on a release/reset export).

import { fileURLToPath } from "node:url";
import { test } from "node:test";
import assert from "node:assert/strict";

process.env.ATP_SOURCE = "live";
process.env.ERP_FEED_DIR = fileURLToPath(
  new URL("../reference/infra/erp-availability/", import.meta.url),
);

const { placeHold } = await import("../backend/src/reservations.ts");
const { confirmOrder } = await import("../backend/src/orders.ts");

// SKU-1002 true ATP = 22. A hold by one cart must reduce what another can confirm.
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
test("feature: a hold reserves against live ATP, not raw on-hand", () => {
  placeHold("SKU-1004", "DC-EAST", 3, "cart-C1", 600_000); // within ATP 5 → ok
  assert.throws(() => placeHold("SKU-1004", "DC-EAST", 12, "cart-C2", 600_000)); // 12 > ATP 5, though < on_hand 30
});

// SKU-1003 true ATP = 13. Holds by different carts accumulate against ATP.
test("feature: holds accumulate against ATP across carts (no double-promise)", () => {
  placeHold("SKU-1003", "DC-EAST", 8, "cart-D", 600_000);
  assert.throws(() => placeHold("SKU-1003", "DC-EAST", 8, "cart-E", 600_000)); // only 13 - 8 = 5 left
});

// SKU-1006 true ATP = 25. A cart is not blocked by its own hold at confirm.
test("feature: a cart is not blocked by its own hold at confirm", () => {
  placeHold("SKU-1006", "DC-WEST", 20, "cart-F", 600_000);
  const ok = confirmOrder({ orderId: "o3", requestId: "r3", sku: "SKU-1006", location: "DC-WEST", qty: 10, cartId: "cart-F" });
  assert.equal(ok.status, "confirmed"); // own hold excluded → sees full ATP 25
});
