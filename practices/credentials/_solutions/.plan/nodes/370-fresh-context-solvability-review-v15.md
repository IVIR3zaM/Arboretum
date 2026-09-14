# 370 — Fresh-context solvability review (V15)

Role: verifier · Tier: reasoning_high · Phase: build · Deps: 360

## Goal
Standalone gate. Do not read .plan/handoffs or builder logs; judge the practice as shipped.

## You may read
- `practices/credentials/**`
- `generator/CONTRACT.md`
- `context/cedar/generation-spec.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/360.json`

## You may write
- `practices/credentials/_solutions/.plan/logs/370/**`
- `practices/credentials/_solutions/.plan/handoffs/370.json`
- `practices/credentials/_solutions/.plan/logs/370/**` (raw output)

## Acceptance criteria
- A1 (V15): Verdict per CONTRACT acceptance-checklist item; solvable at XL in stated time; each discipline reachable without _solutions/; not over-scoped. If over-scoped, name the backend-only fallback and complete as awaiting_approval (routes to a human)

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 370 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
