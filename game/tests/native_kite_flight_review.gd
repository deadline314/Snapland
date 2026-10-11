extends Node

const SessionScript = preload("res://game/minigames/session.gd")
const REVIEW_DIR := "res://.review/kite-flight"

var session: Control
var failures := 0
var _last_mouse_position := Vector2.ZERO
var _mouse_probe_logged := false
var _kite_gui_motions := 0
var _kite_gui_position := Vector2.ZERO

func _ready() -> void:
	call_deferred("_run")

func _process(_delta: float) -> void:
	if _movie_mode():
		RenderingServer.force_draw()

func _movie_mode() -> bool:
	return OS.has_feature("movie") or OS.get_cmdline_args().has("--write-movie")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native kite review requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	var absolute_dir := ProjectSettings.globalize_path(REVIEW_DIR)
	var quarter_speed := Engine.time_scale <= 0.26
	print("NATIVE KITE REVIEW SPEED: ", "quarter" if quarter_speed else "normal", " (engine time_scale=", Engine.time_scale, ")")
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		await _fail("Could not create isolated kite screenshot folder")
		return
	for route in ["keyboard", "mouse"]:
		if not await _run_route(route):
			return
	print("PASS: native kite flight keyboard and mouse routes completed all five model rings")
	get_tree().quit(0)

func _run_route(route: String) -> bool:
	var assisted := route == "keyboard"
	session = SessionScript.new()
	session.name = "KiteFlightReviewSession"
	session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(session)
	session.start("game-002", assisted)
	if route == "keyboard":
		session.set_practice_mode(true)
	session._sync_presentation()
	if not is_instance_valid(session.presentation):
		await _fail("Kite review has no initialized flight input surface")
		return false
	_kite_gui_motions = 0
	session.presentation.gui_input.connect(_observe_kite_gui_input)
	await get_tree().process_frame
	await _capture("%s-starting.png" % route)
	var slowdown_factor := maxi(1, int(ceil(1.0 / maxf(Engine.time_scale, 0.01))))
	var wall_deadline := Time.get_ticks_msec() + 180000 * slowdown_factor
	var captured_flight := false
	var captured_gust := false
	var captured_center := false
	var captured_strain := false
	var last_center_count := 0
	var held_key := 0
	var boost_held := false
	var boost_used := false
	var boost_observed := false
	var boost_start_elapsed := 0.0
	var reel_held := false
	var reel_used := false
	var reel_observed := false
	var reel_start_elapsed := 0.0
	var frame_index := 0
	_last_mouse_position = get_viewport().get_final_transform() * get_viewport().get_mouse_position()
	while not session.ended and Time.get_ticks_msec() < wall_deadline:
		var state: Dictionary = session.kite_model.snapshot()
		boost_observed = boost_observed or bool(state.get("boost", false))
		reel_observed = reel_observed or bool(state.get("reel", false))
		var ring_index := int(state.get("nextRing", 0))
		var desired_aim := 0.0
		if ring_index < 5:
			var ring_height := float(session.kite_model.RING_HEIGHT[ring_index])
			desired_aim = clampf((float(state.height) - ring_height) * 0.024 - float(state.vy) * 0.014, -1.0, 1.0)
		if route == "mouse":
			var pointer_target := Vector2(640.0, 390.0 - desired_aim * 235.0)
			var aim_before := float(session.kite_model.snapshot().get("aim", 0.0))
			_send_mouse_motion(pointer_target)
			Input.flush_buffered_events()
			var observed_aim := float(session.kite_model.snapshot().get("aim", 0.0))
			if not _mouse_probe_logged:
				_mouse_probe_logged = true
				var viewport := get_viewport()
				var hovered := viewport.gui_get_hovered_control()
				print("MOUSE INPUT PROBE: design=", pointer_target, " window=", _last_mouse_position, " viewport=", viewport.get_mouse_position(), " final_transform=", viewport.get_final_transform(), " hovered=", str(hovered.get_path()) if is_instance_valid(hovered) else "none", " gui_motions=", _kite_gui_motions, " gui_local=", _kite_gui_position, " aim_before=", aim_before, " aim_after=", observed_aim, " expected=", desired_aim)
				if _kite_gui_motions == 0 or not is_equal_approx(observed_aim, desired_aim):
					await _fail("mouse motion was not applied to kite aim; inspect viewport coordinate mapping and input dispatch")
					return false
		else:
			var next_key := KEY_UP if desired_aim > 0.25 else (KEY_DOWN if desired_aim < -0.25 else 0)
			if next_key != held_key:
				if held_key != 0: _send_key(held_key, false)
				if next_key != 0: _send_key(next_key, true)
				held_key = next_key
		var distance_to_ring := INF
		if ring_index < 5:
			distance_to_ring = float(state.ring_x) - float(state.x)
		if not boost_used and not boost_held and ring_index < 5 and distance_to_ring > 230.0 and float(state.tension) < 0.62:
			_send_boost(route, true)
			boost_held = true
			boost_start_elapsed = float(state.elapsed)
		elif boost_held and float(state.elapsed) - boost_start_elapsed >= 0.18:
			_send_boost(route, false)
			boost_held = false
			boost_used = true
		if not reel_used and not reel_held and int(state.center_hits) >= 1 and float(state.tension) > 0.26:
			_send_reel(route, true)
			reel_held = true
			reel_start_elapsed = float(state.elapsed)
		elif reel_held and float(state.elapsed) - reel_start_elapsed >= 0.20:
			_send_reel(route, false)
			reel_held = false
			reel_used = true
		if not captured_flight and frame_index >= 40:
			captured_flight = await _capture("%s-flight.png" % route)
		if not captured_gust and absf(float(state.get("actualwind", 0.0))) >= 30.0:
			captured_gust = await _capture("%s-gust.png" % route)
		if int(state.get("center_hits", 0)) > last_center_count:
			last_center_count = int(state.get("center_hits", 0))
			if not captured_center: captured_center = await _capture("%s-center.png" % route)
		if bool(state.get("tension_warning", false)) and not captured_strain:
			captured_strain = await _capture("%s-strain.png" % route)
			if not reel_held:
				_send_reel(route, true)
				reel_held = true
		elif captured_strain and session.kite_model.tension < 0.58 and reel_held:
			_send_reel(route, false)
			reel_held = false
		await get_tree().physics_frame
		frame_index += 1
	if held_key != 0: _send_key(held_key, false)
	if boost_held: _send_boost(route, false)
	if reel_held: _send_reel(route, false)
	if not session.ended or not session.won:
		await _fail("%s input route did not pass all five rings before its guard: %s" % [route, str(session.kite_model.snapshot())])
		return false
	if not await _verify_completed_route(route, assisted, boost_used, reel_used, boost_observed, reel_observed):
		return false
	if not captured_flight and not await _capture("%s-flight.png" % route): return false
	if not captured_gust and not await _capture("%s-gust.png" % route): return false
	if not captured_center and not await _capture("%s-center.png" % route): return false
	if not captured_strain: print("REVIEW: no natural strain warning on route %s; strain screenshot is optional" % route)
	if not await _hold_completed_stage(route): return false
	if not await _capture("%s-completed.png" % route): return false
	if not await _verify_visible_completed_hud(route): return false
	# Keep the terminal mouse result alive until _run quits immediately. Removing
	# it and yielding here would record a fixture-created empty/gray trailing frame.
	if route == "keyboard":
		session.queue_free()
		session = null
		await get_tree().process_frame
	return true

func _hold_completed_stage(route: String) -> bool:
	# Let pending Session redraws and deferred Control layout reach natural frames.
	await get_tree().process_frame
	await get_tree().process_frame
	if not await _verify_visible_completed_hud(route): return false
	var hold_started := Time.get_ticks_msec()
	var held_frames := 0
	while held_frames < 40 or Time.get_ticks_msec() - hold_started < 650:
		await get_tree().process_frame
		if not is_instance_valid(session) or not session.ended or not session.won:
			await _fail(route + " completed stage disappeared during its real-time movie hold")
			return false
		held_frames += 1
	if not await _verify_visible_completed_hud(route): return false
	print("FINAL STAGE HOLD: %s natural_frames=%d wall_ms=%d" % [route,held_frames,Time.get_ticks_msec()-hold_started])
	return true

func _verify_visible_completed_hud(route: String) -> bool:
	if not is_instance_valid(session) or not session.ended or not session.won or not is_instance_valid(session.minigame_hud):
		await _fail(route + " has no live completed Session/HUD to capture")
		return false
	var state: Dictionary = session.kite_model.snapshot()
	var hud: Control = session.minigame_hud
	var expected_score := int(state.center_hits) * 100 + int(state.edge_hits) * 60
	var expected_progress := "風環 %d / 5　中心 %d　救援 %d" % [int(state.nextRing),int(state.center_hits),int(state.rescues_used)]
	if int(state.nextRing) != 5 or int(state.center_hits) != 5 or expected_score != 500 or session.score != expected_score:
		await _fail("%s final capture did not genuinely reach five centers/500 points: %s" % [route,str(state)])
		return false
	if hud._score.text != "%04d" % expected_score or hud._progress.text != expected_progress or not hud._score.is_visible_in_tree() or not hud._progress.is_visible_in_tree():
		await _fail("%s final HUD differs from model: score=%s progress=%s expected=%04d/%s" % [route,hud._score.text,hud._progress.text,expected_score,expected_progress])
		return false
	if not hud._result_layer.visible or hud._result_title.text != "挑戰完成" or not hud._result_status.text.ends_with("　%d" % expected_score):
		await _fail("%s final result panel does not visibly show the real successful score: %s" % [route,hud._result_status.text])
		return false
	print("FINAL HUD: %s score=%s progress=%s result=%s" % [route,hud._score.text,hud._progress.text,hud._result_status.text.replace("\n"," / ")])
	return true

func _verify_completed_route(route: String, route_assisted: bool, boost_used: bool, reel_used: bool, boost_observed: bool, reel_observed: bool) -> bool:
	var state: Dictionary = session.kite_model.snapshot()
	var score_summary: Dictionary = session.score_summary()
	var centers := int(state.get("center_hits", 0))
	var edges := int(state.get("edge_hits", 0))
	var rescues := int(state.get("rescues_used", 0))
	var expected_devil := centers == 5 and edges == 0 and rescues == 0 and not route_assisted
	var expected_score := centers * 100 + edges * 60
	var checks := [
		[int(state.get("nextRing", -1)) == 5, "nextRing == 5"],
		[centers + edges == 5, "center + edge == 5"],
		[session.score == expected_score, "Session.score matches center/edge score formula"],
		[int(score_summary.get("total", -1)) == expected_score, "score_summary.total matches model score"],
		[session.mistakes == int(state.get("mistakes", -1)), "Session mistakes match model"],
		[bool(state.get("devil", false)) == expected_devil and session.devil_won == expected_devil, "devil flags match center/no-edge/no-rescue/unassisted rule"],
		[boost_used and boost_observed, "boost was used and observed active in snapshot"],
		[reel_used and reel_observed, "reel was used and observed active in snapshot"]
	]
	for check in checks:
		if not bool(check[0]):
			await _fail("%s completion assertion failed (%s): state=%s score=%d summary=%s boost_used=%s boost_seen=%s reel_used=%s reel_seen=%s" % [route, str(check[1]), str(state), session.score, str(score_summary), str(boost_used), str(boost_observed), str(reel_used), str(reel_observed)])
			return false
	print("ROUTE RESULT: %s rings=%d centers=%d edges=%d rescues=%d mistakes=%d score=%d devil=%s boost_used=%s boost_seen=%s reel_used=%s reel_seen=%s" % [route, int(state.get("nextRing", 0)), centers, edges, rescues, session.mistakes, session.score, str(session.devil_won), str(boost_used), str(boost_observed), str(reel_used), str(reel_observed)])
	return true

func _send_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _send_mouse_motion(position: Vector2) -> void:
	# parse_input_event takes OS/window coordinates; the kite driver targets its
	# design plane, which can be scaled/letterboxed independently of the window.
	var viewport_point: Vector2 = session.presentation.get_global_transform_with_canvas() * position
	var window_point := get_viewport().get_final_transform() * viewport_point
	var event := InputEventMouseMotion.new()
	event.position = window_point
	event.global_position = window_point
	event.relative = window_point - _last_mouse_position
	event.velocity = event.relative * float(Engine.get_physics_ticks_per_second())
	event.button_mask = Input.get_mouse_button_mask()
	event.window_id = get_window().get_window_id()
	Input.parse_input_event(event)
	_last_mouse_position = window_point

func _send_boost(route: String, pressed: bool) -> void:
	if route == "keyboard":
		_send_key(KEY_SPACE, pressed)
	else:
		_send_mouse_button(MOUSE_BUTTON_LEFT, pressed)

func _send_reel(route: String, pressed: bool) -> void:
	if route == "keyboard":
		_send_key(KEY_SHIFT, pressed)
	else:
		_send_mouse_button(MOUSE_BUTTON_RIGHT, pressed)

func _send_mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	event.pressed = pressed
	event.position = _last_mouse_position
	event.global_position = event.position
	event.window_id = get_window().get_window_id()
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _capture(file_name: String) -> bool:
	# A force_draw from the fixture's early _process can precede Session's
	# redraw/layout. Wait through natural process frames before reading a render.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		await _fail("GPU capture returned no frame: " + file_name)
		return false
	var path := ProjectSettings.globalize_path(REVIEW_DIR.path_join(file_name))
	var result := image.save_png(path)
	if result != OK:
		await _fail("Could not save GPU frame: " + path)
		return false
	print("CAPTURE: ", path)
	return true

func _fail(message: String) -> void:
	failures += 1
	push_error("Native kite review: " + message)
	get_tree().quit(1)

func _observe_kite_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_kite_gui_motions += 1
		_kite_gui_position = event.position
