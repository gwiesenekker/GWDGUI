#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-regression-checks"
CHECKS=(
  analyzer_runner_shutdown_check.pas
  analyzer_position_check.pas
  hub_search_fence_check.pas
  endgame_draw_check.pas
  board_regression_check.pas
  pdn_regression_check.pas
  database_import_recovery_check.pas
  database_import_worker_check.pas
  pdn_tree_check.pas
  game_tree_pdn_filter_check.pas
  game_tree_actor_check.pas
  game_tree_validation_check.pas
  game_runner_history_check.pas
  running_game_lifecycle_check.pas
  move_interaction_check.pas
  game_tree_cursor_check.pas
  game_preservation_check.pas
  game_tree_topology_check.pas
  platform_process_check.pas
  socket_disconnect_check.pas
  engine_clock_check.pas
  atomic_file_check.pas
  tournament_record_check.pas
  tournament_pairing_check.pas
)

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

run_check() {
  local source_file="$1"
  local binary_name
  local compile_log

  binary_name="$(basename "$source_file" .pas)"
  compile_log="$OUT_DIR/$binary_name.compile.log"
  echo "==> $binary_name"
  if ! fpc -B -Fu"$ROOT_DIR" -FU"$OUT_DIR" -FE"$OUT_DIR" "$ROOT_DIR/tests/$source_file" \
    >"$compile_log" 2>&1; then
    cat "$compile_log"
    exit 1
  fi
  "$OUT_DIR/$binary_name"
}

for check in "${CHECKS[@]}"; do
  run_check "$check"
done

echo "==> atomic_file_check (filesystem without hard links)"
fpc -B -dGWDGUI_TEST_NO_HARDLINK -Fu"$ROOT_DIR" -FU"$OUT_DIR" -FE"$OUT_DIR" \
  "$ROOT_DIR/tests/atomic_file_check.pas" > "$OUT_DIR/atomic_file_no_link.compile.log" 2>&1
"$OUT_DIR/atomic_file_check"

bash "$ROOT_DIR/tests/source_audit_check.sh"
