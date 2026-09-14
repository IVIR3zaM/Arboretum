# Verification Contract — build the `credentials` practice

Status: **CONFIRMED** 2026-09-14 (V13 staged-delivery and P2 wording set by the user; V18 added at
decomposition time as a planning-internal gate)
Source: `practices/credentials/DESIGN.md` (working-tree version), `generator/CONTRACT.md`,
`context/cedar/generation-spec.md`, `harness/DESIGN.md`, `AGENTS.md`,
`practices/fulfillment/_solutions/{BUILD-LEDGER,misbehaviors}.md` (lessons from the last Cedar build).

Plan root lives in `_solutions/` because the plan names the bugs and the fixes (AGENTS.md placement rule 2).

## Load-bearing property
**The kata is a band, not a maximum: an assistant run in a harness-shaped clone does NOT clear the grade
gate. This holds for a casual prompt, and it also holds when the prompt asks for the method ("find the
root cause, then fix it"). Without an engineer who understands the system and does the research (with or
without AI), the assistant settles on a wrong root cause or on only the obvious axis. The small fix that comes from understanding each axis (did:web live fetch;
all four webhook axes; the minimal holder-bound DCQL presentation) DOES clear it, using only what is in
the clone.**
Verified by: V13 (control run stays red) **and** V14 (the disciplined path turns green), with V5/V6/V7 as the
mechanism-level evidence underneath. Neither side alone counts. The last Cedar build (fulfillment)
passed every mechanism check, and its control run still cleared FM-16 on the first try.

## Answers (defaults derived from the Context — confirm or override)
- Philosophy: **KISS / restraint.** Tier-sized, the planted traps are the only defects, and each fix stays
  small (invariant 7).
- Test bar: **deterministic gates plus measured trap ladders.** No coverage floor. Every trap is shown to bite
  by a real command run on a throwaway copy.
- Perf: **not verified as a budget.** The webhook "within budget" is a logical budget the grader asserts
  inside the test (injected clock/timeout), not wall-clock timing.
- Failure handling: **only what the graders assert.** Leftover latent defects are planted on purpose.
- Security: **the planted security defects must be present and findable** (replay, trust-registry
  bypass, fall-through to valid). No hardening beyond the design.
- Human gates: **few.** H1 toolchain/deps install, H2 calibration escalation, H3 before push to `main`.
- App stack: **Flutter wallet, full gate.** Install pinned Flutter behind H1. `grade.sh` ANDs (a) + (a2) + (b)
  `flutter test integration_test/`. The backend-only fallback is used only if V15 names it and H2 approves.
- Control-run bar: **must stay red.** V13 is blocking. One strengthening pass, then H2.
- Scope: practice build **plus** generalize `harness/DESIGN.md` + `AGENTS.md` to an ordered ticket queue
  that **still supports a single `TICKET.md`** (V17). Phase-1/4 soft gates and the clone `git init` fix are
  **out of scope**.

## Verifiers

### V1 — Unit suites green, bugs invisible
- Kind: K1 · Tier: none
- Asserts: `commands.test` exits 0 on the shipped (bug-present) tree for every package. The visible
  suite includes a **passing canary test** and only never-rotated issuers / small healthy tenants.
- Evidence: captured output of `commands.test` from `practice.json`.
- Passes when: exit 0, and the test count in the output is >0 for each package.
- Applies to: backend, app, reference-fixture nodes.

### V2 — Grade gate flips: red → green → red
- Kind: K1 · Tier: none
- Asserts: `bash _solutions/grade.sh` on the shipped tree exits non-zero, and **each** sub-gate (a, a2, b) is
  red. With the `FIX.md` reference fix applied to a **throwaway copy** it exits 0 at worst-case. After the fix
  is reverted it is red again. The grader is never weakened.
- Evidence: three captured runs (baseline / fixed / reverted) with per-gate scores; `git diff` shows the
  shipped tree is unchanged.
- Passes when: the three runs give RED / GREEN / RED, the per-gate scores add up to `practice.json` → `grader.max`,
  and the shipped tree's diff is empty.

### V3 — Hermetic gate
- Kind: K1 · Tier: none
- Asserts: after `commands.install` (the only step allowed to use the network), grade runs with no network.
  Cargo runs `--offline --locked` against the lockfile and the install-populated cache; a committed
  `vendor/` is used only if it is under 5 MB. Flutter/pub run with `--offline`, did.json and the canary target are served from `reference/infra/` through a
  file/loopback resolver, and `example.com` is never dialled.
- Evidence: grade run with `CARGO_NET_OFFLINE=true`, `PUB_OFFLINE`/`--offline`, and the network off
  (sandboxed run or proxy set to an unroutable address). Output of a grep for the vendored dirs.
- Passes when: the fixed-copy run is still GREEN with the network off.

### V4 — Dependency hygiene (FM-08 in the practice itself)
- Kind: K2 · Tier: none
- Asserts: every dep is exact-pinned and exists in its registry at that version (lookup captured).
  Dart deps are `ssi` and `dcql` (publisher `affinidi.com`), not the GitHub repo names in DESIGN.md.
  `cargo tree` / `dart pub deps` contain **none** of the deny-list: `affinidi-did-web`,
  `affinidi-did-webs`, `affinidi-did-resolver-*`, `affinidi-tdk`, any other did:web resolver.
  The did resolver is first-party code.
- Evidence: lockfiles, `cargo tree`, `dart pub deps`, registry lookup output.
- Passes when: no deny-list hit, every dep resolves, and the rust toolchain is pinned to ≥ the MSRV of
  `affinidi-did-common` (1.95.0).

### V5 — Ticket 1 trap ladder (FM-13 / FM-16)
- Kind: K1 · Tier: none
- Asserts, each measured on a throwaway copy and then reverted:
  (1) symptom-patch in the VP handler → gate (a) RED;
  (2) re-pin / hard-code the one failing issuer's key → visible suite green, gate (a) RED (plateau on
  the next rotated issuer or endpoint);
  (3) a "fix" that never reads `reference/` (e.g. trust the local snapshot, refresh from local
  fixtures) → the conformance vectors RED;
  (4) real did:web resolution per `reference/did-web-method.md` → gate (a) GREEN.
- Evidence: four captured `grade.sh` outputs, recorded in `trap-manifest.md`.
- Passes when: the pattern is RED, RED, RED, GREEN, with the scores recorded.

### V6 — Ticket 2 four-axis plateau (each axis *necessary*)
- Kind: K1 · Tier: none
- Asserts: gate (a2) stays RED for **each single-axis fix** (4 runs) **and for each leave-one-out
  fix**, meaning three of four axes fixed (4 runs). All four fixed → GREEN. The leave-one-out runs are what
  prove "miss one of four plateaus". The single-axis runs alone do not.
- Evidence: 9 captured gate (a2) runs, scored worst-case across {small, large tenant} × {healthy, one slow
  endpoint}, with the per-assert breakdown (delivery-within-budget, timeout observable, canary ⇒ real).
- Passes when: 8 RED, 1 GREEN.

### V7 — Feature trap reachable and biting
- Kind: K1 + K2 · Tier: none
- Asserts: (K2) the call surface the hidden app/cross-stack test uses, `WalletService.createPresentation(...)`
  with its parameter types, **exists as a stub in the clone**. This is fulfillment's unreachable-gate lesson.
  (K1) stub → gate (b) fails. Naive VP (all claims, or no holder signature, or no nonce/domain binding) → RED.
  Minimal correct VP (DCQL subset, holder-signed, nonce+domain, refuses expired) → GREEN.
- Evidence: a grep of the stub signature in the stripped clone, and three captured gate (b) runs.
- Passes when: the signature matches, and the runs give RED / RED / GREEN.

### V8 — Anti-coaching lint (invariant 12, mechanical)
- Kind: K2 · Tier: none
- Asserts: in a clone stripped exactly as AGENTS.md prescribes, scanned statically with every work item
  (each ticket and the feature request) checked in its staged position, no file contains: `grade`, `_solutions`, `hidden`, `acceptance` (outside test
  names already in the repo), `reproduce`, `root cause`, `read the spec`, `out of date`, `TODO: verify`,
  `may be stale`. Tickets never name `did:web`, `rotat`, `snapshot`, `index`, `timeout`, `canary`,
  `example.com`, `concurrent`. `reference/README.md` never says study/distill/compare/disagree. No
  `grade` script sits in Cargo.toml/pubspec. No `grade.sh` sits outside `_solutions/`. The feature request has no ⚠️
  line (**DESIGN.md's draft FEATURE-REQUEST hint must be dropped**).
- Evidence: the output of an assertion script over the stripped clone.
- Passes when: zero hits (each allow-listed exception is justified inline in the script).

### V9 — Anti-coaching cold read (invariant 12, semantic)
- Kind: K3 · Tier: reasoning_high
- Asserts: someone reading the stripped clone as "the working repo of a team that doesn't know it has a
  bug" finds no narration of any planted defect or of the suite's blind spots. The drifting docs
  mislead; they do not hedge. `reference/` reads like a vendor snapshot. Citations of `reference/` are
  citations, not interpretations.
- Evidence: the stripped clone only. No DESIGN, manifest, or brief.
- Passes when: the judge finds no coaching and cites file:line for anything borderline.

### V10 — Manifest integrity (claims = plants)
- Kind: K2 · Tier: none
- Asserts: every FM id in `practice.json` → `trainingPoints.failureModes` exists in
  `context/cedar/failure-modes.md` **and** has a row in `trap-manifest.md`. Every row's `file:line`
  resolves to code that exists. `latentDefects` equals the number of manifest latent rows (≥5). Every
  `doc-drift-ledger.md` row's quoted doc string greps in the named file. `practice.json` validates
  against `context/cedar/templates/practice.template.json` and has no `status`.
- Evidence: the output of an assertion script.
- Passes when: zero mismatches. (Fulfillment shipped FM-03 claimed but not planted.)

### V11 — Latent defects demonstrably present
- Kind: K1 · Tier: none
- Asserts: each ranked latent defect (the design lists 7 or 8) has a probe in `_solutions/` that **passes
  while the defect is present**: replay with a fresh requestId accepted; by-reference mutation visible;
  seen_nonces growth unbounded; exact-instant exp boundary; status bit off-by-one; untrusted issuer
  accepted; unknown proof type or DID method → valid; (optional) HashMap-order canonicalization.
- Evidence: captured probe run.
- Passes when: every probe passes on the shipped tree and none of the probes is part of the grade gate.

### V12 — Practice shape and placement
- Kind: K2 · Tier: none
- Asserts: layout matches DESIGN §Intended layout. `TICKET-1.md`, `TICKET-2.md`, `FEATURE-REQUEST.md`,
  `README.md` (primer lifted), and `practice.json` exist. `DESIGN.md` is moved to `_solutions/DESIGN-blueprint.md`.
  The only changes are under `practices/credentials/`, `harness/DESIGN.md` and `AGENTS.md`. Nothing
  is added to `context/`. No `.sessions/` is committed. No new top-level dir.
- Evidence: `git status --porcelain` / `git diff --name-only` against the baseline ref, plus an assertion script.
- Passes when: zero violations.

### V13 — Control run stays red (LOAD-BEARING, adversarial)
- Kind: K4 · Tier: reasoning_high, **cold**, ideally a different model than the builders
- Asserts: a fresh assistant is given only the harness-shaped clone (stripped). **Work items are staged
  exactly as in a real session: a bug ticket and the feature request are never in the clone together.**
  The clone starts with `TICKET-1.md` only. When the assistant declares Ticket 1 done, `TICKET-2.md` is
  staged in, using the same prompt shape. `FEATURE-REQUEST.md` is never staged during a control run, so
  V13 scores only gates (a) and (a2). (This departs from `generation-spec.md`'s "whole-ticket gate gets the
  ticket *and* the feature request" rule. By decision, the bugs and the feature are never delivered together.)
  It is run **twice**, each time in a fresh clone and a fresh context:
  - **P1, casual:** "a customer reported this, please fix it".
  - **P2, method-prompted:** "investigate this ticket, find the root cause first, then fix it at the root".
    This is the standard advice with no domain understanding behind it, and it does not mention the feature.
    It comes from the learner's prompt, not the clone, so it does not conflict with invariant 12.
  Neither run clears the gate. On **both** tickets the assistant lands on a wrong or partial cause. For
  Ticket 1 that means a re-pin/refresh of the failing issuer, trusting the local snapshot, or a call-site
  patch, instead of a live did:web fetch per `reference/`. For Ticket 2 it means fixing fewer than all
  four axes (typically the one in plain sight, such as the sequential loop).
- Evidence: both full transcripts (kept on pass). After each run the harness runs `grade.sh` on that clone
  and records per-gate and per-assert scores. Each transcript is annotated with: the root cause the
  assistant *claimed* for each ticket, whether `reference/` was opened (and which files), which of
  A1–A4 were fixed, and whether the re-pin plateau was hit.
- Passes when: for **both P1 and P2**, grade exits non-zero **and gate (a) and gate (a2) are each red**,
  so neither ticket converged. A run where only one ticket stays red counts as a failed attack. Both scores
  are written to `practice.json` → `controlRun` (as `casual` and `methodPrompted`) and to the proof either way.
- On failure: one strengthening pass is allowed. The graded case must then need knowledge that only
  understanding plus `reference/` supplies. Cutting hints is not enough, because P2 already carries the
  method. Then both prompts are re-run. A second failure goes to H2.
- Isolation, cloud single-session runner: the assistant under test is a fresh subagent working in a service
  tree outside the repository, with fresh git history. The Arboretum checkout is pushed and then emptied
  (`cold-seal.sh`) before it starts, and restored from GitHub afterwards. Residual exposure is recorded in
  `controlRun.method`: the orchestrator's transcript under `~/.claude`, and the public repo if the assistant
  looks for it by name.

### V14 — Intended path converges (inverse of V13)
- Kind: K1 + K3 · Tier: none / reasoning_high
- Asserts: a disciplined `train` run, driven through the harness rules (clone, strip, staged
  tickets, jail, `git init` inside the clone, examiner kept separate), reaches `grade.sh` GREEN without
  anyone on the executor side reading `_solutions/`. The combined diff stays small (each axis fix a
  handful of lines, as in the design).
- Evidence: session transcript, captured baseline→final unit and grade outputs, and `git diff --stat` inside the clone.
- Passes when: final grade exits 0, the transcript shows no `_solutions` access, and the diff stat is within
  the XL altitude (the judge cites numbers).

### V15 — Fresh-context solvability review (invariant 7)
- Kind: K3 · Tier: reasoning_high
- Asserts: the practice is solvable at XL in the stated time, every declared discipline is reachable
  without `_solutions/`, and it is not over-scoped now that it has two compound bugs. If it is over-scoped, the reviewer
  names the backend-only fallback.
- Evidence: the practice tree plus CONTRACT.md's acceptance checklist. It does not read the builders' handoffs.
- Passes when: a pass verdict on every checklist item, or a named fallback that becomes a human decision.

### V16 — Proof integrity
- Kind: K2 · Tier: none
- Asserts: `_solutions/proof-train-<date>.html` records harness/mode, date, model, the control run
  and its score, and for each phase: prompt → behaviour → designed trap → examiner output → real outcome.
  **Every numeric score in the proof appears in a captured log** of that session.
- Evidence: the proof file and the session logs, checked by an assertion script that extracts numbers and matches them against the logs.
- Passes when: zero unmatched figures and every required section is present.

### V17 — Harness supports an ordered ticket queue AND a single ticket
- Kind: K1 + K2 + K3 · Tier: none / reasoning_high
- Asserts:
  (K1) the setup procedure in `AGENTS.md` (§Running a mode today), run as written into scratch dirs,
  gives the right initial clone for **three** shapes. `practices/deliveries` (single `TICKET.md`): clone holds
  `TICKET.md` and no `FEATURE-REQUEST.md`. `practices/fulfillment` (single ticket + `reference/`): same, with `reference/`
  present. A queue fixture shaped like credentials: clone holds `TICKET-1.md` only, and `TICKET-2.md` and
  `FEATURE-REQUEST.md` are staged aside. None of the three clones contains `_solutions/`, `README.md` or `practice.json`.
  (K2) `practices/deliveries/` and `practices/fulfillment/` are unchanged, so existing practices need no
  migration. `context/` is unchanged. The practice → harness contract is explicit: a single `TICKET.md`, or
  `practice.json` → `workItems.staged[]` listing the order, and the rule for when each item is handed over
  (next ticket when the previous one lands; feature request at phase 3).
  (K3) A cold reader of `harness/DESIGN.md` + `AGENTS.md` alone finds the two shapes consistent with each
  other and with AGENTS.md rules 3/4. No practice is named in a way that leaks its bug.
- Evidence: the scratch-clone listings from the setup script, `git diff --name-only`, and the judge verdict with cited lines.
- Passes when: all three clone listings match, there are no forbidden diffs, and the judge passes.

### V18 — Build contract digest is coherent (planning-internal)
- Kind: K3 · Tier: reasoning_high
- Asserts: `.plan/digests/build-contract.md` is the single interface every parallel builder binds to. It
  states the issuer dataset (≥3 hosted-DID states, with trust-registry entries), the tenant/subscription
  dataset, the Rust public roots the graders call (resolver, VP verify, notifier, with injectable clock,
  timeout and dispatcher), the observable-timeout signal type, the Dart `WalletService.createPresentation`
  signature, the file list, where each latent defect and each A1–A4 axis is planted, and the reference fix
  per trap. It agrees with DESIGN.md, and a cold builder could implement any single layer from it without a
  question.
- Evidence: the digest, DESIGN.md, `context/cedar/generation-spec.md`.
- Passes when: the judge finds no contradiction and no missing interface a downstream node needs, with cited lines.

### H1 — Toolchain and dependency install (human gate)
Before any network install (Flutter SDK via brew cask or an exact pinned SDK, `cargo vendor`,
`flutter pub get`): a person approves the exact toolchain versions and the dep list from V4.

### H2 — Calibration escalation (human gate)
If V13 fails (the control run clears the gate) after **one** strengthening pass, or any trap node fails its
verifier twice, a person decides: strengthen again, accept and record honestly, or cut scope.

### H3 — Before commit/push to `main` (human gate)
After V2–V16 pass, before the single integration push.

## Explicitly not verified
- **Wall-clock performance** of the notifier. Budgets are logical and asserted in the test.
- **Phases 1, 4, 5 objectively.** Research notes, latent defects found, and review quality stay on the
  rubric (driving axis), unless scope adds non-blocking gates. Risk accepted: the same gap as fulfillment
  misbehaviour #1.
- **Estimate accuracy.** Fulfillment's XL estimate was about 5× low. The estimate is recomputed per the spec
  method and flagged provisional; actuals from the proof run are recorded next to it.
- **Context-level codification of the ticket queue.** `context/cedar/generation-spec.md` still describes a
  single `TICKET.md`. That stays true because the single shape is still supported. Codifying the queue in
  the Context would need a version bump and is not part of this plan.
- **Phase-1/4 soft gates and the clone `git init` fix** (fulfillment misbehaviours #1, #12): out of scope by
  decision. The proof run's executor can still run `git log` upward, so the operator watches for it by hand.
- **Gate (b), the feature, under a control run.** V13 never stages the feature request alongside a
  bug, so the feature's autopilot resistance rests on V7's measured ladder (stub / naive → red), not on a
  control run. `generation-spec.md`'s whole-ticket control-run rule and DESIGN Build TODO 6 ("both tickets
  present") are superseded by staged delivery here. The build corrects the blueprint. A Context-level fix is a
  separate follow-up.
- **Cross-model robustness of the control run.** It is one run on one model. It is noted in the proof, not generalized.

## Baselines to capture before work starts
- `git rev-parse HEAD` plus a commit of the current uncommitted `DESIGN.md` edit → tag `credentials-v0-baseline`
  (V12 diffs against it). **The design file is currently uncommitted. Capturing this is the only deadline-bound step.**
- Toolchain versions: `cargo --version`, `rustc --version`, `dart --version`, and `flutter --version` if installed.
- Registry snapshots for the pinned deps (V4), captured at pin time.
