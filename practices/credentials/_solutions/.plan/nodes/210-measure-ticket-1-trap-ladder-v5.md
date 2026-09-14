# 210 — Measure Ticket 1 trap ladder (V5)

Role: worker · Tier: fast · Phase: P4 · Deps: 200

## Goal
Prove the FM-13/FM-16 ladder bites with real grader runs. Do not tune the grader to make a rung fail; if a rung goes green, stop and report blocked.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/src/**`
- `practices/credentials/_solutions/grade.sh`
- `practices/credentials/_solutions/FIX-ticket1.patch`
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/ladders/ticket1/*.patch`
- `practices/credentials/_solutions/.plan/logs/210/**`
- `practices/credentials/_solutions/.plan/digests/ladder-ticket1.md`
- `practices/credentials/_solutions/.plan/logs/210/**` (raw output)

## Acceptance criteria
- A1 (V5): Four rungs, each a patch applied to a fresh copy in .sessions/build-credentials/210/ and graded: symptom-patch in the VP handler → gate a RED; re-pin/hard-code the one failing issuer → visible suite green AND gate a RED; no-reference 'fix' (trust/refresh local snapshot) → conformance vectors RED; FIX-ticket1 → gate a GREEN. Real outputs in logs/210/rung-N.txt
- A2 (V5): digests/ladder-ticket1.md tabulates rung → score → log path; PR/ is untouched (`git diff --stat` empty)

## Verify
Command: `test -s practices/credentials/_solutions/.plan/digests/ladder-ticket1.md`
Judged by: node 211 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/210/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/210/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 210 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
