#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" >/dev/null && pwd -P)"
OUT_DIR="${1:-${TMPDIR:-/tmp}/gwdgui-app-build}"
python3 "$ROOT_DIR/tests/build_lazarus_check.py" gtk2 "$OUT_DIR" "$ROOT_DIR/gwdgui.lpi"
install -m 775 "$OUT_DIR/gwdgui" "$ROOT_DIR/.gwdgui-new-build"
mv -f "$ROOT_DIR/.gwdgui-new-build" "$ROOT_DIR/gwdgui"
echo "Built $ROOT_DIR/gwdgui"
