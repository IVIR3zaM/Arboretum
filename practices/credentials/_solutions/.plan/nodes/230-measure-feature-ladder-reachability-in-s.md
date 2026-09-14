# 230 — Measure feature ladder + reachability in stripped clone (V7)

Role: worker · Tier: fast · Phase: P4 · Deps: 200

## Goal
Prove the feature trap is reachable from the clone and bites each naive variant.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/grade.sh`
- `practices/credentials/_solutions/FIX-feature.patch`
- `practices/credentials/_solutions/NAIVE-feature.patch`
- `practices/credentials/_solutions/.plan/checks/strip-clone.sh`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/ladders/feature/*.patch`
- `practices/credentials/_solutions/.plan/logs/230/**`
- `practices/credentials/_solutions/.plan/digests/ladder-feature.md`
- `practices/credentials/_solutions/.plan/logs/230/**` (raw output)

## Acceptance criteria
- A1 (V7): strip-clone.sh with --stage FEATURE-REQUEST.md into .sessions/build-credentials/230/clone: the contract signature greps in app/lib; no ticket file present
- A2 (V7): Three naive variants (all claims disclosed; no holder signature; no nonce+domain binding) each gate b RED; minimal correct GREEN; digests/ladder-feature.md tabulates

## Verify
Command: `test -s practices/credentials/_solutions/.plan/digests/ladder-feature.md`
Judged by: node 231 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/230/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 230 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
