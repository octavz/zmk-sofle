#!/usr/bin/env bash
#
# Build the eyelash_sofle firmware locally with Docker.
#
# Uses the exact same image as the GitHub "Build ZMK firmware" workflow, so a
# local build and a CI build produce the same result. All targets from
# build.yaml are built and written to ./build as .uf2 files.
#
# Usage:
#   ./build.sh
#
# Environment overrides:
#   ZMK_BUILD_CACHE  west workspace cache dir (default: ../zmk-sofle-build)
#   ZMK_BUILD_OUT    artifact output dir       (default: ./build)
#   ZMK_BUILD_IMAGE  build image               (default: zmkfirmware/zmk-build-arm:stable)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${ZMK_BUILD_IMAGE:-zmkfirmware/zmk-build-arm:stable}"
CACHE="${ZMK_BUILD_CACHE:-$(dirname "$ROOT")/zmk-sofle-build}"
OUT="${ZMK_BUILD_OUT:-$ROOT/build}"

winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

mkdir -p "$CACHE" "$OUT"

echo ">>> build image : $IMAGE"
echo ">>> west cache  : $CACHE"
echo ">>> artifacts   : $OUT"

MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$(winpath "$ROOT"):/workspace:ro" \
  -v "$(winpath "$CACHE"):/base" \
  -v "$(winpath "$OUT"):/out" \
  -w /base "$IMAGE" bash -euo pipefail -c '
git config --global --add safe.directory "*" >/dev/null 2>&1 || true

# Sync this repo (west manifest + config) into the isolated workspace.
mkdir -p /base/config
cp -a /workspace/config/. /base/config/

if [ ! -d /base/.west ]; then
  west init -l /base/config
fi
west update
west zephyr-export

common="-DZMK_CONFIG=/base/config -DZMK_EXTRA_MODULES=/workspace"

# build <board> <shield> <name> <west-args> <cmake-args>
build() {
  local board="$1" shield="$2" name="$3" west_args="$4" cmake_args="$5"
  local dir="/base/build-$name"
  echo ""
  echo ">>> building $name  ($board + $shield)"
  rm -rf "$dir"
  west build -s zmk/app -d "$dir" -b "$board" $west_args -- \
    $common -DSHIELD="$shield" $cmake_args
  cp "$dir/zephyr/zmk.uf2" "/out/$name.uf2"
}

# Keep these in sync with build.yaml.
build eyelash_sofle_left  nice_view        eyelash_sofle_left        "" ""
build eyelash_sofle_right nice_view_custom eyelash_sofle_right       "" ""
build eyelash_sofle_left  nice_view        eyelash_sofle_studio_left \
  "-S studio-rpc-usb-uart" \
  "-DCONFIG_ZMK_STUDIO=y -DCONFIG_ZMK_STUDIO_LOCKING=n"
build eyelash_sofle_left  settings_reset   settings_reset            "" ""

echo ""
echo ">>> done. artifacts:"
ls -l /out/*.uf2
'
