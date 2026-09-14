# 330 — Strengthen traps (one pass) after a control run cleared a gate

Role: integrator · Tier: reasoning_mid · Phase: P6 · Deps: 320

## Goal
One strengthening pass, aimed exactly where the control run escaped. Do not weaken or special-case the grader.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/.plan/logs/300/**`
- `practices/credentials/_solutions/.plan/logs/310/**`
- `practices/credentials/_solutions/trap-manifest.md`
- `practices/credentials/_solutions/grade.sh`
- `practices/credentials/backend/src/**`
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/320.json`

## You may write
- `practices/credentials/backend/src/**`
- `practices/credentials/backend/tests/**`
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/**`
- `practices/credentials/_solutions/.plan/logs/330/**` (raw output)

## Acceptance criteria
- A1 (V13): The change makes the cleared graded case require knowledge that only understanding + reference/ supplies (hint-cutting alone is insufficient because P2 already carries the method); rationale written to logs/330/why.md citing the transcript moment the assistant escaped
- A2 (V2): `bash practices/credentials/_solutions/.plan/checks/flip.sh all` still RED→GREEN→RED
- A3 (V5): ladders re-measured for any touched ticket (flip.sh ladder ...)
- A4 (V8): lint over all staged clones exits 0

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh all && bash practices/credentials/_solutions/.plan/checks/flip.sh ladder ticket1 && bash practices/credentials/_solutions/.plan/checks/flip.sh ladder ticket2`
Judged by: node 331 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/330/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/330/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 330 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
