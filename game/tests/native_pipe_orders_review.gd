extends "res://game/tests/native_review.gd"

var active: Control
var observed_result: Dictionary = {}

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	if not _native_preflight("Pipe orders review"):
		return
	progress.reset_progress()
	progress.settings["reduced_motion"] = false
	await _start("game-007")
	await _shot("pipe-plan")
	var routes: Array = [[0,4,6,15], [0,1,2,3,4,8,12], [0,1,2,3,6,10,14,15]]
	for order in range(3):
		await _shot("pipe-order-%d" % (order + 1))
		for cell in routes[order]:
			_click(Vector2(400 + (cell % 4) * 160, 216 + int(cell / 4) * 100))
			Input.flush_buffered_events()
			await get_tree().create_timer(0.12).timeout
		assert(active.pipe_connected and observed_result.is_empty())
		await _shot("pipe-flow-%d" % (order + 1))
		await get_tree().create_timer(1.1 if order < 2 else 1.4).timeout
		if order < 2:
			assert(observed_result.is_empty() and active.pipe_model.order_index == order + 1)
	assert(observed_result.get("success", false) and observed_result.get("devil", false))
	assert(int(observed_result.get("score", -1)) == 2620 and active.pipe_model.total_turns == 19)
	await _shot("pipe-complete")
	await _remove()
	print("PASS: native pipe orders; 3 orders, 19 real rotations, score %d" % int(observed_result.get("score", -1)))
	get_tree().quit(0)

func _native_preflight(label: String) -> bool:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name() == "headless":
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

var _evidence_serial := 0
func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image != null and not image.is_empty())
	var folder := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("captures")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("%03d-diversity-%s.png" % [_evidence_serial,label])
	_evidence_serial += 1
	assert(not FileAccess.file_exists(path))
	assert(image.save_png(path)==OK)
	print("CAPTURE: "+label+" "+path)
