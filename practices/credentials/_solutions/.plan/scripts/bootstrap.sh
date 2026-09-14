#!/usr/bin/env bash
# bootstrap.sh — the first thing the cloud orchestrator runs on every start or resume.
# Checks out the build branch, installs the pinned toolchains if this VM lacks them, proves it can push,
# and prints the plan status. Safe to run any number of times.
set -euo pipefail

REPO=$(git rev-parse --show-toplevel)
cd "$REPO"
BR=claude/credentials-build
P=practices/credentials/_solutions/.plan

git fetch -q origin "$BR"
if [ "$(git rev-parse --abbrev-ref HEAD)" != "$BR" ]; then
  git checkout -q "$BR" 2>/dev/null || git checkout -q -b "$BR" "origin/$BR"
fi
git pull -q --rebase origin "$BR"

want=$(sed -n 's/^FLUTTER_VERSION=//p' "$P/scripts/cloud-setup.sh")
if ! command -v flutter >/dev/null 2>&1 || ! flutter --version 2>/dev/null | grep -q "Flutter $want"; then
  echo "bootstrap: installing toolchains (a few minutes, once per VM)"
  if [ "$(id -u)" = 0 ]; then bash "$P/scripts/cloud-setup.sh"; else sudo -E bash "$P/scripts/cloud-setup.sh"; fi
fi

if ! bash "$P/scripts/sync.sh" checkpoint; then
  echo "bootstrap: CANNOT PUSH to $BR. Install the Claude GitHub App on IVIR3zaM/Arboretum with write access, then say 'continue'." >&2
  exit 4
fi

python3 "$P/scripts/plan.py" reap --root "$P" >/dev/null
python3 "$P/scripts/plan.py" status --root "$P"
