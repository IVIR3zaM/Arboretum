# 201 — Tool: full flip + offline

Role: tool · Tier: none · Phase: build · Deps: 170, 180, 190

## Goal
Judge node 200's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- `practices/credentials/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/170.json`, `practices/credentials/_solutions/.plan/handoffs/180.json`, `practices/credentials/_solutions/.plan/handoffs/190.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/201/**`
- `practices/credentials/_solutions/.plan/handoffs/201.json`
- `practices/credentials/_solutions/.plan/logs/201/**` (raw output)

## Acceptance criteria
- A1 (V2): flip.sh all exit 0
- A2 (V3): offline green

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh all --offline`
Judges: node 200 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 200 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 201 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
