# 361 — Tool: proof number check

Role: tool · Tier: none · Phase: build · Deps: 350

## Goal
Judge node 360's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/proof-*.html`
- `practices/credentials/_solutions/.plan/logs/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/350.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/361/**`
- `practices/credentials/_solutions/.plan/handoffs/361.json`
- `practices/credentials/_solutions/.plan/logs/361/**` (raw output)

## Acceptance criteria
- A1 (V16): v16 exit 0

## Verify
Command: `python3 practices/credentials/_solutions/.plan/checks/v16-proof-numbers.py practices/credentials/_solutions/proof-train-*.html --logs practices/credentials/_solutions/.plan/logs`
Judges: node 360 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 360 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 361 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
