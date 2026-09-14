# 390 — H3 — approve merging claude/credentials-build into main

Role: human_gate · Tier: none · Phase: build · Deps: 380

## Goal
A human reviews `git log main..origin/claude/credentials-build` and the proof, then approves the merge with `scripts/sync.sh approve 390 --by <name>`.

## How it is cleared
The orchestrator asks the user in chat and quotes what needs deciding (CLOUD-RUNNER.md §3). Only the user's explicit answer clears it: `bash practices/credentials/_solutions/.plan/scripts/sync.sh approve 390 --by "<user> (chat)" --note "<their words>"`. Never approve on your own judgement.

## You may write
- `practices/credentials/_solutions/.plan/approvals/390.txt`
- `practices/credentials/_solutions/.plan/logs/390/**` (raw output)

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 390 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
