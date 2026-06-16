#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
MUTATION_PATTERN='\.RecordMainlineMove\(|\.RecordMainlineAnnotation\(|\.StoreVariationLine\(|\.ClearStoredVariations\(|\.BeginRebuild\(|\.SetHeader\(|\.RecordClockState\(|\.RecordTimeControl\(|\.TrimMainlineToCount\(|\.RemoveMainlineFrom\('

echo "==> source_audit_check"

violations="$(
  rg -n "$MUTATION_PATTERN" "$ROOT_DIR" --glob '*.pas' \
    | grep -vE '/(uGameTree|uGameTreeActor|uGameTreeBuilder)\.pas:' \
    | grep -vE '/tests/' \
    || true
)"

if [[ -n "$violations" ]]; then
  echo "Direct game-tree mutation outside actor/builder boundary:"
  echo "$violations"
  exit 1
fi
