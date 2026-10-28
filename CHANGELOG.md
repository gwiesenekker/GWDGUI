# Changelog

Notable changes, newest first, reconstructed from the Git commit history and
release-tag snapshots. Dates are those of the tagged commits. Individual fixes
and implementation details are available in the [commit history](https://github.com/gwiesenekker/GWDGUI/commits/main/).

## Unreleased

## [3.4](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.4) — 2026-10-28

Changes since [3.3](https://github.com/gwiesenekker/GWDGUI/compare/v3.3...v3.4).

### Added

- A formatted offline manual with a contents tree, styled headings, lists, tables
  and code examples. Search works across wrapped words and table cells.
- `build.bat` for Windows, including Lazarus discovery, embedded manual/build
  identity, candidate builds and recovery after an interrupted replacement.
- A game-neutral position, variant and rules boundary for the tree, move
  interaction, notation, analysis and game running, with an independent counter
  game used to test it. This prepares future game implementations while retaining
  the draughts application.
- Game-specific timeout outcomes and starting move-number metadata, with tests
  for both starting sides and positions beginning at move 37.
- Windows cross-build checks and Wine batch recovery checks; the batch checks run
  even when Windows compiler units are unavailable.

### Documentation and downloads

- Recreate README and the release-based changelog from the commit history.
- Keep historical refactoring and review notes local instead of publishing them.
- Supply Linux and Windows x86_64 executables and portable archives, with the
  current manual, draughts font and SHA256 checksums. The Windows executable is
  supplied by the maintainer and reports its build commit as unavailable.

### Fixed

- Restore compatibility with the SynEdit highlighter API in Lazarus 3.0.
- Prevent a column error when clicking beyond the end of a line in the moves view.
- Keep a variant's starting side consistent after tree construction and clearing.
- Avoid unnecessary PV-view refreshes when no PV is displayed.
- Restore Windows compilation where unit ordering selected the wrong critical
  section type, and ensure the Windows mode runs its build-info pre-build step.
- Show engine launch failures in dialogs, including guidance for executable paths
  copied from another operating system; mark missing engines in the engine list.
- Use the default font quality for notation and manual text on Windows.
- Preserve manual search selection and feedback after resizing, find split
  identifiers, and highlight complete matches spanning wrapped table cells.

## [3.3](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.3) — 2026-10-27

- Replace the moves memo with a styled, wrapped SynEdit view while retaining
  navigation, selection, copying and saved game content.
- Add a separate Notation preferences tab with colours, bold and italic styles
  for moves, variations, comments and analysis.
- Give engine, annotator and Auto Play PVs independent styles, and add a common
  notation font chooser with saved preferences and platform defaults.
- Preserve explicit PV source information, including when displayed PVs are identical.
- Embed the manual and Git identity in the Windows Lazarus build mode using a
  native generator; fix the Windows write-through constant for FPC 3.2.2.
- Add notation-control comparisons, Unicode/large-text checks and styling regressions.

## [3.2](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.2) — 2026-10-27

- Add **Do not show hints** alongside main-PV and annotator-PV hint options.
- Highlight both source and destination squares for hinted moves and replies.
- Display engine/annotator analysis after the actual move played from its source
  position. Retain the original analysis ownership, replay position and PDN content.

## [3.1](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.1) — 2026-10-26

- Add menu shortcuts, **File → Quit**, a searchable offline manual and
  **About GWDGUI** with the build commit.
- Present game trees as notation with stable selection and expansion; add an
  explicit chooser for captures sharing a source/destination pair.
- Highlight the last move of the displayed position, including branches and previews.
- Preserve literal comments and typed metadata through PDN round trips; merge
  equivalent capture variations and warn about conflicting imported metadata.
- Fix runner completion when stopped before execution and ignore stale runner
  callbacks; bound queued snapshots.
- Publish up-to-date Hub analysis before stdout-driven refreshes, apply DXP peer
  restrictions consistently, validate Hub parameters and read complete monitor output.
- Reduce repeated work in tree imports, notation rendering, normalization and
  node removal; add reproducible performance checks.
- Separate running-game ownership, queued messages, move interaction, displayed
  positions, notation presentation and analysis coordination from the main form.

## [3.0](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.0) — 2026-10-26

- Consolidate the game tree around parent/child nodes, a node cursor and node-owned
  comments, analysis and clocks; preserve nested variations and standalone games.
- Validate moves and board replay, preserve all kings in FEN, reject malformed
  positions and support standard PDN capture paths.
- Correct PDN variation positioning, game boundaries and result handling; retain
  comments and metadata and skip malformed branches without discarding valid games.
- Preserve complete games in the database, improve duplicate identities and Unicode
  filters, recover summaries/indexes after interrupted imports and import on a worker.
- Make tournament saves recoverable and protect existing files against accidental
  overwrites; preserve results, identities and manual corrections across reloads.
- Improve round-robin colour balance and Swiss pairing, including repeat avoidance
  and polynomial-time matching.
- Fix stale Hub replies, DXP disconnect handling and capture-order comparisons;
  align engine deadlines and protocol time controls with game clocks.
- Improve cancellation, thread ownership, process-pipe isolation and output bounds;
  protect frozen PV state and report replay failures instead of showing stale boards.
- Include the user manual and extensive rules, file-preservation, database, engine,
  tournament and GUI regression coverage; keep runtime settings and generated files local.
- Reconcile the local and GitHub histories. This release was initially prepared
  as 2.23 and renamed to 3.0; 2.23 is not a separate retained release tag.

## [2.22](https://github.com/gwiesenekker/GWDGUI/tree/v2.22) — 2026-08-23

- Avoid running Linux `xrandr` monitor detection on Windows when placing dialogs.

## [2.21](https://github.com/gwiesenekker/GWDGUI/tree/v2.21) — 2026-08-23

- Fix ownership of analyzer commands rejected by a closed queue, preventing a
  second attempt to free an already disposed command.

## [2.2](https://github.com/gwiesenekker/GWDGUI/tree/v2.2) — 2026-08-23

- Introduce the game tree, actor command path, tree export and tree-based display
  coordination for games, annotations, variations and analysis searches.
- Expand PDN variation handling, database position search and engine configuration.
- Add browsable analysis PVs, Auto Play and updated game controls.
- Improve analyzer threading, score history and DXP handling.

## [2.1](https://github.com/gwiesenekker/GWDGUI/tree/v2.1) — 2026-06-11

- Expand database filters, sorting, row limits and position-search feedback.
- Improve PDN import and engine configuration, including INI/config-file editing.
- Refine engine launch and DXP handling.

## [2.0](https://github.com/gwiesenekker/GWDGUI/tree/v2.0) — 2026-06-10

- Introduce the reorganized GWDGUI project with dedicated game-running, analysis,
  engine, database and presentation units.
- Add SQLite game storage, PDN import, database searching and GUI preferences.
- Expand position setup, FEN tools, score-history presentation and PV browsing;
  improve multi-monitor dialog placement and Windows process output handling.

## [1.7](https://github.com/gwiesenekker/GWDGUI/tree/v1.7) — 2026-06-03

- Extract board, clock, notation, engine, game-history and tournament components
  from the original main form.
- Introduce dedicated engine registration, Hub/DXP protocol and process helpers.

## [1.6](https://github.com/gwiesenekker/GWDGUI/tree/v1.6) — 2026-06-01

- Expand tournament setup, pairing, results and saved tournament files.
- Extend played-game history, analysis-board and score-history presentation.
- Improve engine configuration and INI parameter handling.

## [1.5](https://github.com/gwiesenekker/GWDGUI/tree/v1.5) — 2026-05-30

- Expand analysis controls, MCTS-related engine settings and score-perspective options.
- Add evaluation-bar presentation and improve incremental board repainting.

## [1.4](https://github.com/gwiesenekker/GWDGUI/tree/v1.4) — 2026-05-29

- Refine game-clock activation and elapsed-time handling.
- Add ponder-information settings and safeguards around opening/closing two engines.

## [1.3](https://github.com/gwiesenekker/GWDGUI/tree/v1.3) — 2026-05-29

- Expand Hub launch arguments and position/capture-format compatibility settings.
- Improve engine lifecycle controls and terminal-result handling.

## [1.2](https://github.com/gwiesenekker/GWDGUI/tree/v1.2) — 2026-05-28

- Expand the two-engine interface, game controls and clocks.
- Add clipboard position handling and clearer engine/side-to-move feedback.

## [1.1](https://github.com/gwiesenekker/GWDGUI/tree/v1.1) — 2026-05-27

- Add unsaved-game confirmation and improve shutdown/save handling.
- Refine engine parameters, PDN saving and position setup dialogs.

## [1.0](https://github.com/gwiesenekker/GWDGUI/tree/1.0) — 2026-05-27

- Initial Lazarus international-draughts GUI, with a draughts board, Hub engine
  integration, engine parameters and position/game controls.
