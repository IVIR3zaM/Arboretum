#!/usr/bin/env bash
# cold/tests/run.sh — self-test for audit.py. Feeds it synthetic stream-json transcripts against a
# throwaway clone dir: each violation kind (a file tool outside the clone, an outside path in Bash,
# a `cd ..` escape, a web tool) must exit 1 and name the violation; a clean transcript, including
# the things a real run does legitimately (relative `..` inside the clone, /dev/null redirects, route
# strings that look like paths, toolchain caches), must exit 0.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AUDIT="$HERE/../audit.py"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CLONE="$TMP/clone"
mkdir -p "$CLONE/src"
echo '{}' > "$CLONE/package.json"

failures=0
fail() { echo "cold test FAIL: $1" >&2; failures=$((failures + 1)); }

# tool_use <name> <input-json> — one assistant line of a stream-json transcript.
tool_use() {
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t%s","name":"%s","input":%s}]}}\n' \
    "$RANDOM" "$1" "$2"
}

header() {
  printf '{"type":"system","subtype":"init","cwd":"%s","model":"claude-opus-test"}\n' "$CLONE"
}

# expect <case> <want-exit> <want-pattern-in-output> — reads the transcript from $TMP/<case>.jsonl.
expect() {
  local name=$1 want=$2 pattern=$3 out rc
  out=$(python3 "$AUDIT" "$TMP/$name.jsonl" "$CLONE" 2>&1)
  rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$name: audit exited $rc, want $want. Output:
$out"
    return
  fi
  if [ -n "$pattern" ] && ! grep -qE -- "$pattern" <<<"$out"; then
    fail "$name: output does not match /$pattern/. Output:
$out"
    return
  fi
  echo "ok  $name (exit $rc)"
}

# (1) a file tool whose path is outside the clone
{ header; tool_use Read "{\"file_path\":\"$CLONE/package.json\"}"; tool_use Read '{"file_path":"/etc/passwd"}'; } > "$TMP/outside-read.jsonl"
expect outside-read 1 '/etc/passwd'

# (2) a Bash command naming a path outside the clone
{ header; tool_use Bash '{"command":"ls src && cat /etc/hostname"}'; } > "$TMP/outside-bash.jsonl"
expect outside-bash 1 '/etc/hostname'

# (3) a Bash command escaping the clone with ..
{ header; tool_use Bash '{"command":"cd .. && ls"}'; } > "$TMP/cd-escape.jsonl"
expect cd-escape 1 '\.\.'

# (3b) a relative .. path that leaves the clone, without cd
{ header; tool_use Bash '{"command":"cat ../../secrets.txt"}'; } > "$TMP/dotdot-escape.jsonl"
expect dotdot-escape 1 '\.\./\.\./secrets\.txt'

# (4) any web tool
{ header; tool_use WebFetch '{"url":"https://example.com","prompt":"read it"}'; } > "$TMP/webfetch.jsonl"
expect webfetch 1 'WebFetch'

{ header; tool_use WebSearch '{"query":"how to fix"}'; } > "$TMP/websearch.jsonl"
expect websearch 1 'WebSearch'

# (5) a clean transcript: everything stays inside the clone or in an allowed toolchain dir
{
  header
  tool_use Read "{\"file_path\":\"$CLONE/package.json\"}"
  tool_use Glob '{"pattern":"src/**/*.ts"}'
  tool_use Grep "{\"pattern\":\"cutoff\",\"path\":\"$CLONE/src\"}"
  tool_use Edit "{\"file_path\":\"$CLONE/src/a.ts\",\"old_string\":\"a\",\"new_string\":\"b\"}"
  tool_use Write '{"file_path":"src/b.ts","content":"export const x = \"/etc/not-a-read\";"}'
  tool_use Bash '{"command":"cd src && cat ../package.json 2>/dev/null | head -5; cd .."}'
  tool_use Bash '{"command":"grep -rn \"/api/v1/users\" src || true"}'
  tool_use Bash "{\"command\":\"ls ~/.cargo/registry >/dev/null; $HOME/.cargo/bin/cargo --version\"}"
  tool_use Bash "{\"command\":\"git -C $CLONE status --short && git diff HEAD -- src\"}"
  tool_use TodoWrite '{"todos":[]}'
} > "$TMP/clean.jsonl"
expect clean 0 'clean'

if [ "$failures" -gt 0 ]; then
  echo "cold tests: $failures failure(s)" >&2
  exit 1
fi
echo "cold tests: all passed"
