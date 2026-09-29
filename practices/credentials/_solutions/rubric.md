# rubric — grading `credentials`

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Grade from three inputs per
> AGENTS.md rules 5-6: this golden context (with `trap-manifest.md`, `feature-qa.md`, `FIX.md`,
> `context-map.md`, `doc-drift-ledger.md`), the learner's prompt transcript, and the result in the
> cloned folder (the diff plus the declared `commands.test` / `commands.grade`, which the examiner
> runs — never the learner's word for them). Compare outputs by pass/fail counts and exit codes,
> never raw bytes (`harness/DESIGN.md` §2).

## Axis A — objective gate (mechanical: run the commands)

Pass/fail, worst-case. This axis does not require reading the transcript.

1. **Backend unit suite stays green.** `cd backend && cargo test --offline --locked` — 68 tests on
   the shipped tree; the learner's new tests add to that. A fix that breaks existing coverage to pass
   the grader is not acceptable.
2. **Wallet unit suite stays green.** `cd app && flutter test --no-pub` — 20 tests on the shipped
   tree, plus the learner's.
3. **`bash _solutions/grade.sh` exits 0** (run against a copy that still has `_solutions/`, after
   `commands.install`) — three axes, all at full marks, worst-case:
   (a) **Ticket 1**, `grade.d/a.sh`, **26/26** — issuer states, retired keys, `reference/`-derived
   conformance vectors, a grader-only next rotation, the §3.2 URL mapping;
   (a2) **Ticket 2**, `grade.d/a2.sh`, **17/17** — `{small, large tenant} × {all healthy, first
   subscriber hangs}` plus a delivery-path failure: delivery within the 10 s budget, an observable
   timeout, canary ⇒ real delivery, no reserved names;
   (b) **the feature**, `grade.d/b.sh`, **7/7** — four wallet cases (subset, holder proof, nonce and
   domain binding, expiry refusal) and three cross-stack cases against the backend `Verifier`.
   Anything short of all three at full marks is a FAIL on this axis, however good the transcript.
   Verified baseline (shipped tree) **6/26 · 4/17 · 0/7** → reference build **26/26 · 17/17 · 7/7**,
   `worst-case: PASS` (`FIX.md`, `FEATURE-FIX.md`). A red case names what it checks, so it tells you
   which part of the model was missing; read it against Axis B.
4. **The feature gate discriminates.** `FEATURE-REQUEST.md` reads as "mostly packaging it up".
   Measured 2026-09-27: stub **0/7**; a holder-signed wrap-all build **1/7**; a naive one-shot hand-off
   by a fresh executor **6/7** (fails only the expiry refusal); the same executor with the held-back
   answers supplied by an operator **7/7** (a calibration run); the reference elicited build **7/7**.
   7/7 is required. The margin is one rule, so a 6/7 tells you which question went unasked: Q4.
5. **Robustness report — non-blocking, not part of the 50-point gate.** From the practice root of the
   graded copy run `bash _solutions/robustness-probes.sh` and report its last line,
   **`robustness n/9`**, next to the gate result. It is never called by `grade.sh` and never changes
   this axis's pass/fail or the grade exit code: a gate PASS with a low robustness score is still a
   PASS. The nine probes: W1, W2 held state handed out by reference (the store, latent #2); W3 the
   presentation shares no state with the held credential; G1 holder binding guarded on the
   presentation, not only on `requestCredential`; D1 a DCQL query naming no claim; D2 a query the
   credential cannot satisfy; N1 a tenant with zero subscriptions; N2 the reserved-name rule on a
   tenant subscription, not only the canary; S1 every status-list index revocable (latent #5).
   Captured 2026-09-27: shipped tree **1/9** (only N1), reference build **5/9** (W3, G1, D1, D2, N1),
   reference plus fixes for #2, #5 and a dispatch-side reserved-name guard **9/9**. Read a probe the
   learner's tree fails and the reference passes (W3, G1, D1, D2) as a defect their change introduced
   that phases 4-5 did not close; read W1/W2/S1 as latents still open; N2 as the rule applied at one
   entry point. It is evidence for Axis B rows 4.2 and 4.1, not a score of its own.

## Axis B — driving axis (scored from the transcript; requires reading it)

Score **every** row `present` / `partial` / `absent` with a one-line justification citing the actual
prompt text, and fill its **Source** cell with where the move came from: `spontaneous` (the learner
or their assistant, unasked), `trainer-prompted` (it followed a Trainer interjection —
`harness/DESIGN.md` §3, Mode TRAIN) or `operator-supplied` (the prompt carries content only the
golden context could have supplied — AGENTS.md rule 10). A move with more than one origin names each
part (e.g. `reference opened spontaneous; §3.2 cited trainer-prompted`). The Source cells below say
what to look for; replace them with the verdict. **Fill every row, including for phases the learner
skipped** — a skipped phase shows as a run of `absent` rows, not as silence. Axis A covers phases 2
and 3 only, so this checklist is the *only* record of how phases 1, 4 and 5 were driven. No credit for
the right answer appearing in the diff if the transcript shows it was reached by luck (e.g. deleting
the snapshot early return without ever opening `reference/did-web-method.md` or saying why the
onboarding copy is wrong).

### Phase 1 — understand / research

| # | Row | Present when | Score | Source |
|---|---|---|---|---|
| 1.1 | **Research pass (FM-16)** | `reference/` is opened before any fix is delegated, and a `research-notes.md` inside `work/` distils it: issuers are did:web; resolution is a live fetch of the current document; documents rotate and a retired key is not a key; the path-DID mapping; trust is a live registry question; (once Ticket 2 is staged) the 10 s hard kill, zero retries, no alarm, the tenant-kind index, the reserved-name rule. Graded against `context-map.md`. Notes that list files without saying what they contradict are `partial`; none is `absent`. | | `spontaneous` if the learner asked for the pass unprompted; `trainer-prompted` if it followed a nudge; `operator-supplied` if the prompt names a fact (§3.2, the snapshot, the 10 s kill) before any reference file was read |
| 1.2 | **Reconcile docs (FM-15)** | The learner calls out the stale lines rather than trusting them — above all `backend/README.md`'s `did:key`, and the "peer DIDs" comment — and says which source wins (`doc-drift-ledger.md`). Quoting a stale line as current truth fails the row even if the final diff is right. | | `spontaneous` / `trainer-prompted`; note if the assistant raised the contradiction and the learner only accepted it (credit the learner only for acting on it) |

### Phase 2 — fix the bugs (two staged tickets)

| # | Row | Present when | Score | Source |
|---|---|---|---|---|
| 2.1 | **Ticket 1 — reproduce before fix (FM-01, FM-02)** | A failing test (or a demonstrated failure) with a *rotated* issuer — a credential signed with a key the issuer publishes now, refused by the door — exists before the fix is requested. Editing on the strength of the ticket text alone is `absent`. | | `spontaneous` / `trainer-prompted`; the ticket does not ask for a reproduction, so it is never `operator-supplied` unless the prompt names the rotated issuer before the learner found it |
| 2.2 | **Ticket 1 — model before delegation (FM-13)** | Before asking for the fix the learner states, in their own words, why the door is wrong: it checks an onboarding copy, and did:web keys live in the document served now (and, for full credit, that path DIDs map without `/.well-known`). Anti-signal: non-converging rounds — a re-pin of the complaining club, then a special case — each declared "fixed" without the grader. | | `spontaneous`; `trainer-prompted` if the model came from a Trainer question; `operator-supplied` if the prompt hands over the root |
| 2.3 | **Ticket 2 — reproduce under the ticket's conditions** | The failure is shown for a tenant with many settings and/or a slow or hanging endpoint — with the canary green throughout — before any change. | | `spontaneous` / `trainer-prompted` |
| 2.4 | **Ticket 2 — reliability and observability: caught all four axes** | The delivered change addresses A1 (a timeout is observable: an event, not a log line), A2 (one slow endpoint cannot starve the rest), A3 (the tenant-kind index, not a scan) and A4 (the canary targets an endpoint the platform operates and runs on the real path) — and the learner can say why each alone would not close the incident. Three of four is `partial`: the recorded cold run fixed A2, A3, half of A1 and A4's position, left the reserved target, and scored a2 13/17. | | `spontaneous` / `trainer-prompted`, per axis if they differ (e.g. `A1-A3 spontaneous; A4 target trainer-prompted`) |
| 2.5 | **Ticket 2 — noticed the canary lies** | The learner (not just the assistant's summary) names that the health check was acknowledged before the real path ran and pointed at a reserved name, so a green canary said nothing about customers — and acts on it or routes the target question to Platform explicitly. Noticing it and still presenting the health check as meaningful is `partial` (the cold run did exactly this). | | `spontaneous` / `trainer-prompted` |

### Phase 3 — build the feature

| # | Row | Present when | Score | Source |
|---|---|---|---|---|
| 3.1 | **Requirements elicitation** | Before prompting for an implementation the learner asks (or has the assistant draft and then takes to the owners) questions close to `feature-qa.md` Q1-Q8: which claims, holder signature, replay binding, **expiry**, revocation, single-use, online/offline, minimal scope — and takes them to the PM / Verifier team / Platform, not to the assistant. A one-shot "implement `createPresentation`" is the anti-pattern (it measured 6/7). | | `spontaneous` / `trainer-prompted`; **`operator-supplied`** when the prompt carries the answers from `feature-qa.md` without the questions having been asked (the recorded elicited run is this) |
| 3.2 | **Read before delegate** | The learner (or the assistant, at the learner's request) reads how the backend verifier checks a presentation (`Verifier::verify_presentation`) before the holder side is built, and the build follows that wire contract. | | `spontaneous` (both recorded feature runs did this unasked) / `trainer-prompted` |
| 3.3 | **The single-use claim resolved out loud** | The README's "credentials are single-use" is raised and resolved with its owner (not in v1; the nonce stops replay of the same presentation) rather than silently enforced or silently ignored. | | `spontaneous` / `trainer-prompted` |

### Phase 4 — improvements

| # | Row | Present when | Score | Source |
|---|---|---|---|---|
| 4.1 | **Latent defects found, not recited** | The learner's own review surfaces ranked latent defects from `trap-manifest.md` (#7 proof-type fall-through, #6 no registry check, #1 replay keyed on `request_id`, #2 the store by reference, #5 the status-list off-by-one, #3 unbounded guard, #4 the expiry instant) as things *noticed in this code*, versus generic concerns that map to nothing here. Credit emergent findings (the manifest's emergent section). **A latent defect fixed silently before phase 4 is neither "found" nor "missed"** — it was never looked for, so it does not count here either way; score it on X.1. Probes W1, W2, S1 still failing are latents left open. | | `spontaneous` (the recorded ticket runs named #7, #6, #1 as asides unasked) / `trainer-prompted` |
| 4.2 | **Caught defects the change itself introduced** | Phase 4 checks the learner's *own* diff for robustness vectors the gate is blind to — above all the presentation sharing state with the stored credential (W3), a holder-binding check only in `requestCredential` (G1), degenerate queries (D1, D2) and the reserved-name rule applied only to the canary (N2). Read the **robustness report** (Axis A item 5): a probe the reference passes and the learner's tree fails is a defect the change introduced that this row did not catch. | | `spontaneous` / `trainer-prompted` |

### Phase 5 — review

| # | Row | Present when | Score | Source |
|---|---|---|---|---|
| 5.1 | **Honest review with intent (FM-14)** | The review triages — the resolver root, the URL mapping and the notifier's canary logic scrutinised; README fixes and test fixtures skimmed — anchored on the tickets' promises ("every approved issuer", "whatever the size of the account"), names a weakness in the learner's own change, what was verified and what the AI got wrong, and records a human decision on what ships now versus later (e.g. retired-key credentials now refused; no retries). A blanket "LGTM" or an unfiltered nit dump is `absent`. | | `spontaneous` / `trainer-prompted` |
| 5.2 | **New tests actually discriminate** | The review checks that the learner's new tests fail on the old code and pass in isolation. **Examiner action:** run them individually (`cargo test --offline --locked <name>`, `flutter test --no-pub --plain-name '<name>'`) against the shipped code and the fixed code, and report any that pass on both or only positionally. | | `spontaneous` / `trainer-prompted` |

### Cross-phase behaviours (score once, over the whole transcript)

| # | Row | Present when | Score | Source |
|---|---|---|---|---|
| X.1 | **Restraint / altitude-match (FM-10)** | Each fix and the feature stay minimal; anything extra (a document cache with TTL, a registry client, retries, a consent screen, credential selection) is *named and deferred out loud*, not silently built or silently dropped. **A planted latent defect fixed silently before phase 4 is scored here**: the unasked fix is the over-build, and splitting it back out and deferring it out loud is the recovery. The recorded ticket runs named #7, #6 and #1 and left them — that is the `present` shape. | | `spontaneous` / `trainer-prompted` |
| X.2 | **Verify-output: claims re-run, not summarised (FM-01, one level up)** | The learner requires measurements to be re-run rather than accepting a summary — "the suite passes", "4 new tests fail before and pass after", "callbacks now reach every subscriber" — and the examiner's own re-run agrees. **Examiner action:** re-run `commands.test` and `commands.grade` and check every self-reported count in the transcript against the real output. The recorded Ticket 2 cold run's "callbacks should now reach every subscriber" was true for delivery, and its own suite was green, yet a2 stood at 13/17: its summary presented the health check as meaningful while the canary still called a reserved domain (which it had listed as a follow-up). A claim can be accurate and still not close the ticket; only the re-run shows which. | | `spontaneous` / `trainer-prompted` |
| X.3 | **Structural choices surfaced as questions** | When a change needs a decision the tickets do not settle (the canary's real endpoint, the notifier's budget margin under the 10 s kill, refusing retired-key credentials, which side of the expiry instant is valid), the learner has the assistant ask before acting rather than decide-then-disclose. | | `spontaneous` / `trainer-prompted` |

### Anti-signals (any of these pulls Axis B down regardless of the final diff's quality)

- Declaring victory after the local suites go green, without ever running (or asking the harness to
  run) the grade, or without checking the fix against issuers and tenants the ticket did not name.
- Quoting `backend/README.md`'s `did:key` line, the "peer DIDs" comment, `expirationDate`, or
  "delivered concurrently … retried" as current fact in a prompt or the delivered summary.
- A Ticket 1 fix that special-cases an issuer DID, re-pins or edits `data/onboarded-issuers.json`, or
  hard-codes a key from `reference/`.
- A Ticket 2 fix that raises `DISPATCH_BUDGET`, or that treats the canary turning green as proof the
  incident is closed.
- A presentation built with no expiry check, disclosing every claim, or unsigned by the holder.
- Treating the assistant's first plausible diff as done without reading it — no comment on *why* it
  is correct, only that it "looks right" or "the tests pass".
- Accepting a summarised measurement (a failure count, "tests pass", "callbacks arrive") without
  requiring the command to be re-run, or leaning on a green test that could not have gone red.
- **A review answered from a summary or ticket list without reading the diff** — a yes/no merge
  verdict whose tool calls never open the changed files (`git diff`, the source), however reasonable
  the blockers it lists. Not a rubber stamp, and not a review.
