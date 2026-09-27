---
name: run-plan
description: Run or resume a plan made by new-plan (.plan/<date>-<slug>/plan.md) as the Orchestrator — dispatch fresh executor and verifier subagents node by node in parallel waves, commit each verified node, retry on findings, replan broken briefs, and stop for the human only when nothing else can run. Use when the user asks to run, continue, resume or execute a plan, or to pick up the next piece of planned work.
argument-hint: [plan slug; empty = suggest the next open plan]
---

You are the Orchestrator. You never write product code. Keep your context near-empty: you read `plan.md`,
dispatch agents, route their one-line replies and edit status cells. Never read briefs (`nodes/`), logs (`log/`),
diffs, source or test output, and never paste an agent's reply to the user.

## 1. Pick the plan

- With an argument: match `.plan/*<arg>*/plan.md`. If several match, ask.
- Without: `grep -H '^status:' .plan/*/plan.md`. Suggest the first RUNNING, WAITING or BLOCKED plan, else the oldest
  READY. Confirm with AskUserQuestion (suggestion first, up to 3 other open plans). A DRAFT plan goes back to
  `/new-plan`'s confirm step. If every plan is DONE, say so.

## 2. Load the state

Read `plan.md`: that is the whole state. Re-read it only after the planner has edited it.
- Resume what was in flight (a stop is not a failure; no budget is spent): RUNNING → dispatch the executor again at the
  same try (the tree may hold a partial attempt); VERIFYING → the verifier again; REPLAN → the planner again.
- Set `status: RUNNING` and `updated:` to today.

## 3. Run waves until every node is DONE

1. **Ready set:** TODO or RETRY nodes whose deps are all DONE. Gate nodes and WAITING nodes are held for step 7.
2. **Execute:** per ready `exec` node, set RUNNING and `try +1` in its row. Dispatch the wave in one message
   (parallel Agent calls, `subagent_type: executor`, model = the node's exec model):
   `Plan: <dir> · Node: N03 · Try: 2`
3. **Route executor replies:** `DONE N03 …` → VERIFYING. `BLOCKED N03: <reason>` → note `blocked: <reason>` → Replan.
   A crash or malformed reply → dispatch once more; if it recurs, stop and tell the user.
4. **Verify** only once every executor of the wave has replied. Dispatch the verifiers in one message
   (`subagent_type: verifier`, model = the node's verify model): `Plan: <dir> · Node: N03 · Try: 2`.
   `check` nodes start here. A check that needs tools the verifier lacks (e.g. a browser) goes to `general-purpose`
   with the same line plus `Follow .claude/agents/verifier.md; write only where it allows.` (so check nodes can
   still write `$P/runs/<node>/`).
5. **Route verifier replies:**
   - `PASS N03` → append `verify: PASS` to `log/N03.md`, set DONE, clear note. With `commit: per-node`, commit that
     node alone: `grep -m1 '^Write:' <dir>/nodes/N03.md` for its paths, then
     `git add -A -- <those paths that exist> <dir>` and message `<slug> N03: <title>`. One commit per node, id order.
   - `FAIL N03` + bullets → append `verify: FAIL <ids>` and the bullets, verbatim, to `log/N03.md`; set note
     `fail <ids>`. A check node, a criterion also in the previous note, or try = 2 → Replan. Otherwise RETRY.
   - After the wave's commits, `git status --short` must be empty. Leftovers are edits outside a Write set: stop and
     tell the user.
6. **Replan:** if rp = 2 → BLOCKED; hold it for step 7 and keep running nodes that don't depend on it. Otherwise set
   REPLAN, reset the node's uncommitted work (`git restore --staged --worktree -- <Write paths>` and
   `git clean -fd -- <Write paths>`; skip with `commit: none`) and dispatch `planner` (model opus):
   `Replan: <dir> · Node: N03 · Reason: <note>`. Replies: `REPLANNED N03[,N05]` or `SPLIT N03 -> N03a,N03b`
   (rows and briefs already edited; re-read `plan.md`), or `ASK N03: D7` (it added a `proposed` Decision: set the
   node WAITING, note `ask: D7`, hold it for step 7).
7. **Human, last and batched.** Only when the ready set is empty and nothing is in flight: collect every held item —
   `proposed` Decisions, live gate nodes whose deps are DONE, BLOCKED nodes — and ask them all in one round of
   AskUserQuestion (recommended answer first). Record answers in `plan.md` (Decisions → `confirmed`; gate → DONE and
   commit `plan.md`, or its defects appended to `log/<id>.md` → Replan; ASK → dispatch `Revise: <dir> · Node: N03 ·
   D7 confirmed`; BLOCKED → the user's call: new brief via Replan with rp reset, skip, or stop). Then continue waves.
8. **Report** one line per wave: `wave 2: N03 ✓ · N04 retry (C2) · next: N05, N06`.

Write every status change into `plan.md` before the dispatch that depends on it. Edit the row; never rewrite the file.

## 4. Finish

All DONE: set `status: DONE` and `updated:`, commit `plan.md`, and report in ≤ 5 lines: goal met, commits, retries and
replans used, follow-ups.

## Pausing

The user may interrupt at any time and a rate or context limit may stop you; `plan.md` already holds the state. Say
`Paused at <node>; /run-plan <slug> resumes.` Never re-read finished work to catch up.

## Additions for this plan (credentials-cloud-build)

`$P` below is `.plan/2026-09-27-credentials-practice-cloud-build`.

1. **Bootstrap on start or resume.** On a Linux host: switch to or fetch `credentials-cloud-build`, then run
   `bash $P/scripts/bootstrap.sh`. If it exits non-zero, relay its message to the human and stop. On a non-Linux
   host (the local Mac), run no bootstrap installs. When node N03 is reached there, tell the human to run
   `bash $P/scripts/handoff.sh` and paste the printed prompt into a cloud session, and stop without marking N03
   DONE.
2. **N03 in the cloud.** If N03 is not DONE, set it DONE, commit `plan.md` and push.
3. **Push after every commit.** Run `git push origin credentials-cloud-build`. If the push fails, stop and tell
   the human.
4. **`general-purpose` fallback.** Whenever a subagent type the skill names (`executor`, `verifier`, `planner`)
   isn't registered, dispatch `general-purpose` with the node's model and the line
   `Follow .claude/agents/<role>.md` prepended to the usual one-line prompt. The session may have started on
   `main`, or with an empty user-level `.claude` dir, so check registration once at start and use the fallback for
   every role that's missing.
5. **Planner templates.** The planner's templates are at `.claude/skills/new-plan/templates`.
6. **Finish: delete the branch.** After the final `plan.md` commit and push, switch to `main` and delete
   `credentials-cloud-build` locally and on origin.

## Rules for every role

- Between agents pass paths and ids, never file contents. Replies are the one-line formats in the agent files.
- Every attempt is a fresh agent; `log/<id>.md` is the only thing that carries over.
- A retry fixes the work (verifier FAIL). A replan fixes the brief (executor BLOCKED, a criterion failing twice, tries
  used up). The human fixes the plan (replans used up, or a decision nobody confirmed).
- Nobody guesses a behavior-changing decision mid-run: executors report BLOCKED, the planner replies ASK.
