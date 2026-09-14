# 031 — Verify assertion scripts faithfully implement V4/V8/V10/V12/V16/V17

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 020

## Goal
Judge node 030's artifacts on disk against its acceptance criteria. Return verdicts; fix nothing.

## You may read
- `practices/credentials/_solutions/.plan/checks/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- `AGENTS.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/020.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/031/**`
- `practices/credentials/_solutions/.plan/handoffs/031.json`
- `practices/credentials/_solutions/.plan/logs/031/**` (raw output)

## Acceptance criteria
- A1 (V8): Each script's decision rule matches its V entry; none can be passed by an empty or trivially shaped target; the self-test fixtures actually exercise the rule

## Verify
Judges: node 030 — see OPERATOR-NOTES.md §How verifier nodes run. Complete node 030 as done or revision_needed, then this node done.

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 031 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
