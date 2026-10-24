# Change history

Entries are newest first. Review IDs refer to the code review of commit
`98da11d`; they identify individual fixes, not release versions.

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
