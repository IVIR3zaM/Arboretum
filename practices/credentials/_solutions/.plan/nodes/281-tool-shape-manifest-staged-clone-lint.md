# 281 — Tool: shape + manifest + staged-clone lint

Role: tool · Tier: none · Phase: build · Deps: 100, 260, 270

## Goal
Judge node 280's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/100.json`, `practices/credentials/_solutions/.plan/handoffs/260.json`, `practices/credentials/_solutions/.plan/handoffs/270.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/281/**`
- `practices/credentials/_solutions/.plan/handoffs/281.json`
- `practices/credentials/_solutions/.plan/logs/281/**` (raw output)

## Acceptance criteria
- A1 (V12): v12 exit 0
- A2 (V10): v10 exit 0
- A3 (V8): lint all stages exit 0

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/v12-shape.sh && python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --clone-all-stages practices/credentials`
Judges: node 280 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 280 as done or revision_needed, then this node done.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 281 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
