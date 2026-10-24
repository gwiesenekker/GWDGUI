# Change history

Entries are newest first. Review IDs refer to the code review of commit
`98da11d`; they identify individual fixes, not release versions.

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
