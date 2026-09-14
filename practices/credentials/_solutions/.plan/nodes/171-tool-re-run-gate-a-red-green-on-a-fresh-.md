# 171 — Tool: re-run gate (a) red/green on a fresh copy

Role: tool · Tier: none · Phase: build · Deps: 120, 140

## Goal
Judge node 170's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- `practices/credentials/backend/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/120.json`, `practices/credentials/_solutions/.plan/handoffs/140.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/171/**`
- `practices/credentials/_solutions/.plan/handoffs/171.json`
- `practices/credentials/_solutions/.plan/logs/171/**` (raw output)

## Acceptance criteria
- A1 (V2): fresh throwaway copy: shipped RED, patched GREEN

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh a`
Judges: node 170 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 170 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 171 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
