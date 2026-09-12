# trap-manifest — everything planted, honestly inventoried

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Cross-reference
> `context/cedar/failure-modes.md` for each FM's full definition.

## Primary bug (phase 2)

**Location:** `backend/src/availability.ts`, `availableToPromise(sku, location)`, the `live`
branch — `return rec.on_hand;` should be `return computeAtp(rec);` (see `FIX.md`).

**Why it is invisible to the shipped suites (26/26 backend + 10/10 web, both green):** the unit
suites exercise the seed SKUs `SKU-1001`/`SKU-1006`, both never-reserved
(`reserved = allocated = 0`, no inbound), for which `computeAtp(rec) === rec.on_hand` exactly.
The local `snapshot.ts` fixture is built the same way, so even flipping `ATP_SOURCE` doesn't
expose the gap under seed data. The bug only produces a wrong answer for SKUs with open
reservations, allocations, or lead-time-relevant inbound — none of which the unit suites touch.
It is caught only by the hidden dual grader (`_solutions/backend-acceptance.test.ts` +
`_solutions/web-integration.test.tsx`, wired through `grade.sh`), which calls the resolver root
directly with `ATP_SOURCE=live` against the full `reference/` feed, including the contended SKUs.
Verified flip: backend 6/14 → 14/14, web 1/2 → 2/2 (see `FIX.md`, `BUILD-LEDGER.md` N5).

**FM coverage:**
- **FM-15** (context rot) — a stale code path encoding an abandoned assumption
  (`stock_count`/snapshot "availability = on-hand we hold" era), with a misleading comment and no
  doc anywhere admitting the live-ATP truth. See the FM-15 section below and
  `doc-drift-ledger.md`.
- **FM-01 × FM-02** — bug invisible to a large green suite (FM-01), and silent/subset-only:
  correct for never-reserved SKUs, wrong for contended ones (FM-02, Cedar's cross-boundary
  extension of the "ambient variable" — here the varying condition is which SKU/location record
  you query, not timezone/locale).
- **FM-16** (cross-boundary) — the true reserved/allocated/inbound numbers exist only in
  `reference/`; a fix reasoned from the local repo alone (local snapshot + local seed) cannot see
  why the "obvious" reading (`on_hand` looks like the right number) is wrong. See its own section
  below.

## Assistant-targeted traps (FM-13, required)

FM-13 is "delegation before comprehension" — planted so that the two most likely *shallow*
fixes both provably fail to converge, and only the comprehension-first fix does.

### Trap A — symptom-patch the checkout handler stays RED
**The autopilot move it punishes:** patching at the call site nearest the visible symptom (add a
clamp/re-check in the checkout flow, e.g. in a component or an HTTP handler layer) instead of
the root that computes availability. This is the textbook FM-13 "symptom-patching" shape —
whack-a-mole that never touches the actual defect.
**Why it fails here:** the hidden grader calls `availableToPromise`/`confirmOrder` directly
(`orders.ts`'s `confirmOrder` **is** the root the grader tests — see `BUILD-LEDGER.md` N2: "this
is what the grader calls directly (root-tested, so a checkout-handler symptom-patch stays red)").
A patch anywhere above that root — the storefront, a hypothetical HTTP wrapper — never changes
what the root itself returns, so the grader's direct calls still see `rec.on_hand` and the
grader stays red at 6/14 no matter how convincing the storefront-side patch looks.
**The discipline that beats it:** *model-before-delegation* + *comprehension-as-ownership* —
trace the availability answer back to where it's actually computed (`availableToPromise`) before
prompting for a fix there, rather than patching wherever the symptom is easiest to see.

### Trap B — re-import/hard-code the one failing SKU plateaus
**The autopilot move it punishes:** reproducing the ticket against the single most obvious SKU
(most likely `SKU-1002`, the "open reservations" case, since it's first in the contended set),
getting a plausible-looking fix that special-cases or hard-codes that SKU's corrected number, and
declaring victory once that one case passes.
**Why it fails here:** that fix passes the shipped unit suite (which never ran `SKU-1002` under
`ATP_SOURCE=live`) and even passes the grader's `SKU-1002` vector, but the grader scores
worst-case across **all** contended SKU states (`SKU-1003` backorder+inbound-in-window,
`SKU-1004` inbound-outside-lead-time red herring, `SKU-1005` exactly-zero-ATP boundary) plus
conformance vectors derived from `reference/`. A special case for one SKU id doesn't generalize
to the general rule, so the grader plateaus short of 14/14 the moment it reaches the next
contended SKU.
**The discipline that beats it:** *establish-cross-boundary-context* (open `reference/` and
derive the general rule from `atp-spec.md`, not from one SKU's numbers) + *reconcile-docs*
(recognize that "the one SKU in the ticket" is a symptom, not the whole defect class) — the only
fix that converges is implementing `computeAtp` at the resolver root, which is correct for every
SKU because it implements the rule instead of memorizing an answer.

### VERIFIED-TO-BITE (N8 — real captured `bash grade.sh` outcomes)
Reproduced on 2026-09-12 against the shipped (bug-present) tree; every deliberately-wrong edit was
applied, measured, then **discarded** (`git checkout --`), so the only file this node changed is
this manifest. Baseline with the bug present: **backend 6/14, web 1/2, exit 1 (RED)**.

| # | Autopilot move (the deliberately-wrong edit) | `grade.sh` result | What it proves |
|---|---|---|---|
| 1 | **Symptom-patch at the call site** — special-case the ticketed SKU in `orders.ts` `confirmOrder` (`const atp = order.sku === "SKU-1002" ? 22 : availableToPromise(...)`), leaving the resolver root untouched | **backend 7/14, web 2/2 → RESULT: FAIL (exit 1)** | The patch fixes the one ticketed SKU's *confirm* decisions and even makes the **web gate pass (2/2)** — the visible symptom looks solved — but the root-tested backend conformance vectors (which call `availableToPromise` directly) stay RED for every other contended SKU. Overall still FAIL. Textbook FM-13 symptom-patch. |
| 2 | **Re-import / hard-code the one SKU** — `if (sku === "SKU-1002") return 22;` in the resolver's live branch, above `return rec.on_hand;` | **backend 8/14, web 2/2 → RESULT: FAIL (exit 1)** | Climbs only 6→**8/14** (SKU-1002's conformance vector + confirm now pass) then **plateaus**: `SKU-1003`/`SKU-1004`/`SKU-1005` still fail because a per-SKU constant doesn't implement the rule. Special-casing more SKUs just chases the plateau; it never reaches 14/14. |
| 3 | **No-`reference/` / single-scope fix** — trust the local on-hand (the shipped bug itself, or pointing confirm at the local snapshot) without computing ATP from the feed's reserved/allocated/inbound | **backend 6/14 (conformance vectors RED)** | A fix derived only from what the single repo can see never subtracts reservations/allocations, so the `reference/`-derived conformance vectors (`availableToPromise(live) === true ATP`) fail for SKU-1002/1003/1004/1005. Only a research pass that reads `reference/` converges (FM-16). |
| 4 | **local-green vs prod-red** (no edit) | `cd backend && npm test` **26/26**, `cd web && npm test` **10/10** GREEN, yet `grade.sh` RED | The "works on my machine" axis: the whole unit suite is green on the seed (snapshot == ATP) while the live feed oversells. Trusting the green suite (FM-01) ships the defect. |
| 5 | **Control — the real root fix** — `import { computeAtp }` + live branch `return computeAtp(rec);` | **backend 14/14, web 2/2 → RESULT: PASS (exit 0)** | Only implementing the rule at the resolver root converges, for every SKU at once (independently reproduces FIX.md's numbers). |

Net: the two shallow fixes (symptom-patch 7/14, hard-code-one 8/14) both stay RED; the FM-16
single-scope fix fails the conformance vectors; only the comprehension-first live-ATP root fix
reaches 14/14 · 2/2. The traps bite as designed.

## FM-15 — context rot (detail)

**The stale code path:** `backend/src/availability.ts`'s `live` branch, `return rec.on_hand;`,
with a comment claiming it "mirrors the nightly availability_snapshot's on-hand figure" — a
description of an *earlier* stage of the `stock_count` → `availability_snapshot` → live-ATP
migration, left in place with no doc anywhere pointing out that the live path was supposed to
call `computeAtp` instead. No README, comment, or contract in the repo states the live-ATP truth;
the only place it's stated is `reference/atp-spec.md` and `reference/erp-availability-contract.md`
— both outside the local repo's own docs.

**The contradicting docs:** see `doc-drift-ledger.md` for the full table — `backend/README.md`'s
"stock is decremented from `stock_count`" line (two migrations stale) and `web/README.md`'s
`GET /stock` endpoint name (the real route is `GET /availability`) are both prose that lags the
migration and would steer a doc-trusting prompt toward the wrong mental model before it even
looks at the code.

## FM-16 — cross-boundary (detail)

The authoritative reserved/allocated/inbound numbers for every SKU exist **only** in
`reference/infra/erp-availability/*.json`, described by `reference/erp-availability-contract.md`
(live query, keyed on `(sku, location)`, returns `atp` only — never `on_hand`) and
`reference/atp-spec.md` (the formula, with the inclusive `<=` lead-time boundary). A fix
attempted without opening `reference/` at all can only see the local repo's own `on_hand`-shaped
snapshot and will, at best, reproduce the primary bug's own assumption (on-hand is promisable) or
guess at a formula that doesn't match `atp-spec.md`'s worked examples. The hidden grader's
conformance vectors are derived directly from the reference feed, so a no-research fix fails them
even if it happens to pass the shipped unit suite.

## Ranked latent defects (≥5, each idiomatic, each traceable to an FM)

Ranked by production impact (highest first). None of these are exercised by the shipped suites
or required to reach 14/14 + 2/2 on the shipped SKU set — the grader's guidance (`BUILD-LEDGER.md`
N5) deliberately tests with quantities and locations away from these boundaries so the primary
fix alone reaches full marks. They exist for a learner's honest-review pass (FM-14) to *find and
name*, not to block the grade.

1. **FM-06 — idempotency keyed on transport id, not the business entity.**
   `backend/src/orders.ts`, `confirmOrder`: `processed.set(order.requestId, result)` /
   `processed.get(order.requestId)`. `requestId` is the client-generated, per-attempt transport
   id (`web/README.md`: "a client-generated `requestId` so a retried submission doesn't double-
   place the order"); the actual business entity being deduplicated is the order itself
   (`orderId`, or `(sku, location, qty)` as placed by a given cart). Keying on `requestId` means
   a *new* attempt to place what is logically the same order (a fresh `requestId`, e.g. the
   shopper double-submits after a UI glitch generates a new client-side id) is not recognized as
   a duplicate and can confirm twice, oversell, and race against the primary fix's own ATP
   accounting.

2. **FM-05 — reservations store returns internal state by reference.**
   `backend/src/reservations.ts`: `active(sku)` returns `holds.get(sku) ?? []` — the live array
   held inside the module's `Map`, not a copy — and `all()` returns the module's `Map` object
   itself. Any caller that pushes/splices/mutates what it got back silently corrupts the store's
   internal state; each individual call site can look correct in isolation while the invariant
   ("the store owns its data") quietly erodes system-wide.

3. **FM-07 — unbounded holds map, no TTL eviction.**
   `backend/src/reservations.ts`: `const holds = new Map<Sku, Hold[]>();` — `place` only ever
   appends; nothing in the module reads `Hold.expiresAt`/`ttlMs` to sweep expired holds. Even
   though `placeHold` itself is currently a stub that throws, the store it sits on top of is
   already shaped to leak: once the cart-hold feature is wired up (`feature-qa.md`), every
   expired-but-unswept hold keeps suppressing availability forever, a slow ATP leak in
   production. This is the concrete latent defect a naive cart-hold implementation is most
   likely to inherit unfixed.

4. **FM-04 — strict boundary comparisons at exactly-zero ATP.**
   `backend/src/orders.ts`, `confirmOrder`: `const accepted = order.qty < atp;` (strict `<`, so a
   qty exactly equal to ATP is rejected, not accepted) and `backend/src/availability.ts`,
   `checkAvailability`: `inStock: atp > 0` (so `atp === 0` correctly reads not-in-stock, but the
   `qty < atp` boundary in `confirmOrder` is arguably off from the domain's real intent — ordering
   *exactly* the remaining ATP should typically succeed). Neither the spec nor any test states
   which side of the boundary is correct; `SKU-1005`'s exactly-zero-ATP feed record exists
   precisely to exercise this once a learner probes boundaries, but the grader's guidance
   deliberately avoids qty values that would turn this into a required fix.

5. **FM-03 — inbound lead-time window uses strict `<` where the spec says `<=`.**
   `backend/src/atp.ts`, `computeAtp`: `line.arrivesInDays < rec.leadTimeDays` — but
   `reference/atp-spec.md` states the boundary is inclusive ("an inbound line with
   `arrivesInDays` exactly equal to `leadTimeDays` **is** counted"). This is latent, not
   currently biting: no shipped SKU in the canonical feed has an inbound line landing exactly on
   its `leadTimeDays` (`SKU-1003` arrives at day 7 of a 30-day window; `SKU-1004` at day 45 of a
   30-day window — both comfortably off the boundary), so `computeAtp` produces the spec-correct
   number for every SKU that ships today. It is a plausible-but-wrong rule (FM-03's own
   steganography) sitting inside the *correct* function — worth finding on an honest read against
   `atp-spec.md`, not just trusting `computeAtp` because it isn't the file with the bug.

6. **FM-08 — location not validated against the authoritative set.**
   `backend/src/erpFeed.ts`, `getRecord(sku, location)`, and `backend/src/availability.ts`: the
   `location` parameter is threaded through every call (`checkAvailability`, `confirmOrder`) but
   never checked against `reference/erp-availability-contract.md`'s authoritative set
   (`{DC-WEST, DC-EAST}`) before being used — a `location` typo or an unprovisioned code
   (`UnknownLocationError` is defined in `types.ts` but nothing in `availability.ts`/`erpFeed.ts`
   throws it) does not fail the way the real ERP contract specifies ("rejected as unknown... does
   not silently fall back"); instead the feed lookup proceeds keyed by SKU id alone (the feed is
   laid out one file per SKU, so `location` isn't even part of the lookup key today) and can
   silently return a record for the wrong location context.
