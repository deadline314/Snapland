extends "res://game/tests/native_review.gd"

var active: Control
var observed_result: Dictionary = {}
var review_frames := 0
var review_seconds := 0.0
var peak_delta := 0.0

func _process(delta: float) -> void:
	review_frames += 1
	review_seconds += delta
	peak_delta = maxf(peak_delta, delta)
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	if not _native_preflight("Balloon harbor review"):
		return
	progress.reset_progress()
	progress.settings["reduced_motion"] = false
	await _start("game-001")
	assert(not active.minigame_hud._feedback.get_global_rect().intersects(active.minigame_hud._header.get_global_rect()))
	await _shot("balloon-intro")
	_key(KEY_ENTER)
	Input.flush_buffered_events()
	var before: Vector2 = active.p
	_held_key(KEY_RIGHT, true)
	await get_tree().create_timer(1.0).timeout
	_held_key(KEY_RIGHT, false)
	Input.flush_buffered_events()
	assert(active.p.x > before.x + 30.0)
	await _shot("balloon-flight")
	_held_key(KEY_SPACE, true)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.6).timeout
	assert(active.balloon_braking)
	await _shot("balloon-brake")
	_held_key(KEY_SPACE, false)
	active.set_time_of_day("night")
	await get_tree().create_timer(0.4).timeout
	await _shot("balloon-night")
	active.set_time_of_day("noon")
	var waypoints: Array[Vector2] = [Vector2(520,305),Vector2(780,270),Vector2(880,270),Vector2(960,360),Vector2(820,480),Vector2(1080,320)]
	var waypoint := 0
	var braking := false
	var flight_deadline := _wall_deadline(90.0)
	while not active.ended and Time.get_ticks_msec() < flight_deadline:
		if active.balloon_delivery_index >= 1 and waypoint == 0: waypoint = 1
		if waypoint >= 1 and waypoint <= 3 and active.p.distance_to(waypoints[waypoint]) < 30.0: waypoint += 1
		if active.balloon_delivery_index >= 2: waypoint = 5
		_motion(active.presentation.design_to_screen(waypoints[waypoint]))
		var distance_to_dock: float = active.p.distance_to(active.target)
		var brake_now: bool = waypoint not in [1,2,3] and distance_to_dock < 150.0
		if brake_now != braking:
			_held_key(KEY_SPACE, brake_now)
			braking = brake_now
		Input.flush_buffered_events()
		await get_tree().process_frame
	_held_key(KEY_SPACE, false)
	Input.flush_buffered_events()
	assert(active.ended and observed_result.get("success", false) and observed_result.get("devil", false) and active.mistakes == 0)
	assert(active.balloon_delivery_index == 3 and int(observed_result.get("score", -1)) == active.score)
	await _shot("balloon-delivered")
	await _remove()
	print("PASS: native balloon harbor; real movement/braking input, 3 deliveries, score %d" % int(observed_result.get("score", -1)))
	print("REVIEW TIMING: frames=%d simulated_seconds=%.3f peak_delta=%.3f" % [review_frames, review_seconds, peak_delta])
	get_tree().quit(0)

func _native_preflight(label: String) -> bool:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error(label + " requires a GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return false
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return false
	progress.intro_seen = true
	progress.settings["assist"] = false
	return true

func _start(id: String) -> void:
	observed_result.clear()
	active = GAME_SESSION.new()
	get_tree().root.add_child(active)
	active.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active.start(id, false)
	active.finished.connect(func(result: Dictionary): observed_result = result.duplicate(true))
	await get_tree().create_timer(0.35).timeout

func _remove() -> void:
	active.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	active = null

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(".review/diversity-" + label + ".png") == OK)
	print("CAPTURE: " + label)

func _wall_deadline(simulated_seconds: float) -> int:
	return Time.get_ticks_msec() + ceili(simulated_seconds / maxf(Engine.time_scale, 0.01) * 1000.0)
