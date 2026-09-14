# 015 — H1 — approve toolchains + dependency pins

Role: human_gate · Tier: none · Phase: build · Deps: 010

## Goal
A human reads digests/deps-pins.md and approves the exact Flutter/Rust/crate/pub versions and the network installs they imply. `plan.py approve 015 --by <name> --note <any substitutions>`.

## You may write
- `practices/credentials/_solutions/.plan/approvals/015.txt`
- `practices/credentials/_solutions/.plan/logs/015/**` (raw output)

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 015 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
