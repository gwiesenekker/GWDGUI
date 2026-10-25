#!/usr/bin/env python3
"""Build an isolated test project using options supported by Lazarus 3.0+."""
import pathlib
import subprocess
import sys
import xml.etree.ElementTree as ET

widgetset, output_arg, project_arg = sys.argv[1:]
output = pathlib.Path(output_arg).resolve()
project = pathlib.Path(project_arg).resolve()
output.mkdir(parents=True, exist_ok=True)
(output / 'units').mkdir(exist_ok=True)
tree = ET.parse(project)
root = tree.getroot()

def option(path, value):
    node = root
    for part in path.split('/'):
        found = node.find(part)
        if found is None:
            found = ET.SubElement(node, part)
        node = found
    node.set('Value', str(value))

for node in root.findall('./ProjectOptions/Units/*/Filename'):
    node.set('Value', str((project.parent / node.get('Value')).resolve()))
option('CompilerOptions/Target/Filename', output / project.stem)
option('CompilerOptions/SearchPaths/OtherUnitFiles', project.parent.parent)
option('CompilerOptions/SearchPaths/UnitOutputDirectory', output / 'units')
isolated = output / project.name
tree.write(isolated, encoding='utf-8', xml_declaration=True)
executable = output / project.stem
executable.unlink(missing_ok=True)
subprocess.run(['lazbuild', '--no-write-project', '--ws=' + widgetset,
                '--pcp=' + str(output / 'config'), str(isolated)], check=True)
if not executable.is_file():
    raise RuntimeError('lazbuild did not produce the requested test executable')
