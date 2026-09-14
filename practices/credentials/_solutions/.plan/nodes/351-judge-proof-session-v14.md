# 351 — Judge proof session (V14)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 320, 340

## Goal
Judge node 350's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/.plan/logs/350/**`
- `.sessions/build-credentials/350/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/320.json`, `practices/credentials/_solutions/.plan/handoffs/340.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/351/**`
- `practices/credentials/_solutions/.plan/handoffs/351.json`
- `practices/credentials/_solutions/.plan/logs/351/**` (raw output)

## Acceptance criteria
- A1 (V14): Re-run grade.sh on the session result → exit 0; no _solutions access in the executor transcript; diff stat within XL altitude (cite numbers)

## Verify
Judges: node 350 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 350 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 351 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
