# 015 — H1 — approve toolchains + dependency pins

Role: human_gate · Tier: none · Phase: build · Deps: 010

## Goal
A human reads digests/deps-pins.md and approves the exact Flutter/Rust/crate/pub versions and the network installs they imply. `plan.py approve 015 --by <name> --note <any substitutions>`.

## How it is cleared
The orchestrator asks the user in chat and quotes what needs deciding (CLOUD-RUNNER.md §3). Only the user's explicit answer clears it: `bash practices/credentials/_solutions/.plan/scripts/sync.sh approve 015 --by "<user> (chat)" --note "<their words>"`. Never approve on your own judgement.

## You may write
- `practices/credentials/_solutions/.plan/approvals/015.txt`
- `practices/credentials/_solutions/.plan/logs/015/**` (raw output)

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 015 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
