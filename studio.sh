#!/usr/bin/env bash
#
# Run the official ZMK Studio web app locally.
#
# Opens on http://localhost:5173 in your browser. Use a Chromium browser
# (Chrome/Edge) because Web Serial is required to talk to the keyboard over USB.
#
# Before connecting, flash the Studio-enabled firmware built by ./build.sh:
#   build/eyelash_sofle_studio_left.uf2
#
# Usage:
#   ./studio.sh
#
# Environment overrides:
#   ZMK_STUDIO_DIR   where zmk-studio is cloned (default: ../zmk-studio)
#   ZMK_STUDIO_REF   git ref to check out          (default: main)
#   ZMK_STUDIO_PORT  local port                    (default: 5173)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${ZMK_STUDIO_DIR:-$(dirname "$ROOT")/zmk-studio}"
REF="${ZMK_STUDIO_REF:-main}"
PORT="${ZMK_STUDIO_PORT:-5173}"
IMAGE="${ZMK_STUDIO_IMAGE:-node:20}"

winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

if [ ! -d "$SRC/.git" ]; then
  echo ">>> cloning zmk-studio ($REF) into $SRC"
  git clone --branch "$REF" https://github.com/zmkfirmware/zmk-studio.git "$SRC"
fi

echo ">>> starting ZMK Studio at http://localhost:$PORT"
echo ">>> (keep this running; Ctrl-C to stop)"

MSYS_NO_PATHCONV=1 docker run --rm -it \
  -p "$PORT:5173" \
  -v "$(winpath "$SRC"):/app" \
  -v zmk-studio-node-modules:/app/node_modules \
  -w /app "$IMAGE" bash -euo pipefail -c '
    if [ ! -d node_modules/.package-lock.json ]; then
      npm install --no-audit --no-fund
    fi
    npm run dev -- --host 0.0.0.0 --port 5173
  '
