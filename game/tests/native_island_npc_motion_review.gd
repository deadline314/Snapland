extends Node

## Main-world NPC evidence fixture. Scripted timing and camera placement are
## recorded; a human must inspect the saved images for visual acceptance.

const MainScene := preload("res://game/main.tscn")
const CharacterAnimationLibraryScript := preload("res://game/world/character_animation_library.gd")
const NpcActivityScript := preload("res://game/world/npc_activity.gd")
const ROLES: Array[String] = ["ticket", "imp", "announcer"]
const ROLE_POINT := {"ticket": "guide", "imp": "quest-001", "announcer": "quest-002"}
const ROLE_IDLE_ACTIONS := {
	"ticket": ["idle_gesture", "emotion_happy"],
	"imp": ["idle_gesture", "emotion_proud", "dance"],
	"announcer": ["special", "emotion_curious"],
}
const CAMERA_UP_SHIFT := 1.25
const CAPTURE_PADDING_PX := 12.0
const REST_IDLE_SECONDS := 3.0
const PROOF_DIRECTORY := "pm/Snapland-art/images"
const FRAME_POINT_TOLERANCE := 0.03
const AUTHORED_ROUTE_HALF_WIDTH := {"ticket": 0.25, "imp": 0.35, "announcer": 0.60}
const ROUTE_AXIS_TOLERANCE := 0.02

var _main: Node
var _library: RefCounted
var _failures: Array[String] = []
var _report: Dictionary = {
	"fixture": "Main-backed island NPC motion review",
	"scripted_fixture": true,
	"human_played": false,
	"human_visual_acceptance": "pending parent review",
	"captures": [],
	"roles": {},
}
var _proof_prefix := "island_npc_final"
var _camera_offset := Vector3.ZERO
var _player_was_visible := true
var _caption: Label


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		if OS.get_environment("SNAPLAND_NPC_SOURCE_CPU_DIAGNOSTIC") == "1" or OS.get_environment("SNAPLAND_NPC_ROUTE_CPU_DIAGNOSTIC") == "1":
			await _run_source_cpu_diagnostic()
			return
		await _fail_and_quit("Native island NPC motion review requires a GPU-backed display; it was not run headless.")
		return
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or save_path.contains("://") or not save_path.is_absolute_path():
		await _fail_and_quit("Set SNAPLAND_SAVE_PATH to an isolated absolute OS save path before running this review.")
		return
	_proof_prefix = _safe_prefix(OS.get_environment("SNAPLAND_NATIVE_PROOF_TAG").strip_edges())
	_report["proof_prefix"] = _proof_prefix
	_report["save_profile_path"] = save_path
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	if not Progress.save_progress():
		await _fail_and_quit("Could not initialize the isolated review save profile.")
		return
	_library = CharacterAnimationLibraryScript.new()
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(12)
	if _main.world == null or _main.world.npc_activity == null:
		_check(false, "Main scene creates the real island and NPC activity controller")
		await _finish()
		return
	_main.world.blocked = false
	_main.world.npc_activity.set_activity_paused(false)
	_main.hud.hide()
	_main.overlay.hide()
	_main.world.camera.size = 5.0
	_camera_offset = _main.world.camera.global_position - _main.world.player.global_position
	_main.world.set_physics_process(false)
	# Hiding the player node also hides the newly opted-in Hero motion rig.
	_player_was_visible = _main.world.player.visible
	_main.world.player.hide()
	_build_overlay()
	_report["player_and_child_hero_rig_hidden_for_capture"] = true
	_report["npc_activity_opted_in_by_main"] = bool(_main.world.npc_activity.motion_report().enabled)
	var support: Dictionary = _main.world.npc_activity.motion_report()
	_check(bool(support.enabled) and support.supported_roles.size() == ROLES.size(), "Main opts in all three actors with measured gait sources")
	if not _failures.is_empty():
		await _finish()
		return
	var total_started := Time.get_ticks_msec()
	for role in ROLES:
		await _review_role(role)
		if not _failures.is_empty():
			await _finish()
			return
	var total_elapsed := Time.get_ticks_msec() - total_started
	_report["total_review_elapsed_ms"] = total_elapsed
	_report["total_review_seconds"] = float(total_elapsed) / 1000.0
	_check(total_elapsed >= 30000, "three-role review observes at least 30 seconds of real controller runtime")
	_report["godot_version"] = Engine.get_version_info()
	_report["viewport_px"] = str(get_viewport().get_visible_rect().size)
	_report["controller_statistics"] = _main.world.npc_activity.statistics()
	_report["limitations"] = "Scripted camera/player positioning only; NPC roots and controller routes were not repositioned. PNGs require human visual review; no gameplay-success claim."
	await _finish()


func _run_source_cpu_diagnostic() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or save_path.contains("://") or not save_path.is_absolute_path():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated absolute OS save path before running the CPU diagnostic.")
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	if not Progress.save_progress():
		push_error("CPU diagnostic could not initialize its isolated save profile.")
		get_tree().quit(2)
		return
	_library = CharacterAnimationLibraryScript.new()
	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(12)
	if _main.world == null or _main.world.npc_activity == null:
		push_error("CPU diagnostic could not create Main's NPC controller.")
		get_tree().quit(2)
		return
	_main.world.blocked = false
	_main.world.npc_activity.set_activity_paused(false)
	_main.world.set_physics_process(false)
	if OS.get_environment("SNAPLAND_NPC_ROUTE_CPU_DIAGNOSTIC") == "1":
		await _run_route_cpu_diagnostic()
		return
	var ticket := _actor_record("ticket")
	var sprite := ticket.get("sprite") as Sprite3D
	var index: int = _record_index("ticket")
	if not is_instance_valid(sprite) or index < 0:
		push_error("CPU diagnostic could not resolve ticket Sprite and action record.")
		get_tree().quit(2)
		return
	var samples := 0
	var mismatches := 0
	var first_mismatch := ""
	for frame_index in range(650):
		await get_tree().process_frame
		var record: Dictionary = _main.world.npc_activity._records[index]
		var motion: Variant = record.get("motion")
		if not sprite.visible or (motion != null and bool(motion.active)):
			continue
		samples += 1
		var sequence := record.get("action_sequence", {}) as Dictionary
		if not _source_frame_matches("ticket", sequence, sprite):
			mismatches += 1
			if first_mismatch.is_empty():
				first_mismatch = "process_frame=%d action=%s elapsed=%.3f sequence_frames=%d %s" % [
					frame_index + 1, String(record.get("action", "")), float(record.get("action_elapsed", 0.0)),
					sequence.get("frames", []).size(), _source_frame_diagnostic("ticket", sequence, sprite)
				]
	print("SOURCE_CPU_DIAGNOSTIC frames=650 samples=%d mismatches=%d first_mismatch=%s" % [samples, mismatches, first_mismatch])
	if samples == 0 or mismatches > 0:
		push_error("CPU source-frame diagnostic failed to establish matching authored pixels: " + first_mismatch)
		get_tree().quit(1)
	else:
		print("PASS: every observed ticket source-Sprite frame matched its loaded action sequence")
		get_tree().quit(0)


func _run_route_cpu_diagnostic() -> void:
	# Measure the announcer's complete authored cycle in Main. No NPC root,
	# clock, animation, or route state is moved or advanced by the fixture.
	await _diagnose_announcer_route_bounds()
	if not _failures.is_empty():
		await _finish()
		return
	# Then observe each role's first real route-start frame.
	for role in ROLES:
		var actor := _actor_record(role)
		var sprite := actor.get("sprite") as Sprite3D
		var activity_root := actor.get("activity_root") as Node3D
		var point: Dictionary = _main.world._point_by_id(String(ROLE_POINT[role]))
		var motion: Variant = _main.world.npc_activity._records[_record_index(role)].get("motion")
		var was_active := bool(motion.active)
		var started := false
		var deadline := Time.get_ticks_msec()+30000
		while Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if motion.active and not was_active:
				started = true
				break
			was_active = bool(motion.active)
		if not _check(started,role+" CPU diagnostic observes a natural route start"):
			break
		if not await _review_own_route(role,motion,sprite,activity_root,point):
			break
	await _finish()


func _review_role(role: String) -> void:
	var actor := _actor_record(role)
	var sprite := actor.get("sprite") as Sprite3D
	var activity_root := actor.get("activity_root") as Node3D
	var point_id := String(ROLE_POINT[role])
	var point: Dictionary = _main.world._point_by_id(point_id)
	var controller: Node = _main.world.npc_activity
	var record_index := _record_index(role)
	if not _check(is_instance_valid(sprite) and is_instance_valid(activity_root) and not point.is_empty(), role + " has its actual world sprite, root, and interaction point"):
		return
	if not _check(record_index >= 0, role + " has a live NpcActivity record"):
		return
	var motion: Variant = controller._records[record_index].get("motion")
	if not _check(motion != null and motion.supported and motion.rig.source_records.size() == 2, role + " uses exactly the measured left/right rig records"):
		return
	var role_start := Time.get_ticks_msec()
	var root_start: Vector3 = activity_root.global_position
	var point_start: Vector3 = point.position
	_focus_actor(role, activity_root)
	var summary := {
		"interaction_point_id": point_id,
		"start_root_world": str(root_start),
		"start_point_world": str(point_start),
		"normal_rest_duration_seconds_required": REST_IDLE_SECONDS,
		"npc_role_motion_enabled": true,
		"motion_views": _motion_view_report(role, motion),
		"authored_action_coverage": {},
		"captures": [],
	}
	_report.roles[role] = summary
	if not await _wait_for_rest(role, 30.0):
		_check(false, role + " reaches a natural resting source-Sprite phase without moving its root by fixture")
		return
	var idle_started := Time.get_ticks_msec()
	var idle_root: Vector3 = activity_root.global_position
	var route_record: Dictionary = controller._records[record_index]
	var route_origin := _route_origin_world(activity_root, route_record)
	var route_excursion_max := 0.0
	var route_bounds_failure := ""
	if not await _capture_actor(role, "idle-rest", "Natural source-Sprite rest; three seconds of controller runtime", true):
		return
	var rest_accumulated := 0.0
	var rest_deadline := Time.get_ticks_msec() + 22000
	var last_tick := Time.get_ticks_msec()
	while rest_accumulated < REST_IDLE_SECONDS and Time.get_ticks_msec() < rest_deadline:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		var delta := float(now - last_tick) / 1000.0
		last_tick = now
		var current: Dictionary = controller._records[_record_index(role)]
		var current_offset: Vector3 = activity_root.global_position - route_origin
		route_excursion_max = maxf(route_excursion_max, absf(current_offset.x))
		if route_bounds_failure.is_empty() and not _within_authored_route_bounds(role, current_offset):
			route_bounds_failure = "offset=%s half_width=%.3f origin=%s" % [str(current_offset), float(AUTHORED_ROUTE_HALF_WIDTH[role]), str(route_origin)]
		if not motion.active and sprite.visible and String(current.action) in ["idle", "stand", "idle_gesture", "emotion_happy", "emotion_proud", "dance", "special", "emotion_curious"]:
			rest_accumulated += delta
	_check(rest_accumulated >= REST_IDLE_SECONDS, role + " accumulates at least three seconds in its authored non-gait rest/activity states")
	if not _failures.is_empty(): return
	summary["rest_observed_seconds"] = rest_accumulated
	summary["rest_elapsed_wall_ms"] = Time.get_ticks_msec() - idle_started
	summary["rest_root_delta"] = str(activity_root.global_position - idle_root)
	summary["rest_route_origin_world"] = str(route_origin)
	summary["rest_max_abs_route_axis_offset_m"] = route_excursion_max
	summary["rest_route_bounds_failure"] = route_bounds_failure
	_check(route_bounds_failure.is_empty(), role + " remains within its authored route envelope during rest observation; max_abs_x=%.3fm half_width=%.3fm failure=%s" % [route_excursion_max, float(AUTHORED_ROUTE_HALF_WIDTH[role]), route_bounds_failure])
	if not _failures.is_empty(): return
	if not await _review_action(role, "greet", sprite): return
	if not await _review_action(role, "interact", sprite): return
	if not await _review_personality_actions(role, sprite, ROLE_IDLE_ACTIONS[role]): return
	if not await _review_own_route(role, motion, sprite, activity_root, point): return
	var elapsed := Time.get_ticks_msec() - role_start
	_check(elapsed >= 9000, role + " receives at least nine seconds of normal live runtime")
	_check(activity_root.global_position.distance_to(point.position) <= FRAME_POINT_TOLERANCE, role + " final interaction point follows its live actor root")
	if _failures.is_empty():
		summary["elapsed_wall_ms"] = elapsed
		summary["end_root_world"] = str(activity_root.global_position)
		summary["end_point_world"] = str(point.position)
		summary["point_delta"] = activity_root.global_position.distance_to(point.position)
		summary["legacy_fallback_used"] = bool(controller._records[_record_index(role)].action_sequence.get("legacy_fallback", false))
		summary["action_frame_counts"] = _action_source_counts(role)
		_report.roles[role] = summary


func _review_action(role: String, action: String, sprite: Sprite3D) -> bool:
	if not await _wait_for_rest(role, 24.0, action):
		_check(false, role + " reaches a natural rest window before " + action)
		return false
	var motion: Variant = _main.world.npc_activity._records[_record_index(role)].motion
	var accepted := bool(_main.world.npc_activity.call(action, sprite, "front"))
	if not _check(accepted, role + " controller accepts authored " + action + " action"):
		return false
	await _frames(2)
	var action_record: Dictionary = _main.world.npc_activity._records[_record_index(role)]
	if not _check(String(action_record.action) == action and not motion.active and sprite.visible, role + " presents authored " + action + " on its source Sprite, not the gait rig"):
		return false
	if not _check(_action_source_count(role, action, "front") > 0 and not bool(action_record.action_sequence.get("legacy_fallback", false)), role + " " + action + " is backed by its named loaded source sequence"):
		return false
	if not await _capture_actor(role, action, "NpcActivity.%s from the actor's loaded authored action sequence" % action, true):
		return false
	return true


func _review_personality_actions(role: String, sprite: Sprite3D, actions: Array) -> bool:
	var seen: Dictionary = {}
	var deadline := Time.get_ticks_msec() + 60000
	while seen.size() < 2 and Time.get_ticks_msec() < deadline:
		var index := _record_index(role)
		if index < 0: break
		var record: Dictionary = _main.world.npc_activity._records[index]
		var action := String(record.action)
		var motion: Variant = record.get("motion")
		if actions.has(action) and sprite.visible and motion != null and not motion.active and not seen.has(action):
			if not _check(_action_source_count(role, action, "front") > 0 and not bool(record.action_sequence.get("legacy_fallback", false)), role + " personality action " + action + " is from its loaded authored sequence"):
				return false
			if not await _capture_actor(role, "personality-" + action, "Naturally scheduled individual idle action: " + action, true):
				return false
			seen[action] = {"action": action, "frame_count": int(record.action_sequence.get("frames", []).size()), "action_elapsed": float(record.action_elapsed)}
		await get_tree().process_frame
	_check(seen.size() >= 2, role + " naturally presents at least two distinct role-specific personality actions")
	if _failures.is_empty():
		var summary: Dictionary = _report.roles[role]
		summary["personality_actions"] = seen
		_report.roles[role] = summary
	return _failures.is_empty()


func _route_origin_world(activity_root: Node3D, record: Dictionary) -> Vector3:
	var parent := activity_root.get_parent() as Node3D
	# route_base is the controller's stable authored anchor. baseline_anchor_position
	# can predate Main's first grounded-anchor update by a few physics frames.
	var local_origin: Vector3 = record.get("baseline_anchor_position", activity_root.position)
	var route_base: Variant = record.get("route_base", null)
	if route_base is Vector3:
		local_origin = route_base
	return parent.global_transform * local_origin if is_instance_valid(parent) else local_origin


func _within_authored_route_bounds(role: String, offset: Vector3) -> bool:
	if not AUTHORED_ROUTE_HALF_WIDTH.has(role):
		return false
	# These routes are authored along X only. Grounding can alter Y, so Y is
	# diagnostic context; Z must remain at the stable authored route origin.
	return absf(offset.x) <= float(AUTHORED_ROUTE_HALF_WIDTH[role]) + ROUTE_AXIS_TOLERANCE and absf(offset.z) <= ROUTE_AXIS_TOLERANCE


func _diagnose_announcer_route_bounds() -> void:
	var role := "announcer"
	var index := _record_index(role)
	var actor := _actor_record(role)
	var anchor := actor.get("activity_root") as Node3D
	if not _check(index >= 0 and is_instance_valid(anchor), "CPU route-bound diagnostic resolves announcer record and root"):
		return
	var controller: Node = _main.world.npc_activity
	var initial_clock := float(controller._action_clock)
	var route_record: Dictionary = controller._records[index]
	var origin := _route_origin_world(anchor, route_record)
	var max_abs_x := 0.0
	var max_abs_y := 0.0
	var max_abs_z := 0.0
	var samples := 0
	var wall_deadline := Time.get_ticks_msec() + 20000
	while float(controller._action_clock) - initial_clock < 8.6 and Time.get_ticks_msec() < wall_deadline:
		await get_tree().process_frame
		var offset: Vector3 = anchor.global_position - origin
		max_abs_x = maxf(max_abs_x, absf(offset.x))
		max_abs_y = maxf(max_abs_y, absf(offset.y))
		max_abs_z = maxf(max_abs_z, absf(offset.z))
		if not _within_authored_route_bounds(role, offset):
			_check(false, "announcer actual Main route stays within authored half-width 0.600m; observed offset=" + str(offset))
			return
		samples += 1
	var elapsed := float(controller._action_clock) - initial_clock
	_check(elapsed >= 8.6 and samples > 0, "CPU diagnostic observes a complete announcer route cycle; elapsed=%.3fs samples=%d" % [elapsed, samples])
	if _failures.is_empty():
		print("ANNOUNCER_ROUTE_BOUNDS_CPU_DIAGNOSTIC elapsed=%.3f samples=%d origin=%s max_abs_x=%.6f max_abs_y=%.6f max_abs_z=%.6f half_width=0.600 tolerance=%.3f (Y/Z recorded, not route axes)" % [elapsed, samples, str(origin), max_abs_x, max_abs_y, max_abs_z, ROUTE_AXIS_TOLERANCE])


func _review_own_route(role: String, motion: Variant, sprite: Sprite3D, activity_root: Node3D, point: Dictionary) -> bool:
	var deadline := Time.get_ticks_msec() + 24000
	var start_position: Vector3 = activity_root.global_position
	var previous_position := start_position
	var greatest_distance := 0.0
	var sample_frames := 0
	while Time.get_ticks_msec() < deadline:
		var index := _record_index(role)
		var record: Dictionary = _main.world.npc_activity._records[index]
		var delta := activity_root.global_position - start_position
		var frame_delta := activity_root.global_position - previous_position
		var route_record: Dictionary = _main.world.npc_activity._records[index]
		var route_offset: Vector3 = activity_root.global_position - _route_origin_world(activity_root, route_record)
		if not _within_authored_route_bounds(role, route_offset):
			_check(false, role + " root remains inside its authored route envelope; offset=" + str(route_offset))
			return false
		var frame_distance := Vector2(frame_delta.x,frame_delta.z).length()
		previous_position = activity_root.global_position
		sample_frames += 1
		greatest_distance = maxf(greatest_distance, Vector2(delta.x, delta.z).length())
		# The adapter activates on the first real route delta (ticket moves only
		# 4.17 mm/frame at 60 FPS). Wait for measurable travel and a still-moving
		# frame; the rig's settling visibility alone does not prove movement.
		if motion.active and motion.rig.visible and not sprite.visible and greatest_distance>0.01 and frame_distance>0.0001:
			if not _check(String(motion.rig.direction) in ["left", "right"] and motion.rig.source_records.has(String(motion.rig.direction)), role + " live gait displays a measured source direction while its own route moves"):
				return false
			if not _check(greatest_distance > 0.01 and frame_distance>0.0001, role + " gait is driven by actual actor-root displacement, not a fixture-only rig animation"):
				return false
			if not _check(activity_root.global_position.distance_to(point.position) <= FRAME_POINT_TOLERANCE, role + " interaction point tracks the moving root during measured gait"):
				return false
			if OS.get_environment("SNAPLAND_NPC_ROUTE_CPU_DIAGNOSTIC") == "1":
				print("ROUTE_CPU_DIAGNOSTIC role=%s root_displacement_m=%.6f frame_displacement_m=%.6f observed_frames=%d rig_speed_mps=%.6f" % [role,greatest_distance,frame_distance,sample_frames,float(motion.rig.speed)])
				return true
			if not await _capture_actor(role, "native-route-gait-" + String(motion.rig.direction), "Actual Main NPC route; measured rig direction=%s" % String(motion.rig.direction), false):
				return false
			var settled := await _wait_for_settle(role, 4.0)
			if not _check(settled and not motion.active and sprite.visible and not motion.rig.visible, role + " measured gait settles back to the same NPC's authored Sprite"):
				return false
			if not await _capture_actor(role, "native-route-settle", "Same NPC after actual route deceleration and rig cleanup", true):
				return false
			if not _failures.is_empty(): return false
			var summary: Dictionary = _report.roles[role]
			summary["route_max_root_displacement_m"] = greatest_distance
			summary["route_sample_frames"] = sample_frames
			summary["route_capture_frame_displacement_m"] = frame_distance
			summary["route_direction"] = String(motion.rig.direction)
			summary["measured_gait_source"] = _motion_view_report(role, motion)
			_report.roles[role] = summary
			return true
		await get_tree().process_frame
	_check(false, role + " reaches its own natural route while the measured walk rig is visible")
	return false


func _wait_for_rest(role: String, timeout_seconds: float, requested_action: String = "") -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var index := _record_index(role)
		if index >= 0:
			var record: Dictionary = _main.world.npc_activity._records[index]
			var motion: Variant = record.get("motion")
			var sprite: Sprite3D = record.target.get_ref()
			var action := String(record.action)
			var rest_actions: Array = ["idle", "stand"] + ROLE_IDLE_ACTIONS[role]
			var in_announcer_rest := true
			if role == "announcer":
				var phase := fposmod(float(_main.world.npc_activity._action_clock), 8.6)
				if requested_action == "greet": in_announcer_rest = phase >= 1.15 and phase <= 1.30
				elif requested_action == "interact": in_announcer_rest = phase >= 5.55 and phase <= 5.70
				else: in_announcer_rest = (phase >= 1.0 and phase < 3.3) or (phase >= 5.4 and phase < 7.6)
			if motion != null and not motion.active and sprite.visible and not motion.rig.visible and rest_actions.has(action) and in_announcer_rest:
				return true
		await get_tree().process_frame
	return false


func _wait_for_settle(role: String, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var record: Dictionary = _main.world.npc_activity._records[_record_index(role)]
		var motion: Variant = record.get("motion")
		if motion != null and not motion.active and motion.rig.blend < 0.08 and record.target.get_ref().visible:
			return true
		await get_tree().process_frame
	return false


func _focus_actor(role: String, actor_root: Node3D) -> void:
	_main.world.player.global_position = actor_root.global_position + Vector3(0.0, 0.0, 1.8)
	var camera: Camera3D = _main.world.camera
	camera.global_position = _main.world.player.global_position + _camera_offset
	camera.look_at(_main.world.player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.global_position += camera.global_basis.y * CAMERA_UP_SHIFT
	camera.size = 5.0
	camera.current = true
	_main.world._update_sprite_grounding()
	_set_caption(role, "Natural world rest | authored front Sprite")


func _capture_actor(role: String, phase: String, note: String, require_source_sprite: bool) -> bool:
	var state := "measured gait %s" % String(_main.world.npc_activity._records[_record_index(role)].motion.rig.direction) if not require_source_sprite else "authored %s" % String(_main.world.npc_activity._records[_record_index(role)].action)
	_set_caption(role, "%s | %s" % [phase.replace("-", " "), state])
	await RenderingServer.frame_post_draw
	var actor := _actor_record(role)
	var sprite := actor.get("sprite") as Sprite3D
	var activity_root := actor.get("activity_root") as Node3D
	var index := _record_index(role)
	if not _check(is_instance_valid(sprite) and is_instance_valid(activity_root) and index >= 0, role + " capture resolves the real actor"):
		return false
	var record: Dictionary = _main.world.npc_activity._records[index]
	var motion: Variant = record.get("motion")
	if not _check(motion != null and motion.supported, role + " keeps its measured adapter for every evidence capture"):
		return false
	var camera: Camera3D = _main.world.camera
	var viewport_rect := get_viewport().get_visible_rect()
	var source_bounds := _project_sprite_alpha_bounds(sprite, camera) if sprite.visible else Rect2()
	var gait_bounds: Array[Dictionary] = []
	var gait_union := Rect2()
	var gait_parts: Array = []
	if motion.rig.visible:
		gait_parts = motion.rig.find_children("*", "VisualInstance3D", true, false)
		for child in gait_parts:
			var visual := child as VisualInstance3D
			if not is_instance_valid(visual) or not visual.is_visible_in_tree(): continue
			var bounds := _project_visual_bounds(visual, camera)
			gait_bounds.append({"name": String(visual.name), "bounds_px": str(bounds)})
			gait_union = bounds if gait_union.size == Vector2.ZERO else gait_union.merge(bounds)
	var use_gait: bool = motion.rig.visible
	if not _check(use_gait != require_source_sprite, role + " capture uses the requested actual visual layer (source Sprite or measured gait rig)"):
		return false
	var measured_bounds := gait_union if use_gait else source_bounds
	if not _check(_bounds_with_padding(measured_bounds, viewport_rect), role + " full visible head-to-feet bounds retain 12px padding at " + phase + ": " + str(measured_bounds)):
		return false
	if use_gait:
		if not _check(motion.active and gait_parts.size() > 0 and gait_bounds.size() > 0, role + " is presenting actual visible measured-rig parts, not its hidden action Sprite"):
			return false
		var visible_names: Array[String] = []
		for item in gait_bounds: visible_names.append(String(item.name))
		if not _check(motion.rig._upper != null and motion.rig._upper.is_visible_in_tree() and motion.rig._boots.size() == 2 and motion.rig._boots[0].is_visible_in_tree() and motion.rig._boots[1].is_visible_in_tree(), role + " visible gait has its actual upper and both boot instances"):
			return false
	else:
		if not _check(sprite.visible and not motion.rig.visible and source_bounds.size.y > 0.0, role + " source action Sprite is visible with its measured alpha silhouette"):
			return false
	var point_id := String(ROLE_POINT[role])
	var point: Dictionary = _main.world._point_by_id(point_id)
	var point_delta := activity_root.global_position.distance_to(point.position)
	if not _check(point_delta <= FRAME_POINT_TOLERANCE, role + " captured interaction point follows its actual route root"):
		return false
	var actual_action := String(record.action)
	var actual_direction := String(record.direction)
	var action_sequence := record.get("action_sequence", {}) as Dictionary
	var source_match := _source_frame_matches(role, action_sequence, sprite) if sprite.visible else false
	var source_counts := _action_source_counts(role)
	if require_source_sprite:
		var source_label := role + " visible Sprite pixels match its loaded authored action sequence or exact NPC rest baseline (including measured costume treatment)"
		if not source_match:
			source_label += " | observed=" + _source_frame_diagnostic(role, action_sequence, sprite)
		if not _check(source_match, source_label):
			return false
	else:
		var view_record: Dictionary = motion.rig.source_records.get(String(motion.rig.direction), {})
		if not _check(view_record.get("source") is Image and bool(view_record.get("valid", false)), role + " gait uses a valid immutable measured image for " + String(motion.rig.direction)):
			return false
		if not _check(not sprite.visible and motion.rig.visible and motion.rig.direction in ["left", "right"], role + " rig view is distinct from the old authored six-cel idle Sprite"):
			return false
	var image := get_viewport().get_texture().get_image()
	if not _check(image.get_size() == Vector2i(1280, 720), "native capture is 1280x720"):
		return false
	var filename := "%s-%s-%s.png" % [_proof_prefix, role, _safe_prefix(phase)]
	var relative := PROOF_DIRECTORY.path_join(filename)
	var path := ProjectSettings.globalize_path("res://" + relative)
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		_check(false, "Could not create island NPC evidence directory: " + str(error))
		return false
	if image.save_png(path) != OK:
		_check(false, "Could not write native NPC screenshot: " + path)
		return false
	var capture := {
		"path": relative,
		"role": role,
		"phase": phase,
		"description": note,
		"engine_frame": Engine.get_process_frames(),
		"elapsed_ms": Time.get_ticks_msec(),
		"controller_action": actual_action,
		"controller_direction": actual_direction,
		"action_source_match": source_match,
		"action_frame_counts": source_counts,
		"gait_rig_visible": use_gait,
		"gait_rig_direction": String(motion.rig.direction) if use_gait else "",
		"gait_source_record": _motion_view_report(role, motion) if use_gait else {},
		"source_alpha_bounds_px": str(source_bounds),
		"rig_visible_part_bounds_px": gait_bounds,
		"visible_full_body_bounds_px": str(measured_bounds),
		"padding_px": CAPTURE_PADDING_PX,
		"root_world": str(activity_root.global_position),
		"interaction_point_id": point_id,
		"interaction_point_world": str(point.position),
		"interaction_point_delta_m": point_delta,
		"sprite_visible": sprite.visible,
		"sprite_pixel_size": sprite.pixel_size,
	}
	_report.captures.append(capture)
	var summary: Dictionary = _report.roles.get(role, {})
	var captures: Array = summary.get("captures", [])
	captures.append(capture)
	summary["captures"] = captures
	_report.roles[role] = summary
	_write_report()
	return true


func _project_sprite_alpha_bounds(sprite: Sprite3D, camera: Camera3D) -> Rect2:
	if sprite.texture == null: return Rect2()
	var image := sprite.texture.get_image()
	if image == null or image.is_empty(): return Rect2()
	var used := _strong_alpha_bounds(image)
	if used.size.x <= 0 or used.size.y <= 0: return Rect2()
	var aabb: AABB = sprite.get_aabb()
	var left := float(used.position.x) / float(image.get_width())
	var right := float(used.end.x) / float(image.get_width())
	var top := float(used.position.y) / float(image.get_height())
	var bottom := float(used.end.y) / float(image.get_height())
	var plane_basis := camera.global_basis if sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED else sprite.global_basis
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for x_ratio in [left, right]:
		for y_ratio in [top, bottom]:
			var local := Vector3(aabb.position.x + float(x_ratio) * aabb.size.x, aabb.position.y + (1.0 - float(y_ratio)) * aabb.size.y, 0.0)
			var screen := camera.unproject_position(sprite.global_position + plane_basis * local)
			minimum.x = minf(minimum.x, screen.x); minimum.y = minf(minimum.y, screen.y)
			maximum.x = maxf(maximum.x, screen.x); maximum.y = maxf(maximum.y, screen.y)
	return Rect2(minimum, maximum - minimum)


func _strong_alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if roundi(image.get_pixel(x, y).a * 255.0) < 128: continue
			minimum.x = mini(minimum.x, x); minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x); maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y: return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _project_visual_bounds(visual: VisualInstance3D, camera: Camera3D) -> Rect2:
	var aabb: AABB = visual.get_aabb()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in range(8):
		var local := aabb.position + Vector3(
			aabb.size.x if corner & 1 else 0.0,
			aabb.size.y if corner & 2 else 0.0,
			aabb.size.z if corner & 4 else 0.0
		)
		var screen := camera.unproject_position(visual.global_transform * local)
		minimum.x = minf(minimum.x, screen.x); minimum.y = minf(minimum.y, screen.y)
		maximum.x = maxf(maximum.x, screen.x); maximum.y = maxf(maximum.y, screen.y)
	return Rect2(minimum, maximum-minimum)


func _bounds_with_padding(bounds: Rect2, viewport: Rect2) -> bool:
	return bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.position.x >= CAPTURE_PADDING_PX and bounds.position.y >= CAPTURE_PADDING_PX and bounds.end.x <= viewport.size.x-CAPTURE_PADDING_PX and bounds.end.y <= viewport.size.y-CAPTURE_PADDING_PX


func _motion_view_report(role: String, motion: Variant) -> Dictionary:
	var views := {}
	for view in ["left", "right"]:
		var record: Dictionary = motion.rig.source_records.get(view, {})
		var measurement: Dictionary = motion.source_provider.direction_measurement(role, view)
		views[view] = {
			"valid": bool(record.get("valid", false)),
			"source_size_px": str((record.get("source") as Image).get_size()) if record.get("source") is Image else "missing",
			"source_atlas_sha256": String(measurement.get("atlas_sha256", motion.source_provider.measurements_for(role).get("source_sha256", ""))),
			"source_rect": measurement.get("source_rect", []),
			"leg_measurement": measurement.get("leg_measurement", {}),
			"measured_source_geometry": bool(record.get("measured_source_geometry", false)),
		}
	return {"metadata_path": motion.rig.metadata_path, "required_directions": motion.rig.required_directions, "rig_source_records": views, "old_idle_front_frame_count": _action_source_count(role, "idle", "front"), "these_are_measured_directional_source_cells_not_the_old_front_animation_sequence": true}


func _source_frame_matches(role: String, action_sequence: Dictionary, sprite: Sprite3D) -> bool:
	if sprite.texture == null: return false
	var live_image := sprite.texture.get_image()
	if live_image == null: return false
	var frames: Array = action_sequence.get("frames", [])
	for frame in frames:
		if not frame is Dictionary: continue
		var source_texture := frame.get("texture") as Texture2D
		if not is_instance_valid(source_texture): continue
		if role == "announcer" and not bool(action_sequence.get("legacy_fallback", false)):
			source_texture = _main.world.npc_activity._costume_texture(role, source_texture)
		if source_texture == sprite.texture: return true
		var source_image := source_texture.get_image()
		if source_image != null and source_image.get_size() == live_image.get_size() and source_image.get_data() == live_image.get_data(): return true
	# Main initializes this actor with NpcActivity's authored rest texture. A
	# failed/missing stand sequence restores that exact baseline and leaves the
	# active sequence empty; verify that source directly instead of rejecting a
	# legitimate rest Sprite or accepting arbitrary pixels.
	if frames.is_empty() and _current_action_for_role(role) == "stand":
		return _baseline_rest_frame_matches(role, sprite)
	return false


func _source_frame_diagnostic(role: String, action_sequence: Dictionary, sprite: Sprite3D) -> String:
	var material := sprite.material_override as ShaderMaterial
	var shader_texture: Texture2D = material.get_shader_parameter("texture_albedo") as Texture2D if material != null and material.shader != null else null
	var sprite_id := sprite.texture.get_instance_id() if sprite.texture != null else 0
	var shader_id := shader_texture.get_instance_id() if shader_texture != null else 0
	var live_image := sprite.texture.get_image() if sprite.texture != null else null
	var idle_sequence: Dictionary = _library.get_sequence(role, "idle", "front") if _library != null else {}
	var idle_match := _source_frame_matches(role, idle_sequence, sprite) if not idle_sequence.is_empty() else false
	var baseline_match := _baseline_rest_frame_matches(role, sprite)
	var frames: Array[String] = []
	var matching_resource_ids: Array[int] = []
	var matching_pixel_ids: Array[int] = []
	for frame in action_sequence.get("frames", []):
		if not frame is Dictionary: continue
		var texture := frame.get("texture") as Texture2D
		if not is_instance_valid(texture): continue
		if role == "announcer" and not bool(action_sequence.get("legacy_fallback", false)):
			texture = _main.world.npc_activity._costume_texture(role, texture)
		if texture == sprite.texture or texture == shader_texture:
			matching_resource_ids.append(texture.get_instance_id())
		var source_image := texture.get_image()
		if live_image != null and source_image != null and live_image.get_size() == source_image.get_size() and live_image.get_data() == source_image.get_data():
			matching_pixel_ids.append(texture.get_instance_id())
		frames.append("%s:%s" % [texture.get_instance_id(), str(texture.get_size())])
	return "action=%s dir=%s elapsed=%.3f frames=%d sprite_tex=%d shader_tex=%d resource_matches=%s pixel_matches=%s loaded_idle_match=%s loaded_idle_frames=%d loaded_rest_baseline_match=%s frame_textures=%s" % [
		String(_current_action_for_role(role)),
		String(action_sequence.get("direction", "")),
		float(action_sequence.get("elapsed", -1.0)),
		frames.size(), sprite_id, shader_id,
		str(matching_resource_ids), str(matching_pixel_ids), str(idle_match), idle_sequence.get("frames", []).size(), str(baseline_match), str(frames)
	]


func _baseline_rest_frame_matches(role: String, sprite: Sprite3D) -> bool:
	if sprite.texture == null: return false
	var live_image := sprite.texture.get_image()
	if live_image == null: return false
	for texture in NpcActivityScript.load_action_frames(role):
		var candidate: Texture2D = texture
		if role == "announcer": candidate = _main.world.npc_activity._costume_texture(role, candidate)
		if candidate == sprite.texture: return true
		var source_image := candidate.get_image() if candidate != null else null
		if source_image != null and source_image.get_size() == live_image.get_size() and source_image.get_data() == live_image.get_data(): return true
	return false


func _current_action_for_role(role: String) -> String:
	var index: int = _record_index(role)
	return String(_main.world.npc_activity._records[index].get("action", "<missing>")) if index >= 0 else "<missing>"


func _action_source_counts(role: String) -> Dictionary:
	var counts := {}
	for action in ["idle", "greet", "interact"] + ROLE_IDLE_ACTIONS[role]:
		counts[action + "/front"] = _action_source_count(role, action, "front")
	return counts


func _action_source_count(role: String, action: String, direction: String) -> int:
	var sequence: Dictionary = _library.get_sequence(role, action, direction)
	return int(sequence.get("frames", []).size())


func _actor_record(role: String) -> Dictionary:
	for record: Dictionary in _main.world.character_sprites:
		if String(record.get("role", "")) == role: return record
	return {}


func _record_index(role: String) -> int:
	for index in range(_main.world.npc_activity._records.size()):
		if String(_main.world.npc_activity._records[index].get("role", "")) == role: return index
	return -1


func _safe_prefix(value: String) -> String:
	var candidate := value if not value.is_empty() else "island_npc_final"
	var result := ""
	for index in range(candidate.length()):
		var character := candidate.substr(index, 1)
		if character.is_valid_identifier() or character.is_valid_int() or character == "-": result += character
	return result if not result.is_empty() else "island_npc_final"


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NativeNpcEvidenceOverlay"
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24.0, 18.0)
	_caption.size = Vector2(1200.0, 42.0)
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color("#fff4dc"))
	_caption.add_theme_color_override("font_shadow_color", Color(0.02, 0.07, 0.08, 0.95))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_caption)


func _set_caption(role: String, state: String) -> void:
	if not is_instance_valid(_caption): return
	var names := {"ticket": "TICKET GUIDE", "imp": "TIDE IMP", "announcer": "ANNOUNCER"}
	_caption.text = "%s   |   %s   |   scripted native evidence, human review pending" % [String(names.get(role, role.to_upper())), state.to_upper()]


func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame


func _check(condition: bool, message: String) -> bool:
	if condition:
		print("PASS: " + message)
		return true
	_failures.append(message)
	push_error("FAIL: " + message)
	_write_report()
	return false


func _finish() -> void:
	_report["failures"] = _failures.duplicate()
	_report["result"] = "PASS" if _failures.is_empty() else "FAIL"
	var report_path := _write_report()
	if is_instance_valid(_main):
		if is_instance_valid(_main.world) and is_instance_valid(_main.world.player): _main.world.player.visible = _player_was_visible
		if is_instance_valid(_main.audio): _main.audio.shutdown()
		_main.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("PASS: Main-backed island NPC evidence fixture; human visual acceptance remains pending: " + report_path)
		get_tree().quit(0)
	else:
		push_error("Main-backed island NPC fixture failed: %d issue(s); see %s" % [_failures.size(), report_path])
		get_tree().quit(1)


func _write_report() -> String:
	var path := ProjectSettings.globalize_path("res://" + PROOF_DIRECTORY.path_join(_proof_prefix + "-report.json"))
	if OS.get_environment("SNAPLAND_NPC_ROUTE_CPU_DIAGNOSTIC") == "1":
		path = OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("npc-route-cpu-report.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	return path


func _fail_and_quit(message: String) -> void:
	push_error(message)
	_failures.append(message)
	_report["result"] = "FAIL"
	_report["failures"] = _failures.duplicate()
	_write_report()
	get_tree().quit(1)
