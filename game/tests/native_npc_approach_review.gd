extends Node
## Scripted native Main interaction evidence; camera/player placement is not human play.

const MainScene := preload("res://game/main.tscn")
const Guard := preload("res://game/core/test_save_guard.gd")
const Timing := preload("res://game/world/character_animation_timing.gd")
const Release := preload("res://game/tests/audio_playback_release.gd")
const POINTS := {"ticket": "guide", "imp": "quest-001", "announcer": "quest-002"}

var _main: Node
var _world: Node
var _output := ""
var _output_valid := false
var _failures: Array[String] = []
var _report := {"technical_status": "RUNNING", "complete_acceptance": false, "human_played": false,
	"scripted_input": true, "npc_roots_repositioned": false, "roles": [], "captures": [],
	"placement_note": "Only player is positioned at NPC root + normalized back-left XZ * 1.6 + Y 0.1. Actual physics proximity and E open Main dialogue. After interaction the hero visual is hidden and world camera-follow physics is disabled for fixed close framing; NPC roots, routes, sequences and action clocks are never written."}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--animation-output="): _output = arg.trim_prefix("--animation-output=")
	if DisplayServer.get_name() == "headless" or not _valid_paths():
		_check(false, "GPU display, fresh isolated absolute save and new empty safe output directory are required")
		await _finish()
		return
	_output_valid = true
	var quarter := args.has("--quarter")
	var reduced := args.has("--reduced-motion")
	var rebuild := args.has("--rebuild")
	if quarter and reduced:
		_check(false, "--quarter and --reduced-motion conflict")
		await _finish()
		return
	Engine.time_scale = 0.25 if quarter else 1.0
	_report.merge({"time_scale": Engine.time_scale, "reduced_motion": reduced, "scene_rebuild": rebuild,
		"movie_writer_active": OS.has_feature("movie"), "display": DisplayServer.get_name()})
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	for pass_index in range(2 if rebuild else 1):
		_main = MainScene.instantiate()
		get_tree().root.add_child(_main)
		await _frames(4)
		_world = _main.world
		if not _check(is_instance_valid(_world) and _main.modal_kind == "", "Main reaches island play"):
			await _finish()
			return
		for role in POINTS:
			await _review_role(String(role), pass_index, reduced)
		if pass_index == 0 and rebuild:
			await _release_main()
			await _frames(2)
	await _finish()

func _review_role(role: String, pass_index: int, reduced: bool) -> void:
	_world.set_physics_process(true)
	_world.player.visible = true
	_world.apply_settings({"reduced_motion": false})
	var actor := _actor(role)
	var root := actor.get("activity_root") as Node3D
	var sprite := actor.get("sprite") as Sprite3D
	if not _check(is_instance_valid(root) and is_instance_valid(sprite), role + " live actor exists"): return
	_world.player.global_position = root.global_position + Vector3(-1,0,-1).normalized() * 1.6 + Vector3(0,0.1,0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	if not _check(String(_world.nearest.get("id", "")) == POINTS[role], role + " back-left physics proximity selects actual point"): return
	var roots := {}
	var points := {}
	for other in POINTS:
		roots[other] = (_actor(other).activity_root as Node3D).global_position
		points[other] = _world._point_by_id(POINTS[other]).position
	await _press_key(KEY_E)
	if not _check(_main.modal_kind == "dialogue" and _world.npc_dialogue_hold and _world.blocked, role + " E opens held Main dialogue"): return
	var record := _record(role)
	var action := "greet" if role == "ticket" else "interact"
	var sequence: Dictionary = record.action_sequence
	if not _check(record.action == action and record.direction == "front" and bool(sequence.get("available", false)) and not bool(sequence.get("loop", true)) and sequence.get("frames", []).size() >= 7 and not bool(sequence.get("legacy_fallback", false)), role + " actual event selects finite complete front source"): return
	_world.player.visible = false
	_world.set_physics_process(false)
	var camera: Camera3D = _world.camera
	camera.global_position = root.global_position + Vector3(0,2.0,4.2)
	camera.look_at(root.global_position + Vector3(0,0.45,0), Vector3.UP)
	camera.size = 6.0
	camera.current = true
	_world._update_sprite_grounding()
	var row := {"role": role, "pass": pass_index, "action": action, "direction": "front", "approach": "back_left",
		"root": _xyz(root.global_position), "camera": _xyz(camera.global_position), "camera_size": camera.size,
		"frames": [], "sequence_seconds": Timing.duration(sequence), "source_consistent": true, "held_positions": true}
	var start_ms := Time.get_ticks_msec()
	var simulated := 0.0
	var captured := false
	while simulated < Timing.duration(sequence) + 1.5:
		await RenderingServer.frame_post_draw
		record = _record(role)
		row.held_positions = bool(row.held_positions) and _held_positions(roots, points)
		if record.action != action: break
		var index := Timing.frame_at_time(sequence, float(record.action_elapsed))
		row.source_consistent = bool(row.source_consistent) and record.direction == "front" and _source_matches(role, sprite, record)
		if not row.frames.has(index): row.frames.append(index)
		if not captured and index >= 2 and index < sequence.frames.size() - 1:
			await _capture("%s-pass%d-%s" % [role, pass_index, action], sprite, row)
			captured = true
		await get_tree().process_frame
		simulated += get_process_delta_time()
	_check(captured and row.frames.size() >= 3 and bool(row.source_consistent), role + " presents multiple exact authored action cels including intermediate capture")
	record = _record(role)
	_check(record.action in ["stand", "idle"] and record.direction == "front" and bool(record.action_sequence.get("loop", false)) and _source_matches(role, sprite, record), role + " finite action returns to complete authored idle")
	_world.apply_settings({"reduced_motion": reduced})
	record = _record(role)
	var idle_start := float(record.action_elapsed)
	var idle_texture := sprite.texture
	await get_tree().create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	record = _record(role)
	_check(_main.modal_kind == "dialogue" and _main.dialogue_panel.visible and _world.npc_dialogue_hold and record.action in ["stand", "idle"] and record.direction == "front" and _source_matches(role, sprite, record), role + " dialogue stays open through steady authored idle")
	_check(is_equal_approx(float(record.action_elapsed), idle_start) and sprite.texture == idle_texture if reduced else float(record.action_elapsed) > idle_start + 0.4, role + " reduced idle freezes" if reduced else role + " held idle timeline advances")
	row.held_positions = bool(row.held_positions) and _held_positions(roots, points)
	_check(bool(row.held_positions), role + " all NPC roots and interaction points stay fixed during hold")
	await _capture("%s-pass%d-idle%s" % [role, pass_index, "-reduced" if reduced else ""], sprite, row)
	row["wall_ms"] = Time.get_ticks_msec() - start_ms
	row["idle_elapsed"] = record.action_elapsed
	row["reduced_motion"] = reduced
	row["idle_source"] = "frozen complete authored front standing sequence" if reduced else "looping authored front standing sequence"
	_report.roles.append(row)
	await _press_key(KEY_ESCAPE)
	_world.apply_settings({"reduced_motion": false})
	await _frames(2)
	_check(_main.modal_kind == "" and not _world.blocked and not _world.npc_dialogue_hold and _world.npc_activity._player.is_playing(), role + " Escape cancels and releases route")

func _source_matches(role: String, sprite: Sprite3D, record: Dictionary) -> bool:
	var sequence: Dictionary = record.get("action_sequence", {})
	var frames: Array = sequence.get("frames", [])
	if frames.is_empty() or not sprite.is_visible_in_tree() or sprite.texture == null or bool(sequence.get("legacy_fallback", false)): return false
	var elapsed := float(record.action_elapsed)
	if record.action in ["stand", "idle"]: elapsed *= _world.npc_activity.breath_tempo(role)
	var expected := frames[Timing.frame_at_time(sequence, elapsed)].get("texture") as Texture2D
	if role == "announcer": expected = _world.npc_activity._costume_texture(role, expected)
	if expected == null or sprite.texture.get_size() != Vector2(_world.npc_activity.ACTION_CANVAS_SIZE): return false
	return sprite.texture == expected or sprite.texture.get_image().get_data() == expected.get_image().get_data()

func _held_positions(roots: Dictionary, points: Dictionary) -> bool:
	for role in POINTS:
		if (_actor(role).activity_root as Node3D).global_position.distance_to(roots[role]) > 0.001 or _world._point_by_id(POINTS[role]).position.distance_to(points[role]) > 0.001: return false
	return true

func _capture(label: String, sprite: Sprite3D, row: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var camera: Camera3D = _world.camera
	var alpha := sprite.texture.get_image().get_used_rect()
	var origin := sprite.texture.get_size() * 0.5 if sprite.centered else Vector2.ZERO
	var bounds := Rect2()
	var first := true
	for x in [alpha.position.x, alpha.end.x]:
		for y in [alpha.position.y, alpha.end.y]:
			var point := camera.unproject_position(sprite.global_position + camera.global_basis.x * (float(x) - origin.x + sprite.offset.x) * sprite.global_basis.x.length() * sprite.pixel_size + camera.global_basis.y * (origin.y - float(y) + sprite.offset.y) * sprite.global_basis.y.length() * sprite.pixel_size)
			bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
			first = false
	var panel: Rect2 = (_main.dialogue_panel.find_child("DialoguePlaque", true, false) as Control).get_global_rect()
	var safe := Rect2(12,116,1256, panel.position.y - 128)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, sprite.global_position, 1, [_world.player.get_rid()])
	var clear: bool = _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	_check(alpha.has_area() and safe.encloses(bounds) and not camera.is_position_behind(sprite.global_position) and clear, label + " full silhouette fits above dialogue with clear geometry ray")
	var path := _output.path_join(label + ".png")
	var image := get_viewport().get_texture().get_image()
	var saved := image != null and not image.is_empty() and not FileAccess.file_exists(path) and image.save_png(path) == OK
	_check(saved, label + " PNG saved")
	_report.captures.append({"path": path, "saved": saved, "alpha_bounds": [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y], "occlusion_ray_clear": clear, "action": _record(row.role).action, "elapsed": _record(row.role).action_elapsed, "process_frame": Engine.get_process_frames()})

func _valid_paths() -> bool:
	var save := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if not Guard.validate_save_path(save, OS.get_user_data_dir()).is_empty() or FileAccess.file_exists(save): return false
	if _output.is_empty() or _output.contains("://") or not _output.is_absolute_path(): return false
	var normalized := Guard._normalized_path(_output)
	var project := Guard._normalized_path(ProjectSettings.globalize_path("res://"))
	var profile := Guard._normalized_path(save.get_base_dir())
	if profile.length() < 4 or DirAccess.dir_exists_absolute(save) or Guard._path_is_inside(Guard._normalized_path(save), project): return false
	if normalized.length() < 4 or normalized.get_base_dir() == normalized or Guard._path_is_inside(normalized, project) or Guard._path_is_inside(project, normalized) or Guard._path_is_inside(normalized, Guard._normalized_path(OS.get_user_data_dir())) or Guard._path_is_inside(profile, normalized): return false
	if DirAccess.dir_exists_absolute(_output):
		var directory := DirAccess.open(_output)
		if directory == null or not directory.get_files().is_empty() or not directory.get_directories().is_empty(): return false
	return DirAccess.make_dir_recursive_absolute(_output) == OK

func _actor(role: String) -> Dictionary:
	for record in _world.character_sprites:
		if record.role == role: return record
	return {}

func _record(role: String) -> Dictionary:
	for record in _world.npc_activity._records:
		if record.role == role: return record
	return {}

func _xyz(position: Vector3) -> Array:
	return [position.x,position.y,position.z]

func _press_key(key: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().physics_frame

func _frames(count: int) -> void:
	for index in count: await get_tree().process_frame

func _check(condition: bool, message: String) -> bool:
	if condition: print("PASS: " + message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)
	return condition

func _release_main() -> void:
	if not is_instance_valid(_main): return
	_main.quitting = true
	var playbacks := Release.capture(_main.audio)
	_main.audio.shutdown()
	_main.queue_free()
	await _frames(2)
	_check(await Release.wait_for_release(get_tree(), playbacks), "audio backend releases stopped playbacks before exit")
	_main = null
	_world = null

func _finish() -> void:
	await _release_main()
	_report["technical_status"] = "PASS" if _failures.is_empty() else "FAIL"
	_report["failures"] = _failures.duplicate()
	if _output_valid:
		var file := FileAccess.open(_output.path_join("npc-approach-report.json"), FileAccess.WRITE)
		if file == null: _check(false, "receipt could not be opened")
		else:
			file.store_string(JSON.stringify(_report,"\t"))
			file.flush()
			_check(file.get_error() == OK, "receipt written after cleanup")
			file.close()
	Engine.time_scale = 1.0
	if _failures.is_empty(): print("PASS: native NPC approach actions and idle recovery")
	else: push_error("Native approach failures: " + "; ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
