# Response to Claude's review of 9c958ec

Reviewed and addressed on 2026-10-25. Source: `claude/review-9c958ec.md`.
Changes are local commits; nothing has been pushed or released.

I agree with all thirteen new findings. R8 and D16 were the most urgent: a valid
ambiguous capture could break export, and an equivalent DXP capture order could
end a normal game. The medium findings also describe real failures or regressions,
not just style preferences. The new tests exercise the precise missing cases.
The game tree remains the source of truth throughout these changes.

| Review IDs | Resolution |
|---|---|
| R8 | Keep freshly generated legal PDN capture paths after playing a move. Regress ambiguous capture after ply 1 through both writers and database import. |
| D16/D10 | Compare DXP captures as source, destination and captured-square multiset. Regress a real TCP exchange with reordered captures. |
| M6 | Publish locked engine PV/score/depth/time and log updates on an immutable runner-owned position snapshot during thinking. The engine thread never reads the mutating orchestrator. |
| T19/T8 | Include arguments, initialization/INI and endpoint settings in engine identity. Persist arguments and INI fields. Resolve an old key only when unique. |
| T20/T5 | Persist capture failures per row, pause scheduling, retain retry/manual overrides, and allow unrelated edits, saving, game removal and explicit rescheduling. |
| F8 | Serialize complete database PDN without replaying every stored node. Reuse already validated canonical mainline moves; compress full PDN when smaller. Schema 5 reads old storage and protects it from older applications. |
| P22/P13 | Compare complete legacy candidates, upgrade duplicate identities lazily, and keep newly supplied comments/variations distinct. Regress v3/v4 rows and capture aliases. |
| P21/P15 | Write compact readable metadata without duplicating ordinary comments. Read old blobs; retain empty-PV depth/time fields, multiline layout and independent analysis after visible edits. Normalize file-join whitespace for edit detection. |
| T21/T4 | Replace exponential Swiss backtracking with maximum-cardinality matching using augmenting paths and odd-cycle contraction. Exhaustively check all six-player graphs against an independent oracle. |
| T3 | Keep round-robin colour runs to at most two in the tested 2–12-player fields, including mirrored double rounds, while preserving balance and pair coverage. |
| F9 | Write tournament JSON once per save, including durable row state when PDN publication fails; cache verified ownership to avoid reparsing unchanged files. |
| T22 | Adopt an older unfingerprinted PDN when it exactly matches the current projection and identity. Preserve unverifiable content with an accurate notice. |
| D18/D12 | Follow protocol.txt's literal Hub values. Backslashes remain literal; reject quotes/newlines that the grammar cannot represent. |
| U6/P18 | Display standard capture notation with correct click/highlight ranges; avoid redundant Black move numbers inside variations. |
| C4 | Include Windows access-denied errors in bounded publication retries. The error classification is regressed; native Windows execution remains unavailable. |
| D8 | Map localhost to loopback, reject invalid/unsupported listen hostnames, validate accepted peers and support an optional explicit peer address. Rejected clients do not stop the listener. |
| P10 | Run import on a worker-owned database connection. Poll locked progress from the modal dialog, with immediate Stop/close cancellation and no nested message processing in import callbacks. |
| Review notes | Launch auxiliary processes under the engine launch lock and protect their Unix pipes. Treat a zero startup timeout as the default. |

Each fix has regression coverage and a CHANGELOG entry. The agreed policy choices
in the older response below remain in place; the latest review explicitly accepts
them. No new finding has been silently deferred.

Two suggestions are deliberately qualified:

- **F9:** retain a content hash on every save rather than trusting file size and
  modification time alone. Rapid same-size edits can share a timestamp; the new
  regression proves they are preserved. Removing duplicate JSON writes and repeated
  parsing still reduces the local 1,000-game / 10 KB autosave benchmark from
  354 ms to 236 ms. This is a local measurement, not a release performance guarantee.
- **F4:** retain the bounded per-refresh validated-board cache. Replaying from the
  root remains correct; a persistent prefix cache would need additional revision
  and invalidation rules. This residual observation is an optimization, not another
  correctness repair.

Verification: the complete headless suite, worker/lifecycle and mutation-audit
checks, GTK main/tournament suites, real TCP DXP suite and application build pass
on Lazarus 4.8 / FPC 3.2.2 / Linux. Native Windows and Lazarus 3.0 runs are still
unavailable. The review's full 136 MB database benchmark has not been rerun, so
no claim is made that its original import time or file size has been restored.

---

# Response to Claude's review of 3678ba3

Reviewed and addressed on 2026-10-25. Source: `claude/review-3678ba3.md`,
with the earlier reviews consulted for the definitions of carried-over IDs.
All changes are local commits; nothing has been pushed or released.

Claude's main assessment is sound: the game tree is now the source of truth,
with node-owned data, parent/children relationships, a node-ID cursor and actor
validation. The new findings identify real regressions around that consolidation,
particularly tournament ownership, PDN boundaries, analysis round trips and parsing
cost. Those deserved fixes before adding features. Some remaining labels describe
policy choices or possible optimizations rather than incorrect current behavior.

## Changes made

| Review IDs | Result |
|---|---|
| T17, T16 | Verify tournament ownership and the last published content fingerprint. Preserve unrelated, externally edited or unverifiable PDNs and publish to a fresh path. Give unidentified legacy tournaments independent identities. |
| T5, T18 | Retain failed finished-game captures for explicit retry, stop unsafe publication/scheduling, and reuse empty storage generations. |
| T3, T4 | Balance round-robin colours and assign actual rounds. Try bounded backtracking before repeated Swiss opponents; describe fallback honestly. |
| T8, T15 | Resolve saved rows by persistent engine identity. Clearing a manual result restores the played result. |
| P7/P19 | Keep header gaps and duplicate result fragments from splitting games. |
| P20 | Report illegal/rejected variation subtrees in the game list and loaded game status. Keep valid neighbours. |
| P15 | Restore typed PVs, scores, depths, times and clocks to their original nodes through a versioned PDN comment extension. Preserve real nested variations without turning every analysis PV into another stored variation. An edited readable comment wins over stale metadata. |
| P12, P18 | Fix legacy Black-start numbering and escaping; preserve literal marker-like comments and comment-only RAV text with a warning. |
| P10, P11 | Make database import modal, cancellable and guarded against reentry. Append PDN without rewriting the existing archive. |
| P13 | Store complete PDN, include annotations/branches in duplicate identity, migrate the schema, and protect existing files and future schema versions. Legacy rows retain the data they already contain; migration cannot recover content discarded by an older import. |
| P14 | Preserve database UTF-8 text and use Unicode lowercasing for literal name/event searches and sorting. |
| R5, R6, U4 | Accept standard landing-square capture paths, export standard captures, tighten move parsing, and reject overlapping FEN squares atomically. Regenerate moves when the side changes. |
| R7 | Apply five- and sixteen-move endgame limits, including capture without restarting the sixteen-move limit and terminal-win precedence. See [FMJD Annex 1, articles 6.3–6.4](https://www.fmjd.org/docs/Annex_1.pdf). |
| M5 | Build runner snapshots only on the runner's owning thread. |
| D6, D7, D9 | Correct DXP minute conversion and Hub increments/sudden-death clocks; configure cold-start deadlines without losing cancellation. |
| D8, A7 | Bind DXP to the configured interface, defaulting to loopback, and protect listener/socket lifetimes across threads. |
| D10 | Track exact exchanged DXP history and reject changed prefixes, takebacks or skipped exchanges before silently desynchronizing. Starting a new game explicitly recovers. |
| D11, D12 | Isolate engine pipes, retain partial packets, enforce packet bounds, validate MOVE fields, clamp Fischer fields, and correct Hub/Windows quoting. |
| D15 | Keep cancellation effective throughout annotator launch. |
| A4–A6 | Show browsing/pending PV state, evaluate the selected position, and stop treating arbitrary comments as scores. |
| U5 | Blank an unbuildable board, show a visible diagnostic, cancel analysis and disable Auto Play. Valid navigation restores the board. |
| F1, F6 | Bound retained engine output and remove unread buffers. Replace character-by-character parsing and redundant ownership copies. |
| F2, F4 | Defer archive move trees until selection and reuse independently copied validated boards within one refresh. |
| C4, C6 | Use wide Windows publication APIs with sharing-error retries and an exclusive-publication fallback on filesystems without hard links. |
| C5 | Build isolated Lazarus checks without newer `--opt` dependencies; make their noninteractive requirement explicit. |
| C1, C2 | Extend mutation auditing and remove proven-unused legacy helpers, an unused setting and a misspelled command alias. |
| C3 | Ignore numbered local engines and runtime files, stop tracking local preferences/tournament output without deleting them, and add `build.sh`. Keep the generated manual as an intentional documentation deliverable. |

Each correctness change has focused regression coverage and a CHANGELOG entry.
The tests exercise actual GTK main/tournament forms, fake Hub processes and a real
local TCP DXP peer, in addition to headless board/parser/model/storage tests.

## Suggestions retained or qualified

- **D3:** Keep the bounded Hub stop fence. It prevents a late reply from entering a
  later search and runs on a worker. A timeout result can still wait for that fence;
  removing it without a replacement synchronization scheme would reintroduce D1.
- **D4:** A peer's unverified draw/win claim is still recorded diagnostically and
  ends an unfinished game as `*`. A resignation concedes a loss. Local draw rules
  now include R7, but a peer claim alone is not proof of a draw.
- **D12:** Keep zero-capture MOVE packets: `00` is required for quiet moves. Invalid
  captured square `00` is rejected. Keep bounded GAMEEND/acknowledgement teardown
  on forced stop; the silent-peer test covers that behavior. This is a deliberate
  shutdown choice, not a claim that the peer completed its turn.
- **T9:** Keep replay/rescheduling explicit. Automatically restarting every `*`
  caused by an unavailable or failing engine could create an endless retry loop.
- **T16:** Retain clearly tagged standings-only PDN records for manual/legacy
  results. Inventing moves or silently omitting those results would be worse.
- **P12:** Keep compatible `1-0`, `1/2-1/2`, `0-1` export spellings and accept both
  families on import; preserve `0-0`. Changing the public result convention is a
  separate interoperability decision.
- **P18:** A comment after a RAV belongs to the surrounding position in the node
  model. A comment-only RAV is retained as text with a diagnostic; it does not
  create a fictitious move node.
- **U4:** Keep empty-side/constructed FENs available for terminal-position analysis.
  Do not impose game-start legality on every analysis setup. Duplicate squares
  and malformed input are rejected.
- **R3:** Keep the unvalidated board operation for internal generated/canonical
  moves. Application input and tree paths are validated before reaching it.
- **C1:** Model mutators remain public Pascal APIs. The actor boundary is enforced
  in application paths and audited by tests, not by a new access-control design.
  The audit is a guardrail, not a proof against arbitrary future misuse.
- **C2:** Keep the protocol-neutral message adapter exercised by integration tests;
  only confirmed-unused compatibility code was removed.
- **C3:** The application remains a portable, writable-directory installation.
  Moving all configuration into an operating-system profile is a packaging change,
  not part of this repair. The README now states that requirement.
- **F3:** Index creation uses `IF NOT EXISTS`; imports no longer drop/rebuild those
  indexes. Continuation summaries still rebuild after import to maintain the P9
  interrupted-import guarantees. Incremental summaries remain an optimization.
- **F7:** Keep complete immutable/coalescible snapshots. Claude's measured cost is
  small at ordinary game lengths; a delta/acknowledgement protocol needs separate
  recovery semantics and is not justified as a correctness repair.

## Verification and limits

- Full headless regression suite, source audit and Lazarus lifecycle check pass.
- GTK main-form and tournament suites pass, including repeated analysis round trips,
  modal import reentry, external PDN edits and replay-cache invalidation.
- Real TCP DXP, engine clock/protocol, child-pipe inheritance and forced no-hard-link
  publication checks pass.
- The application builds with Lazarus 4.8.0 / FPC 3.2.2 / GTK2 on this Linux host.
- The same 10 MB / 1,000-game fixture lists lazily in 21 ms versus 84 ms eagerly;
  the earlier character-based reader took about 762 ms. These are local measurements.
- Autosaving 1,000 tournament games with 10 KB each takes 354 ms on this host.
- Native Windows execution and Lazarus 3.0 execution are not available here.
  Windows-specific API/handle changes need a native release smoke test. The build
  helpers avoid the newer lazbuild option that caused Claude's 3.0 failure.

The remaining qualified items above are not being silently marked fixed. No push,
version bump or release has been performed.
