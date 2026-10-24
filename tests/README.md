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
- `source_audit_check.sh`
