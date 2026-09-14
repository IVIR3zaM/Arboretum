# 241 — Tool: run probes

Role: tool · Tier: none · Phase: build · Deps: 140, 150, 160

## Goal
Judge node 240's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/probes/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/140.json`, `practices/credentials/_solutions/.plan/handoffs/150.json`, `practices/credentials/_solutions/.plan/handoffs/160.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/241/**`
- `practices/credentials/_solutions/.plan/handoffs/241.json`
- `practices/credentials/_solutions/.plan/logs/241/**` (raw output)

## Acceptance criteria
- A1 (V11): run.sh exit 0, one PASS line per defect

## Verify
Command: `bash practices/credentials/_solutions/probes/run.sh`
Judges: node 240 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 240 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 241 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
