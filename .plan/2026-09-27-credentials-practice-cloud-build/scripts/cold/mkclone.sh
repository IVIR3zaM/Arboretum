#!/usr/bin/env bash
# mkclone.sh <stage|practice:ID> <dest> — build a harness-shaped clone (AGENTS.md rules 1-4) OUTSIDE
# the repo, for a cold agent to work in.
#
#   practice:ID  practices/ID as the harness clones it at session start: the first work item only
#                (the first TICKET*.md; later tickets and FEATURE-REQUEST.md are held back).
#   t1           practices/credentials, planted tree, with TICKET-1.md.
#   t2           ... with _solutions/reference-fix/ticket-1.patch applied into the baseline,
#                with TICKET-1.md and TICKET-2.md.
#   feature      ... ticket-1.patch applied, with TICKET-1.md and FEATURE-REQUEST.md.
#   control      planted tree, with TICKET-1.md, TICKET-2.md and FEATURE-REQUEST.md.
#
# Every clone: _solutions/, README.md, practice.json and DESIGN.md stripped; only the files git
# would ship (tracked + untracked-not-ignored), so no build output with repo paths in it; reference/
# stays; then `git init` and one commit, "baseline (stripped clone)".
# Refuses a <dest> inside the repo or a non-empty <dest>. A stage whose inputs are missing exits 3
# and names each missing path.
set -euo pipefail

usage() { echo "usage: mkclone.sh <t1|t2|feature|control|practice:ID> <dest>" >&2; exit 2; }
[ $# -eq 2 ] || usage
STAGE=$1
DEST=$2

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)

case "$STAGE" in
  practice:?*) ID=${STAGE#practice:} ;;
  t1|t2|feature|control) ID=credentials ;;
  *) usage ;;
esac
SRC="$ROOT/practices/$ID"

# --- dest: absolute, outside the repo, empty or absent ---------------------------------------------
DEST=$(realpath -m -- "$DEST")
ROOT_REAL=$(cd "$ROOT" && pwd -P)
case "$DEST/" in
  "$ROOT_REAL"/*|"$ROOT"/*)
    echo "mkclone: refusing dest inside the repo: $DEST" >&2; exit 4 ;;
esac
if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  echo "mkclone: dest exists and is not empty: $DEST" >&2; exit 4
fi

# --- inputs per stage ------------------------------------------------------------------------------
PATCH="$SRC/_solutions/reference-fix/ticket-1.patch"
KEEP=()          # work items (top-level basenames) that stay in the clone
NEED=("$SRC")
case "$STAGE" in
  practice:*)
    first=$( { cd "$SRC" 2>/dev/null && ls TICKET*.md 2>/dev/null | sort | head -1; } || true)
    [ -n "$first" ] && KEEP=("$first") || NEED+=("$SRC/TICKET*.md")
    ;;
  t1)      KEEP=(TICKET-1.md) ;;
  t2)      KEEP=(TICKET-1.md TICKET-2.md); NEED+=("$PATCH") ;;
  feature) KEEP=(TICKET-1.md FEATURE-REQUEST.md); NEED+=("$PATCH") ;;
  control) KEEP=(TICKET-1.md TICKET-2.md FEATURE-REQUEST.md) ;;
esac
for k in "${KEEP[@]}"; do NEED+=("$SRC/$k"); done

missing=0
for n in "${NEED[@]}"; do
  if [ ! -e "$n" ]; then
    echo "mkclone: stage $STAGE: missing ${n#"$ROOT"/}" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 3

# --- copy the service repo -------------------------------------------------------------------------
mkdir -p "$DEST"
(
  cd "$SRC"
  git ls-files -z --cached --others --exclude-standard -- . \
    | while IFS= read -r -d '' f; do [ -e "$f" ] && printf '%s\0' "$f"; done \
    | tar --null -T - -cf - \
    | tar -xf - -C "$DEST"
)

# --- strip the exercise material, then the work items not in KEEP -------------------------------------
rm -rf "$DEST/_solutions" "$DEST/README.md" "$DEST/practice.json" "$DEST/DESIGN.md"
for item in "$DEST"/TICKET*.md "$DEST"/FEATURE-REQUEST.md; do
  [ -e "$item" ] || continue
  b=$(basename "$item")
  keep=0
  for k in "${KEEP[@]}"; do [ "$k" = "$b" ] && keep=1; done
  [ "$keep" -eq 1 ] || rm -f "$item"
done

# --- own git repo, baseline commit (with ticket-1.patch applied for t2/feature) -----------------
g() { git -C "$DEST" -c user.name=arboretum-harness -c user.email=harness@arboretum.invalid -c commit.gpgsign=false "$@"; }
g init -q
case "$STAGE" in
  t2|feature)
    g apply --whitespace=nowarn "$PATCH" || { echo "mkclone: ticket-1.patch does not apply" >&2; exit 5; }
    ;;
esac
g add -A
g commit -q -m "baseline (stripped clone)"

echo "mkclone: $STAGE -> $DEST ($(g rev-parse --short HEAD); work items: ${KEEP[*]:-none})"
