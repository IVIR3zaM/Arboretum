#!/usr/bin/env bash
# snapshot.sh save|restore <NN> — the pre-turn snapshot behind a void-attempt rollback (N17).
#   save <NN>     before turn NN: tar the train clone (build output left out: target/, build/,
#                 .dart_tool/ are rebuilt from source) and copy train/session/ to /tmp/cold-N17-snap3/turn-NN/
#   restore <NN>  roll the clone and train/session/ back to that snapshot (only after the jail audit
#                 has voided turn NN's attempt and the attempt has been kept as train/turn-NN-void-K/)
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: snapshot.sh save|restore <NN>" >&2; exit 2; }
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLONE=/tmp/cold-N17-train3
S="$HERE/train/session"
SNAP=/tmp/cold-N17-snap3/turn-$2
EXCL=(--exclude=./backend/target --exclude=./app/build --exclude=./app/.dart_tool --exclude='./.git/cc-tmp/*/target')
case "$1" in
  save)
    rm -rf "$SNAP"; mkdir -p "$SNAP"
    tar -C "$CLONE" "${EXCL[@]}" -cf "$SNAP/clone.tar" .
    if [ -d "$S" ]; then cp -R "$S" "$SNAP/session"; fi
    echo "snapshot: saved turn $2 -> $SNAP"
    ;;
  restore)
    [ -f "$SNAP/clone.tar" ] || { echo "snapshot: no snapshot for turn $2" >&2; exit 3; }
    find "$CLONE" -mindepth 1 -maxdepth 1 ! -name backend ! -name app -exec rm -rf {} +
    for pkg in backend app; do
      [ -d "$CLONE/$pkg" ] || continue
      find "$CLONE/$pkg" -mindepth 1 -maxdepth 1 ! -name target ! -name build ! -name .dart_tool -exec rm -rf {} +
    done
    tar -C "$CLONE" -xf "$SNAP/clone.tar"
    rm -rf "$S"
    if [ -d "$SNAP/session" ]; then cp -R "$SNAP/session" "$S"; fi
    echo "snapshot: restored turn $2 from $SNAP"
    ;;
  *) echo "usage: snapshot.sh save|restore <NN>" >&2; exit 2 ;;
esac
