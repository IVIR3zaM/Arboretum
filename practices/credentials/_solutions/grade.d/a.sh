#!/usr/bin/env bash
# grade.d/a.sh — axis (a): Ticket 1 hidden acceptance (did:web issuer resolution).
#
# Builds and runs the grader crate in _solutions/grader/ (it depends on
# backend/ by path) hermetically: --offline --locked, using only crates the
# backend's own `cargo fetch` already downloaded. The grader calls the
# verification root directly across the hosted issuer states, the
# reference/-derived conformance vectors and a grader-only next rotation.
#
# Last line: `axis a: PASS|FAIL <n>/<m>`. Exits 0 only on PASS.
# Never weaken these checks to make a run pass.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../grader"   # rust-toolchain.toml pins the backend's toolchain here

out="$(CARGO_NET_OFFLINE=true cargo run --quiet --offline --locked --bin grade 2>&1)"
status=$?
last="$(printf '%s\n' "$out" | tail -n1)"

if [ "$status" -eq 0 ] && printf '%s\n' "$last" | grep -qE '^axis a: PASS [0-9]+/[0-9]+$'; then
  printf '%s\n' "$out"
  exit 0
fi

if printf '%s\n' "$last" | grep -qE '^axis a: (PASS|FAIL) [0-9]+/[0-9]+$'; then
  # the grader ran; report its own count, but never as a pass unless it exited 0
  printf '%s\n' "$out" | sed '$d'
  counts="${last##* }"
  echo "axis a: FAIL $counts"
else
  printf '%s\n' "$out"
  echo "(grader did not run to completion, exit=$status)"
  echo "axis a: FAIL 0/0"
fi
exit 1
