# 191 — Tool: re-run gate (b) ladder

Role: tool · Tier: none · Phase: build · Deps: 140, 160

## Goal
Judge node 190's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/**`
- `practices/credentials/app/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/140.json`, `practices/credentials/_solutions/.plan/handoffs/160.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/191/**`
- `practices/credentials/_solutions/.plan/handoffs/191.json`
- `practices/credentials/_solutions/.plan/logs/191/**` (raw output)

## Acceptance criteria
- A1 (V7): stub RED, naive RED, fix GREEN

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh b`
Judges: node 190 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 190 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 191 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
