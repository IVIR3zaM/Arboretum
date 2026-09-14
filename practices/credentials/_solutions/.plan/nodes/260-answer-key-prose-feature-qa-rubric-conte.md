# 260 — Answer-key prose: feature-qa, rubric, context-map

Role: worker · Tier: fast · Phase: P4 · Deps: 120, 200

## Goal
Write the examiner's golden prose from the verified artifacts.

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/DESIGN.md`
- `practices/credentials/_solutions/FIX.md`
- `practices/credentials/reference/**`
- `context/cedar/goals.md`
- `context/cedar/best-practices.md`
- `practices/fulfillment/_solutions/rubric.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/120.json`, `practices/credentials/_solutions/.plan/handoffs/200.json`

## You may write
- `practices/credentials/_solutions/feature-qa.md`
- `practices/credentials/_solutions/rubric.md`
- `practices/credentials/_solutions/context-map.md`
- `practices/credentials/_solutions/.plan/logs/260/**` (raw output)

## Acceptance criteria
- A1 (V7): feature-qa.md: the 8 held-back questions with answers and minimal correct behaviour matching FIX-feature.patch (single-use resolved: not enforced in v1; nonce prevents same-VP replay)
- A2 (V10): rubric.md: objective gate (a+a2+b worst-case, max matches grade.sh total) + driving axis items for research pass (FM-16), doc reconciliation (FM-15), reliability/observability (all four axes; noticed the canary lies), plus fulfillment misbehaviour #7/#9 criteria (re-run claims; new tests fail when code is broken)
- A3 (V10): context-map.md: current method did:web, hosted-doc truth, the one load-bearing fact, the webhook budget, the absent alarm, the reserved-domain rule

## Verify
Command: `test -s practices/credentials/_solutions/feature-qa.md && test -s practices/credentials/_solutions/rubric.md && test -s practices/credentials/_solutions/context-map.md`
Judged by: node 261 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/260/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 260 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
