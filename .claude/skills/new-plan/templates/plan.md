# <Title in a few words>
status: DRAFT
created: YYYY-MM-DD · updated: YYYY-MM-DD
goal: <one line: the outcome>
verify: <one command that must exit 0 for the whole repo>
commit: per-node
budgets: 2 tries per brief · 2 replans per node

## Decisions

- D1 <assumption the plan rests on> | confirmed
- D2 <assumption or choice> | proposed · recommend: <answer> · alt: <other answer>
- D3 N07 <action that would need a human mid-run> | proposed · recommend: pre-authorize

## Graph

| id | title | type | deps | model | try | rp | status | note |
|----|-------|------|------|-------|-----|----|--------|------|
| N01 | <short title> | exec | - | sonnet/sonnet | 0 | 0 | TODO | |
| N02 | <short title> | exec | N01 | opus/opus | 0 | 0 | TODO | |
| N03 | plan acceptance | check | N01,N02 | -/opus | 0 | 0 | TODO | |

<!--
Format rules (don't copy this comment into a plan)
- This file is the plan and its state, nothing else. Keep it under ~80 lines: no briefs, no findings, no history.
- The request lives in request.md, briefs in nodes/<id>.md, run history in log/<id>.md.
- commit: per-node (one commit per verified node) or none (not a git repo, or the user said so).
- Decisions: every assumption the plan rests on, every choice with more than one reasonable answer, and every
  point where a node would otherwise stop for a human (destructive or outward-facing actions, credentials,
  taste calls). Each is `proposed` until the human answers, then `confirmed` (with the answer if it differs).
  A mid-run stop exists only as a `gate` node whose decision the human chose to keep live.
- Types: exec (executor, then verifier) · check (verifier only) · gate (human, only if kept live in Decisions).
- model: `exec/verify`, `-` where that phase doesn't exist. haiku = mechanical, sonnet = well specified,
  opus = tricky logic or judgement.
- Node status: TODO · RUNNING · VERIFYING · RETRY · REPLAN · WAITING · DONE · BLOCKED.
- Plan status: DRAFT (decisions open) · READY · RUNNING · WAITING · BLOCKED · DONE.
- try: attempts of the current brief. rp: replans used. note: `fail C2,C4`, `blocked: <reason>`, `ask: D5`, or empty.
-->
