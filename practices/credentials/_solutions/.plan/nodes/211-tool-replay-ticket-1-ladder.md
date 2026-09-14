# 211 — Tool: replay Ticket 1 ladder

Role: tool · Tier: none · Phase: build · Deps: 200

## Goal
Judge node 210's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/ladders/ticket1/**`
- `practices/credentials/_solutions/grade.sh`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/211/**`
- `practices/credentials/_solutions/.plan/handoffs/211.json`
- `practices/credentials/_solutions/.plan/logs/211/**` (raw output)

## Acceptance criteria
- A1 (V5): RED,RED,RED,GREEN reproduced

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh ladder ticket1`
Judges: node 210 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 210 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 211 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
