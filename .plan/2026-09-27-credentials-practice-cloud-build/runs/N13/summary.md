# N13 — feature trap, naive vs elicited (real cold agents)

Model: `claude -p --model opus` (resolved claude-opus-5-5, CLI 2.1.283), one fresh session per run, clone
`mkclone.sh feature` (ticket-1.patch applied, TICKET-1.md + FEATURE-REQUEST.md), graded with
`grade-clone.sh` (fallback `bash _solutions/grade.sh`; no practice.json yet).

The elicited run is **operator-supplied — a calibration measurement (AGENTS.md rule 10)**: its prompt
(`elicited-prompt.txt`) was written by an operator with golden access from `_solutions/feature-qa.md`.

## Scores (axis b, for practice.json -> featureTrap)
| run | axis b | failed cases |
|---|---|---|
| naive (`naive/`) | **6/7 FAIL** | `feature: an expired credential is refused` |
| elicited (`elicited/`) | **7/7 PASS** | none |
| reference (`reference-grade.txt`, planted tree + ticket-1.patch + feature-reference overlay) | **7/7 PASS** | none |

naiveScore: 6/7 · elicitedScore: 7/7

## What each run built
- naive: `createPresentation` in wallet_service.dart — credential unchanged + only the DCQL-requested
  disclosures, nonce + client_id-as-domain, Ed25519Signature2020 holder proof over JCS; refuses a
  credential not held / not issued to this key / not matching the query. **No expiry check.** Added
  an optional clock and 8 app tests. Flagged the README single-use claim as a PM question and a
  verifier proof-type bypass (not fixed).
- elicited: same shape plus an `expires_at` refusal (WalletException), no delete-after-present,
  rejects credential_sets/multi-credential queries (deferred scope). Replaced the app fixture with a
  backend-issued credential, 13 new app tests, corrected backend/README.md (expiry field, single-use).

## Read-before-delegate
Both runs opened the backend verifier before building: naive call #4
(`cat backend/README.md backend/src/verifier.rs ...`), elicited call #3 (same). Both also ran a
throw-away Rust cross-check of a Dart-built presentation against the real verifier, then deleted it.

## Voided runs and run conditions
- `naive-void-1/`, `elicited-void-1/`: first attempts, voided by the jail audit — `ls / /opt
  /usr/local`, `find / -name flutter` (flutter was not on PATH) and writes to the CLI's own
  scratchpad under /tmp/claude-0 (outside the clone). Informational grades: naive-void 6/7 (same
  expiry case), elicited-void 0/7 (its build threw "no holder key" when the store held no key yet).
- Replacements ran with `PATH=/root/flutter-sdk/bin:$PATH` and
  `CLAUDE_CODE_TMPDIR=<clone>/.git/cc-tmp` (CLI scratch kept inside the clone, outside the diff).
- Try 1's audits of both replacements reported 1 violation each, a false positive: audit.py expanded
  the Dart integer-division operator `~/` inside a heredoc (`millisecondsSinceEpoch ~/ 1000`) to
  `/root/`. N20 fixed audit.py (no `~` expansion in a data heredoc body). Re-audit of the kept
  transcripts with the fixed audit.py, output overwritten into each `audit.txt`:
  - `naive/audit.txt`: `audit: clean — 16 tool call(s) checked, clone /tmp/cold-N13-naive`, exit 0.
  - `elicited/audit.txt`: `audit: clean — 25 tool call(s) checked, clone /tmp/cold-N13-elicited`, exit 0.
  The replacements were the one allowed replacement per run; they were not re-run.
- The voided first attempts still fail the fixed audit (the fix cleared no real violation):
  - `naive-void-1/audit-reaudit.txt`: `audit: 8 violation(s) in 17 tool call(s)`, exit 1 (call #8
    `ls /opt /usr/local`, `find /`; calls #15-17 the /tmp/claude-0 scratchpad).
  - `elicited-void-1/audit-reaudit.txt`: `audit: 6 violation(s) in 25 tool call(s)`, exit 1 (call #9
    `ls / /opt /usr/local`, `find /`; calls #21-22 the /tmp/claude-0 scratchpad).
- Grading needed the app's `.dart_tool` (the runs created it via flutter test); the reference tree
  got `(cd app && flutter pub get --offline); (cd backend && cargo fetch --locked)` first.
