# 395 — Merge the build branch into main, push, delete the branch

Role: worker · Tier: fast · Phase: P8 · Deps: 390

## Goal
Land the verified build on main.

## You may read
- `practices/credentials/_solutions/.plan/approvals/390.txt`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/390.json`

## You may write
- `(git: merge + push only)`
- `practices/credentials/_solutions/.plan/logs/395/**` (raw output)

## Acceptance criteria
- A1 (V12): `git checkout main && git pull && git merge --no-ff origin/claude/credentials-build` succeeds with no conflicts; `bash checks/v12-shape.sh` exit 0 on main; `git push origin main` succeeds; no .sessions/ in history; the remote branch claude/credentials-build is deleted afterwards (repo rule: no stray branches)

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/v12-shape.sh && git status --porcelain`
Judged by: node 396 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/395/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/395/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 2. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 395 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
