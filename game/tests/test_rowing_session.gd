extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const View = preload("res://game/minigames/rowing_cargo_view.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Solver = preload("res://game/tests/rowing_input_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func key(session, code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	session._unhandled_input(event)

func pointer(view: Control, command: String, pressed: bool) -> void:
	var point := root.get_final_transform() * (view.get_global_transform_with_canvas() * View.button_rect(command).get_center())
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.window_id = root.get_window_id()
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(800, 600) if OS.get_environment("ROWING_LARGE_TEXT") == "1" else Vector2i(1280, 720)
	Paper.set_text_scale(1.25 if OS.get_environment("ROWING_LARGE_TEXT") == "1" else 1.0)
	var progress := root.get_node_or_null("Progress")
	if progress != null and OS.get_environment("ROWING_LARGE_TEXT") == "1":
		progress.settings["text_scale"] = 1.25
	var s = Session.new()
	root.add_child(s)
	s.set_process(false)
	var results: Array[Dictionary] = []
	var cancellations: Array[int] = []
	s.finished.connect(func(result: Dictionary): results.append(result))
	s.cancelled.connect(func(): cancellations.append(1))
	expect(Session.definitions().size() == 12, "default welcome catalog stays twelve")
	s.start("game-013")
	expect(s.game_id == "game-013" and s.mode == "rowing_cargo" and not s.ended, "start accepts delivered global ID")
	if s.game_id != "game-013":
		s.free()
		quit(1)
		return
	expect(Session.definitions("harbor").size() == 1 and s._definition().name == "浪間小艇", "regional catalog and definition resolve delivered row")
	var driver = s.active_driver
	expect(driver != null and s.presentation == null if DisplayServer.get_name() == "headless" else s.presentation != null, "headless skips optional renderer; native owns view")
	await process_frame
	if s.presentation != null:
		pointer(s.presentation, "right", true)
		expect(driver.snapshot().rudder == 1, "native GUI pointer reaches digital driver")
		pointer(s.presentation, "right", false)
	s._process(0.1)
	expect(is_equal_approx(s.elapsed, 0.1) and s.elapsed == driver.snapshot().elapsed, "only model clock advances")
	s.elapsed = 999.0
	s._process(0.1)
	expect(not s.ended and is_equal_approx(s.elapsed, 0.2), "legacy timer cannot race model result")
	key(s, KEY_D)
	expect(driver.snapshot().rudder == 1, "Session forwards digital input")
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	key(s, KEY_W)
	s._process(200.0)
	expect(driver.snapshot() == frozen and frozen.rudder == 0, "pause clears owners and freezes model")
	if s.presentation != null:
		expect(s.presentation.mouse_filter == Control.MOUSE_FILTER_IGNORE, "pause disables direct GUI input")
		expect(s.presentation.find_child("RowingViewport", true, false).render_target_update_mode == SubViewport.UPDATE_ONCE, "pause retains final native frame without live rendering")
		pointer(s.presentation, "stroke", true)
		pointer(s.presentation, "stroke", false)
		expect(driver.snapshot() == frozen, "paused GUI pointer cannot stroke through view")
	s.set_paused(false)
	s._process(200.0)
	expect(driver.snapshot() == frozen, "resume discards suspended delta")
	if s.presentation != null:
		expect(s.presentation.mouse_filter == Control.MOUSE_FILTER_PASS, "resume restores view pointer input")
	s._process(0.1)
	expect(s.elapsed > float(frozen.elapsed), "normal model frames resume")
	key(s, KEY_A)
	s.request_help()
	expect(s.paused and driver.snapshot().rudder == 0, "help clears input and pauses")
	s.set_paused(false)
	s._process(10.0)
	key(s, KEY_D)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(s.paused and driver.snapshot().rudder == 0, "blur pauses and clears held input")
	var retry_view = s.presentation
	s._retry_from_hud()
	expect(not s.paused and not s.ended and s.elapsed == 0.0 and s.active_driver == driver, "retry resets same driver without duplicate view")
	expect(s.presentation == retry_view, "retry preserves one presentation")
	for delta in [NAN, INF, -1.0]:
		s._process(delta)
	expect(s.elapsed == 0.0 and is_finite(s._hud_refresh_clock), "invalid deltas cannot poison Session HUD clock")
	for i in 4000:
		if s.ended: break
		s._process(0.1)
	expect(s.ended and results.size() == 1 and not results[0].success and results[0].ordinary_eligible, "natural timeout has truthful failure and ordinary qualification")
	expect(results[0].game_id == "game-013" and results[0].score_summary.total == s.score, "finished result keeps global identity and driver summary")
	s._process(100.0)
	s._finish(true, true)
	expect(results.size() == 1, "finished signal emits once")
	if s.presentation != null:
		expect(s.presentation.mouse_filter == Control.MOUSE_FILTER_IGNORE, "result blocks direct view input")
	s.set_practice_mode(true)
	expect(not s.ended and s.elapsed == 0.0 and s.practice_mode, "practice starts fresh model")
	for i in 4000:
		if s.ended: break
		s._process(0.1)
	expect(results.size() == 2 and results[1].practice and not results[1].ordinary_eligible and "練習" in results[1].score_summary.qualification_text, "practice timeout cannot grant ordinary card")
	s.set_practice_mode(false)
	key(s, KEY_D)
	var old_view = s.presentation
	s.set_paused(true)
	s.start("game-002")
	expect(s.active_driver == null and driver.snapshot().rudder == 0, "switch to legacy releases driver ownership")
	expect(not s.paused and not s.minigame_hud._pause_layer.visible, "active paused game replacement releases old overlay")
	expect(s.presentation != old_view or old_view == null, "switch to legacy releases old view")
	var old_elapsed: float = driver.snapshot().elapsed
	s._process(0.1)
	expect(driver.snapshot().elapsed == old_elapsed and s.game_id == "game-002", "old driver stops advancing under legacy ID")
	s._finish(true)
	expect(results.back().ordinary_eligible and results.back().game_id == "game-002", "legacy natural result declares ordinary eligibility")
	s.start("rowing_cargo", true)
	expect(s.game_id == "game-013" and s.assisted and s.active_driver != driver, "mode start creates fresh driver after legacy")
	driver = s.active_driver
	key(s, KEY_D)
	old_view = s.presentation
	s.set_paused(true)
	s.start("game-014")
	expect(s.ended and s.game_id.is_empty() and s.active_driver == null and s.presentation == null, "unknown active start tears down previous game")
	expect(driver.snapshot().rudder == 0 and (old_view == null or old_view.is_queued_for_deletion()), "unknown start releases old input and view")
	var result_count := results.size()
	s._process(999.0)
	expect(results.size() == result_count and cancellations.size() == 1, "unknown cannot finish under wrong ID")
	s.start("game-013")
	Solver.solve(Solver.SessionCommands.new(s))
	s._process(0.0)
	expect(s.ended and results.size() == result_count + 1 and results.back().success and results.back().ordinary_eligible and results.back().devil, "real three-cargo Session input route finishes with actual devil qualification")
	expect(results.back().score == 300 and results.back().score_summary.rows[0].count == 3, "success result contains three real deliveries")
	result_count = results.size()
	s.start("game-013")
	key(s, KEY_D)
	driver = s.active_driver
	s._leave_from_hud()
	old_elapsed = driver.snapshot().elapsed
	s._process(99.0)
	expect(s.ended and driver.snapshot().rudder == 0 and driver.snapshot().elapsed == old_elapsed and results.size() == result_count, "leave cancels and stops without completion")
	s.start("game-013")
	s.reduced_motion = true
	s.set_time_of_day("dusk")
	key(s, KEY_SPACE)
	key(s, KEY_SPACE, false)
	key(s, KEY_W)
	key(s, KEY_W, false)
	s._process(0.1)
	s._refresh_hud(true)
	expect(s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "HUD reads normalized driver values")
	expect(not s.minigame_hud._feedback.visible, "driver feedback appears once in its own view instead of over status instruments")
	await process_frame
	await process_frame
	if s.presentation != null:
		var view = s.presentation
		s._sync_presentation()
		expect(s.presentation == view and view.get_index() < s.minigame_hud.get_index(), "one native view stays behind shared HUD")
		var capture_size := root.size
		for window_size in [Vector2i(800, 450), Vector2i(800, 600), Vector2i(1280, 720)]:
			root.size = window_size
			for i in 4: await process_frame
			s._sync_presentation()
			var status_top: float = (view.get_global_transform_with_canvas() * Vector2(24, 140)).y
			var hud_top: float = (s.minigame_hud.get_global_transform_with_canvas() * Vector2(0, s.minigame_hud.gameplay_top())).y
			expect(status_top + 0.01 >= hud_top and is_equal_approx(view.scale.x, view.scale.y), "resize keeps uniform view below measured HUD at %s" % window_size)
			pointer(view, "right", true)
			expect(s.active_driver.snapshot().rudder == 1, "resized GUI pointer aligns at %s" % window_size)
			pointer(view, "right", false)
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.position = view.get_global_transform_with_canvas() * View.button_rect("left").get_center()
			s._unhandled_input(event)
			expect(s.active_driver.snapshot().rudder == -1, "Session fallback uses actual view transform at %s" % window_size)
			event.pressed = false
			s._unhandled_input(event)
		root.size = capture_size
		for i in 4: await process_frame
		s._sync_presentation()
		var capture := OS.get_environment("ROWING_SESSION_CAPTURE")
		if not capture.is_empty():
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(capture) == OK, "native Session frame saved")
	s.queue_free()
	await process_frame
	await process_frame
	print("Rowing Session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
