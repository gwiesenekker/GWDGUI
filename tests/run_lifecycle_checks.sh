#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-lifecycle-checks"
mkdir -p "$OUT_DIR/config"

echo "==> running_game_lifecycle_check (Lazarus nogui)"
if ! python3 "$ROOT_DIR/tests/build_lazarus_check.py" nogui "$OUT_DIR" \
  "$ROOT_DIR/tests/running_game_lifecycle_check.lpi" > "$OUT_DIR/build.log" 2>&1; then
  cat "$OUT_DIR/build.log"
  exit 1
fi
"$OUT_DIR/running_game_lifecycle_check"
