# 140 — backend: VP verifier, status list, trust registry, verify CLI (latents)

Role: worker · Tier: fast · Phase: P2 · Deps: 130

## Goal
Build the verification side the grader roots on, with the ranked latent defects planted and invisible to the suite.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/src/**`
- `practices/credentials/backend/Cargo.toml`
- `practices/credentials/reference/trust-registry.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/130.json`

## You may write
- `practices/credentials/backend/src/verifier/**`
- `practices/credentials/backend/src/status.rs`
- `practices/credentials/backend/src/trust.rs`
- `practices/credentials/backend/src/bin/verify_presentation.rs`
- `practices/credentials/backend/src/lib.rs`
- `practices/credentials/backend/tests/verifier_*.rs`
- `practices/credentials/backend/tests/status_*.rs`
- `practices/credentials/_solutions/.plan/logs/140/**` (raw output)

## Acceptance criteria
- A1 (V1): `cd practices/credentials/backend && cargo test --offline --locked` exits 0
- A2 (V11): Latent defects planted per the planting map: #1 replay dedupe on transport requestId, #3 unbounded seen_nonces, #4 strict </> exp/nbf at the exact instant, #5 status-list bit index off-by-one, #6 issuer trusted without the registry check, #7 unknown proof type / DID method falls through to valid. Each is idiomatic and uncommented
- A3 (V7): The `verify-presentation` CLI (or the contract's chosen bridge) accepts a VP JSON + nonce + domain and prints a typed verdict; it is ordinary shipped tooling with no mention of tests or grading
- A4 (V8): lint over practices/credentials/backend/src and practices/credentials/backend/tests exits 0

## Verify
Command: `(cd practices/credentials/backend && cargo test --offline --locked) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/src --path practices/credentials/backend/tests`
Judged by: node 141 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/140/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/140/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 140 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
