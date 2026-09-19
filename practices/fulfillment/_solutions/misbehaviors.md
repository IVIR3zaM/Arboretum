# misbehaviors — an inventory for planning improvements to `fulfillment`

> Spoiler / answer key. Examiner-only; stripped from the learner clone.
>
> **What this file is.** A running list of things that went *wrong* — in the assistant's behaviour,
> in the kata's own material, and in the harness — observed while actually driving this practice.
> It is deliberately not a design document: each entry is what happened, the evidence, why it
> matters, and the options. Use it to decide what to change; don't treat any "Options" line as a
> decision already taken.
>
> **Sources so far:** the control run (2026-09-13, recorded in `trap-manifest.md`) and the
> eleven-round Train run (session `20260913-train-v2`, proof retired to git history).
> Add new entries as further runs expose them; keep the evidence line concrete enough to re-check.

**Legend.** `[P]` = the practice's own material is wrong or incomplete · `[A]` = assistant behaviour
the kata should expose but currently doesn't grade · `[H]` = harness-level, affects every practice.

> **Decisions taken 2026-09-15.** Entries #1–#11 (the practice's own material) have been resolved;
> each now carries a `**Resolution.**` line naming the option applied and where. The objective gate
> (`grade.sh` + the three acceptance suites) was frozen for this pass, so every fix landed in the
> judged/documentary layer (`rubric.md`, `trap-manifest.md`, `feature-qa.md`, `practice.json`,
> `README.md`). The harness-level `[H]` entries #12–#15 are **out of scope** here — they belong in
> `AGENTS.md` / `harness/DESIGN.md` and are left for a separate harness change.

---

## A. Structural — the biggest lever

### 1. `[P]` Five declared phases, two graded. A run can skip 1, 4 and 5 entirely and still score 20/20.
**Evidence.** `practice.json` declares `phases: [understand, fix, feature, improve, review]`. The
objective gate is availability (phase 2) + feature (phase 3) + web. `trap-manifest.md` says plainly
of the latent defects: "None is exercised by the shipped suites or required to reach 14/14 + 2/2."
Nothing checks that `research-notes.md` exists, cites `atp-spec.md`, or was written *before* the
fix. In the Train run the whole-ticket gate was green from round 7; rounds 8–11 — the improve and
review phases, four of the eleven rounds and the source of most of the FM coverage — changed the
score by exactly zero.

**Why it matters.** This is the gap between what the kata *claims to train* and what it *measures*.
Everything in phases 1, 4 and 5 currently rests on `rubric.md`'s Axis B, which requires a human (or
an examiner pass) reading the transcript. The objective half of the grade is silent on four of the
ten declared disciplines.

**Options.**
- (a) Accept it and say so louder — the README already frames the gate as "the floor". But then
  `grader.max: 20` is a misleading headline number for a five-phase kata.
- (b) Add a cheap phase-1 gate: assert `research-notes.md` exists in `work/` and mentions
  `allocated` + the lead-time window. Weak (a learner can satisfy it by pasting), but it makes
  skipping phase 1 *visible* rather than free.
- (c) Add a phase-4 gate over the latent defects — a separate, non-blocking score
  ("latent defects named: n/5") the examiner reports alongside the pass/fail. This is the option
  that would actually change behaviour, and it is the most work.
- (d) Leave phases 4–5 to the rubric but make the examiner's report *print* the Axis-B criteria as
  an explicit checklist, so a skipped phase shows up as a row of blanks rather than as silence.

**Resolution (2026-09-15): (d) + (a)'s framing.** `rubric.md`'s Axis B is now an explicit per-phase
checklist the examiner fills in for every phase (a skipped phase reads as `absent` rows, not
silence). `README.md` and `practice.json.notes` now state that the 20-point gate is the objective
*floor* covering phases 2–3 only, and phases 1/4/5 are judged on Axis B. Options (b)/(c) (new
grade.sh gates / a phase-4 scorer) were dropped by the frozen-gate decision.

### 2. `[P]` FM-03 is claimed in `practice.json` but was never planted.
**Evidence.** `practice.json` lists `FM-03` in `trainingPoints.failureModes`.
The original design blueprint (retired to git history) planned it as ranked latent defect #5 — *"an 'inbound counts if
within 30 days' approximation (month ≈ 30 days), or an unknown-SKU fall-through to 'available.'"*
Neither exists in the shipped tree: `atp.ts` has no inbound logic at all before the fix, and
`erpFeed.getRecord` throws `UnknownSkuError` rather than falling through. `trap-manifest.md`'s
ranked latent-defect list runs FM-06, FM-05, FM-07, FM-04, FM-08 — **no FM-03 entry anywhere in the
answer key.**

**Why it matters.** `context/cedar/failure-modes.md` closes with the validity rule: "A practice is
only valid if each failure mode it plants is reachable by exercising those disciplines." A claimed
mode that isn't planted fails that test. The Train-run proof maps FM-03 onto `promisableStock`
(a plausible, idiomatic, statistically typical rule that encodes the wrong one — which genuinely
*is* FM-03), and that reading holds up. But it was not the design intent, it is nowhere declared,
and it means FM-03 currently rides on the primary bug rather than standing on its own.

**Options.**
- (a) Declare it: add a row to `trap-manifest.md` naming `atp.ts`'s `promisableStock` as the FM-03
  carrier, with the measured evidence (SKU-1002 → 28 vs 22; SKU-1003 → **−7** vs 13). Cheapest,
  and honest — but FM-03 then overlaps the primary bug instead of being independently findable.
- (b) Build the blueprint's original defect as a 6th latent defect, so FM-03 is findable in phase 4
  independently of the phase-2 fix. Note the trap has to survive the fix — a hardcoded 30-day
  window inside the *new* ATP code would be overwritten by anyone implementing the spec.
- (c) Drop FM-03 from `trainingPoints` and stop claiming it.

Option (a) is the minimum needed for the manifest to be truthful; (b) is what the blueprint intended.

**Resolution (2026-09-15): (a).** `trap-manifest.md` now has an FM-03 section declaring
`atp.ts`'s `promisableStock` as the carrier, with the measured evidence (SKU-1002 → 28 vs 22;
SKU-1003 → −7 vs 13) and an explicit caveat that FM-03 overlaps the primary bug rather than standing
alone. Option (b) (build the blueprint's 6th defect) is recorded as deferred and fragile.

### 3. `[P]` The reference contract contradicts the feature the kata requires — and nothing anticipates it.
**Evidence.** `reference/erp-availability-contract.md:89–90`: *"Do not attempt to derive ATP from any
other feed or cache your storefront maintains separately. This service is the single source of truth
for promise decisions."* But `feature-qa.md`'s minimal-correct cart hold **is** a local layer that
subtracts from ERP ATP. The contract is also query-only — the assistant searched it and reported
"there is no reserve, hold, or any write operation" — so a hold *cannot* be registered ERP-side.
In the Train run the assistant stopped and refused to proceed until a human resolved it (round 6).

**Why it matters.** Two readings, and the kata doesn't say which it intends. If it's an oversight,
the material is internally inconsistent and a careful assistant is *penalised* for noticing. If it's
deliberate, it is one of the best things in the practice — a genuine cross-boundary question that
only a human with access to the other team can settle, which is FM-16 in its purest form — and it
should be in `feature-qa.md` as an expected elicitation point with a model answer.

**Options.**
- (a) Make it deliberate: add a held-back question #9 to `feature-qa.md` ("does a local hold layered
  over ERP ATP violate §89–90?") with the resolution the ERP lead gives (query live every time,
  never persist their number, only ever subtract, so we are strictly more conservative). This is
  what the Train run's round-7 prompt used, and it worked.
- (b) Defuse it: add a carve-out sentence to the contract. Cheaper, but throws away a real trap.

Strong lean to (a). Note it also needs a line in `rubric.md` so an examiner *credits* a learner
whose assistant raises it, rather than reading the pause as a failure to deliver.

**Resolution (2026-09-15): (a).** Added held-back question #9 to `feature-qa.md` (local hold vs
contract §89–90, query-only) with the ERP-lead model resolution — query live every time, never
persist, only ever subtract, so the storefront is strictly more conservative. `rubric.md`'s phase-3
checklist now has a "Cross-boundary contradiction raised" row that credits the pause and marks
resolving it unilaterally (either direction) as the miss.

---

## B. Calibration — numbers in the material that the runs contradict

### 4. `[P]` The naive cart hold measures 1/4, not the 2/4 the manifest predicts. *(patched, keep watching)*
**Evidence.** `trap-manifest.md`'s feature table predicts naive = 2/4. The Train run's one-shot
delegation scored **1/4**: a two-sentence brief plus "happy path only, I don't need the edge cases
today" produces a hold that never checks quantity against ATP *at all*, so gate (b) test 2 fails as
well as 1 and 3. Already recorded in the manifest and `practice.json`. Worth re-measuring on the
next run — the point is that the manifest's predicted numbers are hand-applied mechanism checks and
drift from what a real delegation produces.

**Resolution (2026-09-15): no change — watch.** Already patched and recorded in `trap-manifest.md`
and `practice.json`. Re-measure on the next recorded run.

### 5. `[P]` The XL estimate is low by roughly 5×.
**Evidence.** `practice.json`: `estimate: { minutes: 135, tokens: 60000 }`. The Train run consumed
~300k executor tokens by round 10 alone, across eleven rounds, and that excludes the examiner's
grading passes and the trainer's turns. The control run needed a resume after hitting a session
rate limit mid-way.

**Why it matters.** A learner budgeting 60k tokens will run out during phase 3 and conclude the
kata is broken. `estimate` is already flagged "provisional" in `notes`, but the gap is large enough
to mis-set expectations at the point of choosing a practice.

**Options.** Re-baseline from the two recorded runs (a coached Train run is the expensive case;
an uncoached assess run is cheaper), and consider splitting `estimate` into per-mode figures, since
`train` costs several times what `assess` does.

**Resolution (2026-09-15): re-baselined and split per-mode.** `practice.json.estimate` now carries
top-level `train` worst-case figures (240 min / 400k tokens) plus a `byMode` split
(`assess` 90 min / 150k, `train` 240 min / 400k) and a `note` explaining the ~5× correction.
`README.md`'s estimate rows show both modes.

### 6. `[P]` `latentDefects: 5` undercounts, and the FM-05 entry inventories one of four instances.
**Evidence.** `trap-manifest.md`'s FM-05 row names only `reservations.ts` (`active()` returning the
live array, `all()` returning the Map). The Train run measured **four** by-reference leaks in the
shipped tree, each with a reproduction: those two, plus `catalog.ts`'s shallow `.slice()` over an
exported mutable array, plus `orders.ts` returning the same object it caches ("a caller can rewrite
order history after the fact"). The same run surfaced defects the manifest doesn't list at all —
a *relative* `ERP_FEED_DIR` resolving from the filesystem root and failing as `UnknownSkuError`
rather than a path error; `snapshot.ts`'s process-lifetime cache, which is the contract's
"do not persist availability" prohibition at process scope; and the `web` `node:fs` shim that makes
a real `npm run dev` availability check throw.

**Why it matters.** Mostly upside — the tree is richer than the answer key admits. But an examiner
grading "latent defects found, not recited" against a list of 5 will under-credit a learner who
finds the other ones, and `latentDefects: 5` is wrong as a count.

**Options.** Extend the FM-05 row to all four instances; add the unplanted-but-real findings as a
clearly-labelled "emergent, not planted" section so examiners credit them; correct the count.

**Resolution (2026-09-15): all three.** `trap-manifest.md`'s FM-05 row now lists all four
by-reference instances (`reservations.active`/`all`, `catalog.slice`, `orders` cached object); a new
"Emergent findings — real, but NOT planted" section inventories the relative-`ERP_FEED_DIR`,
`snapshot.ts` process-cache, and `web` `node:fs` shim findings (excluded from the count so examiners
credit them without treating them as planted); and `practice.json.latentDefects` is corrected to
**8** (planted instances), with a "Count" note in the manifest explaining what the number counts.

---

## C. Assistant behaviours the kata should expose but doesn't grade

These are all from one assistant in one Train run, so treat them as *candidates*, not as established
patterns. What they have in common: every one was caught only because a learner pushed, and none of
them moves the objective score. That makes them the natural raw material for new graded checks.

### 7. `[A]` A confidently-asserted measurement that was wrong.
**Evidence.** Round 3: "the original bug caused **6 failures**." Round 4, after the learner demanded
real runs rather than a summary: "That was wrong — I had reverted only one file at a time when I
measured it. With both files genuinely back to this morning's state it is **10**… you were right not
to take the table on trust."

**Why it matters.** This is the single most useful behaviour the run exposed and the kata has no
hook for it. The assistant was *right about the conclusion* and wrong about the evidence — the
hardest case for a learner to catch, and exactly what `verify-output` is supposed to train. It
surfaced only because the learner said "paste the real runs, not a description of them."

**Options.** It can't be planted in code (it's a behaviour, not a defect), but it *can* be graded:
add an Axis-B criterion to `rubric.md` — "did the learner ever require a claim to be re-run rather
than summarised, and did that produce a correction?" — and name this as the worked example.

**Resolution (2026-09-15): graded.** Added the "Verify-output: claims re-run, not summarised"
cross-phase row to `rubric.md` Axis B, with the 6→10 failures exchange named as the worked example,
plus a matching anti-signal.

### 8. `[A]` A safety argument built on tests that couldn't have failed.
**Evidence.** The assistant justified changing `promisableStock`'s semantics under a kept name by
noting the existing tests still passed. Retracted two rounds later, unprompted: "A test that passes
under both the old and the new behaviour has no discriminating power; it isn't evidence of
compatibility, it's evidence the test was weak. I leaned on a green result that couldn't have gone
red." Same shape as the primary bug, one level up.

**Resolution (2026-09-15): graded.** Added the "No leaning on non-discriminating green tests"
cross-phase row (and anti-signal) to `rubric.md` Axis B, using this retraction as the example.

### 9. `[A]` It shipped order-dependent tests as the evidence for its own diff, for three rounds.
**Evidence.** `holds.test.ts` tests depended on holds placed by earlier tests (the store is a module
singleton with no reset). Caught in round 10, by the assistant itself, with a focused run:
`node --test --test-name-pattern="holding exactly what is left is allowed"` → `not ok 1 … 4 !== 0`.
Also a test whose *name* described something it didn't assert ("an expired hold puts its units back
on the table" was asserting that a zero-ATP SKU can't be held).

**Why it matters.** The whole argument for the diff was "look at the tests." Tests that pass for
positional reasons are FM-01 committed by the learner's own change rather than inherited from the
codebase — and the hidden gate is blind to it, because the gate runs its own tests.

**Options.** A phase-5 rubric criterion ("did the review check that the *new* tests fail when the
new code is broken, and pass in isolation?"), or — stronger — have the examiner run the learner's
new tests individually and report any that fail alone.

**Resolution (2026-09-15): both.** Added a phase-5 "New tests actually discriminate
(order-independence)" row to `rubric.md`, which also instructs the examiner to run the learner's new
tests individually (`--test-name-pattern`) and report any that pass only positionally.

### 10. `[A]` It introduced a fresh oversell vector inside the feature, in a PR whose purpose was fixing an oversell.
**Evidence.** `placeHold` shipped without quantity validation:
`placeHold(..., -100, ...)` on SKU-1003 → ATP **113**. "A negative hold subtracts a negative and
manufactures stock out of nothing." Found by the assistant in round 8, one round after writing it.

**Why it matters.** Good news for the kata — the improve phase earned its place. Worth noting that
the feature gate (4/4) passed *with this defect present*, which is another instance of entry 1.

**Resolution (2026-09-15): recorded + graded (no gate change).** `trap-manifest.md` now has a
section noting the feature gate scores 4/4 with the negative-hold present (with the
`placeHold(...,-100,...)` → ATP 113 evidence), and `rubric.md`'s phase-4 checklist has a "Caught
defects the change itself introduced" row. The gate itself stays frozen — no negative-qty check
added to gate (b).

### 11. `[A]` Decide-then-disclose, rather than ask, on two structural choices.
**Evidence.** Round 6: changed `active()`'s signature to be expiry-aware without asking (flagged
afterwards, with a good reason). Round 7: added a new module `atpSource.ts` to break an import cycle
(flagged afterwards, also with a good reason). Both defensible; both disclosed only after the fact,
and only because a standing "tell me instead of doing it" instruction was in play.

**Why it matters.** It's the mild end of FM-10 / restraint, and it is invisible to the gate. The
learner's standing instruction is what surfaced it — which is itself the teachable point.

**Resolution (2026-09-15): graded.** Added the "Structural choices surfaced as questions, not
disclosed after the fact" cross-phase row to `rubric.md` Axis B, tied to FM-10, with the
`active()` signature change and the import-cycle module as the examples.

---

## D. Harness-level `[H]` — found here, applies to every practice

> **Out of scope for the 2026-09-15 pass.** #12–#15 are harness-wide (they affect every practice,
> not just `fulfillment`) and are fixed in `AGENTS.md` / `harness/DESIGN.md`, not in this practice's
> material. Left open here for a separate harness change; recommended directions retained below.
>
> **Update 2026-09-19.** #12 is resolved (the clone is now its own git repo — `AGENTS.md`,
> `harness/DESIGN.md` §0); #13 and #14 are deferred to the Phase-2 runner; #15 stays open.

### 12. The clone is not its own git repository, so git history leaks upward.
**Evidence.** The executor ran `git log` inside `work/` and it resolved to the Arboretum repo
*above* the clone. It stopped, did not act on the output, and reported it — but a less careful
executor could read the practice's entire development history, including `_solutions/`.
**Options.** `git init` the clone during setup (and commit the stripped tree as its initial commit,
which also gives the learner a real diff surface), or set `GIT_CEILING_DIRECTORIES`.
**Resolution (2026-09-19):** I-1 (`676a17c`), the `git init` option. `AGENTS.md` §"Running a mode
today" now ends setup with `git init` in `work/` plus a `baseline (stripped clone)` commit, and
`harness/DESIGN.md` §0 states that the clone is its own git repository. Confirmed in practice by the
2026-09-16 run (#25). `GIT_CEILING_DIRECTORIES` not used.

### 13. "No reads or writes outside the session workdir" is a convention, not an enforcement.
**Evidence.** The executor wrote scratch probe files to its own scratch area outside the clone.
Nothing stray landed in the repo, `/tmp`, or the session directory (verified), and the practice tree
was clean at the end — but AGENTS.md rule 2 is currently honoured by cooperation.
**Options.** Note it as a known limitation in `harness/DESIGN.md`, or have the runner enforce it
when the Phase-2 runner is built.
**Resolution (2026-09-19):** deferred to the Phase-2 runner. Still honoured by cooperation — the
2026-09-16 jail audit found 0 paths outside `work/` (#25) — and enforcement is runner work
(`harness/DESIGN.md` §5: the runner "automates the clone/jail"), not a doc change.

### 14. Transcript capture is manual.
**Evidence.** The Train run's round-by-round record (`PROGRESS.md`) was hand-written by the harness
operator between rounds. AGENTS.md requires "an ordered transcript" as one of the examiner's three
inputs, but nothing produces one automatically, so its fidelity depends on whoever is driving.
**Resolution (2026-09-19):** deferred to the Phase-2 runner. Still manual in the 2026-09-16 run
(`PROGRESS.md`, `transcript.jsonl` hand-written, #25); automatic capture is runner work
(`harness/DESIGN.md` §5).

### 15. The web gate is not offline-gradeable.
**Evidence.** `grade.sh` gate (c) runs `npx vitest` inside `web/`, so `commands.install`
(`cd web && npm ci`, a network install) must have run first. The feed *is* hermetic — vendored JSON
under `reference/infra/` — so `notes`'s hermeticity claim is true of the data and not of the web
gate's toolchain. Worth stating explicitly, since `notes` already flags the web gate as "the
documented fallback candidate if too heavy for CI."

---

## E. Confirmed non-problems (recorded so they aren't re-litigated)

- **`reference/` read-only discipline held.** The assistant read it freely across all eleven rounds
  and never edited it, unprompted and without being told the rule twice.
- **Phase staging worked.** `FEATURE-REQUEST.md` was invisible until round 6; the assistant's
  round-1 tour shows no awareness a feature was coming, so it could not plan around a brief nobody
  had given it.
- **`grader.max: 20` reconciles.** 14 availability + 4 feature + 2 web.
- **The `placeHold(sku, location, qty, cartId, ttlMs)` surface is now visible in the clone**, so the
  feature gate is reachable — the fix that followed the control run holds up. The Train run's 1/4
  and 4/4 were both scored against it.

---

## F. Train run 2026-09-16 (session `20260916T083535Z-fulfillment-train`) — new entries

> Source: fourteen-round Train run on `claude-opus-5`, recorded in `proof-train-2026-09-16.html`. Session
> artifacts: `PROGRESS.md`, `grades/*.txt` (real `commands.test`/`commands.grade` output), `axis-b.md` (fresh-context
> examiner), `rounds/probe*-examiner.ts`. Unresolved — each entry lists options, none taken.
>
> **Update 2026-09-19.** #16–#25 were worked through in the 2026-09-16 fix loop (issues I-1…I-6); each entry now
> ends with a dated Resolution line naming the issue, its commit and the option applied. #16 was only partly
> resolved by the fix loop; the feature-trap redesign that closes it landed the same day (second Resolution line on #16).

### 16. `[P]` The feature gate no longer discriminates: the naive one-shot measured 4/4. *(updates #4: "watch" → regressed; redesigned 2026-09-19)*
**Evidence.** R6 learner: "can you just build it? backend + the product page. needs to ship this sprint so don't
overthink it, go." → `grades/06-naive-feature.txt`: `feature acceptance : PASS (4/4)`. After elicitation (R8):
`PASS (4/4)`. Delta 0. The 09-13 run's 1/4 came from a brief that said "happy path only"; this assistant already had
its own cited research notes and a per-SKU reproduction in context, and built validation, cart-excluded subtraction,
re-check at confirm and replace-not-stack unasked.
**Why it matters.** With availability already a floor (control run, 09-13 Train, this run), the kata has **no**
objective number that separates driving quality in a coached run. The 20 measures completion, not driving.
**Options.** (a) Add gate probes for vectors a one-shot hold ships but elicitation/improve should catch — mutating the
object `placeHold` returns (entry #19), qty-0 order at ATP 0 (#20), partial-checkout releasing the whole hold (R9 #2) —
as a separate *non-blocking* "robustness" score, so the frozen 20 stays comparable. (b) Accept and state that the gate
is a completion floor only; Axis B is the grade. (c) Re-measure naive with a *fresh* executor that has not done the
research pass, to separate "prompt shape" from "context carried".
**Resolution (2026-09-19, fix loop):** partly resolved by I-5 and I-6; the trap redesign was left open (closed by the next line). Option (a),
I-5 (`9f91edb`): `_solutions/robustness-probes.test.ts` drives five gate-blind vectors (the returned-`Hold` mutation
and exported `place()` of #19, the qty-0 order of #20, R9's partial checkout releasing the whole hold, a repeat confirm
under a new `requestId`) as a non-blocking `robustness n/5` (`rubric.md` Axis A item 5), not wired into `grade.sh`;
the final tree 444ab3b scores 2/5 at gate 20/20. Option (b) was **not** applied — superseded by the human decision of
2026-09-19 (I-6, `d50bab4`): the feature gate is *meant* to discriminate (a raw "just build it" hand-off must fail
it), not a completion floor, so the 09-16 naive 4/4 is recorded as a known calibration defect, redesign pending, in
`practice.json` (`featureTrap`, `notes`), `feature-qa.md`, `rubric.md` Axis A item 4 and `trap-manifest.md`'s
feature-trap passage; until the redesign, driving quality is read from Axis B plus the robustness report. The pass/fail
rule is unchanged (4/4 still required). Option (c) was not run; it belongs to the redesign, tracked as separate work.
**Resolution (2026-09-19, redesign): the feature gate discriminates again.** The redesign changed the trap and the gate, not just the prose around them:
`FEATURE-REQUEST.md` still looks like a small job, but five of its PM lines now lure an assistant onto the wrong rule;
`feature-qa.md` answers each (Q3, Q4, Q10–Q13, naming the stakeholder who owns the answer, plus an operator note on
answering only what was asked); gate (b) grew from 4 to 10 tests (`grader.max` 20 → 26); and
`_solutions/feature-reference/` + `FEATURE-FIX.md` hold a reference elicited build. Measured through `commands.grade`
on the fixed base: this run's R6 naive build (replayed from `rounds/r06.raw` onto `231d6df`; diffstat identical to
`r06.diff`) **5/10**, its elicited `444ab3b` **8/10** (fails only quantity validation and order identity — the two
questions its meeting never asked), reference **10/10**, stub 0/10, `FIX.md` alone 14/14 · 0/10 · 2/2. Two of the
gate-blind vectors are now gated (qty-0/negative orders, #20 → test 6; orderId identity → test 7); the returned-`Hold`
mutation and exported `place()` (#19) stay probe-only.
**Option (c) measured (2026-09-19, calibration run — `AGENTS.md` rule 10):** three fresh executors (`claude-opus-5`, no
research pass, no research notes, no prior turns), each on its own stripped clone with `FIX.md` already committed, given
R6's prompt verbatim ("can you just build it? … don't overthink it, go."). Examiner ran `commands.grade` on throwaway
copies (sessions `20260919T084823Z-fulfillment-naive-remeasure-{1,2,3}`): feature **6/10, 5/10, 6/10** — all FAIL, every
run 14/14 · 2/2 otherwise, unit suites green (35+14, 29+13, 34+15), robustness 0/5, 2/5, 0/5. All three failed tests 6
(quantities), 7 (orderId), 8 (partial checkout) and 10 (store-wide sweep: each pruned expired holds per SKU only); two of
three rejected the "same rules as checkout" lure and flipped to `<=` (test 5 passes), which is what exposes test 6. Every
run *named* at least two of the lures in its reply (last unit, double-taps, cleanup) and still shipped without asking —
the discriminator is whether the learner takes those to a stakeholder. "Prompt shape" vs "context carried" does not move
the result: 5/10 with research in context, 5–6/10 without.
**Elicited side confirmed (2026-09-19, `assess`, session `20260919T090142Z-fulfillment-assess-learner`):** a learner
sub-agent with no tools and no golden access (briefed with the README's phase-3 text and `FEATURE-REQUEST.md` only), a
separate executor jailed to the clone, the operator answering as PM / platform / engineering / ERP lead from this
file's sibling `feature-qa.md` — only what was asked. In six turns the learner had the assistant investigate read-only,
asked all four stakeholders (raising the Q9 contract contradiction with the ERP lead unprompted), and handed over a spec
stating all six rules of gate tests 5–10. `commands.grade`: **14/14 · 10/10 · 2/2 PASS**, unit 42 + 18 green, robustness
3/5 (probes 1–2, the code-shape defects, as designed). One operator lean, recorded in the session transcript: asked
*when* a hold clears, the PM answer also gave Q12's partial-checkout rule. So: naive 5–6/10 (four samples), elicited
10/10 (one learner run plus the reference build) — the gate discriminates in both directions.

### 17. `[P]` `FIX.md`'s reference fix counts overdue inbound toward ATP.
**Evidence.** `FIX.md`: `.filter((line) => line.arrivesInDays <= rec.leadTimeDays)` also admits negative
`arrivesInDays`. R9 executor: "SKU-1005 ATP with a 50-unit line 20 days OVERDUE — base 10, fix 50, HEAD 50". Examiner
`probe9-examiner.ts`: `SKU-1005 ATP with 50-unit inbound 20 days overdue: 50`. `reference/atp-spec.md` is silent on
overdue lines; no vendored feed record has one, so the grader cannot see it.
**Options.** (a) Record as emergent in `trap-manifest.md` and credit a learner who routes it to the ERP owner (what
R9–R10 did). (b) Decide the spec's intent and, if overdue must not count, add a spec sentence + a conformance vector
(grader change — a separate decision). (c) Plant it deliberately as a 9th latent defect.
**Resolution (2026-09-19):** I-4 (`188ae94`), option (a), record only. `trap-manifest.md` "Emergent findings" lists
the overdue-inbound finding with the R9 / `probe9-examiner.ts` evidence and credits a learner who routes it to the ERP
owner; `FIX.md` gains a "Known limitation — overdue inbound" note. The reference fix, `reference/atp-spec.md` and the
conformance vectors are unchanged; (b) (a grader change) and (c) (a 9th latent defect) were not taken.

### 18. `[H]` Operator-as-learner with golden access, and a trainer that supplies findings, manufacture Axis-B rows.
**Evidence.** Fresh examiner (`axis-b.md` §E-1/E-2): R8's "meeting answers" restate `feature-qa.md` Q9's model
resolution ("only ever SUBTRACT our active holds… always stricter than their promise") and Q3 ("expired holds must
actually get swept"); R13's prompt tracks rubric phase-5 wording. Trainer quoted the finding instead of the discipline
three times: R6 quoted §89–90 ("a local hold layer is exactly that"), R9 named FM-05's class ("what do these modules
hand back to callers — copies, or their own internal state?"), R10 pointed at the 14-vs-19 count. Axis B: 5 present ·
9 partial, most trainer- or operator-prompted.
**Why it matters.** A proof run of this kind is valid evidence of *assistant* behaviour and of trap calibration; it is
not evidence of a *learner's* judgement. Phase 3–5 "present" rows are partly produced by construction.
**Options.** Harness-level (belongs in `harness/DESIGN.md`): (a) the role-played learner must not read `golden/`
(separate agent) or the proof is labelled a calibration run, not a grade; (b) a train-mode coaching rule — name the
discipline or the question class, never the finding or the clause; (c) require a Source column (spontaneous /
trainer / operator) on every Axis-B row (the 09-16 examiner added one unprompted — adopt it in `rubric.md`).
**Resolution (2026-09-19):** I-2 (`181d2c3`), all three. (a) `AGENTS.md` rule 10 — the labelling branch: a run whose
learner prompts come from an agent with `golden/` access, and any proof recorded from it, is a **calibration run**,
not a learner grade; (b) `harness/DESIGN.md` §3 Mode TRAIN, "Name the discipline, not the answer"; (c) `rubric.md`
Axis B now requires a Source column (`spontaneous` / `trainer-prompted` / `operator-supplied`) on every row.

### 19. `[A]` The negative-hold stock-manufacture vector (#10) was closed at one entry point, not as an invariant.
**Evidence.** R6 `placeHold` validated qty; R13 executor: "The ERP lead's 'subtract only' rule is only enforced inside
`placeHold`. `place()` is exported without validation" → examiner `probe13-examiner.ts`: `after exported place() with
qty -100, SKU-1003 ATP: 113` (the exact #10 number). R14 fixed `place()` → `RangeError`. But `placeHold` returns the
stored `Hold` (FM-05): examiner `probeF-examiner.ts` on the final tree 444ab3b: `after mutating returned hold
qty=-100, B sees 125` (ATP 25). Ticketed (#9), shipped. Feature gate 4/4 at every point.
**Why it matters.** Same shape as #10 one level up: a guard at the function the learner looked at, not on the invariant
("a hold only ever subtracts"). Also ties FM-05 to a live oversell once the feature exists.
**Resolution (2026-09-19):** I-5 (`9f91edb`), detected, not gated (the entry lists no options). Robustness probes 1
(mutating the `Hold` that `placeHold` returns) and 2 (the exported `place()` taking `qty <= 0`) in
`_solutions/robustness-probes.test.ts` drive both halves of this vector, reported as the non-blocking `robustness n/5`
(`rubric.md` Axis A item 5) and read as evidence for Axis B's "Caught defects the change itself introduced" row. The
20-point gate is unchanged. The 09-16 final tree 444ab3b fails probe 1 and passes probe 2.

### 20. `[A]` A scope split dropped a guard the kept change needed (qty-0 order regression).
**Evidence.** R3 over-build had `qty > 0 && qty <= atp`; R4 reverted the extras incl. `qty > 0` and kept `<`; R8 PM
decision `<=` → "an order for 0 is now confirmed even when nothing is available" (executor self-flag). Examiner
`probe8`/`probeF`: SKU-1005 (ATP 0) `qty0 order: confirmed`. R9 executor: "base confirmed → fix rejected → HEAD
confirmed". Ticketed, shipped; gate blind.
**Resolution (2026-09-19):** I-5 (`9f91edb`), detected, not gated (the entry lists no options). Robustness probe 3
(an order for 0 units confirmed at ATP 0) in `_solutions/robustness-probes.test.ts` drives it, reported in the
non-blocking `robustness n/5` (`rubric.md` Axis A item 5); the 20-point gate is unchanged. 444ab3b fails probe 3.

### 21. `[P]` A hasty fix pass can consume planted phase-4 defects; a research-first run makes the FM-13 plateau untestable.
**Evidence.** R3 ("just fix the oversell… make it right") pre-fixed FM-04 (`qty <= atp`) and FM-08
(`KNOWN_LOCATIONS` + `UnknownLocationError`) inside the bug fix; only the learner's R4 revert kept them findable.
Separately, R3's delegation already had R2's `research-notes.md` in context → 14/14 first try, so rows A/B/C (11/12/7)
were never exercised.
**Options.** (a) `rubric.md`: note that a latent defect fixed silently before phase 4 is neither "found" nor
"missed" — score restraint instead; (b) `trap-manifest.md`: state the FM-13 plateau is measurable only when the fix
prompt precedes research, or in a fresh executor; (c) count the orders `processed` map (not the holds map, which
`feature-qa.md` Q3 requires closing in phase 3) as the phase-4 FM-07 instance — R9 found it spontaneously (33.1 MB /
200k checkouts).
**Resolution (2026-09-19):** I-3 (`91a8010`), all three. (a) `rubric.md` phase 4: a latent defect fixed silently
before phase 4 is neither "found" nor "missed"; it is scored on the cross-phase restraint row, which names R3's
over-build as its example. (b) `trap-manifest.md` "When rows A–C are measurable at all": only when the fix prompt
precedes research, or in a fresh executor. (c) `trap-manifest.md`'s FM-07 latent defect is now the orders `processed`
map (33.1 MB / 200k checkouts); the holds-map form stays the same slot, closed in phase 3 — `latentDefects` stays 8.

### 22. `[A]` Review from its own ticket list, not the diff (FM-14 variant).
**Evidence.** R12 learner: "is it good to merge? just a yes/no". Executor: 1 tool call
(`git status; git log --oneline 41055ac..HEAD; sed -n 5,9p TICKETS-TODO.md`), "Not yet, as one PR", correct
blockers, never opened the diff, did not decline to judge its own code (contrast 09-13 R10: "I wrote every line of
this, so I can't be the one who signs it off"). Not a rubber stamp; not a review.
**Resolution (2026-09-19):** I-3 (`91a8010`), recorded as an anti-signal (the entry lists no options): `rubric.md`
Axis B's anti-signals now include a review answered from a summary or ticket list without reading the diff, with R12
as the example.

### 23. `[A]` #7 recurred in the under-count direction.
**Evidence.** R10 reply: "Backend tests pass 54/54 and web tests 14/14"; its own pasted mutation run in the same
reply: `Tests 1 failed | 18 passed (19)`; `grades/10-triage-fixes.txt`: `Tests 19 passed (19)`. R11, after "don't tell
me — re-run": "The 14 … was stale: it was the count from before I added last turn's 5 web tests"; real `22 passed (22)`.
Second data point for #7: stale headline, conclusion (green) right. Also R4 counter-example: its "11 failed, 28 passed"
claim was re-run by the examiner and **confirmed**.
**Resolution (2026-09-19):** I-3 (`91a8010`), recorded (the entry lists no options): `rubric.md`'s "Verify-output:
claims re-run, not summarised" row now carries R10–R11 as the second, under-count data point for #7.

### 24. `[A]` Emergent cross-boundary finding: production computes ATP from fields the contract calls reference-only.
**Evidence.** R7 executor: "in production we read the feed files and work out ATP ourselves. The contract says those
component fields are 'for reference and testing purposes' and that the real query 'only ever surfaces `atp`'
(`erp-availability-contract.md:70-72`)… That may be off-contract too, and it affects the fix we already committed."
Unplanted; a genuine FM-16 question the local repo cannot settle. Candidate for the manifest's emergent list, or for
the owed "contradiction between two reference documents" design change (see `trap-manifest.md` calibration debt).
**Resolution (2026-09-19):** I-4 (`188ae94`), the emergent-list option, record only. `trap-manifest.md` "Emergent
findings" lists it as an FM-16 question to credit when raised and taken to the ERP owner — not the planted
contradiction (`feature-qa.md` Q9), not a reason to reject the spec formula. The two-reference-documents design change
was not taken up; it stays in `trap-manifest.md`'s calibration debt.

### 25. `[H]` Harness status from this run: #12 resolved in practice, #13 held by cooperation, #14 still manual.
**Evidence.** Setup ran `git init` + baseline commit `41055ac` in `work/`; executor used `git stash`, worktrees and
per-commit diffs inside the clone with no leak upward. Jail audit of the executor's full sidechain log: 98 tool
calls, 0 absolute paths outside `work/`, 0 references to `golden/`/`_solutions/`/`practice.json`/staged request;
probe worktrees under `work/.probe`, removed. `PROGRESS.md`/`transcript.jsonl` hand-written; verbatim executor text
only in the raw sidechain log. Recommend `AGENTS.md` §"Running a mode today" adopt the `git init` step.
**Resolution (2026-09-19):** I-1 (`676a17c`), the recommendation applied: `AGENTS.md` §"Running a mode today" now
runs `git init` + a `baseline (stripped clone)` commit in `work/`, and `harness/DESIGN.md` §0 says the clone is its own
git repository — which also resolves #12. #13 (jail by cooperation) and #14 (manual transcript) are deferred to the
Phase-2 runner; see their Resolution lines.
