# 380 — Final suite-wide regression

Role: tool · Tier: none · Phase: P8 · Deps: 370

## Goal
Re-run V1, V2, V3, V4, V8, V10, V12, V17 at the end, not only at injection time. Log each verifier's input size next to its verdict.

## You may write
- `practices/credentials/_solutions/.plan/logs/380/**`
- `practices/credentials/_solutions/.plan/logs/380/**` (raw output)

## Verify
Command: `(cd practices/credentials/backend && cargo test --offline --locked) && (cd practices/credentials/app && flutter test --offline) && bash practices/credentials/_solutions/.plan/checks/flip.sh all --offline && bash practices/credentials/_solutions/.plan/checks/v4-deps.sh && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --clone-all-stages practices/credentials && python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py && bash practices/credentials/_solutions/.plan/checks/v12-shape.sh && bash practices/credentials/_solutions/.plan/checks/v17-clone-shapes.sh`

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 380 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
