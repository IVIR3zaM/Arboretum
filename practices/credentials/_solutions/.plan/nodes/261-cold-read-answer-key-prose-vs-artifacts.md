# 261 — Cold-read answer-key prose vs artifacts

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 120, 200

## Goal
Judge node 260's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/feature-qa.md`
- `practices/credentials/_solutions/rubric.md`
- `practices/credentials/_solutions/context-map.md`
- `practices/credentials/_solutions/FIX.md`
- `practices/credentials/_solutions/*.patch`
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/120.json`, `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/261/**`
- `practices/credentials/_solutions/.plan/handoffs/261.json`
- `practices/credentials/_solutions/.plan/logs/261/**` (raw output)

## Acceptance criteria
- A1 (V7): Every answer agrees with the patches and reference/; rubric max equals grade.sh total; cite lines

## Verify
Judges: node 260 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 260 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 261 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
