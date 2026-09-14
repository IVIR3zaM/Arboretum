# 190 — Hidden grader (b): wallet VP accepted/rejected by Rust verifier

Role: worker · Tier: fast · Phase: P3 · Deps: 140, 160

## Goal
Write the cross-stack feature grader plus the minimal correct and the naive presentation as patches.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/app/lib/**`
- `practices/credentials/backend/src/bin/verify_presentation.rs`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/140.json`, `practices/credentials/_solutions/.plan/handoffs/160.json`

## You may write
- `practices/credentials/_solutions/app/test/presentation_acceptance_test.dart`
- `practices/credentials/_solutions/FIX-feature.patch`
- `practices/credentials/_solutions/NAIVE-feature.patch`
- `practices/credentials/_solutions/.plan/logs/190/**`
- `practices/credentials/_solutions/.plan/logs/190/**` (raw output)

## Acceptance criteria
- A1 (V2): Asserts the wallet VP (DCQL subset via `dcql`) is ACCEPTED by the shipped Rust verifier and that tampered / expired / replayed VPs are REJECTED; prints `gate b: n/m`
- A2 (V7): In .sessions/build-credentials/190/: stub RED; NAIVE-feature.patch (all claims, or no holder signature, or no nonce+domain binding) RED; FIX-feature.patch GREEN; outputs captured

## Verify
Command: `test -s practices/credentials/_solutions/.plan/logs/190/green.txt`
Judged by: node 191 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/190/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 190 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
