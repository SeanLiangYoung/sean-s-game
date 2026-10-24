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
suites = ('relics', 'relic_combat', 'relic_ui', 'progression', 'progression_ui', 'fullscreen_pages', 'run', 'edges', 'campaign', 'integration', 'persistence', 'ui', 'menu', 'art', 'presentation', 'characters', 'equipment', 'routes', 'atlas', 'actions', 'professions', 'profession_combat', 'profession_ui', 'equipment_visual', 'equipment_appearance_ui', 'equipment_shapes', 'character_pages', 'equipment_preview')
for suite in suites:
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
render = subprocess.run([str(engine), '--path', str(root), '--script', 'res://tests/appearance_render.gd'],
                        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
print('[appearance_render]\n' + render.stdout, end='')
match = re.search(r'CHECKS: (\d+) FAILURES: 0', render.stdout)
if render.returncode or not match or 'ERROR:' in render.stdout:
    sys.exit(1)
checks += int(match.group(1))
preview_render = subprocess.run([str(engine), '--path', str(root), '--script', 'res://tests/equipment_preview_render.gd'],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
print('[equipment_preview_render]\n' + preview_render.stdout, end='')
match = re.search(r'CHECKS: (\d+) FAILURES: 0', preview_render.stdout)
if preview_render.returncode or not match or 'ERROR:' in preview_render.stdout:
    sys.exit(1)
checks += int(match.group(1))
print(f'PASS: {checks} checks across {len(suites)+2} suites; scene smoke and native appearance rendering passed.')
