#!/usr/bin/env bash
# Compiles GWDGUI for 64-bit Windows from Linux, so Windows-only code paths
# ({$IFDEF MSWINDOWS}) are checked without a Windows host. Needs the FPC RTL
# and packages built for x86_64-win64 where fpc finds them; skips otherwise.
# The result is not run: this is a compile check only.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd -P)"
OUT_DIR="${TMPDIR:-/tmp}/gwdgui-windows-cross-check"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/probe"

echo "==> windows_cross_check (x86_64-win64, win32 widgetset)"
printf 'program probe; uses Windows, SyncObjs; begin end.\n' > "$OUT_DIR/probe/probe.pas"
if ! fpc -Twin64 -Px86_64 -FE"$OUT_DIR/probe" "$OUT_DIR/probe/probe.pas" > "$OUT_DIR/probe.log" 2>&1; then
  echo "skipped: no FPC units for x86_64-win64 (build the RTL and packages with OS_TARGET=win64)"
  exit 0
fi

fpc -B -Twin64 -Px86_64 -FU"$OUT_DIR/probe" -FE"$OUT_DIR/probe" \
  "$ROOT_DIR/tools/generate_build_info.pas" > "$OUT_DIR/generator.log" 2>&1 ||
  { cat "$OUT_DIR/generator.log"; exit 1; }

if ! GWDGUI_LAZBUILD_TARGET=win64:x86_64 python3 "$ROOT_DIR/tests/build_lazarus_check.py" \
  win32 "$OUT_DIR/app" "$ROOT_DIR/gwdgui.lpi" > "$OUT_DIR/app.log" 2>&1; then
  grep -E 'Error|Fatal' "$OUT_DIR/app.log" || tail -40 "$OUT_DIR/app.log"
  exit 1
fi

# The real Windows build mode, as build.bat and the IDE run it: a stand-in
# cmd.exe performs tools/build_windows.cmd's steps, so the project's pre-build
# wiring (Other/ExecuteBefore, $(CompPath), include paths) is exercised too.
COPY_DIR="$OUT_DIR/source"
mkdir -p "$COPY_DIR" "$OUT_DIR/fakebin"
git -C "$ROOT_DIR" ls-files -z | (cd "$ROOT_DIR" && xargs -0 cp --parents -t "$COPY_DIR")
cp -r "$ROOT_DIR/.git" "$COPY_DIR/.git" 2>/dev/null || true
cat > "$OUT_DIR/fakebin/cmd.exe" <<'FAKE'
#!/usr/bin/env bash
# Stand-in for: cmd.exe /C ""<project>\tools\build_windows.cmd" "<compiler>""
set -euo pipefail
args="$*"
[[ "$args" == *build_windows.cmd* ]] || { echo "unexpected pre-build command: $args"; exit 1; }
compiler="$(grep -oE '/[^" ]*(fpc|ppcx64)[^" ]*' <<<"$args" | tail -1)"
[[ -x "$compiler" ]] || { echo "pre-build did not receive the compiler path: $args"; exit 1; }
root="$GWDGUI_CROSS_ROOT"
out="$root/lib/build-info"
mkdir -p "$out"
fpc -B -FU"$out" -FE"$out" -o"$out/generate_build_info" "$root/tools/generate_build_info.pas" > "$out/generator.log"
"$out/generate_build_info" "$root" "$out/gwdgui-build.inc"
FAKE
chmod +x "$OUT_DIR/fakebin/cmd.exe"
# build.bat builds into lib/candidate/ through the Windows mode's target
# ($Env(GWDGUI_BUILD_DIR)gwdgui, review C12).
rm -f "$COPY_DIR/gwdgui.exe"
if ! PATH="$OUT_DIR/fakebin:$PATH" GWDGUI_CROSS_ROOT="$COPY_DIR" \
  GWDGUI_BUILD_DIR=lib/candidate/ lazbuild --build-all \
  --build-mode=Windows --no-write-project --os=win64 --cpu=x86_64 --ws=win32 \
  --pcp="$OUT_DIR/app/config" "$COPY_DIR/gwdgui.lpi" > "$OUT_DIR/mode.log" 2>&1; then
  grep -E 'Error|Fatal|unexpected|did not' "$OUT_DIR/mode.log" || tail -40 "$OUT_DIR/mode.log"
  exit 1
fi
[[ -f "$COPY_DIR/lib/build-info/gwdgui-build.inc" ]] ||
  { echo "the Windows build mode did not run its pre-build step"; exit 1; }
[[ -f "$COPY_DIR/lib/candidate/gwdgui.exe" ]] ||
  { echo "the Windows build mode produced no lib/candidate/gwdgui.exe"; exit 1; }
[[ ! -e "$COPY_DIR/gwdgui.exe" ]] ||
  { echo "the Windows build mode wrote gwdgui.exe instead of the candidate path"; exit 1; }

# build.bat's replacement logic under Wine's cmd.exe, when Wine is installed.
WINE=""
for candidate in wine64 wine /usr/lib/wine/wine64; do
  if command -v "$candidate" >/dev/null 2>&1; then WINE="$candidate"; break; fi
done
if [[ -n "$WINE" ]]; then
  echo "==> windows_build_bat_check (build.bat under Wine cmd.exe)"
  cp "$ROOT_DIR/build.bat" "$COPY_DIR/build.bat"
  cp "$ROOT_DIR/tests/windows_build_bat_check.bat" "$COPY_DIR/tests/"
  BAT_PATH="$(printf 'Z:%s/tests/windows_build_bat_check.bat' "$COPY_DIR" | sed 's#/#\\#g')"
  WINEPREFIX="${WINEPREFIX:-$OUT_DIR/wineprefix}" WINEDEBUG=-all \
    "$WINE" cmd /c "$BAT_PATH" 2>/dev/null |
    tr -d '\r' | tee "$OUT_DIR/build-bat.log"
  grep -q '^build.bat checks passed$' "$OUT_DIR/build-bat.log" ||
    { echo "build.bat checks failed"; exit 1; }
else
  echo "Wine not installed: skipping tests/windows_build_bat_check.bat (run it on Windows)"
fi
echo "Windows cross-compile check passed (gwdgui.exe built in both modes, not run)"
