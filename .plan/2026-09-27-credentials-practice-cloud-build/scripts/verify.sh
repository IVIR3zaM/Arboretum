#!/usr/bin/env bash
# verify.sh — this plan's verify command. Exits 0 for the whole plan at every stage: a stack whose
# package dir doesn't exist yet is skipped, not failed. If a package dir exists but its toolchain
# is missing, that is a real failure naming bootstrap.sh, not a skip.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
P=.plan/2026-09-27-credentials-practice-cloud-build
PRACTICE=practices/credentials
# the toolchains bootstrap.sh installs, on PATH for this non-interactive shell too
# shellcheck source=toolpath.sh
. "$P/scripts/toolpath.sh"

status=0
err() { echo "verify FAIL: $1" >&2; status=1; }

# (1) Leak guard: practices/credentials/ minus _solutions/, README.md, practice.json, DESIGN.md
# has no grade.sh and no file mentioning _solutions, grade.sh, grader or .plan. TICKET*.md and
# FEATURE-REQUEST.md contain no warning marker. Scans only git-shippable files (tracked, plus
# untracked-not-ignored): gitignored build output (target/, build/, .dart_tool/) never reaches a
# clone or a commit, and Flutter/Cargo caches embed absolute repo paths that would trip the guard.
# The same loop also runs a taxonomy scan over the same file set: a Context id (FM-NN/BP-NN,
# case-sensitive), an exercise-taxonomy word (failure mode(s), best practice(s), arboretum,
# kata(s), learner(s), examiner(s), calibration, trap/traps/trapped, planted, golden —
# case-insensitive), or a Context tree name (read from the dirs under context/, case-insensitive)
# followed by "practice", "context", "tier" or "@". Each hit names the file, the line and the
# matched term — nothing the clone ships may cite the exercise that grades it.
check_leak_guard() {
  [ -d "$PRACTICE" ] || return 0
  local trees id_re='\b(FM|BP)-[0-9]+\b'
  local word_re='\b(failure mode(s)?|best practice(s)?|arboretum|kata(s)?|learner(s)?|examiner(s)?|calibration|trap(s|ped)?|planted|golden)\b'
  trees=$(find context -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | paste -sd '|' -)
  local tree_re=""
  [ -n "$trees" ] && tree_re="\b($trees)\b[[:space:]-]*\b(practice|context|tier)\b|\b($trees)@"
  local f rel base ln m
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue   # tracked but deleted in the worktree
    rel=${f#"$PRACTICE"/}
    case "$rel" in
      _solutions/*|README.md|practice.json|DESIGN.md) continue ;;
    esac
    base=$(basename "$f")
    if [ "$base" = "grade.sh" ]; then
      err "leak guard: $f — a grade.sh lives outside _solutions/"
    fi
    if grep -lE '_solutions|grade\.sh|grader|\.plan' -- "$f" >/dev/null 2>&1; then
      err "leak guard: $f — mentions _solutions, grade.sh, grader or .plan"
    fi
    while IFS=: read -r ln m; do
      [ -n "$ln" ] || continue
      err "leak guard: $f:$ln — matches Context id \"$m\""
    done < <(grep -noE "$id_re" -- "$f" 2>/dev/null)
    while IFS=: read -r ln m; do
      [ -n "$ln" ] || continue
      err "leak guard: $f:$ln — matches exercise-taxonomy term \"$m\""
    done < <(grep -noiE "$word_re" -- "$f" 2>/dev/null)
    if [ -n "$tree_re" ]; then
      while IFS=: read -r ln m; do
        [ -n "$ln" ] || continue
        err "leak guard: $f:$ln — matches Context tree label \"$m\""
      done < <(grep -noiE "$tree_re" -- "$f" 2>/dev/null)
    fi
  done < <(git ls-files -z --cached --others --exclude-standard -- "$PRACTICE")

  while IFS= read -r f; do
    grep -q '⚠️' -- "$f" 2>/dev/null && err "leak guard: $f — contains a ⚠️ warning marker"
  done < <(find "$PRACTICE" -maxdepth 1 -type f \( -name 'TICKET*.md' -o -name 'FEATURE-REQUEST.md' \))
}

# (2) backend Rust suite, offline.
check_backend() {
  local dir="$PRACTICE/backend"
  [ -f "$dir/Cargo.toml" ] || return 0
  if ! command -v cargo >/dev/null 2>&1; then
    err "$dir/Cargo.toml exists but cargo is missing — run bootstrap.sh"
    return
  fi
  if ! (cd "$dir" && cargo test --offline --locked) ; then
    err "$dir: cargo test --offline --locked failed"
  fi
}

# (3) app Flutter suite, no pub fetch.
check_app() {
  local dir="$PRACTICE/app"
  [ -f "$dir/pubspec.yaml" ] || return 0
  if ! command -v flutter >/dev/null 2>&1; then
    err "$dir/pubspec.yaml exists but flutter is missing — run bootstrap.sh"
    return
  fi
  if ! (cd "$dir" && flutter test --no-pub) ; then
    err "$dir: flutter test --no-pub failed"
  fi
}

# (4) practice.json shape.
check_practice_json() {
  local f="$PRACTICE/practice.json"
  [ -f "$f" ] || return 0
  local tmpl="context/cedar/templates/practice.template.json"
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
    err "$f: not valid JSON"
    return
  fi
  local missing
  missing=$(python3 - "$f" "$tmpl" <<'PY'
import json, sys
practice = json.load(open(sys.argv[1]))
template = json.load(open(sys.argv[2]))
missing = [k for k in template.keys() if k not in practice]
print("\n".join(missing))
PY
)
  if [ -n "$missing" ]; then
    err "$f: missing top-level key(s): $(echo "$missing" | tr '\n' ' ')"
  fi
  local cv
  cv=$(python3 -c "import json; print(json.load(open('$f')).get('contextVersion',''))")
  if [ "$cv" != "cedar@1.2.0" ]; then
    err "$f: contextVersion is '$cv', expected cedar@1.2.0"
  fi
  local fm_ids fm_file="context/cedar/failure-modes.md"
  fm_ids=$(python3 -c "import json; print(' '.join(json.load(open('$f')).get('trainingPoints',{}).get('failureModes',[])))")
  local id
  for id in $fm_ids; do
    if ! grep -qE "^#+.*\b$id\b" -- "$fm_file" 2>/dev/null; then
      err "$f: failureModes id $id has no heading in $fm_file"
    fi
  done
}

# (5) grade scripts parse.
check_grade_scripts() {
  local f
  [ -f "$PRACTICE/_solutions/grade.sh" ] && { bash -n "$PRACTICE/_solutions/grade.sh" || err "$PRACTICE/_solutions/grade.sh: bash -n failed"; }
  if [ -d "$PRACTICE/_solutions/grade.d" ]; then
    for f in "$PRACTICE"/_solutions/grade.d/*.sh; do
      [ -e "$f" ] || continue
      bash -n "$f" || err "$f: bash -n failed"
    done
  fi
}

# (6) run every scripts/*/tests/run.sh.
check_script_tests() {
  local f
  for f in "$P"/scripts/*/tests/run.sh; do
    [ -e "$f" ] || continue
    if ! bash "$f"; then
      err "$f: failed"
    fi
  done
}

check_leak_guard
check_backend
check_app
check_practice_json
check_grade_scripts
check_script_tests

exit "$status"
