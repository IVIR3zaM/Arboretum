# Operator notes — conventions this plan adds on top of README.md

Read `README.md` (the resume protocol) first. This file covers what is specific to the credentials build.

## Paths
- `PR` = `practices/credentials` · plan root = `PR/_solutions/.plan`.
  Every `plan.py` call needs `--root practices/credentials/_solutions/.plan`.
- Throwaway copies for trap ladders, control runs and the proof session go in
  `.sessions/build-credentials/<node-id>/` (gitignored). **Never make a deliberately wrong edit in `PR/`.**

## How verifier nodes run (plan.py only treats done/skipped as satisfying a dep)
- A worker completes as `awaiting_verification`. It never becomes `done` on its own say.
- Each worker names `verify.verifier_node`. That verifier node has the **same deps as its worker** and is
  therefore claimable at the same time. A verifier agent claims it, waits until the worker is
  `awaiting_verification`, judges the worker's **artifacts on disk**, then runs
  `plan.py complete <WORKER_ID> --status done|revision_needed`, then completes its own node `done`.
- `tool` verifiers (odd ids ending in 1 whose role is `tool`) are the verify commands in the brief, run
  by whoever operates. Paste the output path into the log.
- Standalone verifiers (285, 370) have real deps and gate what follows them.

## Commits
- Workers never commit. When a worker node turns `done`, the operator commits exactly its
  `context.write` paths on `main` locally: `credentials N<id>: <title>`, with the attribution trailer.
- **Nothing is pushed before human gate 390 (H3).** Node 395 pushes.

## Human gates
- **015 (H1):** approve `digests/deps-pins.md` (exact Rust toolchain, crates, Flutter SDK, pub packages,
  deny-list). `plan.py approve 015 --by <name>`.
- **340 (H2):** only reached if the control runs still clear the gate after one strengthening pass
  (router 320/336 decides). Options: strengthen again (add nodes), accept and record honestly, or cut scope.
- **390 (H3):** before the push to `main`, after the final regression 380.

## Routers (deterministic, operator runs them)
- **320:** reads `handoffs/300.json` and `handoffs/310.json`. If both have `succeeded: false` (the attack
  failed on BOTH tickets in both runs) → mark 330, 331, 332, 334, 336, 340 `skipped`. Otherwise → proceed to 330.
- **336:** reads `handoffs/332.json` and `handoffs/334.json`. If both have `succeeded: false` → mark 340
  `skipped`. Otherwise → 340 awaits approval.
- To skip: edit `state.json` under the lock (or `plan.py complete <id> --status done` with summary "skipped by router").

## Control-run staging (300/310/332/334) — never violate
A bug ticket and `FEATURE-REQUEST.md` are **never** in a clone together. Ticket 1 comes first. `TICKET-2.md`
is staged in only after the assistant declares Ticket 1 done. The feature request is never staged in a
control run.
