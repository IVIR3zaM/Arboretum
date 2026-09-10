# Kata: Deliveries

A small subscription-box **delivery-scheduling** service — TypeScript, Node 22, zero
dependencies. Customers get a recurring box on a cadence; each delivery has a **cutoff**
(a local wall-clock moment, some days before shipping, after which the box is locked).

This is a **driving-test kata**: you work the problem *with* an AI assistant, and you are
training the disciplines that keep AI output correct — not raw typing speed. Most of the
traps here are invisible to a naive "fix the bug / implement this" prompt.

| | |
|---|---|
| **Estimated time** | ~60 min (M tier) |
| **Estimated tokens** | ~25,000 (one assistant, five phases) |
| **Stack / domain** | TypeScript · Node 22 · subscription-box delivery scheduling |
| **Context version** | [`alder`](../../context/alder/) @1.1.0 |

## Setup
```bash
cd practices/deliveries
node --test test/*.test.ts   # 15 tests, all green
npm start                    # a tiny end-to-end run
```
No install step — it runs on Node ≥ 22.18 with built-in TypeScript.

## The five phases (work them in order, on a clock)

1. **Understand** *(no edits).* Ask the assistant to map the module boundaries, the invariant
   each module owns, and where state is mutated — then to name the three places a correctness
   bug is most likely to hide, and why. Do not let it change anything yet.
2. **Fix the bug.** Read [`TICKET.md`](TICKET.md). It is a customer symptom, not a file and
   line. **Build a model of how cutoffs work before you delegate a fix** — prompting "just fix
   it" without understanding the timezone logic will loop: it passes the unit tests and stays
   red on the grader, or it patches the symptom and the defect resurfaces. **Reproduce it with a
   failing test first**, then fix the *root*. `npm run grade` scores the fix across three server
   timezones — a fix that only works on your machine, or that hardcodes a fixed offset, does not
   pass.
3. **Build the feature.** Read [`FEATURE-REQUEST.md`](FEATURE-REQUEST.md). It is deliberately
   underspecified. Gather the requirements *before* you delegate — there is a trap that
   punishes a straight "implement this" prompt. Build the **smallest correct thing**.
4. **Improvements.** Ask the assistant to find (not recite) the highest-value correctness and
   robustness issues remaining, ranked. There are several real ones seeded in the code.
5. **Review.** Review the diff as if it were a teammate's PR: name a weakness in your own
   change, say what you verified and what the AI got wrong, and state one trade-off you made
   and the condition under which you'd revisit it.

> **Grading.** `npm run grade` is the objective gate (timezone correctness). How you *drove*
> — reproduced before fixing, rejected bad output, matched the altitude of a small exercise
> instead of over-building — is the other half, and the half this platform cares about most.
> See the [rubric](_solutions/rubric.md) after you finish (don't read it first).

`_solutions/` holds the answer key (hidden tests, held-back requirements, trap manifest,
rubric). **Opening it defeats the kata** — the whole point is to reach the answers by driving
the assistant well.

## Proof that it works (maintainers)

[`_solutions/proof-train-2026-09-10.html`](_solutions/proof-train-2026-09-10.html) is a recorded
end-to-end **Train-mode** run of this kata — open it in a browser. It documents the harness, date,
and model used, and for each phase: the learner's prompt, how the assistant behaved, the trap that
fired *by design*, the trainer's coaching, and the real command outcome (baseline 15/15 unit ·
grader 0/8 → final 21/21 unit · grader **8/8** worst-case). It is evidence that every planted trap
still bites and that good driving converges. It lives in `_solutions/` because it necessarily
reveals the fix — **don't open it before attempting the kata.** Re-run and refresh it whenever the
practice changes.
