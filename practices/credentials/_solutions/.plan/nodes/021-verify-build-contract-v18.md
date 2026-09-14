# 021 — Verify build contract (V18)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 010

## Goal
Judge node 020's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/DESIGN.md`
- `context/cedar/generation-spec.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/010.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/021/**`
- `practices/credentials/_solutions/.plan/handoffs/021.json`
- `practices/credentials/_solutions/.plan/logs/021/**` (raw output)

## Acceptance criteria
- A1 (V18): No contradiction with DESIGN.md or the Cedar spec; no interface a downstream node needs is missing; cite lines

## Verify
Judges: node 020 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 020 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 021 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
