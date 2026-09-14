# 160 — app: Flutter wallet + createPresentation stub

Role: worker · Tier: fast · Phase: P2 · Deps: 110, 120

## Goal
Build the holder wallet so the phase-3 feature has a reachable, typed surface and the naive path is the easy one.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/.plan/digests/deps-pins.md`
- `practices/credentials/app/pubspec.yaml`
- `practices/credentials/app/lib/main.dart`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/110.json`, `practices/credentials/_solutions/.plan/handoffs/120.json`

## You may write
- `practices/credentials/app/lib/**`
- `practices/credentials/app/test/**`
- `practices/credentials/app/fixtures/**`
- `practices/credentials/_solutions/.plan/logs/160/**` (raw output)

## Acceptance criteria
- A1 (V1): `cd practices/credentials/app && flutter test --offline` exits 0
- A2 (V7): `WalletService.createPresentation(...)` exists with EXACTLY the contract signature and throws UnimplementedError; request-credential + store flows work
- A3 (V11): Latent #2: the wallet store returns the stored credential (and key handle) by reference, planted per the planting map
- A4 (V8): lint over practices/credentials/app/lib and practices/credentials/app/test exits 0

## Verify
Command: `(cd practices/credentials/app && flutter test --offline) && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --path practices/credentials/app/lib --path practices/credentials/app/test`
Judged by: node 161 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/160/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/160/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 160 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
