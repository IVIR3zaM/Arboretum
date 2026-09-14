# 231 — Tool: replay feature ladder

Role: tool · Tier: none · Phase: build · Deps: 200

## Goal
Judge node 230's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/231/**`
- `practices/credentials/_solutions/.plan/handoffs/231.json`
- `practices/credentials/_solutions/.plan/logs/231/**` (raw output)

## Acceptance criteria
- A1 (V7): RED x3, GREEN reproduced

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh ladder feature`
Judges: node 230 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 230 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 231 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
