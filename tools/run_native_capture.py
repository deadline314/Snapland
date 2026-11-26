"""Run one native (GPU) review scene without disturbing the desktop.

The window opens off-screen, the process runs below normal priority, audio is
muted, and progress is written to a throwaway save. The scene decides what to
capture; it receives the output folder in SNAPLAND_CAPTURE_DIR.

Example:
    python tools/run_native_capture.py res://game/tests/native_world_review.tscn --out build/review
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

if __package__:
    from .godot_entrypoints import run_validated_godot
else:
    from godot_entrypoints import run_validated_godot

ROOT = Path(__file__).resolve().parents[1]
OFFSCREEN_POSITION = "-4000,-4000"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("scene", help="project scene, e.g. res://game/tests/native_world_review.tscn")
    parser.add_argument("--out", required=True, help="folder that receives captures")
    parser.add_argument("--size", default="1280x720", help="window size, WIDTHxHEIGHT")
    parser.add_argument("--timeout", type=float, default=180.0, help="seconds before the run is stopped")
    parser.add_argument("--visible", action="store_true", help="keep the window on screen (for watching a run)")
    parser.add_argument("user_args", nargs="*", help="arguments passed to the scene after --")
    args = parser.parse_args()
    engine = os.environ.get("GODOT_BIN", "")
    if not engine or not Path(engine).is_file():
        print("GODOT_BIN must point to the Godot 4.7.2 executable.", file=sys.stderr)
        return 2
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    command = [engine, "--path", str(ROOT), "--audio-driver", "Dummy", "--resolution", args.size]
    if not args.visible:
        command += ["--position", OFFSCREEN_POSITION]
    command.append(args.scene)
    if args.user_args:
        command += ["--", *args.user_args]
    with tempfile.TemporaryDirectory(prefix="snapland-native-") as isolated:
        env = dict(os.environ)
        env["SNAPLAND_SAVE_PATH"] = str(Path(isolated) / "profile" / "progress.json")
        env["SNAPLAND_CAPTURE_DIR"] = str(out)
        try:
            result = run_validated_godot(ROOT, command, env=env, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            print((error.output or "") + (error.stderr or ""))
            print(f"Native capture timed out after {args.timeout:.0f} s.", file=sys.stderr)
            return 1
        except ValueError as error:
            print(error, file=sys.stderr)
            return 2
    output = result.stdout + result.stderr
    print(output)
    failed = result.returncode != 0 or "ERROR:" in output
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
