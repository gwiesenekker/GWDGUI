# Reproducible headless benchmarks

Run from any directory with FPC, Git, `sha256sum` and a POSIX shell:

```sh
bash /path/to/GWDGUI/tests/run_performance_checks.sh
```

Defaults are **100 notation renders, 10 actor imports, 30 board replays, three
samples**. To choose counts, supply those four numbers in that order:

```sh
bash tests/run_performance_checks.sh 100 10 30 5 > /tmp/gwdgui-performance.csv
```

The script builds all units with FPC `-B -O2` in a unique temporary directory,
prints the source revision, tracked-change marker, compiler version, host and
fixture SHA256, then removes its build files on exit. No Lazarus, GUI, engine,
network service, untracked `claude/` file or previously built unit is needed.
MD5 values are output comparison fingerprints, not security checksums.

## Workload and interpretation

`fixtures/performance-long.pdn` is the unchanged 151-ply annotated engine-game
fixture supplied with Claude's `fbf8316` profile. Its SHA256 is
`aafdd8d6d325f0216e62e648d99c3ed853f671e60c8f63ed1924c1aa4c32d1f5`.
The fixture deliberately retains the source's malformed variation paths so the
workload includes recovery; the current actor imports 406 move nodes and reports
19 warnings. Do not interpret it as a fixture with every branch legal.

The harness parses the file and builds/normalizes the PDN tree once before timing.
It warms each operation, then measures:

- **Board replay:** load the starting FEN and legally replay the 151 mainline plies.
- **Notation render:** render the already imported tree with default display
  filters and standard capture notation. Import, parsing and GUI painting are excluded.
- **Actor import:** create an actor, rebuild its mainline/header, import a cloned
  parsed tree with validation/recovery, and destroy the actor. Complete PDN export
  and hashing run outside the timed sections and must match the warm-up output
  on every iteration. Imported node and warning counts must also match.

CSV rows contain the sample, iteration count, total elapsed milliseconds,
milliseconds per iteration, output size and fingerprint. Replay/render output is
also checked against warm-up on each sample. Timing uses the monotonic millisecond
clock; use larger counts for faster workloads. There are no timing pass/fail limits.

Run performance measurements separately from builds and regression suites, with
similar host load, power settings, compiler and counts. Compare medians across at
least three samples. Compare counts and fingerprints first: a smaller output is
not a speedup unless the content change is intended. A nonzero warning count is
reported explicitly rather than silently treated as a clean import.

These measure the headless paths behind F10/F11/F12. They do not measure window
painting, input latency, engine throughput or live-update GUI load. The older
one-off timings in CHANGELOG.md used a different harness/build configuration and
should not be directly compared with these numbers.

## Initial baseline

Baseline source: runtime code at `20d3d42` (2026-10-26), FPC 3.2.2, Linux x86-64,
`-B -O2`. Timings below use the default counts and median of three samples.

| Operation | Iterations per sample | Median total | Median per iteration |
|---|---:|---:|---:|
| Board replay | 30 | 26 ms | 0.867 ms |
| Notation render | 100 | 345 ms | 3.450 ms |
| Actor import | 10 | 130 ms | 13.000 ms |

Measured separately after the validation suites finished; tracked documentation
changes were present, with runtime code unchanged from the revision above.

| Output | Bytes | MD5 |
|---|---:|---|
| Final board FEN | 10 | `ec08defc2e7c4968f2b88a11ab4d0347` |
| Rendered notation | 25,597 | `400b910e767fc83d770f5c4f5c21c94f` |
| Complete imported PDN | 34,191 | `f79d4ae293b7f45483111c5f45d7d997` |

Future changes may intentionally change these fingerprints; explain that change
before using the measurements to claim a performance improvement.
