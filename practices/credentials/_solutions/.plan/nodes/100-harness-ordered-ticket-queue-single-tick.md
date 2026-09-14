# 100 — Harness: ordered ticket queue + single TICKET.md

Role: worker · Tier: fast · Phase: P1 · Deps: 030

## Goal
Generalize the harness from one TICKET.md to an ordered ticket queue while keeping the single-ticket shape working unchanged for existing practices.

## You may read
- `harness/DESIGN.md`
- `AGENTS.md`
- `context/cedar/generation-spec.md`
- `context/cedar/templates/practice.template.json`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- `practices/credentials/_solutions/.plan/checks/v17-clone-shapes.sh`
- `practices/credentials/_solutions/.plan/checks/v12-shape.sh`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/030.json`

## You may write
- `harness/DESIGN.md`
- `AGENTS.md`
- `practices/credentials/_solutions/.plan/logs/100/**` (raw output)

## Acceptance criteria
- A1 (V17): harness/DESIGN.md §0 and AGENTS.md rules 3-4 describe work items as either a single TICKET.md or an ordered queue declared in practice.json -> workItems.staged[]; the next ticket is handed over when the previous one lands; FEATURE-REQUEST.md at phase 3; a bug ticket and the feature request are never in the clone together
- A2 (V17): The setup procedure stays a single ```bash block under `## Running a mode today` and `bash practices/credentials/_solutions/.plan/checks/v17-clone-shapes.sh` exits 0 for deliveries, fulfillment and the queue fixture
- A3 (V17): The control-run paragraph states that control runs stage work items the same way (no ticket + feature request together)
- A4 (V12): `bash practices/credentials/_solutions/.plan/checks/v12-shape.sh --harness-only` exits 0; the AGENTS.md layout table's `_solutions/` row mentions a build plan (`.plan/`) as a legitimate occupant; no practice's bug or domain is named

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/v17-clone-shapes.sh && bash practices/credentials/_solutions/.plan/checks/v12-shape.sh --harness-only`
Judged by: node 101 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/100/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/100/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 100 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
