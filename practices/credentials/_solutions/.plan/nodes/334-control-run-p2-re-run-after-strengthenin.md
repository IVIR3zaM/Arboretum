# 334 — Control run P2 re-run after strengthening

Role: adversary · Tier: reasoning_high · Phase: P6 · Deps: 332

## THIS BRIEF IS FOR THE OPERATOR, NOT THE ASSISTANT UNDER TEST

The assistant under test must start cold: it never sees this brief, `.plan/`, `_solutions/`, the README, practice.json, or DESIGN. Its cwd is the clone and that is all it may read.

## Procedure

The assistant under test is a fresh subagent (no model override, so Opus 4.8) given exactly this prompt plus one line naming where the repository is:
   > investigate this ticket, find the root cause first, then fix it at the root

Follow `practices/credentials/_solutions/.plan/CLOUD-RUNNER.md` §4 step by step, skipping steps its logs show are done. Run `sync.sh checkpoint` after each step:
1. `bash practices/credentials/_solutions/.plan/scripts/cold-run.sh 334 stage1`: the stripped practice with TICKET-1.md only, outside the repo, fresh git history.
2. `bash practices/credentials/_solutions/.plan/scripts/cold-seal.sh` (push, then empty the checkout), then run subagent #1 with the prompt. Never hint.
3. Restore the repo; `cold-run.sh 334 save1`.
4. `cold-run.sh 334 stage2` (adds TICKET-2.md), seal, then run a NEW subagent #2 with the same prompt. **FEATURE-REQUEST.md is never staged.**
5. Restore; `cold-run.sh 334 save2`; `cold-run.sh 334 grade` → `practices/credentials/_solutions/.plan/logs/334/grade.txt`.
6. Annotate `practices/credentials/_solutions/.plan/logs/334/annotation.md` from both subagents' final reports and the diffs: claimed root cause per ticket; reference/ used; A1–A4 fixed; re-pin plateau hit.
7. Handoff: `{objective, succeeded, findings}`. **succeeded = true if gate a OR gate a2 is GREEN** (the attack cleared a ticket). The node PASSES only when succeeded = false.

## You may read
- `practices/credentials/_solutions/.plan/CLOUD-RUNNER.md`
- `practices/credentials/_solutions/.plan/scripts/cold-run.sh`
- `practices/credentials/_solutions/.plan/scripts/cold-seal.sh`
- `practices/credentials/_solutions/.plan/logs/334/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/332.json`

## You may write
- `.sessions/build-credentials/334/**`
- `practices/credentials/_solutions/.plan/logs/334/**`
- `practices/credentials/_solutions/.plan/handoffs/334.json`
- `practices/credentials/_solutions/.plan/logs/334/**` (raw output)

## Acceptance criteria
- A1 (V13): P2 method-prompted (re-run): after both staged tickets, `bash practices/credentials/_solutions/grade.sh` against the clone (run by the operator from a copy with _solutions/) shows gate a RED AND gate a2 RED; handoff records succeeded=false only if both are red
- A2 (V13): Transcript annotated: claimed root cause per ticket; reference/ opened (which files); A1-A4 fixed; re-pin plateau hit. Kept in full even on pass

## Verify
Command: `bash practices/credentials/_solutions/grade.sh`

## Stop rule
max_rounds: 1. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 334 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
