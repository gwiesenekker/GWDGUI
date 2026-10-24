# Regression Checks

Run the quick regression sweep from the project root:

```sh
tests/run_regression_checks.sh
```

The script compiles each standalone Pascal check into
`${TMPDIR:-/tmp}/gwdgui-regression-checks` and then runs it. This keeps new
compiled test binaries and units out of the source tree.

Current checks:

- `board_regression_check.pas`
- `analyzer_runner_shutdown_check.pas`
- `analyzer_position_check.pas` (self-contained fake Hub engine; analysis,
  MCTS, terminal positions and one-shot searches while changing positions)
- `hub_search_fence_check.pas` (slow/missing stop acknowledgements and safe
  rejection of engine reuse after synchronization fails)
- `pdn_regression_check.pas`
- `game_tree_pdn_filter_check.pas`
- `game_tree_actor_check.pas`
- `game_preservation_check.pas` (variation storage and game-content preservation)
- `source_audit_check.sh`

When `lazbuild` is installed, the sweep also builds and runs
`running_game_lifecycle_check.pas` with Lazarus's `nogui` widgetset. This tests
the actual running-game model and runner without opening windows or needing a
display. Run it separately with `bash tests/run_lifecycle_checks.sh`.
The lifecycle check requires Lazarus/LCL; the other checks need only FPC and
the source audit needs ripgrep.

Run `bash tests/run_gui_checks.sh` with Lazarus's GTK2 widgetset and an X display
to exercise the actual main form without showing its window. It verifies that
PDN comments/variations and FEN-only boards survive starting, selecting, stopping
and removing human games. Build output and preference files stay in `/tmp`.

`game_tree_topology_check` verifies parent chains, variation attachment, legal
board replay, failed-replay isolation, trimming and Black-start numbering.
The topology check also covers shared nested nodes, identity and analysis across
refreshes, and trimming one path without deleting another path's subtree. The
preservation check verifies nested PDN structure over three save/load cycles.
The GTK check also clicks nested moves and branch-opening parentheses, follows
the selected branch with Left/Right, compares the displayed board with legal
replay, and asserts that navigation does not mutate the exported tree.
