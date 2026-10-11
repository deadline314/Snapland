extends "res://game/tests/native_review.gd"

var active: Control
var observed_result: Dictionary = {}

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	if not _native_preflight("Crowd traffic review"):
		return
	progress.reset_progress()
	progress.settings["reduced_motion"] = false
	await _start("game-004")
	await _shot("crowd-overhead")
	var first_queue_deadline := _wall_deadline(5.0)
	while active.crowd_model.elapsed < 0.75 and Time.get_ticks_msec() < first_queue_deadline:
		await get_tree().process_frame
	assert(active.crowd_model.phase == "red" and not active.crowd_model.queues[0].is_empty())
	await _shot("crowd-queued")
	# Demonstrate both real inputs immediately after the opening interval. The
	# initial E selection is replaced by Q while there is still room to act.
	_click(Vector2(760,235))
	Input.flush_buffered_events()
	await get_tree().create_timer(0.1).timeout
	assert(active.lane == 1)
	await _shot("crowd-vertical")
	_key(KEY_Q)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.2).timeout
	assert(active.lane == 0 and active.crowd_model.phase == "walk" and not active.crowd_model.active_group.is_empty())
	await _shot("crowd-horizontal")
	await _shot("crowd-crossing")
	var both_queues_deadline := _wall_deadline(8.0)
	while active.crowd_model.elapsed < 3.2 and Time.get_ticks_msec() < both_queues_deadline:
		await get_tree().process_frame
	assert(active.crowd_model.elapsed >= 3.2)
	assert(active.crowd_model.queues[0].size() == 1 and bool(active.crowd_model.queues[0][0].rescue))
	assert(active.crowd_model.queues[1].size() == 1 and int(active.crowd_model.queues[1][0].id) == 2)
	await _shot("crowd-two-queues")
	var crowd_deadline := _wall_deadline(30.0)
	var rescue_captured := false
	while not active.ended and Time.get_ticks_msec() < crowd_deadline:
		var chosen := _crowd_priority_lane(active.crowd_model)
		if chosen >= 0 and active.crowd_model.desired_lane != chosen:
			_key(KEY_Q if chosen == 0 else KEY_E)
			Input.flush_buffered_events()
		await get_tree().process_frame
		if not rescue_captured and active.crowd_model.phase == "walk" and bool(active.crowd_model.active_group.get("rescue", false)):
			await _shot("crowd-rescue")
			rescue_captured = true
	assert(active.ended and observed_result.get("success", false) and observed_result.get("devil", false))
	assert(rescue_captured, "real rescue team must reach the crossing during the review")
	assert(active.crowd_model.safe_count == 6 and active.score == active.crowd_model.score)
	assert(int(observed_result.get("score", -1)) == active.score)
	var final_score: int = int(active.score)
	await _shot("crowd-complete")
	await _remove()
	print("PASS: native crowd traffic; 6 safe groups, score %d" % final_score)
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
