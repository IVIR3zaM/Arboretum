# Plan Runbook

Copied to `.plan/README.md`. Any agent starting cold reads this first.

## Resume protocol

1. Read `.plan/state.json` ONLY. Not the graph, not the ledger.
2. Ask for work:
   `python3 .plan/scripts/plan.py next --role worker`
3. Claim it:
   `python3 .plan/scripts/plan.py claim <ID> --agent <your-name>`
4. Read `.plan/nodes/<ID>*.md`, the files in its `read[]`, and the dependency
   handoffs. **Nothing else.** If you need a file that is not listed, stop and
   complete as `blocked`, naming that file. Do not go look.
5. Work. Raw output to `.plan/logs/<ID>/round-K.txt`.
6. Run the node's verify command yourself. Never hand off on a red command.
7. Hand off:
   `python3 .plan/scripts/plan.py complete <ID> --status awaiting_verification \
      --summary "..." --artifacts "path1,path2" --logs ".plan/logs/<ID>/round-2.txt"`
8. If you hit `max_rounds` without meeting acceptance: complete as `blocked` with a
   reason. Stop. Do not expand scope to make progress feel like it is happening.

Verifiers do the same with `--role verifier`, judging the **artifacts on disk** —
never the worker's summary — and complete as `done` or `revision_needed`.

A node `in_progress` past its lease is reclaimable: `plan.py reap`.
Nothing else in this system needs to survive a crash.

## Operator commands

```
plan.py status                 # counts, blocked nodes, parallel width available now
plan.py validate               # invariants: cycles, self-verification, token budgets
plan.py reap                   # release expired leases
plan.py approve <ID> --by NAME # clear a human gate
```

## Running several agents

Claims are atomic under a lockfile, so you can run N workers against the same plan
directory concurrently. `plan.py status` reports the parallel width available right now —
start that many, not more.

Point each agent at the model tier its role calls for (see `.plan/MODELS.yaml`).
Workers run constantly and should be cheap. Verifiers fire rarely and should be strong.

## Statuses

```
pending  ready  in_progress  awaiting_verification  awaiting_adversary
awaiting_approval  revision_needed  blocked  done  skipped
```
