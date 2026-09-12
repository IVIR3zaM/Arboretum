# Arboretum

> A **flight simulator for AI-assisted development** — deliberate practice on seeded codebases
> where naive prompting provably can't reach the goal.

## Where to start

- **Just want to see it work?** Run the seed kata:
  ```bash
  cd practices/deliveries && node --test test/*.test.ts && npm run grade
  ```
  15 unit tests pass — but the grader reports **0/8**. There's a real bug the tests can't see.
  Fixing it (for every timezone, not just yours) is the exercise.
- **Want to actually train, not just look?** Pick a Context and follow the path
  **read → assess → train** (the [three modes](#how-you-use-it--the-harness-and-its-three-modes)).
  Begin by reading the Context you'll learn: [`context/alder/`](context/alder/).
- **You're an AI agent, or driving one?** Read [`AGENTS.md`](AGENTS.md) — how to run the harness,
  and the rules that matter (clone the practice, jail the assistant to it, never touch the original).
- **Want the reasoning first?** Read [`docs/CONCEPT.md`](docs/CONCEPT.md), or open the visual
  one-pager linked at the bottom.

Everything below explains how it fits together.

---

An arboretum is a living collection of many tree species, grown for study. This one grows
**Contexts** — versioned, tree-named bodies of knowledge about how to use AI coding assistants
well — and turns each into hands-on practice.

Using an AI assistant *well* is a skill of judgment, not typing: reproducing a bug before
fixing it, gathering requirements before delegating, reading before you let the AI change code,
rejecting over-built output, and matching the altitude of the task. Those reflexes are built by
**hitting the traps in a simulator**, not by reading about them.

## The idea in one line
A versioned **Context** (training goals + known AI best practices + known AI failure modes) lets
**any AI agent generate a practice** — a runnable kata with a real hidden bug, an underspecified
feature with a trap, ranked latent defects, and a grading oracle — **in any domain and stack**,
all training the **same points**. The kata is an instance; the Context is the product.

```
Context (versioned, tree-named)  →  Generator (agent contract)  →  Practice (runnable kata)
   context/alder/                      generator/CONTRACT.md          practices/deliveries/
```

## How you use it — the harness and its three modes
The interface is a **harness**: an AI agent (any assistant — the contract is agnostic) that runs
a practice *for* you and *grades how you drove*. It always works on a **throwaway clone** of the
practice, never the original. Three modes, and a path through them:

1. **Read** — understand a Context version's golden knowledge before you try it.
2. **Assess** — drive a practice while an assistant executes your prompts; no live feedback, a
   written debrief at the end showing how each prompting round went.
3. **Train** — drive a practice with live coaching from the harness as you go.

**Suggested path to master a Context:** Read → Assess → Train. See
[`harness/DESIGN.md`](harness/DESIGN.md) for the multi-agent architecture, and
[`AGENTS.md`](AGENTS.md) for how any agent runs the harness today.

## Try the seed kata
```bash
cd practices/deliveries
node --test test/*.test.ts   # 15 tests, all green
npm start                    # tiny end-to-end run
npm run grade                # hidden oracle — 0/8 until you fix the (invisible) bug
```
Then work the five phases in [`practices/deliveries/README.md`](practices/deliveries/README.md):
**understand → fix → feature → improve → review**, with any AI assistant.

## Map
- [`AGENTS.md`](AGENTS.md) — entry point for any AI agent (and you): what's possible, the rules.
- [`harness/DESIGN.md`](harness/DESIGN.md) — the multi-agent harness and the three modes.
- [`docs/CONCEPT.md`](docs/CONCEPT.md) — the model and why it's neither an exam nor a course.
- [`docs/PRIOR-ART.md`](docs/PRIOR-ART.md) — landscape + sources.
- [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) — how people play; the roadmap.
- [`docs/TREE-NAMING.md`](docs/TREE-NAMING.md) — how Context versions are named.
- [`context/alder/`](context/alder/) — **Context v1**: goals, best-practices, failure-modes,
  generation-spec, templates.
- [`generator/CONTRACT.md`](generator/CONTRACT.md) — how any agent generates a new practice.
- [`practices/deliveries/`](practices/deliveries/) — the seed kata (aligned to `alder@1.1.0`).
- [`practices/fulfillment/`](practices/fulfillment/) — an XL Cedar kata: inventory availability &
  order confirmation, React + TS/Node full stack (aligned to `cedar@1.0.0`).

## What this is not
Not an assessment/hiring tool, not a course, not domain-locked. See [`docs/CONCEPT.md`](docs/CONCEPT.md).

## Status
Research + architecture phase. **In:** Context v1, the seed kata, the generator contract, the
harness design, the docs, a one-pager. **Out (next):** generating more katas, a built harness
runner for the three modes with time/token actuals, the multi-agent examiner, a hosted
playground.

## License
[Apache-2.0](LICENSE) © 2026 Reza Maghoul (see [`NOTICE`](NOTICE)). Permissive with a patent
grant — see [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) on keeping a future commercial surface
separate.
