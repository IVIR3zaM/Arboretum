#!/usr/bin/env bash
# grade.sh — the wrapper `practice.json`'s `commands.grade` invokes.
#
# Runs the hidden graders for the WHOLE ticket against the live ERP feed and
# prints a worst-case summary. Three gates: (a) backend availability acceptance
# (phase-2 bug fix), (b) feature acceptance (phase-3 cart hold), (c) web
# integration. Exits 0 ONLY if all three are fully green; non-zero otherwise.
# Hermetic: reads static JSON fixtures from `reference/infra/erp-availability/`
# off disk — no network at grade time.
#
# This script (and everything it runs) lives OUTSIDE the learner's clone in
# spirit: it is checked in at the practice root only because `practice.json`
# needs a stable path to invoke, but its actual grading logic reads
# `_solutions/`, which the harness strips before a learner ever sees the
# clone (see AGENTS.md rule 3). Never weaken these checks to make a run pass.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

overall_exit=0

echo "=================================================================="
echo " fulfillment grader"
echo "=================================================================="

# ---------------------------------------------------------------------------
# (a) Backend acceptance: confirmOrder/availableToPromise against the live
#     ERP feed, run directly with node's built-in test runner (TAP output).
# ---------------------------------------------------------------------------
echo
echo "--- backend acceptance (node --test) ---"
backend_tap="$(node --test --test-reporter=tap _solutions/backend-acceptance.test.ts 2>&1)"
backend_status=$?
echo "$backend_tap"

backend_pass="$(printf '%s\n' "$backend_tap" | grep -m1 -E '^# pass ' | grep -oE '[0-9]+' || true)"
backend_fail="$(printf '%s\n' "$backend_tap" | grep -m1 -E '^# fail ' | grep -oE '[0-9]+' || true)"
backend_total="$(printf '%s\n' "$backend_tap" | grep -m1 -E '^# tests ' | grep -oE '[0-9]+' || true)"
backend_pass="${backend_pass:-0}"
backend_fail="${backend_fail:-0}"
backend_total="${backend_total:-0}"

if [ "$backend_status" -ne 0 ] || [ "$backend_fail" != "0" ] || [ "$backend_total" = "0" ]; then
  backend_ok=0
  overall_exit=1
else
  backend_ok=1
fi

# ---------------------------------------------------------------------------
# (b) Feature acceptance: the phase-3 cart hold, driven through its public
#     surface (placeHold + confirmOrder) against the live feed. RED while the
#     hold is a stub or built naively (not re-checked at confirm / not reserved
#     against live ATP); GREEN only for the minimal-correct hold on a fixed base.
# ---------------------------------------------------------------------------
echo
echo "--- feature acceptance (node --test) ---"
feature_tap="$(node --test --test-reporter=tap _solutions/feature-acceptance.test.ts 2>&1)"
feature_status=$?
echo "$feature_tap"

feature_pass="$(printf '%s\n' "$feature_tap" | grep -m1 -E '^# pass ' | grep -oE '[0-9]+' || true)"
feature_fail="$(printf '%s\n' "$feature_tap" | grep -m1 -E '^# fail ' | grep -oE '[0-9]+' || true)"
feature_total="$(printf '%s\n' "$feature_tap" | grep -m1 -E '^# tests ' | grep -oE '[0-9]+' || true)"
feature_pass="${feature_pass:-0}"
feature_fail="${feature_fail:-0}"
feature_total="${feature_total:-0}"

if [ "$feature_status" -ne 0 ] || [ "$feature_fail" != "0" ] || [ "$feature_total" = "0" ]; then
  feature_ok=0
  overall_exit=1
else
  feature_ok=1
fi

# ---------------------------------------------------------------------------
# (c) Web integration: the real storefront (App.tsx) against the real
#     backend, run via a SEPARATE vitest config (see vitest.web.config.ts's
#     own comment for why web/vite.config.ts can't be reused here).
# ---------------------------------------------------------------------------
echo
echo "--- web integration (vitest) ---"
web_out="$(cd web && npx vitest run --config ../_solutions/vitest.web.config.ts 2>&1)"
web_status=$?
echo "$web_out"

web_summary_line="$(printf '%s\n' "$web_out" | grep -E '^[[:space:]]*Tests[[:space:]]' | tail -n1)"
web_total="$(printf '%s\n' "$web_summary_line" | grep -oE '\(([0-9]+)\)' | grep -oE '[0-9]+' | tail -n1 || true)"
web_pass="$(printf '%s\n' "$web_summary_line" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || true)"
web_fail="$(printf '%s\n' "$web_summary_line" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || true)"
web_pass="${web_pass:-0}"
web_fail="${web_fail:-0}"
web_total="${web_total:-0}"

if [ "$web_status" -ne 0 ] || [ "$web_fail" != "0" ] || [ "$web_total" = "0" ]; then
  web_ok=0
  overall_exit=1
else
  web_ok=1
fi

# ---------------------------------------------------------------------------
# Worst-case summary
# ---------------------------------------------------------------------------
echo
echo "=================================================================="
echo " summary (worst-case; all three gates must be fully green)"
echo "=================================================================="
if [ "$backend_ok" -eq 1 ]; then
  echo "backend acceptance : PASS  ($backend_pass/$backend_total)"
else
  echo "backend acceptance : FAIL  ($backend_pass/$backend_total, exit=$backend_status)"
fi
if [ "$feature_ok" -eq 1 ]; then
  echo "feature acceptance : PASS  ($feature_pass/$feature_total)"
else
  echo "feature acceptance : FAIL  ($feature_pass/$feature_total, exit=$feature_status)"
fi
if [ "$web_ok" -eq 1 ]; then
  echo "web integration    : PASS  ($web_pass/$web_total)"
else
  echo "web integration    : FAIL  ($web_pass/$web_total, exit=$web_status)"
fi
echo

if [ "$overall_exit" -eq 0 ]; then
  echo "RESULT: PASS"
else
  echo "RESULT: FAIL"
fi

exit "$overall_exit"
