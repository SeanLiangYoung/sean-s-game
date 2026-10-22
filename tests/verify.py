#!/usr/bin/env python3
"""Run the complete rule and scene suite; reject Godot's exit-0 script errors."""
import pathlib
import re
import shutil
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
engine = root / '.tools/Godot.app/Contents/MacOS/Godot'
if not engine.exists():
    engine = shutil.which('godot')
if not engine:
    sys.exit('Godot 4.7.2 is required.')
checks = 0
for suite in ('run', 'edges', 'campaign', 'integration', 'persistence', 'ui'):
    result = subprocess.run([str(engine), '--headless', '--path', str(root),
                             '--script', f'res://tests/{suite}.gd'],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
    output = result.stdout
    print(f'[{suite}]\n{output}', end='')
    match = re.search(r'CHECKS: (\d+) FAILURES: 0', output)
    if result.returncode or not match or 'ERROR:' in output:
        sys.exit(1)
    checks += int(match.group(1))
smoke = subprocess.run([str(engine), '--headless', '--path', str(root), '--', '--smoke'],
                       text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
print(smoke.stdout, end='')
if smoke.returncode or 'SCENE_SMOKE_OK' not in smoke.stdout or 'ERROR:' in smoke.stdout:
    sys.exit(1)
print(f'PASS: {checks} checks across 6 suites; native scene smoke passed.')
