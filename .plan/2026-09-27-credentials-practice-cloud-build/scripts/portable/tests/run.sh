#!/usr/bin/env bash
# portable/tests/run.sh — proves the cloud kit under .claude/ and $P/START-PROMPT.md never names a
# home-dir path, and that every .claude/... or $P/... (or .plan/...) path those files point at
# actually exists on this branch. Run with a fresh, empty HOME so a real ~/.claude on this machine
# can't mask a miss. Scoped to this node's own Write paths (.claude/agents, .claude/skills, and
# START-PROMPT.md) rather than every file loose under .claude/ — a dev machine's own local Claude
# Code session state (e.g. .claude/settings.local.json, .claude/worktrees/) lives directly under
# .claude/, outside agents/ and skills/, and is not part of the cloud kit this node ships.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
P=.plan/2026-09-27-credentials-practice-cloud-build

fail() { echo "portable test FAIL: $1" >&2; exit 1; }

kit_files() {
  find .claude/agents .claude/skills -type f 2>/dev/null
  if [ -f "$P/START-PROMPT.md" ]; then echo "$P/START-PROMPT.md"; fi
  true
}

mapfile -t FILES < <(kit_files)
[ "${#FILES[@]}" -gt 0 ] || fail "no kit files found under .claude or $P/START-PROMPT.md"

# (1) No home-dir reference anywhere in the copied kit or the start prompt (the C8 grep, plus $HOME/.claude).
if grep -n '~/\.claude\|/Users/' "${FILES[@]}" 2>/dev/null; then
  fail "home-dir reference (~/.claude or /Users/) found above"
fi
if grep -n '\$HOME/\.claude' "${FILES[@]}" 2>/dev/null; then
  fail "home-dir reference (\$HOME/.claude) found above"
fi

# (2) Every path named in START-PROMPT.md's fenced block, or in any file under .claude/, must exist.
collect_paths() {
  { grep -ohE '\.claude/[A-Za-z0-9_./<>-]+|\.plan/[A-Za-z0-9_./<>-]+' "$@" 2>/dev/null \
    | sed -E 's/[.,;:)]+$//'; } || true
}

paths_file=$(mktemp)
fence_file=$(mktemp)
trap 'rm -f "$paths_file" "$fence_file"' EXIT

# from the (single) fenced block in START-PROMPT.md
awk '/^```/{c++; next} c==1' "$P/START-PROMPT.md" > "$fence_file"
collect_paths "$fence_file" > "$paths_file"

# from every kit file under .claude/
for f in "${FILES[@]}"; do
  case "$f" in
    .claude/*) collect_paths "$f" >> "$paths_file" ;;
  esac
done

count=0
while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in
    *'<role>'*)
      for r in executor verifier planner; do
        expanded=${p//<role>/$r}
        count=$((count + 1))
        [ -e "$expanded" ] || fail "missing path: $expanded"
      done
      continue
      ;;
    *'<'*'>'*)
      continue
      ;;
  esac
  count=$((count + 1))
  [ -e "$p" ] || fail "missing path: $p"
done < <(sort -u "$paths_file")

[ "$count" -gt 0 ] || fail "no paths checked"
echo "portable test: checked $count path(s), all present"
