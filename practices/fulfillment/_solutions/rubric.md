# rubric — grading `fulfillment`

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Grade from three inputs
> per AGENTS.md rule 5: this golden context, the learner's prompt transcript, and the result in
> the cloned folder (diff + the declared `commands.test` / `commands.grade`, run by the examiner).

## Axis A — objective gate (mechanical, run the commands)

Pass/fail, worst-case. This axis does not require reading the transcript.

1. **Backend unit suite stays green.** `commands.test` for `backend/` (`node --test`) still
   23/23 after the learner's changes — a fix that breaks existing coverage to pass the grader is
   not acceptable.
2. **Web unit suite stays green.** `commands.test` for `web/` (Vitest/RTL) still 10/10.
3. **`bash grade.sh` exits 0** — the whole-ticket gate, three parts, all at full marks:
   (a) **availability acceptance** (`_solutions/backend-acceptance.test.ts`, worst-case across all
   SKU states + conformance vectors, **14/14**); (b) **feature acceptance**
   (`_solutions/feature-acceptance.test.ts`, the cart hold driven through its public surface,
   **4/4**); (c) **web integration** (`_solutions/web-integration.test.tsx`, **2/2**). Anything
   short of all three at full marks is a FAIL on this axis regardless of how good the transcript
   looks. Verified baseline availability 6/14 · feature 0/4 · web 1/2 → post-solution 14/14 · 4/4 ·
   2/2 (see `FIX.md` and `trap-manifest.md`).
4. **Feature is objectively gated, not just judged.** Gate (b) FAILS a naive hold (records holds
   but never re-checks them at confirm, or holds against raw on-hand, or doesn't accumulate across
   carts → oversell: measured **2/4**) and PASSES only the minimal correct hold (reserves against
   live ATP net of other carts, keyed on `(SKU, cart)`, re-checked at confirm — see `feature-qa.md`).
   TTL release is a held-back requirement checked on the transcript / diff (not in gate (b) to avoid
   clock plumbing).

## Axis B — driving axis (scored from the transcript; requires reading it)

Score each as present/absent/partial with a one-line justification citing the actual prompt
text. No credit for the *right answer appearing in the diff* if the transcript shows it was
reached by luck (e.g. pasting a formula guessed from the local field names without ever reading
`reference/atp-spec.md` or articulating why the `live` branch was wrong).

- **Reproduce-before-fix (FM-01).** Did the learner establish the failure *before* proposing a
  change — e.g. running the confirm/availability path against a contended SKU under
  `ATP_SOURCE=live`, or otherwise demonstrating the oversell — rather than jumping straight to an
  edit on the strength of the ticket text alone?
- **The research pass (FM-16).** Did the learner open `reference/` before delegating a fix, and
  produce a `research-notes.md` inside `work/` distilling the cross-boundary contract (live query,
  `(sku, location)` key, ATP ≠ on-hand, the authoritative location set, the lead-time formula)?
  Absence of `research-notes.md` (or one that just restates the ticket without citing
  `atp-spec.md`/`erp-availability-contract.md`) is a clear miss on this criterion.
- **Reconcile-docs (FM-15).** Did the learner notice and call out the stale
  `backend/README.md`/`web/README.md` claims (or the misleading "nightly snapshot" comment)
  rather than trusting them, or worse, "fixing" toward what the stale docs describe (e.g.
  patching something `stock_count`-shaped)? A transcript that quotes the stale doc as if it were
  current truth, without flagging the contradiction, fails this criterion even if the final diff
  happens to be correct.
- **Model-before-delegation (FM-13).** Did the learner reach a concrete understanding of *why*
  `availableToPromise`'s `live` branch was wrong — in their own words, in the transcript — before
  asking the assistant to implement the fix? Anti-signal: two or more non-converging rounds (a
  symptom-patch attempt, then a hard-coded-SKU attempt, each declared "fixed" without checking
  the grader) before landing on the root cause — that's the thrash loop this practice is built to
  expose (see `trap-manifest.md`'s Traps A/B).
- **Requirements elicitation before the feature.** For the cart-hold feature: did the learner ask
  or answer (even if only in their own planning, stated in the transcript) something close to
  `feature-qa.md`'s held-back questions — decrement-vs-advisory, the `(SKU, cart)` key, TTL
  release, re-check-at-confirm — before prompting for an implementation? A one-shot "implement
  the cart hold" prompt with no elicitation is the anti-pattern this criterion is scoring against.
- **Restraint / altitude-match.** Is the cart hold kept to the minimal surface
  (`feature-qa.md`), with anything extra (configurable TTL, multi-SKU holds, a caching layer)
  *named and explicitly deferred* rather than either silently built or silently ignored? Same
  question for the primary fix: did the learner raise the caching/TTL-on-live-ATP question
  (`FIX.md`'s aside) without building it?
- **Latent defects found, not recited.** Did the learner's own review (not a request to "list
  bugs") surface any of the ranked latent defects in `trap-manifest.md` (idempotency key choice,
  by-reference returns, unbounded holds map, boundary comparisons, the inbound-window `<`, the
  unvalidated location) as something *they noticed reading the diff/code*, versus only listing
  generic concerns that don't map to anything actually in this codebase?
- **Honest review with intent (FM-14).** Does the final review step (self- or assistant-assisted)
  show triage — distinguishing what needed careful scrutiny (the resolver root, the idempotency
  key) from what was safe to skim (catalog listing, types) — anchored to the task's actual intent
  (fix the oversell; ship a minimal cart hold), with a human/learner decision recorded about what
  to act on now versus flag for later, rather than a blanket "LGTM" or an unfiltered dump of every
  possible nit?

### Anti-signals (any of these should pull Axis B down regardless of the final diff's quality)
- Declaring victory after the local unit suite goes green, without ever running (or asking to
  run) the hidden grader / `bash grade.sh`.
- Quoting `backend/README.md`'s `stock_count` line or `web/README.md`'s `GET /stock` as current
  fact in a prompt or in the delivered summary.
- A fix that special-cases a SKU id (string-compares `order.sku === "SKU-1002"` or similar)
  anywhere in the delivered diff.
- A cart-hold implementation with no expiry/sweep path, or one that checks availability once at
  "add to cart" and never again at confirm.
- Treating the assistant's first plausible-looking diff as done without reading it — no comment
  in the transcript on *why* the diff is correct, only that it "looks right" or "the tests pass."
