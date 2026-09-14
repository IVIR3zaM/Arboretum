# Running the credentials build in one Claude Code cloud session

**What you do:**
1. Open claude.ai/code. Select the **Arboretum** repository and the **Default** environment.
2. Choose model **Opus 4.8**, and a permission mode that doesn't stop for every command.
3. Paste the prompt from [`START-PROMPT.md`](START-PROMPT.md).
4. Answer when it asks you something: the gates 015, 340 and 390, and your learner turns in the proof session.
5. If it stops on a usage limit, type **`continue`** once the limit resets, or paste the same prompt into a new session.

The rest of this file is for the orchestrator.

---

## 0. Why this survives rate limits
A cloud VM is reclaimed when a session stops or sits idle, and anything it was running is lost. So **the only
state is what `scripts/sync.sh` has pushed** to `claude/credentials-build`. Every start and every resume runs
the same Setup, which rebuilds the VM, restores the repo if it's empty, and reads `state.json` from GitHub.
Tasks are claimed for 180 minutes, and `reap` releases a task whose session died.

## 1. Setup (on every start or resume)
1. If the repository directory is empty or has no `.git` (a cold run emptied it), restore it:
   `git clone -q -b claude/credentials-build https://github.com/IVIR3zaM/Arboretum.git .`
2. `bash practices/credentials/_solutions/.plan/scripts/bootstrap.sh`: checks out the branch, installs Flutter
   and Rust if missing, proves it can push, reaps expired leases, and prints status. If it says it cannot push,
   tell the user exactly what it printed and stop.
3. If `logs/<id>/cold-dir.txt` exists for an `in_progress` adversary or proof node, go straight to §4 or §5 for that node.
4. Read `README.md` and `OPERATOR-NOTES.md` in `practices/credentials/_solutions/.plan/`.

## 2. Loop
`P=practices/credentials/_solutions/.plan`
1. `python3 $P/scripts/plan.py status --root $P` (`--root` always goes after the subcommand). Take up to **5** claimable nodes (`ready` / `revision_needed`),
   lowest id first. Never start a node while a cold run (§4/§5) is sealed.
2. For each: `bash $P/scripts/sync.sh claim <ID> --agent orchestrator --lease-min 180`.
3. Run it by role:
   - **worker / integrator / verifier:** start a subagent with the matching `$P/prompts/<role>.md` text and
     the brief path `$P/nodes/<ID>-*.md`. **Model:** `model_tier` `fast` → model **`sonnet`**;
     `reasoning_high` / `reasoning_mid` → **no override** (inherits Opus 4.8). Tell it: never run git; report
     its handoff fields back to you.
   - **tool:** run the brief's command yourself; save the output to `$P/logs/<ID>/output.txt`.
   - **router (320, 336):** apply the rule in OPERATOR-NOTES.md.
   - **human_gate (015, 340, 390):** §3.
   - **adversary (300, 310, 332, 334):** §4, one at a time, with nothing else running.
   - **350 proof session:** §5.
4. When a subagent returns: `bash $P/scripts/sync.sh complete <ID> --status <status> --summary "..." --artifacts "..." --logs "..."`.
   For verifier nodes, also complete the judged worker as `done` or `revision_needed` (OPERATOR-NOTES).
5. Every ~20 minutes, and after every subagent round on a long node: `bash $P/scripts/sync.sh checkpoint`.
6. Repeat. When nothing is claimable and nothing is running: print status, name what is waiting on the user, and stop.

## 3. Human gates: ask in chat
Quote what needs deciding (for 015, the pin table from `digests/deps-pins.md`; for 340, the control-run scores
and your options; for 390, `git log --oneline main..claude/credentials-build | wc -l`, the final grade and the
proof path). Wait for an explicit answer. Then:
`bash $P/scripts/sync.sh approve <ID> --by "<user> (chat)" --note "<their words>"`.
Never approve on your own judgement. After 015, update the versions in `scripts/cloud-setup.sh` to the
approved pins as part of node 110.

## 4. Control runs 300 → 310 → 332 → 334 (cold subagent)
`PROMPT` = the node brief's prompt: P1 `a customer reported this, please fix it`, or P2 `investigate this ticket,
find the root cause first, then fix it at the root`. Look at the node's logs to see which steps are already done,
and skip them.
1. `bash $P/scripts/cold-run.sh <ID> stage1`, then `bash $P/scripts/sync.sh checkpoint`.
2. `bash $P/scripts/cold-seal.sh`. The repo is now empty.
3. Start a **fresh general-purpose subagent, no model override** (Opus 4.8), with exactly this prompt and nothing else:
   ```
   <PROMPT>

   The repository is at <COLD_DIR from logs/<ID>/cold-dir.txt, printed by stage1>.
   ```
   Do not answer its questions with hints. If it asks something, reply only "use your judgement". Let it finish.
4. Restore the repo (§1 step 1), then `bash $P/scripts/cold-run.sh <ID> save1` and `sync.sh checkpoint`.
5. `bash $P/scripts/cold-run.sh <ID> stage2`, `sync.sh checkpoint`, `cold-seal.sh`, then a **new** fresh
   subagent with the same PROMPT and path. Ticket 2 arrives like a new ticket, in a fresh context.
6. Restore, `cold-run.sh <ID> save2`, `cold-run.sh <ID> grade`, `sync.sh checkpoint`.
7. Write `$P/logs/<ID>/annotation.md` from both subagents' final reports and the diffs: the root cause it claimed
   per ticket, whether it read `reference/` (it usually says), which of A1–A4 it fixed, and whether it re-pinned.
8. Complete the node. `succeeded` = true if gate **a** or gate **a2** is green in `grade.txt`. The node passes
   only when both are red.

## 5. Proof session 350 (Train mode, relayed)
1. `cold-run.sh 350 stage1`, `sync.sh checkpoint`. Tell the user: "Proof session ready. Send your learner prompts
   here; I'll forward each one verbatim to the assistant." Wait for their first prompt.
2. `cold-seal.sh`. Start a fresh subagent (no override) with the user's prompt plus `The repository is at
   <COLD_DIR>.` Continue the **same** subagent with SendMessage for each later learner prompt, verbatim.
   Relay its replies to the user word for word. You are also the trainer: after each reply you may add a short
   coaching note, clearly labelled as coaching. Never forward coaching to the subagent.
3. When the user says Ticket 1 has landed: restore, `cold-run.sh 350 save1`, `stage2`, checkpoint, seal, then tell
   the subagent `TICKET-2.md has arrived in the repository.` When the user reaches phase 3: restore, copy
   `practices/credentials/FEATURE-REQUEST.md` into COLD_DIR (the tickets are done by then), checkpoint, seal, and
   tell the subagent `FEATURE-REQUEST.md has arrived in the repository.`
4. When the user ends the session: restore, `cold-run.sh 350 save2`, `cold-run.sh 350 grade`. Save the relayed
   transcript to `$P/logs/350/transcript.md` and the baseline and final unit + grade outputs to `logs/350/`.
   Checkpoint, then complete 350 as `awaiting_verification`.

## 6. Rate limits and crashes
Nothing special to do. On "continue" or a fresh paste, run §1. Work since the last checkpoint is redone.
A cold run that was sealed restarts from its last saved step, because its logs show which steps finished.

## 7. Optional: unattended resume
If you don't want to type "continue" yourself, create one routine at claude.ai/code/routines. Use Arboretum,
the Default environment, Opus 4.8, and a schedule of every 2 hours. Its prompt is START-PROMPT.md with this line
added at the top: `Started by a routine: if practices/credentials/_solutions/.plan/RUNNER.json on
claude/credentials-build was written less than 150 minutes ago, stop immediately.` Human gates still wait for
you in whichever session asked.
