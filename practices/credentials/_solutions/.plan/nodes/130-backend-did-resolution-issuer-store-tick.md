# 130 — backend: DID resolution, issuer, store (Ticket 1 plant)

Role: worker · Tier: fast · Phase: P2 · Deps: 110, 120

## Goal
Build the issuer-DID side of the backend so the did:web stale-snapshot bug ships silently behind a green suite.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/Cargo.toml`
- `practices/credentials/backend/src/lib.rs`
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/110.json`, `practices/credentials/_solutions/.plan/handoffs/120.json`

## You may write
- `practices/credentials/backend/src/did/**`
- `practices/credentials/backend/src/issuer.rs`
- `practices/credentials/backend/src/store.rs`
- `practices/credentials/backend/src/loopback.rs`
- `practices/credentials/backend/src/types.rs`
- `practices/credentials/backend/src/lib.rs`
- `practices/credentials/backend/tests/did_*.rs`
- `practices/credentials/backend/tests/issuer_*.rs`
- `practices/credentials/backend/fixtures/**`
- `practices/credentials/_solutions/.plan/logs/130/**` (raw output)

## Acceptance criteria
- A1 (V1): `cd practices/credentials/backend && cargo test --offline --locked` exits 0 and the did/issuer tests use only the never-rotated issuer
- A2 (V5): The did:web branch of the resolver returns the onboarding-time snapshot instead of fetching via the loopback/file resolver, as ordinary resolver code; did:key and did:peer:2 decode paths are correct; the loopback fetch helper exists and is correct but the stale branch does not call it
- A3 (V11): Latent #2 (wallet-side is app; here: store returns stored credential by reference if the contract places it here) and optional #8 (HashMap-order canonicalization) are planted exactly where the contract's planting map says
- A4 (V8): `practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/src --path practices/credentials/backend/tests` exits 0; one comment mentions peer DIDs near the resolver as a believable leftover, never as a confession

## Verify
Command: `(cd practices/credentials/backend && cargo test --offline --locked) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/backend/src --path practices/credentials/backend/tests`
Judged by: node 131 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/130/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 130 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
