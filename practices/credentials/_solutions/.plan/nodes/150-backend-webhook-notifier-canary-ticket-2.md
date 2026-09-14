# 150 — backend: webhook notifier + canary (Ticket 2 plant, A1-A4)

Role: worker · Tier: fast · Phase: P2 · Deps: 110, 120

## Goal
Build the status-change notifier with four independent latent flaws so the health check stays green while a large tenant gets nothing.

## Notes
Runs in parallel with 130/140. Touches lib.rs module declarations only; if lib.rs conflicts, add the module line and nothing else.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/Cargo.toml`
- `practices/credentials/backend/src/lib.rs`
- `practices/credentials/reference/infra/webhook-config.*`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/110.json`, `practices/credentials/_solutions/.plan/handoffs/120.json`

## You may write
- `practices/credentials/backend/src/notify/**`
- `practices/credentials/backend/src/settings.rs`
- `practices/credentials/backend/src/lib.rs`
- `practices/credentials/backend/tests/notify_*.rs`
- `practices/credentials/_solutions/.plan/logs/150/**` (raw output)

## Acceptance criteria
- A1 (V1): `cd practices/credentials/backend && cargo test --offline --locked --test 'notify_*'` exits 0, including a passing canary health test; tests use only a small tenant and healthy endpoints
- A2 (V6): A1: hardcoded logical dispatch budget, timeout path log-only (no metric/event). A2: sequential `for sub in subs { dispatch(sub).await }` sharing one budget. A3: tenant subscription lookup iterates all settings. A4: canary registered at index 0 targeting example.com, resolved through the loopback stub under test. All four exactly where the planting map says, none commented as a flaw
- A3 (V6): Time is logical/injectable (no wall-clock sleeps), so the future grader asserts deterministically
- A4 (V8): lint over practices/credentials/backend/src/notify and practices/credentials/backend/tests exits 0

## Verify
Command: `(cd practices/credentials/backend && cargo test --offline --locked) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/src --path practices/credentials/backend/tests`
Judged by: node 151 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/150/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 150 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
