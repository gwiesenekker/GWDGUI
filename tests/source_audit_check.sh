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
  uAnalysisCoordinator
  uPvSnapshot
  uEngineBase
  uGameMoveHistory
  uGameOrchestrator
  uGameRunnerThread
  uRunningGame
)
# Draughts-only units carry the uDraughts prefix, so one pattern covers them.
DRAUGHTS_PATTERN='\buDraughts\w*|\bTDraughtsBoard\b|\bTDraughtsSide\b|\bNormalizeMoveNotation\b|\bSameMoveIgnoringCaptureOrder\b|\bMoveSquareAt\b|\bExtractMoveSquares\b|\bTEndgameDrawCounter\b|\bTHubEngine\b|\bTDxpEngine\b'
for unit_name in "${GENERIC_UNITS[@]}"; do
  unit_file="$ROOT_DIR/$unit_name.pas"
  unit_text="$(cat "$unit_file")"
  # Known chess replacement point: the actor imports the PDN
  # parser's move tree (TPdnMoveNode) until that type moves to a neutral unit.
  if [[ "$unit_name" == uGameTreeActor ]]; then
    unit_text="$(sed -E 's/\buDraughtsPdn\b//g' <<<"$unit_text")"
  fi
  if rg -n "$DRAUGHTS_PATTERN" <<<"$unit_text"; then
    echo "$unit_name is game-neutral and must use uGamePosition only."
    exit 1
  fi
done

# The Windows unit declares a TCriticalSection record. Where a unit uses both,
# SyncObjs must come after Windows, or TCriticalSection names that record and
# the Windows build fails (Linux builds cannot notice).
python3 - "$ROOT_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bad = []
for path in sorted(root.glob('*.pas')) + sorted(root.glob('tests/*.pas')):
    text = re.sub(r'\{[^$][^}]*\}|//[^\n]*', '', path.read_text(encoding='utf-8', errors='replace'))
    for clause in re.findall(r'\buses\b(.*?);', text, re.S | re.I):
        names = [n.lower() for n in re.findall(r'[A-Za-z_][\w.]*', re.sub(r'\{\$[^}]*\}', ' ', clause))]
        if 'windows' in names and 'syncobjs' in names and names.index('syncobjs') < names.index('windows'):
            bad.append(str(path.relative_to(root)))
if bad:
    print('SyncObjs must follow Windows in the uses clause of: ' + ', '.join(bad))
    sys.exit(1)
PY
