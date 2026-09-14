# 336 — Router: did both re-runs fail?

Role: router · Tier: none · Phase: P6 · Deps: 332, 334

## Goal
If handoffs 332 and 334 both report succeeded=false mark 340 skipped; else 340 awaits approval.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 336 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
