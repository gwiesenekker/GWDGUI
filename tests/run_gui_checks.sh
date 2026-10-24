#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-gui-checks"
mkdir -p "$OUT_DIR/config" "$OUT_DIR/units"

echo "==> standalone_preservation_check (GTK2, hidden main form)"
if ! lazbuild --no-write-project --ws=gtk2 --pcp="$OUT_DIR/config" \
  --opt="-FU$OUT_DIR/units" --opt="-o$OUT_DIR/standalone_preservation_check" \
  "$ROOT_DIR/tests/standalone_preservation_check.lpi" > "$OUT_DIR/build.log" 2>&1; then
  cat "$OUT_DIR/build.log"
  exit 1
fi
cd "$OUT_DIR"
"$OUT_DIR/standalone_preservation_check"
