# 111 — Tool: re-run V4 + offline builds

Role: tool · Tier: none · Phase: build · Deps: 015, 020

## Goal
Judge node 110's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/backend/**`
- `practices/credentials/app/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/015.json`, `practices/credentials/_solutions/.plan/handoffs/020.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/111/**`
- `practices/credentials/_solutions/.plan/handoffs/111.json`
- `practices/credentials/_solutions/.plan/logs/111/**` (raw output)

## Acceptance criteria
- A1 (V4): v4-deps.sh exit 0
- A2 (V3): offline build + test exit 0 with network disabled

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/v4-deps.sh && (cd practices/credentials/backend && cargo build --offline --locked) && (cd practices/credentials/app && flutter test --offline)`
Judges: node 110 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 110 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 111 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
