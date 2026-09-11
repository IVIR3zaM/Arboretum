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
3. **Strip `_solutions/` from the learner's clone.** The learner and the executor must not be
   able to see the answer key, the hidden tests, the rubric, or the fix. Keep `_solutions/` and
   the Context aside as the **examiner's** golden context only.
4. **Separate executor from examiner.** The agent that runs the learner's prompts must not be the
   one that grades them; grade in a fresh context (a sub-agent or a separate pass).
5. **The examiner grades from three inputs, never one:** its golden context (Context +
   `_solutions/`), the learner's prompt transcript, and the result in the cloned folder (the diff
   plus the practice's declared **grade** and **test** commands, which *you* run, not the learner).
6. **Read commands from `practice.json`, never hardcode a toolchain.** Each practice declares
   `commands.install` / `commands.test` / `commands.grade` for its own stack — `cargo test`,
   `go test ./...`, `pytest`, `npm run grade`, etc. The harness runs those. Assuming `npm` breaks
   every non-Node practice.
7. **In `assess`, no feedback until the end.** In `train`, coach as you go.
8. **A `reference/` in the clone is read-only external truth (Cedar practices).** A Cedar practice
   is still **one** cloned folder, but it may hold several package dirs and a top-level
   `reference/` (a sibling service's contract, cloud infra config, a method spec). The assistant
   **may read `reference/` but must not edit it or treat it as the working repo**; the learner's
   research pass distills it into a **`research-notes.md`** written inside `work/`. The jail is
   unchanged — `reference/` and `research-notes.md` are inside the clone; nothing outside it is
   ever read or written.

## Running a mode today (before the built runner exists)
```
# one-time per session, for assess/train:
cp -R practices/<id> .sessions/<stamp>/work && rm -rf .sessions/<stamp>/work/_solutions
cp -R practices/<id>/_solutions .sessions/<stamp>/golden          # examiner only
```
Then: execute the learner's prompts inside `work/`; keep an ordered transcript; run the
practice's declared grade command (`practice.json` → `commands.grade`, against a copy that still
has `_solutions/` or the `golden/` grader) to score; and in `assess`, write
`.sessions/<stamp>/feedback.md` at the end per the rubric shape in `harness/DESIGN.md §2`.

## Map
- `context/<tree>/` — the Context (`context/alder/` is the foundation; `context/cedar/` adds
  multi-repo, external-truth, and context-rot training on top of it).
- `generator/CONTRACT.md` — generate a new practice.
- `harness/DESIGN.md` — the full multi-agent design and the three modes.
- `practices/deliveries/` — the seed kata (Alder). `practices/credentials/DESIGN.md` — the first
  Cedar practice, as a blueprint (not yet runnable).
- `docs/` — concept, prior-art, distribution, tree-naming.

## This repo's own working rules (for an agent editing Arboretum itself)
- Keep it tool-agnostic: the harness and generator are contracts any assistant can follow.
- A practice's `_solutions/` is the answer key — never surface it to a learner through the
  harness, and never weaken a grader to make a run pass.
- Don't add anyone's personal or biographical origin to these files; the content stands on its
  own as product knowledge.
