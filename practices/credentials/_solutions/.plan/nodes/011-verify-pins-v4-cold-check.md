# 011 — Verify pins (V4 cold check)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: —

## Goal
Judge node 010's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/.plan/digests/deps-pins.md`
- `practices/credentials/_solutions/.plan/logs/010/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`

## You may write
- `practices/credentials/_solutions/.plan/logs/011/**`
- `practices/credentials/_solutions/.plan/handoffs/011.json`
- `practices/credentials/_solutions/.plan/logs/011/**` (raw output)

## Acceptance criteria
- A1 (V4): Re-run each registry lookup and the deny-list scan independently; every pin exists at that version and no deny-list crate/package is in the tree

## Verify
Judges: node 010 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 010 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 011 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
