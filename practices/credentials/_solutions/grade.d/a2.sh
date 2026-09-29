#!/usr/bin/env bash
# grade.d/a2.sh — axis (a2): Ticket 2 hidden acceptance (the status-change webhook notifier).
#
# Builds and runs the grader crate in _solutions/grader/ (it depends on
# backend/ by path) hermetically: --offline --locked, using only crates the
# backend's own `cargo fetch` already downloaded. The `grade-a2` bin drives
# the notifier root under a paused clock across {small, large tenant} x
# {all healthy, one hanging endpoint} plus a delivery-path failure, with the
# budget and the reserved names read from reference/infra/, and reports the
# worst case. Transport and sink are injected: nothing leaves the process.
#
# Last line: `axis a2: PASS|FAIL <n>/<m>`. Exits 0 only on PASS.
# Never weaken these checks to make a run pass.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../grader"   # rust-toolchain.toml pins the backend's toolchain here

out="$(CARGO_NET_OFFLINE=true cargo run --quiet --offline --locked --bin grade-a2 2>&1)"
status=$?
last="$(printf '%s\n' "$out" | tail -n1)"

if [ "$status" -eq 0 ] && printf '%s\n' "$last" | grep -qE '^axis a2: PASS [0-9]+/[0-9]+$'; then
  printf '%s\n' "$out"
  exit 0
fi

if printf '%s\n' "$last" | grep -qE '^axis a2: (PASS|FAIL) [0-9]+/[0-9]+$'; then
  # the grader ran; report its own count, but never as a pass unless it exited 0
  printf '%s\n' "$out" | sed '$d'
  counts="${last##* }"
  echo "axis a2: FAIL $counts"
else
  printf '%s\n' "$out"
  echo "(grader did not run to completion, exit=$status)"
  echo "axis a2: FAIL 0/0"
fi
exit 1
