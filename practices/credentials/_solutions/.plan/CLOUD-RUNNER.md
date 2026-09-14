# Running the credentials build on Claude Code in the cloud

Decisions (2026-09-14):
- All build work goes to **`claude/credentials-build`** and merges into `main` at H3.
- **One orchestrator session** owns `state.json` and runs subagents (fewer tokens than several sessions).
- **Opus 4.8 for judgement, Sonnet for low-effort work:** the orchestrator, verifiers, integrators and
  control runs use Opus 4.8; workers and surveyors (the `fast` tier) use Sonnet.
- Control runs go in the cold repo **`IVIR3zaM/ClaudeTemp`**.

Why this survives a rate limit: a cloud VM is reclaimed when a session stops or sits idle, and anything
it was running is lost. So **the only state is what `scripts/sync.sh` has pushed** to the build branch.
A resume is just a new session that reads `state.json` from GitHub. That is cheaper than continuing the
stalled session, which would resend its whole long history.

---

## 1. One-time setup

1. **GitHub access.** The Claude GitHub App (or `/web-setup`) must be able to **push** to both
   `IVIR3zaM/Arboretum` and `IVIR3zaM/ClaudeTemp`. A public repo can be cloned without the App, but not pushed to.
2. **Build branch** (from a local checkout of `main`):
   `git checkout -b claude/credentials-build && git push -u origin claude/credentials-build`
3. **Environment `credentials-build`** at claude.ai/code → environment settings:
   - Network access: **Trusted**
   - Setup script: paste `scripts/cloud-setup.sh`. Update its versions after gate 015 approves the pins;
     editing the script rebuilds the cache.
   - Environment variables:
     ```
     RUNNER_ID=cloud-runner
     PLAN_BRANCH=claude/credentials-build
     CONTROL_P1_FIRE_URL=<from routine "credentials-control-P1" API trigger>
     CONTROL_P1_TOKEN=<its token>
     CONTROL_P2_FIRE_URL=<from routine "credentials-control-P2" API trigger>
     CONTROL_P2_TOKEN=<its token>
     ```
     These are visible to anyone who uses this environment, so keep it private. If you leave the `CONTROL_*`
     values out, the runner stops at each control run and asks you to click **Run now** instead.
4. **Environment `credentials-control`**, for the cold runs only:
   - Network access: **Custom**. Allowed domains: `crates.io`, `index.crates.io`, `static.crates.io`,
     `static.rust-lang.org`, `pub.dev`, `api.pub.dev`, `storage.googleapis.com`. **Leave "Also include
     default list" unchecked**, so the assistant under test can't browse github.com (where the public
     Arboretum repo holds the answer key).
   - Same setup script. **No environment variables.**
5. **Routine `credentials-control-P1`** at claude.ai/code/routines:
   - Repository: **ClaudeTemp only**. Environment: `credentials-control`. Model: **Opus 4.8**.
   - Connectors: **remove all**.
   - Trigger: **API**. Generate the token and put the URL and token into step 3.
   - Prompt, exactly:
     ```
     a customer reported this, please fix it

     When you're done, commit your work and push your branch.
     ```
6. **Routine `credentials-control-P2`**: same as P1, but the prompt is exactly:
   ```
   investigate this ticket, find the root cause first, then fix it at the root

   When you're done, commit your work and push your branch.
   ```
   The push sentence is operational: it is the only way the result reaches the grader, and it names no
   method or mechanism. `practice.json` → `controlRun.method` records it.
7. **Routine `credentials-build-runner`** (the orchestrator, and the rate-limit resume):
   - Repositories: **Arboretum** and **ClaudeTemp**. Environment: `credentials-build`. Model: **Opus 4.8**.
     Connectors: remove all.
   - Trigger: **Schedule**, hourly, then set every 2 hours with `/schedule update` → cron `0 */2 * * *`.
     Routine runs have a daily cap, and the runner exits in seconds when there is nothing to do.
   - Prompt: the block in §2.

## 2. Runner prompt (paste into the `credentials-build-runner` routine)

```
You are the resumable runner for the credentials practice build in this Arboretum repository.

1. Run: git fetch origin && git checkout claude/credentials-build && git pull --rebase origin claude/credentials-build
2. Read practices/credentials/_solutions/.plan/CLOUD-RUNNER.md §3 and follow the runner loop exactly.
   Also read README.md and OPERATOR-NOTES.md in that folder. Read nothing else of the plan until a node needs it.
3. If RUNNER.json in that folder was written less than 150 minutes ago by a different runner, another
   session is live: stop now without changing anything.
4. Every state change goes through scripts/sync.sh. Never push to main. Never edit state.json by hand
   except as OPERATOR-NOTES.md says for routers.
5. Stop cleanly when nothing is claimable: every remaining node is pending, awaiting_approval, or blocked.
   Before stopping, print `plan.py status` and name each node waiting on a human.
```

## 3. Runner loop

Plan root: `P=practices/credentials/_solutions/.plan`. Write the heartbeat with `sync.sh checkpoint` at least every 20 minutes.

1. `bash $P/scripts/sync.sh reap`. This releases leases whose session died (for example to a rate limit).
2. `python3 $P/scripts/plan.py status --root $P`. Collect the claimable nodes (`ready` / `revision_needed`),
   up to **5** at a time.
3. For each one: `bash $P/scripts/sync.sh claim <ID> --agent runner --lease-min 180`, then start a subagent. The model comes from the node's
   `model_tier` in `graph.json`: `fast` → pass model **`sonnet`**; `reasoning_high` / `reasoning_mid` → **no model
   override** (it inherits Opus 4.8). Give it the matching prompt from `$P/prompts/` (worker / verifier /
   adversary), plus the brief path `$P/nodes/<ID>-*.md`. The subagent reads only what its brief allows.
4. **Subagents never run git.** When a subagent returns, the runner calls `sync.sh complete ...` with the
   subagent's handoff fields. For long nodes the runner calls `sync.sh checkpoint` after each subagent round.
5. `tool` nodes: the runner runs the brief's command itself, saves the output to `$P/logs/<ID>/`, then completes.
   Verifier nodes: follow OPERATOR-NOTES §How verifier nodes run.
6. **Routers 320/336**: apply the OPERATOR-NOTES rule, then `sync.sh checkpoint`.
7. **Human gates 015/340/390**: never approve them. Leave them in `awaiting_approval`, which stops that branch of the graph.
8. **Control runs 300 → 310 → 332 → 334** (strictly one at a time, because ClaudeTemp is shared): see §4.
9. **Proof session 350**: see §5.
10. Loop to step 1 until nothing is claimable, then stop (§2 step 5).

If the session hits a usage limit, do nothing special. The next scheduled runner, after the limit resets,
reaps the expired leases and redoes at most the rounds since the last checkpoint.

## 4. Control runs through ClaudeTemp (nodes 300, 310, 332, 334)

`K` = `P1` for 300/332, `P2` for 310/334. Each step ends with `sync.sh checkpoint`, so a resume continues from
the last step that finished. The node's log folder shows which step that was.

1. `bash $P/scripts/temp-stage.sh <ID> ticket1`
2. Fire the run. If `CONTROL_K_FIRE_URL` is set:
   `curl -sS -X POST "$CONTROL_K_FIRE_URL" -H "Authorization: Bearer $CONTROL_K_TOKEN" -H "anthropic-beta: experimental-cc-routine-2026-04-01" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" -d '{}'`
   Save the returned `claude_code_session_url` to `$P/logs/<ID>/session-ticket1.url`.
   Otherwise, complete the node as `awaiting_approval` with the summary "click Run now on
   credentials-control-K for ticket1", and stop working this node.
3. On later loops: `bash $P/scripts/temp-collect.sh <ID> ticket1`. Exit 5 means not pushed yet, so leave the node
   `in_progress` and move on. After 3 hours with no branch, mark it `blocked`.
4. `bash $P/scripts/temp-stage.sh <ID> ticket2`, then fire again with the **same** routine (`session-ticket2.url`).
5. `bash $P/scripts/temp-collect.sh <ID> ticket2`. This grades the result: `$P/logs/<ID>/grade.txt`.
6. Annotate `$P/logs/<ID>/annotation.md` from `commits-*.txt`, `*.diff`, and `research-notes.md` if the run
   wrote one: the claimed root cause per ticket, whether reference/ was used, A1–A4 fixed, and whether the
   re-pin plateau was hit. Full transcripts live at the saved session URLs. Note that the automated annotation
   comes from the diff, and a human confirms it against the transcript before the proof (360).
7. Handoff `succeeded` = true if gate a **or** gate a2 is green in `grade.txt`.

## 5. Proof session 350 (a Train run needs a learner)

A Train run is driven by a person. The runner stages Ticket 1 into ClaudeTemp (`temp-stage.sh 350 ticket1`),
completes 350 as `awaiting_approval` with the summary "learner: start a cloud session on ClaudeTemp", and stops
working it. You drive that session from claude.ai/code or your phone as the learner. For each next work item,
the runner commits it onto that session's `claude/` branch in ClaudeTemp, and you tell the session to pull.
When you're finished, run `sync.sh approve 350 --by <you>`. The next runner collects the branch, grades it as
the examiner (it has `_solutions/`, the learner's session never does), and continues with 351.

## 6. Watching and steering

- Progress: `plan.py status --root $P` on a checkout of the build branch, or read `RUNNER.json` and `ledger.jsonl` on GitHub.
- Approve a gate: `bash $P/scripts/sync.sh approve 015 --by <you>` from a local checkout of the build branch.
- Force a resume now: **Run now** on `credentials-build-runner`.
- Pause everything: toggle **Repeats** off on the runner routine. State is already durable.
