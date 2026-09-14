# 020 — Build contract digest (the single interface)

Role: integrator · Tier: reasoning_mid · Phase: P0 · Deps: 010

## Goal
Write the one document every parallel builder binds to, so backend, app, reference and graders agree without talking. Carry the fulfillment lessons: the graded surface must exist as a stub in the clone; no ready-made correct helper in local code; no tests that assert the true answer.

## You may read
- `practices/credentials/DESIGN.md`
- `context/cedar/generation-spec.md`
- `context/cedar/failure-modes.md`
- `generator/CONTRACT.md`
- `practices/fulfillment/_solutions/BUILD-LEDGER.md`
- `practices/fulfillment/_solutions/misbehaviors.md`
- `practices/credentials/_solutions/.plan/digests/deps-pins.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/010.json`

## You may write
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/.plan/logs/020/**`
- `practices/credentials/_solutions/.plan/logs/020/**` (raw output)

## Acceptance criteria
- A1 (V18): Issuer dataset: >=3 hosted did:web issuers = (a) never rotated, (b) rotated signing key, (c) rotated key + changed service endpoint; each with DID, onboarding-snapshot key(s), current key(s), trust-registry status; plus one untrusted/spoofed issuer for latent #6
- A2 (V18): Webhook dataset: small tenant (few settings) and large tenant (many settings, enough that the unindexed scan alone blows the logical budget); one slow/hanging endpoint; the canary registration at index 0 targeting example.com; the logical dispatch budget value and the observable-timeout signal type the grader asserts
- A3 (V18): Public roots graders call, with exact Rust signatures: did resolver root, VP verification root (returns a typed verdict), status-list check, notifier fan-out root with injectable clock/timeout/dispatcher (logical time, no wall-clock sleeps). Dart: `WalletService.createPresentation(...)` exact signature and the DCQL query type
- A4 (V18): Grader injection mechanism that leaves nothing grade-shaped in the clone: grade.sh copies the package to a temp dir and drops `_solutions/backend/tests/*.rs` / `_solutions/app/test/*.dart` in, then runs `cargo test --offline --locked --test <name>` / `flutter test --offline <file>`. Explicitly decide and justify how gate (b) reaches the Rust verifier (e.g. a shipped `verify-presentation` CLI the Dart test invokes) and whether `flutter test` VM tests replace a device-bound integration_test
- A5 (V18): Planting map: exact file + function for the stale did:web snapshot branch, each of A1-A4, each of latent defects 1-8, each FM-15 doc-drift item; and the reference fix per trap in <=10 lines of prose each (goes to FIX.md later)
- A6 (V18): Source file list with LOC budget per file totalling ~1,600-1,900 LOC across packages (invariant 7), and the green-suite rules: unit tests only use never-rotated issuers, small tenants, healthy endpoints, and a passing canary test

## Verify
Command: `test -s practices/credentials/_solutions/.plan/digests/build-contract.md`
Judged by: node 021 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/020/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 4. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 020 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
