# feature-qa — phase-3 cart hold

> Spoiler / answer key. Examiner-only; stripped from the learner clone.

**FEATURE (as given to the learner in `FEATURE-REQUEST.md`):** let a shopper reserve an item for
10 minutes while they check out (a "cart hold"), on both the storefront and the backend.

The request is a thin, realistic PM ask (2-3 sentences, no methodology and **no hint** that a trap
exists — like the TICKET, it just states what the PM wants). A learner who elicits requirements
before delegating should surface something close to the questions below; one who doesn't will hand
an assistant a vague prompt and get a plausible-but-wrong cart hold back (a feature-shaped FM-13).

**Objectively gated:** the phase-3 feature is graded by `_solutions/feature-acceptance.test.ts`
(wired into `grade.sh` as gate (b)) — a naive hold that records holds but never re-checks them at
confirm scores **2/4** (oversells), the minimal correct hold scores **4/4**. So "the AI built a
hold and the demo works" is not enough; it has to actually reserve. See `trap-manifest.md`'s
"Feature trap (phase 3)".

Existing scaffolding the learner will find: `backend/src/reservations.ts` already has a
`holds` store (`place`, `active`, `all`) and a `placeHold(sku, qty, ttlMs)` stub that throws
`"not implemented: cart holds are not yet wired up"`. The `Hold` type
(`{sku, location, qty, createdAt, ttlMs, expiresAt}`) is already defined in `types.ts`. Nothing in
the storefront calls it yet — `web/README.md`'s Cart section says the cart is "just a local tally
shown in the header until checkout," with no server-side hold.

## Held-back questions (a strong learner surfaces these before delegating)

1. **Does a hold decrement ATP for other shoppers, or is it advisory only (UI-only, doesn't
   affect what other shoppers can buy)?**
   → It must be **real**: a hold has to reserve against live ATP. An advisory-only hold (e.g. a
   client-side countdown with no server effect) doesn't solve the problem the feature exists
   for — two shoppers could both be shown "in stock" and both check out the last unit. The hold
   has to reduce the ATP visible to everyone else for the held duration.

2. **Is a hold keyed on the SKU alone, or on `(SKU, cart)`?**
   → `(SKU, cart)` — the business entity. A SKU-only key can't tell two different shoppers'
   holds apart (or a shopper's second hold from their first), and can't be released or
   re-checked per-shopper at confirm. This is the same discipline as FM-06 (idempotency keyed on
   the business entity, not a transport id) applied to holds: key on what the domain actually
   distinguishes, not on the smallest thing that happens to compile.

3. **How and when are expired holds released — does anything sweep them?** (ties to FM-07)
   → Holds must be released on TTL expiry, and something must actually evict them — an unbounded
   holds map that only ever grows (the existing `reservations.ts` `holds` Map has no eviction
   path at all) is exactly the FM-07 shape: fine in a quick manual test, a slow leak (and a slow
   *ATP* leak — expired-but-uncounted holds keep suppressing availability) in production.

4. **What happens at exactly-zero ATP — can you hold the last unit? Can the shopper who already
   holds units place a second hold on the same SKU?** (boundary, ties to FM-04)
   → The spec doesn't hand this answer over; the learner should name it explicitly rather than
   let a `<`/`<=` choice fall out by accident, the same way `orders.ts`'s `qty < atp` and
   `atp.ts`'s inbound-window comparison are strict where the domain's boundary case matters.

5. **Does a hold survive an availability change — what if the ATP the hold was placed against
   drops (e.g. from a new reservation elsewhere) while the hold is active?**
   → Not something to silently paper over: name it as a scoped-out edge (a hold reserves at
   placement time; it does not get invalidated by a later drop in ATP from other causes) rather
   than pretend the system handles it and never test that it does.

6. **Is the hold re-checked live at order confirmation, or is the earlier hold trusted as proof
   of availability?**
   → **Re-checked live at confirm.** A hold is a temporary claim, not a guarantee — the same
   principle as "treat every availability check as a fresh, live query" from
   `reference/erp-availability-contract.md`. Trusting a stale hold at confirm time reintroduces
   exactly the primary bug's failure mode (promising off a number that may no longer be true) one
   layer up the stack.

7. **Does placing a hold require an ERP round-trip, or can it be satisfied against something
   locally cached?**
   → It needs the live ATP number to decide whether the hold can be granted at all (you cannot
   correctly hold more than what's currently promisable) — so it goes through the same
   `availableToPromise` resolver root the fix already routes through, not a separate path that
   could drift from it.

8. **What is the minimal correct surface, and what is explicitly deferred?**
   → See below. A learner who tries to build hold analytics, configurable TTLs, multi-item cart
   holds, or a caching layer for the hold check in the same pass has skipped straight past
   requirements elicitation into over-build (FM-10) — the request was ten minutes, one item, one
   cart.

## Minimal correct behaviour

A cart hold that:
- **reserves against live ATP** — placing a hold for qty *n* on a SKU/location makes that *n*
  unavailable to every other shopper's availability check and order confirmation for the
  duration of the hold (i.e. the ATP calculation, or what it feeds, accounts for active holds);
- is **keyed on the business entity** `(SKU, cart)`, not the SKU alone and not a transport/request
  id;
- is **released on TTL expiry**, and expiry is actually **swept** — not left to accumulate in an
  unbounded store (closing the FM-07 gap already present in `reservations.ts`'s holds map);
- is **re-checked live at order confirmation** — the confirm root queries current availability
  again rather than trusting the hold as a stored fact.

Everything else — configurable TTLs, multi-SKU cart holds, hold analytics/telemetry, a caching
layer in front of the live ATP check, cross-device cart merge — is explicitly **deferred out
loud**, not built. Naming these out loud and not building them is the restraint half of the
rubric's driving axis; silently building them (or silently *not* handling them and never saying
so) both fail it, for opposite reasons.

## What a naive implementation gets wrong

The failure modes a plausible-looking but wrong first pass tends to hit:
- **Double-counts holds** — placing a hold twice (e.g. shopper double-clicks "add to cart," or a
  retry) creates two holds instead of updating one, silently reserving more than the shopper
  actually asked for (the same idempotency shape as FM-06, now applied to the hold's own
  placement, not just order confirmation).
- **Holds against the stale snapshot instead of live ATP** — if the hold check is wired to
  `snapshot.onHand`, the stale `promisableStock` helper, or copies the primary bug's `rec.on_hand`
  shortcut instead of the live ATP query, the hold "succeeds" against a number that was never
  promisable in the first place, reproducing the exact defect this practice's phase 2 exists to
  fix, one layer up.
- **Leaks holds forever** — no TTL sweep, so every abandoned cart holds inventory hostage
  indefinitely; ATP visibly and permanently shrinks over time even though nothing was actually
  sold (the FM-07 unbounded-growth shape, now user-visible as "why does this say sold out when
  the warehouse has stock?").
