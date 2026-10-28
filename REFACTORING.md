# Main-form refactoring and chess-port inventory

Working plan, 2026-10-26, starting from GWDGUI 3.0 (`9054215`).
Draughts and chess will be separate applications, with no shared-component or
interchangeable-game framework requirement. This work changes structure, not
playing behaviour, file formats, protocols or released version numbers.

## Ownership to preserve

- The game tree owns persistent moves, ordered children, comments, clocks and
  analysis. The actor validates mutations. Controllers must not create another
  persistent move list, board or ply-indexed metadata store.
- The cursor identifies a tree/node; displayed boards are validated projections
  with a revision-scoped cache. A controller may own temporary selection state.
- A running game owns its tree, actor, copied engine setup, retained snapshot and
  runner. It waits for runner termination before freeing those objects.
- The GUI queue owns posted messages. Snapshot messages own their snapshots;
  finished messages identify runners without owning them. Consumers copy data
  before a message is freed. Preserve consumer snapshot coalescing and shutdown ordering.
- Workers publish immutable snapshots; UI decisions and control updates stay on
  the main thread. Keep tree/node/search IDs and cancellation fences intact.

## Porting inventory

“Retain” means a candidate to copy into the independent chess application, not
an obligation to keep source or binaries shared between the applications.

| Area | Current units | Draughts cleanup / chess disposition |
|---|---|---|
| Main window | `uMainForm` | Retain control layout and event wiring where useful; extract decisions and ownership in stages. |
| Setup values | `uGameSetupTypes`, `uGameSetupForm` | Player/setup records are extracted from the LCL form; retain the simple value/ownership contract. |
| Running games and messages | `uRunningGame`, `uGameGuiMessages`, `uThreadMessageQueue` | Classes are extracted mechanically; retain snapshot ownership, engine reservations and lifecycle transitions. |
| Move interaction | `uMoveInteraction`, `uDisplayedPosition`, board event wiring in `uMainForm` | Legal candidates, source/target selection, routing, highlight calculation and replay coordination are extracted. Keep the draughts implementation; replace in chess without assuming a move is uniquely identified by two squares. |
| Tree and cursor | `uGameTree`, `uGameTreeActor`, `uGameTreeBuilder`, `uGameTreeCursor`, `uGameTreeSearchRef` | Retain topology, node identity and actor/search contracts; replace draughts positions, validation and notation in the chess copy. |
| Notation presentation | `uGameTreePdn`, `uNotationPresentation`, memo event wiring in `uMainForm` | PDN format/ranges are preserved with incremental board traversal; the presenter owns text/ranges, signatures, hit targets and highlight selection. Chess needs its own PGN/SAN rendering from the position before each move. |
| Record import/export | `uPdn`, `uGameTreePdn` | Keep GWDGUI PDN compatibility; implement PGN in the chess application. Do not relabel PDN data as PGN. |
| Rules and positions | `uDraughtsBoard`, `uDraughtsDrawRules`, `uGameOrchestrator` | Replace rules, FEN interpretation, move representation and termination logic for chess. Preserve orchestration concepts only after checking game-specific assumptions. |
| Board display/setup | `uBoardControl`, `uPositionSetupForm` | Replace numbered 10×10 squares and piece artwork with chess geometry/pieces; support promotion choice and multi-square move effects. |
| Analysis | `uAnalysisCoordinator`, `uAnalyzerRunnerThread`, `uPvBrowser`, `uPvSnapshot`, form event/runner wiring | Search/request, Auto Play and PV coordination are extracted without LCL. Retain immutable updates, request identities and stale-result protection; replace board/notation/protocol details in chess. |
| Engine protocols | `uHubEngine`, `uDxpEngine`, `uDxpProtocol`, `uEngineRegistry`, `uEngineBase` | Retain transport, process isolation and cancellation lessons; implement UCI separately. Keep Hub/DXP supported in GWDGUI. |
| MCTS | GWD-specific Hub extension and main-form controls | Keep existing GWDGUI behaviour. Omit from the initial chess port unless explicitly requested later. |
| Database | `uGameDatabase`, `uDatabaseImportWorker`, `uDatabaseForm` | Retain transactional import, worker ownership and recovery patterns; replace position keys, notation and schema identification. Chess must not silently open a draughts database. |
| Tournament | `uTournament*` | Retain durable records, identity, scheduling and file preservation; replace result conventions/scoring and game setup in the chess copy. |
| Platform/UI support | `uPlatformProcess`, `uAtomicFile`, socket helpers, preferences, dialogs | Candidates to copy after checking game-specific settings; no shared-library project in this phase. |
| Distribution | build scripts, regression runners, manuals | Keep GWDGUI release/tag unchanged; chess needs independent names, configuration locations, assets and documentation. |

## Sequence and gates

1. Inventory and characterization tests for gaps below.
2. Extract setup value types without changing record layout or engine ownership.
3. Move `TRunningGame` and its snapshot-input records to `uRunningGame`.
   Move queued-message classes to `uGameGuiMessages` in a separate commit.
4. Extract move interaction/display coordination.
5. Extract notation presentation using the existing PDN renderer.
6. Extract analysis coordination while retaining main-thread delivery and runner ownership.
7. Next: reassess session management against the remaining form responsibilities.
   Keep shutdown ordering stable; a new session manager is not an automatic requirement.

Keep the existing GTK end-to-end checks. Add tests below the UI as boundaries
become independent; do not replace integration coverage with controller tests.
Line count and removal of every draughts type from the form are not hard gates.
The gates are explicit ownership, preserved behaviour and independently testable
operations. Each change gets relevant regressions and a local commit. Do not push
or move the published v3.0 tag as part of this work.

## Coverage inventory before extraction

| Boundary | Existing coverage | Characterization to add first |
|---|---|---|
| Capture selection | legal move/capture ambiguity and export checks | Actual board source/target clicks with several legal captures; canonical node/board result. |
| Board orientation | board geometry used by navigation checks | Flip with the real keyboard handler, verify square mapping on all 50 squares and unchanged model/cursor. |
| Auto Play | one-shot analyzer searches and actor/node tests | Actual form start/stop, attachment to the selected historical node, and rejection of a late reply after stop. |
| MCTS | headless runner position switching and shutdown | Actual form open/close and reservation release, reopening and destruction with pending updates. |
| Unsaved standalone replacement | preservation when switching to running games; unexpected-dialog guard | Cancel prevents replacement; declining save permits it; selecting another running game does not discard/prompt for the standalone tree. |
| Running-game ownership | real-runner stopping, edits waiting for completion, illegal/stale commands | Check copied setup ownership and retained snapshot independence before moving the class. |
| Queue ownership | consumer coalescing used by GUI runner-history checks | Count owned snapshot destruction on message disposal, replacement and queue shutdown; finished messages must not free runners. |

## Characterization added

- `tests/main_form_boundaries_check.pas`: actual GTK interaction and fake-engine
  checks for the five form-level gaps above. Existing GUI tests remain unchanged.
- `tests/running_game_lifecycle_check.pas`: copied setup/snapshot/reservation
  ownership and counted queue/snapshot destruction before extraction.
- A duplicate finished notification for an already freed runner is not injected;
  close/reopen and pending-update destruction are exercised through real callbacks.
- The native save-file chooser's Yes path is not automated; Cancel and No exercise
  the replacement prompt, and existing export tests check saved content separately.

## Completed in this stage

- Inventory and pre-extraction characterization checks are committed first.
- `uGameSetupTypes` owns the unchanged player/setup value declarations.
- `uRunningGame` owns the unchanged running-game class, lifecycle and snapshot
  inputs. `uGameGuiMessages` owns the unchanged eight message classes.
- Ownership/lifecycle tests import these units directly and compile with plain
  FPC, without LCL or a display. GTK integration coverage remains in place.
- `uMoveInteraction` owns temporary legal candidate/target selection, move routing
  and board-highlight calculation from the actual displayed move. It does not execute actor commands or runner
  calls. Same-target captures require an explicit choice of standard PDN path;
  cancellation and changes to the displayed position do not play a move.
- `uDisplayedPosition` owns the existing sole tree cursor, temporary PV preview
  and copied replay cache. Trees are borrowed; actor revisions are passed by the
  caller. The outer UI refresh bounds cache lifetime, including nested refreshes.
  Failed previews leave the caller's board unchanged.
- New headless interaction/display tests cover legal targets, route decisions,
  highlight data, nested branch identity/replay, preview failure, cursor fallback,
  copied cache boards, revision changes and nested refresh lifetime. Existing GTK
  interaction/preservation checks continue to exercise real form event wiring.
- `uNotationPresentation` owns rendered PDN text/ranges and label signatures,
  with PDN format/ranges preserved by `uGameTreePdn`. It returns hit targets and
  highlight ranges from a temporary selection description, without owning or
  changing a tree/cursor. Memo updates, focus and navigation commands stay in
  the form. Automatic root highlights clear selection; explicit navigation
  retains the existing selection when no highlight range applies, as before.
- `notation_presentation_check` verifies all 256 display-filter combinations,
  nested branch and analysis-preview ranges, capture captions, label invalidation,
  variation-first hit precedence, caret/selection endpoints and preview isolation.
  GTK tests additionally exercise selection edges and annotation-filter rebuilding
  through real controls, alongside existing branch/keyboard/PV checks.
- `uAnalysisCoordinator` owns ordinary search tracking, analyzer/MCTS restart
  signatures and request preparation. Search start/done/cancel/release and
  snapshot validation/preparation retain the actor boundary and full identities.
  Snapshot delivery/coalescing, actor lookup and UI result application stay in
  the form. Transient previews cannot publish persistent analysis metadata.
- `TAutoPlayCoordinator` owns temporary line accumulation and selected-node/search
  identity. It prepares legal move commands and advances only after actor
  acceptance; official mainline moves remain unchanged.
- `TAnalysisPvState` owns copied analyzer/main PV bases and display-cache state.
  It borrows the existing displayed-position replay cache with actor revisions.
  Request records borrow those boards synchronously; runner posting copies them.
- Headless analysis checks cover cancelled/completed/foreign search identities,
  queued releases, cross-game replacement, transient/terminal request policy,
  snapshot preparation, PV copy/fallback/cache behaviour and Auto Play rejection,
  reset and historical-node preservation. GTK frozen-PV and real analysis-control
  checks remain in the sweep.
- `uMainForm` is reduced from 7,652 to 5,871 lines. Session management, engine/menu
  ownership and shutdown remain in the form. Control updates,
  actor/runner dispatch, analysis cancellation and shutdown stay there during
  these extractions. The published v3.0 tag stays at the release commit.

## Profiling follow-up completed

- Legal-move comparisons use ordinal normalized text (F12).
- Notation and tree captions advance a board per line, copying at forks (F10).
  Frozen text/range fixtures and work counters protect compatibility and scaling.
- The Game Tree window defaults to notation columns, offers the original nested
  layout, marks variations and retains expansion/selection for the same tree.
- Node IDs resolve through a non-owning hash index. Removal batches invalidate
  it once; the next lookup rebuilds it from survivors without changing IDs. Batch PDN import validates
  each visited move once inside the actor while preserving subtree warnings,
  canonical moves and metadata (F11). Index lifecycle tests cover stale pointers.
- Headless measurements on Claude's long-game fixture: 100 notation renders
  12.45 s to 0.54 s; ten imports 4.57 s to 0.28 s. These compare the affected
  operations, not desktop end-to-end latency. No published release is changed.

## Queue-delivery follow-up

- Coalescing belongs to `GuiEventTimerTick`, not `TThreadMessageQueue`. The
  consumer retains the latest snapshot per game/search and flushes before other
  messages and at tick boundaries. Every popped message counts toward the
  100-event timer budget; shutdown drains all pending messages.
- `gui_delivery_check` feeds the actual consumer real-runner snapshots and checks
  full/live history, independent games/searches, completion barriers, exact payload
  destruction, cancellation, removal and form shutdown. The boundary check also
  verifies that foreign finished notifications preserve active analyzer/MCTS
  runners, searches and engine reservations. Shutdown ownership/order is unchanged.

## Reproducible performance baseline

- `bash tests/run_performance_checks.sh` builds with fixed `-B -O2` settings and
  uses a tracked copy of the long-game fixture. It measures replay, notation
  rendering and actor import without a GUI or external engine, reports revision,
  compiler/host, counts, recovery warnings and output fingerprints, and checks
  output stability between iterations/samples.
- See `tests/PERFORMANCE.md` for the baseline and comparison method. Timing is
  opt-in and has no noisy wall-clock threshold in the regression sweep. These
  measurements do not replace end-to-end GUI profiling.
- The pre-chess cleanup now has explicit capture choices, tested consumer message
  delivery and a reproducible draughts baseline. Further reduction of form line
  count or a new session manager is not a prerequisite for the separate chess app.

## Review follow-up at 57647e7

- Completion delivery now belongs to the runners' termination hooks, which also
  run when an immediate stop prevents Execute from starting. Cancellation tokens,
  engine interruption and session shutdown ownership remain unchanged.
- Parsed PDN normalization advances a board along each line and saves only fork
  positions. Conflicting merged metadata generates named warnings in GUI/import
  diagnostics and database logs; first-value conflict policy is unchanged.
- Highlight data comes from the actual validated displayed move, including branch
  and preview positions. The manual and source-archive checks match current behavior.
- Node-index removal work is bounded by one invalidation and one subsequent rebuild;
  the regression checks 20,000 removed IDs and preserves surviving identities.

## Game-position boundary (steps 1-8 done)

Design and rationale: `claude/position-interface-proposal.md`. Generic units reach
the game only through `uGamePosition` (`TGamePosition`, `TGameVariant`); moves are
canonical strings that only the game parses or compares. Draughts is the only
implementation (`uDraughtsPosition`, an adapter over `TDraughtsBoard`) until every
generic unit is converted; behaviour, formats and performance stay unchanged.

| Step | Scope | Status |
|---|---|---|
| 1 | `uGamePosition`, `uDraughtsPosition`, `position_contract_check` (perft, FEN, notation, `SameMove`, choosers, trusted replay) | Done |
| 2 | Source audit: listed generic units must not use the draughts board or parse move text | Done |
| 3 | Variant into tree/actor/builder/cursor; `SameMove` replaces text comparison | Done |
| 4 | Displayed position and move interaction (`MoveSquares`, `MovesBetween`) | Done |
| 5 | Notation walker and presentation (`MoveNotation`) | Done |
| 6 | Analysis coordination and PV state | Done |
| 7 | `TGameRules`; orchestrator, runner and running game | Done |
| 8 | Remaining main-form uses; list the chess replacement points | Done |

Each step is one local commit with all suites and the performance baseline passing.

Additions to the proposal, made in step 3:
- `TGamePosition.PlayMoveText`: validated play of any accepted spelling that
  returns the canonical move. The actor and tree replay use it, so import warnings
  keep the game's exact messages (`Illegal move: 50-1`).
- `TGameVariant.SameMove`: move equality without a position, for the tree's
  child lookup and mainline comparisons.
- `RegisterDefaultGameVariant`/`DefaultGameVariant`: a game unit registers itself
  when linked, and `TGameTree.Create` without a variant uses it. Every program
  (`gwdgui.lpr`, each test) names `uDraughtsPosition` explicitly; a program
  without a game fails with a clear error instead of picking one implicitly.

Known transitive dependencies after step 3 (the audit checks unit text, not the
dependency graph): `uGameTree` still uses `uGameOrchestrator` (game-state and
time-control types) and, in its implementation, `uPdn` (PDN comment helpers).
Both use the draughts board. Step 5 (notation) and step 7 (rules/orchestrator)
remove these; until then `TryBuildDraughtsBoardAtNode` in `uDraughtsPosition`
serves the units not yet converted.

Step 4 notes:
- `uDisplayedPosition` caches and returns `TGamePosition`s (`TryBuildNodePosition`,
  `TryBuildPosition`); preview moves are validated with `PlayMoveText`.
- `uMoveInteraction` takes candidates from `MovesFrom` and targets from
  `MoveSquares`, routes with `TryParseMove` (canonical moves), and computes
  highlights through the new `TGameVariant.MoveSquares`: PV hints lie several
  plies away from any built position. It returns 0, 0 when move text alone does
  not determine the squares; for a legal move it agrees with the position (checked
  by the contract test). `MoveSquareAt` moved to `uDraughtsPosition`.
- The form and the analysis coordinator still hold `TDraughtsBoard`s. They use
  `TryBuildDraughtsNodeBoard`/`TryBuildDraughtsDisplayedBoard`; the form passes a
  reused scratch position, because creating one per call (start position plus
  legal moves) made a human move about 15% slower in the GUI harness.
- The highlight's last move still comes from the draughts board's move history
  in `UpdateBoardHighlights`; step 8 takes it from the displayed node instead.

Step 5 notes:
- The board-free PDN text helpers (comment escaping, analysis annotations, result
  normalization) moved from `uPdn` to the new `uPdnText`. `uGameTree` uses that
  instead of `uPdn`, which removes one of the transitive dependencies above; the
  orchestrator dependency remains for step 7.
- `uGameTreePdn` (export, notation walker, move captions) replays with
  `TGamePosition` from the tree's variant: `CreatePositionFromFEN`, `Clone` per
  variation, `PlayMoveText`, and `MoveNotation` in the position before the move.
  Invalid legacy moves still end the replay for that line and keep the raw text.
- New `TGameVariant.NormalizeMove` for analysis text that is compared or stored
  without replay (the first PV move in compact annotations, annotator
  alternatives). The contract test checks that canonical moves are unchanged and
  that a normalized spelling is the same move.
- `GameTreeHasContent` and the `[SetUp "1"]` tag compare the start position with
  the tree variant's default instead of the draughts constant.
- The source audit covers `uPdnText`, `uGameTreePdn`, `uNotationPresentation` and
  `uGameTreeView`; `game_tree_variant_check` renders a counter-game tree.
- `TDraughtsPosition.MoveNotation` returns quiet moves without generating legal
  moves, as the walker did before.

Step 6 notes:
- `uAnalysisCoordinator` and `uPvSnapshot` hold `TGamePosition`s and are in the
  source audit. PV bases replay straight into the coordinator's own positions
  (previously a temporary draughts position per replay). Each base remembers its
  game; a tree of another game replaces it before replaying (`BuildNodeBase`).
- A snapshot's base position is `nil` until one is set (it was a start-position
  board); `CanDisplayTransientAnalysis` and the PV browser treat `nil` as "no
  base". New `AssignGamePosition` copies a position into a holder of unknown class.
- The annotator runner (`uAnalyzerRunnerThread`) copies request positions with
  `Clone`; a request without a base clears the runner's base.
- The PV browser stays per-game: it takes game positions and shows draughts ones
  on its mini board. The game runner keeps its orchestrator board until step 7 and
  feeds snapshots through `TDraughtsPosition.AssignBoard`.
- `TAnalysisPvState.SetCache` takes a position key; the form computes it as before.
- `UpdateDisplayedPvCacheFromTree` compared an empty key when no PV was visible
  but stored the base position's key, so with no PV every running-game snapshot
  reported a PV change. Fixed in the commit after step 6:
  `TAnalysisPvState.UpdateCache` compares and stores the same key.

Step 7 notes:
- `TGameRules` (`uGamePosition`): `Reset`, `MovePlayed(ABefore, AMove, AAfter)`,
  `Outcome`. `TDraughtsRules` (`uDraughtsPosition`) holds what the orchestrator did
  before: no legal move loses, the FMJD 16/5-move endgame limits
  (`uDraughtsDrawRules`), threefold repetition and the 25-move rule, in the same
  order and with the same log texts. `TGameVariant` gained `CreateRules` and
  `ResultText` (draughts `2-0`/`0-2`/`1-1`); loss on time stays in the orchestrator.
- `uGameOrchestrator`, `uGameRunnerThread`, `uRunningGame`, `uGameMoveHistory` and
  `uEngineBase` are game-neutral and in the source audit. The orchestrator and the
  runner take an optional variant (default: the registered game). The runner
  snapshot carries a `Position` instead of a draughts board.
- Engines: `TDraughtsEngine` in `uEngineBase` became `TGameEngine` (shared
  infrastructure; virtual `LaunchAndInit`, `ProtocolName`, `NormalizeMoveText`).
  The new `uDraughtsEngine.TDraughtsEngine` is the base of the Hub and DXP engines
  and normalizes draughts move text as before. Engine units register a factory per
  engine kind (`RegisterGameEngineFactory`); the runner creates engines with
  `CreateGameEngine`. Programs that run engine games link `uHubEngine` and
  `uDxpEngine` (`gwdgui.lpr` names them next to `uDraughtsPosition`).
- `TGameMoveHistory` stores the canonical moves it is given; the orchestrator
  validates them with `TryParseMove` first.
- The orchestrator's position now records its move history (as tree replays do);
  it plays validated moves with `PlayTrustedMove`. An orchestrator replay benchmark
  (300 random games, 81,870 moves, identical results) costs about 8% more per move
  (about 33 µs instead of 30 µs), which is negligible next to engine searches.
- With step 7, `uGameTree`'s dependency on `uGameOrchestrator` is game-neutral too.

Step 8 notes:
- The main form builds displayed positions as game positions everywhere except
  for its board controls: legal moves list and clicks, FEN copy, board highlights,
  loading a FEN or PDN game, starting a game, score-history side, variation input
  and snapshot comparison. Short queries reuse one position of the tree's game
  (`PositionScratch`).
- The last-move highlight comes from the displayed position
  (`TDisplayedPosition.TryBuildPosition(..., out ALastMove)`: the node's move, or
  the canonical last preview move) instead of the draughts board's move history.
- `TScoreHistoryControl`/`TScoreHistoryForm` take a `TGameSide`.
- GUI harness (8 interleaved runs): load, browse, jump and human moves within the
  run-to-run spread.

### Chess replacement points

What still names draughts after step 8. Since the rename after step 8, every
draughts-only unit carries the `uDraughts` prefix (`uDraughtsBoardControl`,
`uDraughtsPositionSetupForm`, `uDraughtsPdn`, `uDraughtsHubEngine`,
`uDraughtsDxpEngine`, `uDraughtsDxpProtocol`, `uDraughtsDxpTestConnection`), and
the source audit rejects any `uDraughts*` unit in a generic unit. The one
exception is `uGameTreeActor`'s use of `uDraughtsPdn` (record move tree, below). Units outside the source audit's list are
per game by design (proposal, section 4); a chess build supplies its own version or
a per-game strategy. Counts are of code references at step 8.

| Area | Where | What a chess port replaces |
|---|---|---|
| Rules, moves, notation | `uDraughtsBoard`, `uDraughtsDrawRules`, `uDraughtsPosition` (`TDraughtsPosition`, `TDraughtsVariant`, `TDraughtsRules`) | `uChessPosition`: position, variant (FEN, SAN, result texts), rules (mate, stalemate, 50 moves, repetition, material) |
| Program wiring | `gwdgui.lpr` links `uDraughtsPosition`, `uDraughtsHubEngine`, `uDraughtsDxpEngine` | Link the chess game and engine units instead |
| Main form, board controls | `uMainForm`: 5 `TDraughtsBoard`s with their `TDraughtsBoardControl`s (main board, PV and annotator mini boards, two pop-outs), `TryBuildDisplayedBoard` with `FDraughtsScratch` (draughts helper `TryBuildDraughtsDisplayedBoard`), `ApplyBoardTheme`; 12 `TDraughtsBoard` and 12 `TDraughtsBoardControl` references | A chess board control behind the same events (square clicked, targets, highlights); the form keeps one control-facing helper per game |
| Main form, other | `FPositionSetupForm` (`TPositionSetupForm`); window caption "International Polish Draughts" (2 places) | Chess setup form; caption from the variant name |
| PV view | `uPvBrowser` (mini board, move numbering from the FEN's side letter) | Chess PV browser or a game-neutral one over a chess board control |
| Board widgets | `uDraughtsBoardControl`, `uDraughtsPositionSetupForm` | Chess board control and setup form |
| Engines | `uDraughtsEngine`, `uDraughtsHubEngine`, `uDraughtsDxpEngine`, `uDraughtsDxpProtocol`; `uAnalyzerRunnerThread` creates `THubEngine` directly (annotator, MCTS); `uEngineRegistry` kinds `eekHub`/`eekDxp`; `uEnginesDialog`, `uEngineEditForm` (Hub/DXP fields) | UCI engine unit registered through `RegisterGameEngineFactory`; the annotator runner should use `CreateGameEngine`; a UCI engine kind and its settings |
| Game records | `uDraughtsPdn` (PDN reader/writer, `TPdnMoveNode`), the PDN-syntax part of `uGameTreePdn` (tags, `PdnExportResult`), `uPdnText` (2-0/1-1/0-2 result normalization), `uPdnOpenDialog` | PGN reader/writer reusing the line walker; `uGameTreeActor` imports `TPdnMoveNode` (move this record-tree type to a neutral unit); `uScoreHistoryControl` and `uTournamentGameRecord` use `uDraughtsPdn` |
| Database | `uGameDatabase` (draughts board replay, `TDraughtsSide` in position search), `uDatabaseForm` (board control) | Replay and position keys through `TGamePosition`; side through `TGameSide`; chess board control |
| Tournaments | `uTournamentResults`, `uTournamentDialog`, `uTournamentGridModel` (2-0/1-1/0-2 scoring and menus), `uTournamentStorage`/`uTournamentGameRecord` (PDN) | A per-game scoring strategy (1-0/½-½/0-1) and the record format |
- `uAnalysisCoordinator` still uses `uGameOrchestrator` for `TGameOrchestratorState`
  (step 7).

