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
            ("wardrobe runtime tests", common + ["--script", "res://game/tests/test_wardrobe.gd"]),
            ("avatar runtime tests", common + ["--script", "res://game/tests/test_avatar.gd"]),
            ("eight-direction walk tests", common + ["--script", "res://game/tests/test_avatar_walk.gd"]),
            ("character animation library tests", common + ["--script", "res://game/tests/test_character_animation_library.gd"]),
            ("NPC animation state tests", common + ["--script", "res://game/tests/test_npc_animation_states.gd"]),
            ("tutorial panel/catalog tests", common + ["--script", "res://game/tests/test_tutorial_panel.gd"]),
            ("tutorial seen progress tests", common + ["res://game/tests/test_tutorial_seen_progress.tscn"]),
            ("travel collection UI tests", common + ["res://game/tests/test_travel_book_ui.tscn"]),
            ("tutorial image/control tests", common + ["res://game/tests/native_tutorial_depth_review.tscn", "--", "--tutorial-review-controls-only"]),
            ("time-of-day tests", common + ["--script", "res://game/tests/test_time_of_day.gd"]),
            ("daylight lighting tests", common + ["--script", "res://game/tests/test_daylight_lighting.gd"]),
            ("NPC activity tests", common + ["--script", "res://game/tests/test_npc_activity.gd"]),
            ("NPC world activity tests", common + ["--script", "res://game/tests/test_npc_world_activity.gd"]),
            ("sprite clearance tests", common + ["--script", "res://game/tests/test_sprite_clearance.gd"]),
            ("wardrobe UI tests", common + ["res://game/tests/test_wardrobe_ui.tscn"]),
            ("component animation tests", common + ["--script", "res://game/tests/test_component_animation.gd"]),
            ("building occlusion tests", common + ["--script", "res://game/tests/test_occlusion.gd"]),
            ("kite flight model tests", common + ["--script", "res://game/tests/test_kite_flight_model.gd"]),
            ("kite flight view tests", common + ["--script", "res://game/tests/test_kite_flight_view.gd"]),
            ("bubble photo model tests", common + ["--script", "res://game/tests/test_bubble_photo_model.gd"]),
            ("bubble photo view tests", common + ["--script", "res://game/tests/test_bubble_photo_view.gd"]),
            ("bench swap model tests", common + ["--script", "res://game/tests/test_bench_swap_model.gd"]),
            ("bench swap view tests", common + ["--script", "res://game/tests/test_bench_swap_view.gd"]),
            ("sign balance model tests", common + ["--script", "res://game/tests/test_sign_balance_model.gd"]),
            ("sign balance view tests", common + ["--script", "res://game/tests/test_sign_balance_view.gd"]),
            ("hat rescue model tests", common + ["--script", "res://game/tests/test_hat_rescue_model.gd"]),
            ("hat rescue view tests", common + ["--script", "res://game/tests/test_hat_rescue_view.gd"]),
            ("melody memory model tests", common + ["--script", "res://game/tests/test_melody_memory_model.gd"]),
            ("melody memory view tests", common + ["--script", "res://game/tests/test_melody_memory_view.gd"]),
            ("ribbon rhythm model tests", common + ["--script", "res://game/tests/test_ribbon_rhythm_model.gd"]),
            ("ribbon rhythm view tests", common + ["--script", "res://game/tests/test_ribbon_rhythm_view.gd"]),
            ("shadow theatre model tests", common + ["--script", "res://game/tests/test_shadow_theatre_model.gd"]),
            ("shadow theatre view tests", common + ["--script", "res://game/tests/test_shadow_theatre_view.gd"]),
            ("crowd semaphore view tests", common + ["--script", "res://game/tests/test_crowd_semaphore_view.gd"]),
            ("welcome minigame tests", common + ["--script", "res://game/tests/test_minigames.gd"]),
            ("pipe round model tests", common + ["--script", "res://game/tests/test_pipe_round_model.gd"]),
            ("pipe plan presentation tests", common + ["--script", "res://game/tests/test_pipe_plan_view.gd"]),
            ("balloon harbor presentation tests", common + ["--script", "res://game/tests/test_balloon_harbor_view.gd"]),
            ("crowd traffic model tests", common + ["--script", "res://game/tests/test_crowd_traffic_model.gd"]),
            ("crowd crossing view tests", common + ["--script", "res://game/tests/test_crowd_crossing_view.gd"]),
            ("fountain jump view tests", common + ["--script", "res://game/tests/test_fountain_jump_view.gd"]),
            ("fountain timing tests", common + ["--script", "res://game/tests/test_fountain.gd"]),
            ("balloon delivery tests", common + ["--script", "res://game/tests/test_balloon.gd"]),
            ("story runtime tests", common + ["--script", "res://game/tests/test_story.gd"]),
            ("audio runtime tests", common + ["--script", "res://game/tests/test_audio.gd"]),
            ("main scene integration tests", common + ["res://game/tests/test_integration.tscn"]),
        ]
        for suite_index, (label, command) in enumerate(checks):
            env["SNAPLAND_SAVE_PATH"] = str(Path(temporary) / f"profile-{suite_index}.json")
            try:
                result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
            except subprocess.TimeoutExpired as error:
                def decoded(value: str | bytes | None) -> str:
                    return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
                output = decoded(error.stdout) + "\n" + decoded(error.stderr)
                return fail(f"{label} timed out after 90 seconds:\n{output.strip()[-6000:]}")
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
                "wardrobe runtime tests": "PASS: wardrobe runtime checks",
                "avatar runtime tests": "PASS: avatar runtime checks",
                "eight-direction walk tests": "PASS: eight-direction avatar walk checks",
                "character animation library tests": "PASS: character animation library checks",
                "NPC animation state tests": "PASS: NPC animation state progression, interruption, pause, fallback, and cleanup",
                "tutorial panel/catalog tests": "PASS: tutorial panel/catalog checks",
                "tutorial seen progress tests": "PASS: tutorial seen progress and failed-save start checks",
                "travel collection UI tests": "PASS: travel map, paged collection book, achievement stamps, and reduce-motion hook",
                "tutorial image/control tests": "PASS: tutorial controls/assets preflight",
                "time-of-day tests": "PASS: time-of-day runtime checks",
                "daylight lighting tests": "PASS: daylight lighting runtime checks",
                "NPC activity tests": "PASS: NPC activity runtime checks",
                "NPC world activity tests": "PASS: NPC world activity integration",
                "sprite clearance tests": "PASS: billboard sprites keep authored feet on the ground for eight headings and camera pitches",
                "wardrobe UI tests": "PASS: wardrobe UI runtime checks",
                "component animation tests": "PASS: component animation runtime checks",
                "building occlusion tests": "PASS: occlusion controller runtime checks",
                "kite flight model tests": "Kite flight model: ",
                "kite flight view tests": "Kite flight view: ",
                "bubble photo model tests": "PASS: bubble photo model (",
                "bubble photo view tests": "PASS: bubble photo view (",
                "bench swap model tests": "Bench swap model: ",
                "bench swap view tests": "Bench swap view: ",
                "sign balance model tests": "Sign balance model: ",
                "sign balance view tests": "Sign balance view: ",
                "hat rescue model tests": "Hat rescue model: ",
                "hat rescue view tests": "Hat rescue view: ",
                "melody memory model tests": "Melody memory model: ",
                "melody memory view tests": "Melody memory view: ",
                "ribbon rhythm model tests": "PASS: ribbon rhythm model (",
                "ribbon rhythm view tests": "PASS: ribbon rhythm view (",
                "shadow theatre model tests": "Shadow theatre model: ",
                "shadow theatre view tests": "Shadow theatre view: ",
                "crowd semaphore view tests": "PASS: 3D crowd semaphore view (",
                "welcome minigame tests": "PASS: welcome minigame checks",
                "pipe round model tests": "PASS: pipe round model checks",
                "pipe plan presentation tests": "PASS: pipe plan view checks",
                "balloon harbor presentation tests": "PASS: isolated miniature harbor view",
                "crowd traffic model tests": "PASS: crowd traffic model (",
                "crowd crossing view tests": "PASS: overhead crowd-crossing view (",
                "fountain jump view tests": "FountainJumpView tests: ",
                "fountain timing tests": "PASS: fountain timing checks",
                "balloon delivery tests": "PASS: balloon delivery checks",
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
