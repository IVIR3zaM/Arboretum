# 131 — Tool: backend DID suite + lint

Role: tool · Tier: none · Phase: build · Deps: 110, 120

## Goal
Judge node 130's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/backend/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/110.json`, `practices/credentials/_solutions/.plan/handoffs/120.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/131/**`
- `practices/credentials/_solutions/.plan/handoffs/131.json`
- `practices/credentials/_solutions/.plan/logs/131/**` (raw output)

## Acceptance criteria
- A1 (V1): cargo test exit 0
- A2 (V8): lint exit 0

## Verify
Command: `(cd practices/credentials/backend && cargo test --offline --locked) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/src --path practices/credentials/backend/tests`
Judges: node 130 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 130 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 131 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
