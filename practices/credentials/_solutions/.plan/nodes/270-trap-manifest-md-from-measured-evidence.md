# 270 — trap-manifest.md from measured evidence

Role: worker · Tier: fast · Phase: P4 · Deps: 210, 220, 230, 240, 250

## Goal
Assemble the manifest from measured results only, so claims equal plants.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/.plan/digests/ladder-ticket1.md`
- `practices/credentials/_solutions/.plan/digests/ladder-ticket2.md`
- `practices/credentials/_solutions/.plan/digests/ladder-feature.md`
- `practices/credentials/_solutions/.plan/logs/240/**`
- `practices/credentials/_solutions/doc-drift-ledger.md`
- `context/cedar/failure-modes.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/210.json`, `practices/credentials/_solutions/.plan/handoffs/220.json`, `practices/credentials/_solutions/.plan/handoffs/230.json`, `practices/credentials/_solutions/.plan/handoffs/240.json`, `practices/credentials/_solutions/.plan/handoffs/250.json`

## You may write
- `practices/credentials/_solutions/trap-manifest.md`
- `practices/credentials/_solutions/.plan/logs/270/**` (raw output)

## Acceptance criteria
- A1 (V10): Every planted item → FM id + file:line + (assistant traps) the autopilot move it punishes + the discipline that beats it; latent rows = probes count; A1-A4 rows each cite their single-axis and leave-one-out runs
- A2 (V10): Every number quoted is copied from a ladder digest/log with its path; nothing predicted by hand; `v10-manifest.py --manifest-only` exits 0

## Verify
Command: `python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py --manifest-only`
Judged by: node 271 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/270/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/270/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 270 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
