# 110 — Toolchains + package skeletons (both stacks)

Role: worker · Tier: fast · Phase: P2 · Deps: 015, 020

## Goal
Install the approved toolchains (Flutter via the approved method) and create compiling, pinned, empty backend/ and app/ packages.

## You may read
- `practices/credentials/_solutions/.plan/digests/deps-pins.md`
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/.plan/approvals/015.txt`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/015.json`, `practices/credentials/_solutions/.plan/handoffs/020.json`

## You may write
- `practices/credentials/backend/Cargo.toml`
- `practices/credentials/backend/Cargo.lock`
- `practices/credentials/backend/rust-toolchain.toml`
- `practices/credentials/backend/.cargo/**`
- `practices/credentials/backend/.gitignore`
- `practices/credentials/backend/src/lib.rs`
- `practices/credentials/backend/src/bin/**`
- `practices/credentials/app/pubspec.yaml`
- `practices/credentials/app/pubspec.lock`
- `practices/credentials/app/analysis_options.yaml`
- `practices/credentials/app/.gitignore`
- `practices/credentials/app/lib/main.dart`
- `practices/credentials/app/test/smoke_test.dart`
- `practices/credentials/_solutions/.plan/logs/110/**` (raw output)

## Acceptance criteria
- A1 (V4): Exactly the approved pins (approvals/015.txt substitutions applied); `bash practices/credentials/_solutions/.plan/checks/v4-deps.sh` exits 0
- A2 (V3): After `cd backend && cargo fetch --locked` and `cd app && flutter pub get`, `cargo build --offline --locked` and `flutter test --offline` succeed with the network off (log the method used to disable it)
- A3 (V12): No `grade` script/target/bin in Cargo.toml or pubspec.yaml; skeleton compiles with no domain logic yet

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/v4-deps.sh && (cd practices/credentials/backend && cargo build --offline --locked) && (cd practices/credentials/app && flutter test --offline)`
Judged by: node 111 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/110/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/110/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 110 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
