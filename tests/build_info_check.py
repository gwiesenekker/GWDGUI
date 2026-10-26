#!/usr/bin/env python3
"""Compile generated build data and verify Git/archive/dirty cases end to end."""
import pathlib
import subprocess
import sys
import tempfile
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import generate_build_info

with tempfile.TemporaryDirectory(prefix='gwdgui-build-info-') as scratch:
    folder = pathlib.Path(scratch)
    source = folder / 'source'
    source.mkdir()
    program = folder / 'check.pas'
    program.write_text('''program check;
{$mode objfpc}{$H+}
uses uAppInfo;
begin
  WriteLn(AppBuildCommit);
  WriteLn(AppAboutText);
  WriteLn('---MANUAL---');
  Write(AppManualText);
end.
''')
    for index, (manual, git_results, expected_commit, dirty) in enumerate([
        ("# Manual\nDraughts player's guide — αβ\n", ['a'*40, 'v3.0-1-gaaaaaaa', ''], 'a'*40, False),
        ("Changed manual's last line", ['b'*40, 'v3.0-2-gbbbbbbb', ' M MANUAL.md'], 'b'*40, True),
        ("Source archive\n", OSError('no git'), 'unavailable (source archive)', False),
    ]):
        (source / 'MANUAL.md').write_text(manual, encoding='utf-8')
        with mock.patch.object(generate_build_info, 'git', side_effect=git_results):
            generate_build_info.generate(source, folder / 'gwdgui-build.inc')
        result = subprocess.run(['fpc', '-B', '-dGWDGUI_EMBEDDED_HELP', '-Fu'+str(ROOT),
                                 '-Fi'+str(folder), '-FU'+str(folder), '-FE'+str(folder), str(program)],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if result.returncode:
            raise AssertionError(result.stdout)
        output = subprocess.check_output([str(folder / 'check')]).decode('utf-8')
        about, embedded = output.split('---MANUAL---\n', 1)
        assert output.splitlines()[0] == expected_commit, 'embedded commit differs from build input'
        assert embedded == manual, 'manual text/Unicode/apostrophes/final newline changed'
        assert ('Includes uncommitted changes.' in about) == dirty, 'dirty build marker incorrect'
    # An IDE build without generated data must not pretend to identify a commit.
    result = subprocess.run(['fpc', '-B', '-Fu'+str(ROOT), '-FU'+str(folder),
                             '-FE'+str(folder), str(program)], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        raise AssertionError(result.stdout)
    output = subprocess.check_output([str(folder / 'check')]).decode('utf-8')
    assert 'unavailable (build with build.sh' in output
    assert 'The manual is not included' in output
    manual = "Local IDE manual\n"
    (folder / 'MANUAL.md').write_text(manual, encoding='utf-8')
    output = subprocess.check_output([str(folder / 'check')]).decode('utf-8')
    assert output.split('---MANUAL---\n', 1)[1] == manual
print('Build identity and embedded manual checks passed')
