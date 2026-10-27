#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
MUTATION_PATTERN='\.SetStatusText\(|\.SetTimeControl\(|\.RecordAutoPlayPVForNodeId\(|\.RestoreNodeData\(|\.RecordBranchMove\(|\.RecordNodeAnnotation\(|\.SetNodeOrigin\(|\.ClearBranches\(|\.RemoveBranch\(|\.RecordCompletedMoveData\(|\.RecordMainlineMove\(|\.RecordMainlineAnnotation\(|\.BeginRebuild\(|\.SetHeader\(|\.SetGameState\(|\.SetClockState\(|\.SetNodeClockState\(|\.RecordClockState\(|\.RecordTimeControl\(|\.RecordEnginePV\(|\.RecordAnnotatorPV\(|\.RecordEnginePVForNodeId\(|\.RecordAnnotatorPVForNodeId\(|\.TrimMainlineToCount\(|\.RemoveMainlineFrom\('

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

# The model owns child nodes; import/rebuild must not regain line-index state.
adapter_violations="$(
  rg -n 'TGameTreeVariationLine|FVariationLines|RebuildVariationLines|GameTreeVariationLineInput|StoreVariationLine|FindVariationNode|TryLocateVariationNode' \
    "$ROOT_DIR/uGameTree.pas" "$ROOT_DIR/uGameTreeActor.pas" \
    "$ROOT_DIR/uGameTreeBuilder.pas" "$ROOT_DIR/uGameTreePdn.pas" \
    "$ROOT_DIR/uMainForm.pas" || true
)"
if [[ -n "$adapter_violations" ]]; then
  echo "Retired variation-line adapter reintroduced:"
  echo "$adapter_violations"
  exit 1
fi

if rg -n 'DecodePdnVariationLine|MoveVariationsText|MoveVariationAnnotationsText' "$ROOT_DIR/uMainForm.pas"; then
  echo "The GUI must consume parsed PDN nodes, not legacy flattened fields."
  exit 1
fi

if rg -n 'DecodeVariationAnnotations|EncodeVariationAnnotations|DecodePdnVariationLine' "$ROOT_DIR/uGameTreeActor.pas"; then
  echo "Game-tree commands must accept typed moves and literal node annotations."
  exit 1
fi

# Game-neutral units reach the game only through uGamePosition (see
# claude/position-interface-proposal.md). Each migration step adds the units it
# converts. A generic unit must not use the draughts board or parse move text.
GENERIC_UNITS=(
  uGamePosition
  uGameTree
  uGameTreeActor
  uGameTreeBuilder
  uGameTreeCursor
  uDisplayedPosition
  uMoveInteraction
  uPdnText
  uGameTreePdn
  uNotationPresentation
  uGameTreeView
)
for unit_name in "${GENERIC_UNITS[@]}"; do
  unit_file="$ROOT_DIR/$unit_name.pas"
  if rg -n '\buDraughtsBoard\b|\buDraughtsPosition\b|\bTDraughtsBoard\b|\bTDraughtsSide\b|\bNormalizeMoveNotation\b|\bSameMoveIgnoringCaptureOrder\b|\bMoveSquareAt\b|\bExtractMoveSquares\b' "$unit_file"; then
    echo "$unit_name is game-neutral and must use uGamePosition only."
    exit 1
  fi
done
