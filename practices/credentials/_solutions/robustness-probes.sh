#!/usr/bin/env bash
# robustness-probes.sh — EXAMINER-ONLY robustness probes (non-blocking; generator/CONTRACT.md step 6a).
#
# Sits beside the gate and is never part of it: grade.sh does not call this script, and its result never
# changes the gate's pass/fail or exit code. The examiner runs it from the practice root of the graded copy
# (a copy that still has _solutions/, after the practice's install command) and reports the last line,
# `robustness n/m`, next to the gate result (rubric.md, Axis A).
#
# Nine probes for vectors the frozen gate does not see:
#   wallet  (_solutions/robustness/wallet_probes_test.dart, flutter test --no-pub in a temp copy of app/)
#     W1 W2  held state handed out by reference — the wallet store (latent #2)
#     W3     the presentation path shares no state with the held credential
#     G1     holder binding guarded on the presentation, not only on requestCredential
#     D1     a DCQL query naming no claim discloses nothing, still signed and bound (degenerate query)
#     D2     a DCQL query for a claim the credential lacks is refused, not half-answered (degenerate query)
#   backend (_solutions/robustness/probes, built offline --locked on backend/Cargo.lock in a temp copy)
#     N1     a tenant with zero subscriptions (degenerate quantity)
#     N2     the reserved-name rule holds for a tenant subscription, not only for the canary's URL
#     S1     every status-list index handed out can be revoked (latent #5, degenerate capacity)
#
# One `PASS|FAIL <id> <what>` line per probe, then `robustness n/m`. Exit 0 once the probes ran (whatever
# they scored); exit 2 when they could not be set up. The working tree is not modified except for the
# gitignored build cache _solutions/robustness/probes/target/ (override with PROBES_TARGET_DIR).
set -uo pipefail

ROOT=$(pwd)
WALLET_IDS=(W1 W2 W3 G1 D1 D2)
BACKEND_IDS=(N1 N2 S1)
M=$(( ${#WALLET_IDS[@]} + ${#BACKEND_IDS[@]} ))

setup_failed() {
  echo "robustness: setup failed — $1" >&2
  echo "robustness 0/$M (not run)"
  exit 2
}

for f in app/pubspec.yaml backend/Cargo.toml backend/Cargo.lock _solutions/robustness/probes/Cargo.toml _solutions/robustness/wallet_probes_test.dart; do
  [ -f "$f" ] || setup_failed "missing $f (run from the practice root, with _solutions/)"
done
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/flutter-sdk/bin/flutter" ]; then
  export PATH="$HOME/flutter-sdk/bin:$PATH"
fi
if ! command -v cargo >/dev/null 2>&1 && [ -x "$HOME/.cargo/bin/cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
command -v flutter >/dev/null 2>&1 || setup_failed "flutter not on PATH"
command -v cargo >/dev/null 2>&1 || setup_failed "cargo not on PATH"
command -v python3 >/dev/null 2>&1 || setup_failed "python3 not on PATH"
[ -f app/.dart_tool/package_config.json ] ||
  setup_failed "app/.dart_tool/package_config.json missing — run the practice's install command first"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
: >"$T/lines.txt"

# --- backend probes, on the backend's locked dependency set ---------------------------------------
PR="$T/probes"
mkdir -p "$PR"
cp -R _solutions/robustness/probes/src _solutions/robustness/probes/rust-toolchain.toml "$PR/"
sed "s|path = \"../../../backend\"|path = \"$ROOT/backend\"|" _solutions/robustness/probes/Cargo.toml >"$PR/Cargo.toml"
cp backend/Cargo.lock "$PR/Cargo.lock"
export CARGO_TARGET_DIR="${PROBES_TARGET_DIR:-$ROOT/_solutions/robustness/probes/target}"
if (cd "$PR" && cargo update --offline --workspace --quiet && cargo build --offline --locked --quiet) >"$T/cargo.log" 2>&1; then
  "$CARGO_TARGET_DIR/debug/probes" >>"$T/lines.txt" 2>"$T/probes.err"
else
  head -40 "$T/cargo.log" >&2
  for id in "${BACKEND_IDS[@]}"; do echo "FAIL $id: the backend probes did not build against this tree" >>"$T/lines.txt"; done
fi

# --- wallet probes, in a temp copy of app/ ---------------------------------------------------------
APP="$T/app"
mkdir -p "$APP"
(cd app && tar --exclude=./build -cf - .) | (cd "$APP" && tar -xf -) || setup_failed "copying app/ failed"
cp _solutions/robustness/wallet_probes_test.dart "$APP/test/"
(cd "$APP" && flutter test --no-pub --reporter json test/wallet_probes_test.dart) >"$T/flutter.json" 2>"$T/flutter.err"
python3 - "$T/flutter.json" "${WALLET_IDS[@]}" >>"$T/lines.txt" <<'PY'
import json, re, sys
path, ids = sys.argv[1], sys.argv[2:]
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
        errors.setdefault(e["testID"], " ".join((e.get("error") or "").strip().split())[:220])
    elif t == "testDone":
        name = names.get(e["testID"], "")
        m = re.match(r"robustness (\w+): (.*)", name)
        if m:
            results[m.group(1)] = (m.group(2), e.get("result"), e["testID"])
for pid in ids:
    got = results.get(pid)
    if not got:
        print(f"FAIL {pid}: did not run (compile error?)")
    elif got[1] == "success":
        print(f"PASS {pid} {got[0]}")
    else:
        print(f"FAIL {pid} {got[0]}: {errors.get(got[2], got[1])}")
PY
if grep -q 'did not run' "$T/lines.txt"; then
  head -40 "$T/flutter.err" >&2
fi

# --- report, wallet first ----------------------------------------------------------------------------
passed=0
for id in "${WALLET_IDS[@]}" "${BACKEND_IDS[@]}"; do
  line=$(grep -E "^(PASS|FAIL) $id( |:)" "$T/lines.txt" | head -1)
  [ -n "$line" ] || line="FAIL $id: no result"
  echo "$line"
  case "$line" in PASS*) passed=$((passed + 1)) ;; esac
done
echo "robustness $passed/$M"
exit 0
