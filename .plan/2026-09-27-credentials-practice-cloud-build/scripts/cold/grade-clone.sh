#!/usr/bin/env bash
# grade-clone.sh <clone> <outdir> [practice-id] — grade a cold run's clone with the practice's
# declared grade command (practice.json -> commands.grade, AGENTS.md rule 7; `bash _solutions/grade.sh`
# while the practice has no practice.json, harness/DESIGN.md). It grades a throwaway copy of the clone
# plus the practice's _solutions/ — never the clone the agent used, never the practice itself.
# Writes <outdir>/grade.txt: the command, the raw output (stdout+stderr) and the exit code.
# practice-id defaults to credentials. Exits with the grade command's exit code.
set -euo pipefail

usage() { echo "usage: grade-clone.sh <clone> <outdir> [practice-id]" >&2; exit 2; }
[ $# -eq 2 ] || [ $# -eq 3 ] || usage
CLONE=$(realpath -e -- "$1") || usage
OUT=$(realpath -m -- "$2")
ID=${3:-credentials}

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
SRC="$ROOT/practices/$ID"
[ -d "$SRC/_solutions" ] || { echo "grade-clone: missing ${SRC#"$ROOT"/}/_solutions" >&2; exit 3; }

if [ -f "$SRC/practice.json" ]; then
  CMD=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commands"]["grade"])' "$SRC/practice.json")
  FROM="practice.json -> commands.grade"
else
  CMD="bash _solutions/grade.sh"
  FROM="fallback (no practice.json)"
fi
[ -n "$CMD" ] || { echo "grade-clone: empty grade command in ${SRC#"$ROOT"/}/practice.json" >&2; exit 3; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/cold-grade.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
cp -R "$CLONE/." "$WORK/"
rm -rf "$WORK/_solutions"
cp -R "$SRC/_solutions" "$WORK/_solutions"

mkdir -p "$OUT"
set +e
RAW=$(cd "$WORK" && bash -c "$CMD" 2>&1)
RC=$?
set -e

{
  echo "practice: $ID"
  echo "clone: $CLONE"
  echo "command: $CMD   ($FROM)"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "----- output -----"
  printf '%s\n' "$RAW"
  echo "----- end -----"
  echo "exit: $RC"
} > "$OUT/grade.txt"

echo "grade-clone: $ID exit $RC -> $OUT/grade.txt"
exit "$RC"
