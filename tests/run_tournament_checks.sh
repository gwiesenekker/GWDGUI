#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-tournament-checks"
mkdir -p "$OUT_DIR/config" "$OUT_DIR/units"
echo "==> tournament_preservation_check (GTK2, hidden tournament form)"
if ! lazbuild --no-write-project --ws=gtk2 --opt=-dGWDGUI_NONINTERACTIVE_TEST --pcp="$OUT_DIR/config" \
  --opt="-FU$OUT_DIR/units" --opt="-o$OUT_DIR/tournament_preservation_check" \
  "$ROOT_DIR/tests/tournament_preservation_check.lpi" > "$OUT_DIR/build.log" 2>&1; then
  cat "$OUT_DIR/build.log"
  exit 1
fi
cd "$OUT_DIR"
XDG_CONFIG_HOME="$OUT_DIR/recovery" "$OUT_DIR/tournament_preservation_check" "$@"
