"""Run project startup and GDScript runtime tests in isolated user data."""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

if __package__:
    from .godot_entrypoints import run_validated_godot
else:
    from godot_entrypoints import run_validated_godot

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "4.7.2"

PASS_MARKERS = {
    "photo retake progress tests": "PASS: attempt history, selected retake awards, provenance and atomic rollback",
    "participation result tests": "PASS: fourteen participation results, practice, cancellation and driver eligibility",
    "retake panel tests": "PASS: retake panel canonical targets, reversible state, keyboard and capture guards",
    "photo retake Main tests": "PASS: Main selected retakes, actual attempts, truthful awards and safe PNG replacement",
    "retake native fixture tests": "PASS: retake native fixture adjacent helper, isolated packaging and real resources",
    "rowing native fixture tests": "PASS: rowing native fixture adjacent helper and three real tutorial PNGs",
    "rowing Main tests": "PASS: rowing Main entry, regional map, tutorial, truthful timeout, practice, assisted reward and reload",
    "harbor collection tests": "Harbor collection: 22 checks, 0 failures",
    "rowing Session tests": "Rowing Session: 34 checks, 0 failures",
    "rowing cargo view tests": "Rowing view: 32 checks, 0 failures",
    "rowing cargo driver tests": "Rowing driver: 39 checks, 0 failures",
    "rowing cargo model tests": "Rowing cargo: 58 checks, 0 failures",
    "sandbar native fixture tests": "PASS: sandbar native fixture adjacent helper and three real tutorial PNGs",
    "sandbar Main tests": "PASS: sandbar Main entry, regional map, tutorial, truthful timeout, practice, routes, assisted devil and reload",
    "sandbar Session tests": "Tide sandbar Session: 31 checks, 0 failures",
    "sandbar view tests": "Tide sandbar view: 45 checks, 0 failures",
    "sandbar driver tests": "Tide sandbar driver: 37 checks, 0 failures",
    "sandbar model tests": "Tide sandbar: 53 checks, 0 failures",
    "harbor game progress tests": "PASS: harbor rewards, replay, legacy, captures, reload and atomic failure",
    "delivered game catalog tests": "PASS: delivered game catalog, copies, regional identity and malformed data",
    "boat prologue state tests": "PASS: boat prologue state, save boundaries, and optional story validation",
    "boat prologue stage tests": "PASS: boat prologue reversible ferry stage, timing, and bounded preview",
    "boat prologue integration tests": "PASS: boat prologue first-run, replay, interruption, and unchanged rewards",
    "avatar prop foreground tests": "PASS: prop foreground 128 complete-pose blends, independent hand/camera witnesses, rigid guards, exact-source rejection, bounded cache and 10 malformed inputs",
    "NPC departure lifecycle tests": "PASS: planted NPC departure, pause, dialogue, interruption, stride restart, reduced motion and damaged-source fallback",
    "pixel typography tests": "PASS: 40 pixel font checks, 0 failures",
    "localization framework tests": "PASS: locale packs, fallback, preferences and live UI state",
    "pixel UI shell tests": "PASS: pixel shell pause, ticket, controls, three explorations, synthetic result and Main dialogue; geometry, Tab and pointer return at 800/1280/1920",
    "pixel UI popup tests": "PASS: actual popup window bounds and44physical rows at800/1280/1920, 1.25 text",
    "pixel UI button depth tests": "PASS: Paper pixel-button depth, state, focus and contrast checks",
    "pixel UI collection tests": "PASS: pixel UI collection, map, achievement, and tutorial checks",
    "pixel tutorial page tests": "PASS: native-matching tutorial45steps, all five semantic fields in capacity-driven page groups, three sizes/1.25, visible copy clip/line height and blocked wheel",
    "pixel UI customization tests": "PASS: pixel UI settings, text-scale persistence, immediate time selection, and fixed category controls",
    "pixel UI minigame tests": "PASS: minigame HUD, pause/results, invite, dialogue, photo frame, and 3 viewport sizes",
    "region progress tests": "PASS: region progress defaults, migration, transactions, and rollback",
    "harbor world tests": "PASS: harbor world terrain, tide safety, free ferry, map alignment and bounded reentry (7041 checks)",
    "region travel tests": "PASS: region travel admission, lifecycle, scoped UI, restart, and unchanged rewards",
    "game startup": "PASS: game startup and clean shutdown",
    "core runtime tests": "PASS: core runtime checks",
    "test/review save isolation tests": "PASS: save guard child processes use a unique verified fake Godot profile; every rejected-path case preserves seeded sidecars",
    "wardrobe runtime tests": "PASS: wardrobe runtime checks",
    "avatar runtime tests": "PASS: avatar runtime checks",
    "avatar renderer tests": "PASS: independent bob nose/eye alpha, 64-cel bob/curly face RGBA and opening alpha across all skins/species, two-color original body/palette and haircut RGB, bounded caches; native quality pending",
    "avatar attachment tests": "PASS: measured walk head attachments",
    "island hair lifecycle tests": "PASS: island hair lifecycle retains live walk phase through appearance, motion and reduced-motion changes",
    "island alternate hair source tests": "PASS: alternate island hair ownership remains registered across",
    "seated avatar tests": "PASS: four measured front seated poses, head/feet anchors, card bounds, and preserved action coverage",
    "avatar motion rig runtime tests": "PASS: eight direction 3D gait model/source/sole/cancellation/bounded resource tests; native quality pending",
    "avatar role rig tests": "PASS: role metadata path, two-view coverage, scaled fixed bones/boots, ground following, actual NPC source-width legs/opaque boot attachment, non-skin trouser limb ownership, and missing-role fallback",
    "avatar motion world integration tests": "PASS: integrated avatar motion world checks",
    "minigame HUD hierarchy tests": "PASS: minigame HUD hierarchy checks (71 checks)",
    "eight-direction walk tests": "PASS: eight-direction avatar walk checks",
    "authored avatar walk loop tests": "PASS: real world avatar presents authored eight-direction walk cels, natural stance holds, and allocates no unused hero rig",
    "source registration coordinate tests": "PASS: body registration, independent palette/boot coordinates and immutable rebuild",
    "authored avatar side idle tests": "PASS: dedicated stable idle timing, source diagnostics, and reduced-motion stance",
    "atomic outfit coverage tests": "PASS: atomic outfit coverage (",
    "legacy head source tests": "PASS: reviewed legacy human cuts preserve original face body and 24 default requests with bounded masks and fail-closed data",
    "garment cache tests": "PASS: garment cache bounds 344 exact blends, 512 warm hits and atomic missing or changed reload recovery",
    "garment overlay tests": "PASS: garment overlay preserves 172 original compositions; missing last cel falls back across all eight directions",
    "garment part ownership tests": "PASS: garment sleeves retain 121 owned source pixels, reject adjacent raster tiles and preserve unassigned torso pixels",
    "side outfit palette tests": "PASS: side jacket palette, 72 source-bound cases, exposed cloth witnesses and curly hair occlusion",
    "authored idle hair attachment tests": "PASS: source-atlas closed-eye attachment availability (not production idle playback)",
    "authored NPC source walking tests": "PASS: all three authored NPC routes display complete side poses and preserve independent personality actions",
    "authored NPC patrol tests": "PASS: authored NPC patrol bounds, distance phase, obstacle/ground rejection, teleport, long-frame and release",
    "character animation library tests": "PASS: character animation library checks",
    "NPC animation state tests": "PASS: NPC animation state progression, interruption, pause, fallback, and cleanup",
    "tutorial panel/catalog tests": "PASS: tutorial panel/catalog checks",
    "tutorial seen progress tests": "PASS: tutorial seen progress and failed-save start checks",
    "travel collection UI tests": "PASS: travel map, paged collection book, achievement stamps, and reduce-motion hook",
    "tutorial image/control tests": "PASS: tutorial controls/assets preflight",
    "time-of-day tests": "PASS: time-of-day runtime checks",
    "actor alpha silhouette tests": "PASS: actor alpha caster preserves pose, frame, atlas, flips and live texture identity without source mutation",
    "daylight lighting tests": "PASS: daylight lighting runtime checks",
    "NPC activity tests": "PASS: NPC activity runtime checks",
    "NPC world activity tests": "PASS: NPC world activity integration",
    "NPC motion source tests": "PASS: all three NPC roles' source hashes, measured alpha bounds, nearest normalized RGBA streams, unsupported-view behavior, and rig-prepared limb/boot regions",
    "NPC walk motion tests": "PASS: optional three-role measured gait, source fallback, pause/hold lifecycle, and measured announcer leg costume",
    "NPC direction lifecycle tests": "PASS: imp same-view long-frame support epoch, route turns, settlement and tiny-frame restart",
    "NPC missing walk idle tests": "PASS: missing authored side walk preserves idle lifecycle and measured route after dialogue",
    "NPC dialogue hold tests": "PASS: Main NPC dialogue hold lifecycle",
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
    "ribbon Session startup tests": "PASS: Ribbon Session startup (3 checks)",
    "ribbon Session lifecycle tests": "PASS: Ribbon Session lifecycle (61 checks)",
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
    "story runtime tests": "PASS: story data, compatibility, mission evidence, and idempotency",
    "main story integration tests": "PASS: real Main story interactions and exploration evidence",
    "island ride tests": "PASS: island ride lifecycle",
    "island layout tests": "PASS: island layout contracts",
    "promenade free play tests": "PASS: promenade stepping and context toys, no standing repeats, pause/focus safety, reduced-motion result and unchanged save",
    "coastal free play tests": "PASS: coastal free play direction, physics, recall, bell, water, pause/focus/reduced-motion and unchanged save",
    "shared photo thumbnail tests": "PASS: MAIN-13 shared photo paths, replay idempotence, legacy backfill, malformed/missing fallback",
    "saved photo viewer tests": "PASS: saved album photo viewer, focus return, and immutable progress",
    "photo original preservation tests": "PASS: bounded photo originals, shared collection metadata, safe viewer loading",
    "island dialogue tests": "PASS: island dialogue panel and bounded, speaker-pitched beep",
    "island game entry tests": "PASS: 12 compact invites and first-entry/optional-rule flow",
    "audio runtime tests": "PASS: audio runtime checks",
    "island audio dynamics tests": "PASS: phase-aware island audio dynamics and dialogue duck",
    "main scene integration tests": "PASS: main scene integration checks",
}



def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def result_error(label: str, result: subprocess.CompletedProcess[str], expected_save_path: str | None = None) -> str | None:
    """A completed engine process still needs its own error-free completion line."""
    output = (result.stdout or "") + "\n" + (result.stderr or "")
    if result.returncode:
        return f"{label} exited {result.returncode}:\n{output.strip()[-6000:]}"
    engine_errors = [line for line in output.splitlines() if "ERROR:" in line]
    if label == "boat prologue state tests":
        # This suite deliberately blocks exactly its own profile's .tmp write.
        expected = rf"ERROR: Cannot write progress temporary file '{re.escape(expected_save_path or '')}\.tmp': Can't open file"
        matches = [line for line in engine_errors if re.fullmatch(expected, line)] if expected_save_path else []
        if len(matches) != 1:
            return f"{label} expected exactly one isolated temporary-write diagnostic; observed {len(matches)}."
        engine_errors.remove(matches[0])
    if engine_errors:
        return f"{label} logged engine errors:\n" + "\n".join(engine_errors[-40:])
    marker = PASS_MARKERS.get(label)
    if marker is None:
        if label == "clean project import":
            return None
        return f"{label} has no configured completion marker."
    stdout_lines = (result.stdout or "").splitlines()
    completed = any(line == marker for line in stdout_lines) if label.startswith(("boat prologue ", "rowing ", "sandbar ", "harbor ", "delivered game ", "photo retake ", "participation result ", "retake ")) or label in {"region progress tests", "region travel tests"} else any(line.startswith(marker) for line in stdout_lines)
    if not completed:
        observed = [line for line in stdout_lines if line.startswith("PASS")]
        return f"{label} exited without its PASS marker ({marker!r}); observed completion lines: {observed[-8:]!r}."
    return None


def build_checks(executable: str) -> list[tuple[str, list[str]]]:
    """Construct the single ordered catalog without starting the engine."""
    common = [executable, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility"]
    return [
        ("clean project import", [executable, "--headless", "--editor", "--path", str(ROOT), "--rendering-method", "gl_compatibility", "--import", "--quit"]),
        ("game startup", common + ["--", "--smoke-test"]),
        ("photo retake progress tests", common + ["--script", "res://game/tests/test_photo_retake_progress.gd"]),
        ("participation result tests", common + ["--script", "res://game/tests/test_participation_results.gd"]),
        ("retake panel tests", common + ["--script", "res://game/tests/test_retake_panel.gd"]),
        ("photo retake Main tests", common + ["res://game/tests/test_photo_retake_main.tscn"]),
        ("retake native fixture tests", common + ["--script", "res://game/tests/test_retake_native_fixture.gd"]),
        ("region progress tests", common + ["--script", "res://game/tests/test_region_progress.gd"]),
        ("harbor world tests", common + ["--script", "res://game/tests/test_harbor_world.gd"]),
        ("region travel tests", common + ["res://game/tests/test_region_travel.tscn"]),
        ("delivered game catalog tests", common + ["--script", "res://game/tests/test_game_catalog.gd"]),
        ("harbor game progress tests", common + ["--script", "res://game/tests/test_harbor_game_progress.gd"]),
        ("rowing cargo model tests", common + ["--script", "res://game/tests/test_rowing_cargo.gd"]),
        ("rowing cargo driver tests", common + ["--script", "res://game/tests/test_rowing_cargo_driver.gd"]),
        ("rowing cargo view tests", common + ["--script", "res://game/tests/test_rowing_cargo_view.gd"]),
        ("rowing Session tests", common + ["--script", "res://game/tests/test_rowing_session.gd"]),
        ("harbor collection tests", common + ["--script", "res://game/tests/test_harbor_collection.gd"]),
        ("rowing Main tests", common + ["res://game/tests/test_rowing_main.tscn"]),
        ("rowing native fixture tests", common + ["res://game/tests/native_rowing_main.tscn", "--", "--rowing-preflight"]),
        ("sandbar model tests", common + ["--script", "res://game/tests/test_tide_sandbar.gd"]),
        ("sandbar driver tests", common + ["--script", "res://game/tests/test_tide_sandbar_driver.gd"]),
        ("sandbar view tests", common + ["--script", "res://game/tests/test_tide_sandbar_view.gd"]),
        ("sandbar Session tests", common + ["--script", "res://game/tests/test_tide_sandbar_session.gd"]),
        ("sandbar Main tests", common + ["res://game/tests/test_tide_sandbar_main.tscn"]),
        ("sandbar native fixture tests", common + ["res://game/tests/native_tide_sandbar_main.tscn", "--", "--sandbar-preflight"]),
        ("core runtime tests", common + ["res://game/tests/test_core.tscn"]),
        ("test/review save isolation tests", common + ["res://game/tests/test_test_save_guard.tscn"]),
        ("wardrobe runtime tests", common + ["--script", "res://game/tests/test_wardrobe.gd"]),
        ("avatar runtime tests", common + ["--script", "res://game/tests/test_avatar.gd"]),
        ("avatar renderer tests", common + ["--script", "res://game/tests/test_avatar_renderer.gd"]),
        ("avatar attachment tests", common + ["--script", "res://game/tests/test_avatar_attachment.gd"]),
        ("island hair lifecycle tests", common + ["--script", "res://game/tests/test_island_hair_lifecycle.gd"]),
        ("island alternate hair source tests", common + ["--script", "res://game/tests/test_island_hair_sources.gd"]),
        ("seated avatar tests", common + ["--script", "res://game/tests/test_avatar_seated.gd"]),
        ("source registration coordinate tests", common + ["--script", "res://game/tests/test_source_registration.gd"]),
        ("avatar motion rig runtime tests", common + ["--script", "res://game/tests/test_avatar_motion_rig.gd"]),
        ("avatar role rig tests", common + ["res://game/tests/test_avatar_role_rig.tscn"]),
        ("avatar motion world integration tests", common + ["--script", "res://game/tests/test_avatar_motion_world.gd"]),
        ("minigame HUD hierarchy tests", common + ["--script", "res://game/tests/test_minigame_hud.gd"]),
        ("eight-direction walk tests", common + ["--script", "res://game/tests/test_avatar_walk.gd"]),
        ("authored avatar walk loop tests", common + ["--script", "res://game/tests/test_avatar_authored_walk_loop.gd"]),
        ("authored avatar side idle tests", common + ["--script", "res://game/tests/test_avatar_side_idle.gd"]),
        ("authored idle hair attachment tests", common + ["--script", "res://game/tests/test_avatar_idle_attachment.gd"]),
        ("authored NPC source walking tests", common + ["--script", "res://game/tests/test_npc_authored_source_walking.gd"]),
        ("authored NPC patrol tests", common + ["--script", "res://game/tests/test_authored_npc_patrol.gd"]),
        ("NPC departure lifecycle tests", common + ["--script", "res://game/tests/test_npc_departure_lifecycle.gd"]),
        ("character animation library tests", common + ["--script", "res://game/tests/test_character_animation_library.gd"]),
        ("atomic outfit coverage tests", common + ["--script", "res://game/tests/test_outfit_atomic_coverage.gd"]),
        ("garment overlay tests", common + ["--script", "res://game/tests/test_garment_overlay.gd"]),
        ("garment cache tests", common + ["--script", "res://game/tests/test_garment_cache.gd"]),
        ("legacy head source tests", common + ["--script", "res://game/tests/test_legacy_head_source.gd"]),
        ("garment part ownership tests", common + ["--script", "res://game/tests/test_garment_part_ownership.gd"]),
        ("side outfit palette tests", common + ["--script", "res://game/tests/test_outfit_side_palette.gd"]),
        ("avatar prop foreground tests", common + ["--script", "res://game/tests/test_avatar_prop_foreground.gd"]),
        ("NPC animation state tests", common + ["--script", "res://game/tests/test_npc_animation_states.gd"]),
        ("tutorial panel/catalog tests", common + ["--script", "res://game/tests/test_tutorial_panel.gd"]),
        ("tutorial seen progress tests", common + ["res://game/tests/test_tutorial_seen_progress.tscn"]),
        ("travel collection UI tests", common + ["res://game/tests/test_travel_book_ui.tscn"]),
        ("tutorial image/control tests", common + ["res://game/tests/native_tutorial_depth_review.tscn", "--", "--tutorial-review-controls-only"]),
        ("time-of-day tests", common + ["--script", "res://game/tests/test_time_of_day.gd"]),
        ("daylight lighting tests", common + ["--script", "res://game/tests/test_daylight_lighting.gd"]),
        ("actor alpha silhouette tests", common + ["--script", "res://game/tests/test_actor_shadow_silhouette.gd"]),
        ("NPC activity tests", common + ["--script", "res://game/tests/test_npc_activity.gd"]),
        ("NPC world activity tests", common + ["--script", "res://game/tests/test_npc_world_activity.gd"]),
        ("NPC motion source tests", common + ["res://game/tests/test_npc_motion_sources.tscn"]),
        ("NPC walk motion tests", common + ["--script", "res://game/tests/test_npc_walk_motion.gd"]),
        ("NPC direction lifecycle tests", common + ["--script", "res://game/tests/test_npc_walk_direction_lifecycle.gd"]),
        ("NPC missing walk idle tests", common + ["res://game/tests/test_missing_walk_idle_lifecycle.tscn"]),
        ("NPC dialogue hold tests", common + ["res://game/tests/test_npc_dialogue_hold.tscn"]),
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
        ("ribbon Session startup tests", common + ["--script", "res://game/tests/test_ribbon_session_startup.gd"]),
        ("ribbon Session lifecycle tests", common + ["--script", "res://game/tests/test_ribbon_finish_session.gd"]),
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
        ("boat prologue state tests", common + ["--script", "res://game/tests/test_boat_prologue_state.gd"]),
        ("boat prologue stage tests", common + ["--script", "res://game/tests/test_boat_prologue_stage.gd"]),
        ("boat prologue integration tests", common + ["res://game/tests/test_boat_prologue_integration.tscn"]),
        ("story runtime tests", common + ["--script", "res://game/tests/test_story.gd"]),
        ("main story integration tests", common + ["res://game/tests/test_story_integration.tscn"]),
        ("island ride tests", common + ["--script", "res://game/tests/test_island_ride.gd"]),
        ("island layout tests", common + ["--script", "res://game/tests/test_island_layout.gd"]),
        ("promenade free play tests", common + ["--script", "res://game/tests/test_promenade_play.gd"]),
        ("coastal free play tests", common + ["--script", "res://game/tests/test_coastal_play.gd"]),
        ("shared photo thumbnail tests", common + ["res://game/tests/test_main_photo_thumbnails.tscn"]),
        ("saved photo viewer tests", common + ["res://game/tests/test_album_photo_viewer.tscn"]),
        ("photo original preservation tests", common + ["res://game/tests/test_photo_originals.tscn"]),
        ("island dialogue tests", common + ["res://game/tests/test_island_dialogue.tscn"]),
        ("island game entry tests", common + ["res://game/tests/test_island_game_entry.tscn"]),
        ("audio runtime tests", common + ["--script", "res://game/tests/test_audio.gd"]),
        ("island audio dynamics tests", common + ["--script", "res://game/tests/test_audio_dynamics.gd"]),
        ("main scene integration tests", common + ["res://game/tests/test_integration.tscn"]),
        ("pixel UI shell tests", common + ["res://game/tests/test_pixel_ui_shell.tscn"]),
        ("pixel UI popup tests", common + ["--script", "res://game/tests/test_pixel_ui_popup_bounds.gd"]),
        ("pixel UI button depth tests", common + ["--script", "res://game/tests/test_pixel_button_depth.gd"]),
        ("pixel UI collection tests", common + ["res://game/tests/test_pixel_ui_collections.tscn"]),
        ("pixel tutorial page tests", common + ["--script", "res://game/tests/test_tutorial_paged_viewport.gd"]),
        ("pixel UI customization tests", common + ["res://game/tests/test_pixel_ui_customization.tscn"]),
        ("pixel UI minigame tests", common + ["res://game/tests/test_pixel_ui_minigames.tscn"]),
        ("pixel typography tests", common + ["res://game/tests/test_pixel_fonts.tscn"]),
        ("localization framework tests", common + ["res://game/tests/test_localization.tscn"]),
    ]


def validate_selection(only: list[str] | tuple[str, ...], shard_index: int | None, shard_count: int | None) -> None:
    if (shard_index is None) != (shard_count is None):
        raise ValueError("--shard-index and --shard-count must be supplied together")
    if shard_count is not None:
        if shard_count <= 0 or not 0 <= shard_index < shard_count:
            raise ValueError("--shard-count must be positive and --shard-index must be in [0, count)")
        if only:
            raise ValueError("--only cannot be combined with --shard-index/--shard-count")


def select_checks(checks: list[tuple[str, list[str]]], *, only: list[str] | tuple[str, ...] = (),
                  shard_index: int | None = None, shard_count: int | None = None) -> list[tuple[str, list[str]]]:
    """Validate the whole catalog before narrowing it; always import first."""
    validate_selection(only, shard_index, shard_count)
    labels = [label for label, _ in checks]
    if not labels or labels[0] != "clean project import" or len(labels) < 2:
        raise ValueError("Runtime catalog must start with clean project import and contain runtime suites.")
    if len(labels) != len(set(labels)):
        raise ValueError("Runtime catalog contains duplicate suite labels.")
    missing = set(labels[1:]) - PASS_MARKERS.keys()
    stale = PASS_MARKERS.keys() - set(labels[1:])
    if missing or stale:
        raise ValueError(f"Runtime completion marker mismatch: missing {sorted(missing)!r}, stale {sorted(stale)!r}.")
    if shard_count is not None:
        if shard_count > len(checks) - 1:
            raise ValueError(f"--shard-count {shard_count} exceeds {len(checks) - 1} runtime suites.")
        selected = [row for row in checks[1:]
                    if int.from_bytes(hashlib.sha256(row[0].encode("utf-8")).digest(), "big") % shard_count == shard_index]
        if not selected:
            raise ValueError(f"Runtime shard {shard_index}/{shard_count} is empty.")
        return checks[:1] + selected
    if only:
        selected = [row for row in checks[1:] if any(text in row[0] for text in only)]
        if not selected:
            raise ValueError(f"--only {only!r} matched no runtime suite.")
        return checks[:1] + selected
    return checks[:]


def parse_options(argv: list[str]) -> argparse.Namespace:
    """Default execution stays complete; shards partition that same catalog."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", action="append", default=[], metavar="TEXT",
                        help="run only suites whose label contains TEXT (repeatable); the clean import still runs first")
    parser.add_argument("--keep-going", action="store_true",
                        help="run every selected suite and report all failures instead of stopping at the first")
    parser.add_argument("--timeout-scale", type=float, default=1.0, metavar="FACTOR",
                        help="multiply per-suite limits on slower local machines (>= 1; CI keeps 1)")
    parser.add_argument("--shard-index", type=int, metavar="INDEX", help="0-based runtime shard index (requires --shard-count)")
    parser.add_argument("--shard-count", type=int, metavar="COUNT", help="number of runtime shards (requires --shard-index)")
    options = parser.parse_args(argv)
    if not options.timeout_scale >= 1.0:
        parser.error("--timeout-scale cannot shorten the configured limits")
    try:
        validate_selection(options.only, options.shard_index, options.shard_count)
    except ValueError as error:
        parser.error(str(error))
    return options


def main(argv: list[str] | None = None) -> int:
    options = parse_options(list(argv or []))
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
        try:
            checks = select_checks(build_checks(executable), only=options.only,
                                   shard_index=options.shard_index, shard_count=options.shard_count)
        except ValueError as error:
            return fail(str(error))
        failures: list[str] = []
        for suite_index, (label, command) in enumerate(checks):
            # Photos, decoder proofs and caches live beside the JSON profile.
            # Distinct filenames in one parent still let suites affect each other.
            suite_directory = Path(temporary) / f"suite-{suite_index}"
            suite_directory.mkdir()
            env["SNAPLAND_SAVE_PATH"] = str(suite_directory / "progress.json")
            timeout = (240 if label == "avatar renderer tests" else 90) * options.timeout_scale
            started = time.monotonic()
            print(f"RUN: {label} ({suite_index + 1}/{len(checks)}, limit {timeout}s)", flush=True)
            try:
                result = run_validated_godot(ROOT, command, env=env, timeout=timeout)
            except subprocess.TimeoutExpired as error:
                def decoded(value: str | bytes | None) -> str:
                    return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
                output = decoded(error.stdout) + "\n" + decoded(error.stderr)
                message = f"{label} timed out after {timeout:g} seconds:\n{output.strip()[-6000:]}"
            except (ValueError, OSError, subprocess.SubprocessError) as error:
                message = f"{label} could not run: {error}"
            else:
                message = result_error(label, result, env["SNAPLAND_SAVE_PATH"])
            if message:
                if label == "clean project import" or not options.keep_going:
                    return fail(message)
                fail(message)
                failures.append(label)
                continue
            print(f"PASS: {label} ({time.monotonic() - started:.2f}s)", flush=True)
    if failures:
        return fail(f"{len(failures)} of {len(checks)} runtime checks failed: {failures!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
