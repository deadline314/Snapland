"""Run project startup and GDScript runtime tests in isolated user data."""
from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "4.7.2"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    configured = os.environ.get("GODOT_BIN")
    executable = configured or shutil.which("godot") or shutil.which("godot4")
    if not executable:
        return fail("Godot 4.7.2 executable is required; set GODOT_BIN or add godot to PATH.")
    try:
        version = subprocess.run([executable, "--version"], check=True, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
    except (OSError, subprocess.SubprocessError) as error:
        return fail(f"cannot run Godot executable '{executable}': {error}")
    if not re.search(rf"\b{re.escape(EXPECTED_VERSION)}(?:\.stable)?\b", version.stdout + version.stderr):
        return fail(f"expected Godot {EXPECTED_VERSION}; executable reported {(version.stdout + version.stderr).strip()!r}.")

    with tempfile.TemporaryDirectory(prefix="snapland-godot-test-") as temporary:
        env = os.environ.copy()
        env["SNAPLAND_SAVE_PATH"] = str(Path(temporary) / "profile" / "progress.json")
        common = [executable, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility"]
        checks = [
            ("clean project import", [executable, "--headless", "--editor", "--path", str(ROOT), "--rendering-method", "gl_compatibility", "--import", "--quit"]),
            ("game startup", common + ["--", "--smoke-test"]),
            ("core runtime tests", common + ["res://game/tests/test_core.tscn"]),
            ("welcome minigame tests", common + ["--script", "res://game/tests/test_minigames.gd"]),
            ("story runtime tests", common + ["--script", "res://game/tests/test_story.gd"]),
            ("audio runtime tests", common + ["--script", "res://game/tests/test_audio.gd"]),
            ("main scene integration tests", common + ["res://game/tests/test_integration.tscn"]),
        ]
        for suite_index, (label, command) in enumerate(checks):
            env["SNAPLAND_SAVE_PATH"] = str(Path(temporary) / f"profile-{suite_index}.json")
            try:
                result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
            except (OSError, subprocess.SubprocessError) as error:
                return fail(f"{label} could not run: {error}")
            if result.returncode:
                output = ((result.stdout or "") + "\n" + (result.stderr or "")).strip()
                return fail(f"{label} exited {result.returncode}:\n{output[-6000:]}")
            output = (result.stdout or "") + "\n" + (result.stderr or "")
            engine_errors = [line for line in output.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
            if engine_errors:
                return fail(f"{label} logged engine errors:\n" + "\n".join(engine_errors[-40:]))
            pass_markers = {
                "game startup": "PASS: game startup and clean shutdown",
                "core runtime tests": "PASS: core runtime checks",
                "welcome minigame tests": "PASS: welcome minigame checks",
                "story runtime tests": "PASS: story runtime checks",
                "audio runtime tests": "PASS: audio runtime checks",
                "main scene integration tests": "PASS: main scene integration checks",
            }
            marker = pass_markers.get(label)
            if marker and marker not in (result.stdout or ""):
                return fail(f"{label} exited without its PASS marker ({marker!r}).")
            print(f"PASS: {label}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
