"""Fail if a Godot project has no native runtime test command."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
project = ROOT / "project.godot"
runner = ROOT / "tools" / "run_game_tests.py"
suite = ROOT / "game" / "tests" / "test_core.tscn"
if project.exists() or any(ROOT.rglob("*.gd")) or any(ROOT.rglob("*.tscn")):
    missing = [str(path.relative_to(ROOT)) for path in (project, runner, suite) if not path.is_file()]
    if missing:
        print("FAIL: runtime files found but the actual runtime test suite is incomplete: " + ", ".join(missing), file=sys.stderr)
        sys.exit(1)
    print("PASS: native runtime test command is configured.")
else:
    print("NOT APPLICABLE: no Godot project/runtime exists yet.")
