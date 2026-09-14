# 030 — Author assertion scripts + self-tests

Role: worker · Tier: fast · Phase: P0 · Deps: 020

## Goal
Write the mechanical verifiers from the contract BEFORE the things they judge exist, so no builder grades itself and no check is fitted to finished work.

## You may read
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- `AGENTS.md`
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/020.json`

## You may write
- `practices/credentials/_solutions/.plan/checks/**`
- `practices/credentials/_solutions/.plan/logs/030/**` (raw output)

## Acceptance criteria
- A1 (V8): practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py implements V8 over a clone built by practices/credentials/_solutions/.plan/checks/strip-clone.sh, with an inline, justified allow-list
- A2 (V10): practices/credentials/_solutions/.plan/checks/v10-manifest.py implements V10 using the manifest and ledger row formats defined in the build contract
- A3 (V12): practices/credentials/_solutions/.plan/checks/v12-shape.sh implements V12 against `git diff --name-only credentials-v0-baseline`; `--harness-only` mode allows only harness/DESIGN.md + AGENTS.md
- A4 (V4): practices/credentials/_solutions/.plan/checks/v4-deps.sh implements V4 over Cargo.lock / pubspec.lock using the deny-list from V4
- A5 (V16): practices/credentials/_solutions/.plan/checks/v16-proof-numbers.py extracts every `n/m` score and exit code from a proof HTML and fails if one is missing from the named session logs
- A6 (V17): practices/credentials/_solutions/.plan/checks/v17-clone-shapes.sh executes the ```bash block under `## Running a mode today` in AGENTS.md (placeholders <id>/<stamp> substituted) against deliveries, fulfillment and a queue fixture in $TMPDIR, and asserts the three clone listings from V17
- A7 (V8): practices/credentials/_solutions/.plan/checks/strip-clone.sh <practice> <dest> [--stage TICKET-1.md|TICKET-2.md|FEATURE-REQUEST.md ...] builds a harness-shaped clone; never places a ticket and FEATURE-REQUEST.md together (exits non-zero if asked to)
- A8 (V2): practices/credentials/_solutions/.plan/checks/flip.sh <a|a2|b|all [--offline]|ladder ticket1|ladder ticket2|ladder feature> copies practices/credentials to a fresh dir under .sessions/build-credentials/flip/, applies the named _solutions patches per the contract's injection mechanism, runs the grade command(s), and asserts the expected RED/GREEN pattern from V2/V5/V6/V7; it never touches practices/credentials
- A9 (V12): bash practices/credentials/_solutions/.plan/checks/selftest.sh runs each script against a known-bad and a known-good fixture under practices/credentials/_solutions/.plan/checks/fixtures/ and exits 0 only if every bad fixture fails and every good one passes

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/selftest.sh`
Judged by: node 031 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/030/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/030/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 030 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
