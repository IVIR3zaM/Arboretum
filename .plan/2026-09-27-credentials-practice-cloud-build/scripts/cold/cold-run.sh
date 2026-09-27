#!/usr/bin/env bash
# cold-run.sh <clone> <prompt-file> <outdir> [--resume <session-id>]
#
# One headless turn of a cold agent (`claude -p --model opus`) in a harness-shaped clone made by
# mkclone.sh. The clone is the cwd; web tools are disallowed; no user/project/local settings, MCP
# servers, skills or Chrome are loaded; only the built-in coding tools are offered (subagents
# included) and they are pre-approved (acceptEdits + the same allow-list), so a headless turn can
# work without a prompter. The host session's own Claude env (session id, extra dirs + their
# CLAUDE.md, messaging socket, ...) is stripped so the child starts cold. The toolchains are put on
# PATH (../toolpath.sh), and the CLI's own files — its scratchpad (CLAUDE_CODE_TMPDIR) and its
# config dir with the session store and oversized-tool-output spills (CLAUDE_CONFIG_DIR) — live in
# <clone>/.git/cc-tmp and <clone>/.git/cc-config: inside the jail, out of diff.patch, kept across
# --resume turns. Nothing is copied from $HOME/.claude.
#
# Writes to <outdir>:
#   transcript.jsonl  stream-json, appended turn after turn
#   meta.env          one block per turn: date, model, CLI version, session id, prompt file,
#                     toolchain paths, the relocated CLI dirs
#   diff.patch        the clone's working tree (untracked files included) vs. the baseline commit
#   stderr.log        the CLI's stderr
# Multi-turn: pass --resume <session-id> (from meta.env) with the same <outdir>.
# Exit code: the CLI's. COLD_TIMEOUT (seconds, default 3600) caps a turn.
set -euo pipefail

usage() { echo "usage: cold-run.sh <clone> <prompt-file> <outdir> [--resume <session-id>]" >&2; exit 2; }
[ $# -eq 3 ] || [ $# -eq 5 ] || usage
CLONE=$(realpath -e -- "$1") || usage
PROMPT=$(realpath -e -- "$2") || usage
OUT=$(realpath -m -- "$3")
RESUME=
if [ $# -eq 5 ]; then
  [ "$4" = "--resume" ] && [ -n "$5" ] || usage
  RESUME=$5
fi

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../toolpath.sh
. "$HERE/../toolpath.sh"
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
ROOT_REAL=$(cd "$ROOT" && pwd -P)
case "$CLONE/" in
  "$ROOT_REAL"/*|"$ROOT"/*) echo "cold-run: refusing a clone inside the repo: $CLONE" >&2; exit 4 ;;
esac
[ -d "$CLONE/.git" ] || { echo "cold-run: $CLONE is not a mkclone.sh clone (no .git)" >&2; exit 4; }
BASELINE=$(git -C "$CLONE" rev-list --max-parents=0 HEAD | tail -1)
CC_TMP="$CLONE/.git/cc-tmp"
CC_CONFIG="$CLONE/.git/cc-config"
mkdir -p "$CC_TMP" "$CC_CONFIG"
FLUTTER=$(command -v flutter || true)
CARGO=$(command -v cargo || true)

mkdir -p "$OUT"
if [ -n "$RESUME" ]; then
  SID=$RESUME
  SESSION_FLAG=(--resume "$SID")
  TURN=$(( $(grep -c '^TURN=' "$OUT/meta.env" 2>/dev/null || echo 0) + 1 ))
else
  SID=$(python3 -c 'import uuid; print(uuid.uuid4())')
  SESSION_FLAG=(--session-id "$SID")
  TURN=1
  : > "$OUT/transcript.jsonl"
  : > "$OUT/meta.env"
fi

MODEL=opus
# the built-in coding tool set, subagents included; the host environment's extra tools (artifacts,
# notifications, file sending, cron, ...) are left out.
TOOLS="Bash,Read,Edit,Write,Glob,Grep,NotebookEdit,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop"
CLI_VERSION=$(claude --version 2>/dev/null | head -1)
STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# The host session's env would otherwise leak in: its session id, extra dirs and their CLAUDE.md,
# the messaging socket, debug/tee output and partial-message streaming.
HOST_ENV=(
  CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_CHILD_SESSION CLAUDE_PID
  CLAUDE_ADDITIONAL_DIRECTORIES CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD
  CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN CLAUDE_CODE_TEE_SDK_STDOUT
  CLAUDE_CODE_DEBUG CLAUDE_CODE_DIAGNOSTICS_FILE CLAUDE_CODE_INCLUDE_PARTIAL_MESSAGES
  CLAUDE_CODE_SYNC_SKILLS CLAUDE_CODE_SYNC_SESSION_REFS CLAUDE_CODE_BASE_REF
  DOCUMENTS_MCP_SCRATCH_ROOT OLDPWD
)
UNSET=()
for v in "${HOST_ENV[@]}"; do UNSET+=(-u "$v"); done

set +e
(
  cd "$CLONE"
  env "${UNSET[@]}" CLAUDE_CODE_TMPDIR="$CC_TMP" CLAUDE_CONFIG_DIR="$CC_CONFIG" timeout "${COLD_TIMEOUT:-3600}" claude -p \
    --model "$MODEL" \
    "${SESSION_FLAG[@]}" \
    --output-format stream-json --verbose \
    --setting-sources "" \
    --strict-mcp-config \
    --disable-slash-commands \
    --no-chrome \
    --permission-mode acceptEdits \
    --tools "$TOOLS" \
    --allowedTools "$TOOLS" \
    --disallowedTools "WebFetch WebSearch" \
    < "$PROMPT"
) >> "$OUT/transcript.jsonl" 2>> "$OUT/stderr.log"
RC=$?
set -e

RESOLVED=$(python3 - "$OUT/transcript.jsonl" <<'PY'
import json, sys
model = ""
for line in open(sys.argv[1], encoding="utf-8"):
    try:
        o = json.loads(line)
    except Exception:
        continue
    if o.get("type") == "system" and o.get("subtype") == "init" and o.get("model"):
        model = o["model"]
print(model)
PY
)

{
  echo "# turn $TURN"
  echo "TURN=$TURN"
  echo "DATE=$STARTED"
  echo "FINISHED=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "MODEL=$MODEL"
  echo "MODEL_RESOLVED=$RESOLVED"
  echo "CLI_VERSION='$CLI_VERSION'"
  echo "SESSION_ID=$SID"
  echo "PROMPT_FILE=$PROMPT"
  echo "CLONE=$CLONE"
  echo "BASELINE=$BASELINE"
  echo "FLUTTER=$FLUTTER"
  echo "CARGO=$CARGO"
  echo "CLAUDE_CODE_TMPDIR=$CC_TMP"
  echo "CLAUDE_CONFIG_DIR=$CC_CONFIG"
  echo "EXIT=$RC"
} >> "$OUT/meta.env"

# diff vs. the baseline, untracked files included, without touching the clone's own index
IDX=$(mktemp)
cp "$CLONE/.git/index" "$IDX" 2>/dev/null || true
GIT_INDEX_FILE=$IDX git -C "$CLONE" add -A
GIT_INDEX_FILE=$IDX git -C "$CLONE" diff --cached --binary "$BASELINE" > "$OUT/diff.patch"
rm -f "$IDX"

echo "cold-run: turn $TURN, session $SID, exit $RC, diff $(grep -c '^diff --git' "$OUT/diff.patch" || true) file(s) -> $OUT"
exit "$RC"
