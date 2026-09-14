# 340 — H2 — calibration decision

Role: human_gate · Tier: none · Phase: build · Deps: 336

## Goal
A control run still clears a gate after one strengthening pass. Decide: strengthen again (add nodes), accept and record honestly in practice.json + proof, or cut scope. Record the decision in approvals/340.txt.

## You may write
- `practices/credentials/_solutions/.plan/approvals/340.txt`
- `practices/credentials/_solutions/.plan/logs/340/**` (raw output)

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 340 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
