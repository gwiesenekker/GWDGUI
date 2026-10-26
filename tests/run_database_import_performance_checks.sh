#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gwdgui-db-performance.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT
if ! fpc -B -O2 -Fu"$ROOT_DIR" -FU"$OUT_DIR" -FE"$OUT_DIR" \
  "$ROOT_DIR/tests/database_import_performance_check.pas" > "$OUT_DIR/build.log" 2>&1; then
  cat "$OUT_DIR/build.log"
  exit 1
fi
"$OUT_DIR/database_import_performance_check" "$ROOT_DIR/tests/fixtures/performance-long.pdn" "${1:-100}"
