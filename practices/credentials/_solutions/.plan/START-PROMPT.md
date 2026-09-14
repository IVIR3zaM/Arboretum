# Start prompt — paste into a Claude Code cloud session on Arboretum (model Opus 4.8)

```
Run the Arboretum "credentials" practice build plan to completion. You are its orchestrator.

On every start, and again whenever I say "continue":
1. If this repository directory is empty or has no .git, restore it with:
   git clone -q -b claude/credentials-build https://github.com/IVIR3zaM/Arboretum.git .
2. Run: bash practices/credentials/_solutions/.plan/scripts/bootstrap.sh
3. Read practices/credentials/_solutions/.plan/CLOUD-RUNNER.md and follow it exactly from §1.

Rules:
- Every plan state change goes through practices/credentials/_solutions/.plan/scripts/sync.sh, which pushes to
  claude/credentials-build. Never push to main, except node 395 after I approve gate 390.
- Ask me in this chat at human gates 015, 340 and 390, and when the proof session (350) needs my learner prompts.
  Only my explicit answer approves a gate.
- Workers run as subagents on Sonnet; verifiers, integrators and control runs inherit your model.
- Control runs must be cold: follow CLOUD-RUNNER.md §4 exactly (seal the repo before the subagent starts).
- If you hit a usage limit, nothing is lost. When I say "continue", start again from step 1.
```
