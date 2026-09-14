# 240 — Latent-defect probes (V11)

Role: worker · Tier: fast · Phase: P4 · Deps: 140, 150, 160

## Goal
Prove every claimed latent defect is actually planted and findable.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/src/**`
- `practices/credentials/app/lib/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/140.json`, `practices/credentials/_solutions/.plan/handoffs/150.json`, `practices/credentials/_solutions/.plan/handoffs/160.json`

## You may write
- `practices/credentials/_solutions/probes/**`
- `practices/credentials/_solutions/.plan/logs/240/**`
- `practices/credentials/_solutions/.plan/logs/240/**` (raw output)

## Acceptance criteria
- A1 (V11): One probe per ranked latent defect (7, +#8 if planted) under _solutions/probes/, each PASSING on the shipped tree because the defect is present (replay accepted with fresh requestId; by-reference mutation visible; seen_nonces grows unbounded; exact-instant exp; bit off-by-one; untrusted issuer accepted; unknown proof type → valid)
- A2 (V11): Probes are not wired into grade.sh; `bash _solutions/probes/run.sh` prints one line per defect with file:line of the planted code

## Verify
Command: `bash practices/credentials/_solutions/probes/run.sh`
Judged by: node 241 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/240/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/240/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 240 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
