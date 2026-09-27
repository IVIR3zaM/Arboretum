#!/usr/bin/env bash
# bootstrap.sh — the first thing the cloud orchestrator runs on every start or resume (run-plan
# addition 1). Idempotent: safe to run any number of times. Installs toolchains only on Linux.
# `--check` runs the probes and reports, on any OS, with no installs.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
P=.plan/2026-09-27-credentials-practice-cloud-build
PRACTICE=practices/credentials

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

IS_LINUX=0
[ "$(uname -s)" = "Linux" ] && IS_LINUX=1

status=0

probe() {
  local name="$1" url="$2"
  if curl -fsSL --max-time 10 -o /dev/null "$url" 2>/dev/null; then
    echo "probe $name: ok"
  else
    echo "probe $name: FAILED — switch the environment network to Full"
    status=1
  fi
}

# --- idempotent PATH persistence (Linux install path only) ---
append_path_once() {
  local line="$1" f
  for f in "$HOME/.bashrc" "$HOME/.profile"; do
    touch "$f" 2>/dev/null || continue
    grep -qxF "$line" "$f" 2>/dev/null || echo "$line" >> "$f"
  done
}

install_toolchains() {
  # rustup, stable, minimal profile — honour backend/rust-toolchain.toml if present.
  if ! command -v rustup >/dev/null 2>&1; then
    echo "bootstrap: installing rustup (minimal profile)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
    append_path_once 'export PATH="$HOME/.cargo/bin:$PATH"'
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  local toolchain_file="$PRACTICE/backend/rust-toolchain.toml"
  if [ -f "$toolchain_file" ] && command -v rustup >/dev/null 2>&1; then
    rustup show >/dev/null 2>&1 || true
  fi

  # Flutter — pinned version from scripts/toolchains.env if N04 has written it, else latest stable.
  local flutter_version=""
  if [ -f "$P/scripts/toolchains.env" ]; then
    flutter_version=$(sed -n 's/^FLUTTER_VERSION=//p' "$P/scripts/toolchains.env" | head -1)
  fi
  if ! command -v flutter >/dev/null 2>&1; then
    echo "bootstrap: installing Flutter ${flutter_version:-latest stable}"
    local dest="$HOME/flutter-sdk"
    if [ -n "$flutter_version" ]; then
      git clone -q --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$dest"
    else
      git clone -q --depth 1 -b stable https://github.com/flutter/flutter.git "$dest"
    fi
    append_path_once "export PATH=\"$dest/bin:\$PATH\""
    export PATH="$dest/bin:$PATH"
    flutter precache >/dev/null 2>&1 || true
  fi
}

fetch_deps() {
  # Fetch against committed lockfiles wherever they exist, so test/grade can run offline.
  if command -v cargo >/dev/null 2>&1; then
    [ -f "$PRACTICE/backend/Cargo.toml" ] && (cd "$PRACTICE/backend" && cargo fetch --locked)
    for f in "$PRACTICE"/_solutions/*/Cargo.toml; do
      [ -e "$f" ] || continue
      (cd "$(dirname "$f")" && cargo fetch --locked)
    done
  fi
  if command -v flutter >/dev/null 2>&1 && [ -f "$PRACTICE/app/pubspec.yaml" ]; then
    (cd "$PRACTICE/app" && flutter pub get --enforce-lockfile)
  fi
}

if [ "$IS_LINUX" = 1 ] && [ "$CHECK_ONLY" != 1 ]; then
  install_toolchains
  fetch_deps
fi

probe rustup https://static.rust-lang.org/rustup/release-stable.toml
probe crates.io https://index.crates.io/config.json
probe pub.dev https://pub.dev/
probe "flutter storage" https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json

if command -v claude >/dev/null 2>&1; then
  echo "probe claude CLI: ok"
else
  echo "probe claude CLI: FAILED — claude CLI not found on PATH"
  status=1
fi

if git push --dry-run origin credentials-cloud-build >/dev/null 2>&1; then
  echo "probe git push: ok"
else
  echo "probe git push: FAILED — cannot push to credentials-cloud-build"
  status=1
fi

grep -m1 '^status:' "$P/plan.md"

exit "$status"
