# 250 — Plant FM-15 doc drift + doc-drift-ledger

Role: worker · Tier: fast · Phase: P4 · Deps: 140, 150, 160

## Goal
Plant the misleading docs of a partially migrated repo and record the truth for each in the answer key.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/src/**`
- `practices/credentials/app/lib/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/140.json`, `practices/credentials/_solutions/.plan/handoffs/150.json`, `practices/credentials/_solutions/.plan/handoffs/160.json`

## You may write
- `practices/credentials/backend/README.md`
- `practices/credentials/app/README.md`
- `practices/credentials/_solutions/doc-drift-ledger.md`
- `practices/credentials/_solutions/.plan/logs/250/**` (raw output)

## Acceptance criteria
- A1 (V8): backend/README.md says issuers are identified with did:key; claims credentials are single-use; claims status notifications are delivered concurrently with retries; uses `expirationDate`. app/README.md describes JWT-VC. Each written as belief, never hedged; lint exits 0
- A2 (V10): doc-drift-ledger.md has one row per contradiction in the contract's row format: doc quote, file, contradicting code file:line, authoritative source and why; `v10-manifest.py --ledger-only` exits 0

## Verify
Command: `python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/README.md --path practices/credentials/app/README.md && python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py --ledger-only`
Judged by: node 251 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/250/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 250 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
