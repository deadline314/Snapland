extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const View = preload("res://game/minigames/tide_sandbar_view.gd")
const Route = preload("res://game/tests/tide_sandbar_route.gd")
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

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var s = Session.new()
	root.add_child(s)
	s.set_process(false)
	var results: Array[Dictionary] = []
	var cancellations: Array[int] = []
	s.finished.connect(func(result: Dictionary): results.append(result))
	s.cancelled.connect(func(): cancellations.append(1))
	expect(Session.definitions().size() == 12 and Session.definitions("harbor")[1].mode == "tide_sandbar", "welcome stays twelve; sandbar is the second harbor game")
	s.start("game-014")
	expect(s.game_id == "game-014" and s.mode == "tide_sandbar" and not s.ended, "start accepts delivered global ID")
	if s.game_id != "game-014":
		s.free()
		quit(1)
		return
	var driver = s.active_driver
	expect(driver != null and (s.presentation == null if DisplayServer.get_name() == "headless" else s.presentation != null), "headless skips optional renderer; native owns view")
	await process_frame
	s._process(0.1)
	expect(is_equal_approx(s.elapsed, 0.1) and s.elapsed == driver.snapshot().elapsed, "only model clock advances")
	s.elapsed = 999.0
	s._process(0.1)
	expect(not s.ended and is_equal_approx(s.elapsed, 0.2), "legacy timer cannot race model result")
	key(s, KEY_D)
	var before: Vector2 = driver.snapshot().position
	s._process(0.1)
	expect(driver.snapshot().position.x > before.x, "Session forwards held movement")
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	key(s, KEY_SPACE)
	s._process(200.0)
	expect(driver.snapshot() == frozen and not frozen.moving, "pause clears owners and freezes model")
	s.set_paused(false)
	s._process(200.0)
	expect(driver.snapshot() == frozen, "resume discards suspended delta")
	s._process(0.1)
	expect(s.elapsed > float(frozen.elapsed) and driver.snapshot().position == frozen.position, "resumed frames run without stuck movement")
	key(s, KEY_A)
	s.request_help()
	s.set_paused(false)
	s._process(0.1)
	expect(driver.snapshot().position == frozen.position, "help clears held movement")
	key(s, KEY_D)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(s.paused, "blur pauses")
	s.set_paused(false)
	s._process(0.1)
	expect(not driver.snapshot().moving, "blur releases held movement")
	var retry_view = s.presentation
	s._retry_from_hud()
	expect(not s.paused and not s.ended and s.elapsed == 0.0 and s.active_driver == driver and s.presentation == retry_view, "retry resets same driver and view")
	expect(driver.snapshot().variant == 1, "retry changes tide period and highland")
	for delta in [NAN, INF, -1.0]:
		s._process(delta)
	expect(s.elapsed == 0.0 and is_finite(s._hud_refresh_clock), "invalid deltas cannot poison Session")
	for i in 2000:
		if s.ended: break
		s._process(0.1)
	expect(s.ended and results.size() == 1 and not results[0].success and results[0].ordinary_eligible, "natural timeout is a truthful failure with ordinary qualification")
	expect(results[0].game_id == "game-014" and results[0].score_summary.total == s.score and results[0].score == 0, "result keeps global identity and driver summary")
	s._finish(true, true)
	expect(results.size() == 1, "finished emits once")
	s.set_practice_mode(true)
	expect(not s.ended and s.elapsed == 0.0 and s.practice_mode, "practice starts fresh")
	expect(Route.solve(Route.SessionCommands.new(s), Route.SECURE_FIRST, true, 1.0 / 60.0, true), "practice route completes with real keys")
	s._process(0.0)
	expect(results.size() == 2 and results[1].practice and results[1].success and not results[1].ordinary_eligible, "practice success never grants cards")
	s.set_practice_mode(false)
	s.start("game-014", true)
	expect(s.assisted and s.active_driver != driver, "fresh start creates a new driver")
	expect(Route.solve(Route.SessionCommands.new(s), Route.SECURE_FIRST, true, 1.0 / 60.0, true), "assisted secure route with digital keys")
	s._process(0.0)
	var last: Dictionary = results.back()
	expect(last.success and last.devil and last.ordinary_eligible and last.score == 400 and last.assisted, "assisted secure route keeps devil eligibility")
	s.start("game-014")
	expect(Route.solve(Route.SessionCommands.new(s), Route.FAR_FIRST, true, 1.0 / 60.0, true), "far-first route with digital keys")
	s._process(0.0)
	last = results.back()
	expect(last.success and not last.devil and last.score == 400, "far-first is success without devil")
	var count := results.size()
	s.start("game-014")
	key(s, KEY_D)
	driver = s.active_driver
	s._leave_from_hud()
	var old_elapsed: float = driver.snapshot().elapsed
	s._process(99.0)
	expect(s.ended and not driver.snapshot().moving and driver.snapshot().elapsed == old_elapsed and results.size() == count, "leave cancels without completion")
	s.start("game-013")
	expect(s.mode == "rowing_cargo" and s.active_driver != driver, "switching to rowing releases the sandbar driver")
	s.start("game-120")
	expect(s.ended and s.game_id.is_empty() and s.active_driver == null, "undelivered game is refused")
	s.start("game-014")
	s._process(0.1)
	s._refresh_hud(true)
	expect(s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "HUD reads normalized driver values")
	expect(not s.minigame_hud._feedback.visible, "driver feedback stays in its own view")
	s.queue_free()
	await process_frame
	await process_frame
	print("Tide sandbar Session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
