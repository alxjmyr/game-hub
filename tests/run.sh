#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${GODOT_BIN:-$ROOT/.tools/Godot_v4.5.2-stable_linux.x86_64}"
if [[ ! -x "$ENGINE" ]]; then ENGINE="$(command -v godot || command -v godot4 || true)"; fi
if [[ -z "$ENGINE" ]]; then printf '%s\n' 'Set GODOT_BIN to the Godot executable.' >&2; exit 1; fi
TEST_DATA="$(mktemp -d "${TMPDIR:-/tmp}/gamehub-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_DATA"' EXIT
export XDG_DATA_HOME="$TEST_DATA/data"
export XDG_CONFIG_HOME="$TEST_DATA/config"
export XDG_CACHE_HOME="$TEST_DATA/cache"
for suite in memory ball_bucket hub; do
  # Accelerate physics only. The hub exercises the real-time audio mixer,
  # which needs wall-clock time to release playback resources on shutdown.
  TIMING=()
  if [[ "$suite" == ball_bucket ]]; then TIMING=(--fixed-fps 120); fi
  if ! "$ENGINE" --headless --path "$ROOT" "${TIMING[@]}" --script "tests/test_$suite.gd" > "$TEST_DATA/$suite.log" 2>&1; then
    cat "$TEST_DATA/$suite.log"
    exit 1
  fi
  cat "$TEST_DATA/$suite.log"
  if rg -q 'SCRIPT ERROR|ERROR:|FAIL|leaked' "$TEST_DATA/$suite.log"; then exit 1; fi
done
