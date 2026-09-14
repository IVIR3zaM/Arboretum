# 181 — Tool: re-run gate (a2) red/green

Role: tool · Tier: none · Phase: build · Deps: 120, 150

## Goal
Judge node 180's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- `practices/credentials/backend/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/120.json`, `practices/credentials/_solutions/.plan/handoffs/150.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/181/**`
- `practices/credentials/_solutions/.plan/handoffs/181.json`
- `practices/credentials/_solutions/.plan/logs/181/**` (raw output)

## Acceptance criteria
- A1 (V2): fresh copy: shipped RED, all-four GREEN

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh a2`
Judges: node 180 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 180 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 181 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
