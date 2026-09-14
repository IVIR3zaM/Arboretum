# 251 — Tool: lint + ledger check

Role: tool · Tier: none · Phase: build · Deps: 140, 150, 160

## Goal
Judge node 250's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/140.json`, `practices/credentials/_solutions/.plan/handoffs/150.json`, `practices/credentials/_solutions/.plan/handoffs/160.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/251/**`
- `practices/credentials/_solutions/.plan/handoffs/251.json`
- `practices/credentials/_solutions/.plan/logs/251/**` (raw output)

## Acceptance criteria
- A1 (V8): lint exit 0
- A2 (V10): ledger check exit 0

## Verify
Command: `python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/README.md --path practices/credentials/app/README.md && python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py --ledger-only`
Judges: node 250 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 250 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 251 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
