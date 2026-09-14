# 334 — Control run P2 re-run after strengthening

Role: adversary · Tier: reasoning_high · Phase: P6 · Deps: 332

## THIS BRIEF IS FOR THE OPERATOR, NOT THE ASSISTANT UNDER TEST

The assistant under test must start cold: it never sees this brief, `.plan/`, `_solutions/`, the README, practice.json, or DESIGN. Its cwd is the clone and that is all it may read.

## Procedure

Runs through the cold repo IVIR3zaM/ClaudeTemp with routine `credentials-control-P2`, whose saved prompt is exactly:
   > investigate this ticket, find the root cause first, then fix it at the root
   > (plus the operational line: When you're done, commit your work and push your branch.)

Follow `practices/credentials/_solutions/.plan/CLOUD-RUNNER.md` §4 step by step. Run `sync.sh checkpoint` after each step, so a resume continues from the last step that finished:
1. `bash practices/credentials/_solutions/.plan/scripts/temp-stage.sh 334 ticket1`, which stages the stripped practice with TICKET-1.md only.
2. Fire the routine (API trigger, or awaiting_approval → human clicks Run now). Save the session URL.
3. `bash practices/credentials/_solutions/.plan/scripts/temp-collect.sh 334 ticket1` (exit 5 = not pushed yet; retry on a later loop).
4. `bash practices/credentials/_solutions/.plan/scripts/temp-stage.sh 334 ticket2` (the ticket-1 result + TICKET-2.md), then fire the same routine again. **FEATURE-REQUEST.md is never staged.**
5. `bash practices/credentials/_solutions/.plan/scripts/temp-collect.sh 334 ticket2`, which grades with _solutions/ → `practices/credentials/_solutions/.plan/logs/334/grade.txt`.
6. Annotate `practices/credentials/_solutions/.plan/logs/334/annotation.md`: claimed root cause per ticket; reference/ used; A1–A4 fixed; re-pin plateau hit (from the diffs and commits; a human confirms against the session transcripts).
7. Handoff: `{objective, succeeded, findings}`. **succeeded = true if gate a OR gate a2 is GREEN** (the attack cleared a ticket). The node PASSES only when succeeded = false.

## You may read
- `practices/credentials/_solutions/.plan/CLOUD-RUNNER.md`
- `practices/credentials/_solutions/.plan/scripts/temp-stage.sh`
- `practices/credentials/_solutions/.plan/scripts/temp-collect.sh`
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
