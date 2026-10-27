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

The sweep also compiles `running_game_lifecycle_check.pas` directly with FPC.
It exercises the extracted running-game/message units and real runners without
Lazarus/LCL or a display. Run it separately with
`bash tests/run_lifecycle_checks.sh`. This is also a dependency check: importing
these units must not pull in the main form or setup dialog. The source audit
needs ripgrep.

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
The topology check also verifies that replacing, trimming or clearing moves
cannot transfer their analysis or clocks to another node, while unchanged and
shared nodes retain their metadata through refreshes and path-index changes.
The GTK check also verifies read-only standalone and running-game exports,
including event-name overrides and preservation of model content and revision.
The lifecycle check also sends illegal and stale duplicate human commands to a
real runner, verifies rejection without game failure, and continues legal play
without resetting the human clock.
`socket_disconnect_check` tests broken Unix sockets in isolated subprocesses,
verifying per-socket SIGPIPE protection without changing the application's
global signal disposition. It reports a skip on Windows.

Run `bash tests/run_dxp_checks.sh` with local TCP access to exercise the real DXP
adapter and orchestrator against a self-contained fake peer. It verifies that
win/draw claims cannot award results while resignations retain their meaning
for both colours. Output and executables stay in `/tmp/gwdgui-dxp-checks`.
The DXP check also disconnects the peer immediately after GAMEACC, verifying
prompt error detection, unchanged game state and safe shutdown.

`engine_clock_check` uses a self-contained fake Hub engine to check clock-derived
deadlines, both colours' time losses, increment timing, stopping/fencing and reuse
after a timed-out search. After the regular sweep, run
`/tmp/gwdgui-regression-checks/engine_clock_check --long-check` to verify that a
real 61-second search succeeds with a two-minute clock. The DXP integration
check also tests a silent peer's clock deadline and loss on time.

Run `bash tests/run_tournament_checks.sh` with GTK2 and an X display for the
hidden tournament-form regressions. They cover stale completion callbacks,
manual overrides, rescheduling and pairing actions during pending shutdown.
All generated binaries, preference files and fixtures stay outside the repo.
The tournament checks also cover failed-load isolation, autosave recovery in a
fresh form, stable PDN paths, unnamed recovery files and failure/retry behavior.
`atomic_file_check` verifies replacement and cleanup after a failed atomic save.

`main_form_boundaries_check` runs as part of `run_gui_checks.sh`. Before the
main-form extraction it characterizes actual source/target capture clicks,
all-square board flipping via the keyboard, cancel/decline replacement prompts,
and preservation when switching from a standalone board to a running game.
Its self-contained fake Hub engine exercises Auto Play on a stopped historical
node, late replies after Stop, and MCTS open/close/reopen with queued shutdown.
Test-only seams expose queue delivery and current runner/search identities; the
capture chooser test operates its actual list and buttons. The existing GTK
suites remain intact.
The lifecycle check also counts queued snapshot destruction and verifies that
running games own independent setup definitions, reservations and snapshots.

`move_interaction_check.pas` covers legal source/target selection, capture ordering,
explicit same-target capture choices, selection clearing, routing between
mainline, variation and live runner moves,
and last-move/PV highlight data.

`displayed_position_check.pas` covers selected nested paths, temporary preview
replay and atomic failure, inactive-game projection, cursor fallback and
revision-scoped replay caching through nested display refreshes.

`notation_presentation_check.pas` checks presenter text/ranges against the PDN
renderer for every filter combination, capture captions and label invalidation.
It also covers nested branch/PV hit targets, selection endpoints, preview click
restrictions and automatic/focused highlight ranges. Its export fingerprint
remains pinned independently of display-layout changes.

`notation_analysis_order_check.pas` covers analysis after the played continuation,
empty/tip fallbacks, White/Black starts, all PV source filter combinations and exact
preview base/ranges. The GTK boundary check clicks relocated engine/annotator PVs
in both full-line and first-move-only modes and compares their boards with replay.

The GTK standalone preservation check also exercises memo caret/selection edges
and confirms that hiding/restoring annotations rebuilds ranges, preserves the
selected board and leaves the exported tree unchanged.

`analysis_coordinator_check.pas` covers analysis search identities, active/stale
snapshots, cancellation and queued release, snapshot coalescing keys, independent
analyzer/MCTS restart signatures and historical/terminal analysis policy. It also
checks Auto Play historical-node attachment, command preparation/acceptance,
preview accumulation, rejected targets and stop/restart identity fences. PV-state
checks cover copied bases, nested identities/fallbacks, latest-PV selection and
complete display-cache keys. Request/snapshot checks cover cross-game cancellation,
unchanged-position suppression, terminal and transient search eligibility,
snapshot publication targets, stale rejection and transient display isolation.

GTK notation-tree checks cover each model node exactly once in both layouts,
variation headers, selection/expansion retention, game isolation, popup switching
and standard capture captions. Caption traversal is also bounded by node count.

`game_tree_index_check.pas` checks live/stale IDs through repeated structural edits.
`pdn_batch_import_check.pas` compares batch import with the previous validated
per-node path, including nested/invalid variations, metadata, capture aliases,
payload ownership and a 200-ply line with one validation per visited move.

`gui_delivery_check` runs in the GTK suite. It feeds the real GUI consumer full
and live snapshots produced by a human runner, interleaves games and analysis
searches, checks flush-before-completion ordering and the 100-event timer budget,
counts payload destruction, and exercises cancelled searches, removal and form
shutdown. The main-form boundary check injects old analyzer/MCTS completion
notifications while a current runner remains active.

For reproducible opt-in headless performance measurements, run
`bash tests/run_performance_checks.sh`. See [PERFORMANCE.md](PERFORMANCE.md) for
the fixture, timings, output fingerprints, compiler settings and comparison
procedure. These timings are not pass/fail limits in the regression suite.

`help_menu_check` exercises File/Database/Help shortcuts, Quit save/cancel
behavior, opening/reopening the embedded manual, case-insensitive search,
next/previous wraparound, Unicode selection offsets, keyboard controls and
About's embedded commit. It runs in the GTK suite. `build_info_check.py` compiles
generated build data with FPC and checks clean/modified Git identities, source
archives, Unicode/apostrophes and exact manual text, plus the direct IDE fallback.
The headless sweep runs it automatically. Isolated Lazarus builds regenerate
embedded data and rebuild project units so commit/manual changes cannot reuse
stale unit files.

`runner_early_stop_check` repeatedly stops runners before their first execution
and immediately after Start. It verifies actual termination, worker-thread
completion exactly once, and no duplicate on disposal for games and analyzers.
The GUI suite retains real form destruction/stop and annotator reservation checks.

PDN identity checks include nested sibling-board restoration and conflicting
metadata warnings, including the database import log. Board checks cover direct
copy construction, legal capture paths and independent history. The performance
harness also measures parsing and canonical PDN storage (`pdn_storage`).

`performance_archive_check.py` runs the actual benchmark from a Git-less copy,
asserting unknown metadata and successful operations without Git error output.
The Help check accepts the explicit archive identity; build-info tests also guard
against borrowing the identity of an unrelated enclosing repository.

The index regression additionally removes 20,000 synthetic internal nodes and
checks one lazy rebuild per batch, stale/surviving IDs, new nodes added before
rebuilding, and bulk takebacks. It uses work counts, not timing thresholds.
