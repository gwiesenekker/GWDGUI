# GWDGUI

GWDGUI is a desktop application for **international draughts (10×10)**. It lets
players and engine authors play games, examine analysis, explore variations,
run engine tournaments and search game databases. It supports engines using the
**Hub** and **DXP** protocols, including GWD.

[Download version 3.4](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.4)
· [User manual](MANUAL.md)
· [Change history](CHANGELOG.md)

This README describes the current source tree. Changes made after the latest
tagged release are listed under [Unreleased](CHANGELOG.md#unreleased).

## Features

- Human-versus-human, human-versus-engine and engine-versus-engine games, with
  configurable time controls and multiple games in the game history.
- Legal move selection on the board or from a list, including a chooser for
  captures that share the same source and destination.
- Game-tree browsing with nested variations, comments, analysis and clocks;
  PDN import/export and FEN position setup, copying and pasting.
- Hub engine analysis and annotators, principal-variation browsing, Auto Play,
  score history, an evaluation bar and optional board hints.
- Single and double round-robin and Swiss tournaments, with concurrent games,
  saved standings, recovery files and PDN game records.
- SQLite game databases with PDN import, duplicate detection, player/event
  filters and position searches.
- Configurable board colours and notation styles, separate engine/annotator PV
  colours and a font chooser for the moves window.
- An offline, searchable manual under **Help → Manual** and the build commit
  under **Help → About GWDGUI**.

## Download and run

The [version 3.4 release](https://github.com/gwiesenekker/GWDGUI/releases/tag/v3.4)
provides **Linux x86_64** and **Windows x86_64** portable archives, plus the
executables, draughts font and manual as separate downloads. Compare download
checksums with the release's `SHA256SUMS` file.

Extract the archive for your operating system into a writable directory. On
Windows, run `gwdgui.exe`. On Linux, run:

```sh
./gwdgui
```

Linux requires the GTK2 and SQLite3 runtime libraries. Keep `draughts.ttf` beside
the executable. GWDGUI also needs an independently installed draughts engine
for engine play or analysis; you can play human-versus-human games without one.

## Getting started

1. Open **Engines...**, add an executable and select its Hub or DXP protocol.
   Use **Launch engine** to test it, then **Launched correctly** to save it.
   See [Configuring engines](MANUAL.md#2-configuring-engines) for protocol settings.
2. Choose **New game...**, select the players and time control, and start play.
   Make a human move by clicking its source and destination, or choose a legal
   move from the list.
3. Select games in **Game History**. Click moves to browse; use Left/Right to
   navigate the focused notation, tree or PV view.
4. Use **Tournament...** for engine competitions, or the **Database** menu for
   collections and position searches.
5. Press **F1** for the full manual. **Ctrl+O** opens PDN, **Ctrl+S** saves PDN,
   **Ctrl+,** opens preferences and **Ctrl+Q** quits with the normal save prompts.

## Settings and saved files

Keep the application directory writable: `engines.json` and `prefs.json` are
stored beside the executable. Per-engine `.params.json` files are stored beside
the engine they describe. Save games, databases and named tournaments wherever
you prefer. Unsaved tournament recovery files use the operating system's per-user
configuration directory.

Engine paths are specific to the machine and operating system. Re-register or
edit engine entries when moving between Linux and Windows. For DXP, give each
simultaneous connection its own port.

See [File locations and portability](MANUAL.md#121-file-locations-and-portability)
and [Common problems](MANUAL.md#11-common-problems) for details.

## Build from source

Use **Lazarus/LCL 3.0 or later**, its bundled **SynEdit** package and
**Free Pascal 3.2.2 or later**. Keep the source directory writable and keep
`draughts.ttf` with the resulting executable.

### Linux

Install the GTK2 Lazarus development environment, SQLite3 runtime library and
Python 3, then run from the source directory:

```sh
bash build.sh
./gwdgui
```

The script compiles in a temporary directory, embeds the manual and Git identity,
and replaces the local executable only after compilation succeeds.

### Windows

With Lazarus installed, run:

```bat
build.bat
```

The script finds `lazbuild.exe` on PATH or in standard Lazarus installation
folders. You can supply its full path explicitly:

```bat
build.bat "C:\lazarus\lazbuild.exe"
```

It builds a candidate executable in `lib\candidate` and replaces `gwdgui.exe`
only after a successful build, preserving the previous executable on failure.
Alternatively, open `gwdgui.lpi` in Lazarus, select the **Windows** build mode
under **Project → Project Options → Build modes**, and choose **Build**.

The Windows build mode embeds the manual and Git identity without Python.
Install Git for Windows and make `git` available on PATH before starting the
build. A Git checkout identifies its commit; a source archive without `.git`
reports that identity as unavailable. Modified tracked files are marked in About.

The Linux build script and Windows build mode provide embedded help and identity.
The Lazarus **Default** mode instead loads `MANUAL.md` from beside the executable
and reports that build identity is unavailable.

## Checks

Run the headless regression suite from the source directory:

```sh
bash tests/run_regression_checks.sh
```

It requires FPC, Python 3 and ripgrep. GTK interface tests additionally require
Lazarus/GTK2 and a display:

```sh
bash tests/run_gui_checks.sh
bash tests/run_tournament_checks.sh
```

[tests/README.md](tests/README.md) describes the other checks.
`bash tests/run_windows_cross_check.sh` runs the batch recovery checks under
Wine when available, then attempts a Windows cross-build when FPC's win64 units
are installed. Missing tools or target units are reported as skips. Cross-building
and Wine tests do not replace native Windows testing.

## Project and license

GWDGUI is maintained by Gijsbert Wiesenekker and was developed using Codex and
Claude. Its tagged releases and commit history record the development from the
initial Lazarus GUI through the current application.

See [LICENSE](LICENSE) for the GNU General Public License, version 3.
