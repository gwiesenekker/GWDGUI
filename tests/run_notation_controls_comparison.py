#!/usr/bin/env python3
"""Build/run the isolated GUI prototype. Dependencies stay outside the checkout."""
import argparse
import pathlib
import subprocess
import tempfile
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PIN = '7bc09f8493b50b69ad29c0bb1966f1c804bc2719'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--richmemo', type=pathlib.Path, required=True, help='RichMemo checkout at the documented pinned commit')
p.add_argument('--lazarus', type=pathlib.Path, required=True, help='Lazarus source directory containing components/synedit')
p.add_argument('--output', type=pathlib.Path, default=pathlib.Path(tempfile.gettempdir()) / 'gwdgui-notation-controls')
p.add_argument('--widgetset', default='gtk2', choices=['gtk2', 'win32'])
p.add_argument('--interactive', action='store_true')
p.add_argument('--samples', type=int, default=3)
p.add_argument('--fixture', type=pathlib.Path, default=ROOT / 'tests/fixtures/performance-long.pdn')
a = p.parse_args()
assert a.samples > 0
rich = a.richmemo.resolve()
assert subprocess.check_output(['git', '-C', str(rich), 'rev-parse', 'HEAD'], text=True).strip() == PIN, 'Unexpected RichMemo revision'
a.output = a.output.resolve()
config = a.output / 'config'
config.mkdir(parents=True, exist_ok=True)
with (a.output / 'build.log').open('w') as log:
    for package in [a.lazarus / 'components/synedit/synedit.lpk', rich / 'richmemopackage.lpk']:
        subprocess.run(['lazbuild', '--pcp='+str(config), '--add-package-link', str(package.resolve())], check=True, stdout=log, stderr=subprocess.STDOUT)
    subprocess.run([sys.executable, str(ROOT / 'tests/build_lazarus_check.py'), a.widgetset,
                    str(a.output), str(ROOT / 'tests/notation_controls_compare.lpi')], check=True, stdout=log, stderr=subprocess.STDOUT)
exe = a.output / ('notation_controls_compare.exe' if a.widgetset == 'win32' else 'notation_controls_compare')
args = [str(exe), str(a.fixture.resolve()), str(a.samples)]
if a.interactive:
    subprocess.run(args+['--interactive'], check=True)
else:
    with (a.output / 'results.csv').open('w') as results:
        subprocess.run(args, check=True, stdout=results)
    print((a.output / 'results.csv').read_text())
    print('Build log and raw timings:', a.output)
