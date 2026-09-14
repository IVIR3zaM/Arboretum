# SELFCHECK — architect's audit of the credentials build plan

Generated 2026-09-14. `plan.py validate` → **65 nodes · 0 errors · 0 warnings**.

## 1. Does every VERIFICATION.md item map to at least one node's acceptance criteria?
Yes. The validator warns on uncited V-numbers and reported none. Mapping:
V1 130/140/150/160 · V2 170/180/190/200/330 · V3 110/200 · V4 010/011/110 · V5 120/130/170/210/330 ·
V6 120/150/180/220 · V7 140/160/190/230/260 · V8 030/120/130/140/150/160/250/280/330 · V9 121/285 ·
V10 030/250/260/270/280 · V11 130/140/160/240 · V12 030/100/110/280/395 · V13 300/310/330/332/334/360 ·
V14 350/351 · V15 370 · V16 030/360/361 · V17 030/100/101 · V18 020/021.
The human gates H1/H2/H3 are nodes 015/340/390.

## 2. Does every worker node have a distinct verifier?
Yes. Each worker/integrator names a verifier node that is not itself (the validator enforces this). Each
worker has its own verifier (N0 → N1). Model-judged verifiers are 011, 021, 031, 101, 121, 261, 351 and the
standalone gates 285 and 370. Workers whose criteria are mechanically decidable have `tool` verifiers
that re-run the command on a fresh copy, so a worker's own green run is never the evidence.
The mechanical checks (030) are written from the contract **before** anything they judge exists.
Adversaries (300/310/332/334) start cold on a clone. The operator stages the tickets and runs the grade.

## 3. Could a cold reader evaluate every node's acceptance criteria without asking a question?
Mostly yes. Two deliberate dependencies on upstream artifacts:
- Builder criteria say "per the planting map / contract signature", which only resolves once 020 is
  verified (021). That is intended: V18 exists to make the contract the one source of those names.
- 285 and 370 are judgement calls (V9, V15). Their criteria require cited lines, so a verdict can be checked.
Residual ambiguity: **latent #2** (by-reference store) may land in backend 130 or app 160 depending on the
contract. Both briefs defer to the planting map, and 240's probe count reconciles it.

## 4. Is any node over its tier's token threshold?
No. The largest estimates are 370 (70k, reasoning_high 80k), 330 (60k, reasoning_mid 80k) and 350/360 (60k).
The validator checks this. 350 (the proof session) orchestrates sub-agents whose contexts are separate.
Its 60k covers only the orchestrator. If it runs hot, move examiner grading into 351.

## 5. Which nodes are serialized by a dependency that does not actually exist?
- **150 → 120**: the notifier needs only the webhook-config values, which the contract already fixes. It could
  depend on 020 + 110 alone and start alongside 120. Kept serialized so the config file and the code
  can't drift. Cost: one node's latency.
- **240/250 → 160**: the probes and doc drift for the backend could start before the app lands. Kept because
  each is one verifier's unit of work across both stacks.
- **280 → 100**: real. `practice.json` → `workItems.staged` uses the format 100 defines.
- **110 → 015**: real. No network install before H1.
- **310 → 300, 334 → 332**: real. A cold run seals (empties) the checkout, so control runs have to run one
  after another with nothing else in flight (added for the cloud runner).
Everything else is a genuine data dependency.

## Parallel width
Peak ≈ **5 workers**: after 120 lands, 130 → 140 and 150 and 160 run together, plus 100 if it's still open.
After 200, 210/220/230 run together, while 240/250 may still be running. Verifier and tool nodes add
short-lived width on top.

## Known risks carried into the run
- **Flutter gate (b) on a VM test vs integration_test:** 020 must decide and justify it. If the contract
  keeps `integration_test/`, it needs a desktop device, which weakens V3's offline claim.
- **Control runs clearing the gate** (fulfillment precedent): the 320 → 330 → 332/334 → 336 → 340 path
  exists for this.
- **Estimate:** recomputed per the spec in 280 and flagged provisional. Fulfillment's was about 5× low.
