# 331 — Tool: flip + ladders after strengthening

Role: tool · Tier: none · Phase: build · Deps: 320

## Goal
Judge node 330's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/320.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/331/**`
- `practices/credentials/_solutions/.plan/handoffs/331.json`
- `practices/credentials/_solutions/.plan/logs/331/**` (raw output)

## Acceptance criteria
- A1 (V2): flip all exit 0
- A2 (V5): ladders reproduce

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh all && bash practices/credentials/_solutions/.plan/checks/flip.sh ladder ticket1 && bash practices/credentials/_solutions/.plan/checks/flip.sh ladder ticket2`
Judges: node 330 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 330 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 331 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
