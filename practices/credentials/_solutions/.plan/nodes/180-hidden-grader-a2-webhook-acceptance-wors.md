# 180 — Hidden grader (a2): webhook acceptance, worst-case matrix

Role: worker · Tier: fast · Phase: P3 · Deps: 120, 150

## Goal
Write the Ticket 2 grader so only all four axes converge, and one minimal patch per axis for the ladder.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/src/notify/**`
- `practices/credentials/backend/src/settings.rs`
- `practices/credentials/reference/infra/webhook-config.*`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/120.json`, `practices/credentials/_solutions/.plan/handoffs/150.json`

## You may write
- `practices/credentials/_solutions/backend/tests/webhook_acceptance.rs`
- `practices/credentials/_solutions/FIX-ticket2-A1.patch`
- `practices/credentials/_solutions/FIX-ticket2-A2.patch`
- `practices/credentials/_solutions/FIX-ticket2-A3.patch`
- `practices/credentials/_solutions/FIX-ticket2-A4.patch`
- `practices/credentials/_solutions/.plan/logs/180/**`
- `practices/credentials/_solutions/.plan/logs/180/**` (raw output)

## Acceptance criteria
- A1 (V2): Drives the notifier root across {small, large tenant} x {all-healthy, one-slow-endpoint}; asserts every real subscription delivered within the logical budget, a timeout is observable, canary-pass => real delivery; prints `gate a2: n/m` worst-case
- A2 (V2): One patch per axis, each applying cleanly alone and in any combination; in .sessions/build-credentials/180/: shipped RED, all four patches GREEN; captured
- A3 (V6): The A4 fix routes the canary through the loopback stub on the real path with no privileged position; the assert that catches A4 fails when only A1-A3 are fixed

## Verify
Command: `test -s practices/credentials/_solutions/.plan/logs/180/red.txt && test -s practices/credentials/_solutions/.plan/logs/180/green.txt`
Judged by: node 181 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/180/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/180/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 180 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
