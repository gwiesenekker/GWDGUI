# Change history

Entries are newest first. Review IDs refer to the code reviews of commits
`98da11d` and `8ad88b5`; they identify individual fixes, not release versions.

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
