# 320 — Router: did both control-run attacks fail?

Role: router · Tier: none · Phase: P6 · Deps: 300, 310

## Goal
If handoffs 300 and 310 both report succeeded=false, mark 330,331,332,334,336,340 skipped; else leave them to run.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 320 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
