#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-lifecycle-checks"
mkdir -p "$OUT_DIR/config"

echo "==> running_game_lifecycle_check (Lazarus nogui)"
if ! lazbuild --no-write-project --ws=nogui --pcp="$OUT_DIR/config" \
  --opt="-FU$OUT_DIR" --opt="-o$OUT_DIR/running_game_lifecycle_check" \
  "$ROOT_DIR/tests/running_game_lifecycle_check.lpi" \
  > "$OUT_DIR/build.log" 2>&1; then
  cat "$OUT_DIR/build.log"
  exit 1
fi
"$OUT_DIR/running_game_lifecycle_check"
