# AGENTS.md — how to operate Arboretum

This file is the entry point for **any AI agent** (and for the human reading over its shoulder).
It is intentionally tool-agnostic. Claude Code also reads it via [`CLAUDE.md`](CLAUDE.md).

## What Arboretum is
A training ground for using AI coding assistants well. A versioned, tree-named **Context**
(`context/<tree>/`) encodes the training goals, the known AI best practices, and the known AI
failure modes. A **generator contract** ([`generator/CONTRACT.md`](generator/CONTRACT.md)) turns
a Context into **practices** (`practices/<id>/`) — runnable katas with a hidden bug, an
underspecified feature, latent defects, and a grading oracle. The **harness**
([`harness/DESIGN.md`](harness/DESIGN.md)) is the interface: it runs a practice for a learner and
grades how they drove.

## What a user can do here
Offer the learner these options:

1. **Read a Context** (`read`) — give them a primer on a Context version (e.g. `alder`) from its
   `goals.md` + `best-practices.md` + `failure-modes.md`, so they know what they'll be trained
   on. No clone, no code.
2. **Assess on a practice** (`assess`) — they drive a practice; you execute their prompts but
   give **no live feedback**; at the end (or when they're stuck, or when you have enough signal)
   you write a `feedback.md` debrief of each prompting round.
3. **Train on a practice** (`train`) — they drive a practice and you **coach live** as they go.
4. **Generate a new practice** — from a Context version + a domain + a stack, following
   [`generator/CONTRACT.md`](generator/CONTRACT.md).

**Suggested path to master a Context:** `read` → `assess` → `train`. Diagnose, then remediate.

## Rules for an agent running the harness — NON-NEGOTIABLE
These come from [`harness/DESIGN.md`](harness/DESIGN.md §0–§2). Follow them exactly.

1. **Never run prompts against `practices/<id>/` itself.** Every session, **clone** the practice
   into a disposable session workdir and work only there. The original is read-only.
2. **Jail the assistant role to the clone.** No reads or writes outside the session workdir.
3. **Strip the exercise material from the clone — `_solutions/`, `README.md`, `practice.json`.**
   The learner and the executor must not be able to see the answer key, the hidden tests, the
   rubric, or the fix. But the answer leaks through more than `_solutions/`: the practice
   `README.md` is the *learner's* briefing (it names the phases and the disciplines under test)
   and `practice.json` names the planted bug and the traps outright. An assistant that reads
   either one is being coached, and the traps stop testing anything. **What the clone holds is
   the service repo plus the work item of the moment** — the source, the tests, the stack
   manifest, and whichever of `TICKET.md` / `FEATURE-REQUEST.md` the learner has reached (rule 4)
   — so the assistant meets the task the way an engineer would.
   `_solutions/`, `README.md`, `practice.json` and the Context stay aside as the **examiner's**
   golden context; the learner reads the README before the session, not through the assistant.
4. **Deliver the work items one phase at a time.** The learner never holds the ticket and the
   feature request at once — that is not how work arrives, and a clone containing both lets the
   assistant read ahead, plan around a brief nobody has given it yet, and blunt the phase it has
   not reached. Stage them: the clone starts with `TICKET.md` only; `FEATURE-REQUEST.md` is copied
   in when phase 3 begins. Each phase's prompts are the learner's; the harness holds the rest back.
   **A Cedar `reference/` is the exception — it is in the clone from the start.** It is the
   external documentation an engineer already has on day one, the packages usually read it at
   runtime, and handing it over when the research pass is due would itself announce that the local
   repo is not the whole story — the exact judgement FM-16 measures. The trap is that a
   single-scope run never opens it, not that it is hidden.
5. **Separate executor from examiner.** The agent that runs the learner's prompts must not be the
   one that grades them; grade in a fresh context (a sub-agent or a separate pass).
6. **The examiner grades from three inputs, never one:** its golden context (Context +
   `_solutions/`), the learner's prompt transcript, and the result in the cloned folder (the diff
   plus the practice's declared **grade** and **test** commands, which *you* run, not the learner).
7. **Read commands from `practice.json`, never hardcode a toolchain.** Each practice declares
   `commands.install` / `commands.test` / `commands.grade` for its own stack — `cargo test`,
   `go test ./...`, `pytest`, `node _solutions/grade.mjs`, etc. The harness runs those (the grade
   command against a copy that still has `_solutions/`). Assuming `npm` breaks every non-Node
   practice.
8. **In `assess`, no feedback until the end.** In `train`, coach as you go.
9. **A `reference/` in the clone is read-only external truth (Cedar practices).** A Cedar practice
   is still **one** cloned folder, but it may hold several package dirs and a top-level
   `reference/` (a sibling service's contract, cloud infra config, a method spec). The assistant
   **may read `reference/` but must not edit it or treat it as the working repo**; the learner's
   research pass distills it into a **`research-notes.md`** written inside `work/`. The jail is
   unchanged — `reference/` and `research-notes.md` are inside the clone; nothing outside it is
   ever read or written.
10. **An agent with golden access is not a learner.** If the learner's prompts are written by an
    agent that can read `golden/` — typically the operator role-playing the learner to record a
    proof — the run, its grade and any proof recorded from it are labelled a **calibration run**,
    not a learner grade. It is good evidence of how the assistant behaves and whether the traps
    fire; it is no evidence of a learner's judgement, because answer-key content reaches the
    prompts by construction. The Trainer's side of the same leak is ruled on in
    [`harness/DESIGN.md`](harness/DESIGN.md) §3 (Mode TRAIN); the practice rubric's Source column
    records, row by row, where each move came from.

## Running a mode today (before the built runner exists)
```
# one-time per session, for assess/train:
cp -R practices/<id> .sessions/<stamp>/work
rm -rf .sessions/<stamp>/work/_solutions                          # the answer key
rm -f  .sessions/<stamp>/work/README.md .sessions/<stamp>/work/practice.json   # the briefing + the manifest
cp -R practices/<id>/_solutions .sessions/<stamp>/golden          # examiner only
cp practices/<id>/practice.json .sessions/<stamp>/golden/         # examiner reads the commands from here
mv .sessions/<stamp>/work/FEATURE-REQUEST.md .sessions/<stamp>/staged-FEATURE-REQUEST.md
                                                                  # hand it over when phase 3 starts, not before
# make work/ its own git repo, so git inside the clone can't reach Arboretum's history (or _solutions/):
git -C .sessions/<stamp>/work init -q
git -C .sessions/<stamp>/work add -A
git -C .sessions/<stamp>/work -c user.name=arboretum-harness -c user.email=harness@arboretum.invalid -c commit.gpgsign=false commit -q -m "baseline (stripped clone)"
```
Then: execute the learner's prompts inside `work/`; keep an ordered transcript; run the
practice's declared grade command (`practice.json` → `commands.grade`, against a copy that still
has `_solutions/` or the `golden/` grader) to score; and in `assess`, write
`.sessions/<stamp>/feedback.md` at the end per the rubric shape in `harness/DESIGN.md §2`.

## Repository layout & where files go
Every folder has **one** responsibility. Before creating or moving a file, find its home here.
The recurring mistake is putting a file where it's convenient instead of where it belongs (e.g. a
practice **proof** dropped in `docs/` instead of the practice's `_solutions/`) — don't.

### The map — one responsibility per location
| Path | Holds | Never holds |
|---|---|---|
| `context/<tree>/` | The abstract, versioned Context: `goals.md`, `best-practices.md`, `failure-modes.md`, `generation-spec.md`, `CHANGELOG.md`, `VERSION`, `templates/`. Domain-agnostic training theory only. | Any reference to a specific practice, its domain, or its fix (see the working rules below). |
| `generator/` | The generation **contract** (`CONTRACT.md`) — the prompt an agent follows to turn a Context into a new practice. | Generated practices; per-practice files. |
| `harness/` | The harness **design** (`DESIGN.md`) — the multi-agent interface and the three modes. | Session outputs; runnable code (until the Phase-2 runner, which gets its own home). |
| `practices/<id>/` | One runnable kata, in three layers: the **work items + service repo** that get cloned (`TICKET.md`, `FEATURE-REQUEST.md`, source, tests, stack manifest); the **exercise material** that does not (`README.md` the learner's briefing, `practice.json` the manifest); and `_solutions/` (hidden). Cedar practices also hold multiple package dirs + a read-only `reference/`. A not-yet-runnable practice may be a single `DESIGN.md` blueprint. | Cross-practice or conceptual docs; anything belonging to the Context. |
| `practices/<id>/_solutions/` | The answer key, hidden from the learner: hidden grader/acceptance tests, `grade.*`, `trap-manifest.md`, `rubric.md`, `feature-qa.md`, `FIX.md`, `FEATURE-FIX.md` + `feature-reference/` (a reference elicited build of the phase-3 feature), **proof files** (`proof-<mode>-<YYYY-MM-DD>.html`), and Cedar's `context-map.md` / `doc-drift-ledger.md`. A **finished** practice ships only what runs, grades, and proves it (the proof is the record of a run) — build logs, run diaries, and a maintenance backlog of mis-calibrations do not live here; they stay in git history (a run's own session artifacts live under the gitignored `.sessions/`). | Build logs, run-by-run diaries, a running "misbehaviors" backlog, or any dev/maintenance notes. |
| `docs/` | Product & conceptual prose *about* Arboretum: `CONCEPT.md`, `PRIOR-ART.md`, `DISTRIBUTION.md`, `TREE-NAMING.md`. | Per-practice files, proofs, run outputs, or any generated/session artifact. |
| `one-pager/` | The standalone static marketing site (`index.html`). | App/harness code. |
| `.sessions/<stamp>/` | **All** per-run artifacts — the clone (`work/`, with the learner's `research-notes.md` inside it), the examiner's `golden/`, the transcript, `feedback.md`, `PROGRESS.md`, `session.env`. Disposable and **gitignored**. | Anything meant to be committed. |
| repo root | Project-level files only: `README.md`, `AGENTS.md`, `CLAUDE.md`, `LICENSE`, `NOTICE`, `.gitignore`. | New loose files — put it in the folder that owns it. |

### Placement rules (apply before writing any file)
1. **Session/run output goes in `.sessions/<stamp>/`, nowhere else** — transcripts, feedback,
   progress notes, clones, golden context, research notes. It is gitignored; never commit it and
   never scatter these into `docs/`, `practices/`, or the repo root.
2. **Anything that reveals a fix lives in that practice's `_solutions/`** — proofs above all
   (`generator/CONTRACT.md` §10). The harness strips `_solutions/` from the learner's clone, so
   this is the *only* safe home for the answer, the grader, and the recorded proof.
3. **Per-practice content stays under `practices/<id>/`.** If it's about one kata, it does not go
   in `docs/`, `context/`, or the root.
4. **Abstract, cross-practice training theory goes in `context/<tree>/`** — and stays
   domain-agnostic (see the working rules).
5. **`docs/` is prose about the product, not artifacts of running it.** If a file is generated,
   recorded, or tied to one practice/run, it does not belong in `docs/`.
6. **Don't create a new top-level directory or a new kind of file location without adding it to
   this table in the same change.** If nothing here fits, the file probably belongs inside an
   existing owner — ask before inventing a new one.

## This repo's own working rules (for an agent editing Arboretum itself)
- Keep it tool-agnostic: the harness and generator are contracts any assistant can follow.
- **Work on `main`; never create a new branch unless the user explicitly asks for one.** Commit
  and push directly to `main` by default. Don't open feature/topic branches on your own initiative,
  and if a stray branch already exists, merge it back into `main` and delete it rather than leaving
  it around.
- **Keep Contexts domain-agnostic — never name a specific practice or leak its domain into
  `context/<tree>/`.** A Context is the abstract, upstream source; practices are concrete
  instances generated *from* it, so a Context must not reference a practice by name (`deliveries`,
  `credentials`, …) or bake in its business domain or its planted bug/solution. Two reasons: it
  inverts the dependency (the practice is calibrated against the Context, not the other way round),
  and — because `read` mode primes a learner from `goals.md` + `best-practices.md` +
  `failure-modes.md` — a "Kata X: the timezone-on-cutoff bug" aside hands that learner the answer
  before they ever run the practice. Illustrate failure modes and generation inputs with
  *hypothetical* domains (e.g. "metering & billing"), point at the `practices/` directory
  generically rather than a named practice, and keep changelog entries at the level of tier and
  version, not the practice's name or its fix.
- A practice's `_solutions/` is the answer key — never surface it to a learner through the
  harness, and never weaken a grader to make a run pass.
- Don't add anyone's personal or biographical origin to these files; the content stands on its
  own as product knowledge.
