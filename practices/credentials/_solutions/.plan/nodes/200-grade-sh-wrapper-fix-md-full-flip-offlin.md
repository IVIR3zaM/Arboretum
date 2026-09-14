# 200 — grade.sh wrapper + FIX.md + full flip + offline proof

Role: integrator · Tier: reasoning_mid · Phase: P3 · Deps: 170, 180, 190

## Goal
Integrate the three gates into the one hermetic wrapper the harness runs, and prove the full red→green→red flip.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/backend/**`
- `practices/credentials/_solutions/app/**`
- `practices/credentials/_solutions/*.patch`
- `practices/credentials/_solutions/.plan/logs/170/**`
- `practices/credentials/_solutions/.plan/logs/180/**`
- `practices/credentials/_solutions/.plan/logs/190/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/170.json`, `practices/credentials/_solutions/.plan/handoffs/180.json`, `practices/credentials/_solutions/.plan/handoffs/190.json`

## You may write
- `practices/credentials/_solutions/grade.sh`
- `practices/credentials/_solutions/FIX.md`
- `practices/credentials/_solutions/.plan/logs/200/**`
- `practices/credentials/_solutions/.plan/logs/200/**` (raw output)

## Acceptance criteria
- A1 (V2): `bash practices/credentials/_solutions/grade.sh` (run from practices/credentials) ANDs gates a, a2, b and prints per-gate + total worst-case; shipped tree exits non-zero with EACH gate red; all fix patches applied in a throwaway copy exits 0; reverted exits non-zero; `git diff --stat practices/credentials` empty afterwards
- A2 (V3): The fixed-copy run is repeated with the network disabled and still exits 0; method logged
- A3 (V2): `bash practices/credentials/_solutions/.plan/checks/flip.sh all` (authored in 030) exits 0 against this wrapper; FIX.md explains each fix, why re-pin plateaus, why each single axis plateaus, and names caching/TTL as an aside not built

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/flip.sh all`
Judged by: node 201 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/200/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/200/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 200 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
