# Change history

Entries are newest first. Review IDs refer to the code review of commit
`98da11d`; they identify individual fixes, not release versions.

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
