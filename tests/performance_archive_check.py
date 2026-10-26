#!/usr/bin/env python3
"""Run the real performance wrapper from a minimal Git-less source archive."""
import pathlib
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='gwdgui-archive-check-') as scratch:
    archive = pathlib.Path(scratch)
    for source in root.glob('*.pas'):
        shutil.copy2(source, archive / source.name)
    for relative in ['tests/run_performance_checks.sh', 'tests/performance_check.pas',
                     'tests/fixtures/performance-long.pdn']:
        target = archive / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / relative, target)
    result = subprocess.run(['bash', str(archive / 'tests/run_performance_checks.sh'),
                             '1', '1', '1', '1'], capture_output=True, text=True, check=True)
    assert result.stderr == '', result.stderr
    assert '# revision=unavailable (source archive)' in result.stdout
    assert '# tracked_worktree=unknown' in result.stdout
    assert 'tracked_worktree=modified' not in result.stdout
    for operation in ['board_replay', 'notation_render', 'actor_import', 'pdn_storage']:
        assert operation + ',1,1,' in result.stdout, result.stdout
print('Source-archive performance checks passed')
