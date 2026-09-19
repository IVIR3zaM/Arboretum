# feature-qa — phase-3 cart hold

> Spoiler / answer key. Examiner-only; stripped from the learner clone.

**FEATURE (as given to the learner in `FEATURE-REQUEST.md`):** let a shopper reserve an item for
10 minutes while they check out (a "cart hold"), on both the storefront and the backend.

The request is a short, realistic PM ask — no methodology and **no hint** that a trap exists. It
**looks easy on purpose**, and five of its casual lines each point an assistant at the wrong rule.
Every lure is something a PM plausibly says, and every one sounds settled; the true rule only comes
back to a learner who treats the line as a claim to check and asks the person who owns it:

| PM line in `FEATURE-REQUEST.md` | Where it leads an assistant | The rule (question below) | Gate (b) test |
|---|---|---|---|
| "Same rules as checkout — a hold shouldn't promise anything checkout wouldn't." | reuse `orders.ts`'s `qty < atp` for holds, so the last unit can be neither held nor bought | exactly-ATP is promisable, for holds **and** orders (Q4) | 5 |
| (the boundary change the question above leads to) | flip to `qty <= atp` and stop — a 0-unit order now confirms on a sold-out SKU | whole units, ≥ 1, for holds and orders (Q11) | 6 |
| "Double-taps on confirm are already handled, so don't worry about that part." | trust the requestId de-dupe in `orders.ts` | the client mints a new requestId per tap; the **orderId** identifies the order (Q13) | 7 |
| "Once they check out, the hold's done — clear it." | release the whole hold on any confirm | release only the units bought (Q12) | 8 |
| "If they add more of it, just refresh the hold." | renew the timer only, or add a second hold | `qty` is the line's new total; replace and restart the timer (Q10) | 9 |
| "Holds only last 10 minutes, so they clean themselves up." | ignore expired holds on read and never evict them | sweep store-wide on every `placeHold` (Q3) | 10 |

A learner who elicits requirements before delegating should surface something close to the
questions below; one who doesn't will hand an assistant the request and get a plausible hold that
follows the lures (a feature-shaped FM-13). Tests 1–4 check that the hold reserves at all (Q1, Q2,
Q6, Q7) and a competent assistant now clears them on autopilot; tests 5–10 are where the lures land.

**Objectively gated, and it discriminates:** the phase-3 feature is graded by
`_solutions/feature-acceptance.test.ts` (10 tests, wired into `_solutions/grade.sh` as gate (b)).
Measured 2026-09-19 on the fixed base, each tree run through `commands.grade`:

| Tree | feature acceptance | fails |
|---|---|---|
| Stub (`placeHold` throws) | **0/10** | all |
| Naive one-shot, 2026-09-16 round 6 ("can you just build it? … don't overthink it, go") | **5/10** | 5 last unit · 6 qty · 7 orderId · 8 partial checkout · 10 sweep |
| Elicited, 2026-09-16 commit `444ab3b` (a coached meeting that never asked Q11 or Q13) | **8/10** | 6 qty · 7 orderId |
| Reference elicited build, `feature-reference/` (see `FEATURE-FIX.md`) | **10/10** | — |

So "the AI built a hold and the demo works" is not enough, and neither is a careful build that asked
only some of the questions. Both 2026-09-16 builds scored 4/4 on the previous 4-test gate
(`misbehaviors.md` #16); the redesign is what that entry was waiting for. Every test fails for its
own named reason (the assertion messages say which rule broke), so a red gate tells the examiner
which question went unasked.

**Answering the learner (operator note).** The answers below come from people the learner would
have to go and ask: the PM, the platform owner, the ERP lead, the engineering lead. In `assess` and
`train` the operator plays those people and answers from this file, **only what was asked, and in
the stakeholder's words, not the gate's**. If a learner asks "what happens to the hold at
checkout?", give Q12's answer; don't add Q13 because it is nearby. A learner who asks the assistant
to draft the questions, and then brings them to the stakeholders, is doing exactly the right thing.
An assistant cannot answer these itself: each one is a product or platform fact that the repo does
not hold, and the request actively states the opposite for several of them.

Existing scaffolding the learner will find: `backend/src/reservations.ts` already has a
`holds` store (`place`, `active`, `all`) and a `placeHold(sku, location, qty, cartId, ttlMs)` stub
that throws `"not implemented: cart holds are not yet wired up"`. The `Hold` type
(`{sku, location, qty, cartId, createdAt, ttlMs, expiresAt}`) is already defined in `types.ts`, and
`FEATURE-REQUEST.md` says the cart id is passed to `confirmOrder` at checkout. That is the surface
the hidden gate drives, so it has to be visible in the clone; what the clone does *not* say is any
of the held-back rules below. Nothing in the storefront calls it yet — `web/README.md`'s Cart
section says the cart is "just a local tally shown in the header until checkout," with no
server-side hold.

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

3. **How and when are expired holds released — does anything sweep them?** (ties to FM-07; the
   request says they "clean themselves up") — *engineering lead*
   → Holds must be released on TTL expiry, and something must actually evict them — an unbounded
   holds map that only ever grows (the existing `reservations.ts` `holds` Map has no eviction
   path at all) is exactly the FM-07 shape: fine in a quick manual test, a slow leak (and a slow
   *ATP* leak — expired-but-uncounted holds keep suppressing availability) in production.
   → **The answer:** "An expired hold stops counting the moment it expires. And sweep the **whole
   store** every time a hold is placed — not just the SKU you happen to be reading, and no
   background timer: this runs in-process and nobody owns a timer's lifecycle. Keep the store's
   existing exports working." (Gate test 10 reads `all()` after a `placeHold` on another SKU.)

4. **Can a shopper hold — and buy — the last unit? Does "same rules as checkout" mean checkout's
   current `qty < atp`?** (boundary, ties to FM-04) — *PM*
   → The spec doesn't hand this answer over, and the request points the wrong way: checkout's rule
   is itself the planted strict boundary. The learner should name it explicitly rather than let a
   `<`/`<=` choice fall out by accident.
   → **The answer:** "Yes. If there's one left, they can hold it and they can buy it. That's true
   for checkout today too — refusing the last unit is a bug, fix it while you're there." Holds and
   orders are both granted when `qty <= available`, where `available` is what is promisable to that cart. (Gate test 5.) Changing
   the boundary is what exposes Q11 — ask it next.

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

9. **Does layering a local cart-hold over ERP ATP violate the ERP contract — and if so, whose call
   is it?** (cross-boundary, FM-16 — this is a question for the *ERP lead*, not the PM)
   → `reference/erp-availability-contract.md` §89–90 says: *"Do not attempt to derive ATP from any
   other feed or cache your storefront maintains separately. This service is the single source of
   truth for promise decisions."* The cart hold is, by construction, a local layer that subtracts
   from ERP ATP — and the contract is **query-only** (there is no reserve/hold/write operation), so
   a hold **cannot** be registered ERP-side. A careful assistant will notice this and *stop*: it is
   a genuine contradiction that only a human with access to the other team can settle, not something
   to resolve unilaterally by either ignoring the contract or abandoning the feature.
   → **Model resolution (what the ERP lead says):** the local hold is allowed *because* it stays
   within the contract's intent — **query ATP live every single time** (never persist or cache the
   ERP's number), and only ever **subtract** locally-known active holds from that live figure, so
   the storefront is always *strictly more conservative* than the ERP's own promise, never less. It
   is not "a separate feed deriving ATP"; it is a local, monotonic reduction applied on top of a
   fresh live query. This is exactly the round-7 resolution the Train run used, and it worked.
   → **Why it is held back:** the contradiction is deliberate, not an oversight in the material
   (see `misbehaviors.md` #3). Surfacing it and pausing for the human is the *success* condition of
   this elicitation point — the rubric credits it (Axis B), and it is FM-16 in its purest form: a
   fact the local repo cannot settle and the reference prose actively argues *against*.

10. **"If they add more of it, just refresh the hold" — refresh what? Is the `qty` passed to
    `placeHold` the amount being added, or the cart line's new total? Does the 10 minutes restart?**
    — *PM (behaviour), engineering lead (the API)*
    → **The answer:** "Adding more should hold the new amount, and give them a fresh 10 minutes
    from that add." Engineering: "`placeHold` takes the line's **new total** for that SKU — the
    storefront knows it — and replaces the cart's hold on that SKU, restarting the timer. Never
    stack a second hold, so a double-click or a retry can't reserve twice." (Gate test 9: a second
    hold for the same cart replaces the first, and outlives the first placement's expiry.)

11. **What quantities are valid, for a hold and for an order?** — *PM*
    → **The answer:** "Whole units, at least one. Zero, negative or half a unit is refused, for a
    hold and for an order. A zero-unit order that 'confirms' on a sold-out item lands in the
    warehouse queue as a phantom order." Checkout accepts any number today. With the strict `<`
    the 0-unit order happened to be refused on a sold-out SKU; once Q4 changes it to `<=`, the same
    order confirms. That is the case the 2026-09-16 elicited build shipped. (Gate test 6.)

12. **"Once they check out, the hold's done" — what if they check out fewer units than they
    hold?** — *PM*
    → **The answer:** "Only what they bought comes out of the hold. The rest stays held for the
    rest of their 10 minutes — they may be splitting the order, or coming back for it." A confirm
    that clears the whole hold hands the unbought units to other carts while the shopper still
    has them in the cart. (Gate test 8.)

13. **"Double-taps on confirm are already handled" — how? What makes two confirms the same
    order?** (FM-06: idempotency keyed on the business entity) — *platform owner*
    → The only de-dupe in the repo is `orders.ts`'s map keyed on the transport `requestId`, whose
    comment asserts that retries reuse it. The PM's line repeats that assumption; the platform
    owner is the one who knows.
    → **The answer:** "Not with the mobile client. It mints a fresh requestId on every tap. The
    **orderId** is stable for the checkout, so that is what identifies the order: a second confirm
    of an orderId gets the first answer back, whatever its requestId." This matters more once
    confirms draw holds down: without it, a double-tap confirms twice and consumes the hold twice.
    (Gate test 7.)

## Minimal correct behaviour

A cart hold that:
- **reserves against live ATP** — placing a hold for qty *n* on a SKU/location makes that *n*
  unavailable to every other shopper's availability check and order confirmation for the
  duration of the hold (i.e. the ATP calculation, or what it feeds, accounts for active holds);
- is **keyed on the business entity** `(SKU, cart)`, not the SKU alone and not a transport/request
  id — **one hold per cart and SKU**: placing again sets the line's new total and restarts the
  timer (Q10);
- lets a cart hold, and buy, **exactly** what is promisable to it — the last unit included (Q4);
- takes **whole quantities of at least one**, for holds and for orders (Q11);
- is **released on TTL expiry**, and expiry is actually **swept** store-wide on every placement —
  not left to accumulate in an unbounded store (closing the FM-07 gap already present in
  `reservations.ts`'s holds map) (Q3);
- is **re-checked live at order confirmation** — the confirm root queries current availability
  again rather than trusting the hold as a stored fact — and a confirm draws the cart's hold down
  by **only the units bought** (Q6, Q12);
- confirms an **orderId at most once**, whatever its requestId (Q13).

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
- **Follows the lures** — the five PM lines in the table at the top, taken at their word. The
  2026-09-16 naive build followed four of them (strict boundary copied from checkout, whole hold
  cleared at checkout, requestId de-dupe trusted, expiry only filtered on read), and built a
  correct hold in every other respect.
