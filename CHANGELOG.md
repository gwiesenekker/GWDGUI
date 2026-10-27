# Change history

Entries are newest first. Review IDs refer to the code reviews of commits
`98da11d` and `8ad88b5`; they identify individual fixes, not release versions.

### 2026-10-27 — Windows Lazarus build identity

- Add a Windows build mode that embeds the current Git commit, revision, tracked
  changes marker and searchable manual, using Lazarus’s compiler without Python.
- Regenerate build data before compilation; stop on generator failures. Report
  missing Git/source-archive identity explicitly, without borrowing a parent repo.
- Compare the native generator against the existing Linux generator using real
  clean/dirty repositories, Unicode paths/text, archives, absent Git, empty manuals
  and compiled About/manual output. Document Windows build instructions.
- Full headless/source-audit/archive checks and an isolated Linux GTK2 build pass.
  Native Windows IDE execution remains to be checked in the Windows VM.

### 2026-10-27 — Windows compiler compatibility

- Use the documented Win32 write-through flag value: FPC 3.2.2 omits its
  symbolic name. Keep atomic publication and replacement behavior unchanged.
- Existing atomic-file regressions pass on Linux; native Windows validation
  remains necessary.

## Version 3.2 — 2026-10-27

This release improves hint controls and analysis presentation since v3.1.

- Add **Do not show hints** alongside the main/annotator PV radio options.
- Outline both source and destination for the first PV move and its reply,
  retaining the existing colors and independent last-move marker.
- Show engine/annotator analysis (full PV or first move) after the actual move
  played from its source position. Keep analysis without a played continuation
  at the tip, or at the root of an empty game.
- Keep the game tree, analysis ownership, preview bases and saved PDN content
  unchanged; expand headless and actual GTK navigation/painting regressions.
- Update the manual and publish a freshly built Linux x86_64 executable, portable
  bundle and SHA256SUMS. No Windows executable is included.

The dated entries below describe development work before publication.

### 2026-10-27 — Show analysis after the played move

- Present engine, annotator and Auto Play PVs (or first-move-only projections)
  after the actual move played from their position. Show tip/root analysis without
  a played continuation at the end, once per source position.
- Keep analysis node ownership and preview base plies unchanged; PDN file exports
  retain their previous content and metadata.
- Add white/Black-start, empty/short games, all source filter combinations and
  relocated prefix/move hit tests. The ordering test fails against the old layout;
  the file-export fingerprint is identical before and after the change.
- Add actual GTK memo clicks for engine/annotator full PVs and first moves,
  verifying source-board replay, separate played-move selection and unchanged export.
- Full headless/source-audit/archive, GTK and default performance checks pass;
  update the manual and test inventory. Nothing pushed or released.

### 2026-10-27 — Outline both ends of PV hint moves

- Highlight the source and destination of the first PV move and its reply, for
  both main and annotator PVs, using the existing PV/hint colors for each pair.
- Clear target hints along with source hints when disabled, empty or unrelated
  to the displayed position; keep the last-move marker independent.
- Cover quiet moves, captures, single/empty/mismatched PVs, all menu modes and
  actual painted outlines (including flipped boards) through headless and GTK
  regression tests. Full headless/source-audit/archive and GTK suites pass.

### 2026-10-27 — Allow disabling PV hints

- Add Do not show hints as a third board-menu radio option alongside main and
  annotator PV. Keep main PV as the default and preserve last-move/click markers.
- Test all three choices through the actual GUI, immediate clearing, repeated
  selection, refresh, re-enabling and unchanged game/position data.
- Document the three modes in the manual; keep the published 3.1 release unchanged.

## Version 3.1 — 2026-10-26

This release includes the accumulated improvements below since v3.0.

- Extract running-game ownership, queued messages, move interaction, displayed
  positions, notation presentation and analysis coordination from the main form.
- Present the game tree as notation with stable selection and expansion; offer
  explicit choices for ambiguous captures and preserve the displayed move marker.
- Add menu shortcuts, File → Quit, a searchable offline manual and About with
  the exact build commit. Update the manual for current behavior and settings.
- Preserve PDN comments and metadata, normalize equivalent capture variations,
  report conflicting metadata and improve database duplicate identities.
- Fix early-stop completion, stale live PVs, DXP connection-test peer restrictions,
  Hub parameter save validation and truncated monitor-query output.
- Improve actor import, notation rendering, normalization and branch-removal costs;
  add reproducible benchmarks, lifecycle and GUI delivery regressions.
- Publish a Linux x86_64 executable and portable bundle with SHA256SUMS. No Windows
  executable is included; native Windows validation remains outstanding.

The dated entries below record development changes and validation before publication.

### 2026-10-26 — Complete validation of the latest review pass

- Headless/source-audit/archive, GTK preservation/boundary/delivery/Help, lifecycle,
  real TCP DXP, tournament and default performance checks pass; application builds.
- Record A8's existing protection, measured F8 costs, four correctness fixes and
  remaining scope in REVIEW_NOTES. Native Windows execution remains unverified.
- All changes are local commits; nothing pushed or released.

### 2026-10-26 — Publish the current PV with stdout enabled (M7)

- Parse a complete Hub output chunk before notifying stdout log observers, so a
  throttled live snapshot contains the new analysis instead of the previous line.
- Regress a single info line followed by silence with Show stdout both off and on;
  the PV/score/depth must arrive before the move. The enabled case fails before
  the fix and both modes pass afterwards.

### 2026-10-26 — Read complete monitor-query output (U7)

- Drain auxiliary stdout while its process runs and after it exits, instead of
  treating the currently available pipe size as the complete xrandr output.
- Add a real child-process regression with delayed chunks, more than a pipe buffer
  of output and the laptop-panel line last; verify complete output and exit status.

### 2026-10-26 — Apply DXP peer restrictions to connection tests (D19)

- Pass gui-dxp-peer-ip through the engine editor to its registration listener,
  using the same address/peer rules as live games; report rejected peers.
- Keep host configuration immutable while Stop can read it; normalize a local
  binding address instead of rewriting the shared string from the worker.
- Add real TCP matching/rejected-peer checks alongside repeated immediate stops.
  Update the manual to reflect the shared restriction.

### 2026-10-26 — Reject invalid Hub parameters before saving (D20)

- Validate transmitted Hub parameter names/values before accepting the editor or
  writing its parameter file. Name the invalid parameter and keep the editor open.
- Preserve existing files on validation failure; allow quotes in GUI-only launch
  arguments and line breaks in initialization commands, and retain DXP behavior.
- Add save-preservation/grammar regressions and an actual GTK editor rejection check.

### 2026-10-26 — Separate fresh and duplicate import measurements (F8)

- Add a real SQLite import benchmark with fresh/duplicate and logging on/off cases;
  assert insert/duplicate/error counts and retained rows, with a small regression run.
- On this host, 100 long games took 2339/2358 ms for fresh import (logging off/on),
  and 1556/3002 ms for duplicate import. These are local measurements, not thresholds.
- Confirm storage already skips writer replay; duplicate logs and legacy comparisons
  still request public PDN rendering. Keep its standard capture notation intact.

### 2026-10-26 — Verify analyzer disposal during completion (A8)

- Document the existing explicit thread join before analyzer resources are freed.
- Add a blocked-completion regression: disposal must wait for the callback to
  return, including when Execute was skipped by an immediate shutdown.
- Validation: early-stop/racing-stop and blocked-completion checks pass on Linux.
  Native Windows execution remains a release check; no runtime change was needed.

### 2026-10-26 — Rebuild the node index once after removal batches (F13)

- Empty the non-owning index once before freeing nodes and rebuild it lazily
  from survivors on the next lookup. New nodes added while invalidated are
  included; normal insertions/lookups remain incremental.
- Avoid per-node hash-list deletion/rehashing during branch clearing and takebacks.
- Add a 20,000-node removal regression and rebuild-work assertions covering
  surviving/stale IDs, insertion before lookup, bulk takeback and clear/ID reuse.
- Validation: full headless/source-audit, GTK, real DXP, tournament and default
  benchmark checks plus the application build pass. Nothing pushed.

### 2026-10-26 — Bring the user manual in line with current behavior (C9)

- Correct selected-ply evaluation-bar precedence and tournament engine identities.
- Explain game termination/draw limits, startup and DXP settings/limitations,
  metadata/result compatibility, duplicate detection, database upgrades/import
  cancellation, FEN paste, mini-board pop-outs and Clear pairing.
- Lead with Getting started; collect keyboard/Help references at the end. Summarize
  tournament saving first and retain preservation/recovery details separately.
- Distinguish inactive compatibility settings and consolidate portable/recovery
  file locations. Validate the regenerated searchable manual with GTK Help checks.

### 2026-10-26 — Support Git-less archive checks (C8)

- Accept explicit source-archive identity in Help checks. Benchmarks report
  unavailable revision/unknown worktree without Git errors or false modification.
- Refuse to borrow commit identity from an enclosing unrelated repository.
- Add real Git-less benchmark execution and nested-archive build-data coverage.
- Validation: compiled build-data tests, actual archive benchmark and an actual
  Git-less GTK Help/menu build all pass.

### 2026-10-26 — Report metadata discarded by equivalent-move merges (P27)

- Retain first conflicting values and independent metadata as before, but record
  import warnings naming the move, ply and conflicting analysis/clock/time fields.
- Carry conflict diagnostics through descendant merges and clones; cached builds
  and later validation do not duplicate warnings. Include late normalization
  warnings in the database import log before duplicate detection.
- Add conflict/independent-field, repeated-build and actual database-log regressions.
  Variation identity and comment-preservation checks pass.

### 2026-10-26 — Highlight the move actually displayed (U9)

- Calculate the last-move target from the validated displayed position's history,
  including variations and temporary previews, rather than its mainline ply.
- Keep PV hint matching separate; remove the mainline-only input from the helper.
- Add headless variation/capture checks and GTK assertions for nested Black-start
  branches whose destinations differ from the replaced mainline moves.
- Validation: move-interaction and GTK preservation/boundary/delivery/help checks pass.

### 2026-10-26 — Reuse normalization boards along PDN lines (F8)

- Advance one board along each parsed line and preserve positions only at forks.
  Add independent board-copy construction without unused starting-move generation.
- Test copy ownership/history/capture paths and nested sibling restoration through
  repeated export/import, retaining malformed-subtree recovery and capture identity.
- Add canonical PDN storage to the reproducible benchmark. Same-session median
  for ten parse/storage operations: 172 → 122 ms, with identical complete output.
- Validation: board, variation identity, PDN tree and database recovery checks pass.

### 2026-10-26 — Always deliver early runner completion (M8)

- Publish game/analyzer completion from the thread termination hook, including
  when an immediate stop causes the runtime to skip Execute. Keep cancellation
  tokens, engine interruption and shutdown ownership unchanged.
- Add repeated deterministic pre-start stops and start/stop races, checking one
  worker-thread notification, actual termination and no duplicate on disposal.
- Validation: early-stop, analyzer shutdown, running-game lifecycle and GTK
  lifecycle/preservation/delivery/help checks pass.

### 2026-10-26 — Add searchable offline Help and commit identification

- Add Help → Manual (F1) with a read-only offline manual, case-insensitive Find,
  result counts, Next/Previous with wraparound, Ctrl+F, F3/Shift+F3 and Escape.
- Add Help → About GWDGUI (Shift+F1), showing the full commit captured at build
  time and whether tracked files had uncommitted changes.
- Embed MANUAL.md and build identity in isolated application/test builds and
  rebuild project units to prevent stale metadata. Direct IDE and Git-less source
  builds report unavailable identity explicitly; direct IDE builds can read a
  manual beside the executable. Generated files stay outside the source tree.
- Update the manual for Help, all menu shortcuts, Quit and build identification.
- Add actual GTK help/menu/search tests and compiled build-data regressions for
  Unicode, quoting, exact text, clean/modified Git, archives and IDE fallback.
- Validation: full headless/source-audit and GTK suites, generated-data checks,
  and application build pass. Nothing pushed.

### 2026-10-26 — Add menu accelerators and File → Quit

- Add File/Database mnemonics and shortcuts for PDN open/save, preferences,
  database create/open and Quit. Quit uses the existing close/save/shutdown path.
- Document the shortcuts; add GTK menu checks for bindings and cancellation of
  quitting an unsaved game, followed by normal close after declining save.
- Validation: GTK menu/close regression passes. Nothing pushed.

### 2026-10-26 — Record a reproducible draughts performance baseline

- Track the long-game profiling fixture and an opt-in headless harness for board
  replay, notation rendering and validated actor import. Build in isolated
  temporary storage with fixed compiler settings; report revision, host, counts,
  warnings, output sizes and fingerprints alongside repeated timing samples.
- Check output stability across iterations/samples. Document the fixture's 19
  recovered variation warnings and distinguish these measurements from GUI
  latency and the older one-off benchmark configuration.
- Record the baseline and comparison method in `tests/PERFORMANCE.md`; refresh
  the testing/refactoring inventories for the completed pre-chess cleanup.
- Validation: benchmark smoke/default runs, full headless/source-audit sweep,
  GTK preservation/interaction/delivery, tournament checks and application build
  all pass. Nothing pushed; the published release and tag remain unchanged.

### 2026-10-26 — Verify and fence GUI message delivery (C7)

- Add actual-consumer GTK coverage for interleaved full/live runner snapshots,
  per-search analyzer coalescing, flush-before-completion ordering, cancelled
  searches, removed games and form shutdown, with exact payload destruction counts.
- Count snapshot messages toward the existing 100-event timer limit; previously
  snapshot-only streams bypassed it. Keep unlimited shutdown draining.
- Ignore analyzer/MCTS completion messages from other runners before changing
  search tracking or engine reservations. Test with a completed old runner while
  a current annotator or MCTS runner remains active.
- Correct the inventory: the GUI consumer coalesces snapshots; the queue is FIFO.
- Validation: GTK preservation/boundary and expanded delivery checks pass.

### 2026-10-26 — Choose ambiguous board captures explicitly (U8)

- Offer distinct standard PDN paths when legal captures share their source and
  destination. Keep direct selection for unique moves and preserve the position
  on Cancel; reject choices made against a position changed during the dialog.
- Add headless candidate-selection checks and actual GTK chooser tests for both
  captures, cancellation and a position change while the chooser is open.
- Validation: move-interaction and full GTK preservation/boundary checks pass.

### 2026-10-26 — Stabilize database identities for capture variations (P23)

- Store position-resolved canonical moves on every branch, including standalone
  and nested variations, while keeping public PDN notation and source spelling.
- Reuse parsed-tree normalization so storage needs no second board traversal.
- Advance the internal database format and hash identity to 6. Compare complete
  legacy game content before lazily upgrading old identities; rebuild the legacy
  candidate index during migration. Older binaries refuse the newer format.
- Add export/reimport regressions for full, short and ambiguous capture paths,
  changed variation comments, and migration of version-5 variation identities.
- Validation: full headless/source-audit sweep and application build pass. GTK
  checks pass on rerun; the initial boundary test hung during game shutdown.

### 2026-10-26 — Merge position-equivalent parsed moves (P26)

- Resolve parsed sibling moves against their parent board before merging capture
  aliases; retain the first spelling and keep different captured sets distinct.
- Combine comments, independent analysis fields and child continuations. Retain
  first nonempty values for conflicting metadata; cache normalization per parsed
  game signature and leave invalid subtrees for existing warning/recovery paths.
- Add stable repeated-export, metadata/continuation preservation and ambiguous
  same-endpoint capture regressions. PDN, comment and GTK checks pass.

### 2026-10-26 — Keep metadata-like user comments literal (P25)

- Recognize the current metadata envelope by its checksum header, rather than a
  bare prefix. Ordinary prefix-like prose no longer produces metadata warnings.
- Escape a literal leading metadata marker in file output and distinguish that
  escape during parsing, including text that is itself a valid extension. Keep
  genuine and legacy analysis extensions readable and edited-comment handling.
- Add repeated public/storage/tree writer round trips for literal root and move
  comments. Comment, metadata/filter and notation-compatibility checks pass.

### 2026-10-26 — Preserve comments following node metadata (P24)

- Keep typed comments in sync when ordinary text follows a node-data comment,
  including root, move and variation comments. Retain independent analysis data.
- Add repeated writer/parser round trips and actor-restoration regressions.
  Comment-preservation and PDN metadata/filter checks pass.

### 2026-10-26 — Validate PDN imports in one actor traversal (F11)

- Replace one replaying move command per imported node with an actor command that
  owns a cloned parsed tree and advances boards along each line, copying only at
  forks. Preserve actor ownership, move normalization and per-subtree recovery.
- Keep ordered warnings, subsequent valid siblings, full metadata and non-finite
  clock checks. Compare the new path with the previous per-node implementation;
  add payload ownership, stale target and 200-ply validation-work regressions.
- Headless benchmark on Claude's long-game fixture, ten imports with identical
  exports: 4.57 s before, 0.28 s after (both using the node index and F12).
- Update the manual for notation-style tree display and its alternate layout.
- Validation: full headless/source-audit sweep, GTK preservation/interaction, DXP
  and tournament checks, plus the application build, all pass. Nothing pushed.

### 2026-10-26 — Index game-tree node identities (F11)

- Replace recursive node-ID lookup with a non-owning hash index; nodes remain
  owned by their parents and IDs keep their existing lifetime/scoping rules.
- Remove complete subtrees from the index before deletion and clear it on rebuild.
  Add repeated removal, trimming, replacement, branch-clear and rebuild checks
  for live identities and stale pointers. Cursor/topology/validation checks pass.

### 2026-10-26 — Show the game tree as notation

- Adopt Claude's notation-layout proposal: mainline moves are sibling rows and
  alternatives nest under the move they replace. Mark variation headers and keep
  the original nested layout available in the tree popup (session-only setting).
- Preserve expanded nodes and selection by identity on same-tree rebuilds/layout
  switches; reveal the selected path and avoid carrying state between games.
- Build standard PDN capture captions in one incremental traversal, without
  replaying from the root for each row.
- Add GTK tests for exact node coverage, both layouts, nesting, expanded-state and
  selection preservation, popup switching and capture captions. GTK checks pass.

### 2026-10-26 — Render notation with incremental boards (F10)

- Advance one board along each notation line and copy at variation boundaries.
  Capture captions no longer replay their entire ancestry. Invalid legacy paths
  still fall back to raw move text.
- Verify compact/export text and all navigation metadata against a frozen
  pre-change digest over all 256 filter combinations. Add a deterministic bound
  of one board move per displayed model node; PDN and GTK checks pass.
- Headless benchmark on Claude's 151-ply fixture, 100 renders: 12.45 s before,
  0.54 s after with identical output (same ordinal move-comparison setting).

### 2026-10-26 — Use ordinal legal-move comparisons (F12)

- Make the legal-move list case-sensitive and locale-independent. Input still
  normalizes before lookup; generated move order and capture aliases are unchanged.
- Add uppercase/zero-padded landing-path and reordered-capture regressions,
  duplicate detection and copied-board lookup checks. Board and DXP suites pass.

### 2026-10-26 — Extract analysis request and snapshot preparation

- Move analyzer/MCTS request preparation, prior-search cancellation, selected-base
  choice and persistent-search eligibility into analysis coordination. The form
  supplies a borrowed position description and posts the resulting request.
- Move snapshot filtering/target preparation out of the form, preserving scoped
  node identities, unscoped base-ply fallback and transient preview isolation.
  Keep queue draining, UI updates, runner ownership and shutdown in place.
- Add cross-game cancellation, unchanged-request, transient/terminal, copied-base,
  persistent snapshot and late-snapshot rejection regressions. Update inventory.
- Validation: full headless/source-audit sweep, GTK preservation/analysis-control
  checks, GTK tournament check and application build pass. Nothing pushed.

### 2026-10-26 — Extract analysis PV base and display-cache ownership

- Move copied analyzer/main PV base boards, node/base-ply association, engine and
  annotator PV lookup, visible-PV selection and display-cache tuple to analysis
  coordination. Borrow the displayed-position replay cache and actor revision.
- Preserve latest-engine-PV selection, nested analyzer bases, fallback positions,
  nil-board behaviour and frozen browser updates; controls remain in the form.
- Add headless copy/fallback/cache regressions. GTK preservation, frozen-PV and
  analysis-control checks pass.

### 2026-10-26 — Extract Auto Play coordination

- Move Auto Play node/tree/search identity, temporary PV accumulation, continuation
  policy and legal move-command preparation to TAutoPlayCoordinator.
- Advance the preview only after an accepted actor command and keep cancellation,
  runner stop requests and UI refresh ordering in the form.
- Add regressions for historical-node attachment, preserved official continuation,
  rejected moves/targets, game changes, restart/reset and late-result fencing.
  GTK analysis-control and preservation checks pass.

### 2026-10-26 — Extract analysis search coordination

- Add LCL-independent uAnalysisCoordinator for analysis search tracking, actor
  start/done/cancel/release commands, snapshot identity checks and coalescing keys.
- Move analyzer/MCTS restart signatures and terminal-position policy out of the
  form. Keep actor lookup, queue delivery, engine ownership and shutdown there.
- Add headless regressions for nested identities, stale results after cancellation
  or completion, queued release, restart suppression and terminal/history policy.
  GTK preservation and analysis-control checks pass.

### 2026-10-26 — Verify notation selections across filter rebuilds

- Add a GTK regression using actual memo and popup handlers for caret endpoints,
  selected-text overlap and hiding/restoring annotations. Verify rebuilt ranges
  keep the selected board and exported game unchanged.
- Update the refactoring inventory: notation presentation is extracted; analysis
  coordination is next. Keep the published version and tag unchanged.
- Validation: complete headless/source-audit sweep, GTK interaction/preservation
  checks, GTK tournament check and application build pass.

### 2026-10-26 — Extract notation hit-testing and highlight selection

- Move memo range hit-testing and automatic/focused highlight selection into
  uNotationPresentation. Return navigation targets and ranges; keep cursor,
  preview, memo focus and control updates in the form.
- Preserve variation-first hit priority, inclusive caret endpoints, exclusive
  selected-text overlap, preview click restrictions and root-selection behaviour.
- Add headless regressions for nested node/opening-bracket identity, PV context,
  hit boundaries and automatic versus focused highlights. GTK checks pass.

### 2026-10-26 — Extract notation rendering and range ownership

- Add the LCL-independent uNotationPresentation presenter, using the existing
  PDN renderer unchanged. It owns rendered text/ranges and the label signature;
  the form no longer copies parallel mainline and variation arrays.
- Preserve label invalidation rules and capture/branch navigation metadata.
  Keep memo updates, focus and cursor commands in the form.
- Add headless parity checks for all 256 filter combinations, nested branches,
  capture captions and signature invalidation; GTK navigation checks pass.

### 2026-10-26 — Extract move-highlight calculation

- Move last-move, PV-source and next-PV-source square calculation to
  uMoveInteraction. The form supplies the existing displayed-position/PV match
  and applies the returned values to controls.
- Preserve the mainline-at-base-ply last-move marker and suppression of PV hints
  for unrelated positions. Add regressions for historical/root/empty positions,
  one-move PVs and cleared hints.
- Update the refactoring inventory for the extracted move/display boundaries.
- Validation: the complete headless/source-audit sweep, GTK preservation and
  interaction checks, GTK tournament check and application build pass.

### 2026-10-26 — Extract displayed-position coordination

- Move the sole tree cursor, temporary PV preview, selected-path text and validated
  board projection to uDisplayedPosition, independent of LCL. Keep tree ownership,
  actor lookup, analysis cancellation and control updates in the form.
- Preserve revision-scoped replay reuse during nested refreshes, copied cached
  boards, cache disposal after the outer refresh, and atomic preview failure.
- Add headless nested-branch, preview, selection/fallback and replay-cache tests.
  GTK preservation and interaction checks pass.

### 2026-10-26 — Extract board move interaction

- Move temporary source selection, legal candidates, ordered target squares and
  move routing into the LCL-independent uMoveInteraction unit.
- Preserve single-choice play, first-candidate capture selection, unfinished-tip
  appends, historical/completed-game variations and live human runner delivery.
  Actor mutations, runner calls and control updates remain in the form.
- Add headless selection/routing regressions; GTK preservation and interaction
  checks pass.

### 2026-10-26 — Extract queued GUI message classes

- Move the eight runner, analyzer and MCTS message classes verbatim into
  uGameGuiMessages. Snapshot messages retain ownership; finished messages continue
  to borrow runner identities. Payloads and message kinds are unchanged.
- Keep queue posting/coalescing, delivery and main-thread shutdown coordination
  in the form; do not introduce a new session manager or callback mechanism.
- Retarget ownership/lifecycle tests to the extracted units and compile them with
  plain FPC in the standard headless sweep, proving they no longer require LCL.
- Validation: headless ownership/lifecycle, GTK main-form and tournament checks pass.

### 2026-10-26 — Extract the running-game owner from the main form

- Move TRunningGame, its lifecycle and snapshot-input records to uRunningGame,
  preserving method bodies, copied setup/snapshot ownership and runner release order.
- Import the model explicitly from the form, tournament integration and regression
  checks. Keep session management, UI queue draining and shutdown in the form.
- Validation: lifecycle/ownership, GTK interaction and tournament checks pass.

### 2026-10-26 — Separate setup values from the game-setup form

- Move player kind, setup record and setup callback declarations unchanged to
  uGameSetupTypes. Value-only users no longer import the LCL setup form.
- Keep engine-definition ownership and record layout unchanged; the setup form
  and main form explicitly import the value unit alongside UI dependencies.
- Validation: ownership/lifecycle, GTK main-form and tournament checks pass.

### 2026-10-26 — Characterize main-form interaction and analysis boundaries

- Add actual board capture-click and 50-square flip checks, replacement prompt
  cancellation/decline checks, and preservation when selecting another game.
- Exercise Auto Play on a historical node of a real stopped game, preserve its
  official continuation, and reject a delayed reply after Escape stops playback.
- Use a self-contained Hub process to exercise MCTS opening, protocol start,
  closing/reopening, reservation release and destruction with pending updates.
- Validation: existing and new GTK checks pass before extraction; UI tests use
  real event handlers and popup actions without private-field hooks.

### 2026-10-26 — Characterize running-game and queued-message ownership

- Verify copied engine setup and reservation keys, independently returned setup
  definitions, and retained snapshot/PV/log data after the source is changed/freed.
- Count snapshot destruction on consumption, queue clear, closed-queue rejection
  and shutdown; verify finished messages borrow runner identities and move messages
  retain exact tree/node/search references.
- Validation: Lazarus nogui lifecycle and ownership checks pass before extraction.

### 2026-10-26 — Inventory the main-form refactor before the independent chess port

- Document retain/replace/omit decisions, ownership invariants, extraction order
  and missing regression coverage in REFACTORING.md.
- Keep the draughts and chess applications independent, preserve current behaviour,
  and leave the published v3.0 tag unchanged.

## Version 3.0 — 2026-10-26

This release includes the accumulated correctness fixes below since v2.22.

- Consolidate game-tree data and cursor ownership; preserve nested variations,
  standalone games, comments, analysis and clocks across navigation and PDN export.
- Correct capture notation, game boundaries, malformed-variation recovery and
  metadata round trips; retain readable, compact analysis metadata.
- Protect tournament files, recover failed captures per row, distinguish engine
  configurations, and improve Swiss matching, round-robin colours and autosaves.
- Correct Hub/DXP history, clocks, startup and cancellation; restore live analysis
  updates and isolate child-process pipes and network listeners.
- Preserve complete database games, recognize legacy duplicates, recover interrupted
  imports, compress storage and run GUI imports on a separate worker connection.
- Publish a Linux x86_64 build and portable bundle. Windows binaries are not
  included in this release; Windows-specific changes still need native validation.

The following dated entries describe individual changes and their regression tests.

### 2026-10-25 — Recognize multiline metadata through the file reader (P21/P15)

- Normalize whitespace introduced by file-line joining only for metadata edit
  detection, preserving original comment layout and literal metadata values.
- Extend repeated complete-file round trips with multiline notes and verify that
  unchanged comments produce no stale-metadata warning.
- Validation: metadata, parser, preservation and database regressions pass.

### 2026-10-25 — Keep canonical capture identities in fast storage (F8/P22)

- Reuse the importer’s already validated mainline moves in the storage writer,
  so standard and internal capture spellings retain the same duplicate identity
  without an additional replay.
- Validation: standard/internal capture reimport and database recovery checks pass.

### 2026-10-25 — Isolate auxiliary process pipes and default zero startup timeouts

- Launch the monitor-query process under the same lock as engines, protect its
  Unix parent pipes from inheritance, and drain output before waiting outside
  the launch lock.
- Interpret a configured startup timeout of zero as the 60-second default.
- Validation: real child-process checks cover auxiliary-to-engine and
  engine-to-auxiliary pipe isolation; startup/clock regressions pass.

### 2026-10-25 — Import databases on an owned worker connection (P10)

- Move parsing and database writes off the GUI thread. A worker owns its SQLite
  connection and publishes locked progress snapshots; the modal dialog polls them.
- Remove nested message processing from progress callbacks. Keep reentry guards,
  immediate Stop/close cancellation and durable completed games before reconnecting.
- Validation: independent thread completion/error/cancellation checks and the GTK
  modal reentry/cancellation regression pass.

### 2026-10-25 — Publish one tournament snapshot per save (F9/T22)

- Write JSON once after attempting PDN publication, including the durable row
  state when PDN publication fails. Restore Save As fingerprints on failure.
- Cache verified ownership by path and content hash to avoid reparsing unchanged
  PDNs. Keep hashing on every save to detect same-size edits within one timestamp.
- Adopt an identical older projection without a fingerprint; preserve mismatches
  with an accurate notice instead of claiming they were necessarily edited.
- Validation: GTK tournament preservation suite passes; the 1,000-game / 10 KB
  benchmark takes 236 ms on this host, with same-size edit protection regressed.

### 2026-10-25 — Avoid replaying database PDN storage and migrate duplicate identities (F8/P22)

- Store the complete parsed tree without replaying a board for every stored node;
  public PDN exports continue to resolve captures with validated positions.
- Compress complete stored PDNs when smaller, while retaining plaintext and legacy
  loading. Schema 5 prevents older applications from misreading compressed rows.
- Match legacy duplicate candidates by complete content and upgrade their identity
  lazily. Newly supplied comments and variations remain distinct games.
- Validation: interrupted-import, compressed comment/tree reload, v3/v4 duplicate
  migration, changed-content and schema compatibility regressions pass.

### 2026-10-25 — Keep node metadata compact and readable (P21/P15)

- Replace duplicated base64 JSON with a compact readable extension; ordinary
  human comments need no metadata. Continue reading the previous format.
- Preserve multiline comment layout and depth/time fields without a PV. Normalize
  visible whitespace before detecting edits, and retain independent analysis
  when comments change while discarding contradictory edited score/clock values.
- Validation: repeated tree and legacy writer round trips, edited comments/scores,
  multiline notes, empty PVs, old metadata and preservation regressions pass.

### 2026-10-25 — Show standard captures in the move list (U6/P18)

- Render mainline and real variation captures with the board's standard PDN
  notation and calculate navigation/highlight ranges from the displayed caption.
- Number a variation's first move and subsequent White moves without repeating
  the number before every Black reply.
- Validation: tree rendering/preservation and GTK regressions pass, including
  clicking and highlighting a shortened capture caption on the actual board.

### 2026-10-25 — Match Swiss opponents without exponential search (T21/T4, T3)

- Replace bounded backtracking with augmenting-path matching and odd-cycle
  contraction. Maximize fresh pairings and keep score order as a preference;
  label unavoidable repeated pairs accurately.
- Alternate round-robin pair orientations, fix the virtual bye for odd fields,
  and reverse the mirrored second leg to avoid joining colour streaks.
- Regress matching against an independent exhaustive oracle on every six-player
  graph (32,768 cases), 25 rounds with 40 players, and colour runs of at most two
  alongside existing balance, round and pair-coverage checks for 2–12 players.
- Validation: pairing regressions pass in under one second on this host.

### 2026-10-25 — Isolate failed tournament captures to their rows (T20)

- Persist a failed capture's result and diagnostic in its row and PDN placeholder,
  pause scheduling, and keep unrelated result edits, autosaves and Save As working.
- Keep capture retries available while the live game exists, preserve manual
  overrides during retry, and detach pending references when a game is removed.
- Allow explicit rescheduling, retaining the failed attempt in history. Show failed
  captures in the row and window title, including after reload.
- Validation: record and GTK tournament checks cover deterministic failure, retry,
  another row's durable result, Save As, removal and rescheduling.

### 2026-10-25 — Distinguish tournament engine configurations (T19)

- Include arguments, initialization/INI settings and DXP endpoint settings in
  engine identity. Preserve these fields when saving the registry; arguments
  were previously read but omitted on save.
- Upgrade an old identity only when it uniquely identifies a definition. Refuse
  ambiguous legacy keys rather than silently selecting the first variant.
- Regress same-executable fast/slow definitions through setup and tournament
  save/load, parameter differences, old-key ambiguity and existing reorder cases.
- Validation: GTK tournament regression suite passes.

### 2026-10-25 — Validate DXP bindings and preserve literal Hub paths (D8/D18)

- Resolve localhost to loopback before binding and reject other nonnumeric listen
  addresses instead of silently exposing all interfaces. Keep explicit IPv4 network
  bindings supported; optionally restrict accepted clients with gui-dxp-peer-ip.
- Check accepted peer addresses and continue listening after a rejected client.
  Apply the same address validation to the connection tester.
- Follow protocol.txt's literal Hub values: do not double backslashes or treat a
  final backslash as escaping the closing quote. Reject unrepresentable quotes
  and line breaks explicitly instead of inventing undocumented escapes.
- Validation: real TCP binding/peer checks and Hub clock/quoting regressions pass.

### 2026-10-25 — Retry transient Windows access-denied publication errors (C4)

- Include access denied in the existing bounded atomic-rename retry policy for
  transient antivirus/indexer handles. Keep permanent path/existence errors immediate.
- Validation: retry-policy classification and atomic-file regression checks pass;
  native Windows execution remains unavailable on this Linux host.

### 2026-10-25 — Publish live engine analysis from stable position snapshots (M6)

- Keep full position/history snapshots on the owning runner thread. During a
  search, engine log callbacks may publish a copy of its last stable snapshot
  with current locked PV/score/depth/time and log data, throttled to 500 ms.
- Gate updates by the active engine and serialize publication so no stale live
  update follows the completed move. Never read the orchestrator on an engine thread.
- Regress a two-second fake Hub think with live info, verifying analysis arrives
  before the move, its board/history stay unchanged and the final move follows.
- Validation: Lazarus lifecycle/runner regressions pass.

### 2026-10-25 — Compare DXP captures independently of square order (D16)

- Compare source, destination and the captured-square multiset for exchanged DXP
  moves. Keep changed captures, changed destinations and shortened histories rejected.
- Regress a real TCP peer sending a capture in reverse square order, then playing
  its next turn after the GUI has stored the canonical move.
- Validation: board/history and TCP DXP regression checks pass.

### 2026-10-25 — Keep capture paths after playing a move (R8)

- Keep newly generated PDN capture paths alongside legal moves; clear both lists
  only when move generation is explicitly deferred.
- Regress an ambiguous king capture on ply two through both PDN writers and a
  database import surrounded by valid games. Verify the chosen capture survives.
- Validation: board, tree-PDN and PDN/database regression checks pass.

### 2026-10-25 — Keep runtime files local and document review decisions (C3)

- Stop tracking local preferences and tournament output while preserving both
  existing files on disk. Keep the generated user manual as documentation.
- Add a portable Lazarus build command that stages compilation in a temporary
  directory and replaces the local executable only after a successful build.
- Document the portable writable-directory configuration model, build/test
  prerequisites, and the response to Claude's 3678ba3 review in REVIEW_NOTES.md.
- Validation: isolated application build succeeds; headless, GTK, TCP DXP and
  tournament checks pass. The 1,000-game autosave check takes 354 ms on this host.

### 2026-10-25 — Reuse validated boards within a display refresh (F4)

- Cache successful board replays by tree, node and actor revision for the duration
  of one refresh. Board/highlight/PV/search consumers receive independent copies;
  no cached board survives the refresh or a changed revision.
- Route ply-based replay through the same node cache and free copies on errors.
- Validation: GTK import/navigation/preservation suite passes, including a bound
  on repeated replay builds, tree edits, invalid selections and recovery.

### 2026-10-25 — Defer archive move trees until selection (F2)

- List PDN headers/results while retaining each game's raw movetext, then build
  its recursive tree only when selected. Copying or exporting a deferred game
  preserves and resolves its complete content.
- Mark unselected warnings as pending rather than implying those games have
  already been validated; show the selected game's warnings after parsing.
- Regress deferred/eager equivalence, nested branches, Black starts, movetext
  results, copy isolation and actual GUI warning selection.
- Validation: PDN and GTK suites pass. On the same 10 MB / 1,000-game fixture,
  listing takes 21 ms versus 84 ms for eager parsing on this host.

### 2026-10-25 — Remove drifted compatibility helpers (C1/C2)

- Remove the unused pairing selector, White-only text history adapter, obsolete
  PDN stripping/extraction helpers and misspelled `go thiink` alias.
- Stop advertising the unused single-capture compatibility setting. Keep the
  exercised protocol-neutral message adapter used by engine integration tests.
- Extend the mutation audit to cover status, time control and Auto Play PV writes.
- Validation: PDN, pairing, GTK and mutation-audit checks pass.

### 2026-10-25 — Make an invalid displayed position visible (U5)

- Show a clear window-title diagnostic and blank the board when a corrupt node
  cannot be replayed. Disable Auto Play, cancel analysis and avoid refreshing
  dependent views from the previous board; navigation remains available.
- Restore the board and clear the diagnostic when a valid node is selected.
- Validation: GTK regression deliberately bypasses the actor to create corrupt
  legacy state, navigates into it, then returns to the valid root.

### 2026-10-25 — Preserve external tournament PDN edits (T16)

- Persist the fingerprint of the last published PDN and verify it before replacing
  an owned projection. Preserve changed or unverifiable files byte for byte,
  select a fresh projection path, and show a preservation notice in the title.
- Give each legacy file without an identity a fresh ID when loaded, including
  when several legacy tournaments are loaded through the same dialog.
- Keep explicitly tagged standings-only records for legacy/manual results so
  their results remain exportable without inventing a move history.
- Validation: GTK tournament suite passes, including same-ID external edits,
  resume after edits, independent legacy identities and existing collision cases.

### 2026-10-25 — Apply FMJD endgame draw limits (R7)

- Track the sixteen-move and five-move material limits from FMJD Annex 1,
  articles 6.3/6.4 (https://www.fmjd.org/docs/Annex_1.pdf). Start counting after
  the qualifying position is reached; keep an existing sixteen-move deadline
  through captures and apply an earlier five-move deadline when appropriate.
- Reset counters on a new game and give a terminal win precedence over draws.
- Regress both sides, king/man material classes, entry into a qualifying ending,
  capture without reset, counter reset and actual played king-versus-king draw.
- Validation: dedicated endgame, board and headless regression suites pass.

### 2026-10-25 — Reconcile DXP exchanges with the game record (D10)

- Track the exact moves and starting position exchanged with a DXP peer. Send
  only a single new opponent move after an unchanged prefix; reject takebacks,
  changed prefixes, changed starts and skipped exchanges with a resynchronization
  diagnostic instead of silently continuing a different game.
- Record received engine moves in the exchanged history and wait for acceptance
  when opening a resumed session. Recovery requires explicitly starting a new game.
- Validation: board regressions cover matching/changed/shortened/skipped histories
  and equivalent notation; the real TCP DXP suite passes.

### 2026-10-25 — Harden engine protocol boundaries and pipe ownership (D11/D12)

- Retain partial DXP packets between timed reads, enforce the 127-byte limit,
  reject trailing/non-numeric MOVE data and invalid/repeated captured squares,
  and clamp oversized Fischer fields. Keep valid zero-capture quiet moves.
- Parse Hub arguments outside quoted values and round-trip escaped quotes,
  backslashes and whitespace consistently. Correct Windows command-line quoting
  for embedded quotes and trailing backslashes, including the executable path.
- Serialize process launches, mark Unix parent pipe descriptors close-on-exec,
  and close failed Windows launch pipe handles. Concurrent Windows launches can
  no longer inherit another launch's temporary child handles.
- Regress packet fragments/limits, malformed captures, Fischer bounds, Hub quotes,
  Windows argument strings and actual Linux child pipe inheritance.
- Validation: board, engine clock, process and real TCP DXP suites pass. Native
  Windows execution remains unavailable on this Linux host.

### 2026-10-25 — Show current analysis and frozen PV state (A4–A6)

- Mark the PV browser as browsing, explain Escape to resume, and indicate a newer
  pending PV. Clear that feedback when the newest PV is applied.
- Evaluate the selected position from its own annotator/engine score. Keep older
  evaluations in the history chart rather than presenting them as current.
- Stop interpreting arbitrary free-text comments as engine evaluations.
- Validation: GTK regressions cover browsing/pending/resume feedback, score
  precedence, historical selection, root selection and numeric-looking comments.

### 2026-10-25 — Match database names across Unicode case (P14)

- Use Unicode lowercasing consistently for database name/event filters and
  sorting. Treat percent and underscore as literal search characters.
- Bind and read database text explicitly as UTF-8, preserving accented and
  Cyrillic names in imported games as well as in search parameters.
- Regress accented/Cyrillic import, case-insensitive individual and either-player
  filters, literal wildcard characters and Unicode sorting.
- Validation: database recovery and PDN regression suites pass.

### 2026-10-25 — Retain complete imported database games (P13)

- Store complete PDN alongside canonical mainline position rows, preserving root
  comments, nested variations and typed node analysis through database load.
- Include the complete serialized game in duplicate identity so distinct notes
  and branches cannot be silently discarded. Canonicalization no longer mutates
  the parsed source tree before storage.
- Migrate existing rows without rewriting them, record schema version 4, and
  refuse newer schemas. Creating a database now refuses an existing filename;
  opening a database requires an existing file.
- Regress nested analysis round trips, annotation-sensitive duplicates, legacy
  migration, existing-file protection and future-version protection.
- Validation: database recovery and PDN regression suites pass.

### 2026-10-25 — Preserve typed node analysis through PDN (P15)

- Save PVs, scores, depths, timings and clocks in a versioned PDN comment
  extension, and restore them through the actor onto their original nodes.
  Keep readable annotations and real nested variations; analysis previews no
  longer become ordinary variations on every save/load cycle.
- Preserve typed data in parsed-tree copies and the legacy PDN writer. An edited
  visible comment takes precedence over stale metadata, with an import warning.
- Regress repeated file and actual GTK form round trips, root and nested node
  data, full clock values, escaped comments and invalid restoration commands.
- Validation: focused PDN, actor, tree and GTK suites and mutation audit pass.

### 2026-10-25 — Pause safely on finished-game capture errors (T5)

- Catch capture/serialization failures, mark finished rows inactive, and retain a
  pending capture with its error instead of retrying it every timer tick.
- Do not publish an incomplete tournament while captures are pending. Allow an
  explicit save/completion retry to recover retained live games; protect pending
  captures from manual result edits and retain duplicate-completion safeguards.
- Regress injected capture failure, successful retry and a later manual override.
  Preserve the round-number fallback for callers constructing pairing records.
- Validation: GTK tournament suite passes.

### 2026-10-25 — Resume tournament rows by engine identity (T8)

- Persist each row's engine identity with its record and persist selected engine
  keys separately from display labels. Resolve those keys on load and refresh
  labels after registry reordering; never fall back to a display slot for a saved key.
- Keep legacy rows compatible by capturing their identity when first resolved.
  Missing engines receive a row diagnostic rather than leaving scheduling spinning.
- Validate the added identity fields before mutating a loaded tournament.
- Regress registry reordering and engine removal through actual save/load/setup;
  tournament record and GTK tournament suites pass.

### 2026-10-25 — Let star clear a tournament manual override (T15)

- Treat manual `*` as clearing the override, restoring the played result when
  available and returning an unplayed row to pending otherwise. Clear the manual
  reason consistently instead of persisting a blocking unknown override.
- Regress record-level clearing and the actual grid's played-result restoration.
- Validation: tournament record and GTK tournament suites pass.

### 2026-10-25 — Backtrack before proposing repeated Swiss opponents (T4)

- Search score-ordered nonrepeat matchings before the existing penalized fallback,
  retaining colour balancing and bye policy. Bound search work so a pathological
  opponent graph cannot monopolize the GUI indefinitely.
- Describe repeated proposals accurately without claiming a proof that no other
  pairing exists when a bounded search falls back.
- Regress a greedy dead end with an available nonrepeat matching, unique
  participants and a fully exhausted opponent graph.
- Validation: greedy-repeat regression fails before the fix; pairing and GTK
  tournament suites pass.

### 2026-10-25 — Balance round-robin colours and schedule real rounds (T3)

- Generate circle pairings with alternating fixed-player colours, a virtual bye
  for odd fields, and distinct round numbers. Double round robins mirror the full
  first leg with colours reversed in later rounds.
- Carry each pairing's round into the grid rather than assigning every game to round 1.
- Regress 2–12 participants, both formats, pair coverage, colour balance and no
  participant playing twice in a round.
- Validation: balance regression fails before the fix; pairing and GTK tournament suites pass.

### 2026-10-25 — Preserve literal PDN comments and Black-start numbering (P18, P12)

- Stop interpreting `base_ply` or annotator-like text in comments as structural
  metadata. Explicit compatibility records retain their own base fields.
- Preserve comment-only variation text as a position comment with a diagnostic.
  Escape braces/backslashes on export and honor them across stream buffers and
  recursive variations, so comment contents cannot change game boundaries.
- Correct White move numbers after a Black-to-move start in the legacy writer.
- Regress literal metadata-looking comments, comment-only text, escaped delimiters
  across save/load and legacy Black-start export. PDN/tree/filter suites pass.

### 2026-10-25 — Reject malformed moves and overlapping FEN pieces (R6, U4)

- Reject whitespace within move squares, dangling capture separators and mixed
  separator types instead of normalizing malformed input into a legal move.
- Accept whitespace around FEN ranges and a terminal period; reject duplicate or
  overlapping squares atomically. Regenerate moves when side-to-move is changed.
- Keep empty-side positions available for terminal-position analysis.
- Validation: expanded board regression suite passes.

### 2026-10-25 — Accept and export standard PDN capture paths (R5, P15)

- Validate landing-square capture routes against the board, including flying
  kings, blockers, capture counts and repeated victims. Preserve internal DXP
  captured-piece notation while canonicalizing accepted actor move aliases.
- Retain a legal landing path for each generated capture. File exports use short
  endpoints when unique, otherwise the full disambiguating landing path.
- Add SetUp for nonstandard starting positions and preserve double-loss results
  in the tree writer. Compact board displays keep their internal hit mapping.
- Regress men/kings, illegal partial/routes, ambiguous destinations, all-capture
  round trips and actual GUI import/export. Update ancestry expectations to the
  actor's canonical capture notation.
- Validation: board, actor, validation, topology, runner history, preservation,
  cursor, PDN/filter and hidden GTK main-form suites pass.

### 2026-10-25 — Guard database import with a modal progress window (P10)

- Begin import only after its modal progress window is active. Stop/close requests
  cancel safely; database browse/open/search/repair routes cannot reenter the
  connection or commit its active batch while progress messages are processed.
- Keep the importing form alive until its callback returns; clear queued work and
  restore normal interaction after success, cancellation or failure.
- Regress modal entry, attempted browse/database replacement and close cancellation
  in the actual GUI, verifying only the first game is retained on cancellation.
- Validation: hidden GTK main-form suite passes.

### 2026-10-25 — Append PDN without rewriting the archive (P11)

- Append the new record through an append-mode handle and flush it, reading only
  the final byte needed for separation. Preserve all existing bytes and line
  endings; use Unicode Windows paths and exclusive Windows writer sharing.
- Regress CRLF prefix preservation while retaining existing append/load checks.
- Validation: PDN regression suite passes.

### 2026-10-25 — Bound engine output retained in memory (F1)

- Bound engine state logs and individual diagnostic entries. Consume Hub info
  updates without retaining them in the protocol-response queue; bound that queue
  and discard oversized output lines without treating their suffix as a command.
- Remove the DXP stdout buffer/list that was populated but never consumed.
- Regress 20,000 log entries, a 20,000-line info flood and a malformed oversized
  line followed by a real move. Existing DXP protocol tests still pass.
- Validation: unbounded-log regression fails before the fix; clock/flood and local
  TCP DXP suites pass.

### 2026-10-25 — Allow configurable cold engine startup (D9)

- Use a 60-second Hub handshake/ready and DXP acceptance default, configurable
  per engine as `gui-startup-timeout-ms` (bounded to 1–300 seconds).
- Wait for Hub's handshake completion directly instead of imposing an additional
  optional-ID delay. Existing cancellation and process-exit checks remain active.
- Regress the parameter override and an engine taking over five seconds to initialize.
- Validation: expanded clock/launch suite passes.

### 2026-10-25 — Bind DXP locally and protect listener lifetimes (D8, A7)

- Bind listeners to the configured host (loopback by default), including the
  connection tester, and wake the same address during shutdown.
- Protect server references while stopping/freeing listeners. Join workers before
  freeing their sockets/locks; the connection tester no longer frees a socket
  while its worker may still be assigning it.
- Regress rejection on another loopback interface, a normal local peer and
  repeated immediate shutdown of both listener implementations.
- Validation: interface-binding regression fails before the fix; full local TCP
  DXP suite passes, including claims, disconnects and clock timeout handling.

### 2026-10-25 — Keep extended clock configuration protocol-neutral (D7)

- Route increment-aware clock data through a typed engine method. Hub adds its
  protocol field; other adapters receive their unchanged accumulated used time.
- Regress compatibility with an adapter implementing the original clock method.
- Validation: clock suite passes; removes the generic text-message path that
  could otherwise reset DXP's used-time field.

### 2026-10-25 — Send accurate engine clock controls (D6, D7)

- Truncate DXP whole-minute controls instead of rounding fractional minutes up,
  retaining the protocol's one-minute minimum.
- Omit Hub `moves` for sudden death and send the currently applicable increment,
  including the GUI's delayed-increment policy, before each search.
- Regress fractional DXP controls and actual Hub level messages alongside the
  existing timeout, period-boundary, delayed-increment and history checks.
- Validation: DXP rounding regression fails before the fix; board and clock suites pass.

### 2026-10-25 — Reuse storage for empty tournament resets (T18)

- Keep the storage identity/path when clearing or recreating a tournament with
  no results or historical attempts. Preserve the separate-generation safeguard
  whenever recorded or rescheduled history exists.
- Regress repeated empty resets and a reset after rescheduling a recorded game.
- Validation: empty-reset regression fails before the fix; GTK tournament suite passes.

### 2026-10-25 — Preserve annotator cancellation through launch (D15)

- Give each analyzer runner a persistent cancellation token, assign it when its
  engine is created, and cancel it before requesting shutdown. Launch checks it
  before starting a process; handshake waits already observe the same token.
- Regress shutdown from the Opening callback against a silent launch, exactly
  between the runner's termination check and engine initialization.
- Validation: launch-window regression fails before the fix; analyzer shutdown
  suite passes, including stop-fence interruption and immediate shutdown races.

### 2026-10-25 — Publish safely on Unicode paths and filesystems without hard links (C4, C6)

- Use explicit wide-character Windows create/rename/delete calls for UTF-8 paths.
  Retry only transient sharing/lock failures with a bounded delay, preserving the
  existing destination when replacement fails.
- Fall back from unsupported Unix hard links to exclusive name reservation and
  rename. Existing files/directories remain protected; a crash before rename can
  leave an empty recoverable projection rather than overwrite unrelated data.
- Regress non-ASCII paths, collisions and cleanup through both normal and forced
  no-hard-link paths. Include the fallback in the regression runner.
- Validation: both atomic-file modes pass on Linux. Windows API changes were
  checked against the installed FPC declarations; native Windows execution remains
  unavailable in this workspace.

### 2026-10-25 — Read PDN spans without per-character string growth (F6)

- Copy ordinary token, comment, header and whitespace spans from stream buffers;
  slice recursive variation text once. Reuse bounded-growth parser buffers.
- Buffered loads take ownership of parsed games directly instead of deep-cloning
  their trees. Streaming callbacks retain their existing borrowed ownership.
- Add headers-only streaming for tournament identity checks, avoiding move trees
  and large comment copies on every save. Reject malformed identity documents.
- Regress large comments spanning buffers, mixed identities and spoofed/malformed
  ownership tags. Existing boundary, tree, filter and GUI tests pass.
- Validation: the same 10 MB/1,000-game fixture improved from 762/735 ms buffered/
  streaming to 75/54 ms. GTK tournament performance/preservation passes (195 ms
  for a 1,000-game, 10 KB-per-game autosave); hidden main-form suite passes.

### 2026-10-25 — Make Lazarus regression builds portable and noninteractive (C5, C3)

- Store the noninteractive define in all three test projects and reject builds
  without it, preventing hidden confirmation dialogs from hanging the tests.
- Build isolated project copies with ordinary Lazarus 3.0-compatible options;
  remove dependence on `--opt` and verify the requested executable exists.
- Ignore numbered local engine configurations/executables without moving or
  deleting them, preventing accidental staging of large local files.
- Validation: lifecycle and both GTK suites build and pass through the new helper.

### 2026-10-25 — Explain rejected PDN branches (P20)

- Validate a selected PDN's recursive tree lazily and show illegal-move/subtree
  diagnostics in the PDN list. Preserve parsed input for inspection; do not pay
  for legal replay of every game merely to populate the file list.
- Record actor import rejections instead of ignoring their error text, and retain
  warnings in the loaded board status. Valid mainlines and sibling branches load.
- Regress parser diagnostics and the actual list/board warning flow.
- Validation: recursive-tree and hidden GTK main-form suites pass.

### 2026-10-25 — Keep runner snapshots on their owning thread (M5)

- Asynchronous engine log callbacks only append under the log lock; they cannot
  snapshot the orchestrator while its runner is changing the board or history.
  Runner-owned publication retains the accumulated log and completed move data.
- Regress foreign-thread log delivery and assert snapshot callbacks always run
  on the runner, including startup, human moves, rejection and shutdown.
- Validation: thread-affinity regression fails before the fix; lifecycle suite passes.

### 2026-10-25 — Avoid phantom PDN games from header gaps and repeated results (P19)

- Blank lines no longer split a header, including after its Result tag. Repeated
  tags still identify separate tags-only games. Ignore extra result fragments
  after a completed game rather than inventing empty games.
- Regress spaced complete headers and duplicate results. Disjoint header fields
  without a repeated tag or movetext terminator remain one header block.
- Validation: boundary regression fails before the fix; PDN regression passes.

### 2026-10-25 — Verify tournament PDN ownership before replacement (T17)

- Check the tournament IDs in an existing projection before replacing it, even
  when a copied JSON claims ownership. Preserve unrelated, damaged or occupied
  targets and publish the authoritative records to a fresh path instead.
- Preserve TournamentId through PDN reads and copies. Regress a copied JSON
  pointing at an unrelated PDN and update recovery tests to preserve unknown data.
- Validation: overwrite regression fails before the fix; GTK tournament suite passes.

### 2026-10-25 — Retain database indexes through interrupted imports (P9)

- Keep the position-search and game-position indexes active throughout imports,
  so cancellation, failed recovery or process exit cannot leave them missing.
  Opening older interrupted databases still recreates any missing indexes.
- Extend regressions to inspect all import/search indexes during progress and
  after failed summary rebuilds, abrupt committed-batch exit and abrupt exit with
  an additional uncommitted game. Verify the final game and its positions roll
  back while earlier batches survive and their statistics recover correctly.
- Validation: the index-preservation regression fails before the fix; full
  headless suite, both GTK suites and application build pass. Rebuilt the local app.

### 2026-10-25 — Track and recover database summary freshness (P9)

- Persist a summary freshness flag before imports and invalidate it atomically
  with position inserts, updates and deletes. Searches aggregate position rows
  while the summary is stale, including after a rebuild during an active import.
- Publish rebuilt statistics and the clean flag together. On opening an
  interrupted or older database, rebuild its summary before returning it for use.
  A failed rebuild leaves the prior summary marked stale and searches correct.
- Add regressions for live White/Black statistics, cancellation, reentrant
  rebuilds, failed summary writes, old-database migration and abrupt process exit
  immediately after a committed 10,000-game batch, bypassing all import cleanup.
- Validation: stale-summary regressions fail before their fixes; new import
  recovery and existing PDN regression checks pass.

### 2026-10-25 — Separate PDN games at mainline result tokens (P7)

- End each game at its mainline result, retaining adjacent untagged games even
  on one line. Ignore result-like text in comments and nested variations; keep
  trailing comments and NAGs with the completed game without creating empty games.
- Preserve result-only games, cancellation and tokens spanning stream buffers.
  Allow blank lines in unfinished headers; a blank line can separate a tags-only
  game once its Result tag declares a completed result.
- Regress database import of untagged games, nested results, trailing comments,
  result-only games, empty input, exact CR/LF/CRLF bytes, EOF without a newline,
  spaced headers and quoted tags/comments/results crossing the 64 KiB buffer.
- Validation: the untagged-game regression fails before the fix; full headless
  suite, both GTK suites and application build pass. PDN regression heap checking
  reports no leaks. Rebuilt the local application.

### 2026-10-25 — Read PDN headers outside comments and quoted values (P7)

- Use one incremental reader for buffered and streaming imports. Read each tag
  separately, including multiple tags and following moves on the same line;
  preserve escaped quotes and brackets in values and accept tab separators.
- Keep tag-like text inside brace and line comments in its game. Separate
  tags-only games at repeated tags or blank lines between header blocks, retaining
  forfeits without moves. Keep recovery at a new-line header after a damaged RAV.
- Regress inline tags/moves, multiline comments, forfeits, escaped values and
  UTF-8 BOMs, checking buffered/streamed results and warning parity.
- Validation: the boundary regression fails before the fix; PDN regression,
  recursive-tree, tree-filter and preservation checks pass.

### 2026-10-25 — Continue database import after invalid games (P8)

- Validate each whole game before inserting any rows. Log and count illegal
  moves and malformed FENs, then continue with the following game. Valid games
  and duplicate detection survive errors on either side of a batch commit.
- Keep database and file failures fatal, preserving their original exceptions
  and transaction rollback rather than reporting them as invalid PDN.
- Regress invalid first/late moves, invalid FENs, neighboring valid games,
  repeated imports, persistence across the 10,000-game batch boundary and an
  injected database failure after a partial write.
- Validation: invalid-game regression fails before the fix; full headless suite,
  hidden GTK main-form checks and application build pass. Rebuilt the local app.

### 2026-10-25 — Recognize double-loss PDN results (P6)

- Treat `0-0` as a result, preserving it in tags, movetext and exports instead
  of importing it as an illegal move or changing it to an unknown result.
- Regress tagged and untagged results, streaming parity, database import and
  save/load round trips.
- Validation: the double-loss regression fails before the fix; PDN regression,
  recursive-tree and tree-filter checks pass.

### 2026-10-25 — Retain PDN movetext results (P5)

- Use the mainline termination result when no Result tag was supplied. Normalize
  equivalent result spellings and retain an explicit tag on conflict, with an
  import warning. Results inside variations and comments do not affect the game.
- Regress buffered and streaming imports, explicit unknown results, conflicts,
  equivalent spellings and save/load round trips.
- Validation: the missing-result regression fails before the fix; PDN regression,
  recursive-tree and tree-filter checks pass.

### 2026-10-25 — Make batch import commands use typed move records (G7)

- Replace flattened move text plus encoded annotation arrays in actor imports
  with copied move/comment records. Node imports use the same literal data path.
  The actor and builder no longer depend on the PDN decoder.
- Preflight the whole typed branch before mutation. Empty batches, missing
  parents and late illegal moves fail without creating a partial prefix.
- Regress command-owned input copies and marker-like literal comments in batch
  imports, and enforce the decoder boundary in the source audit.
- Validation: expanded actor validation, full headless suite, GTK main-form
  checks and the full application build pass.

### 2026-10-25 — Import PDN recursively from parsed nodes (G7)

- Build ordered move nodes during PDN parsing, including nested variations at
  their actual parents. Preserve the first continuation even if a RAV appears
  before it; attach leading variation comments to the variation's first move.
- Import these nodes recursively through validated parent-node commands. Remove
  the GUI's flattened-variation decoder and its display/base/index bookkeeping.
- Deep-copy parsed trees for game copies and callers. Keep old database-field
  conversion confined to the PDN boundary, with cache invalidation after edits.
- Regress nested White/Black alternatives, Black-start captures, malformed
  branches, early RAVs, legal replay of every path, copy isolation and old records.
  Enforce adapter retirement in the source audit.
- Import each parsed node with a literal-comment command. Regress marker-like
  comments that previously caused a valid branch to be skipped or reinterpreted.
- Validation: full headless suite, both GTK suites and the large tournament save
  check pass; the new parser/tree test also passes with heap leak checking enabled.

### 2026-10-25 — Remove stored variation lines and indexed mutation (G7)

- Remove the model's variation-line table, line-owned annotations/origin, builder
  rematerialization and rebuild-command line payloads. Nodes own all branch data.
- Import validated moves under an explicit parent node ID. Creating/exploring a
  move finds or creates one child directly; clearing branches follows structure.
- Remove branch indices from memo hits, selection and highlighting. Analysis
  supplied with a rebuild targets a node ID rather than a remapped line index.
- Keep only read-only branch inspection paths, derived on demand from children:
  they are not stored game state and cannot be used to rebuild or mutate a line.
- Migrate regression fixtures to structural imports/removals and node metadata;
  retain coverage for malformed imports, shared prefixes, subtree removal,
  immutable selections, repeated imports, clocks, analysis and save/load cycles.
- Validation: full headless regression suite and hidden GTK main-form checks pass.

### 2026-10-25 — Preserve live subtrees during mainline rebuilds (G7)

- Stop copying and replaying stored variation lines during rebuilds. Update the
  mainline chain in place, keeping surviving node IDs, descendants and metadata.
- Resolve an optional analysis target to its node ID before a rebuild, and validate
  header changes against actual child paths. A different root starts a fresh tree.
- Regress a queued rebuild followed by a new branch move and analysis update:
  executing the rebuild must preserve both newer edits instead of replaying stale data.
- Validation: the new regression fails with the old adapter; topology, actor,
  move-validation and preservation checks pass.

### 2026-10-25 — Remove encoded variation keys from the model and actor (G7)

- Delete stored `base:display:index:ply` keys and their parser. Determine mainline
  membership structurally and prune alternatives using node identity.
- Build new branch paths from real parents; find an existing child by move before
  updating the legacy line adapter. Reindexing that adapter cannot redirect a move.
- Derive shared-comment merge locations from node IDs; preserve existing comments
  when another path contributes an empty annotation.
- Regress imported paths containing a mainline prefix, sibling insertion, alias
  removal/reindexing and following an existing child without tree mutation.
- Validation: topology, actor, preservation, cursor and GTK main-form checks pass.
- The legacy line adapter remains at import/rebuild boundaries; its complete
  retirement is separate from removal of encoded keys and structural selection.

### 2026-10-25 — Render and select branches by structure and node identity (G7)

- Render a branch's first-child continuation and sibling alternatives directly
  from the tree, without parsing variation keys or using them to pick children.
- Carry immutable node IDs in stored-variation caret ranges. Move clicks select
  that node; variation prefixes select its real parent and remember the child.
- Derive remaining compatibility locations from node IDs; cursor lookup no
  longer parses encoded variation keys.
- Regress node-based caret ranges before and after shared-path shortening,
  alongside nested/Black-start navigation and existing annotation filters.
- Validation: topology, PDN filtering, preservation, cursor and GTK checks pass.

### 2026-10-25 — Reuse explored nodes as first-child main continuations (G7)

- Find an existing child before adding a mainline move. Promote that same node
  to the first-child position, retaining its ID, comments, analysis and descendants.
- Keep earlier alternatives after a later mainline insertion; avoid duplicate
  move children when an explored continuation becomes the official line.
- Regress promotion of two successive moves, metadata retention and insertion
  after alternatives already exist.
- Validation: promotion regression fails before the fix; topology, actor,
  preservation, cursor and GTK main-form checks pass.

### 2026-10-25 — Apply complete runner history to game-tree nodes (M1, consumer)

- Attach each completed search to its parent position, and each move's elapsed
  time and post-move clocks to that move's node. Keep live clocks separate.
- Apply history during batched append, full rebuild and same-position updates;
  include metadata in rebuild/update signatures and copy command-owned arrays.
- Export per-move elapsed time with clock annotations.
- Regress batched updates, metadata-only rebuilds, command-copy isolation and live
  versus historical clocks. A real two-engine game finishes before any GUI update
  to verify that coalescing preserves both searches, move times and clocks.
- Validation: the GUI regression fails with the history bridge omitted; the full
  headless suite and expanded GTK main-form checks pass with it connected.

### 2026-10-25 — Carry complete move data in runner snapshots (M1, producer)

- Capture each completed move's analysis, score, depth, search time, seconds used
  and both post-move clocks before clearing engine search fields.
- Include independent, complete move-data arrays in every runner snapshot and
  snapshot copy, so coalescing GUI updates cannot discard earlier move metadata.
- Regress multiple engine moves around a human reply, per-move analysis isolation,
  both clocks, rejected human input timing and independent snapshot copies.
- Validation: expanded engine-clock and runner lifecycle checks pass.

### 2026-10-25 — Build large tournament saves in linear passes (F5)

- Stream JSON arrays/objects, the combined PDN and each game's movetext instead
  of repeatedly copying their growing text. Keep the complete authoritative
  records, readable JSON, immediate atomic saves and existing failure handling.
- Regress nested JSON types, Unicode/escaping, full large-game comments and the
  final record in a 1,000-game tournament. Add an optional two-second autosave
  check (`tests/run_tournament_checks.sh --performance`).
- The 1,000-game, 10 KB-per-game fixture fell from 3,773 ms to about 270 ms here.
  Disk writes still occur synchronously; this change removes the measured growth
  problem without delaying recovery saves.
- Validation: full headless suite, both GTK suites and the large-save check pass.

### 2026-10-25 — Adjudicate flag fall before granting the next period (D14)

- Check the current period's clock before adding the next period's allowance.
  A late boundary move loses on time without changing the board or move history.
- Retain the applicable increment policy used by engine deadlines.
- Regress both colors, human/engine move sources, exact expiry, overspending and
  successful in-time boundary moves receiving their next period.
- Validation: boundary regression reproduces the old rescue; expanded engine clock checks pass.

### 2026-10-25 — Interrupt stuck annotators and report worker errors (D13)

- Request engine cancellation before waiting for annotator shutdown, including
  while a position change is waiting for an unresponsive engine's stop fence.
- Protect engine lifetime against shutdown races; stop draining pending commands
  after termination. Report worker exceptions and always deliver the finished event.
- Regress ignored stop commands, explicit failure logs, finished callbacks, clean
  exception handling, repeated immediate shutdown and shutdown after launch failure.
- Validation: the ignored-stop regression reproduces the old delay; expanded
  annotator shutdown and position checks pass.

### 2026-10-25 — Make tournament PDN paths portable (T13)

- Store PDN paths relative to the JSON. Moving a tournament folder keeps its PDN
  linked; older absolute paths still work when their directory exists.
- Rebuild beside the loaded JSON when the recorded directory is missing, using
  an unused filename to preserve existing archives.
- Regress folder moves, resumed result edits, missing legacy directories and
  collision-safe fallback, alongside existing ownership protections.
- Validation: relative-path regression fails before the fix; GTK tournament suite passes.

### 2026-10-25 — Move recovery files on the first named tournament save (T12)

- Publish the JSON and a separate, collision-safe PDN beside the chosen save
  location before removing the old recovery files. Preserve recovery files and
  in-memory paths if saving fails. Later Save As keeps an established PDN path.
- Regress failed and successful first saves, unrelated PDN collisions, recovery
  cleanup, reloading results and subsequent Save As behavior.
- Validation: regression fails without relocation; expanded GTK tournament suite passes.

### 2026-10-25 — Isolate malformed PDN variations instead of aborting files (P16)

- Skip variations whose numbered or annotated start is outside their parent line;
  retain the surrounding mainline, valid parent/sibling branches and later games.
  Record per-game import warnings instead of clamping a branch to another position.
- Diagnose unterminated and unmatched variation brackets. Respect parentheses in
  semicolon comments when finding a variation's closing bracket.
- Preserve warnings through streaming reads and game copies. Show counts and
  selected-game details in the PDN list, and write database import warnings to
  the import log while continuing to import valid mainlines.
- Regress multiple nesting depths, bad starts, damaged brackets, comment handling,
  buffered/streaming parity, cancellation, database continuation and GUI warnings.
- Validation: full headless regression suite and GTK main-form checks pass.

### 2026-10-25 — Position White variations correctly when Black starts (remaining P1)

- Correct numbered White-move conversion for Black-to-move FENs: move 2 follows
  the initial Black ply, and later White alternatives retain the same offset.
- Regress Black and White alternatives, a nested White choice, a later capture
  alternative, annotations and three model save/load cycles with legal replay.
- Exercise actual move-memo clicks on parsed Black-start variations and verify
  their boards follow the correct parent paths without mutating the game.
- Validation: model preservation and expanded GTK main-form checks pass.

### 2026-10-24 — Avoid adopting or overwriting existing tournament PDNs (T11)

- Choose an unused PDN target for a new tournament, including existing directory
  names and collisions with a legacy migration's suffixed filename.
- Persist whether a projection has actually been created. Unclaimed targets stay
  unclaimed across reloads; a file arriving later gets a new target instead.
  Older snapshots without an ownership marker also preserve their existing PDN.
- Publish the first PDN atomically without replacement, so a file created between
  path selection and publication cannot be overwritten. Continue atomically
  updating established tournament projections and repairing them on reload.
- Request overwrite confirmation when saving JSON over an existing file. Refresh
  action availability after an explicit save resolves a previous save failure.
- Regress empty saves beside archives, late arrivals, reload and correction,
  directory collisions, legacy migration collisions, ownership validation and
  exclusive atomic publication with failure cleanup.
- Validation: sixteen headless regression programs, source audit, both GTK
  regression suites and the full application build pass.

### 2026-10-24 — Preserve saved tournaments when resetting pairings (T10)

- Start a new tournament ID and separate storage files for Apply settings,
  round-robin recreation and Clear pairings. Leave the previous JSON and PDN
  untouched, including unnamed recovery tournaments.
- Build replacement pairings before resetting current state. Block destructive
  resets while a save error leaves results only in memory.
- Regress all three real dialog actions, cancel/confirm Clear, original file bytes,
  reopening played games with manual overrides, separate recovery generations,
  and reset attempts before and after failed-save recovery.
- Keep confirmation responses explicit in noninteractive GUI tests; unexpected
  dialogs still fail without opening a window.
- Validation: expanded GTK tournament preservation checks pass.

### 2026-10-24 — Share the cursor with the tree window and keep tests noninteractive

- Bind tree-window rows to immutable node IDs and their source tree. Tree clicks,
  memo clicks and Left/Right now share the board's cursor and selection. Metadata
  rows select their enclosing position; Escape resumes following the mainline.
- Ignore stale tree-window rows belonging to another game or removed nodes.
- Give GUI regression builds a noninteractive mode: unexpected dialogs raise a
  diagnostic before opening, and the tested tree window stays hidden. Normal
  application builds retain the interactive UI.
- Regress tree/memo/board agreement, nested parent/child navigation, Escape and
  unexpected-dialog failures. Update the browsing documentation.
- Validation: sixteen headless regression programs, source audit, both GTK
  regression suites and a full application build pass.

### 2026-10-24 — Retain rebuild variations only on surviving parent paths

- Carry existing variations into a rebuild only when their complete mainline
  parent path still exists. A shorter PDN reload no longer fails validation due
  to branches attached beyond its new end, or transplants them to replaced moves.
- Remove obsolete compatibility paths while preserving shared surviving nodes and
  their analysis. Remap explicit variation-PV targets when retained indexes change.
- Continue rejecting invalid branches explicitly supplied by a command.
- Regress shorter same-game reloads, changed parents, surviving node identity and
  explicit analysis targets after filtering; retain the existing topology checks.
- Validation: actor, validation, cursor, topology and preservation checks pass.

### 2026-10-24 — Reject malformed variation annotations atomically (G6)

- Validate encoded variation annotations during actor preflight, alongside their
  move sequence. Reject malformed JSON and mismatched annotation counts before
  storing a variation or applying a rebuild.
- Regress malformed text and wrong counts in both variation and rebuild commands;
  verify all existing headers, moves, metadata and revision remain unchanged.
- Validation: the actor-validation regression passes.

### 2026-10-24 — Make the structural browsing cursor a node ID

- Replace independently stored mainline ply, variation index and variation ply
  with a tree-scoped node-ID cursor. Derive legacy rendering coordinates on demand.
- Navigate real parents and children, retaining the selected branch when stepping
  back and forward. Keep temporary analysis-PV offsets separate from tree nodes.
- Follow the live tip explicitly; keep a selected node frozen as the game grows.
  If a selected node disappears, fall back to its nearest surviving ancestor.
  Never select a replacement merely because it occupies the same ply or line index.
- Return the created move's node ID from actor variation commands and use it when
  following edits. Guard background-tree reads from changing the displayed cursor.
- Regress nested navigation, shared-path changes, removal, replacement, tree changes,
  and live following. Verify board and memo selection through actual GUI events.
- Validation: sixteen headless regression programs and source audit pass; expanded
  GTK main-form checks pass.

### 2026-10-24 — Validate structural moves at the actor boundary (G6)

- Reject illegal, malformed and wrong-side moves, invalid variation bases and
  mainline holes before mutating the tree. Validate against the actual parent
  position, including nested branches and legal short-form multiple captures.
- Preflight complete rebuilds and variation lines before applying any prefix;
  validate snapshot and header changes before changing headers or annotations.
- Rejected commands leave nodes, metadata, revision and queued follow-up work
  intact. Add a dedicated regression covering every structural command path.
- Replace older impossible test sequences with legal alternatives while retaining
  their original preservation and topology assertions.
- Validation: focused actor, preservation and topology checks and both GTK
  regression suites pass.

### 2026-10-24 — Extend unfinished games and preserve completed mainlines (G5, U3)

- Allow board moves at the end of a pasted position or unfinished imported game
  to extend its mainline, including successive moves and an explicitly browsed tip.
- Keep earlier-position edits as find-or-create variations. Preserve the existing
  ability to extend a stopped game whose result is still unknown.
- Store moves after a completed result as continuation variations; never extend
  the official mainline or change its result. Keep alternative continuations too.
- Regress actual board clicks for pasted FEN, imported PDN, earlier alternatives,
  a stopped game, and a finished game with legal moves left after a loss on time.
- Validation: fourteen headless regression programs, source audit, main-form
  and tournament GTK regressions, and a full GTK application build pass.

### 2026-10-24 — Validate PV browsing and identify illegal continuations (A2)

- Validate each PV against its base position. Replay only its legal prefix, using
  validated moves so short-form multiple captures resolve correctly.
- Identify the first illegal move in the PV memo and restrict navigation and
  selection to the last legal position. Revalidate pending data when unfreezing.
- Regress wrong-side moves, impossible moves, malformed text, short captures,
  invalid suffix selection, warning reset and frozen pending updates.
- Validation: the expanded hidden GTK main-form regression passes.

### 2026-10-24 — Preserve the frozen PV board during game refreshes (A3)

- Let the PV browser exclusively update its mini board and popout. A main-game
  refresh no longer copies the game position over a selected PV position.
- Regress a PV selection followed by a full main-form refresh: the board and
  highlighted line remain paired, and Escape resumes the latest complete PV.
- Validation: the hidden GTK main-form preservation regression passes.

### 2026-10-24 — Keep tournament games and standings consistent (T2)

- Store played PDN, original result, explicit manual override and attempt history
  per pairing in the tournament JSON. Retain moves, comments and nested variations.
- Regenerate PDN from current records instead of appending on completion. Repeated
  callbacks and resumed games cannot duplicate a pairing; rescheduling archives
  the previous attempt and removes it from the current PDN.
- Save authoritative JSON before PDN and repair stale or failed PDN output on load.
  Preserve older unlinked PDN archives separately when migrating legacy files.
- Validate the storage version, records and unique round/game identifiers before
  loading. Retain Swiss bye scores without creating fictitious PDN games.
- Regress record round trips, annotations, overrides, replay history, zero-move
  games, duplicate callbacks, failed PDN recovery, legacy archives and bye reloads.
- Validation: fourteen headless regression programs, source audit and GTK
  tournament preservation checks pass.

### 2026-10-24 — Autosave tournament standings and keep storage paths stable (T1, T5)

- Atomically replace tournament snapshots after pairing changes, registration,
  completion, manual results and rescheduling. Create recovery files for unnamed
  tournaments in the application config directory; Load starts there when needed.
- Persist tournament identity and the absolute PDN path. Renaming the tournament
  or saving its JSON elsewhere no longer redirects subsequent game records.
- Include tournament ID, round and game number in exported game records, including
  games that ended before their first move. Replace the PDN file atomically too.
- Release completed game references before saving. Pause scheduling on save errors,
  show the error in the tournament title, and retry pending saves on recovery.
- Regress atomic overwrite/failure cleanup, recovery in a fresh form, unnamed
  recovery files, stable paths, failed replacement and successful retry.
- Validation: thirteen headless regression programs, source audit and expanded
  GTK tournament checks pass.

### 2026-10-24 — Reject invalid tournament loads before changing current data (T7)

- Parse and validate tournament settings, engine selections and every pairing row
  before applying anything to the form. Reject malformed roots, wrong field
  types, invalid numeric settings and unknown result or pairing values.
- Enter the loading flag only after successful validation and always release it.
  Remember the selected file only after a successful load.
- Regress syntax errors, invalid document shapes and a bad field in a game row;
  verify existing settings/results remain byte-for-byte saveable and subsequent
  edits still trigger change tracking.
- Validation: the hidden GTK tournament preservation regression passes.

### 2026-10-24 — Ignore stale tournament callbacks and protect stopping games (T2c, T6)

- Apply completion callbacks only to active tournament game references. Removing
  an old finished game can no longer replace a manual result or undo rescheduling.
- Mark manual result changes explicitly, including overrides of played results.
- Guard pairing creation, clearing, loading and settings application while games
  are running or still stopping; disable the corresponding actions too.
- Add a hidden GTK tournament regression covering duplicate callbacks, manual
  overrides, rescheduling, pending shutdown and every destructive pairing action.
- Validation: the tournament preservation regression passes.

### 2026-10-24 — Use the game clock for engine move deadlines (D3)

- Derive clocked-game search deadlines from remaining time and the increment
  applicable to that move, with a small polling/transport margin. Replace the
  Hub and DXP adapters' fixed sixty-second waits with that supplied deadline.
- Stop and fence a timed-out Hub search; end and close a timed-out DXP session.
  Report expiry separately from engine failures and record a loss on time with
  clock usage, rather than an unfinished `*` result or runner error.
- Bound the entire DXP move wait, so extra packets cannot restart its deadline.
- Measure engine move elapsed time with a monotonic timer rather than wall time.
- Regress short-clock losses for both colours, increment timing, clocks longer
  than sixty seconds, timeout status reset and safe reuse after acknowledgement.
  Add a silent-peer DXP timeout case and run a real sixty-one-second Hub search
  successfully under a two-minute clock.
- Validation: twelve headless regression programs, source audit, eight local-TCP
  DXP integration cases, GTK check and the long-search regression pass.

### 2026-10-24 — Detect a disconnected DXP engine promptly (D5)

- Distinguish socket EOF and hard read errors from temporary receive timeouts.
  Also notice an exited engine process while retrying a transient read.
- Propagate disconnects as engine errors instead of silently polling until the
  move deadline; intentional Stop still interrupts the wait normally.
- Extend the local-TCP regression with a peer that disconnects after GAMEACC.
  Verify prompt detection, an unchanged board/history, and safe shutdown of the
  dead peer alongside all six result-claim cases.
- Validation: all seven local-TCP DXP integration cases pass.

### 2026-10-24 — Do not award results from unverified DXP claims (D4)

- Treat DXP GAMEEND win and draw reasons as peer information, retaining them in
  the engine log without awarding a result in a nonterminal position.
- Continue accepting an explicit resignation as a loss for the engine that sent
  it. Terminal positions, draw rules and clock adjudication remain with the GUI.
- Add a self-contained fake DXP peer over local TCP and exercise both engine
  colours, win/draw/unspecified claims, resignation and GAMEEND acknowledgement
  through the real adapter and orchestrator.
- Validation: the six local-TCP DXP integration cases pass.

### 2026-10-24 — Prevent broken DXP sockets from terminating the process (D2)

- Suppress SIGPIPE on accepted and connected DXP sockets: use MSG_NOSIGNAL on
  Unix send operations and SO_NOSIGPIPE on macOS, leaving global signal handling
  unchanged. Broken writes remain ordinary exceptions handled during shutdown.
- Add an isolated-child socket regression with SIGPIPE restored and unblocked.
  Confirm a raw broken write receives SIGPIPE and a configured socket reports a
  write error without terminating the process.
- Validation: eleven headless regression programs, source audit and GTK check pass.

### 2026-10-24 — Reject stale human input without ending the game (M2)

- Validate human commands against the runner's current board before playing them,
  and pass the resolved canonical move to the orchestrator.
- Log a rejection and publish the unchanged position for illegal or stale input.
  Keep the human turn's elapsed time and continue accepting legal commands.
- Regress an illegal first move, a queued duplicate after the turn changes, and
  legal continuation in a real human-versus-human runner.
- Validation: the headless Lazarus lifecycle/runner regression passes.

### 2026-10-24 — Make PDN export read-only (remaining M4)

- Export running and standalone games directly from their current trees. Remove
  retained-snapshot synchronization during export and before annotator updates.
- Remove export-time writes from read-only header widgets. A requested event name
  overrides only the exported header, without changing the stored game.
- Regress repeated standalone exports and a running-game export with retained
  snapshot state that differs from its corrected tree; verify names, moves,
  analysis, terminal result, state and actor revision remain unchanged.
- Validation: ten headless regression programs, source audit and expanded GTK
  export/navigation/preservation check pass.

### 2026-10-24 — Stop score propagation during runner synchronization (G8)

- Report only the score stored on each node; empty positions no longer inherit
  an annotator score from the preceding move.
- Remove rendered score-text feedback and score-text equality checks from runner
  synchronization. Match move prefixes directly and preserve existing node data
  when appending moves or updating a matching snapshot's header and clock.
- Regress twenty refresh cycles with a single annotated position and verify all
  later score slots remain empty.
- Validation: ten headless regression programs, source audit and GTK check pass.

### 2026-10-24 — Keep analysis and historical clocks on their nodes (G3)

- Remove the per-ply and per-variation-index analysis and clock side tables.
  Scores, PVs, depth, search time, Auto Play and historical clocks now belong to
  the nodes that produced them and disappear when those nodes are removed.
- Retain metadata on unchanged and shared nodes during refreshes, including when
  a shared node receives a different compatibility variation address.
- Keep the current live clock separately from historical node clocks; record the
  initial clock on the root rather than transferring it onto a later move.
- Regress replacement, trimming/re-addition, clearing/reusing a variation index,
  rewriting a variation and refreshing a shared subtree. The new regression
  fails against the preceding commit and passes with this fix.
- Validation: ten headless regression programs, source audit and GTK check pass.

### 2026-10-24 — Verify nested branch navigation in the GUI

- Exercise actual move-memo clicks on nested moves and branch openings, then
  use Left/Right to verify the selected branch and legally replayed board.
- Assert that browsing leaves the exported game tree unchanged.
- Give the move memo and main board stable component names for the GUI test.
  Avoid requesting focus when the main form is hidden or cannot accept focus.
- Report unexpected GUI-test exceptions directly so they cannot leave a hidden
  regression process waiting for an error dialog.
- Validation: the expanded GTK navigation and standalone-preservation check passes;
  the preceding model changes also pass all ten headless programs and source audit.

### 2026-10-24 — Preserve nested variations as shared move nodes

- Consolidate legacy variation paths into parent-and-child move relationships.
  Shared prefixes now refer to the same nodes rather than cloned sibling lines.
  Keep legacy line indexes as compatibility paths for existing callers.
- Export alternatives inside their enclosing variations, immediately after the
  moves they replace. Render shared prefixes once and retain nested click targets.
- Preserve analysis on shared nodes when importing another path. Shortening a
  compatibility path only removes nodes no remaining path references.
- Test nested parentage, shared identity, legal replay, stable refresh, analysis,
  safe trimming and clearing, and nested comments over three save/load cycles.
- Validation: ten headless regression programs, source audit and GTK check pass.

### 2026-10-24 — Follow move ancestry for board navigation

- Link mainline moves to their preceding positions and attach alternatives at
  their actual base position, independently of their legacy display slot.
- Build displayed boards and analysis move lists from node ancestry. Validate
  replay on a temporary board so an invalid continuation leaves the board intact.
- Correct move numbering for games that begin with Black to move.
- Add topology, legal replay, failed replay, trimming and Black-start regression
  checks. All ten headless programs, the source audit and GTK check pass.

### 2026-10-24 — Retain nested PDN continuation paths (P3)

- Recursively read nested alternatives instead of discarding them. Preserve
  each full path with its shared prefix and per-move commentary.
- The current line-based model stores these as sibling paths anchored to the
  mainline; export writes equivalent complete alternatives. Original nesting
  layout is flattened until the planned tree-topology consolidation.
- Test an outer alternative, a nested choice and a deeper choice with their
  comments over three save/load cycles.
- Validation: all nine headless regression programs, the source audit and
  the GTK preservation check pass.

### 2026-10-24 — Explore variations without truncating existing lines (G2)

- Replaying an existing mainline or variation move navigates to that node,
  preserving its continuation and avoiding duplicate variations.
- A different continuation inside a variation creates a separate branch with
  the shared prefix. Appending at the end extends only that branch and keeps
  existing comments and scores on their original prefix moves.
- Match stored variation lines by their complete move sequence, allowing two
  branches to share a first move without overwriting each other.
- Test replay, branching, mainline navigation, tail and comment preservation,
  and extension of the new branch. Update an old test that required truncation.
- Validation: all nine headless regression programs, the source audit and
  the GTK preservation check pass.

### 2026-10-24 — Keep the standalone board reachable and intact (U1)

- Keep a permanent Board entry in game history. Selecting it or removing the
  last running game restores the existing standalone tree without resetting it.
- Offer to save standalone content before replacement and before closing while
  another game is selected. Include FEN-only and annotated root positions.
- Capture the save target before opening the file chooser, so scheduling or
  selection changes while it is open cannot redirect the saved game.
- Add a GTK regression that exercises the actual hidden main form: load an
  annotated PDN or FEN-only position, start/select/stop/remove human games, and
  verify the original tree, commentary and variations remain intact.
- Validation: nine headless regression programs, the source audit and the
  GTK main-form preservation check pass.

### 2026-10-24 — Preserve PDN commentary and annotation positions (P2, P4)

- Retain free text, consecutive comments and text mixed with scores. Normalize
  comment line breaks so they cannot create extra move-annotation slots.
- Store introductory comments on the root and keep comments on every move of
  a variation, rather than retaining only its final annotation.
- Preserve these comments through both tree and legacy PDN exporters. Internal
  per-move annotation encoding is never written into exported PDN.
- Test three save/load cycles, mixed comments/scores, introductory text, first,
  middle and final variation comments, and multiline annotation alignment.
- Validation: all nine regression programs and the source audit pass.

### 2026-10-24 — Preserve PDN variation branch positions (P1, root export in G5)

- Keep the base ply inferred from a variation's move number unless explicit
  legacy metadata overrides it. Unnumbered alternatives replace the preceding
  move instead of starting after it.
- Export mainline alternatives after the move they replace, including root
  alternatives. Retain end-of-line continuations and variations on empty games.
- Test numbered and unnumbered imports and save/load preservation of root and
  reply alternatives created through the GUI's actor commands.
- Validation: all nine regression programs and the source audit pass.

### 2026-10-24 — Keep variations with their original game (G4)

- Carry stored variations into a rebuild only when the game identity matches.
  Loading another game or starting FEN no longer imports the old game's lines.
- Test same-game refresh preservation, different games with identical moves,
  and a new FEN where the old root alternative is illegal.
- Correct an older regression assertion that required variations to survive
  a change of game identity.
- Validation: all nine regression programs and the source audit pass.

### 2026-10-24 — Materialize imported variations when they are stored (G1)

- Store a variation's text and create its move nodes in the same actor command,
  so imported lines are immediately visible to rendering and PDN export.
- Keep repeated storage of an unchanged, materialized line a no-op.
- Add a preservation regression program covering the full variation, its
  annotation, immediate export and unchanged-command revision handling.
- Validation: all nine regression programs and the source audit pass.

### 2026-10-24 — Wait for runner completion before editing a stopped game (M3)

- Gate mainline edits and variation exploration on the runner lifecycle,
  rather than treating a stopped or game-over tree as proof of completion.
- Reject new human input while Stop or removal is pending, so late runner
  snapshots cannot overwrite moves added during shutdown.
- Extend the lifecycle regression test across starting, running, stopped,
  game-over, finished and removal states. Stopped and completed snapshot headers
  remain read-only until the runner's finished event has been handled.
- Validation: all eight regression programs and the source audit pass.

### 2026-10-24 — Preserve completed results when Stop is requested (M4)

- Leave terminal snapshots unchanged when Stop is requested, preserving a
  completed game's result and an existing error instead of replacing them
  with a stopped `*` result.
- Add a headless Lazarus lifecycle test that runs a real zero-clock human game
  to completion, then requests Stop before marking its model finished and
  checks the snapshot data used to update the tree.
- The main regression sweep runs this check when Lazarus is installed and
  reports a skip otherwise. No display server is needed.
- Validation: all eight regression programs and the source audit pass.
- Reapplying stored snapshots during export remains separate model work;
  this change addresses the completed-result loss reported in M4.

### 2026-10-24 — Fence stopped Hub searches before reuse (D1)

- Wait up to ten seconds for the stopped search's `done` response instead of
  treating an unacknowledged stop as success after two seconds.
- On failure, report an error and reject new positions, analysis, MCTS and
  thinking searches until the engine is relaunched. A late response cannot
  become a move for a different position.
- Add a fake-engine regression test for a slow acknowledgement and a missing
  acknowledgement, checking both the next move and rejection of unsafe reuse.
- Validation: all seven regression programs and the source audit pass.

### 2026-10-24 — Keep analysis attached to its searched position (A1)

- Stop the previous search and clear its engine analysis by setting the new
  position before switching the snapshot's board, node and search reference.
- Clear analysis for terminal positions too, so they cannot inherit a previous
  position's PV, score, depth or time.
- Add a self-contained fake Hub engine test covering position changes during
  analysis and MCTS, one-shot searches and terminal snapshots. No Python or
  installed engine is required.
- Move the change history into this file and link it from the README.
- Validation: all six regression programs and the source audit pass.

### 2026-10-24 — Preserve the board when a FEN is rejected (R4)

- Parse the side to move into a local value and apply it only after the entire
  FEN succeeds, keeping the current position and legal moves consistent.
- Test bad squares, ranges and sections for both sides to move, preservation
  of recorded moves, and successful play and position loading after rejection.
- Validation: all five regression programs and the source audit pass.

### 2026-10-24 — Preserve the board when a move is rejected (R2)

- Apply move changes to a temporary square array, so invalid destinations or
  captures leave the pieces, turn, move history and legal moves intact.
- Add regression cases for occupied and out-of-range destinations, missing,
  invalid and repeated captured squares, and continued play after rejection.
- Validation: all five regression programs and the source audit pass.

### 2026-10-24 — Preserve kings in saved positions (R1)

- Export one FEN section per colour and prefix every king with `K`, preserving
  multiple kings when positions are copied, saved and loaded again.
- Test mixed men and kings, kings-only positions, empty sides, both sides to
  move, and unchanged legal moves after a FEN round trip.
- Validation: all five regression programs and the source audit pass.

### 2026-10-24 — Reconcile the repository and retire manual publishing

- Merge the local and GitHub histories, preserving both repositories' files,
  and configure local `main` to track GitHub's `main` branch.
- Remove the manual publishing directory, its source-copy filter and ignore
  rule, and the byte-for-byte duplicate `MANUAL.md.txt`. Keep `MANUAL.md`.
