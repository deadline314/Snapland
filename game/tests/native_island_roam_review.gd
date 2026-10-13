extends Node
## GPU-backed, input-driven navigation audit of the first island.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const SCREENSHOT_DIR := "res://pm/Snapland-main/images"
const MAX_STEP_SECONDS := 32.0
const MAX_REVIEW_SECONDS := 180.0
# Movie Maker renders offline; output duration is not wall-clock duration.
# Keep a bounded recording allowance without changing movement/stuck checks.
const MAX_MOVIE_REVIEW_SECONDS := 240.0
const STUCK_SECONDS := 1.2

var _main: Node
var _world: Node
var _progress: Node
var _report: Dictionary = {
	"status": "running",
	"scripted_input": "real Input.parse_input_event keyboard events",
	"human_played": false,
	"fixture_note": "scripted movement audit only; not a human play session",
	"teleport_or_recovery_used_by_fixture": false,
	"waypoints": [],
	"area_transitions": [],
	"wall_collision_contacts": {},
	"wall_collision_frames": 0,
	"screenshots": [],
	"ride": {"optional": true, "attempted": false},
}
var _failure_reason := ""
var _started_ms := 0
var _proof_tag := ""

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native island roam review requires a GPU-backed display and an isolated SNAPLAND_SAVE_PATH.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_proof_tag=OS.get_environment("SNAPLAND_NATIVE_PROOF_TAG").strip_edges()
	if not _proof_tag.is_empty() and (not _proof_tag.is_valid_identifier() or _proof_tag.length()>40):
		push_error("Native roam proof tag must be a short identifier")
		get_tree().quit(1)
		return
	_started_ms = Time.get_ticks_msec()
	get_window().size = Vector2i(1280, 720)
	_report["display_server"] = DisplayServer.get_name()
	_report["offline_movie_recording"] = OS.has_feature("movie")
	_report["wall_clock_budget_seconds"] = MAX_MOVIE_REVIEW_SECONDS if OS.has_feature("movie") else MAX_REVIEW_SECONDS
	_report["requested_window_size"] = "1280x720"
	_progress = get_tree().root.get_node_or_null("Progress")
	if _progress == null:
		_finish(false, "Progress autoload is missing")
		return
	var main_scene: PackedScene = load(MAIN_SCENE_PATH)
	_main = main_scene.instantiate()
	_main.name = "NativeIslandRoamMain"
	get_tree().root.add_child(_main)
	await _frames(8)
	_world = _main.world
	_world.area_changed.connect(_on_area_changed)
	_report["initial_player"] = _position_record(_world.player.position)
	if _main.modal_kind != "dialogue" or not is_instance_valid(_main.dialogue_panel) or not _main.dialogue_panel.visible:
		_finish(false, "fresh isolated profile did not open the initial arrival dialogue; modal=%s" % _main.modal_kind)
		return
	_send_key(KEY_ESCAPE, true)
	await _frames(2)
	_send_key(KEY_ESCAPE, false)
	await _frames(3)
	_report["arrival_cancel"] = {"input": "Escape", "modal_after": _main.modal_kind, "intro_seen": bool(_progress.intro_seen)}
	if _main.modal_kind != "" or not _progress.intro_seen:
		_finish(false, "real Escape input did not cancel and persist the first arrival dialogue")
		return
	if not await _walk_and_mark("dock-exit", Vector2(0.0, 12.0), "MAIN-11-roam-dock-out.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("tide-ramp-approach", Vector2(-4.5, 11.2), "MAIN-11-roam-guide-ride.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("ride-tide-point", Vector2(-6.7, 11.2), ""):
		_finish(false, _failure_reason)
		return
	await _try_ride_with_real_interaction()
	if not await _walk_and_mark("west-fountain-approach", Vector2(-4.2, 6.2), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("south-fountain-bypass", Vector2(-4.2, -4.2), "MAIN-11-roam-fountain-west.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("east-fountain-approach", Vector2(4.2, -4.2), "MAIN-11-roam-fountain-east.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("avenue-threshold", Vector2(4.2, -10.4), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("wind-sail-west-district", Vector2(-6.0, -17.0), "MAIN-11-roam-west-district.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("west-avenue-crossing", Vector2(-4.2, -22.0), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("east-avenue-crossing", Vector2(4.2, -22.0), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("tidepool-east-district", Vector2(6.0, -27.0), "MAIN-11-roam-east-district.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("lookout-spine", Vector2(4.2, -34.0), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("lookout-ramp-toe", Vector2(6.7, -36.2), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("lookout-front-walkway", Vector2(9.55, -34.8), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("lookout-deck", Vector2(12.7, -34.8), "MAIN-11-roam-lookout.png"):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("lookout-front-walkway-return", Vector2(9.55, -34.8), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("lookout-ramp-descent", Vector2(6.7, -36.2), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("moonshadow-east-approach", Vector2(4.2, -38.5), ""):
		_finish(false, _failure_reason)
		return
	if not await _walk_and_mark("moonshadow-stage", Vector2(0.0, -38.5), "MAIN-11-roam-moonstage.png"):
		_finish(false, _failure_reason)
		return
	for point in [Vector2(4.2, -34.0), Vector2(4.2, -22.0), Vector2(3.0, -13.0), Vector2(3.0, -9.0), Vector2(4.2, -4.2), Vector2(4.2, 6.2), Vector2(0.0, 12.0)]:
		if not await _walk_and_mark("return-spine-%d" % _report.waypoints.size(), point, ""):
			_finish(false, _failure_reason)
			return
	if not await _walk_and_mark("dock-return", Vector2(0.0, 25.0), "MAIN-11-roam-dock-return.png"):
		_finish(false, _failure_reason)
		return
	_report["elapsed_seconds"] = float(Time.get_ticks_msec() - _started_ms) / 1000.0
	_finish(true, "")

func _walk_and_mark(label: String, target: Vector2, screenshot_name: String) -> bool:
	var start_position: Vector3 = _world.player.position
	var started := Time.get_ticks_msec()
	var deadline_ms := int(maxf(3.0, start_position.distance_to(Vector3(target.x, start_position.y, target.y)) / float(_world.AVATAR_RUN_SPEED) * 2.0 + 5.0) * 1000.0)
	deadline_ms = mini(deadline_ms, int(MAX_STEP_SECONDS * 1000.0))
	var previous_distance := _horizontal_distance(target)
	var last_progress_ms := Time.get_ticks_msec()
	var wall_contacts_before := int(_report.wall_collision_frames)
	var step_travel_distance := 0.0
	while Time.get_ticks_msec() - started < deadline_ms:
		var total_budget := MAX_MOVIE_REVIEW_SECONDS if OS.has_feature("movie") else MAX_REVIEW_SECONDS
		if float(Time.get_ticks_msec() - _started_ms) / 1000.0 > total_budget:
			_failure_reason = "review exceeded the %.0f-second total budget at %s; actual=%s" % [total_budget, label, str(_world.player.position)]
			return _record_failed_waypoint(label, target, start_position, started)
		var current: Vector3 = _world.player.position
		if Vector2(current.x, current.z).distance_to(target) <= 0.35:
			break
		var horizontal_frame_start := Vector2(current.x, current.z)
		if absf(target.x - current.x) > 0.1:
			_set_key(KEY_A if target.x < current.x else KEY_D, true)
		if absf(target.y - current.z) > 0.1:
			_set_key(KEY_W if target.y < current.z else KEY_S, true)
		await get_tree().physics_frame
		_set_all_movement_keys(false)
		var after: Vector3 = _world.player.position
		var displacement := Vector2(after.x - horizontal_frame_start.x, after.z - horizontal_frame_start.y).length()
		step_travel_distance += displacement
		if displacement > 0.5:
			_failure_reason = "%s had unexpected player displacement %.3fm; from=%s to=%s" % [label, displacement, str(horizontal_frame_start), str(Vector2(after.x, after.z))]
			return _record_failed_waypoint(label, target, start_position, started)
		if _world.player.is_on_wall():
			_report["wall_collision_frames"] = int(_report.wall_collision_frames) + 1
			_record_wall_contacts()
		var distance := _horizontal_distance(target)
		if distance < previous_distance - 0.015:
			previous_distance = distance
			last_progress_ms = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_progress_ms > int(STUCK_SECONDS * 1000.0):
			_failure_reason = "%s made no measurable progress for %.1fs; actual=%s remaining=%.3fm slide_collisions=%d" % [label, STUCK_SECONDS, str(_world.player.position), distance, _world.player.get_slide_collision_count()]
			return _record_failed_waypoint(label, target, start_position, started)
		if not _world.player.is_on_floor() and absf(_world.player.velocity.y) < 0.01:
			_failure_reason = "%s reached a non-grounded state; actual=%s" % [label, str(_world.player.position)]
			return _record_failed_waypoint(label, target, start_position, started)
	if _horizontal_distance(target) > 0.35:
		_failure_reason = "%s missed its waypoint deadline; actual=%s target=%s remaining=%.3fm" % [label, str(_world.player.position), str(target), _horizontal_distance(target)]
		return _record_failed_waypoint(label, target, start_position, started)
	var waypoint := {
		"name": label,
		"target_xz": [target.x, target.y],
		"from": _position_record(start_position),
		"actual": _position_record(_world.player.position),
		"elapsed_seconds": float(Time.get_ticks_msec() - started) / 1000.0,
		"walked_distance_m": snappedf(step_travel_distance, 0.01),
		"wall_collision_frames": int(_report.wall_collision_frames) - wall_contacts_before,
		"on_floor": _world.player.is_on_floor(),
		"area": _world.current_area,
	}
	_report.waypoints.append(waypoint)
	_report["walked_distance_m"] = float(_report.get("walked_distance_m", 0.0)) + step_travel_distance
	if not screenshot_name.is_empty() and not await _capture(screenshot_name):
		_failure_reason = "Could not save selected screenshot %s" % screenshot_name
		return false
	return true

func _record_failed_waypoint(label: String, target: Vector2, start_position: Vector3, started: int) -> bool:
	_set_all_movement_keys(false)
	_report["failed_waypoint"] = {
		"name": label,
		"target_xz": [target.x, target.y],
		"from": _position_record(start_position),
		"actual": _position_record(_world.player.position),
		"elapsed_seconds": float(Time.get_ticks_msec() - started) / 1000.0,
		"remaining_m": _horizontal_distance(target),
		"wall": _world.player.is_on_wall(),
		"slide_collisions": _world.player.get_slide_collision_count(),
	}
	return false

func _try_ride_with_real_interaction() -> void:
	var before: Vector3 = _world.player.position
	var nearest_id := str(_world.nearest.get("id", ""))
	var ride_report: Dictionary = {"optional": true, "attempted": nearest_id == "ride-tide", "nearest_before": nearest_id, "before": _position_record(before)}
	_report["ride"] = ride_report
	if nearest_id != "ride-tide":
		return
	_send_key(KEY_E, true)
	await _frames(2)
	_send_key(KEY_E, false)
	ride_report["entered_by_e"] = _world.is_riding()
	if not _world.is_riding():
		return
	await _frames(24)
	_send_key(KEY_E, true)
	await _frames(2)
	_send_key(KEY_E, false)
	await _frames(2)
	ride_report["exited_by_e"] = not _world.is_riding()
	ride_report["after"] = _position_record(_world.player.position)
	ride_report["exit_displacement_m"] = Vector2(_world.player.position.x - before.x, _world.player.position.z - before.z).length()

func _capture(file_name: String) -> bool:
	if not _proof_tag.is_empty(): file_name=file_name.replace("MAIN-11-roam-","MAIN-11-"+_proof_tag+"-roam-")
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var directory := ProjectSettings.globalize_path(SCREENSHOT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return false
	var path := directory.path_join(file_name)
	if image.save_png(path) != OK:
		return false
	_report.screenshots.append(path)
	return true

func _on_area_changed(area: String) -> void:
	_report.area_transitions.append({"area": area, "player": _position_record(_world.player.position), "elapsed_seconds": float(Time.get_ticks_msec() - _started_ms) / 1000.0})

func _record_wall_contacts() -> void:
	for collision_index in range(_world.player.get_slide_collision_count()):
		var collision: KinematicCollision3D = _world.player.get_slide_collision(collision_index)
		if collision == null or not collision.get_collider() is Node:
			continue
		var collider := collision.get_collider() as Node
		var contact_name := collider.name
		var contacts: Dictionary = _report.wall_collision_contacts
		contacts[contact_name] = int(contacts.get(contact_name, 0)) + 1

func _horizontal_distance(target: Vector2) -> float:
	return Vector2(_world.player.position.x, _world.player.position.z).distance_to(target)

func _position_record(position: Vector3) -> Dictionary:
	return {"x": snappedf(position.x, 0.01), "y": snappedf(position.y, 0.01), "z": snappedf(position.z, 0.01)}

func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _send_key(key: Key, pressed: bool) -> void:
	_set_key(key, pressed)

func _set_all_movement_keys(pressed: bool) -> void:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_set_key(key, pressed)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().physics_frame

func _write_report() -> void:
	_report["elapsed_seconds"] = float(Time.get_ticks_msec() - _started_ms) / 1000.0 if _started_ms > 0 else 0.0
	_report["player_final"] = _position_record(_world.player.position) if is_instance_valid(_world) and is_instance_valid(_world.player) else {}
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save_path.is_empty():
		var report_path := save_path.get_base_dir().path_join("island-roam-report.json")
		var directory_error := DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		if directory_error == OK or directory_error == ERR_ALREADY_EXISTS:
			var report_file := FileAccess.open(report_path, FileAccess.WRITE)
			if report_file != null:
				report_file.store_string(JSON.stringify(_report, "\t"))
				report_file.close()
	print("ISLAND_ROAM_REPORT_BEGIN")
	print(JSON.stringify(_report, "\t"))
	print("ISLAND_ROAM_REPORT_END")

func _finish(success: bool, reason: String) -> void:
	_set_all_movement_keys(false)
	_report["status"] = "PASS" if success else "FAIL"
	_report["failure_reason"] = reason
	_write_report()
	if success:
		print("PASS: scripted native island roam review")
		get_tree().quit(0)
	else:
		push_error("Native island roam review failed: " + reason)
		get_tree().quit(1)
