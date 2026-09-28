#!/usr/bin/env bash
# checkpoint.sh <clone> <outdir> — the outcome checker's between-rounds measurement (N17).
# Copies the clone to a throwaway dir (never touching the clone the assistant works in), runs the
# practice's declared commands.install then commands.test there (read from practice.json, AGENTS.md
# rule 7), writes <outdir>/unit.txt, then grades that same prepared copy with the kit's
# grade-clone.sh (commands.grade against a copy with _solutions/ dropped in) -> <outdir>/grade.txt.
set -uo pipefail
[ $# -eq 2 ] || { echo "usage: checkpoint.sh <clone> <outdir>" >&2; exit 2; }
CLONE=$(realpath -e -- "$1") || exit 2
OUT=$(realpath -m -- "$2")
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
KIT="$ROOT/.plan/2026-09-27-credentials-practice-cloud-build/scripts"
. "$KIT/toolpath.sh"
PJ="$ROOT/practices/credentials/practice.json"
cmd() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commands"][sys.argv[2]])' "$PJ" "$1"; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/cold-N17-check.XXXXXX")
trap 'rm -rf "$WORK" "$WORK.target"' EXIT
# build output stays behind (gitignored, never part of the diff): the disk is tight, and the copy is
# rebuilt from source by commands.install / commands.test anyway.
tar -C "$CLONE" --exclude=./.git/cc-tmp --exclude=./.git/cc-config --exclude=./backend/target \
  --exclude=./app/build --exclude=./app/.dart_tool -cf - . | tar -C "$WORK" -xf -
export CARGO_TARGET_DIR="$WORK.target"   # the unit run's build dir, outside the copy grade-clone.sh takes
mkdir -p "$OUT"
INSTALL=$(cmd install); TEST=$(cmd test)
{
  echo "clone: $CLONE (throwaway copy)"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "install: $INSTALL   (practice.json -> commands.install)"
  echo "----- install output -----"
  (cd "$WORK" && bash -c "$INSTALL") 2>&1 | tail -n 5
  echo "install exit: ${PIPESTATUS[0]}"
  echo "test: $TEST   (practice.json -> commands.test)"
  echo "----- test output -----"
} > "$OUT/unit.txt"
(cd "$WORK" && bash -c "$TEST") >> "$OUT/unit.txt" 2>&1
RC=$?
{ echo "----- end -----"; echo "test exit: $RC"; } >> "$OUT/unit.txt"
echo "checkpoint: unit exit $RC -> $OUT/unit.txt"
rm -rf "$WORK.target"; unset CARGO_TARGET_DIR
bash "$KIT/cold/grade-clone.sh" "$WORK" "$OUT"
