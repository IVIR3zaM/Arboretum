# 220 — Measure Ticket 2 four-axis plateau: 9 runs (V6)

Role: worker · Tier: fast · Phase: P4 · Deps: 200

## Goal
Prove every webhook axis is necessary, not merely that single fixes plateau.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/grade.sh`
- `practices/credentials/_solutions/FIX-ticket2-*.patch`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/220/**`
- `practices/credentials/_solutions/.plan/digests/ladder-ticket2.md`
- `practices/credentials/_solutions/.plan/logs/220/**` (raw output)

## Acceptance criteria
- A1 (V6): In fresh copies under .sessions/build-credentials/220/: each single-axis patch alone (4 runs) → gate a2 RED; each leave-one-out combination (4 runs) → RED; all four → GREEN. Per-assert breakdown captured for each run
- A2 (V6): digests/ladder-ticket2.md tabulates the 9 runs with which assert failed; if any leave-one-out run is GREEN, complete as blocked naming the axis that is not necessary

## Verify
Command: `test -s practices/credentials/_solutions/.plan/digests/ladder-ticket2.md`
Judged by: node 221 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/220/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 220 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
