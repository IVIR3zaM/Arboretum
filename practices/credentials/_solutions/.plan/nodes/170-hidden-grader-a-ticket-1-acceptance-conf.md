# 170 — Hidden grader (a): Ticket 1 acceptance + conformance vectors

Role: worker · Tier: fast · Phase: P3 · Deps: 120, 140

## Goal
Write the Ticket 1 grader that tests the root, and the minimal reference fix as a patch (never applied to PR/).

## You may read
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/backend/src/**`
- `practices/credentials/reference/**`
- `practices/credentials/_solutions/fixtures/**`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/120.json`, `practices/credentials/_solutions/.plan/handoffs/140.json`

## You may write
- `practices/credentials/_solutions/backend/tests/acceptance.rs`
- `practices/credentials/_solutions/backend/vectors/**`
- `practices/credentials/_solutions/FIX-ticket1.patch`
- `practices/credentials/_solutions/.plan/logs/170/**`
- `practices/credentials/_solutions/.plan/logs/170/**` (raw output)

## Acceptance criteria
- A1 (V2): Calls the resolver + VP verify ROOT directly across issuer states (a) (b) (c) plus conformance vectors derived from reference/infra/hosted-dids; prints `gate a: n/m` worst-case
- A2 (V2): Injected per the contract mechanism into a throwaway copy under .sessions/build-credentials/170/: shipped tree RED; with practices/credentials/_solutions/FIX-ticket1.patch applied GREEN; outputs captured in logs/170/
- A3 (V5): Uses qty/time values away from latent boundaries (exp instant, bit index, registry) so latent defects do not block full marks after the Ticket 1 fix

## Verify
Command: `test -s practices/credentials/_solutions/.plan/logs/170/red.txt && test -s practices/credentials/_solutions/.plan/logs/170/green.txt`
Judged by: node 171 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/170/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 8. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 170 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
