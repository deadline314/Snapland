"""Fail loudly until real Godot runtime tests are configured when the game exists."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
projects = [p for p in root.rglob('project.godot') if not any(x in p.parts for x in ('.git', '.review', '.godot'))]
runtime_files = [p for suffix in ('*.gd', '*.tscn', '*.tres', '*.cs') for p in root.rglob(suffix) if not any(x in p.parts for x in ('.git', '.review', '.godot'))]
if projects or runtime_files:
    print('FAIL: Godot project/runtime files found. Add and execute the actual runtime test suite in CI before claiming full coverage.', file=sys.stderr)
    sys.exit(1)
print('NOT APPLICABLE: no Godot project/runtime yet; only the complete design validation suite exists.')
