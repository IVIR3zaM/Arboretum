# 280 — Learner docs, work items, practice.json, move DESIGN.md

Role: worker · Tier: fast · Phase: P5 · Deps: 100, 260, 270

## Goal
Write the learner-facing material and the manifest so the practice is complete and nothing in the clone coaches.

## You may read
- `practices/credentials/DESIGN.md`
- `practices/credentials/_solutions/.plan/digests/build-contract.md`
- `practices/credentials/_solutions/trap-manifest.md`
- `practices/credentials/_solutions/rubric.md`
- `context/cedar/templates/practice.template.json`
- `context/cedar/generation-spec.md`
- `practices/fulfillment/README.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- Dependency handoffs: `practices/credentials/_solutions/.plan/handoffs/100.json`, `practices/credentials/_solutions/.plan/handoffs/260.json`, `practices/credentials/_solutions/.plan/handoffs/270.json`

## You may write
- `practices/credentials/README.md`
- `practices/credentials/TICKET-1.md`
- `practices/credentials/TICKET-2.md`
- `practices/credentials/FEATURE-REQUEST.md`
- `practices/credentials/practice.json`
- `practices/credentials/DESIGN.md`
- `practices/credentials/_solutions/DESIGN-blueprint.md`
- `practices/credentials/_solutions/.plan/logs/280/**` (raw output)

## Acceptance criteria
- A1 (V12): README.md lifts the domain primer (all mermaid diagrams) + the five-phase flow + estimate; DESIGN.md moved to _solutions/DESIGN-blueprint.md; `v12-shape.sh` exits 0
- A2 (V8): TICKET-1.md / TICKET-2.md carry DESIGN's symptom text only; FEATURE-REQUEST.md is the PM ask + expected surface with the ⚠️ hint DROPPED; lint over the staged clones exits 0
- A3 (V10): practice.json validates against the template, has no `status`, declares commands.{install,test,grade} (grade = bash _solutions/grade.sh, test/install match the pinned stacks), workItems.staged = [TICKET-1.md, TICKET-2.md, FEATURE-REQUEST.md], grader.max = grade.sh total, latentDefects = probe count, estimate recomputed per spec method and marked provisional; controlRun left as placeholders; `v10-manifest.py` exits 0

## Verify
Command: `bash practices/credentials/_solutions/.plan/checks/v12-shape.sh && python3 practices/credentials/_solutions/.plan/checks/v10-manifest.py && python3 practices/credentials/_solutions/.plan/checks/v8-coaching-lint.py --clone-all-stages practices/credentials`
Judged by: node 281 (reads artifacts on disk, never your summary)

## Rules
- Never commit. Never make a deliberately wrong edit in `practices/credentials/` — throwaway copies go in `.sessions/build-credentials/280/`.
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`python3 practices/credentials/_solutions/.plan/scripts/plan.py --root practices/credentials/_solutions/.plan complete 280 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
