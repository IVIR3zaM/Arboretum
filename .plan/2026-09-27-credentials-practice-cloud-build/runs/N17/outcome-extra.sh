#!/usr/bin/env bash
# outcome-extra.sh <clone> <outdir> — the outcome checker's two examiner-only measurements on the final
# tree (rubric.md Axis A item 5 and row 5.2), taken on throwaway copies, never on the clone itself:
#   <outdir>/robustness.txt      _solutions/robustness-probes.sh from the root of a copy of the clone
#                                with _solutions/ dropped in, after practice.json -> commands.install
#   <outdir>/discrimination.txt  every test the run added, run one at a time (--exact) against the
#                                baseline commit's source and against the final source
set -uo pipefail
[ $# -eq 2 ] || { echo "usage: outcome-extra.sh <clone> <outdir>" >&2; exit 2; }
CLONE=$(realpath -e -- "$1") || exit 2
OUT=$(realpath -m -- "$2")
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
. "$ROOT/.plan/2026-09-27-credentials-practice-cloud-build/scripts/toolpath.sh"
PRACTICE="$ROOT/practices/credentials"
PJ="$PRACTICE/practice.json"
INSTALL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commands"]["install"])' "$PJ")
SCR=$(mktemp -d "${TMPDIR:-/tmp}/n17-extra.XXXXXX")
trap 'rm -rf "$SCR"' EXIT
mkdir -p "$OUT"
copy_final() {  # <dest>
  mkdir -p "$1"
  tar -C "$CLONE" --exclude=./.git --exclude=./backend/target --exclude=./app/build \
    --exclude=./app/.dart_tool -cf - . | tar -C "$1" -xf -
}
BASE=$(git -C "$CLONE" rev-list --max-parents=0 HEAD | tail -1)

# --- robustness report -------------------------------------------------------------------------
F="$SCR/final"; copy_final "$F"
cp -R "$PRACTICE/_solutions" "$F/_solutions"
export CARGO_TARGET_DIR="$SCR/target-final"
{
  echo "clone: $CLONE (throwaway copy + practices/credentials/_solutions)"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "install: $INSTALL"
  (cd "$F" && bash -c "$INSTALL") > "$SCR/install.log" 2>&1; echo "install exit: $?"
  echo "command: bash _solutions/robustness-probes.sh   (rubric.md Axis A item 5; non-blocking)"
  echo "----- output -----"
  (cd "$F" && PROBES_TARGET_DIR="$SCR/target-probes" bash _solutions/robustness-probes.sh 2>&1)
  echo "----- end -----"
  echo "exit: $?"
} > "$OUT/robustness.txt"
rm -rf "$SCR/target-probes"
echo "robustness: $(grep '^robustness' "$OUT/robustness.txt")"

# --- test discrimination -----------------------------------------------------------------------
# The trees: final = the clone's working tree; base = the baseline commit's source with the final
# tree's test files laid over it (the tests the run added or changed, nothing else).
B="$SCR/base"; mkdir -p "$B"
git -C "$CLONE" archive "$BASE" | tar -C "$B" -xf -
TESTFILES=$(cd "$CLONE" && { git diff --name-only "$BASE" -- backend/tests app/test; git ls-files --others --exclude-standard -- backend/tests app/test; } | sort -u)
for f in $TESTFILES; do mkdir -p "$B/$(dirname "$f")"; cp "$CLONE/$f" "$B/$f"; done
(cd "$B" && bash -c "$INSTALL") > "$SCR/install-base.log" 2>&1

new_rust_tests() {  # <file> : test fns the run added (whole file if untracked, + lines otherwise)
  local f=$1
  if git -C "$CLONE" cat-file -e "$BASE:$f" 2>/dev/null; then
    git -C "$CLONE" diff "$BASE" -- "$f" | grep -E '^\+\s*(async )?fn [a-z0-9_]+\(' | sed -E 's/.*fn ([a-z0-9_]+)\(.*/\1/'
  else
    awk '/#\[(tokio::)?test/{t=1; next} t && /fn [a-z0-9_]+\(/{match($0,/fn [a-z0-9_]+\(/); print substr($0,RSTART+3,RLENGTH-4); t=0}' "$CLONE/$f"
  fi
}
run_rust() {  # <tree> <target> <testbin> <name> -> ok | FAILED | no-build
  local out
  out=$(cd "$1/backend" && CARGO_TARGET_DIR="$2" cargo test --offline --locked --test "$3" -- --exact "$4" 2>&1)
  if grep -q "^test $4 \.\.\. ok" <<<"$out"; then echo ok
  elif grep -q "^test $4 \.\.\. FAILED" <<<"$out"; then echo FAILED
  elif grep -qE '^error(\[E[0-9]+\])?:' <<<"$out"; then echo no-build
  else echo "?"; fi
}
{
  echo "clone: $CLONE   baseline commit: $BASE"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "method: each test the run added, run alone (cargo test --offline --locked --test <file> -- --exact <name>)"
  echo "        against base (baseline source + the final test files) and final (the clone's tree)."
  echo "        no-build = the test file does not compile against that source (it names API the run added)."
  echo "        Flutter tests: the whole new test file per tree (flutter test --no-pub <file>), per-test lines."
  echo
  printf '%-10s %-8s %-8s %s\n' "file" "base" "final" "test"
  for f in $TESTFILES; do
    case "$f" in backend/tests/*.rs) ;; *) continue ;; esac
    bin=$(basename "$f" .rs)
    for t in $(new_rust_tests "$f"); do
      b=$(run_rust "$B" "$SCR/target-base" "$bin" "$t")
      n=$(run_rust "$F" "$SCR/target-final" "$bin" "$t")
      printf '%-10s %-8s %-8s %s\n' "$bin" "$b" "$n" "$t"
    done
  done
  for f in $TESTFILES; do
    case "$f" in app/test/*_test.dart) ;; *) continue ;; esac
    git -C "$CLONE" cat-file -e "$BASE:$f" 2>/dev/null && continue
    for tree in base final; do
      [ "$tree" = base ] && d=$B || d=$F
      echo
      echo "----- flutter test --no-pub $f   ($tree) -----"
      (cd "$d/app" && flutter test --no-pub --reporter expanded "${f#app/}" 2>&1) \
        | grep -E '^[0-9:]+ \+[0-9]+' | sed -E 's/^[0-9:]+ //' | tail -n 60
    done
  done
} > "$OUT/discrimination.txt" 2>&1
echo "discrimination: $(grep -c . "$OUT/discrimination.txt") lines -> $OUT/discrimination.txt"
