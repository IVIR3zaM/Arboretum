# 285 — Anti-coaching cold read of every staged clone (V9)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 280

## Goal
Standalone gate: read the learner's clones as an outsider and find coaching. Operator builds the clones; you read only them.

## You may read
- `.sessions/build-credentials/285/clone-*/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/280.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/285/**`
- `practices/credentials/_solutions/.plan/handoffs/285.json`
- `practices/credentials/_solutions/.plan/logs/285/**` (raw output)

## Acceptance criteria
- A1 (V9): Build clones with strip-clone.sh for stage TICKET-1, TICKET-2 and FEATURE-REQUEST (separately). Reading only a clone: no narration of any planted defect or suite blind spot; docs mislead rather than hedge; reference/ citations cite, not interpret. On fail: set 280 (or the owning builder node) revision_needed with cited lines

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 285 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
