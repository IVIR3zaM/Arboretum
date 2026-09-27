# N01 log

## try 1 · YYYY-MM-DD
exec: DONE · tests 12 passed
- <what changed, in ≤ 3 bullets>
- <any choice made that the brief didn't settle>
verify: FAIL C2
- C2 path:line - problem - expected

## replan 1 · YYYY-MM-DD
- reason: <the note that triggered it> · change: <one line on what the brief now says>

<!--
Format rules (don't copy this comment into a log)
- One append-only file per node, log/<id>.md: what happened in each run of that node. Never edit earlier entries.
- The executor appends `## try K` with its `exec:` line and bullets; the orchestrator appends the `verify:` line
  and the verifier's bullets under it; the planner appends `## replan K`.
- Read by: the next executor (on a retry), the planner (on a replan), and humans. Never by the orchestrator.
-->
