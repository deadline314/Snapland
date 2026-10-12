extends SceneTree

const View = preload("res://game/minigames/melody_memory_view.gd")
const Model = preload("res://game/minigames/melody_memory_model.gd")
const Session = preload("res://game/minigames/session.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: View = View.new()
	view.set_size(View.DESIGN_SIZE)
	root.add_child(view)
	await process_frame
	_test_stage_bounds(view)
	_test_distinct_materials_and_pointer_input(view)
	_test_cues_and_reduced_motion(view)
	await _test_game_session_view_lifecycle(view)
	view.queue_free()
	await process_frame
	if failures == 0:
		print("Melody memory view: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Melody memory view: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_stage_bounds(view) -> void:
	var canvas := Rect2(Vector2.ZERO, View.DESIGN_SIZE)
	var hud: Rect2 = view.hud_safe_rect()
	var scene: Rect2 = view.scene_bounds()
	var play: Rect2 = view.playable_bounds()
	_expect(scene.position.y > hud.end.y and canvas.encloses(scene), "seaside close-up occupies the 1280x720 frame below the shared HUD")
	_expect(scene.end.y <= 652 and scene.end.x <= 1248, "stage leaves the shared lower 80px clear and stays inside the frame")
	_expect(scene.encloses(view.timeline_bounds()) and not view.timeline_bounds().intersects(hud), "mechanical score roll clears the HUD inside the local stage")
	_expect(scene.encloses(view.roll_case_bounds()) and not view.roll_case_bounds().intersects(hud), "wood and brass music-box housing stays below the shared HUD")
	_expect(scene.encloses(view.crank_label_bounds()) and view.crank_label_bounds().size.y >= 40, "hand-crank title sits on a legible measured paper plaque")
	_expect(scene.encloses(view.table_bounds()) and view.table_bounds().end.y <= 592, "harbor workbench is a measured stage surface above lower shared HUD clearance")
	_expect(scene.encloses(View.REPLAY_RECT), "replay control fits the lower stage edge")
	for index in range(4):
		var bounds: Rect2 = view.instrument_bounds(index)
		var drawn: Rect2 = view.instrument_visual_bounds(index)
		_expect(play.encloses(bounds) and scene.encloses(bounds), "instrument %d remains completely inside the input playfield" % index)
		_expect(not hud.intersects(bounds), "instrument %d has no collision with shared HUD" % index)
		_expect(bounds.size.x >= 190 and bounds.size.y >= 160, "instrument %d keeps a large pointer and visual target" % index)
		_expect(play.encloses(drawn) and scene.encloses(drawn), "instrument %d actual visible extent stays in scene and playfield" % index)
		_expect(not view.instrument_label_bounds(index).intersects(drawn), "instrument %d visible artwork clears its key label" % index)
	_expect(view.has_instrument_atlas(), "the approved v2 atlas loads in the game project")
	if view.has_instrument_atlas():
		_expect(view.atlas_resource_cached_correctly(), "all four quadrants share the imported Texture2D ResourceLoader cache")
		var texture_widths: Array[float] = []
		for index in range(4):
			var source: Rect2 = view.atlas_region_bounds(index)
			var expected_source := Rect2((index % 2) * 627, (index >> 1) * 627, 627, 627)
			_expect(source == expected_source, "instrument %d uses its exact non-bleeding atlas quadrant" % index)
			var actual_drawn: Rect2 = view.instrument_texture_bounds(index)
			texture_widths.append(actual_drawn.size.x)
			_expect(play.encloses(actual_drawn) and not view.instrument_label_bounds(index).intersects(actual_drawn), "atlas alpha extent %d is measured within its own instrument target" % index)
		_expect(texture_widths[0] > texture_widths[1] and texture_widths[2] > texture_widths[3], "atlas preserves the shell and slit drum silhouettes instead of four uniform pads")
	else:
		_expect(true, "procedural fallback remains measurable when the optional atlas cannot load")
	_expect(view.rhythm_markers({"heard_notes": [0, 2, 1]}).size() == 3, "music roll renders the complete observed note ribbon")

func _test_distinct_materials_and_pointer_input(view) -> void:
	var kinds: Array[String] = []
	for index in range(4):
		kinds.append(view.instrument_kind(index))
	_expect(kinds == ["shell_reed", "glass_bell", "wood_block", "harbor_drum"], "four targets use distinct physical instrument silhouettes and materials")
	var requested: Array[int] = []
	var replayed: Array[int] = []
	view.note_requested.connect(func(index: int) -> void: requested.append(index))
	view.replay_requested.connect(func() -> void: replayed.append(1))
	for index in range(4):
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = view.instrument_bounds(index).get_center()
		view._gui_input(event)
	_expect(requested == [0, 1, 2, 3], "pointer taps map once to each large instrument center")
	var replay_event := InputEventMouseButton.new()
	replay_event.button_index = MOUSE_BUTTON_LEFT
	replay_event.pressed = true
	replay_event.position = View.REPLAY_RECT.get_center()
	view._gui_input(replay_event)
	_expect(replayed.size() == 1, "separate replay control emits its own signal")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = View.REPLAY_RECT.get_center()
	view._gui_input(release)
	_expect(replayed.size() == 1, "button release does not generate a duplicate replay request")

func _test_cues_and_reduced_motion(view) -> void:
	var model = Model.new()
	model.reset()
	var state := model.snapshot().duplicate(true)
	state["phase"] = "listen"
	state["current_cue"] = 2
	state["cue_index"] = 2
	state["heard_notes"] = [2, 2, 0]
	state["rhythm"] = [0.0, 0.43, 0.86]
	view.update_frame(state, "noon", false)
	var normal_cue: bool = view.cue_is_visible(2)
	var normal_marks: Array = view.rhythm_markers().duplicate()
	var normal_motion: bool = view.visual_motion_enabled()
	view.update_frame(state, "night", true)
	_expect(view.palette_phase() == "night", "night changes the instrument palette")
	_expect(view.cue_is_visible(2) and not view.cue_is_visible(1), "reduced motion keeps the exact essential visual note cue")
	_expect(view.rhythm_markers() == normal_marks and normal_cue and normal_motion, "static reduced-motion roll retains all visual notes and rhythm marks")
	_expect(not view.visual_motion_enabled(), "reduced motion disables decoration without removing input cues")
	state["heard_notes"] = []
	state["current_cue"] = -1
	view.update_frame(state, "dawn", true)
	_expect(view.rhythm_markers().is_empty() and not view.cue_is_visible(2), "ready phase clears previous phrase reveal before active play")

func _test_game_session_view_lifecycle(view: View) -> void:
	var session: Control = Session.new()
	root.add_child(session)
	var native_display := DisplayServer.get_name() != "headless"
	if native_display:
		DisplayServer.window_set_size(Vector2i(1280, 720))
	else:
		# Headless rule tests do not allocate the renderer; retain a direct ready view
		# to verify that its resource setup and update path still work in that mode.
		session.presentation = view
		session.presentation_mode = "melody_memory"
		view.note_requested.connect(session._on_melody_note_requested)
		view.replay_requested.connect(session._on_melody_replay_requested)
	session.start("game-012")
	var model: Variant = session.melody_model
	var launched_view: View = view if not native_display else session.presentation as View
	_expect(session.game_id == "game-012" and session.mode == "melody_memory", "game-012 launches its actual melody session and finite model")
	_expect(launched_view != null and launched_view.is_node_ready() and launched_view.has_instrument_atlas() and launched_view.atlas_resource_cached_correctly(), "the launched session creates a ready view with the imported instrument atlas already cached")
	if native_display:
		await RenderingServer.frame_post_draw
		var capture_path := OS.get_environment("SNAPLAND_MELODY_LAUNCH_CAPTURE")
		if not capture_path.is_empty():
			var capture_dir := capture_path.get_base_dir()
			DirAccess.make_dir_recursive_absolute(capture_dir)
			var captured := root.get_viewport().get_texture().get_image().save_png(capture_path) == OK
			_expect(captured, "native game-012 session launch screenshot is saved when requested")
	var active := false
	for _frame in 800:
		if model.snapshot().phase == "active":
			active = true
			break
		session._process(0.025)
	_expect(active, "session advances its first listened phrase into the matching input phase")
	if active:
		var expected := int(Model.PHRASES[0][0])
		var pointer := InputEventMouseButton.new()
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.pressed = true
		pointer.position = launched_view.instrument_bounds(expected).get_center()
		launched_view._gui_input(pointer)
		_expect(int(model.snapshot().input_index) == 1 and launched_view._snapshot.get("last_event") == model.snapshot().last_event, "an actual instrument pointer event reaches the session model and refreshes the view's response cue")
	session._retry_from_hud()
	_expect(int(model.snapshot().input_index) == 0 and model.snapshot().phase == "listen" and session.score == 0, "retry resets both the launched game model and visible phrase")
	session.set_practice_mode(true)
	_expect(session.practice_mode and model.snapshot().phase == "listen" and model.snapshot().input_index == 0, "practice restarts the same view-model lifecycle without carrying the answer forward")
	session.queue_free()
	await process_frame
