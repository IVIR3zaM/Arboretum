# 390 — H3 — approve push to main

Role: human_gate · Tier: none · Phase: build · Deps: 380

## Goal
A human reviews `git log credentials-v0-baseline..main` and the proof, then approves the push.

## You may write
- `practices/credentials/_solutions/.plan/approvals/390.txt`
- `practices/credentials/_solutions/.plan/logs/390/**` (raw output)

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 390 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
