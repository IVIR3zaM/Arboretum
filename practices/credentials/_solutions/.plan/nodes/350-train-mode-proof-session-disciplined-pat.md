# 350 — Train-mode proof session (disciplined path)

Role: worker · Tier: reasoning_high · Phase: P7 · Deps: 320, 340

## Goal
Drive the finished practice end-to-end as a disciplined learner would, to prove the intended path converges. In the cloud this is a human-driven session on IVIR3zaM/ClaudeTemp: follow `practices/credentials/_solutions/.plan/CLOUD-RUNNER.md` §5 (stage Ticket 1 with temp-stage.sh, hand over to the learner as awaiting_approval, stage the later items onto the session's claude/ branch, then collect and grade as the examiner).

## You may read
- `AGENTS.md`
- `harness/DESIGN.md`
- `practices/credentials/README.md`
- `practices/credentials/_solutions/rubric.md`
- `practices/credentials/_solutions/trap-manifest.md`
- `practices/credentials/_solutions/.plan/checks/strip-clone.sh`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/320.json`, `practices/credentials/_solutions/.plan/handoffs/340.json`

## You may write
- `.sessions/build-credentials/350/**`
- `practices/credentials/_solutions/.plan/logs/350/**`
- `practices/credentials/_solutions/.plan/logs/350/**` (raw output)

## Acceptance criteria
- A1 (V14): Run per AGENTS.md with separate sub-agents: learner (reads README only), executor (jailed to the clone, `git init` inside it), examiner (fresh context, golden/). Work items staged: TICKET-1 → TICKET-2 after Ticket 1 lands → FEATURE-REQUEST at phase 3; never a ticket + feature together
- A2 (V14): Final `bash practices/credentials/_solutions/grade.sh` against the session result exits 0; baseline and final unit + grade outputs captured verbatim in logs/350/; transcript shows no executor access to _solutions/; `git diff --stat` inside the clone recorded

## Verify
Command: `test -s practices/credentials/_solutions/.plan/logs/350/final-grade.txt`
Judged by: node 351 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/350/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/350/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 3. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 350 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
