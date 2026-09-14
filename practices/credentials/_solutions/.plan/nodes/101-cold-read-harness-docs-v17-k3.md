# 101 — Cold-read harness docs (V17 K3)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 030

## Goal
Judge node 100's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `harness/DESIGN.md`
- `AGENTS.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/030.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/101/**`
- `practices/credentials/_solutions/.plan/handoffs/101.json`
- `practices/credentials/_solutions/.plan/logs/101/**` (raw output)

## Acceptance criteria
- A1 (V17): Reading only harness/DESIGN.md + AGENTS.md: the single and queue shapes are consistent with each other and with rules 3/4; no practice leak; cite lines

## Verify
Judges: node 100 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 100 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 101 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
