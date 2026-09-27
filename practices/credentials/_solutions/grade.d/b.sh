#!/usr/bin/env bash
# grade.d/b.sh — axis (b): the phase-3 feature gate and the cross-stack check.
#
# Run from the practice root (a copy that still has _solutions/). Prints one `case <name>: PASS|FAIL`
# line per graded case and, last, `axis b: PASS|FAIL <n>/<m>`; exits 0 only on PASS.
#
#   1. builds the hidden Rust bin _solutions/xstack against this tree's backend/ (offline, --locked,
#      on the backend's own Cargo.lock) and has it issue the gate's credentials from Harbour Club;
#   2. copies app/ into a temp grading copy, adds _solutions/app-tests/ to its test/, and runs
#      `flutter test --no-pub` headless (no device, no integration_test/) — 4 `feature:` cases;
#   3. hands the presentation the wallet built to the backend's Verifier — 3 `xstack:` cases.
#
# The working tree is not modified except for the gitignored build cache _solutions/xstack/target/
# (override with XSTACK_TARGET_DIR).
set -uo pipefail

ROOT=$(pwd)
M=7
FEATURE_CASES=(
  "feature: discloses exactly the claims the DCQL query asks for"
  "feature: the presentation is signed by the holder's key"
  "feature: the presentation is bound to the request's nonce and domain"
  "feature: an expired credential is refused"
)
XSTACK_CASES=(
  "xstack: the backend verifier accepts the wallet's presentation"
  "xstack: the backend verifier rejects a tampered disclosed value"
  "xstack: the backend verifier rejects the presentation replayed to another nonce or domain"
)

fail_all() {
  echo "axis b: setup failed — $1" >&2
  local c
  for c in "${FEATURE_CASES[@]}" "${XSTACK_CASES[@]}"; do echo "case $c: FAIL — setup: $1"; done
  echo "axis b: FAIL 0/$M"
  exit 1
}

for f in app/pubspec.yaml backend/Cargo.toml backend/Cargo.lock _solutions/xstack/Cargo.toml _solutions/app-tests/feature_gate_test.dart; do
  [ -f "$f" ] || fail_all "missing $f (run from the practice root, with _solutions/)"
done
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/flutter-sdk/bin/flutter" ]; then
  export PATH="$HOME/flutter-sdk/bin:$PATH"
fi
command -v flutter >/dev/null 2>&1 || fail_all "flutter not on PATH (run bootstrap.sh)"
command -v cargo >/dev/null 2>&1 || fail_all "cargo not on PATH (run bootstrap.sh)"
command -v python3 >/dev/null 2>&1 || fail_all "python3 not on PATH"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# --- 1. the cross-stack bin, on the backend's locked dependency set ------------------------------
XS="$T/xstack"
mkdir -p "$XS"
cp -R _solutions/xstack/src _solutions/xstack/rust-toolchain.toml "$XS/"
sed "s|path = \"../../backend\"|path = \"$ROOT/backend\"|" _solutions/xstack/Cargo.toml >"$XS/Cargo.toml"
cp backend/Cargo.lock "$XS/Cargo.lock"
export CARGO_TARGET_DIR="${XSTACK_TARGET_DIR:-$ROOT/_solutions/xstack/target}"
# Adds only the xstack root entry to the backend's lock; every dependency keeps its locked version.
(cd "$XS" && cargo update --offline --workspace --quiet) >"$T/cargo.log" 2>&1 ||
  { cat "$T/cargo.log" >&2; fail_all "xstack lock derivation failed"; }
(cd "$XS" && cargo build --offline --locked --quiet) >>"$T/cargo.log" 2>&1 ||
  { cat "$T/cargo.log" >&2; fail_all "xstack build failed"; }
BIN="$CARGO_TARGET_DIR/debug/xstack"

# --- 2. the wallet gate, in a temp grading copy of app/ -------------------------------------------
APP="$T/app"
mkdir -p "$APP"
(cd app && tar --exclude=./build -cf - .) | (cd "$APP" && tar -xf -) || fail_all "copying app/ failed"
[ -f "$APP/.dart_tool/package_config.json" ] ||
  fail_all "app/.dart_tool/package_config.json missing — run the practice's install command first"
cp -R _solutions/app-tests/. "$APP/test/"
"$BIN" issue "$APP/test/gate" || fail_all "xstack issue failed"

(cd "$APP" && flutter test --no-pub --reporter json test/feature_gate_test.dart) >"$T/flutter.json" 2>"$T/flutter.err"

python3 - "$T/flutter.json" "${FEATURE_CASES[@]}" >"$T/feature.txt" <<'PY'
import json, sys
path, cases = sys.argv[1], sys.argv[2:]
names, results, errors = {}, {}, {}
for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        e = json.loads(line)
    except ValueError:
        continue
    t = e.get("type")
    if t == "testStart":
        names[e["test"]["id"]] = e["test"]["name"]
    elif t == "error":
        errors.setdefault(e["testID"], (e.get("error") or "").strip().splitlines()[:1])
    elif t == "testDone":
        results[names.get(e["testID"], "")] = (e.get("result"), e["testID"])
for case in cases:
    got = results.get(case)
    if got and got[0] == "success":
        print(f"case {case}: PASS")
    else:
        why = "did not run (compile error?)" if not got else " ".join(errors.get(got[1], [got[0]])) or got[0]
        print(f"case {case}: FAIL — {why}")
PY
if ! grep -q '^case ' "$T/feature.txt"; then
  cat "$T/flutter.err" >&2
  fail_all "could not read the flutter test results"
fi
if grep -q 'did not run' "$T/feature.txt"; then
  head -40 "$T/flutter.err" >&2
fi

# --- 3. the backend verifier on the wallet's presentation ----------------------------------------
"$BIN" verify "$APP/test/gate" "$ROOT/reference/infra/hosted-dids" >"$T/xstack.txt" 2>&1

status=0
passed=0
for c in "${FEATURE_CASES[@]}" "${XSTACK_CASES[@]}"; do
  line=$(grep -F "case $c: " "$T/feature.txt" "$T/xstack.txt" -h | head -1)
  [ -n "$line" ] || line="case $c: FAIL — no result"
  echo "$line"
  case "$line" in
    "case $c: PASS"*) passed=$((passed + 1)) ;;
    *) status=1 ;;
  esac
done

if [ "$status" = 0 ] && [ "$passed" = "$M" ]; then
  echo "axis b: PASS $passed/$M"
  exit 0
fi
echo "axis b: FAIL $passed/$M"
exit 1
