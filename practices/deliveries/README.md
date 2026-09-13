# Kata: Deliveries

A small subscription-box **delivery-scheduling** service — TypeScript, Node 22, zero
dependencies. Customers get a recurring box on a cadence; each delivery has a **cutoff**
(a local wall-clock moment, some days before shipping, after which the box is locked).

This is a **driving-test kata**: you work the problem *with* an AI assistant, and you are
training the disciplines that keep AI output correct — not raw typing speed. The traps are not
signposted. Nothing in the workdir your assistant sees says where they are, or that there are
any — you get a ticket and a PM brief, the way you would at work.

| | |
|---|---|
| **Estimated time** | ~60 min (M tier) |
| **Estimated tokens** | ~25,000 (one assistant, five phases) |
| **Stack / domain** | TypeScript · Node 22 · subscription-box delivery scheduling |
| **Context version** | [`alder`](../../context/alder/) @1.2.0 |

## Setup

This file, `practice.json` and `_solutions/` are **exercise material**, and the harness keeps
all three out of the clone your assistant works in. What it gets is the service repo plus the
two work items (`TICKET.md`, `FEATURE-REQUEST.md`) — a task, not a briefing.

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
2. **Fix the bug.** Read [`TICKET.md`](TICKET.md). It is a customer symptom, not a file and a
   line. Build your own model of the mechanism **before** you delegate a fix, and **reproduce
   the report with a failing test first**. Then fix the root: a patch that silences the symptom
   at one call site, or that only holds on the machine you happen to be sitting at, is not a
   fix.
3. **Build the feature.** Read [`FEATURE-REQUEST.md`](FEATURE-REQUEST.md). It is as thin as a
   real PM brief. Work out what you still need to know and **ask** before you delegate, read
   the code the change has to land in, and build the **smallest correct thing**.
4. **Improvements.** Ask the assistant to find (not recite) the highest-value correctness and
   robustness issues remaining, ranked, each with the evidence in the code that supports it.
5. **Review.** Review the diff as if it were a teammate's PR: name a weakness in your own
   change, say what you verified and what the AI got wrong, and state one trade-off you made
   and the condition under which you'd revisit it.

> **Grading.** A hidden acceptance grader is the objective gate, and **the harness runs it —
> not you, and not your assistant.** Neither of you ever sees it, and a green `node --test` is
> not the bar. But be clear about what that gate is worth: a strong assistant can clear it from
> a single careless prompt, and that is **not** the same as having driven well. How you drove —
> reproduced before fixing, asked about the things the brief does not say, rejected bad output,
> held the change to what was asked for — is the other half, and the half this platform cares
> about most. See the [rubric](_solutions/rubric.md) after you finish (don't read it first).

`_solutions/` holds the answer key (hidden tests, held-back requirements, trap manifest,
rubric). **Opening it defeats the kata** — the whole point is to reach the answers by driving
the assistant well.

## Proof that it works (maintainers)

[`_solutions/proof-train-2026-09-13.html`](_solutions/proof-train-2026-09-13.html) is a recorded
end-to-end **Train-mode** run of this kata — open it in a browser. A casual engineer drives all
five phases in order, taking the shortcut every time; the work items are staged one phase at a
time, the trainer coaches between rounds, and every trap fires. It records, per round: the
learner's prompt, what the assistant did, the trap that fired *by design*, the trainer's
interjection, and the real command output (baseline 15/15 unit · **0/13** grader → **4/13** on the
prescribed shortcut with a green 18-test suite → **8/13** after the root fix → **13/13** once the
PM was finally asked). It closes with a coverage table mapping every discipline and failure mode
`practice.json` claims to the round that evidences it. It lives in `_solutions/` because it
necessarily reveals the fix — **don't open it before attempting the kata.** Re-run and refresh it
whenever the practice changes.
