extends Node
## Bounded Main-backed animation evidence. All inputs and framing are scripted;
## the resulting clips require human visual review and are not a playthrough.

const MainScene := preload("res://game/main.tscn")
const TestSaveGuard := preload("res://game/core/test_save_guard.gd")
const AnimationLibraryScript := preload("res://game/world/character_animation_library.gd")
const NpcActivityScript := preload("res://game/world/npc_activity.gd")
const ROLES := ["traveller", "ticket", "imp", "announcer"]
const NPC_POINT := {"ticket": "guide", "imp": "quest-001", "announcer": "quest-002"}
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const NPC_EMOTION := {"ticket": "happy", "imp": "proud", "announcer": "curious"}
const NPC_SPECIAL := {"ticket": "idle_gesture", "imp": "dance", "announcer": "special"}
const MAX_SIMULATION_SECONDS := 60.0
const CAMERA_UP_SHIFT := 0.0
const FRAME_PADDING := 12.0
const HUD_TOP_SAFE := 116.0
const HUD_BOTTOM_SAFE := 84.0

var _main: Node
var _world: Node
var _actor := ""
var _output := ""
var _report: Dictionary = {}
var _failures: Array[String] = []
var _library: RefCounted
var _simulated_seconds := 0.0
var _movie_fps := 0.0
var _start_process_frame := 0
var _output_validated := false
var _camera_offset := Vector3.ZERO
var _camera_up_correction := 0.0
var _framing_can_pin := false
var _framing_locked := false
var _framing_pin_seconds := -1.0
var _held_keys: Array[int] = []
var _observation: Dictionary = {}
var _buffered_captures: Array[Dictionary] = []
var _alpha_rect_cache: Dictionary = {}

func _ready() -> void:
	process_priority = 100
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	call_deferred("_run")

func _process(delta: float) -> void:
	_simulated_seconds += maxf(0.0, delta)
	if is_instance_valid(_world) and is_instance_valid(_world.camera):
		_focus_live_actor()

func _run() -> void:
	_start_process_frame = Engine.get_process_frames()
	if DisplayServer.get_name() == "headless":
		print("Animation acceptance rejected: GPU-backed display is required")
		get_tree().quit(1)
		return
	var args := OS.get_cmdline_user_args()
	_actor = _arg(args, "--actor=")
	_output = _arg(args, "--animation-output=")
	if not ROLES.has(_actor):
		await _finish(false, "Pass --actor=traveller|ticket|imp|announcer")
		return
	if not _valid_isolated_paths():
		await _finish(false, "SNAPLAND_SAVE_PATH and --animation-output must be isolated absolute OS paths; output must be empty/new")
		return
	_output_validated = true
	var quarter := args.has("--quarter")
	var actions_only := args.has("--actions-only")
	var idle_only := args.has("--idle-only")
	if quarter and not actions_only:
		await _finish(false, "Quarter-rate recording must use --actions-only so the 30-second idle segment does not exceed the 60-second video limit")
		return
	if actions_only and idle_only:
		await _finish(false, "Choose either --actions-only or --idle-only")
		return
	var reduced := args.has("--reduced-motion")
	var rebuild := args.has("--rebuild")
	if quarter:
		Engine.time_scale = 0.25
	_report = {
		"fixture": "Main-backed native island animation acceptance",
		"status": "running", "actor": _actor, "human_played": false,
		"scripted_input": true, "placed_camera": true, "camera_size": 5.0,
		"initial_actor_placement_changed": _actor == "traveller", "hero_scripted_placement": true, "npc_roots_repositioned": false, "initial_actor_placement_note": "Hero is scripted once to the plaza review patch (-2.6, 0.4, -5.5), whose actual movement is verified by this run; subsequent eight-direction movement uses real keyboard input without teleport or facing presets." if _actor == "traveller" else "Selected NPC root and route are unchanged. The hero is repositioned near the NPC every fixture frame as a scripted camera helper; this is not natural hero movement evidence.", "initial_hero_position": [-2.6, 0.4, -5.5] if _actor == "traveller" else null, "camera_placement_note": "Review camera is framed on the live actor and foot baseline, framed once from the first complete, grounded and stationary live Sprite, then translated with the actor root using a fixed camera correction and 5-unit orthographic size. NPC roots, routes, and role scale remain unchanged.",
		"playback_mode": "quarter simulation time_scale=0.25" if quarter else "normal simulation time_scale=1.0",
		"expected_movie_slowdown_factor": 4.0 if quarter else 1.0,
		"segment_mode": "actions-only" if actions_only else ("idle-only" if idle_only else "natural-idle-and-actions"),
		"movie_writer_active": OS.has_feature("movie"),
		"reduced_motion": reduced, "scene_rebuild": rebuild,
		"actions": [], "failures": _failures, "capture_png": [], "captured_frame_framing": [], "natural_action_windows": [],
		"expected_movie_fps": _expected_movie_fps(args), "encoded_movie_metadata": "pending ffprobe verification by root", "fixed_fps": 0.0, "movie_writer_frame_count": null, "movie_duration_estimate_seconds": 0.0,
	}
	get_window().size = Vector2i(1280, 720)
	var progress := get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _finish(false, "Progress autoload missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	if args.has("--coral-jacket"):
		progress.equipped["outfit"] = "outfit-coral"
	_report["wardrobe_profile"] = "catalog-coral-jacket" if args.has("--coral-jacket") else "default"
	progress.settings["reduced_motion"] = reduced
	var passes := 2 if rebuild else 1
	for pass_index in range(passes):
		if not await _build_main(progress): return
		if pass_index == 0 and rebuild:
			await _record_action("scene-before-rebuild", "scene", "rebuild", "pending", {}, true)
			await _release_main()
			await _frames(3)
			continue
		break
	if not is_instance_valid(_main): return
	_world = _main.world
	_world.apply_settings(progress.settings)
	_library = AnimationLibraryScript.new()
	if _library.manifest.is_empty():
		_fail("animation library manifest unavailable")
		await _finish(false)
		return
	_movie_fps = _read_movie_fps()
	_report["fixed_fps"] = _movie_fps
	_report["movie_fps_source"] = "Godot fixed movie process delta" if OS.has_feature("movie") else "not recording movie"
	_report["starting_anchor"] = _actor_anchor()
	_focus_live_actor()
	await _capture("start")
	if not actions_only:
		await _observe_idle(30.0)
	if not reduced and not idle_only:
		if _actor == "traveller": await _hero_actions()
		else: await _npc_actions()
	elif reduced:
		await _record_action("reduced-motion", "idle", "front", _current_source(), _actor_anchor(), _valid_reduced_motion())
		await _capture("reduced-motion")
	if not _within_budget():
		_fail("simulation budget exceeded 60 seconds")
	_report["simulation_seconds"] = _simulated_seconds
	_report["ending_anchor"] = _actor_anchor()
	_report["npc_activity_clock"] = float(_world.npc_activity._action_clock) if _actor != "traveller" else -1.0
	await _finish(_failures.is_empty())

func _build_main(progress: Node) -> bool:
	_camera_up_correction = 0.0
	_framing_can_pin = false
	_framing_locked = false
	_framing_pin_seconds = -1.0
	_main = MainScene.instantiate()
	_main.name = "AnimationAcceptanceMain"
	get_tree().root.add_child(_main)
	await _frames(12)
	if not is_instance_valid(_main) or _main.world == null:
		_fail("Main did not create ParkWorld")
		await _finish(false)
		return false
	_world = _main.world
	if not String(_main.modal_kind).is_empty() or _main.session != null:
		_fail("Main startup did not reach unobstructed island play")
		await _finish(false)
		return false
	_world.blocked = false
	_camera_offset = _world.camera.global_position - _world.player.global_position
	_world.npc_activity.set_activity_paused(false)
	_world.apply_settings(progress.settings)
	if _actor == "traveller":
		_world.player.position = Vector3(-2.6, 0.4, -5.5)
	else:
		var actor_record := _actor_record(_actor)
		if actor_record.is_empty():
			_fail("Main is missing selected live NPC")
			await _finish(false)
			return false
	var grounding := await _wait_initial_grounding()
	_report["initial_grounding"] = grounding
	if not bool(grounding.complete):
		_fail("initial live actor did not reach grounded stationary source for three frames")
		await _finish(false)
		return false
	_framing_can_pin = true
	_focus_live_actor()
	return true

func _wait_initial_grounding() -> Dictionary:
	var start := _simulated_seconds
	var stable_frames := 0
	var previous := _actor_anchor()
	var horizontal_speed := 0.0
	var grounded := false
	while _simulated_seconds - start < 3.0 and _within_budget():
		await _frames(1)
		var sprite := _live_sprite()
		var complete_sprite := is_instance_valid(sprite) and sprite.is_visible_in_tree() and sprite.texture != null
		if complete_sprite:
			var image := sprite.texture.get_image()
			complete_sprite = image != null and image.get_used_rect().has_area()
		var anchor := _actor_anchor()
		if _actor == "traveller":
			horizontal_speed = Vector2(_world.player.velocity.x, _world.player.velocity.z).length()
			grounded = _world.player.is_on_floor()
		else:
			horizontal_speed = Vector2(float(anchor.x) - float(previous.x), float(anchor.z) - float(previous.z)).length() / maxf(0.000001, get_process_delta_time())
			grounded = complete_sprite and bool(sprite.get_meta("npc_world_ground_anchor_managed", false))
		previous = anchor
		if complete_sprite and grounded and horizontal_speed <= 0.001 and (_current_action() != "walk" if _actor != "traveller" else not _world.avatar_is_walking): stable_frames += 1
		else: stable_frames = 0
		if stable_frames >= 3: break
	return {"complete": stable_frames >= 3, "stable_process_frames": stable_frames, "grounded": grounded, "horizontal_speed": horizontal_speed, "grounding_method": "live CharacterBody3D is_on_floor" if _actor == "traveller" else "runtime Sprite ground-anchor with stationary NPC root", "simulation_seconds": _simulated_seconds - start}

func _observe_idle(seconds: float) -> void:
	_begin_observation("idle", "")
	var start_position := _actor_anchor()
	var elapsed := 0.0
	var seen_actions: Dictionary = {}
	var seen_frames: Dictionary = {}
	var seen_sources: Dictionary = {}
	var seen_textures: Dictionary = {}
	var transitions: Array[Dictionary] = []
	var previous := ""
	var min_anchor := start_position.duplicate(true)
	var max_anchor := start_position.duplicate(true)
	while elapsed < seconds and _within_budget():
		await _frames(1)
		elapsed += maxf(0.0, get_process_delta_time())
		var action := _current_action()
		var frame_index := _current_frame_index()
		var source := _current_source()
		var texture_id := _live_texture_id()
		seen_actions[action] = true
		seen_sources[source] = true
		if frame_index >= 0:
			var cel := action + "/" + str(frame_index)
			seen_frames[cel] = true
		if texture_id != 0: seen_textures[str(texture_id)] = true
		var state := "%s/%s/%d/%d" % [action, source, frame_index, texture_id]
		if state != previous:
			transitions.append({"simulation_seconds": elapsed, "action": action, "frame_index": frame_index, "source": source, "visible_texture_instance": texture_id})
			previous = state
		var anchor := _actor_anchor()
		for axis in ["x", "y", "z"]:
			min_anchor[axis] = minf(float(min_anchor[axis]), float(anchor[axis]))
			max_anchor[axis] = maxf(float(max_anchor[axis]), float(anchor[axis]))
	var rendered := _end_observation()
	_flush_buffered_captures()
	var scheduler_live := _actor == "traveller" or not bool(_world.npc_activity.statistics().get("activity_paused", true))
	var observable_cels := seen_frames.size() > 1 and seen_textures.size() > 1
	var predicate := elapsed >= seconds * 0.98 and scheduler_live and observable_cels and bool(rendered.source_consistent) and (rendered.frames as Dictionary).size() > 1
	if bool(_report.get("reduced_motion", false)):
		predicate = elapsed >= seconds * 0.98 and _valid_reduced_motion() and not observable_cels
	elif _actor == "traveller":
		predicate = predicate and not _world.avatar_is_walking and _hero_sprite_source_consistent() and seen_sources.has("authored")
	else:
		predicate = predicate and seen_actions.size() > 1 and seen_sources.has("authored")
	await _record_action("natural-idle-30s", "idle", _current_direction(), _current_source(), start_position, predicate, {
		"simulation_seconds": elapsed, "observed_actions": seen_actions.keys(), "observed_source_frames": seen_frames.keys(),
		"observed_sources": seen_sources.keys(), "observed_texture_instances": seen_textures.keys(), "transitions": transitions,
		"scheduler_live": scheduler_live, "observable_source_cel_changes": observable_cels, "rendered_observation": rendered,
		"start_anchor": start_position, "end_anchor": _actor_anchor(), "route_min_anchor": min_anchor, "route_max_anchor": max_anchor,
	})
	await _capture("natural-idle-30s")
	if _actor != "traveller" and not bool(_report.get("reduced_motion", false)): await _observe_npc_route_start_settle()

func _npc_actions() -> void:
	var actor_record := _actor_record(_actor)
	var sprite := actor_record.get("sprite") as Sprite3D
	if not is_instance_valid(sprite):
		_fail("live NPC source Sprite missing")
		return
	var controller: Node = _world.npc_activity
	for action in ["greet", "interact", "emotion_" + String(NPC_EMOTION[_actor]), String(NPC_SPECIAL[_actor])]:
		if _actor == "announcer":
			var window := await _wait_announcer_action_window(String(action))
			_report.natural_action_windows.append(window)
			if not bool(window.complete):
				await _record_action("natural-rest-window-" + String(action), String(action), "front", "pending-natural-rest-window", _actor_anchor(), false, window)
				_fail("announcer natural action window failed for %s: %s" % [String(action), String(window.get("reason", "unavailable"))])
				return
		var direction := "front"
		var accepted := false
		if action == "greet": accepted = controller.greet(sprite, direction)
		elif action == "interact": accepted = controller.interact(sprite, direction)
		elif action == "emotion_" + String(NPC_EMOTION[_actor]): accepted = controller.set_actor_emotion(sprite, String(NPC_EMOTION[_actor]), direction)
		elif action == "special": accepted = controller.play_special(sprite, direction)
		else: accepted = controller.request_action(sprite, action, direction)
		var requested: String = action
		var playback := await _observe_npc_sequence(requested, accepted)
		var source_count := int(playback.get("source_frame_count", 0))
		var has_source := bool(playback.get("authored", false))
		var predicate := bool(playback.get("complete", false)) and has_source
		await _record_action(action, action, direction, "authored" if has_source else "pending-authored-source", _actor_anchor(), predicate, {"requested": requested, "accepted": accepted, "source_frames": source_count, "playback": playback})
		await _capture(action)
		if not has_source:
			if not _report.has("pending"): _report["pending"] = []
			_report["pending"].append("%s/%s authored source unavailable" % [_actor, action])
	var report: Dictionary = controller.coverage_report()
	_report["coverage_report"] = report
	await _wait_npc_settle()

static func _announcer_rest_remaining(phase: float) -> float:
	if phase >= NpcActivityScript.ANNOUNCER_OUTBOUND_SECONDS and phase < NpcActivityScript.ANNOUNCER_FIRST_REST_END:
		return NpcActivityScript.ANNOUNCER_FIRST_REST_END - phase
	if phase >= NpcActivityScript.ANNOUNCER_RETURN_SECONDS and phase < NpcActivityScript.ANNOUNCER_SECOND_REST_END:
		return NpcActivityScript.ANNOUNCER_SECOND_REST_END - phase
	return 0.0

func _wait_announcer_action_window(requested: String) -> Dictionary:
	var sequence := _sequence(requested, "front")
	var frames: Array = sequence.get("frames", [])
	var fps := maxf(0.01, float(sequence.get("fps", 1.0)))
	var available := bool(sequence.get("available", false)) and not frames.is_empty()
	var duration := float(frames.size()) / fps
	var frame_guard := 1.0 / 30.0
	var required_remaining := duration + frame_guard
	var controller: Node = _world.npc_activity
	var start_clock := float(controller._action_clock)
	var start_simulation := _simulated_seconds
	var deadline := start_clock + NpcActivityScript.CYCLE_SECONDS * 2.0
	var wall_deadline := Time.get_ticks_msec() + maxi(10000, roundi(NpcActivityScript.CYCLE_SECONDS * 2.0 / maxf(0.01, Engine.time_scale) * 2000.0))
	var previous := _actor_anchor()
	var previous_clock := start_clock
	var horizontal_speed := 0.0
	var remaining := 0.0
	var phase := fposmod(start_clock, NpcActivityScript.CYCLE_SECONDS)
	var natural_action := _current_action()
	var source_visible := false
	var samples := 0
	var ready := false
	while available and float(controller._action_clock) < deadline and Time.get_ticks_msec() < wall_deadline and _within_budget():
		# Measure a real advancing controller interval; no route/clock mutation.
		await _frames(1)
		var clock := float(controller._action_clock)
		var clock_delta := clock - previous_clock
		var anchor := _actor_anchor()
		horizontal_speed = Vector2(float(anchor.x) - float(previous.x), float(anchor.z) - float(previous.z)).length() / maxf(0.000001, clock_delta)
		previous = anchor
		previous_clock = clock
		samples += 1
		phase = fposmod(clock, NpcActivityScript.CYCLE_SECONDS)
		remaining = _announcer_rest_remaining(phase)
		natural_action = _current_action()
		source_visible = _live_texture_id() != 0 and _current_source() == "authored" and _npc_sprite_source_consistent(_current_frame_index())
		var natural_rest := natural_action in ["stand", "idle", "idle_gesture", "special", "emotion_curious"]
		var enough_budget := MAX_SIMULATION_SECONDS - _simulated_seconds >= required_remaining + 0.5
		if clock_delta > 0.0 and horizontal_speed <= 0.001 and natural_rest and source_visible and remaining >= required_remaining and enough_budget:
			ready = true
			break
		if not enough_budget: break
	var reason := "ready" if ready else ("missing authored front source" if not available else ("simulation budget insufficient" if MAX_SIMULATION_SECONDS - _simulated_seconds < required_remaining + 0.5 else ("wall watchdog expired" if Time.get_ticks_msec() >= wall_deadline else "natural controller window deadline expired")))
	return {"complete": ready, "reason": reason, "requested_action": requested, "authored_source_available": available, "source_frame_count": frames.size(), "source_fps": fps, "sequence_duration_seconds": duration, "frame_guard_seconds": frame_guard, "required_rest_remaining_seconds": required_remaining, "rest_remaining_seconds": remaining, "controller_phase": phase, "natural_action_before_request": natural_action, "source_sprite_visible_and_consistent": source_visible, "root_horizontal_speed": horizontal_speed, "controller_clock_start": start_clock, "controller_clock_end": float(controller._action_clock), "controller_wait_seconds": float(controller._action_clock) - start_clock, "simulation_wait_seconds": _simulated_seconds - start_simulation, "simulation_budget_remaining_seconds": MAX_SIMULATION_SECONDS - _simulated_seconds, "observed_intervals": samples, "watchdog_expired": Time.get_ticks_msec() >= wall_deadline, "clock_or_root_injected": false}

func _observe_npc_route_start_settle() -> void:
	if _actor in ["ticket", "imp"]:
		await _record_action("natural-route-start-settle", "walk", _current_direction(), "pending-authored-walk-source", _actor_anchor(), false, {"note": "No approved walking source; stationary authored idle does not pass walking."})
		return
	var start := _actor_anchor()
	var elapsed := 0.0
	var saw_walk := false
	var saw_settle := false
	var observed: Dictionary = {}
	var positions: Dictionary = {}
	var all_visible := true
	while elapsed < 9.2 and _within_budget():
		await _frames(1)
		elapsed += maxf(0.0, get_process_delta_time())
		if _current_action() == "walk":
			saw_walk = true
			observed[str(_current_frame_index())] = true
			positions[JSON.stringify(_actor_anchor())] = true
			all_visible = all_visible and _live_texture_id() != 0 and _current_source() == "authored"
		elif saw_walk:
			saw_settle = true
			break
	await _record_action("natural-route-start-settle", "walk", _current_direction(), "authored" if saw_walk else "pending-route-source", _actor_anchor(), saw_walk and saw_settle and observed.size() > 1 and positions.size() > 1 and all_visible, {"saw_route_start": saw_walk, "settled": saw_settle, "source_sprite_visible": all_visible, "observed_walk_cels": observed.keys(), "distinct_route_positions": positions.size(), "simulation_seconds": elapsed, "start_anchor": start, "settle_anchor": _actor_anchor()})

func _wait_npc_settle() -> void:
	var elapsed := 0.0
	while elapsed < 3.0 and _current_action() not in ["stand", "idle", "idle_gesture", "special", "walk"] and _within_budget():
		await _frames(1)
		elapsed += maxf(0.0, get_process_delta_time())
	await _record_action("settled-after-authored-actions", _current_action(), _current_direction(), _current_source(), _actor_anchor(), _live_texture_id() != 0 and _current_action() in ["stand", "idle", "idle_gesture", "special", "walk"], {"waited_simulation_seconds": elapsed})

func _observe_npc_sequence(requested: String, accepted: bool) -> Dictionary:
	var record := _npc_record(_actor)
	var sequence: Dictionary = record.get("action_sequence", {})
	var frames: Array = sequence.get("frames", [])
	var authored := String(record.get("action", "")) == requested and bool(sequence.get("available", false)) and not bool(sequence.get("legacy_fallback", false)) and not frames.is_empty()
	if not accepted or not authored: return {"complete": false, "accepted": accepted, "authored": false, "source_frame_count": frames.size()}
	var duration := float(frames.size()) / maxf(0.01, float(sequence.get("fps", 1.0)))
	_begin_observation("npc_sequence", requested)
	var start := _simulated_seconds
	while _simulated_seconds - start < duration + 0.25 and _within_budget():
		await _frames(1)
		if bool(sequence.get("loop", true)) and (_observation.frames as Dictionary).size() >= frames.size(): break
		if _current_action() != requested: break
	var rendered := _end_observation()
	_flush_buffered_captures()
	return {"accepted": accepted, "source_frame_count": frames.size(), "observed_frame_indices": (rendered.frames as Dictionary).keys(), "observed_texture_instances": (rendered.textures as Dictionary).keys(), "rendered_samples": rendered.samples, "simulation_seconds": _simulated_seconds - start, "sequence_duration_seconds": duration, "complete": (rendered.frames as Dictionary).size() >= frames.size() and (rendered.textures as Dictionary).size() > 1 and bool(rendered.source_consistent), "source_consistent": rendered.source_consistent, "authored": authored}

func _npc_sprite_source_consistent(index: int) -> bool:
	var record := _npc_record(_actor)
	var sequence: Dictionary = record.get("action_sequence", {})
	var frames: Array = sequence.get("frames", [])
	if index < 0 or index >= frames.size() or bool(sequence.get("legacy_fallback", false)): return false
	var expected := frames[index].get("texture") as Texture2D
	if _actor == "announcer": expected = _world.npc_activity._costume_texture(_actor, expected)
	var sprite := _actor_record(_actor).get("sprite") as Sprite3D
	return is_instance_valid(sprite) and sprite.is_visible_in_tree() and expected != null and _same_texture_pixels(sprite.texture, expected)

func _hero_actions() -> void:
	var key_pairs := [[KEY_W], [KEY_W, KEY_D], [KEY_D], [KEY_S, KEY_D], [KEY_S], [KEY_S, KEY_A], [KEY_A], [KEY_W, KEY_A]]
	var expected_directions := ["back", "back_right", "right", "front_right", "front", "front_left", "left", "back_left"]
	var directions_seen: Array[String] = []
	for index in key_pairs.size():
		var keys: Array = key_pairs[index]
		var expected: String = expected_directions[index]
		for key in keys: _press(key, true)
		await _physics_frames(3)
		var walk := await _observe_hero_walk(0.5, expected)
		await _record_action("walk-" + expected, "walk", String(_world.facing), "authored-walk-atlas", _actor_anchor(), bool(walk.complete), walk)
		await _capture("walk-" + expected)
		for key in keys: _press(key, false)
		var stop := await _wait_hero_settle()
		var direction := String(_world.facing)
		directions_seen.append(direction)
		await _record_action("stop-" + expected, "idle", direction, _current_source(), _actor_anchor(), bool(stop.complete) and direction == expected and _hero_sprite_source_consistent(), {"settle": stop, "facing_retained": direction == expected, "sprite_visible": _world.avatar.is_visible_in_tree(), "rig_hidden": _hero_rig_hidden()})
	# Request front-only authored gestures from a genuinely backward facing walk.
	for pair in [[KEY_F, "wave"], [KEY_P, "photograph"]]:
		await _face_back_with_keyboard()
		var input_facing := String(_world.facing)
		_press(pair[0], true)
		var action: String = pair[1]
		var playback := await _observe_hero_sequence(action)
		playback["input_facing_before_request"] = input_facing
		_press(pair[0], false)
		await _record_authored_playback(action, playback)
	await _face_back_with_keyboard()
	var interaction_facing := String(_world.facing)
	_world.play_action("interact")
	var interaction_playback := await _observe_hero_sequence("interact")
	interaction_playback["input_facing_before_request"] = interaction_facing
	await _record_authored_playback("interact", interaction_playback)
	var before_look: Dictionary = _world.avatar_appearance.duplicate(true)
	var before_equipped: Dictionary = _world.avatar_equipped.duplicate(true)
	var combos := [
		{"appearance":{"skin":"warm","species":"human","hair":"windswept","hair_color":"ink","face":"curious"},"equipped":{"hat":"hat-straw","outfit":"outfit-coral"}},
		{"appearance":{"skin":"warm","species":"elf","hair":"bob","hair_color":"ink","face":"curious"},"equipped":{"hat":"hat-flower","outfit":"outfit-tide"}},
	]
	for index in combos.size():
		var combo: Dictionary = combos[index]
		_world.set_avatar_look(combo.appearance, combo.equipped)
		_press(KEY_S, true)
		await _physics_frames(3)
		var walk := await _observe_hero_walk(0.5, "front")
		var look_applied: bool = _world.avatar_appearance == combo.appearance and _world.avatar_equipped == combo.equipped
		await _record_action("wardrobe-during-motion-" + str(index), "walk", String(_world.facing), "authored-walk-atlas+avatar-compositor", _actor_anchor(), look_applied and bool(walk.complete), {"appearance": combo.appearance, "equipped": combo.equipped, "playback": walk, "look_applied": look_applied})
		await _capture("wardrobe-during-motion-" + str(index))
		_press(KEY_S, false)
		await _wait_hero_settle()
	_world.set_avatar_look(before_look, before_equipped)
	_report["hero_directions_seen"] = directions_seen
	for direction in expected_directions:
		if not directions_seen.has(direction): _fail("true keyboard input did not produce facing " + direction)

func _observe_hero_walk(seconds: float, expected: String) -> Dictionary:
	var elapsed := 0.0
	var cels: Dictionary = {}
	var textures: Dictionary = {}
	var consistent := true
	var inconsistent_samples: Array[Dictionary] = []
	var start := _actor_anchor()
	while elapsed < seconds and _within_budget():
		await _frames(1)
		# Sample after the world has presented its physics state. At quarter time
		# a physics direction change can precede the next Sprite refresh.
		await RenderingServer.frame_post_draw
		elapsed += maxf(0.0, get_process_delta_time())
		if not _world.avatar_is_walking: continue
		cels[str(_world.last_avatar_frame)] = true
		textures[str(_live_texture_id())] = true
		var pixels_match := _hero_sprite_source_consistent()
		var sample_consistent: bool = pixels_match and String(_world.facing) == expected and String(_world.last_avatar_action) == "walk"
		if not sample_consistent and inconsistent_samples.size() < 8:
			inconsistent_samples.append({"pixels_match": pixels_match, "facing": _world.facing, "presented_direction": _world.last_avatar_direction, "action": _world.last_avatar_action, "frame": _world.last_avatar_frame, "velocity": str(_world.player.velocity)})
		consistent = consistent and sample_consistent
	var moved := start != _actor_anchor()
	return {"complete": moved and consistent and cels.size() > 1 and textures.size() > 1 and _world.avatar_is_walking, "actual_movement": moved, "source_consistent": consistent, "sprite_visible": _world.avatar.is_visible_in_tree(), "rig_hidden": _hero_rig_hidden(), "rig_instantiated": is_instance_valid(_world.avatar_motion_rig), "observed_cels": cels.keys(), "observed_texture_instances": textures.keys(), "simulation_seconds": elapsed, "expected_direction": expected, "inconsistent_samples": inconsistent_samples}

func _record_authored_playback(action: String, playback: Dictionary) -> void:
	var available := bool(playback.get("authored", false))
	await _record_action(action, action, String(playback.get("presented_direction", "")), "authored" if available else "pending-authored-source", _actor_anchor(), bool(playback.get("complete", false)), {"trigger": "keyboard" if action in ["wave", "photograph"] else "runtime action API", "playback": playback})
	await _capture(action + "-after-playback")

func _face_back_with_keyboard() -> void:
	_press(KEY_W, true)
	await _physics_frames(3)
	_press(KEY_W, false)
	var settle := await _wait_hero_settle()
	if not bool(settle.complete) or String(_world.facing) != "back": _fail("real keyboard input did not settle facing back before action request")

func _wait_hero_settle() -> Dictionary:
	var start := _simulated_seconds
	var stable_frames := 0
	while _simulated_seconds - start < 1.0 and _within_budget():
		await _frames(1)
		var horizontal_speed := Vector2(_world.player.velocity.x, _world.player.velocity.z).length()
		if horizontal_speed <= 0.001 and not _world.avatar_is_walking: stable_frames += 1
		else: stable_frames = 0
		if stable_frames >= 3: break
	return {"complete": stable_frames >= 3, "stable_process_frames": stable_frames, "horizontal_speed": Vector2(_world.player.velocity.x, _world.player.velocity.z).length(), "is_walking": _world.avatar_is_walking, "simulation_seconds": _simulated_seconds - start}

func _observe_hero_sequence(action: String) -> Dictionary:
	var sequence := _sequence(action, "front")
	var frames: Array = sequence.get("frames", [])
	var available := not frames.is_empty() and bool(sequence.get("available", false))
	if not available: return {"complete": false, "authored": false, "source_frame_count": frames.size()}
	_begin_observation("hero_sequence", action)
	var start := _simulated_seconds
	var duration := float(frames.size()) / maxf(0.01, float(sequence.get("fps", 1.0)))
	while _simulated_seconds - start < duration + 0.25 and _within_budget():
		await _frames(1)
		if _simulated_seconds - start > 0.05 and _world.avatar_action_remaining <= 0.0: break
	var rendered := _end_observation()
	_flush_buffered_captures()
	return {"complete": (rendered.frames as Dictionary).size() >= frames.size() and bool(rendered.source_consistent), "authored": available, "source_frame_count": frames.size(), "observed_frame_indices": (rendered.frames as Dictionary).keys(), "source_consistent": rendered.source_consistent, "simulation_seconds": _simulated_seconds - start, "sequence_duration_seconds": duration, "action_timer_remaining": float(_world.avatar_action_remaining), "returned_to_idle": _current_action() == "idle", "rendered_samples": rendered.samples, "presented_direction": rendered.get("direction", ""), "presented_action": rendered.get("presented_action", "")}

func _hero_rig_hidden() -> bool:
	return not is_instance_valid(_world.avatar_motion_rig) or not _world.avatar_motion_rig.visible

func _hero_sprite_source_consistent() -> bool:
	if not _world.avatar.is_visible_in_tree() or is_instance_valid(_world.avatar_motion_rig) or _world.avatar.texture == null: return false
	var action: String = _world.last_avatar_action
	var direction: String = _world.last_avatar_direction
	if action not in ["walk", "idle"] and not _library.has_frame("traveller", action, direction): return false
	var texture_action := "walk" if action == "idle" and not _library.has_frame("traveller", "idle", direction) else action
	var expected: Texture2D = _world.avatar_renderer.texture(_world.avatar_appearance, _world.avatar_equipped, direction, int(_world.last_avatar_frame), texture_action)
	return expected != null and _same_texture_pixels(_world.avatar.texture, expected)

func _live_texture_id() -> int:
	var sprite := _world.avatar as Sprite3D if _actor == "traveller" else _actor_record(_actor).get("sprite") as Sprite3D
	return sprite.texture.get_instance_id() if is_instance_valid(sprite) and sprite.is_visible_in_tree() and sprite.texture != null else 0

func _live_sprite() -> Sprite3D:
	return _world.avatar as Sprite3D if _actor == "traveller" else _actor_record(_actor).get("sprite") as Sprite3D

func _same_texture_pixels(actual: Texture2D, expected: Texture2D) -> bool:
	if actual == null or expected == null or actual.get_size() != expected.get_size(): return false
	var actual_image := actual.get_image()
	var expected_image := expected.get_image()
	return actual_image != null and expected_image != null and actual_image.get_format() == expected_image.get_format() and actual_image.get_data() == expected_image.get_data()

func _sprite_screen_bounds(sprite: Sprite3D) -> Rect2:
	if not is_instance_valid(sprite) or sprite.texture == null: return Rect2()
	var key := str(sprite.texture.get_instance_id())
	if not _alpha_rect_cache.has(key):
		var image := sprite.texture.get_image()
		_alpha_rect_cache[key] = image.get_used_rect() if image != null else Rect2i()
	var alpha: Rect2i = _alpha_rect_cache[key]
	var canvas := sprite.texture.get_size()
	var origin := canvas * 0.5 if sprite.centered else Vector2.ZERO
	var scale_x := sprite.global_basis.x.length() * sprite.pixel_size
	var scale_y := sprite.global_basis.y.length() * sprite.pixel_size
	var left := (float(alpha.position.x) - origin.x + sprite.offset.x) * scale_x
	var right := (float(alpha.end.x) - origin.x + sprite.offset.x) * scale_x
	var top := (origin.y - float(alpha.position.y) + sprite.offset.y) * scale_y
	var bottom := (origin.y - float(alpha.end.y) + sprite.offset.y) * scale_y
	var points: Array[Vector2] = []
	for x in [left, right]:
		for y in [top, bottom]:
			points.append(_world.camera.unproject_position(sprite.global_position + _world.camera.global_basis.x * x + _world.camera.global_basis.y * y))
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	return bounds

func _focus_live_actor() -> void:
	var actor_position: Vector3 = _world.player.global_position
	if _actor != "traveller":
		var root := _actor_record(_actor).get("activity_root") as Node3D
		if not is_instance_valid(root): return
		# The hero is only a camera helper in NPC review; keep it outside the
		# framed silhouette so it cannot hide the NPC's knees and shoes.
		_world.player.global_position = root.global_position + Vector3(6.0, 0.0, 1.8)
		actor_position = root.global_position
	_world.camera.size = 5.0
	_world.camera.global_position = actor_position + _camera_offset
	_world.camera.look_at(actor_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_world.camera.current = true
	_world._update_sprite_grounding()
	var sprite := _live_sprite()
	var bounds := _sprite_screen_bounds(sprite)
	var viewport := get_viewport().get_visible_rect().size
	var safe_bottom := viewport.y - HUD_BOTTOM_SAFE
	if is_instance_valid(_main.context_bar) and _main.context_bar.is_visible_in_tree():
		safe_bottom = minf(safe_bottom, _main.context_bar.get_global_rect().position.y - FRAME_PADDING)
	if not _framing_locked:
		var target_y := (HUD_TOP_SAFE + safe_bottom) * 0.5
		var reference: Vector2 = _world.camera.unproject_position(sprite.global_position)
		var up_reference: Vector2 = _world.camera.unproject_position(sprite.global_position + _world.camera.global_basis.y)
		var pixels_per_unit := absf(up_reference.y - reference.y)
		_camera_up_correction = (target_y - bounds.get_center().y) / maxf(1.0, pixels_per_unit)
		if _framing_can_pin and bounds.has_area():
			_framing_locked = true
			_framing_pin_seconds = _simulated_seconds
	# Source-cel and wardrobe bounds are checked below but never move this correction.
	_world.camera.global_position += _world.camera.global_basis.y * _camera_up_correction
	bounds = _sprite_screen_bounds(sprite)
	_report["camera_framing"] = {"orthographic_size": float(_world.camera.size), "camera_up_shift": _camera_up_correction, "correction_pinned": _framing_locked, "pin_simulation_seconds": _framing_pin_seconds, "fixture_adjusted_camera": true, "actor_scale_or_npc_route_changed": false, "sprite_alpha_screen_rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "hud_safe_top": HUD_TOP_SAFE, "hud_safe_bottom": safe_bottom, "head_padding_pixels": bounds.position.y - HUD_TOP_SAFE, "foot_padding_pixels": safe_bottom - bounds.end.y, "full_silhouette_inside_hud_safe_viewport": bounds.position.y >= HUD_TOP_SAFE + FRAME_PADDING and bounds.end.y <= safe_bottom - FRAME_PADDING and bounds.position.x >= FRAME_PADDING and bounds.end.x <= viewport.x - FRAME_PADDING}

func _begin_observation(mode: String, action: String) -> void:
	_observation = {"mode": mode, "action": action, "frames": {}, "textures": {}, "source_consistent": true, "samples": []}

func _end_observation() -> Dictionary:
	var result := _observation
	_observation = {}
	return result

func _on_frame_drawn() -> void:
	if _observation.is_empty() or not is_instance_valid(_world): return
	var action := String(_world.last_avatar_action) if _actor == "traveller" else _current_action()
	var mode := String(_observation.mode)
	if mode != "idle" and action != String(_observation.action): return
	var index := _current_frame_index()
	if index < 0 or _live_texture_id() == 0: return
	var consistent := _hero_sprite_source_consistent() if _actor == "traveller" else _npc_sprite_source_consistent(index)
	if mode != "idle" and _actor == "traveller":
		consistent = consistent and _library.has_frame("traveller", action, String(_world.last_avatar_direction))
	_observation.source_consistent = bool(_observation.source_consistent) and consistent
	if not consistent: return
	_observation["direction"] = String(_world.last_avatar_direction) if _actor == "traveller" else _current_direction()
	_observation["presented_action"] = action
	var key := str(index) if mode != "idle" else "%s/%s/%d" % [action, _current_direction(), index]
	var frames: Dictionary = _observation.frames
	if not frames.has(key):
		var elapsed := float(_world.avatar_action_elapsed) if _actor == "traveller" else float(_npc_record(_actor).get("action_elapsed", 0.0))
		_observation.samples.append({"frame_index": index, "action": action, "direction": _current_direction(), "simulation_seconds": _simulated_seconds, "action_elapsed": elapsed, "process_frame": Engine.get_process_frames()})
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			var label := "natural-" + key.replace("/", "-") if mode == "idle" else action + "-frame-" + str(index)
			_buffered_captures.append({"label": label, "image": image, "framing": _report.get("camera_framing", {}).duplicate(true)})
	frames[key] = true
	_observation.textures[str(_live_texture_id())] = true

func _flush_buffered_captures() -> void:
	for row in _buffered_captures:
		_store_capture(String(row.label), row.image as Image, row.framing as Dictionary)
	_buffered_captures.clear()

func _record_action(label: String, action: String, direction: String, source: String, anchor: Dictionary, predicate: bool, extra := {}) -> void:
	var sequence := _sequence(action, direction)
	var row := {"label": label, "action": action, "direction": direction, "source": source,
		"authored_frames": int(sequence.get("frames", []).size()), "authored_or_rig_source": source,
		"anchor": anchor, "gait_position": _gait_position(), "predicate": predicate,
		"status": "observed" if predicate else "pending", "detail": extra}
	_report.actions.append(row)
	if not predicate:
		if not _report.has("pending"): _report["pending"] = []
		_report["pending"].append(label + ": " + source)
	if not predicate and not str(source).begins_with("pending"):
		_fail("action predicate failed: " + label)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("could not capture viewport PNG for " + label)
		return
	_store_capture(label, image)

func _store_capture(label: String, image: Image, framing: Dictionary = {}) -> void:
	if framing.is_empty(): framing = _report.get("camera_framing", {}).duplicate(true)
	if not bool(framing.get("full_silhouette_inside_hud_safe_viewport", false)): _fail("captured frame outside HUD-safe bounds: " + label)
	_report.captured_frame_framing.append({"label": label, "framing": framing})
	var path := _output.path_join("%s-%s.png" % [_actor, label.validate_filename()])
	if FileAccess.file_exists(path):
		_fail("refusing to overwrite PNG: " + path)
		return
	if image.save_png(path) != OK:
		_fail("failed saving PNG: " + path)
		return
	_report.capture_png.append(path)

func _valid_isolated_paths() -> bool:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or not save_path.is_absolute_path() or save_path.contains("://"): return false
	if _output.is_empty() or not _output.is_absolute_path() or _output.contains("://"): return false
	if not TestSaveGuard.validate_save_path(save_path, OS.get_user_data_dir()).is_empty(): return false
	var err := DirAccess.make_dir_recursive_absolute(_output)
	if err != OK and err != ERR_ALREADY_EXISTS: return false
	var directory := DirAccess.open(_output)
	if directory == null: return false
	directory.list_dir_begin()
	var item := directory.get_next()
	while not item.is_empty():
		if item not in [".", ".."]:
			directory.list_dir_end()
			return false
		item = directory.get_next()
	directory.list_dir_end()
	return true

func _valid_reduced_motion() -> bool:
	return bool(_world.reduced_motion) and (bool(_world.npc_activity.statistics().get("reduced_motion", false)) if _actor != "traveller" else _hero_rig_hidden())

func _actor_record(role: String) -> Dictionary:
	for row in _world.character_sprites:
		if String(row.get("role", "")) == role: return row
	return {}

func _npc_record(role: String) -> Dictionary:
	for row in _world.npc_activity._records:
		if String(row.get("role", "")) == role: return row
	return {}

func _actor_anchor() -> Dictionary:
	var point: Vector3 = _world.avatar.global_position if _actor == "traveller" else (_actor_record(_actor).get("activity_root") as Node3D).global_position
	return {"x": point.x, "y": point.y, "z": point.z}

func _gait_position() -> Dictionary:
	if _actor == "traveller": return {"phase": float(_world.walk_distance_phase), "walking": bool(_world.avatar_is_walking)}
	var record := _npc_record(_actor)
	var motion: Variant = record.get("motion")
	return {"active": bool(motion.active), "position": str(motion.rig.position), "travel": float(motion.rig.travel)} if motion != null else {}

func _current_action() -> String:
	if _actor == "traveller": return String(_world.avatar_action) if _world.avatar_action_remaining > 0.0 else ("walk" if _world.avatar_is_walking else "idle")
	return String(_npc_record(_actor).get("action", ""))

func _current_direction() -> String:
	return String(_world.facing) if _actor == "traveller" else String(_npc_record(_actor).get("direction", "front"))

func _current_source() -> String:
	if _actor == "traveller":
		if _world.avatar_is_walking: return "authored-walk-atlas" if _world.avatar_renderer.has_walk_atlas() else "pending-walk-source"
		return "authored" if _library.has_frame("traveller", _current_action(), _current_direction()) else "held-authored-walk-stance"
	var sequence: Dictionary = _npc_record(_actor).get("action_sequence", {})
	return "authored" if not sequence.is_empty() and not bool(sequence.get("legacy_fallback", false)) else "pending-authored-source"

func _current_frame_index() -> int:
	if _actor == "traveller": return int(_world.last_avatar_frame) if _live_texture_id() != 0 else -1
	var record := _npc_record(_actor)
	var sequence: Dictionary = record.get("action_sequence", {})
	var frames: Array = sequence.get("frames", [])
	if frames.is_empty(): return -1
	var index := floori(float(record.get("action_elapsed", 0.0)) * maxf(0.01, float(sequence.get("fps", 1.0))))
	if bool(sequence.get("loop", false)): return posmod(index, frames.size())
	return mini(index, frames.size() - 1)

func _sequence(action: String, direction: String) -> Dictionary:
	return _library.get_sequence(_actor, action, direction) if _library != null else {}

func _within_budget() -> bool:
	return _simulated_seconds <= MAX_SIMULATION_SECONDS

func _expected_movie_fps(args: PackedStringArray) -> float:
	var explicit := _arg(args, "--expected-movie-fps=")
	if not explicit.is_empty(): return explicit.to_float()
	var command := OS.get_cmdline_args()
	for index in range(command.size() - 1):
		if command[index] == "--fixed-fps": return command[index + 1].to_float()
	return 0.0

func _read_movie_fps() -> float:
	return maxf(1.0, roundf(Engine.time_scale / maxf(get_process_delta_time(), 0.000001))) if OS.has_feature("movie") else 0.0

func _press(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	if pressed and not _held_keys.has(key): _held_keys.append(key)
	elif not pressed: _held_keys.erase(key)
	event.keycode = key; event.physical_keycode = key; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func _physics_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().physics_frame

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _arg(args: PackedStringArray, prefix: String) -> String:
	for arg in args:
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func _fail(message: String) -> void:
	_failures.append(message)
	push_error("Animation acceptance: " + message)

func _release_main() -> void:
	if is_instance_valid(_main):
		if is_instance_valid(_world): _world.npc_activity.set_activity_paused(true)
		if is_instance_valid(_main.audio):
			_main.audio.shutdown()
			await get_tree().create_timer(0.15).timeout
		_main.queue_free()
		await _frames(3)
		await RenderingServer.frame_post_draw
	_main = null
	_world = null

func _finish(success: bool, reason := "") -> void:
	if not reason.is_empty(): _fail(reason)
	_report["failures"] = _failures.duplicate()
	_report["technical_status"] = "PASS" if success and _failures.is_empty() else "FAIL"
	_report["status"] = "FAIL" if not _failures.is_empty() else ("CONTENT_PENDING" if not _report.get("pending", []).is_empty() else "OBSERVATIONS_COMPLETE_VISUAL_PENDING")
	_report["complete_acceptance"] = false
	_report["human_visual_review"] = "pending"
	_report["simulation_seconds_including_capture_and_startup"] = _simulated_seconds
	var process_frames_in_run := Engine.get_process_frames() - _start_process_frame
	_report["process_frames_in_run"] = process_frames_in_run
	_report["movie_writer_frame_count"] = null
	_report["movie_duration_estimate_seconds"] = float(process_frames_in_run) / _movie_fps if _movie_fps > 0.0 else 0.0
	_report["movie_duration_source"] = "estimate before final cleanup from Godot process frames / reported fixed FPS; verify encoded file metadata and playback"
	var report_path := _output.path_join(_actor + "-report.json") if _output_validated else ""
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_report, "\t")); file.close()
	for key in _held_keys.duplicate(): _press(key, false)
	if is_instance_valid(_main): await _release_main()
	_library = null
	_observation.clear()
	_buffered_captures.clear()
	_alpha_rect_cache.clear()
	if RenderingServer.frame_post_draw.is_connected(_on_frame_drawn): RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if success and _failures.is_empty() else 1)
