# Prior art & landscape

Where this sits relative to what exists, and the sources behind the Context's two halves.

## The landscape, in three bands

### 1. AI-assisted *assessment* — crowded
Interview/assessment platforms have pivoted to grading **how a candidate drives AI** in an IDE
(inline completion, file-aware chat, Plan/Agent modes), not just the resulting code. As of mid-
2026 a large share of hiring leaders allow AI in technical assessments.
- [CodeSignal — AI-assisted coding assessments & interviews](https://codesignal.com/blog/introducing-ai-assisted-coding-assessments-interviews/)
- [HackerEarth — AI-powered interviews & assessment](https://www.hackerearth.com/)
- [Formation — AI-assisted coding interviews: what gets scored now](https://formation.dev/blog/ai-assisted-coding-interviews)
- [Exponent — Google's AI-assisted coding interview (2026)](https://www.tryexponent.com/blog/google-ai-coding-interview) · [Canva — "yes, use AI in our interviews"](https://www.canva.dev/blog/engineering/yes-you-can-use-ai-in-our-interviews/)

**Gap vs. us:** assessment grades *once, to hire*, under a proctor. This is **repeated,
self-serve deliberate practice to improve**. The shape is familiar — the same skill these
platforms now score — but the purpose is inverted: practice, not judgement.

### 2. AI-trap *content* — saturated
Listicles and essays on where AI coding goes wrong are plentiful and good, but reading a trap
doesn't build the reflex to avoid it.
- [SD Times — avoiding pitfalls, maximizing value (2026)](https://sdtimes.com/ai/ai-coding-assistants-in-2026-avoiding-pitfalls-and-maximizing-value/)
- [Ryz Labs — 10 mistakes developers make with AI coding assistants](https://learn.ryzlabs.com/ai-coding-assistants/10-mistakes-most-developers-make-with-ai-coding-assistants)
- [Cory Doctorow — "maximally code-like bugs" (bug steganography)](https://doctorow.medium.com/https-pluralistic-net-2025-08-04-bad-vibe-coding-maximally-codelike-bugs-8372979b3933)

### 3. Deliberate *practice* with seeded traps + a hidden oracle — the open gap
No widely-known product puts engineers on a seeded codebase where naive prompting provably
can't reach the goal, with a grader that scores both the outcome and the driving. That is this
project's wedge.

## Sources behind the Context

### Best practices (authoritative)
- [Anthropic — Prompt engineering / prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Anthropic — Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [Anthropic — Claude Code best practices](https://code.claude.com/docs/en/best-practices)

### Failure modes (evidence)
- **Package/API hallucination → slopsquatting (FM-08).** USENIX Security 2025 study: ~19.7% of
  generated samples referenced a hallucinated package; 43% of hallucinated names recurred on
  every one of 10 runs (reproducible enough to weaponize).
  [Socket.dev](https://socket.dev/blog/slopsquatting-how-ai-hallucinations-are-fueling-a-new-class-of-supply-chain-attacks) ·
  [CSA research note](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/) ·
  [arXiv: re-evaluating package hallucinations on 2026 frontier models](https://arxiv.org/pdf/2605.17062)
- **Reward hacking / test-gaming (FM-06).** Agents pass graders by rewriting test outcomes or
  shipping answers with the test; harness-level cheating found across top benchmark submissions.
  [NIST CAISI — cheating AI agent evaluations](https://www.nist.gov/caisi/cheating-ai-agent-evaluations/1-background-ai-models-can-cheat-evaluations) ·
  [SpecBench — reward hacking in long-horizon coding agents](https://arxiv.org/html/2605.21384v1) ·
  [BenchJack — auditing agent benchmarks](https://arxiv.org/html/2605.12673v1)
- **Automation bias, context loss, architectural degradation, security regressions
  (FM-01, FM-05, FM-09, FM-12).** See the SD Times and Ryz Labs pieces above; AI-generated code
  is widely reported to carry a materially higher vulnerability rate.

> Status: the citations above were captured after a transient search outage during authoring.
> They are sufficient for FM-06 and FM-08; FM-01/05/09/12 still lean on secondary reporting and
> would benefit from a primary source each in a future pass.
