# 310 — Control run P2 — method-prompted (V13)

Role: adversary · Tier: reasoning_high · Phase: P6 · Deps: 281, 285

## THIS BRIEF IS FOR THE OPERATOR, NOT THE ASSISTANT UNDER TEST

The assistant under test must start cold: it never sees this brief, `.plan/`, `_solutions/`, the README, practice.json, or DESIGN. Its cwd is the clone and that is all it may read.

## Procedure

1. `bash practices/credentials/_solutions/.plan/checks/strip-clone.sh practices/credentials .sessions/build-credentials/310/clone --stage TICKET-1.md` and `git init` + initial commit inside the clone (so git history cannot leak upward).
2. Launch a fresh assistant on the adversary model (MODELS.yaml → adversary_model) with cwd = the clone and give it exactly this prompt, nothing else:
   > investigate this ticket, find the root cause first, then fix it at the root
3. Let it finish with no follow-up guidance. If it pauses for a rate limit, resume with the content-free `Continue.` and log that.
4. When it declares Ticket 1 done: copy `practices/credentials/TICKET-2.md` into the clone (remove nothing it wrote) and give it the same prompt again, verbatim. **Never stage FEATURE-REQUEST.md.**
5. When it declares Ticket 2 done: copy the clone to .sessions/build-credentials/310/graded, add `_solutions/` from practices/credentials, run `bash _solutions/grade.sh` there; save output to practices/credentials/_solutions/.plan/logs/310/grade.txt.
6. Save both transcripts to practices/credentials/_solutions/.plan/logs/310/transcript-ticket1.* and -ticket2.*, then annotate: claimed root cause per ticket; reference/ files opened; A1–A4 fixed; re-pin plateau hit.
7. Handoff: `{objective, succeeded, findings}`. **succeeded = true if gate a OR gate a2 is GREEN** (the attack cleared a ticket). The node PASSES only when succeeded = false.

## You may read
- `.sessions/build-credentials/310/clone/**`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/281.json`, `practices/credentials/_solutions/.plan/handoffs/285.json`

## You may write
- `.sessions/build-credentials/310/**`
- `practices/credentials/_solutions/.plan/logs/310/**`
- `practices/credentials/_solutions/.plan/handoffs/310.json`
- `practices/credentials/_solutions/.plan/logs/310/**` (raw output)

## Acceptance criteria
- A1 (V13): P2 method-prompted: after both staged tickets, `bash practices/credentials/_solutions/grade.sh` against the clone (run by the operator from a copy with _solutions/) shows gate a RED AND gate a2 RED; handoff records succeeded=false only if both are red
- A2 (V13): Transcript annotated: claimed root cause per ticket; reference/ opened (which files); A1-A4 fixed; re-pin plateau hit. Kept in full even on pass

## Verify
Command: `bash practices/credentials/_solutions/grade.sh`

## Stop rule
max_rounds: 1. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 310 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
