# 360 — Write proof HTML + practice.json controlRun/trainRun

Role: worker · Tier: fast · Phase: P7 · Deps: 350

## Goal
Record the runs honestly; every figure must come from a captured log.

## You may read
- `practices/credentials/_solutions/.plan/logs/300/**`
- `practices/credentials/_solutions/.plan/logs/310/**`
- `practices/credentials/_solutions/.plan/logs/332/**`
- `practices/credentials/_solutions/.plan/logs/334/**`
- `practices/credentials/_solutions/.plan/logs/350/**`
- `practices/credentials/_solutions/.plan/approvals/**`
- `practices/credentials/practice.json`
- `practices/fulfillment/_solutions/proof-train-2026-09-13.html`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/350.json`

## You may write
- `practices/credentials/_solutions/proof-train-*.html`
- `practices/credentials/practice.json`
- `practices/credentials/_solutions/.plan/logs/360/**` (raw output)

## Acceptance criteria
- A1 (V16): Proof records harness/mode, date, model, both control runs (P1, P2; re-runs if any) with scores and per-ticket claimed root causes, and per phase: prompt → behaviour → designed trap → examiner output → real outcome; `python3 practices/credentials/_solutions/.plan/checks/v16-proof-numbers.py` exits 0
- A2 (V13): practice.json controlRun has `casual` and `methodPrompted` entries (date, method incl. staged delivery, per-gate scores, reference opened, axes caught, claimed root causes, finding)

## Verify
Command: `python3 practices/credentials/_solutions/.plan/checks/v16-proof-numbers.py practices/credentials/_solutions/proof-train-*.html --logs practices/credentials/_solutions/.plan/logs`
Judged by: node 361 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/360/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 4. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 360 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
