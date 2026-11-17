extends "res://game/tests/native_region_travel_review.gd"
## Synthetic profile setup; actual Main controls and input actions, never human play.
var walking_samples: Array[Dictionary] = []

func _ready() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	output_directory = OS.get_environment("SNAPLAND_CANDY_REVIEW_OUTPUT")
	var dimensions := OS.get_environment("SNAPLAND_CANDY_REVIEW_SIZE")
	var parts := dimensions.split("x")
	if not save_path.is_absolute_path() or not output_directory.is_absolute_path() or parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("Candy review requires isolated absolute paths and WIDTHxHEIGHT");get_tree().quit(1);return
	requested_size = Vector2i(int(parts[0]), int(parts[1]))
	if requested_size not in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)] or DisplayServer.get_name() == "headless":
		push_error("Candy review requires GPU and a supported viewport");get_tree().quit(1);return
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		push_error("Candy review output is not writable");get_tree().quit(1);return
	var restart := OS.get_environment("SNAPLAND_CANDY_REVIEW_MODE") == "restart"
	var scale_text := OS.get_environment("SNAPLAND_CANDY_REVIEW_TEXT_SCALE")
	if scale_text not in ["", "1", "1.0", "1.25"]:
		push_error("Candy review text scale must be 1 or 1.25");get_tree().quit(1);return
	if not restart:
		report["scripted_profile_setup"] = true
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		Progress.settings.ui_scale = 1.25 if scale_text == "1.25" else 1.0
		Progress.settings.reduced_motion = OS.get_environment("SNAPLAND_CANDY_REVIEW_REDUCED_MOTION") == "1"
		Progress.settings.fullscreen = false
		for index in range(1,6): Progress.photos["photo-welcome-game-%d" % index] = {"fixture":"scripted_profile_setup"}
		_check(Progress.save_progress(), "five-card synthetic fixture saves in isolated profile")
	else:
		_check(FileAccess.file_exists(save_path) and Progress.current_region == "candy", "separate process loads a real travel-written candy save")
	report.merge({"scope":"Third-region Main travel and material observation; no new game or earned cards", "mode":"restart_reader" if restart else "scripted_setup_and_input_route", "direct_player_position_assignment":false, "scripted_input":true, "save_path":save_path, "text_scale":Progress.settings.ui_scale, "reduced_motion":Progress.settings.reduced_motion}, true)
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_size = requested_size
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_window().size = requested_size
	await _frames(4)
	main = MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	_check(get_window().size == requested_size, "actual window uses requested dimensions")
	if not restart:
		main._interact("gate:candy", "糖果工廠")
		await _frames(3)
		_check(main.overlay.find_child("TravelCandyButton", true, false) == null, "five ordinary cards do not expose travel")
		await _capture("five-cards-locked")
		main._close()
		Progress.photos["photo-harbor-game-1"] = {"fixture":"scripted_profile_setup"}
		_check(Progress.normal_count() == 6, "sixth source is global, not a candy award")
		_check(Progress.save_progress(), "six-card synthetic fixture persists")
		baseline = _snapshot()
		main._interact("gate:candy", "糖果工廠")
		await _frames(3)
		await _capture("qualified-gate")
		if not _travel_button("TravelCandyButton"):
			await _finish();return
		await _frames(8)
	else:
		baseline = _snapshot()
	_check(main.world_region == "candy" and Progress.current_region == "candy", "Main saves and builds actual factory")
	if main.world_region != "candy":
		await _finish();return
	_check(main.boat_stage == null and main.audio._active_context == "plaza", "factory has no arrival stage and uses a valid existing audio context")
	_check(main.world.reduced_motion == Progress.settings.reduced_motion, "factory applies current reduced-motion setting")
	await _capture("restart-factory" if restart else "factory-arrival")
	await _walk_to(Vector3(0, 0.2, 0))
	await _walk_to(Vector3(-8, 0.2, 0))
	_check(main.world.nearest.get("id", "") == "candy:temperature", "input route reaches actual observation control")
	for state in range(3):
		await _interact_input()
		_check(int(main.world.map_snapshot().temperature) == (state + 1) % 3, "Main input cycles the real sample")
		await _capture("temperature-%d" % ((state + 1) % 3))
	main._show_map()
	await _frames(4)
	_check(main.overlay.find_child("CandyMapPanel", true, false) != null, "factory map uses actual local snapshot")
	await _capture("factory-map")
	main._close()
	main._show_album()
	await _frames(4)
	var selector := main.overlay.find_child("AlbumRegionSelector", true, false) as OptionButton
	_check(selector != null and selector.selected == 2, "album defaults to actual third region")
	await _capture("factory-empty-collection")
	if selector != null:
		selector.select(1);selector.item_selected.emit(1)
		await _frames(4)
		await _capture("saved-harbor-collection")
	main._close()
	main._show_tasks()
	await _frames(4)
	await _capture("factory-tasks")
	main._close()
	main._show_ticket()
	await _frames(4)
	await _capture("factory-game-guide")
	main._close()
	main._show_pause()
	_check(main.overlay.find_child("PauseBoatPrologueButton", true, false) == null, "factory does not offer absent welcome boat stage")
	await _capture("factory-pause")
	main._close()
	await _walk_to(Vector3(0, 0.2, 0))
	await _walk_to(Vector3(0, 0.2, 9))
	await _walk_to(Vector3(9, 0.2, 9))
	_check(main.world.nearest.get("id", "") == "candy:reset", "input route reaches actual reset point")
	await _interact_input()
	_check(main.world.player.position.distance_to(main.world.ENTRY) < 0.15 and main.world.player.velocity.length() < 0.01, "real reset returns safely without stale velocity")
	await _capture("factory-reset")
	await _walk_to(Vector3(0, 0.2, 10))
	await _interact_input()
	_check(main.world_region == "welcome", "actual return point permanently returns free")
	await _capture("free-return-welcome")
	# Exercise a real three-region round trip, ending with a durable factory save.
	main._interact("gate:harbor", "潮汐碼頭")
	if not _travel_button("TravelHarborButton"):
		await _finish();return
	await _frames(6)
	_check(main.world_region == "harbor", "existing harbor travel remains available")
	main.world.interaction_requested.emit("region:welcome", "返回迎賓大道")
	await _frames(6)
	main._interact("gate:candy", "糖果工廠")
	if not _travel_button("TravelCandyButton"):
		await _finish();return
	await _frames(6)
	_check(main.world_region == "candy" and Progress.current_region == "candy", "writer finishes with a real persisted factory reentry")
	_check(_snapshot() == baseline, "all travel, material changes, reset and menus preserve rewards")
	report["walking_samples"] = walking_samples
	await _finish()

func _travel_button(node_name: String) -> bool:
	var button := main.overlay.find_child(node_name, true, false) as Button
	_check(button != null, "actual travel button exists: " + node_name)
	if button == null: return false
	_check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "travel button fits viewport")
	button.pressed.emit()
	return true

func _walk_to(target: Vector3) -> void:
	for tick in range(600):
		var position: Vector3 = main.world.player.position
		var difference := Vector2(target.x - position.x, target.z - position.z)
		for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
		if difference.length() < 0.22:
			await _frames(4)
			return
		if absf(difference.x) > 0.12: Input.action_press("move_right" if difference.x > 0 else "move_left")
		if absf(difference.y) > 0.12: Input.action_press("move_down" if difference.y > 0 else "move_up")
		if tick % 12 == 0: walking_samples.append({"position":position,"target":target})
		await get_tree().physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	_check(false, "input route did not reach waypoint: " + str(target))

func _interact_input() -> void:
	var event := InputEventAction.new()
	event.action = "interact";event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventAction.new();event.action = "interact";event.pressed = false
	Input.parse_input_event(event)
	await _frames(5)

func _finish() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	if is_instance_valid(main):
		main.quitting = true
		main.audio.shutdown()
		main.world.area_changed.emit("海風碼頭")
		await get_tree().create_timer(0.25).timeout
		_check(main.audio._active_context.is_empty(), "stale events cannot restart audio during teardown")
		main.free()
		await _frames(5)
	report["rewards_after"] = _snapshot()
	report["failures"] = failures
	var file := FileAccess.open(output_directory.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"));file.close()
	else: _check(false, "review report opens")
	for failure in failures: push_error("Candy review: " + failure)
	if failures.is_empty(): print("PASS: native Main candy travel and saved restart review ", requested_size, "; scripted fixture, inspect images for visual acceptance")
	get_tree().quit(0 if failures.is_empty() else 1)
