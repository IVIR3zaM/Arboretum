#!/usr/bin/env bash
# sync.sh — run one plan.py state transition and make it durable on GitHub.
#
#   bash practices/credentials/_solutions/.plan/scripts/sync.sh <plan.py subcommand and args>
#   e.g. sync.sh claim 130 --agent runner --lease-min 180
#        sync.sh complete 130 --status awaiting_verification --summary "..." --artifacts "..."
#        sync.sh approve 015 --by reza
#        sync.sh checkpoint            # commit + push work in progress, no state change
#
# Every call: pull the build branch, apply the transition, write the heartbeat, commit everything
# in the build's scope (state, handoffs, logs, and any work files), and push. A cloud VM can be
# reclaimed at any moment (rate limit, idle expiry), so nothing counts until this script returns 0.
set -euo pipefail

REPO=$(git rev-parse --show-toplevel)
cd "$REPO"
P=practices/credentials/_solutions/.plan
BRANCH=${PLAN_BRANCH:-claude/credentials-build}
SCOPE=(practices/credentials harness/DESIGN.md AGENTS.md)

cur=$(git rev-parse --abbrev-ref HEAD)
if [ "$cur" != "$BRANCH" ]; then
  echo "sync.sh: on '$cur', expected '$BRANCH' (git fetch origin && git checkout $BRANCH)" >&2
  exit 2
fi

[ $# -ge 1 ] || { echo "usage: sync.sh <plan.py args> | checkpoint" >&2; exit 2; }

# Commit local work first, so the rebase can't clobber it.
git add -A -- "${SCOPE[@]}"
git commit -q -m "credentials build: wip before $1" || true
git pull -q --rebase origin "$BRANCH" || {
  echo "sync.sh: rebase conflict (probably state.json edited in two places). Resolve by hand, never with --theirs on state.json." >&2
  exit 3
}

if [ "$1" != "checkpoint" ]; then
  python3 "$P/scripts/plan.py" --root "$P" "$@"
fi

printf '{"runner": "%s", "at": "%s", "last": "%s"}\n' \
  "${RUNNER_ID:-$(hostname)}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" > "$P/RUNNER.json"

git add -A -- "${SCOPE[@]}"
git commit -q -m "credentials build: $*" || true

for attempt in 1 2 3 4 5; do
  if git push -q origin "$BRANCH"; then
    exit 0
  fi
  sleep $((attempt * 3))
  git pull -q --rebase origin "$BRANCH" || { echo "sync.sh: rebase conflict on retry $attempt" >&2; exit 3; }
done
echo "sync.sh: push failed 5 times; state is committed locally but NOT durable" >&2
exit 4
