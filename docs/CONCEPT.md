# Concept — a flight simulator for AI-assisted development

## The problem
AI coding assistants are now standard, but using them *well* is an unevenly held skill. The
failures are not about typing: they are about **judgment under an eager assistant** — trusting a
green suite, shipping plausible-but-wrong logic, skipping requirements, over-building a small
task, pasting output unread. These failures are silent and they survive casual testing, which
is exactly why reading about them doesn't fix them.

## The insight
The skill is trainable the way landing an aircraft is trainable — in a **simulator** where the
traps are deliberate, the stakes are zero, and the feedback is immediate. A good training
codebase is one where **naive prompting provably can't reach the goal**: the bug is invisible
to the passing tests, the feature is underspecified, the obvious implementation trips an
invariant, and a hidden oracle only passes when the work was actually done right.

That artifact already exists in embryo — a kata built to rehearse exactly these moves. This
repo generalizes it.

## The model: Context → Generator → Practice
- **Context** *(the product)* — a versioned spec that encodes the **training goals**, the
  **known AI best practices**, and the **known AI failure modes**. Versions are named after
  trees; v1 is [`alder`](../context/alder/).
- **Generator** *(the contract)* — any AI agent, given a Context version + a target domain and
  stack, produces a fresh practice carrying the **same training points**. See
  [`generator/CONTRACT.md`](../generator/CONTRACT.md).
- **Practice** *(an instance)* — a runnable kata with a green unit suite hiding a real bug, an
  underspecified feature with a trap, ranked latent defects, and a **hidden acceptance grader**.
  The seed is [`practices/deliveries/`](../practices/deliveries/).

The learner works a practice with *any* assistant through five phases — **understand → fix →
feature → improve → review** — on a clock. The hidden grader is the objective gate; *how they
drove* (reproduced before fixing? rejected over-build? matched altitude?) is the real lesson.

## Why this and not the alternatives
- **Not an assessment tool.** Assessment (CodeSignal, HackerEarth, Formation; Meta/Google/Canva)
  grades "how you drive AI" *once, to hire*. This is **deliberate practice**, repeated, to
  *improve* — and it's self-serve, not proctored. See [`PRIOR-ART.md`](PRIOR-ART.md).
- **Not a course or a listicle.** "8 AI coding traps" articles are saturated. Reading a trap
  doesn't build the reflex; hitting it in a simulator with a grader does.
- **Not domain-locked.** Because the Context is the product and the kata is just an instance, the
  same training points regenerate into any domain and stack a team actually uses.

## What this phase delivers (and what it doesn't)
**In:** Context v1, the seed kata aligned to it, the generator contract, the harness design
([`../harness/DESIGN.md`](../harness/DESIGN.md)), this brief, the prior-art and distribution
docs, a tree-naming scheme, and a visual one-pager.
**Out (Phase 2+):** generating more katas, a built runner for the three modes with time/token
actuals, the multi-agent examiner, and a hosted playground. The roadmap is in
[`DISTRIBUTION.md`](DISTRIBUTION.md).

## Why altitude is the central lesson
The failure engineers most reliably make with a capable assistant is **applying production
altitude to a small task** — letting every surfaced concern become code, and running out of
time on an over-built solution. The discipline that fixes it is **surface ≠ build**: name every
concern, build only the minimal spec, park the rest out loud. This is baked into the Context as
failure mode FM-10 and the restraint disciplines, because a true, well-reasoned instinct for
production rigor is exactly what misfires here.
