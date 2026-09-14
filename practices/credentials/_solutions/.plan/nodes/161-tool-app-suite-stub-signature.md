# 161 — Tool: app suite + stub signature

Role: tool · Tier: none · Phase: build · Deps: 110, 120

## Goal
Judge node 160's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/app/**`
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/110.json`, `practices/credentials/_solutions/.plan/handoffs/120.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/161/**`
- `practices/credentials/_solutions/.plan/handoffs/161.json`
- `practices/credentials/_solutions/.plan/logs/161/**` (raw output)

## Acceptance criteria
- A1 (V1): flutter test exit 0
- A2 (V7): grep of the contract signature in lib/ matches

## Verify
Command: `(cd practices/credentials/app && flutter test --offline) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/app/lib --path practices/credentials/app/test`
Judges: node 160 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 160 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 161 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
