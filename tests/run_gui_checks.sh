#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-gui-checks"
mkdir -p "$OUT_DIR/config" "$OUT_DIR/units"

echo "==> standalone_preservation_check (GTK2, hidden main form)"
if ! python3 "$ROOT_DIR/tests/build_lazarus_check.py" gtk2 "$OUT_DIR" \
  "$ROOT_DIR/tests/standalone_preservation_check.lpi" > "$OUT_DIR/build.log" 2>&1; then
  cat "$OUT_DIR/build.log"
  exit 1
fi
cd "$OUT_DIR"
"$OUT_DIR/standalone_preservation_check"

echo "==> main_form_boundaries_check (GTK2, interaction and analysis lifecycle)"
if ! python3 "$ROOT_DIR/tests/build_lazarus_check.py" gtk2 "$OUT_DIR" \
  "$ROOT_DIR/tests/main_form_boundaries_check.lpi" > "$OUT_DIR/boundaries-build.log" 2>&1; then
  cat "$OUT_DIR/boundaries-build.log"
  exit 1
fi
"$OUT_DIR/main_form_boundaries_check"


echo "==> gui_delivery_check (GTK2, queue consumption and shutdown)"
if ! python3 "$ROOT_DIR/tests/build_lazarus_check.py" gtk2 "$OUT_DIR" \
  "$ROOT_DIR/tests/gui_delivery_check.lpi" > "$OUT_DIR/delivery-build.log" 2>&1; then
  cat "$OUT_DIR/delivery-build.log"
  exit 1
fi
"$OUT_DIR/gui_delivery_check"


echo "==> help_menu_check (GTK2, shortcuts and application help)"
if ! python3 "$ROOT_DIR/tests/build_lazarus_check.py" gtk2 "$OUT_DIR" \
  "$ROOT_DIR/tests/help_menu_check.lpi" > "$OUT_DIR/help-build.log" 2>&1; then
  cat "$OUT_DIR/help-build.log"
  exit 1
fi
"$OUT_DIR/help_menu_check"


echo "==> notation_preferences_check (GTK2, styles and SynEdit ranges)"
if ! python3 "$ROOT_DIR/tests/build_lazarus_check.py" gtk2 "$OUT_DIR" \
  "$ROOT_DIR/tests/notation_preferences_check.lpi" > "$OUT_DIR/notation-preferences-build.log" 2>&1; then
  cat "$OUT_DIR/notation-preferences-build.log"
  exit 1
fi
"$OUT_DIR/notation_preferences_check"
