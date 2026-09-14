# 005 — Capture baseline (done at plan time)

Role: tool · Tier: none · Phase: P0 · Deps: —

## Goal
Record baseline ref credentials-v0-baseline and toolchain versions.

## You may write
- `practices/credentials/_solutions/.plan/logs/005/baseline.txt`
- `practices/credentials/_solutions/.plan/logs/005/**` (raw output)

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 005 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
