# 396 — Tool: main contains the build, branch gone

Role: tool · Tier: none · Phase: build · Deps: 390

## Goal
Judge node 395's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may write
- `practices/credentials/_solutions/.plan/logs/396/**`
- `practices/credentials/_solutions/.plan/handoffs/396.json`
- `practices/credentials/_solutions/.plan/logs/396/**` (raw output)

## Acceptance criteria
- A1 (V12): origin/main contains the build head; origin/claude/credentials-build no longer exists; v12 exit 0

## Verify
Command: `git fetch --prune origin && ! git rev-parse -q --verify origin/claude/credentials-build && bash practices/credentials/_solutions/.plan/checks/v12-shape.sh`
Judges: node 395 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 395 as done or revision_needed, then this node done.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 396 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
