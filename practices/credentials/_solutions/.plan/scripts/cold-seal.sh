#!/usr/bin/env bash
# cold-seal.sh — run immediately before handing work to an assistant under test (control runs, the
# proof session's executor). It makes sure every commit is pushed, then EMPTIES this checkout, so the
# answer key, the plan, git history, and the learner briefing are not on disk for it to find.
#
# Restore afterwards, from the (now empty) repo directory:
#   git clone -q -b claude/credentials-build https://github.com/IVIR3zaM/Arboretum.git .
# Nothing is lost: everything in scope was pushed first, and the cold work lives outside the repo.
#
# Residual exposure, accepted and recorded in practice.json -> controlRun.method: the orchestrator's own
# session transcript under ~/.claude, and the public GitHub repo, which the cold assistant would have to
# go looking for by name. Nothing in the service tree names either.
set -euo pipefail

REPO=$(git rev-parse --show-toplevel)
cd "$REPO"
BR=claude/credentials-build
[ "$(git rev-parse --abbrev-ref HEAD)" = "$BR" ] || { echo "cold-seal: not on $BR" >&2; exit 2; }

bash practices/credentials/_solutions/.plan/scripts/sync.sh checkpoint
git fetch -q origin "$BR"
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BR")" ]; then
  echo "cold-seal: local HEAD is not on origin; refusing to empty the checkout" >&2
  exit 3
fi

find "$REPO" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
echo "cold-seal: sealed. Restore with: cd $REPO && git clone -q -b $BR https://github.com/IVIR3zaM/Arboretum.git ."
