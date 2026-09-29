#!/usr/bin/env bash
# examiner-run.sh — the N17 examiner: a separate cold `claude -p --model opus` process, fresh session,
# in its own directory outside the repo (/tmp/cold-N17-examiner3), never the process that ran the
# learner's prompts. Its inputs: golden/ (the session's golden context: _solutions/ + practice.json +
# context/cedar goals, best-practices, failure-modes), the ordered transcript, the per-turn logs, the
# final diff, the outcome checker's baseline/final captures, and harness/DESIGN.md. Runs the kit's
# cold-run.sh with examiner/prompt.txt, audits it with the kit's audit.py, and copies the result to
# examiner/ (transcript.jsonl, meta.env, audit.txt, feedback.md) and the session dir (feedback.md).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
KIT="$ROOT/.plan/2026-09-27-credentials-practice-cloud-build/scripts/cold"
SESSION="$ROOT/.sessions/20260929T094910Z-credentials-train"
T="$HERE/train"
E=/tmp/cold-N17-examiner3
[ ! -e "$E" ] || { echo "examiner-run: $E exists" >&2; exit 3; }
mkdir -p "$E/turns" "$E/outcome"
cp -R "$SESSION/golden" "$E/golden"
rm -rf "$E/golden/grader/target"
cp "$T/transcript.md" "$E/transcript.md"
for d in "$T"/turn-[0-9][0-9]; do cp "$d/transcript.jsonl" "$E/turns/$(basename "$d").jsonl"; done
cp "$T/session/diff.patch" "$E/diff.patch"
cp -R "$T/checkpoints/00-baseline" "$T/checkpoints/99-final" "$E/outcome/"
cp "$ROOT/harness/DESIGN.md" "$E/harness-DESIGN.md"
git -C "$E" init -q
git -C "$E" add -A
git -C "$E" -c user.name=arboretum-harness -c user.email=harness@arboretum.invalid -c commit.gpgsign=false commit -q -m "examiner inputs"
OUT="$HERE/examiner"
bash "$KIT/cold-run.sh" "$E" "$OUT/prompt.txt" "$OUT/run" || true
cp "$OUT/run/transcript.jsonl" "$OUT/transcript.jsonl"
cp "$OUT/run/meta.env" "$OUT/meta.env"
python3 "$KIT/audit.py" "$OUT/transcript.jsonl" "$E" > "$OUT/audit.txt" 2>&1 || true
cp "$E/feedback.md" "$OUT/feedback.md"
cp "$E/feedback.md" "$SESSION/feedback.md"
cp "$T/transcript.md" "$SESSION/transcript.md"
echo "examiner-run: $(head -1 "$OUT/audit.txt"); feedback $(wc -l < "$OUT/feedback.md") lines"
