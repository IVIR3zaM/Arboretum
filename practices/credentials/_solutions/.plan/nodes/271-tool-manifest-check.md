# 271 — Tool: manifest check

Role: tool · Tier: none · Phase: build · Deps: 210, 220, 230, 240, 250

## Goal
Judge node 270's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- `practices/credentials/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/210.json`, `practices/credentials/_solutions/.plan/handoffs/220.json`, `practices/credentials/_solutions/.plan/handoffs/230.json`, `practices/credentials/_solutions/.plan/handoffs/240.json`, `practices/credentials/_solutions/.plan/handoffs/250.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/271/**`
- `practices/credentials/_solutions/.plan/handoffs/271.json`
- `practices/credentials/_solutions/.plan/logs/271/**` (raw output)

## Acceptance criteria
- A1 (V10): v10-manifest.py --manifest-only exit 0

## Verify
Command: `python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py --manifest-only`
Judges: node 270 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 270 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 271 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
