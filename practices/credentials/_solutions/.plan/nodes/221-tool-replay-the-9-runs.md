# 221 — Tool: replay the 9 runs

Role: tool · Tier: none · Phase: build · Deps: 200

## Goal
Judge node 220's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/221/**`
- `practices/credentials/_solutions/.plan/handoffs/221.json`
- `practices/credentials/_solutions/.plan/logs/221/**` (raw output)

## Acceptance criteria
- A1 (V6): 8 RED, 1 GREEN reproduced

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh ladder ticket2`
Judges: node 220 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 220 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 221 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
