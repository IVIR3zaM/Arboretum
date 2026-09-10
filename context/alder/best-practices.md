# Best practices for AI-assisted coding — Context "Alder" v1

The other half of the Context: the known-good disciplines, drawn from Anthropic's published
guidance (authoritative) and observed practice in AI-enabled, process-graded coding rounds.
Each maps to the
[`goals.md`](goals.md) discipline it trains and the [`failure-modes.md`](failure-modes.md) it
defeats. A generated practice must create a genuine opportunity to *exercise* these, not just
describe them.

## Sources (authoritative)
- **Prompt engineering** — `platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices`
- **Building Effective Agents** — `anthropic.com/engineering/building-effective-agents`
- **Claude Code best practices** — `code.claude.com/docs/en/best-practices`
- **Altitude & restraint in process-graded rounds** — see §E and `docs/CONCEPT.md`.

---

## A. Prompting craft (from Anthropic's prompt-engineering guide)
1. **Be clear and direct.** Treat the model as a capable new colleague with no context. Specify
   the output and constraints; if you want "above and beyond," ask for it. *Golden rule: if a
   colleague with minimal context would be confused, so will the model.*
2. **Add context / motivation.** Explain *why* a constraint matters; the model generalizes from
   the reason.
3. **Use examples (multishot).** 3–5 relevant, diverse examples wrapped in `<example>` /
   `<examples>` tags steer format and behaviour more reliably than description.
4. **Structure with XML tags.** Separate instructions, context, input, and examples with
   descriptive tags so nothing is misread.
5. **Give the model a role** via the system prompt to focus tone and judgment.
6. **Let it think (chain of thought)** for multi-step reasoning; make the reasoning visible.
7. **Prefill** the start of the response to pin format.
8. **Chain prompts** — decompose into sequential calls with checkpoints rather than one giant
   prompt.

## B. The four coding-round prompt skeletons (for AI-enabled, process-graded rounds)
1. **Understand (no writes).** *"Don't change anything. Summarise the module boundaries, the
   invariant each module owns, and where state is mutated. Then name the three places a
   correctness bug is most likely to hide, and why."* → trains *read-before-delegate*.
2. **Reproduce before fixing.** *"Write a failing test that demonstrates the bug, in the
   existing test style. Don't fix it yet — I want the failure first."* → trains
   *reproduce-before-fix*; beats FM-01/FM-02.
3. **Spec a feature (plan).** Requirement in your own words + constraints + the invariant that
   must not break + *"flag anything in my requirement that's ambiguous."* → trains
   *requirements-elicitation*; surfaces the question to ask the stakeholder.
4. **Reject and redo.** *"No — that changes X, which must hold. Redo it keeping X fixed and
   tell me what you traded off."* → trains *verify-output* and *reject-on-camera*; beats FM-10.

## C. Agentic structure (from *Building Effective Agents*)
- **Start simple.** A single call with retrieval + examples beats an agent for most tasks; add
  autonomy only when simpler approaches demonstrably underperform.
- **Three principles:** *simplicity*, *transparency* (show the plan), *good tool design*.
- **Know the patterns** and pick the lightest that fits: prompt chaining, routing,
  parallelization, orchestrator-workers, evaluator-optimizer. Full autonomy is the exception.

## D. Claude Code working discipline (from the best-practices guide)
- **Give the agent a check it can run** — tests, a build, a screenshot, a grader. Without one,
  "looks done" is the only signal and you are the verification loop. *(This platform's whole
  grader design.)* Beats FM-01.
- **Explore → plan → code → commit.** Separate research/planning from implementation so you
  don't solve the wrong problem. Skip planning only when the diff fits in one sentence.
- **Spec first.** For anything non-trivial, have the assistant interview you and write a
  self-contained spec (files, interfaces, out-of-scope, an end-to-end verification step) before
  coding. Trains *requirements-elicitation*.
- **Manage context aggressively.** Performance degrades as the window fills; clear between
  unrelated tasks, keep the source of truth in files not chat. Beats FM-09.
- **Adversarial review in a fresh context.** A reviewer subagent that sees only the diff and
  the criteria evaluates on its own terms — but told to "find gaps" it will over-report, so
  scope it to correctness and the stated requirements. Beats FM-12; guards against FM-10.
- **Named failure patterns to avoid:** the kitchen-sink session, correcting-over-and-over, the
  over-specified CLAUDE.md, the **trust-then-verify gap**, and infinite exploration.

## E. Altitude & restraint (the lesson most often missed in process-graded rounds)
- **Match the altitude of the task.** Production rigor on a toy exercise reads as
  over-engineering and burns the clock. The deep understand-phase analysis is *rewarded*; the
  error is letting every surfaced concern become code.
- **SURFACE ≠ BUILD.** Surface every concern out loud; build only the minimal spec; park the
  rest as "noted, out of scope, here's when I'd do it." The firewall that prevents FM-10.
- **A named production trade-off still reads as a smell in a clean-room exercise.** Implement
  the clean/idiomatic default; keep the production alternative as a verbal aside.
- **Finishing the minimal-correct task beats an unfinished elaborate one**, every time.

---

**Generator contract:** a valid practice gives the learner a real reason to reach for B1–B4
(an unseen codebase to understand, a symptom to reproduce, an underspecified feature to
elicit, eager AI output to reject) and is graded by a runnable check (D1). See
[`generation-spec.md`](generation-spec.md).
