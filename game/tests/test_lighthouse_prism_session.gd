extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Route = preload("res://game/tests/lighthouse_prism_route.gd")
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
	s.finished.connect(func(result: Dictionary): results.append(result))
	expect(Session.definitions("harbor")[2].mode == "lighthouse_prism", "prism is the third harbor game")
	s.start("game-015")
	expect(s.game_id == "game-015" and s.mode == "lighthouse_prism" and not s.ended, "start accepts delivered global ID")
	if s.game_id != "game-015":
		s.free()
		quit(1)
		return
	var driver = s.active_driver
	expect(driver != null and (s.presentation == null if DisplayServer.get_name() == "headless" else s.presentation != null), "headless skips optional renderer; native owns view")
	await process_frame
	s._process(0.1)
	expect(is_equal_approx(s.elapsed, 0.1) and s.elapsed == driver.snapshot().elapsed, "only model clock advances")
	key(s, KEY_E)
	key(s, KEY_E, false)
	expect(Route.state_of(driver.snapshot(), "p1") == 1, "Session forwards rotation")
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	key(s, KEY_E)
	key(s, KEY_E, false)
	s._process(200.0)
	expect(driver.snapshot() == frozen, "pause freezes the board and clock")
	s.set_paused(false)
	s._process(200.0)
	expect(driver.snapshot() == frozen, "resume discards suspended delta")
	key(s, KEY_E)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(s.paused, "blur pauses")
	s.set_paused(false)
	key(s, KEY_E)
	key(s, KEY_E, false)
	expect(Route.state_of(driver.snapshot(), "p1") == 3, "blur released the held key so the next press acts")
	var retry_view = s.presentation
	s._retry_from_hud()
	expect(not s.ended and s.elapsed == 0.0 and s.active_driver == driver and s.presentation == retry_view, "retry resets same driver and view")
	expect(driver.snapshot().variant == 1 and Route.state_of(driver.snapshot(), "p1") == 0, "retry changes fog and resets the board")
	for i in 2000:
		if s.ended: break
		s._process(0.1)
	expect(s.ended and results.size() == 1 and not results[0].success and results[0].ordinary_eligible and results[0].score == 0, "timeout is a truthful failure with ordinary qualification")
	expect(results[0].game_id == "game-015" and results[0].score_summary.total == s.score, "result keeps identity and driver summary")
	s.set_practice_mode(true)
	var commands = Route.SessionCommands.new(s)
	Route.arrange(commands, Route.CHAIN)
	commands.settle()
	s._process(0.0)
	expect(results.size() == 2 and results[1].practice and results[1].success and not results[1].ordinary_eligible, "practice success never grants cards")
	s.set_practice_mode(false)
	s.start("game-015", true)
	commands = Route.SessionCommands.new(s)
	Route.arrange(commands, Route.DEVIL)
	commands.settle()
	s._process(0.0)
	var last: Dictionary = results.back()
	expect(last.success and last.devil and last.assisted and last.score == 350, "assisted devil route with real keys")
	s.start("game-015")
	commands = Route.SessionCommands.new(s)
	Route.arrange(commands, Route.SPLIT)
	commands.settle()
	s._process(0.0)
	last = results.back()
	expect(last.success and not last.devil and last.score == 300, "split route without the side beacon is success without devil")
	var count := results.size()
	s.start("game-015")
	driver = s.active_driver
	s._leave_from_hud()
	s._process(99.0)
	expect(s.ended and results.size() == count, "leave cancels without completion")
	s.start("game-120")
	expect(s.ended and s.game_id.is_empty() and s.active_driver == null, "undelivered game is refused")
	s.start("game-015")
	s._process(0.1)
	s._refresh_hud(true)
	expect(s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "HUD reads normalized driver values")
	expect(not s.minigame_hud._feedback.visible, "driver feedback stays in its own view")
	s.queue_free()
	await process_frame
	await process_frame
	print("Lighthouse prism Session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
