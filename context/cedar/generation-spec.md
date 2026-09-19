# Generation spec — Context "Cedar" v1

The contract an AI agent follows to generate a **new practice** in a different domain and tech
stack that trains the **same points** as the Context. The agent reads this file plus
[`goals.md`](goals.md), [`best-practices.md`](best-practices.md), and
[`failure-modes.md`](failure-modes.md); the step-by-step an agent executes is in
[`../../generator/CONTRACT.md`](../../generator/CONTRACT.md).

Cedar is a superset of Alder's spec (`alder@1.3.0`): **invariants 1 and 3–9 below are Alder's,
unchanged**, and **invariant 12 is Alder's invariant 10, carried forward and extended** — Cedar
numbers it 12 because 10 and 11 were already taken when Cedar branched. Cedar extends invariant 2,
adds invariants 10–11, a multi-repo practice shape, a dual grade gate, and a new XL difficulty tier.

## Inputs
- **context** — `cedar@1.2.0`.
- **domain** — the business story (e.g. "metering & billing", "warehouse inventory sync").
  Picks the vocabulary and the natural home for the planted bugs.
- **stack** — one or more packages, each language + runtime + test runner. Zero-dependency or
  pinned-minimal preferred; a multi-package practice pins each package's toolchain.
- **difficulty tier** — `S` | `M` | `L` | `XL` (drives size and the time/token estimate).
- **time budget** — optional override of the tier default.
- **coverage** — which disciplines/failure modes to train (default: the core disciplines in
  goals.md, including the two Cedar additions; **FM-13 required by default**; a Cedar practice also
  covers **FM-15 and FM-16** — see invariants 10–11).

## Required output (the fixed practice shape)
A practice is **three layers**, not two — what gets cloned, what stays out of the clone, and what
stays hidden:
```
<practice>/
  ── cloned (the assistant sees this) ────────────────────────────────────────
  <package>/…       # one or more package dirs (e.g. backend/ + app/), each the size of the tier
  test/ or <pkg>/test/   # a GREEN unit suite per package; the primary bug is invisible to it
  reference/        # READ-ONLY external truth: sibling service contract, infra config, method spec
  TICKET.md         # the bug as a SYMPTOM — never a file+line, never a method
  FEATURE-REQUEST.md  # 2–3 sentences, underspecified; staged in at phase 3, not before
  ── exercise material (NOT cloned) ──────────────────────────────────────────
  README.md         # the LEARNER's briefing: domain primer + the 5-phase flow + the estimate
  practice.json     # metadata + trainingPoints coverage (validates against templates/)
  ── hidden (NOT cloned) ─────────────────────────────────────────────────────
  _solutions/       # acceptance graders, the grade wrapper, trap-manifest, feature Q&A,
                    # rubric, FIX, context-map, doc-drift ledger, proofs
```
`README.md` is the *learner's* briefing — it names the phases and the disciplines under test — and
`practice.json` names the planted bug, the doc-drift trap and the cross-boundary trap outright. An
assistant that reads either one has been coached by the instrument measuring it (invariant 12, and
`AGENTS.md` rule 3). The **grade wrapper lives in `_solutions/`** for the same reason: a `grade.sh`
at the practice root is carried into the clone and announces that a hidden grader exists and that
the visible suite is not the bar.

**The work items are staged, one phase at a time.** The clone starts with `TICKET.md`;
`FEATURE-REQUEST.md` is handed over when phase 3 begins. A learner never holds a bug report and a
feature brief at once — work does not arrive that way, and a clone carrying both lets the assistant
read ahead and plan around a brief nobody has given it.

**`reference/` is the exception: it is in the clone from the start, never staged.** It is the
external documentation an engineer already has access to on day one — a vendor's published API
docs, the infra console, a protocol spec — and in most Cedar practices the local packages read it
at runtime, so withholding it breaks the repo. More to the point, handing it over at the moment the
research pass is due *is* the coaching: it tells the learner that the local repo is not the whole
story, which is precisely the judgement FM-16 exists to measure. The trap is not that `reference/`
is hidden; it is that a single-scope run never opens it.

The learner produces **`research-notes.md`** in their workdir during the understand phase (their
distillation of `reference/`); it is not shipped in the source.

## Invariants every generated practice MUST satisfy
1. **The unit suite is green and the primary bug is invisible to it** (FM-01). The hidden
   acceptance grader starts failing and passes only after the correct fix.
2. **The bug is a silent, subset-only failure** (FM-02) keyed on an ambient variable the author
   didn't parameterize. **Cedar extends the ambient variable** beyond process-local env (timezone,
   locale, currency, encoding, clock) to include **cross-boundary / externally-hosted state** — a
   hosted document that can rotate, a sibling service's contract, an infra config the local repo
   never parameterized. Graded across ≥3 values of it.
3. **The feature is underspecified, reads as easy, and misleads.** A straight "implement this"
   prompt trips a real trap — an invariant it violates, state not yet materialized, or a
   plausible-but-wrong rule the brief quietly leans toward. The gate scores the rules **only
   elicitation surfaces**, so handing the brief over raw *fails* it and an elicited build *passes*
   it — defeatable by read-**and-ask**-before-delegate, not by delegation. (Proven by the paired
   naive-vs-elicited build in Validation.)
4. **≥5 ranked latent defects** drawn from FM-03..FM-08, *findable* from the code, not recited.
5. **The grader is runnable with zero/minimal deps**, invoked via the practice's **declared
   command** (`practice.json` → `commands.grade`) — stack-appropriate, never assumed to be
   `npm`. It reports a worst-case score across the ambient-variable values (a fix that only works
   locally does not count).
6. **Every planted item maps to a failure-mode ID** in the trap manifest. No orphan traps, no
   uncovered required discipline.
7. **It is solvable at the stated altitude in the stated time** — not a production system. Cedar
   practices are *complex in the fog, not in the fix*: the multi-repo/external setup and the
   drifting docs make the problem hard to *understand*, but each phase's required change stays
   small. A large diff is a smell (FM-10), even here.
8. **`practice.json` declares the stack's commands** — `commands.install`, `commands.test`,
   `commands.grade` — so the harness runs the practice **without knowing the language**. A Rust
   kata declares `cargo test` / `cargo run --bin grade`; a Go kata `go test ./...`; a Python kata
   `pytest` / `python grade.py`; a **multi-package** kata declares a wrapper (see the dual grade
   gate below). **The harness and AGENTS.md read these; they hardcode nothing.** A practice whose
   grader can only be invoked as `npm run grade` is a stack leak — fix it here.
9. **An assistant-targeted over-reliance trap (FM-13) is present** — a place engineered so an
   *autopilot* run (vague prompt, delegate-before-understand, accept-the-first-suggestion)
   provably loops instead of converging: the objective grader tests the **root** behaviour, so a
   symptom-patch at a call site leaves it red; and the "obvious" fix the assistant proposes (a
   constant or special-case where the correct answer varies per case) passes the visible suite
   but fails a case that needs genuine understanding. Only *model-before-delegation* and
   *comprehension-as-ownership* converge. Distinct from the feature trap (#3, which targets
   reading the code): this one targets *delegating before understanding the goal*.
10. **Context rot is planted in both forms (FM-15).** There is (a) a **stale code path encoding an
    abandoned assumption that no doc references** — a believable leftover of an earlier repo era,
    hidden behind the large green suite (it covers only the still-working subset); **and** (b)
    **≥1 authoritative-looking doc/comment that contradicts the current code** from a partial
    migration, misleading a naive prompter. The **current code + `reference/`** are ground truth.
    Defeatable by *reconcile-docs* + not trusting the green suite. The `_solutions/` doc-drift
    ledger names, for every contradiction, which source is authoritative and why.
11. **The true cause lives across a boundary (FM-16).** The authoritative contract for at least one
    defect (ideally the primary bug) lives **only** in the read-only `reference/` (sibling service +
    infra config + method spec); the local repo's obvious assumption is wrong and nothing local
    states the truth. A single-scope autopilot run makes a **provably wrong assumption** and stays
    locally green; it is defeatable **only** by a research pass that distills `reference/` into
    `research-notes.md` *before* delegating. The grader includes **conformance vectors derived from
    the reference**, so a fix that never read it fails.
12. **Nothing the assistant can read coaches it** (Alder's invariant 10, extended for Cedar).
    Everything in the clone reads as the working repo of a team that does not yet know it has a
    bug. Concretely: the **ticket** reports a symptom and states the rule the customer was
    promised, then stops — it does not prescribe method ("reproduce first", "read the spec", "fix
    the root cause"), does not hint at the mechanism, and never mentions that a grader exists or
    how it is invoked. The **feature request** is the PM's ask plus the expected surface — it does
    not warn that the obvious implementation trips an invariant, or that there is a trap at all.
    **Source and test comments** state intent and contract, and may leave the *evidence* a careful
    reader needs; they never narrate the planted defect or confess the suite's own blind spot. The
    **grade command** is not runnable from inside the clone, no package manifest carries a `grade`
    script, and nothing in the clone refers to one. The learner's briefing and the manifest stay
    outside the clone (see the practice shape above). Cedar adds three of its own:
    - **The drifting doc must mislead, not confess.** The FM-15 contradiction is written by
      someone who believed it — a stale README paragraph, a comment describing the previous
      design. A doc that hedges ("this may be out of date", "TODO: verify against the spec") is
      coaching wearing a doc's clothes, and hands over the reconciliation for free.
    - **`reference/` reads as a vendor snapshot, not a hint sheet.** Its `README.md` says what the
      directory is and that it is read-only. It does not tell the reader to study it, to distill
      it, to compare it against the local repo, or that the local repo disagrees with it. The
      spec inside states the method as a spec states a method — it never points at the local
      implementation or notes that anything local is wrong.
    - **A pointer to external truth is evidence, not coaching.** A module that genuinely consumes
      the reference may cite it the way real code cites a spec (`see reference/<spec>.md`). That
      is the trail a careful reader follows; removing it would make the practice unfair rather
      than uncoached. The line to hold is between *citing* the source and *interpreting* it.

    The discipline under test is the *learner's* to bring: a workdir that tells the assistant to
    reproduce before fixing, or to go read the reference, has already spent the thing it was
    measuring. **Coaching belongs to the learner's briefing and to the trainer — never to the
    workdir.**

## The multi-repo practice shape (Cedar)
- **One clone, multiple packages, one read-only `reference/`.** The harness's clone-and-jail rule
  is unchanged (see [`../../harness/DESIGN.md`](../../harness/DESIGN.md) §0): the practice is still
  a single cloned folder. Inside it, several package dirs represent the local system, and
  **`reference/`** represents the *external* world the repo talks to but does not own — a sibling
  service's contract, cloud infra config (an S3/CloudFront-hosted document, a KMS key policy), and
  the method/protocol spec. `reference/` is **read-only truth**: the assistant may read it but must
  not treat it as the working repo, and it is what the learner's research pass distills.
- **`research-notes.md`** is the learner's artifact of the research pass — the distilled,
  load-bearing facts from `reference/`. Its presence (and quality) is a positive signal on the
  driving axis; its absence when the bug required it is the FM-16 tell.

## The dual grade gate (Cedar, when the practice spans stacks)
- `commands.grade` may be a **wrapper** that runs **every** package's grader and reports a
  **combined worst-case** — all stacks must pass, across all ambient values. **The wrapper lives in
  `_solutions/`** (`bash _solutions/grade.sh`), not at the practice root and not as a `make grade`
  target in a file the clone keeps: it is stripped with the rest of the answer key, so the clone
  carries no evidence that a hidden gate exists (invariant 12). Example for a Rust backend +
  Flutter app: (a) `cargo run --bin grade` for the backend's
  acceptance across ≥3 ambient values plus the reference-derived conformance vectors; (b)
  `flutter test integration_test/` for the app producing a presentation the backend accepts and
  correctly rejecting a tampered/expired one. The wrapper exits 0 only if both pass at worst-case.
- The gate must be **hermetic**: pinned toolchains, no network, fixtures (including the
  `reference/` documents and conformance vectors) vendored in the repo. If a full second-stack gate
  proves too costly for CI, a practice may **fall back to grading the primary stack only** and mark
  the cross-stack check as a `test`-level (not `grade`-level) expectation — recorded in the notes.

## Difficulty tiers
| Tier | Source files | ~LOC | Phases | Time |
|---|---|---|---|---|
| S | 3–4 | ~200 | understand · fix · review | ~30 min |
| M | 5–6 | ~450 | all five | ~60 min |
| L | 7–8 | ~800 | all five + a second bug | ~90 min |
| XL | 10–14 across packages | ~1,200–1,600 | all five (research pass inside *understand*) + a read-only `reference/` + dual grade | ~135 min |

## Estimation method (every practice reports both)
- **Time** = sum of phase budgets for the tier. XL split ≈ understand 30 (incl. the research pass)
  · fix 25 · feature 30 · improve 20 · review 15 · with ~15 of slack for cross-boundary reading
  (minutes) → ~135.
- **Tokens** = `repo_read_tokens × read_passes + expected_rounds × avg_round_tokens`, where
  `repo_read_tokens ≈ LOC × 10`, `avg_round_tokens ≈ 1,500`. XL uses `read_passes ≈ 2.5` (the extra
  half-pass is reading `reference/`) and `expected_rounds ≈ 16`. Worked example (XL, ~1,400 LOC):
  `1,400×10×2.5 + 16×1,500 = 35,000 + 24,000 = 59,000` → report **~60,000**. The Phase-2 runner
  records *actuals* (time always; tokens where the tool exposes usage); the XL model is provisional
  until it does.

## Validation (before a generated practice is accepted)
- Unit suite green; grader fails pre-fix and passes post-fix across all ambient values — run via
  the declared `commands.test` / `commands.grade`, never an assumed `npm`.
- `practice.json` validates, declares `commands.{install,test,grade}`, and every
  `trainingPoints.failureModes` id exists in `failure-modes.md` and appears in the trap manifest.
- **Autopilot check (FM-13):** a symptom-patch and a plausible first-suggestion fix are both
  verified to leave the grader red; only the root, understanding-based fix reaches full marks.
  The trap must bite an autopilot run, not just a careless one.
- **Context-rot check (FM-15):** the stale code path has no doc trace and is invisible to the
  suite; the contradicting doc actively misleads; the doc-drift ledger names the authoritative
  source for each contradiction.
- **Cross-boundary check (FM-16):** a run that never opens `reference/` makes a provably wrong
  assumption and fails the reference-derived conformance vectors; a run that does the research pass
  converges. The `_solutions/context-map.md` states the true cross-boundary contract.
- **Feature-trap discrimination — a paired build.** The feature trap is proven not by the control
  run alone but by **two** builds scored through the declared grade command: a **naive one-shot**
  (fresh executor that has not done the research pass, brief handed over raw) and an **elicited**
  build (the feature after its questions were asked and answered). The trap counts only if **naive
  fails the feature gate and elicited passes.** Naive-also-passes means the gate is a completion
  floor, not a trap — tighten it until only understanding clears it; elicited-also-fails means it is
  impossibly hard. Both scores are recorded, both are genuine captured output.
- **Robustness probes (examiner-only, non-blocking).** The gate's blind vectors — state handed out
  by reference, a guard placed at one entry point instead of on the invariant, a degenerate-quantity
  case — are covered by probes shipped in `_solutions/` **beside** the gate, never wired into the
  grade wrapper and never changing its pass/fail. Each probe's expected result was captured from a
  real build (the reference fix and a stub), not asserted by hand.
- **Manifest completeness.** Every claimed failure mode is planted where a run actually reaches it
  (count planted *instances*, not modes); a mode named in `practice.json` but unreachable is not
  covered. Emergent (unplanted) findings and the reference fix's known limitations are recorded in
  a labelled section, excluded from the planted count.
- **Control run (invariant 12) — the one that actually settles it.** Clone the practice exactly as
  the harness would (`_solutions/`, `README.md` and `practice.json` stripped, `reference/` present),
  hand a *fresh* assistant nothing but that clone and one casual, uncoached prompt, let it finish,
  and grade the result. The clone carries **the work items the grade command actually grades** —
  staging is a property of a multi-phase session, and a control run is a single uncoached shot at
  whatever the gate measures, so a whole-ticket gate gets the ticket *and* the feature request or
  the score is not comparable to `grader.max`. Record
  the score in the proof and in `practice.json` → `controlRun`. A trap that a control run walks past
  unharmed is not a trap, and the two ways that happens have different fixes: if the material told
  it what to do, that is an invariant-12 leak, so cut the coaching; if the material said nothing and
  the trap still failed to bite, the trap is too weak for the assistants of the day, so make the
  graded case one that only genuine understanding reaches. Verifying a trap's mechanism by hand is
  not a substitute — mechanisms hold while the prose quietly gives the answer away. For a Cedar
  practice the control run is also the **cross-boundary check's** real evidence: what an uncoached
  run does with `reference/` sitting in front of it — open it, skim it, or never mention it — is the
  FM-16 measurement, and the transcript should say which.
- A reviewer agent (fresh context) confirms each required discipline is genuinely reachable and
  the exercise is solvable at the stated altitude/time — not over-scoped.
