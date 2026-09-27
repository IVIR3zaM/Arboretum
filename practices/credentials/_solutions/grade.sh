#!/usr/bin/env bash
# grade.sh — the wrapper `practice.json`'s `commands.grade` invokes.
#
# Runs the hidden axes in order and ANDs them worst-case:
#   (a)  grade.d/a.sh  — Ticket 1: did:web issuer resolution at the verification root
#   (a2) grade.d/a2.sh — Ticket 2: webhook notifier acceptance
#   (b)  grade.d/b.sh  — the wallet app's integration suite against the verifier
# Each axis script prints, as its last line, `axis <x>: PASS|FAIL <n>/<m>` and
# exits 0 only on PASS. A missing axis script is reported as
# `axis <x>: MISSING` and counts as FAIL. The last line here is
# `worst-case: PASS|FAIL`; this script exits 0 only when every axis passes.
#
# This script lives INSIDE `_solutions/`, which the harness strips before a
# learner ever sees the clone; the harness runs it against a copy that still
# has `_solutions/`. Hermetic: no network (the hosted did.json documents are
# served from reference/infra/, Rust builds run --offline --locked).
# Never weaken these checks to make a run pass.

set -uo pipefail
# run from the practice root; this script sits one level down in _solutions/
cd "$(dirname "${BASH_SOURCE[0]}")/.."

overall=0
summary=()

for axis in a a2 b; do
  script="_solutions/grade.d/$axis.sh"
  echo "=================================================================="
  echo " axis $axis ($script)"
  echo "=================================================================="
  if [ ! -f "$script" ]; then
    line="axis $axis: MISSING"
    echo "$line"
    overall=1
  else
    out="$(bash "$script" 2>&1)"
    status=$?
    printf '%s\n' "$out"
    line="$(printf '%s\n' "$out" | tail -n1)"
    if [ "$status" -ne 0 ] || ! printf '%s\n' "$line" | grep -qE "^axis $axis: PASS [0-9]+/[0-9]+\$"; then
      overall=1
      if ! printf '%s\n' "$line" | grep -qE "^axis $axis: (PASS|FAIL)"; then
        line="axis $axis: FAIL (no result line, exit=$status)"
      elif [ "$status" -ne 0 ]; then
        line="${line/: PASS /: FAIL }"
      fi
    fi
  fi
  summary+=("$line")
  echo
done

echo "=================================================================="
echo " summary (worst-case; every axis must pass)"
echo "=================================================================="
printf '%s\n' "${summary[@]}"
if [ "$overall" -eq 0 ]; then
  echo "worst-case: PASS"
else
  echo "worst-case: FAIL"
fi
exit "$overall"
