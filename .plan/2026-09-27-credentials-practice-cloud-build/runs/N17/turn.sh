#!/usr/bin/env bash
# turn.sh <NN> — one learner turn of the N17 train run.
# Runs train/prompts/turn-NN.txt through the kit's cold-run.sh in the train clone (turn 01 starts the
# session, later turns --resume it), then snapshots train/turn-NN/: the prompt, this turn's slice of
# the stream-json transcript, its meta.env block, the clone's diff vs. the baseline after the turn,
# and the kit's jail audit of this turn's slice (audit.txt, exit code appended).
set -uo pipefail
[ $# -eq 1 ] || { echo "usage: turn.sh <NN>" >&2; exit 2; }
NN=$1
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
KIT="$ROOT/.plan/2026-09-27-credentials-practice-cloud-build/scripts/cold"
CLONE=/tmp/cold-N17-train2
T="$HERE/train"
PROMPT="$T/prompts/turn-$NN.txt"
[ -f "$PROMPT" ] || { echo "turn.sh: missing $PROMPT" >&2; exit 2; }
S="$T/session"
mkdir -p "$S" "$T/turn-$NN"
BEFORE=$(wc -l < "$S/transcript.jsonl" 2>/dev/null || echo 0)
# Run condition added after turn 02's first attempt was voided by the audit (its test wrote scratch
# dirs through std::env::temp_dir() into /tmp, then it listed and removed them there): the process
# temp dir points inside the jail, next to the CLI's own scratchpad, outside diff.patch.
export TMPDIR="$CLONE/.git/cc-tmp"
mkdir -p "$TMPDIR"
if [ "$NN" = "01" ]; then
  bash "$KIT/cold-run.sh" "$CLONE" "$PROMPT" "$S"
else
  SID=$(grep -m1 '^SESSION_ID=' "$S/meta.env" | cut -d= -f2)
  bash "$KIT/cold-run.sh" "$CLONE" "$PROMPT" "$S" --resume "$SID"
fi
RC=$?
D="$T/turn-$NN"
cp "$PROMPT" "$D/prompt.txt"
tail -n +"$((BEFORE + 1))" "$S/transcript.jsonl" > "$D/transcript.jsonl"
awk -v t="# turn $((10#$NN))" '$0==t{p=1} p&&/^# turn /&&$0!=t{p=0} p' "$S/meta.env" > "$D/meta.env"
cp "$S/diff.patch" "$D/diff.patch"
python3 "$KIT/audit.py" "$D/transcript.jsonl" "$CLONE" > "$D/audit.txt" 2>&1
echo "audit exit: $?" >> "$D/audit.txt"
echo "turn.sh: turn $NN exit $RC; $(head -1 "$D/audit.txt")"
exit "$RC"
