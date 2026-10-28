#!/usr/bin/env bash
# Compiles GWDGUI for 64-bit Windows from Linux, so Windows-only code paths
# ({$IFDEF MSWINDOWS}) are checked without a Windows host. Needs the FPC RTL
# and packages built for x86_64-win64 where fpc finds them; skips otherwise.
# The result is not run: this is a compile check only.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-windows-cross-check"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/probe"

echo "==> windows_cross_check (x86_64-win64, win32 widgetset)"
printf 'program probe; uses Windows, SyncObjs; begin end.\n' > "$OUT_DIR/probe/probe.pas"
if ! fpc -Twin64 -Px86_64 -FE"$OUT_DIR/probe" "$OUT_DIR/probe/probe.pas" > "$OUT_DIR/probe.log" 2>&1; then
  echo "skipped: no FPC units for x86_64-win64 (build the RTL and packages with OS_TARGET=win64)"
  exit 0
fi

fpc -B -Twin64 -Px86_64 -FU"$OUT_DIR/probe" -FE"$OUT_DIR/probe" \
  "$ROOT_DIR/tools/generate_build_info.pas" > "$OUT_DIR/generator.log" 2>&1 ||
  { cat "$OUT_DIR/generator.log"; exit 1; }

if ! GWDGUI_LAZBUILD_TARGET=win64:x86_64 python3 "$ROOT_DIR/tests/build_lazarus_check.py" \
  win32 "$OUT_DIR/app" "$ROOT_DIR/gwdgui.lpi" > "$OUT_DIR/app.log" 2>&1; then
  grep -E 'Error|Fatal' "$OUT_DIR/app.log" || tail -40 "$OUT_DIR/app.log"
  exit 1
fi
echo "Windows cross-compile check passed (gwdgui.exe built, not run)"
