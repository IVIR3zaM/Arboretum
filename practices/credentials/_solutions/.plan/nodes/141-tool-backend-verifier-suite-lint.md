# 141 — Tool: backend verifier suite + lint

Role: tool · Tier: none · Phase: build · Deps: 130

## Goal
Judge node 140's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/backend/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/130.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/141/**`
- `practices/credentials/_solutions/.plan/handoffs/141.json`
- `practices/credentials/_solutions/.plan/logs/141/**` (raw output)

## Acceptance criteria
- A1 (V1): cargo test exit 0
- A2 (V8): lint exit 0

## Verify
Command: `(cd practices/credentials/backend && cargo test --offline --locked) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/src --path practices/credentials/backend/tests`
Judges: node 140 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 140 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 141 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
