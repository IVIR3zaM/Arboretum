# 121 — Cold-read reference/ for coaching (V9)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 020, 110

## Goal
Judge node 120's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/020.json`, `practices/credentials/_solutions/.plan/handoffs/110.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/121/**`
- `practices/credentials/_solutions/.plan/handoffs/121.json`
- `practices/credentials/_solutions/.plan/logs/121/**` (raw output)

## Acceptance criteria
- A1 (V9): reference/ reads as a vendor snapshot: no study/distill/compare instruction, no hint that the local repo disagrees, no narration of any defect; cite lines

## Verify
Judges: node 120 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 120 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 121 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
