# Moves-window control comparison

This is a standalone, read-only prototype. It does not replace the application's
moves window, modify application preferences, or write games. It uses the actual
PDN importer, game tree, notation presenter and cursor. There is no second PDN
renderer and no RTF round trip.

The three controls use the same font family and size. Played moves are bold,
branch moves green/italic, PVs blue, and other text gray/italic. Engine and
annotator PVs originally shared the analysis style in the recorded comparison.
The current shared styling code gives engine PVs blue and annotator PVs purple. Move numbers and
punctuation also use the gray fallback style; this is not a final visual design.
TMemo provides the unformatted baseline. RichMemo applies attributes directly to
presenter-derived spans; SynEdit uses a highlighter over the same style map.

## Build and run

Requires Lazarus/LCL, FPC, Python 3, Git and a desktop display. SynEdit is included
with Lazarus. Fetch RichMemo outside the project checkout, at this exact revision:

```sh
git clone https://github.com/skalogryz/richmemo.git /tmp/gwdgui-richmemo-prototype
git -C /tmp/gwdgui-richmemo-prototype checkout 7bc09f8493b50b69ad29c0bb1966f1c804bc2719
python3 tests/run_notation_controls_comparison.py \
  --richmemo /tmp/gwdgui-richmemo-prototype \
  --lazarus /usr/share/lazarus/4.8.0
```

The launcher uses its own Lazarus configuration, generated project and executable
under the temporary output directory. It does not install packages into your IDE.
RichMemo package compilation writes ignored build output in the external dependency
checkout. Existing RichMemo checkouts must match the pin; nothing is reset or fetched
automatically. DejaVu Sans Mono must be installed for matching typography.

Pass `--interactive` to inspect the same window and switch between controls.
Click moves/branches/PVs, use Left/Right to browse and Escape to follow the current
position, or select text and use Ctrl+C. Native mouse/drag/clipboard behaviour can
be examined here; automated checks exercise selection ranges and the shared click/
key handlers, without changing the system clipboard. This prototype shows target
IDs in a status line rather than a second board. It deliberately has no editing,
context menus, engine processes or database integration.

On Windows use native Windows paths, your Lazarus source directory, and
`--widgetset win32`; use the same pinned RichMemo checkout and install the font.
Windows runs are still needed: Linux results do not establish native Windows
correctness or performance. The project is also available as
`tests/notation_controls_compare.lpi`; add SynEdit and RichMemo package links in
your own isolated Lazarus configuration and the repository root to the unit path
if building it manually.

## Correctness checks

Before timing each control, check exact displayed text and all styles, sampled
mainline/variation/PV native selections (including start/middle/end), selected
text, presenter navigation targets, cursor Left/Right and preview wrapping,
Escape, Unicode combining/non-BMP characters, empty/Black-start games and hidden
annotations. The shared document's headless regression checks every Unicode
character boundary and offset conversion, including Windows UTF-16 and CRLF.
An additional root comment exceeds 70,000 characters: compare the entire text,
move ranges after that comment and a full-document selection to detect truncation.
The existing long-game importer reports its warnings; all controls see exactly
the same resulting tree. Compare PDN before/after checks and restore all modified
node data after live-update timing. Production GUI regressions remain separate.

## Timing method

Default: three samples, fixed host area 760×600, font DejaVu Sans Mono 11, visible
GTK2 window. Leave the window alone during measurements. The launcher saves raw
`results.csv` and `build.log` in its output directory (`--output` overrides it).
Each iteration processes events, repaints the control and processes events again.
Milliseconds use GetTickCount64; very small averages have limited resolution.
There are no timing pass/fail thresholds.

- `reload_styled`: five repeated full assignments and style application to the
  same document. TMemo can optimize identical text assignment; this measures the
  actual adapters, not an isolated text-copy primitive.
- `browse`: 30 deterministic selections, jumping by 37 mainline plies and scrolling
  into view. Selection and painting are included; board replay is not.
- `resize_wrap`: ten alternations of the host width between 600 and 760 pixels.
- `live_update`: five alternating engine scores at the middle node, including
  presenter rendering, style-map/index generation, full control refresh and
  restoration of the highlighted middle move. Original node data is restored.
- `cached_refresh`: ten unchanged refreshes using cached text/presenter signature,
  followed by painting/event processing. It avoids text/style assignment.

Controls are tested sequentially in enum order, with a fresh widget per control;
subsequent operations/samples reuse that widget. This intentionally exposes costs
of repeated updates, including any backend tag accumulation. RichMemo's GTK2
SetTextAttributes creates a GTK tag for each span; SynEdit's wrapping plugin is
marked experimental in Lazarus 4.8. Source and exact dependency revisions should
be recorded with result snapshots. These measurements are specific to this
fixture, machine, widgetset, font and implementation; do not infer Windows timings
or performance of every possible RichMemo update strategy from them.
