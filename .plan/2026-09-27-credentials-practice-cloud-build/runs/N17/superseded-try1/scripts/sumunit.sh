#!/usr/bin/env bash
# sumunit.sh <unit.txt> — one line: backend cargo passed/failed (summed over test binaries) and the
# flutter suite's final line, read from a checkpoint's captured unit.txt.
f=$1
awk '/^test result:/{p+=$4; fl+=$6} END{printf "backend: %d passed, %d failed", p, fl}' "$f"
printf ' · app: %s · %s\n' "$(grep -E '^[0-9:]+ \+[0-9]+.*(All tests passed!|Some tests failed\.)' "$f" | tail -1 | sed 's/^[0-9:]* //')" "$(grep '^test exit:' "$f")"
