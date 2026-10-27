# Notation controls: GTK2 comparison, 2026-10-27

Source: prototype commit `a101da3`; Linux x86_64, Lazarus/LCL 4.8.0,
FPC 3.2.2, GTK2, DejaVu Sans Mono 11. RichMemo source:
`7bc09f8493b50b69ad29c0bb1966f1c804bc2719`. Three samples, visible 760×600
host. See [method and reproduction](../NOTATION_CONTROLS.md) and
[raw results](notation-controls-gtk2-2026-10-27.csv).

The existing performance-long.pdn fixture imports to 151 mainline plies,
25,597 displayed bytes, 285 variation/PV hit ranges and 813 style spans.
The importer reports 19 warnings for this existing fixture; all three controls
receive the same canonical tree. No importer changes were made for this test.

Median milliseconds per operation:

| Operation | TMemo (plain) | TSynEdit (styled) | RichMemo (styled) |
|---|---:|---:|---:|
| Full assignment/style refresh | 0.8 | 7.6 | 1,389.8 |
| Browse/select/scroll | 6.2 | 14.3 | 455.0 |
| Resize and wrap | 16.5 | 8.8 | 122.5 |
| Live score update/render/style/select | 17.8 | 17.2 | 1,043.0 |
| Cached unchanged refresh and repaint | 0.7 | 3.6 | 1.2 |

All controls passed exact text, style (where supported), representative native
selection/hit targets, shared click/key handlers, empty and Black-start games,
Unicode combining/non-BMP text, annotations hidden/restored, and text above 64K.
Tree/PDN exports were preserved. The shared headless document regression separately
checks every Unicode boundary and native-offset conversion.

SynEdit is the practical choice for the requested formatting. The plain memo
remains faster for browsing; these results do not claim SynEdit is universally
faster. RichMemo's direct per-span GTK2 formatting becomes costly on this fixture:
full-refresh sample averages rise from 966 to 1,390 to 1,902 ms as the widget is
reused. Its GTK2 backend creates a fresh GTK tag per SetTextAttributes call.
A debugger sample during selection was in GTK text layout/cursor selection.
This is evidence about this update strategy and backend, not every possible
RichMemo implementation. RTF parsing was not measured.

Per the user's preference, retain one font family/size. Colours and bold/italic
provide the distinctions. Native Windows correctness, typography and timings
remain to be checked; Linux results cannot establish those.
