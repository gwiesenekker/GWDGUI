#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-regression-checks"
CHECKS=(
  board_regression_check.pas
  pdn_regression_check.pas
  game_tree_pdn_filter_check.pas
  game_tree_actor_check.pas
)

mkdir -p "$OUT_DIR"

run_check() {
  local source_file="$1"
  local binary_name
  local compile_log

  binary_name="$(basename "$source_file" .pas)"
  compile_log="$OUT_DIR/$binary_name.compile.log"
  echo "==> $binary_name"
  if ! fpc -Fu"$ROOT_DIR" -FE"$OUT_DIR" "$ROOT_DIR/tests/$source_file" \
    >"$compile_log" 2>&1; then
    cat "$compile_log"
    exit 1
  fi
  "$OUT_DIR/$binary_name"
}

for check in "${CHECKS[@]}"; do
  run_check "$check"
done
