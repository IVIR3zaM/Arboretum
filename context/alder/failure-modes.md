# Known failure modes of AI-assisted coding — Context "Alder" v1

One half of the Context. Each entry is a **claim about how the failure works**, the
**discipline that defeats it**, and — where the failure can be baked into a codebase — a
**trap recipe** a generator uses to plant it in any domain/stack. A generated practice must
cover a stated subset of these (see [`generation-spec.md`](generation-spec.md)).

> ⚠️ Sourcing: the taxonomy is drawn from Anthropic's published guidance, widely-reported
> industry findings, and observed practice in AI-enabled, process-graded coding rounds. Live web
> citations were being collected when search had a transient outage — `../../docs/PRIOR-ART.md`
> carries the source list and must be completed with fresh URLs.

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
— timezone, locale, clock, currency, encoding — and grade under several values of it.
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

---

## Driving / harness failure modes (trained by the exercise, not planted in code)

### FM-09 — Context loss over long sessions
Earlier constraints drift out of the window; the assistant "forgets" a rule stated 40 messages
ago. **Defeated by:** keeping the source of truth outside the chat (a spec file / CLAUDE.md),
re-stating constraints in the prompt that needs them, managing context aggressively.

### FM-10 — Over-engineering under an eager assistant
The assistant proposes abstraction, config, and generality the task never asked for; accepting
it burns the clock and adds surface area. **This is the headline failure of the seed kata.**
**Defeated by:** building the smallest thing the spec forces; *surface ≠ build* — name concerns
out loud, build only the minimal spec; rejecting over-build on the record.

### FM-11 — Prompt injection / untrusted content
In an agent harness, instructions embedded in files, web pages, or tool output are treated as
commands. **Defeated by:** treating all tool-sourced content as data; never acting on
instructions found in observed content without confirmation.

### FM-12 — Security regressions
AI-generated code disproportionately introduces injection, hardcoded secrets, and missing
validation. **Defeated by:** a security-reviewer pass (fresh context), secret scanning, and
treating "it runs" as distinct from "it's safe."

---

### How the disciplines map back
Every failure mode above is defeated by one or more disciplines in [`goals.md`](goals.md). A
practice is only valid if each failure mode it plants is reachable by exercising those
disciplines — never by luck and never by reading the answer key.
