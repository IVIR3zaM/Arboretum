#!/usr/bin/env bash
# cold-run.sh — the service tree an assistant under test works in, kept OUTSIDE the repository.
#
#   cold-run.sh <node-id> stage1   # stripped practice with TICKET-1.md only -> $COLD_DIR, fresh git history
#   cold-run.sh <node-id> save1    # diff + commits + tree tarball of the ticket-1 result -> logs (durable)
#   cold-run.sh <node-id> stage2   # add TICKET-2.md to the ticket-1 result (restores it from logs if the VM changed)
#   cold-run.sh <node-id> save2    # same as save1, for ticket 2
#   cold-run.sh <node-id> grade    # graded copy with _solutions/ -> logs/<id>/grade.txt (verdict is data, exit 0)
#
# Stage and save steps run with the repo PRESENT. Seal (cold-seal.sh) only between stageN and saveN.
# FEATURE-REQUEST.md is never staged here: a bug ticket and the feature request are never delivered together.
set -euo pipefail

ID=${1:?node id}; STEP=${2:?step}
REPO=$(git rev-parse --show-toplevel)
PR=$REPO/practices/credentials
P=$PR/_solutions/.plan
LOG=$P/logs/$ID
if [ -z "${COLD_DIR:-}" ]; then
  if mkdir -p /srv 2>/dev/null && [ -w /srv ]; then COLD_DIR=/srv/service; else COLD_DIR=/var/tmp/service; fi
fi
mkdir -p "$LOG"
echo "$COLD_DIR" > "$LOG/cold-dir.txt"

refuse_leaks() {
  for f in _solutions README.md practice.json FEATURE-REQUEST.md DESIGN.md; do
    if [ -e "$COLD_DIR/$f" ]; then echo "cold-run: refusing, $f present in $COLD_DIR" >&2; exit 3; fi
  done
}

save() {
  n=$1
  git -C "$COLD_DIR" add -A -N .
  git -C "$COLD_DIR" diff "$(cat "$LOG/import.sha")" > "$LOG/ticket$n.diff" || true
  git -C "$COLD_DIR" log --format='%h %an %s%n%b' > "$LOG/ticket$n-commits.txt"
  tar -czf "$LOG/ticket$n-tree.tgz" -C "$(dirname "$COLD_DIR")" \
    --exclude=target --exclude=.dart_tool --exclude=build "$(basename "$COLD_DIR")"
  echo "cold-run: saved ticket$n result for $ID"
}

case "$STEP" in
  stage1)
    rm -rf "$COLD_DIR"
    bash "$P/checks/strip-clone.sh" "$PR" "$COLD_DIR" --stage TICKET-1.md
    [ ! -e "$COLD_DIR/TICKET-2.md" ] || { echo "cold-run: TICKET-2.md must not be present at stage1" >&2; exit 3; }
    refuse_leaks
    git -C "$COLD_DIR" init -q -b main
    git -C "$COLD_DIR" add -A
    git -C "$COLD_DIR" -c user.name="Credentials Team" -c user.email="team@issuer.invalid" commit -q -m "Import service repository"
    git -C "$COLD_DIR" rev-parse HEAD > "$LOG/import.sha"
    echo "cold-run: ticket1 staged at $COLD_DIR"
    ;;
  save1) save 1 ;;
  stage2)
    if [ ! -d "$COLD_DIR/.git" ]; then
      rm -rf "$COLD_DIR"; mkdir -p "$(dirname "$COLD_DIR")"
      tar -xzf "$LOG/ticket1-tree.tgz" -C "$(dirname "$COLD_DIR")"
    fi
    cp "$PR/TICKET-2.md" "$COLD_DIR/TICKET-2.md"
    refuse_leaks
    echo "cold-run: ticket2 staged at $COLD_DIR"
    ;;
  save2) save 2 ;;
  grade)
    G=$REPO/.sessions/build-credentials/$ID/graded
    rm -rf "$G"; mkdir -p "$(dirname "$G")"
    cp -R "$COLD_DIR" "$G"; rm -rf "$G/.git"
    cp -R "$PR/_solutions" "$G/_solutions"
    set +e
    (cd "$G" && bash _solutions/grade.sh) > "$LOG/grade.txt" 2>&1
    echo "exit=$?" >> "$LOG/grade.txt"
    set -e
    tail -8 "$LOG/grade.txt"
    ;;
  *) echo "cold-run: unknown step $STEP" >&2; exit 2 ;;
esac
