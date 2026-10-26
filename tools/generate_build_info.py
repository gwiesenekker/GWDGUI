#!/usr/bin/env python3
"""Embed the manual and the build's Git identity, without modifying sources."""
import pathlib
import subprocess
import sys


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True,
                                   stderr=subprocess.DEVNULL).strip()


def literal(text):
    return "'" + text.replace("'", "''") + "'"


def generate(root, output):
    root = pathlib.Path(root).resolve()
    output = pathlib.Path(output)
    try:
        commit = git(root, 'rev-parse', '--verify', 'HEAD')
        revision = git(root, 'describe', '--tags', '--always')
        # Untracked local engines/configuration are not part of the executable.
        dirty = bool(git(root, 'status', '--porcelain', '--untracked-files=no'))
    except (OSError, subprocess.CalledProcessError):
        commit, revision, dirty = 'unavailable (source archive)', 'source build', False
    manual = (root / 'MANUAL.md').read_text(encoding='utf-8')
    lines = [
        'const',
        '  BuildCommit = ' + literal(commit) + ';',
        '  BuildRevision = ' + literal(revision) + ';',
        '  BuildHasChanges = ' + str(dirty) + ';',
        '  EmbeddedManual: UTF8String =',
    ]
    parts = manual.split('\n')
    for i, part in enumerate(parts):
        # Preserve all text, including an absent/present final newline.
        suffix = ';' if i == len(parts)-1 else ' + #10 +'
        lines.append('    ' + literal(part) + suffix)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    generate(sys.argv[1], sys.argv[2])
