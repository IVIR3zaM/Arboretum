# Distribution — how people play and train themselves

How a learner uses this, from today's self-serve repo to a later hosted playground. The design
principle throughout: **tool-agnostic core, optional Claude-first depth.**

## Today — self-serve, any assistant
1. Clone the repo, open a practice (`practices/deliveries/`), read `README.md`.
2. Work the five phases with **any** AI assistant — Claude Code, Cursor, Copilot, a web chat.
3. `npm run grade` is the portable self-grader (the hidden acceptance oracle). It needs no
   service and no account; it runs locally and scores worst-case across the ambient values.
4. Read `_solutions/rubric.md` only after finishing, to self-assess how you drove.

This already works. The only dependency is a recent Node for the seed kata; other stacks ship
their own runner.

### Keeping the answer key honest
For the seed, `_solutions/` sits in the repo, clearly marked "opening it defeats the kata."
Before any multi-user or competitive use, move the answer key **behind the grader** — ship the
practice without `_solutions/`, and run grading as a service or a sealed package so a learner
can't read the hidden tests, held-back requirements, or fix. (Tracked as a Phase-2 task.)

## Phase 2 — a built harness runner (the three modes)
Today the harness is run by an agent following [`../harness/DESIGN.md`](../harness/DESIGN.md)
and [`../AGENTS.md`](../AGENTS.md); Phase 2 turns that into a tool.
- **Runner CLI** (`arbor read|assess|train <practice>`): implements the three modes, **clones**
  the practice into a session workdir and **jails** the assistant agent to it (never the
  original), **times** the session, runs the grader, and writes the scorecard / debrief. Reports
  time/token **actuals** (time always; tokens when the assistant exposes usage — e.g. Claude
  Code `/cost`, API usage headers) and re-calibrates the Context's estimates from real runs.
- **Multi-agent examiner** (the differentiator): a separate evaluator that reads the learner's
  prompt transcript **and** the result in the cloned folder against its **golden context** (the
  Context version + the practice's `_solutions/` rubric and trap manifest), and scores the
  **driving** axis — reproduced before fixing? gathered requirements? rejected over-build?
  matched altitude? A pass/fail oracle can't see any of that; this is what makes it *training*,
  not a test. Agnostic core still works without it (the oracle alone).

## Phase 3 — hosted playground
- In-browser editor + an assistant + the grader, no local setup; a catalog of practices across
  domains/stacks/tiers; progress tracking and a personal weakness map (which failure modes you
  repeatedly miss); optional team mode and leaderboards.
- The **generator** (`generator/CONTRACT.md`) feeds the catalog: new practices are generated
  from a Context version into the domains/stacks a team actually uses.

## Licensing / openness (decision deferred)
The Context and the generator contract could be open (they're reference knowledge); the
practice catalog and hosted grader are the natural commercial surface. No decision needed for
the research phase — flagged here so it isn't forgotten.

## Audience
Individual engineers leveling up their AI-driving reflexes; teams onboarding to AI-assisted
workflows with practices in their own stack; and (secondarily) interview prep, since the skill
assessment tools now grade is the same skill this trains.
