#!/usr/bin/env bash
# temp-collect.sh — fetch a control run's pushed result from the cold repo and (after ticket 2) grade it.
#
#   temp-collect.sh <node-id> ticket1     # saves the result tree for temp-stage.sh <id> ticket2
#   temp-collect.sh <node-id> ticket2     # saves the result, adds _solutions/, runs grade.sh
#
# Exit 5 = no claude/* branch pushed yet (the run hasn't finished or didn't push; try again later).
# The grade's own exit code is saved to logs, and this script exits 0 once the grade has run, whatever
# the verdict. The verdict is data for the adversary handoff, not a script failure.
set -euo pipefail

ID=${1:?node id}; STAGE=${2:?ticket1|ticket2}
TEMP_REMOTE=${TEMP_REMOTE:-https://github.com/IVIR3zaM/ClaudeTemp.git}
PR=practices/credentials
P=$PR/_solutions/.plan
LOG=$P/logs/$ID
S=.sessions/build-credentials/$ID
mkdir -p "$LOG" "$S"

branches=$(git ls-remote --heads "$TEMP_REMOTE" 'claude/*' | awk '{print $2}')
[ -n "$branches" ] || { echo "temp-collect: no claude/* branch yet on ClaudeTemp" >&2; exit 5; }

G=$S/fetch-$STAGE
rm -rf "$G" && git init -q "$G"
for b in $branches; do git -C "$G" fetch -q "$TEMP_REMOTE" "$b:$b"; done
latest=$(git -C "$G" for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads | head -1)
git -C "$G" fetch -q "$TEMP_REMOTE" main:staged
{ echo "branch: $latest"; echo "sha: $(git -C "$G" rev-parse "$latest")"; echo "all: $branches"; } > "$LOG/result-$STAGE.txt"
git -C "$G" log --format='%h %s%n%b' "staged..$latest" > "$LOG/commits-$STAGE.txt"
git -C "$G" diff "staged" "$latest" > "$LOG/$STAGE.diff"

R=$S/result-$STAGE
rm -rf "$R" && mkdir -p "$R"
git -C "$G" archive "$latest" | tar -x -C "$R"

if [ "$STAGE" = "ticket2" ]; then
  GR=$S/graded
  rm -rf "$GR" && cp -R "$R" "$GR"
  cp -R "$PR/_solutions" "$GR/_solutions"
  set +e
  (cd "$GR" && bash _solutions/grade.sh) > "$LOG/grade.txt" 2>&1
  echo "exit=$?" >> "$LOG/grade.txt"
  set -e
  tail -5 "$LOG/grade.txt"
fi
echo "temp-collect: $STAGE for $ID collected from $latest"
