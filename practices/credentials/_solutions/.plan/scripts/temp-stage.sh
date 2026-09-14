#!/usr/bin/env bash
# temp-stage.sh — put exactly one learner work item into the cold repo (IVIR3zaM/ClaudeTemp) for a
# control run, with no history and no other branches, so the assistant can see nothing else.
#
#   temp-stage.sh <node-id> ticket1                 # stripped practice + TICKET-1.md only
#   temp-stage.sh <node-id> ticket2                 # the ticket-1 result tree + TICKET-2.md
#
# Never stages FEATURE-REQUEST.md (control runs never carry the feature; a bug ticket and the
# feature request are never delivered together). Runs from the Arboretum repo root.
set -euo pipefail

ID=${1:?node id}; STAGE=${2:?ticket1|ticket2}
TEMP_REMOTE=${TEMP_REMOTE:-https://github.com/IVIR3zaM/ClaudeTemp.git}
PR=practices/credentials
P=$PR/_solutions/.plan
W=.sessions/build-credentials/$ID/temp-$STAGE
LOG=$P/logs/$ID
mkdir -p "$LOG"
rm -rf "$W" && mkdir -p "$W"

case "$STAGE" in
  ticket1)
    bash "$P/checks/strip-clone.sh" "$PR" "$W/tree" --stage TICKET-1.md
    ;;
  ticket2)
    RESULT=.sessions/build-credentials/$ID/result-ticket1
    [ -d "$RESULT" ] || { echo "temp-stage: run temp-collect.sh $ID ticket1 first" >&2; exit 2; }
    cp -R "$RESULT" "$W/tree"
    rm -rf "$W/tree/.git"
    cp "$PR/TICKET-2.md" "$W/tree/TICKET-2.md"
    ;;
  *) echo "temp-stage: stage must be ticket1 or ticket2" >&2; exit 2 ;;
esac

# Guards: nothing from the answer key or the learner briefing, and never the feature request.
for forbidden in _solutions README.md practice.json FEATURE-REQUEST.md DESIGN.md; do
  if [ -e "$W/tree/$forbidden" ]; then echo "temp-stage: refusing, $forbidden present" >&2; exit 3; fi
done

cd "$W/tree"
git init -q -b main
git add -A
git -c user.name="${TEMP_AUTHOR_NAME:-Credentials Team}" -c user.email="${TEMP_AUTHOR_EMAIL:-team@issuer.invalid}" \
  commit -q -m "Import service repository"
git push -q --force "$TEMP_REMOTE" main
for ref in $(git ls-remote --heads "$TEMP_REMOTE" | awk '{print $2}' | grep -v '^refs/heads/main$' || true); do
  git push -q "$TEMP_REMOTE" --delete "${ref#refs/heads/}"
done
cd - >/dev/null

git ls-remote "$TEMP_REMOTE" refs/heads/main | awk '{print $1}' > "$LOG/staged-$STAGE.sha"
echo "temp-stage: $STAGE for $ID staged at $(cat "$LOG/staged-$STAGE.sha")"
