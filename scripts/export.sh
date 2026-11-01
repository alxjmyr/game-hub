#!/usr/bin/env bash
# Usage: scripts/export.sh [linux|windows|macos|all]
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${GODOT_BIN:-$ROOT/.tools/Godot_v4.5.2-stable_linux.x86_64}"
if [[ ! -x "$ENGINE" ]]; then ENGINE="$(command -v godot || command -v godot4 || true)"; fi
if [[ -z "$ENGINE" ]]; then printf '%s\n' 'Set GODOT_BIN to a Godot 4.5.2 executable.' >&2; exit 1; fi
# Keep all editor caches and installed templates inside this checkout.
export XDG_DATA_HOME="$ROOT/.tools/data"
export XDG_CONFIG_HOME="$ROOT/.tools/config"
export XDG_CACHE_HOME="$ROOT/.tools/cache"
mkdir -p "$ROOT/build/linux" "$ROOT/build/windows" "$ROOT/build/macos"
"$ENGINE" --headless --path "$ROOT" --editor --import --quit
TARGET="${1:-linux}"
case "$TARGET" in
  linux|windows|macos) TARGETS=("$TARGET") ;;
  all) TARGETS=(linux windows macos) ;;
  *) printf '%s\n' 'Usage: scripts/export.sh [linux|windows|macos|all]' >&2; exit 2 ;;
esac
for PLATFORM in "${TARGETS[@]}"; do
  case "$PLATFORM" in
    linux) "$ENGINE" --headless --path "$ROOT" --export-release 'Linux' "$ROOT/build/linux/game-hub" ;;
    windows) "$ENGINE" --headless --path "$ROOT" --export-release 'Windows' "$ROOT/build/windows/game-hub.exe" ;;
    macos) "$ENGINE" --headless --path "$ROOT" --export-release 'macOS' "$ROOT/build/macos/Game Hub.zip" ;;
  esac
  cp "$ROOT/licenses/GODOT-LICENSE.txt" "$ROOT/licenses/GODOT-COPYRIGHT.txt" "$ROOT/build/$PLATFORM/"
done
