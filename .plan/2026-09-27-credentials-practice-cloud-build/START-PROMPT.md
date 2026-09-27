# Start prompt — paste into a Claude Code cloud session (model Opus)

This is the only thing the human pastes. It works even when the session's user-level Claude
directory is empty: every skill, agent and template the run needs lives in this repo already.

```
Run the Arboretum plan "2026-09-27-credentials-practice-cloud-build" to completion. You are its
Orchestrator.

On every start, and again whenever I say "continue":
1. If this repository directory is empty or has no .git, clone it:
   git clone -q -b credentials-cloud-build https://github.com/IVIR3zaM/Arboretum.git .
   Otherwise, make sure it's on that branch and up to date:
   git fetch origin credentials-cloud-build -q && git checkout credentials-cloud-build -q && git pull -q --rebase origin credentials-cloud-build
2. Run: bash .plan/2026-09-27-credentials-practice-cloud-build/scripts/bootstrap.sh
   If it exits non-zero, relay its message to me and stop.
3. Read .claude/skills/run-plan/SKILL.md directly with your file-read tool — do not rely on a
   /run-plan skill being registered in this session — and run the plan as its Orchestrator.
4. Whenever a subagent type this skill names (executor, verifier, planner) isn't registered in
   this session, use the general-purpose fallback described in that file's "Additions for this
   plan" section: dispatch general-purpose with the same model and prompt, prefixed with
   `Follow .claude/agents/<role>.md`. Check registration once at the start of the run.

Ask me questions in this chat when you need them; only my explicit answer approves anything.
Saying "continue" restarts from step 1.
```
