# FEATURE-FIX — reference elicited build of the cart hold

> Spoiler. Examiner-only; stripped from the learner clone.

`feature-reference/backend/` is a cart hold written from `FEATURE-REQUEST.md` plus the answers in
`feature-qa.md` and nothing else: what a learner's assistant can build once the learner has asked
the questions and handed the answers over. It is the proof that gate (b) can be passed from the
elicited rules alone, the same way `FIX.md` is the proof for gate (a). It includes `FIX.md`'s
resolver fix, because the hold reserves against the ATP that fix computes.

## Files (full replacements for the shipped ones)

| File | What changed | Rule (feature-qa) |
|---|---|---|
| `backend/src/availability.ts` | `FIX.md`'s ATP formula; `availableToPromise(sku, location, cartId?)` subtracts every *other* cart's active holds from the live figure, which is queried fresh every call | Q1, Q6, Q7, Q9 |
| `backend/src/reservations.ts` | `placeHold`: whole units ≥ 1; store-wide sweep of expired holds on every call; granted if `qty <=` what is promisable to that cart; one hold per (SKU, location, cart), replaced with the new line total and a fresh timer; returns a copy. `place` refuses non-whole quantities; `active`/`all` return copies; `heldQty` and `consume` added | Q2, Q3, Q4, Q10, Q11 |
| `backend/src/orders.ts` | de-dupe keyed on `orderId`; `qty` must be a whole number ≥ 1 and `<=` what is promisable to the cart; a confirm draws the cart's hold down by the units bought only | Q4, Q6, Q11, Q12, Q13 |
| `backend/src/types.ts` | `Order.cartId?`; `HoldRefusedError` | — |
| `backend/test/orders.test.ts`, `backend/test/reservations.test.ts` | the stub test replaced; tests for each rule above | — |

The storefront wiring (add-to-cart places a hold, checkout passes the cart id) is not in the
reference build: gate (b) drives the backend surface only, and the web gates are unchanged. A
learner still owes it — the request asks for it — and the rubric reads it from the diff.

The one import cycle (`availability.ts` ↔ `reservations.ts`) is safe: neither module uses the other
at load time. A learner who breaks it differently (a third module, or holds subtracted in
`orders.ts` and `checkAvailability` separately) is equally correct.

## Verified numbers (2026-09-19)

Each tree was copied into a scratch directory with `_solutions/` and `practice.json` overlaid, and
graded by running `commands.grade` read from `practice.json` (`bash _solutions/grade.sh`):

| Tree | availability | feature | web | result |
|---|---|---|---|---|
| Shipped stub | 6/14 | 0/10 | 1/2 | FAIL |
| `FIX.md` only | 14/14 | 0/10 | 2/2 | FAIL |
| Naive one-shot, 2026-09-16 round 6 (replayed onto `231d6df`, diffstat identical to `r06.diff`: 10 files, +376/−35) | 14/14 | **5/10** | 2/2 | FAIL |
| Elicited, 2026-09-16 `444ab3b` | 14/14 | **8/10** | 2/2 | FAIL |
| **`FIX.md` + `feature-reference/`** | **14/14** | **10/10** | **2/2** | **PASS** |

On the reference tree `commands.test` is green (backend 32/32, web 10/10) and the robustness
probes score **5/5**. Gate (b) passed 15/15 repeat runs, and 6/6 with four CPU-bound processes
running alongside (test 9's timing margins are 300 ms or more). Mutation checks on the reference:
stacking a second hold instead of replacing it, and keeping the first placement's expiry, each fail
test 9 alone (9/10). Tests 5, 6, 7, 8 and 10 are each failed, with their named message, by one of
the two 2026-09-16 builds above.

To reproduce: copy the practice, apply `FIX.md`, `cp -R _solutions/feature-reference/backend/. backend/`,
then run `commands.install` and `commands.grade` from `practice.json`.
