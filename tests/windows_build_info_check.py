#!/usr/bin/env python3
"""Exercise the Windows build's native generator with real Git and compiled About."""
import os
import pathlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
from generate_build_info import generate


def run(args, **kwargs):
    result = subprocess.run(list(map(str, args)), stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, **kwargs)
    assert result.returncode == 0, result.stdout.decode(errors='replace')
    return result.stdout


with tempfile.TemporaryDirectory(prefix='gwdgui-windows-info-') as tmp:
    base = pathlib.Path(tmp)
    source = base / "Source with spaces Gérard"
    source.mkdir()
    run(['git', 'init', source])
    run(['git', '-C', source, 'config', 'user.email', 'test@example.invalid'])
    run(['git', '-C', source, 'config', 'user.name', 'Build regression'])
    manual = source / 'MANUAL.md'
    manual.write_bytes("# Player's guide\r\nUnicode — 棋\r\n".encode())
    run(['git', '-C', source, 'add', 'MANUAL.md'])
    run(['git', '-C', source, 'commit', '-m', 'Fixture'])
    run(['git', '-C', source, 'tag', 'v-test'])
    run(['fpc', '-B', '-FU'+tmp, '-FE'+tmp, ROOT / 'tools/generate_build_info.pas'])
    helper = base / 'generate_build_info'
    generated = base / 'gwdgui-build.inc'
    expected = base / 'expected.inc'
    program = base / 'check.pas'
    program.write_text('''program check;
{$mode objfpc}{$H+}
uses uAppInfo;
begin
  WriteLn(AppAboutText);
  WriteLn('---MANUAL---');
  Write(AppManualText);
end.
''')
    for case in ['clean', 'dirty', 'empty', 'nested archive', 'no git']:
        root = source
        env = os.environ.copy()
        if case == 'dirty':
            manual.write_text("Changed player's manual — αβ", encoding='utf-8')
        if case == 'empty':
            manual.write_text('')
        if case == 'nested archive':
            root = source / 'archive'
            root.mkdir()
            (root / 'MANUAL.md').write_text('Archive manual\n')
        if case == 'no git':
            manual.write_text('No Git manual', encoding='utf-8')
            env['PATH'] = str(base / 'nonexistent')
        generated.write_text('stale output must be replaced')
        run([helper, root, generated], env=env)
        # Compare with the existing Linux generator's contract.
        from unittest import mock
        context = mock.patch('generate_build_info.git', side_effect=OSError()) if case == 'no git' else mock.patch.dict(os.environ, {})
        with context:
            generate(root, expected)
        assert generated.read_bytes() == expected.read_bytes(), case
        run(['fpc', '-B', '-dGWDGUI_EMBEDDED_HELP', '-Fu'+str(ROOT),
             '-Fi'+tmp, '-FU'+tmp, '-FE'+tmp, program])
        output = run([base / 'check']).decode('utf-8')
        about, embedded = output.split('---MANUAL---\n', 1)
        if case == 'empty':
            assert 'The manual is not included' in embedded
        else:
            assert embedded == (root / 'MANUAL.md').read_text(encoding='utf-8'), case
        assert ('Includes uncommitted changes.' in about) == (case in ['dirty', 'empty']), case
        if case in ['nested archive', 'no git']:
            assert 'unavailable (source archive)' in about, case
        else:
            assert run(['git', '-C', source, 'rev-parse', 'HEAD']).decode().strip() in about, case
    # Missing required inputs must stop the pre-build, rather than accepting stale data.
    manual.unlink()
    assert subprocess.run([str(helper), str(source), str(generated)],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0

project = ET.parse(ROOT / 'gwdgui.lpi')
mode = project.find("./ProjectOptions/BuildModes/Item2[@Name='Windows']/CompilerOptions")
assert mode is not None
assert '-dGWDGUI_EMBEDDED_HELP' in mode.find('Other/CustomOptions').get('Value')
assert 'lib/build-info' in mode.find('SearchPaths/IncludeFiles').get('Value')
command = mode.find('ExecuteBefore/Command').get('Value')
assert 'build_windows.cmd' in command and '$(CompPath)' in command
print('Native Windows build-info generator checks passed (host execution; Windows IDE still needs validation)')
