# N01 <short title>
Do: <2–4 sentences: what changes and why. No backstory.>
Context: <only what this node needs from the Decisions, restated in a line; spec sections and file:line to read>
Read: <paths the executor needs>
Write: <paths or globs; disjoint from every node that can run in the same wave>
Test first: <the failing test's behavior, if the project has tests; else `-`>
Done when:
- C1 <falsifiable statement>
- C2 the plan's verify command exits 0

<!--
Format rules (don't copy this comment into a brief)
- One brief per file, nodes/<id>.md. Self-contained: the executor and verifier read this file and nothing else
  of the plan. Cite paths and file:line; never paste code or spec text.
- Only the planner writes briefs. Run history goes in log/<id>.md, never here.
- A check node has Do + Done when only. A gate node has Do (what the human decides) + Done when.
-->
