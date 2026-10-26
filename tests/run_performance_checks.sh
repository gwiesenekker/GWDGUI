#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gwdgui-performance.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT
# Fixed compiler settings make timings comparable between checkouts.
if ! fpc -B -O2 -Fu"$ROOT_DIR" -FU"$OUT_DIR" -FE"$OUT_DIR" \
  "$ROOT_DIR/tests/performance_check.pas" > "$OUT_DIR/compile.log" 2>&1; then
  cat "$OUT_DIR/compile.log"
  exit 1
fi
printf '# revision=%s\n' "$(git -C "$ROOT_DIR" rev-parse HEAD)"
if ! git -C "$ROOT_DIR" diff --quiet HEAD --; then echo '# tracked_worktree=modified'; fi
printf '# compiler=%s flags=-B -O2\n' "$(fpc -iV)"
printf '# host=%s\n' "$(uname -srm)"
printf '# fixture_sha256=%s\n' "$(sha256sum "$ROOT_DIR/tests/fixtures/performance-long.pdn" | cut -d ' ' -f 1)"
"$OUT_DIR/performance_check" "$ROOT_DIR/tests/fixtures/performance-long.pdn" "$@"
