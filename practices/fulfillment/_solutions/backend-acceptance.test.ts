// HIDDEN acceptance grader (examiner-only — never shipped to the learner's
// clone). Points ATP_SOURCE at the live ERP feed (reference/infra/erp-availability/)
// and asserts the resolver root returns the TRUE available-to-promise figure,
// not the feed's raw on_hand — and that confirmOrder's accept/reject decisions
// track true ATP for contended SKUs. This must FAIL while the primary bug
// (availability.ts's live branch returning rec.on_hand) is present, and PASS
// once the resolver computes the full ATP formula from reference/atp-spec.md
// (on_hand - reserved - allocated + inbound-within-lead-time) at the root.
//
// ES module imports are hoisted ahead of any top-level statement regardless of
// textual position, so setting these env vars is safe here: availability.ts's
// source() and erpFeed.ts's feedDir() both read process.env at CALL time
// (inside confirmOrder/availableToPromise, invoked from test bodies below),
// never at module-load time — so both env vars are guaranteed to be in place
// before any resolver code actually runs.

import { fileURLToPath } from "node:url";
import { test } from "node:test";
import assert from "node:assert/strict";
import { availableToPromise } from "../backend/src/availability.ts";
import { confirmOrder } from "../backend/src/orders.ts";

process.env.ATP_SOURCE = "live";
process.env.ERP_FEED_DIR = fileURLToPath(
  new URL("../reference/infra/erp-availability/", import.meta.url)
);

// ---------------------------------------------------------------------------
// Conformance vectors: availableToPromise(sku, location) must equal the TRUE
// ATP computed from the reference feed (on_hand - reserved - allocated +
// eligible inbound), not the feed's raw on_hand. Pre-fix, every contended SKU
// (1002-1005) fails here because the live branch returns on_hand verbatim.
// ---------------------------------------------------------------------------

const TRUE_ATP: Array<{ sku: string; location: string; atp: number }> = [
  { sku: "SKU-1001", location: "DC-WEST", atp: 50 },
  { sku: "SKU-1002", location: "DC-WEST", atp: 22 },
  { sku: "SKU-1003", location: "DC-EAST", atp: 13 },
  { sku: "SKU-1004", location: "DC-EAST", atp: 5 },
  { sku: "SKU-1005", location: "DC-WEST", atp: 0 },
  { sku: "SKU-1006", location: "DC-WEST", atp: 25 },
];

for (const { sku, location, atp } of TRUE_ATP) {
  test(`availableToPromise(live): ${sku} @ ${location} === true ATP ${atp}`, () => {
    assert.equal(availableToPromise(sku, location), atp);
  });
}

// ---------------------------------------------------------------------------
// confirmOrder root decisions across ≥3 SKU states. Quantities are chosen away
// from the exact-ATP boundary (so the strict `<` FM-04 latent defect never
// changes the expected verdict) and each SKU's own valid location (so the
// FM-08 location-validation latent defect never changes the expected verdict
// either) — these vectors isolate the PRIMARY bug only.
// ---------------------------------------------------------------------------

let requestSeq = 0;
function nextRequestId(): string {
  requestSeq += 1;
  return `acceptance-req-${requestSeq}`;
}

function expectDecision(
  label: string,
  order: { sku: string; location: string; qty: number },
  expectedStatus: "confirmed" | "rejected"
) {
  test(`confirmOrder: ${label}`, () => {
    const requestId = nextRequestId();
    const result = confirmOrder({
      orderId: requestId,
      requestId,
      sku: order.sku,
      location: order.location,
      qty: order.qty,
    });
    assert.equal(result.status, expectedStatus);
    assert.equal(result.sku, order.sku);
    assert.equal(result.location, order.location);
    assert.equal(result.qty, order.qty);
  });
}

// SKU-1002 (true ATP 22; snapshot/live bug would report on_hand 40) —
// oversell guard: a quantity the true ATP cannot cover must be rejected, one
// well inside it must be confirmed.
expectDecision(
  "SKU-1002 qty 30 (> true ATP 22) -> rejected",
  { sku: "SKU-1002", location: "DC-WEST", qty: 30 },
  "rejected"
);
expectDecision(
  "SKU-1002 qty 10 (< true ATP 22) -> confirmed",
  { sku: "SKU-1002", location: "DC-WEST", qty: 10 },
  "confirmed"
);

// SKU-1004 (true ATP 5; buggy live branch would report on_hand 30, an inbound
// red herring that arrives outside the lead-time window and so does not count).
expectDecision(
  "SKU-1004 qty 12 (> true ATP 5) -> rejected",
  { sku: "SKU-1004", location: "DC-EAST", qty: 12 },
  "rejected"
);
expectDecision(
  "SKU-1004 qty 3 (< true ATP 5) -> confirmed",
  { sku: "SKU-1004", location: "DC-EAST", qty: 3 },
  "confirmed"
);

// SKU-1005 (true ATP 0 — fully reserved) — even qty 1 must be rejected. The
// buggy live branch would report on_hand 10 and wrongly confirm it.
expectDecision(
  "SKU-1005 qty 1 (true ATP 0) -> rejected",
  { sku: "SKU-1005", location: "DC-WEST", qty: 1 },
  "rejected"
);

// SKU-1003 (true ATP 13 once inbound-within-lead-time is counted; the STALE
// snapshot's on_hand of 8 would wrongly reject qty 10 — the under-promise
// direction of the same bug class). This is the vector that specifically
// catches a fix that special-cases only the oversell direction.
expectDecision(
  "SKU-1003 qty 10 (< true ATP 13, > stale on_hand 8) -> confirmed",
  { sku: "SKU-1003", location: "DC-EAST", qty: 10 },
  "confirmed"
);
expectDecision(
  "SKU-1003 qty 20 (> true ATP 13) -> rejected",
  { sku: "SKU-1003", location: "DC-EAST", qty: 20 },
  "rejected"
);

// SKU-1001 (true ATP 50, never-reserved seed) — sanity vector that passes both
// pre- and post-fix, so a grader run always has at least one green baseline.
expectDecision(
  "SKU-1001 qty 10 (seed, well under ATP 50) -> confirmed",
  { sku: "SKU-1001", location: "DC-WEST", qty: 10 },
  "confirmed"
);
