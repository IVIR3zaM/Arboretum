# Harness design

The harness is Arboretum's **interface**. A learner never edits a practice by hand against the
repo; they go through the harness, which runs the practice *for* them with an AI assistant and
grades *how they drove*. It is agent-agnostic — any capable assistant can play the roles — and
this document is the contract it follows. ([`../AGENTS.md`](../AGENTS.md) is the short version an
agent reads to run it today; the built runner is Phase 2.)

---

## 0. The one inviolable rule — clone and jail

**The harness never runs prompts against `practices/<id>/` itself. Ever.**

Every session begins by **cloning** the chosen practice into an isolated, disposable workdir,
and the assistant agent is **jailed** to that clone — no read or write outside it. The original
practice is read-only source of truth; a thousand sessions leave it untouched.

```
practices/deliveries/            ← source of truth, READ-ONLY, never mutated
.sessions/2026-09-10T14-03-runner/
  work/                          ← clone the learner + assistant touch: the service repo and the
                                   work items ONLY (no _solutions/, no README.md, no practice.json)
  golden/                        ← the practice's _solutions/ + practice.json + the Context,
                                   for the EXAMINER only
  transcript.jsonl               ← every learner prompt + assistant response, in order
  feedback.md                    ← written at the end (assess) or alongside (train)
```

Two consequences that matter:
- The clone the assistant sees has the **exercise material stripped** — `_solutions/` (the answer
  key, the hidden tests, the rubric), `README.md` (the learner's briefing, which names the phases
  and the disciplines under test) and `practice.json` (the manifest, which names the planted bug
  and every trap). What remains is a service repo and a couple of work items. This is not
  squeamishness about spoilers: a practice is an instrument for measuring how someone drives, and
  an assistant that has read the briefing or the manifest has been coached by the instrument. A
  trap that the workdir warns about measures nothing. The learner reads the README *before* the
  session, outside the clone.
- **The work items are staged, not dumped.** The clone starts with `TICKET.md` only;
  `FEATURE-REQUEST.md` is handed over when phase 3 begins. A learner never holds a bug report and a
  feature brief at the same time — work does not arrive that way, and a clone carrying both lets
  the assistant read ahead and plan around a brief nobody has given it, which blunts the phase it
  has not reached. The harness holds each item until its phase. **A Cedar `reference/` is not a
  work item and is not staged** — it is in the clone from the start, for the reasons in the next
  paragraph.
- **The clone is its own git repository.** After stripping and staging, setup runs `git init` in
  `work/` and commits the stripped tree as `baseline (stripped clone)`. Without it, `git log` inside
  `work/` resolves to the Arboretum repo above the clone — its whole history, `_solutions/` included;
  with it, the learner's changes have a real diff surface against that baseline. The nested repo
  lives under the gitignored `.sessions/`, so Arboretum never tracks it.
- The examiner reads `_solutions/` and the Context from `golden/`, which the assistant/learner
  **cannot** see. The grader — the practice's **declared** command (`practice.json` →
  `commands.grade`; `node _solutions/grade.mjs` for the seed, `cargo run --bin grade` for a Rust kata, a
  wrapper like `bash _solutions/grade.sh` for a multi-package kata, …) — is run by the harness against the
  clone, not by the learner. The harness reads the command from `practice.json`; it assumes no
  particular toolchain.

**Multi-package practices and a read-only `reference/` (Context Cedar).** The clone-and-jail rule
is unchanged: the practice is still **one** cloned folder. From Cedar on, that folder may hold
several package dirs (e.g. `backend/` + `app/`) and a top-level **`reference/`** — a read-only
snapshot of the *external* world the repo talks to but does not own (a sibling service's contract,
cloud infra config, a method spec). The assistant **may read `reference/`** but must not treat it
as the working repo or edit it; it is the truth a Cedar practice's FM-16 defect depends on, and
what the learner's research pass distills into a **`research-notes.md`** written inside `work/`.
This is still a single clone, still jailed — `reference/` and `research-notes.md` both live inside
`work/`, and the jail's "no reads or writes outside the clone" is untouched. `_solutions/`
stripping is unchanged.

`reference/` is present **from the first prompt of the session**, not staged with the research
pass. It stands for documentation an engineer already has access to on day one — a vendor's
published API docs, the infra console, a protocol spec — and a Cedar practice's packages typically
read it at runtime, so a clone without it does not run. Handing it over at the moment the research
pass is due would be the coaching the Context forbids: it announces that the local repo is not the
whole story, which is the judgement FM-16 exists to measure. What the harness watches is whether
the learner opens it unprompted.

---

## 1. The agents (multi-agent)

Separating who *does* the work from who *grades* it is deliberate — a grader that is also the
author is biased toward its own output (Anthropic's "second opinion / fresh-context review"
best practice). Roles:

- **Orchestrator** *(the harness core).* Picks the mode, clones the practice, launches the
  agents, enforces the jail, records the transcript, decides when an assess round ends, and
  writes the outputs. Holds no opinion about code; it runs the protocol.
- **Assistant / Executor.** The agent that actually executes the **learner's** prompts against
  the clone — edits files, runs tests, reports back. This is what the learner "drives." It is
  jailed to `work/` and is given the learner's prompts verbatim. It does **not** grade.
- **Examiner / Evaluator.** Judges the run from **three inputs** (see §2). Runs in a fresh
  context. May itself be **multiple sub-agents**:
  - an **outcome checker** — runs the practice's declared grade and test commands on the clone,
    reads the diff, records objective results;
  - a **transcript judge** — reads the learner's prompts against the golden context and the
    rubric, scoring each prompting round on the driving axis;
  - an **aggregator** — reconciles the two and writes `feedback.md`.
- **Trainer** *(train mode only).* The examiner's transcript-judge logic, but allowed to
  interject **during** the run instead of only at the end.

---

## 2. What the examiner evaluates — its three inputs

The examiner never grades from the prompt alone. It always reads **all three**:

1. **Its golden context** — the Context version it was created from (`context/<tree>/goals.md`,
   `best-practices.md`, `failure-modes.md`) **plus** the practice's `_solutions/` (rubric,
   trap-manifest, feature-qa, FIX). This is the standard it grades *against*.
2. **The learner's prompts** — the ordered transcript of what the learner told the assistant
   (and the assistant's responses). This is *how they drove*.
3. **The result on the cloned practice** — the diff, and the outcome of the unit suite and the
   hidden grader run against the clone. This is *what their driving produced*.

For each prompting round the examiner answers: *what signal was the learner going for · was the
prompt good practice (which best-practice / which failure-mode did it hit or miss) · what was
the consequence in the code · what would the best-practice prompt have been.* That is the shape
of every line in `feedback.md`.

---

## 3. The three modes

### Mode READ — understand the golden context first
No clone, no execution. The harness produces a **readable primer** for a chosen Context version
from its `goals.md` + `best-practices.md` + `failure-modes.md`: what this version teaches, the
disciplines, the failure modes, and how a practice will exercise them. The learner reads it to
know what they are about to be trained on.
- **Output:** a primer file (or rendered page) for `context/<tree>/`.

### Mode ASSESS — a diagnostic round ("interview")
The learner drives a practice themselves. The **Executor** runs their prompts on the clone. The
**Examiner observes silently** — **no live feedback.** The Orchestrator ends the round when any
of these is true:
- the practice is **complete** (grader passes and the phases are done), **or**
- the learner is **stuck** (repeated failed attempts, no progress, or they ask to stop), **or**
- the Examiner has **enough signal** — it can already characterize where the learner is strong
  and where they are lacking, so continuing adds no diagnostic value.

Then the Examiner writes **`feedback.md`**: a per-round breakdown — for each prompting round,
what the learner did, where it was good and where it was not, the consequence it had on the
practice, and the best practice for that moment. The learner reads it afterward.
- **Output:** `feedback.md` (the diagnosis), plus the objective scorecard.

### Mode TRAIN — a coached round ("normal")
The learner drives a practice with the **Executor** running their prompts **and** the
**Trainer** coaching **as they go** — catching a weak prompt before its consequence compounds,
suggesting the best-practice move, confirming good ones. This is the assistant-and-trainer mode:
remediation, not diagnosis.

**Name the discipline, not the answer.** The Trainer reads `golden/`, so its interjections are the
one channel through which the answer key can reach the learner mid-run. A coaching note names the
discipline being skipped or the class of question worth asking — *"you haven't seen it fail yet"*,
*"what does the system on the other side of this boundary promise?"*, *"which of those claims did
you watch being measured?"* — and never the finding, the clause or the number: not the defect the
Trainer knows is planted, not the sentence of a reference document that settles the question, not
the figure that is wrong. A move the learner makes after a coaching note is coached, not
spontaneous; the practice rubric's Source column records which.
- **Output:** the coached session transcript + a short closing summary.

---

## 4. The suggested path — mastering a Context

To actually *learn* a Context version (e.g. `alder`), the recommended path is:

```
READ (alder)  →  ASSESS (a practice)  →  TRAIN (a practice)   [→ re-ASSESS to confirm]
 learn what      find out where you      drill the gaps with
 it teaches      are weak, no help       live coaching
```

Diagnose before you remediate. The goal is that by the end of the path the learner has
internalized that Context version — its best practices are reflexes and its failure modes are
ones they now avoid without prompting.

---

## 5. What exists today vs. Phase 2

- **Today:** an agent can *be* the harness by following this document and [`../AGENTS.md`](../AGENTS.md)
  — clone the practice manually, jail itself to the clone, keep the transcript, and run the
  examiner as a fresh-context pass. The objective gate — the practice's declared `commands.grade`
(`node _solutions/grade.mjs` for the seed) — already works.
- **Phase 2 (build):** the `arbor` runner CLI automates the clone/jail, the transcript capture,
  the multi-agent examiner, time/token actuals, and the `feedback.md` format. See
  [`../docs/DISTRIBUTION.md`](../docs/DISTRIBUTION.md).
