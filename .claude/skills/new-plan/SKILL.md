---
name: new-plan
description: Plan a body of work as a task graph under .plan/<date>-<slug>/ — a small plan.md (graph + state), one brief per node in nodes/, one run log per node in log/ — with every assumption and human approval confirmed up front, before any brief is written. Use when the user asks to plan, decompose or build something too big for one context (a spec, RFC, DESIGN.md, ticket dump or long request), or mentions a task graph, planner/executor/verifier, or plan nodes. Run it afterwards with run-plan.
argument-hint: <what to build or change, or a path to a request>
---

You set up a plan. You don't explore the codebase yourself: the planner does that in its own context.
Templates: `templates/plan.md`, `templates/node.md`, `templates/log.md` in `.claude/skills/new-plan`.

## Layout

```
.plan/<YYYY-MM-DD>-<slug>/
  request.md      the request, verbatim or a pointer to its file    planner only
  plan.md         header, Decisions, Graph: the plan and its state  orchestrator reads only this
  nodes/N01.md    one brief per node: the step's instructions       planner writes; executor, verifier read
  log/N01.md      append-only history of that node's runs           executor, orchestrator, planner append
```

If the project's CLAUDE.md or AGENTS.md says plans live elsewhere, use that location with the same layout.

## Steps

1. **Request.** Use the arguments; if empty, ask one line: what should the plan achieve? Pick the dir: today's date
   (`date +%F`) + a 2–5 word kebab-case slug of the outcome; add `-2` if it exists. Write `request.md`: the request
   text verbatim, or a one-line pointer to the file that holds it.
2. **Outline.** Dispatch `planner` (model opus) with exactly:
   `Outline: <dir> · Templates: .claude/skills/new-plan/templates`
   It writes `plan.md` only, no briefs. Expect `OUTLINED <dir> | nodes: n | waves: w | open: k`.
3. **Confirm, once, up front.** Read `plan.md`. Show the user the goal, the Graph (≤ 25 lines), and the verify command.
   Then ask every `proposed` Decision in one round of AskUserQuestion (up to 4 per call; recommended answer first,
   labelled "(Recommended)"). Those include the human stops the planner found: offer "pre-authorize" first, "keep as
   a live gate" second. Close the round with: approve the graph as shown, or change it.
   - Mark each answered line `confirmed` (append the answer if it isn't the recommendation). Don't change anything else.
   - If an answer changes scope or the graph, dispatch `Revise: <dir> · <answers or feedback, one line each>` and
     repeat this step for any new `proposed` lines only.
4. **Brief.** When no line is `proposed`, dispatch `planner` (model opus):
   `Brief: <dir> · Templates: .claude/skills/new-plan/templates`
   It writes `nodes/*.md` and an empty `log/*.md` per node. Expect `BRIEFED <dir> | nodes: n`.
5. **Ready.** Set `status: READY` in `plan.md` and offer `/run-plan <slug>`. Start it only if the user asked for that.

There is no second approval: briefs are derived from a graph and decisions the user has already confirmed.
Never write briefs or edit the Graph yourself; the planner owns the plan's content.
