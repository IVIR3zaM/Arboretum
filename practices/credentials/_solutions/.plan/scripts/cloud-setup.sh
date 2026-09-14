#!/usr/bin/env bash
# Cloud environment setup script for the credentials build. Paste the body into
# claude.ai/code → environment settings → "Setup script". Runs as root on Ubuntu 24.04 x86_64 before
# Claude Code starts, and the result is cached (re-runs only when this script changes or after ~7 days).
#
# Needs network access "Trusted" (storage.googleapis.com, static.rust-lang.org, crates.io, pub.dev are on
# the default list). Keep it under ~5 minutes.
#
# VERSIONS MUST MATCH the pins approved at gate 015 (digests/deps-pins.md). Editing them rebuilds the cache.
set -euo pipefail

FLUTTER_VERSION=3.47.4
FLUTTER_SHA256=5b45f0ceda99b9bebdc873e7e69f6450aeb4c30f454b505e2e62fc9255a907d3
RUST_TOOLCHAIN=1.95.0

install_flutter() {
  cd /opt
  curl -fsSL -o flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  echo "${FLUTTER_SHA256}  flutter.tar.xz" | sha256sum -c -
  tar -xJf flutter.tar.xz
  rm flutter.tar.xz
  git config --system --add safe.directory /opt/flutter
  ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
  ln -sf /opt/flutter/bin/dart /usr/local/bin/dart
  flutter config --no-analytics >/dev/null
  flutter --version            # builds the flutter_tool snapshot once, into the cache
}

install_rust() {
  if command -v rustup >/dev/null; then
    rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal
    rustup default "$RUST_TOOLCHAIN"
  else
    echo "rustup missing; rust-toolchain.toml cannot auto-install $RUST_TOOLCHAIN" >&2
    return 1
  fi
}

install_flutter & f=$!
install_rust & r=$!
wait "$f"
wait "$r"
echo "cloud-setup: flutter ${FLUTTER_VERSION}, rust ${RUST_TOOLCHAIN} ready"
