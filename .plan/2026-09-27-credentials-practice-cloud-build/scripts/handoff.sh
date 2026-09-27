#!/usr/bin/env bash
# handoff.sh (local) — the human runs this on the Mac when the local run reaches node N03. It
# refuses unless the tree is clean and on credentials-cloud-build, pushes, then prints the fenced
# prompt from START-PROMPT.md — the only thing the human pastes into a cloud session.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
P=.plan/2026-09-27-credentials-practice-cloud-build

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "credentials-cloud-build" ]; then
  echo "handoff: refusing — on branch '$branch', expected credentials-cloud-build" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "handoff: refusing — working tree is not clean" >&2
  git status --short >&2
  exit 1
fi

git push origin credentials-cloud-build

echo "handoff: pushed credentials-cloud-build. Paste the block below into a Claude Code cloud session:"
echo
sed -n '/^```/,/^```/p' "$P/START-PROMPT.md"
