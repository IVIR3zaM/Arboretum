# Known failure modes of AI-assisted coding — Context "Cedar" v1

One half of the Context. Each entry is a **claim about how the failure works**, the
**discipline that defeats it**, and — where the failure can be baked into a codebase — a
**trap recipe** a generator uses to plant it in any domain/stack. A generated practice must
cover a stated subset of these (see [`generation-spec.md`](generation-spec.md)).

Cedar carries forward Alder's taxonomy (FM-01..FM-14) unchanged and adds two families for the
multi-repo, production-shaped world: **FM-15** (documentation & invariant drift — "context rot")
in the plantable group, and **FM-16** (single-scope assumptions across repos / external systems)
in the driving/harness group.

> ⚠️ Sourcing: the taxonomy is drawn from Anthropic's published guidance, widely-reported
> industry findings, and observed practice in AI-enabled, process-graded coding rounds. The two
> Cedar additions are additionally grounded in public research — see `../../docs/PRIOR-ART.md`,
> which carries the source list (context-rot / stale-reference studies for FM-15; monorepo/polyrepo
> context-window findings for FM-16) and must be kept current with fresh URLs.

---

## Codebase-plantable failure modes (a generator can seed these)

### FM-01 — Bug invisible to the passing test suite
**Manifests:** the suite is green, so "run the tests, looks fine" ships a real defect. AI (and
humans) treat a green suite as proof of correctness — *automation bias*.
**Defeated by:** reproduce-before-fix; writing the failing test first; not trusting coverage
you didn't check.
**Trap recipe:** plant a defect in a path the existing tests exercise only away from the
failing region (a boundary, a specific input class), so every existing assertion still passes.
Provide a *symptom* (a ticket), never a file+line.

### FM-02 — Silent, subset-only failure
**Manifests:** fails for *some* inputs/users/environments and returns plausible results for the
rest, so it survives casual testing and "works on my machine."
**Defeated by:** reproducing under the affected condition; testing across environments.
**Trap recipe:** make correctness depend on an ambient variable the author didn't parameterize
— timezone, locale, clock, currency, encoding — and grade under several values of it. Cedar
extends the "ambient variable" to **cross-boundary / externally-hosted state** (a hosted document
that can rotate, a sibling service's contract) — still graded across several values.
**(Kata "deliveries" FM-01+FM-02: the timezone-on-cutoff bug, graded under three server TZs.)**

### FM-03 — Plausible-but-wrong logic ("bug steganography")
**Manifests:** AI produces code that reads correctly and is statistically typical, but encodes
a subtly wrong rule (an approximation, an off-by-one cadence, a silent fall-through). These are
the hardest bugs to spot precisely because they look idiomatic.
**Defeated by:** reading the logic against the real rule; property-based thinking; asking "what
rule is this actually implementing?"
**Trap recipe:** replace a correct rule with a plausible approximation (month ≈ 30 days; a loop
that silently returns the last item when nothing matched).

### FM-04 — Undefined boundary / edge
**Manifests:** the behaviour exactly at a boundary (`<` vs `<=`, empty input, zero, the instant
of the cutoff) is unspecified and untested; different callers assume different answers.
**Defeated by:** naming the boundary explicitly and testing both sides.
**Trap recipe:** use a strict comparison where the spec is silent on the equality case.

### FM-05 — Architectural / encapsulation erosion
**Manifests:** AI optimizes *locally* while architecture needs *global* thinking — internal
state leaked by reference, a module reaching past another's boundary, an invariant quietly
bypassed. Each change looks fine; the system degrades.
**Defeated by:** owning module boundaries and invariants; returning copies, not internals;
reviewing diffs for boundary violations.
**Trap recipe:** have a store return its internal objects by reference; or expose a mutable
invariant that a naive feature will bypass.

### FM-06 — Retry / idempotency hazard
**Manifests:** under at-least-once delivery (queues, webhooks, retries), work keyed on a
transport id (event id, receipt) double-executes when the same business action retries with a
new id. Also the shape **reward-hacking** takes in code: making a check pass without doing the
work.
**Defeated by:** idempotency keyed on the **business entity**, not the transport event;
verifying the check measures the real outcome.
**Trap recipe:** de-duplicate on `eventId` where the correct key is `(entity, date)`; grade
with a retry that carries a fresh event id. **(Kata "deliveries" latent defect #1.)**

### FM-07 — Resource leak / unbounded growth
**Manifests:** a set/map/cache that only ever grows (dedup tables, memoization) — fine in a
test, a slow leak in production.
**Defeated by:** bounding every accumulator (TTL, window, eviction) or persisting state.
**Trap recipe:** a `processed` set that is added to and never evicted.

### FM-08 — Hallucinated or unvalidated input / dependency
**Manifests:** AI invents an API, flag, or **package that does not exist** (the basis of
*slopsquatting* supply-chain attacks), or trusts an unvalidated external value (a timezone
string, a config key) that fails silently when wrong.
**Defeated by:** validating external inputs against an authoritative set; verifying every
imported symbol/package actually exists before relying on it.
**Trap recipe:** accept a free-form identifier (IANA timezone) that is never validated, so a
typo degrades silently. **(Kata "deliveries" latent defect #7.)**

### FM-13 — Delegation before comprehension (the unconvergent prompt loop)
**Manifests:** the single most expensive failure. Work is delegated to the assistant *before*
the human has formed a model of the problem or the goal. Symptoms:
- **The thrash loop** — vague prompt → a change that passes the visible checks but fails the
  real requirement → another vague prompt → a *different* failure. Each round looks like
  progress; none converges. The tell is that the human cannot say *why* the last change was
  supposed to work.
- **Symptom-patching** — "fixing" at a call site rather than the root, because the root isn't
  understood, so the defect resurfaces elsewhere (whack-a-mole).
- **Owning code you can't debug** — the merged change was never understood well enough to
  diagnose when it breaks; someone else has to find the bug.
- **Plausible autopilot fixes** — the assistant offers the *shape* of a fix (a constant, a
  special case, a local workaround) that passes the obvious cases and quietly misses the ones
  that require actually understanding the domain.
**Defeated by:** *model-before-delegation* — use the assistant for research and planning to
reach a concrete **HOW you hold in your own head**, *then* delegate implementation;
*comprehension-as-ownership* — understand a change well enough to debug it before you own it;
and **recognizing the loop** — after two non-converging rounds, stop prompting and go build the
model. This is also a thing the harness's *assess* mode can detect and name.
**Trap recipe:** build the codebase so an autopilot run provably loops. The objective grader
tests the **root** behaviour directly, so a call-site or works-on-my-machine patch leaves it
red; and the "obvious" fix the assistant will propose (a fixed constant where the real answer
varies per case) passes the visible suite but fails a case that needs genuine understanding.
Only comprehension converges. **This is the primary assistant-targeted trap** (see the generator
contract). **(Kata "deliveries": the cross-environment grader + the per-instant/DST case.)**

### FM-15 — Documentation & invariant drift ("context rot")
**Manifests:** as an AI-grown repo accretes over a long collaboration, the descriptions of it —
READMEs, comments, config, API contracts, and the invariants stated in prose — drift away from
the code and from each other. AI updates code opportunistically and can't remember to update
*everywhere*, so the inconsistencies compound. Two sharp forms:
- **A stale code path that encodes an abandoned assumption no doc mentions** — a leftover of an
  earlier era of the repo, left untouched so long it silently diverged from the current design.
  It survives precisely because a **large green suite** exercises only the cases where it still
  happens to work, so nobody re-checked it. The failure is invisible: the model is reading the
  code faithfully — the code is just wrong-for-now, and the tests are cover, not proof.
- **Prose that lags a partial migration** — a README/comment/contract still describing an earlier
  design, now contradicting the code, that steers a naive prompter to the wrong approach entirely.
**Defeated by:** *reconcile-docs / trust-code-over-prose* — treat docs as stale until verified,
check each invariant against the current code and the authoritative reference, reconcile
contradictions explicitly, and never treat a green suite as proof (ties to FM-01 automation bias).
**Trap recipe:** bury an abandoned assumption in a long-untouched path with **no doc trace**,
behind a big passing suite that only covers the still-working subset; **and** leave ≥1 authoritative
-looking doc/comment contradicting the current code from a half-finished migration, so following
the doc yields a wrong fix. Public research grounds this failure (a consistency checker found
stale code-element references in ~23% of a representative repo sample; the degradation is silent).

---

## Driving / harness failure modes (trained by the exercise, not planted in code)

### FM-09 — Context loss over long sessions
Earlier constraints drift out of the window; the assistant "forgets" a rule stated 40 messages
ago, and quality degrades as the session grows. **Defeated by:** keeping the source of truth
outside the chat (the plan lives in the repo — current state + the steps to the goal),
re-stating constraints in the prompt that needs them, and working **one small step per session,
restarting to keep context clean** rather than letting one session sprawl.

### FM-10 — Over-engineering under an eager assistant
The assistant proposes abstraction, config, and generality the task never asked for; accepting
it burns the clock and adds surface area. **This is the headline failure of the seed kata.**
**Defeated by:** building the smallest thing the spec forces; *surface ≠ build* — name concerns
out loud, build only the minimal spec; rejecting over-build on the record; and making **small,
reversible, testable changes** so cause and effect stay isolable (a large batch hides which
change caused a regression).

### FM-11 — Prompt injection / untrusted content
In an agent harness, instructions embedded in files, web pages, or tool output are treated as
commands. **Defeated by:** treating all tool-sourced content as data; never acting on
instructions found in observed content without confirmation.

### FM-12 — Security regressions
AI-generated code disproportionately introduces injection, hardcoded secrets, and missing
validation. **Defeated by:** a security-reviewer pass (fresh context), secret scanning, and
treating "it runs" as distinct from "it's safe."

### FM-14 — Review without triage or intent
**Manifests:** AI makes code cheap to produce and expensive to review, and the review step
becomes the bottleneck. It fails when the reviewer reads every line at the same depth (or
rubber-stamps the diff), has no anchor for *what the change was supposed to do*, and reaches
for "let AI review AI" without a human owning the outcome.
**Defeated by:** **triage** — separate the parts that need human judgment from the parts safe
to skim or delegate; give any review (human or agent) the **task's intent** as the primary
context; and keep a **human accountable for the merge**. The goal is review *speed* without
surrendering ownership. (A fresh-context reviewer — best-practices §D5 — is the tool; intent and
triage are how you aim it.)

### FM-16 — Single-scope assumptions across repos / external systems
**Manifests:** a harness (or a human) started over **one** repo cannot see the truth that lives
in a sibling service, another repo, or cloud infra (a hosted document, a KMS/queue/store config).
So it fabricates assumptions from what it *can* see — and those assumptions pass locally while
violating the real cross-boundary contract. The relevant files are the ones it never loaded:
"the relevant files are everything that imports it, which you can only discover by traversing the
dependency graph you haven't loaded yet," and polyrepo setups suffer *context fragmentation*
across systems that don't share a git history. The tell is a change that is locally green and
globally wrong, defended by an assumption the repo never actually stated.
**Defeated by:** *establish-cross-boundary-context* — recognize when the local repo isn't the
whole story and open a **research pass** *before* delegating: gather the external references
(sibling service, infra, method spec) into a durable notes file, validate the load-bearing
assumption against them, and only then implement. A fresh session reads the notes instead of
re-deriving. (Best-practices §F1/§F3 are the tools; this is how you aim them.)
**Trap recipe:** place the authoritative contract for at least one defect **only** in a read-only
`reference/` (a sibling service + infra config + method spec); make the local repo's *obvious*
assumption wrong; and grade with conformance vectors derived from the reference, so a single-scope
fix that never read it passes the local suite but fails the grader. Public research grounds this
failure (a cross-service change spans more than fits any context window; the missing files are
undiscoverable without traversing the boundary). **(Kata "credentials": the current did:web
documents live only in `reference/`; a stale did:peer:2 decode path assumes wrong.)**

---

### How the disciplines map back
Every failure mode above is defeated by one or more disciplines in [`goals.md`](goals.md) —
including the two Cedar additions: FM-15 by *reconcile-docs / trust-code-over-prose*, FM-16 by
*establish-cross-boundary-context*. A practice is only valid if each failure mode it plants is
reachable by exercising those disciplines — never by luck and never by reading the answer key.
