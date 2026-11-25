extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const View = preload("res://game/minigames/sugar_bridge_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

static func key(session: Control, code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	session._unhandled_input(event)

static func tap(session: Control, code: Key) -> void:
	key(session, code)
	key(session, code, false)

static func advance(session: Control, seconds: float) -> void:
	for i in ceili(seconds / 0.25):
		if session.ended: break
		session._process(0.25)

static func pointer(session: Control, work: Vector2, action: String) -> void:
	var design := View.design_point(work)
	var scale_factor := minf(session.size.x / Session.DESIGN_SIZE.x, session.size.y / Session.DESIGN_SIZE.y)
	var position: Vector2 = session.presentation.get_global_transform_with_canvas() * design if is_instance_valid(session.presentation) else session.get_global_transform_with_canvas() * ((session.size - Session.DESIGN_SIZE * scale_factor) * 0.5 + design * scale_factor)
	var event: InputEvent
	if action == "move":
		event = InputEventMouseMotion.new()
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = action == "press"
	event.position = position
	session._unhandled_input(event)

static func drag(session: Control, endpoint: int, destination: Vector2) -> void:
	pointer(session, session.active_driver.snapshot().endpoints[endpoint].position, "press")
	pointer(session, destination, "move")
	pointer(session, destination, "release")

static func solve(session: Control, devil: bool = false) -> bool:
	if session == null or session.active_driver == null: return false
	session.set_process(false)
	drag(session, 0, Vector2.ZERO)
	var state: Dictionary = session.active_driver.snapshot()
	if devil:
		var flight := 0.9
		var pull: Vector2 = (Vector2(state.hopper) + Vector2(0, 2.4 * flight * flight)) / (1.0 - 4.0 * float(state.elasticity) * flight)
		drag(session, 1, pull)
		advance(session, 1.25)
		if not session.active_driver.snapshot().bands[0].hit: return false
	state = session.active_driver.snapshot()
	drag(session, 1, state.anchors[2])
	for i in 3:
		tap(session, KEY_ENTER)
		advance(session, 14.0)
	return session.ended and session.won and (session.devil_won if devil else not session.devil_won)

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Sugar Session requires an absolute isolated save")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	expect(Catalog.find("game-025").get("mode", "") == "sugar_bridge", "game-025 must be delivered before Sugar Session integration can run")
	if failures:
		_finish()
		return
	var s = Session.new()
	root.add_child(s)
	s.set_process(false)
	var results: Array[Dictionary] = []
	s.finished.connect(func(result: Dictionary): results.append(result))
	s.start("game-025")
	expect(s.mode == "sugar_bridge" and s.active_driver != null and not s.ended, "Session routes025 to the material driver")
	if s.active_driver == null:
		s.free()
		_finish()
		return
	var driver = s.active_driver
	expect(s.presentation == null if DisplayServer.get_name() == "headless" else s.presentation != null, "native owns a view and headless keeps rules renderer-free")
	await process_frame
	s._process(0.1)
	expect(is_equal_approx(s.elapsed, 0.1) and s.elapsed == driver.snapshot().elapsed, "only model time advances")
	tap(s, KEY_SPACE)
	key(s, KEY_RIGHT)
	s._process(0.1)
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	expect(frozen.grabbed == -1 and not frozen.bean.active, "pause cancels held input without firing")
	s._process(100.0)
	expect(driver.snapshot() == frozen, "pause freezes materials and timer")
	s.set_paused(false)
	s._process(100.0)
	expect(driver.snapshot() == frozen, "resume discards suspended delta")
	tap(s, KEY_SPACE)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(s.paused and driver.snapshot().grabbed == -1 and not driver.snapshot().bean.active, "blur pauses and cancels without firing")
	s.set_paused(false)
	var old_view = s.presentation
	s._retry_from_hud()
	expect(s.active_driver == driver and s.presentation == old_view and driver.snapshot().variant == 1 and s.elapsed == 0.0, "retry reuses driver/view and changes real configuration")
	advance(s, 151.0)
	expect(results.size() == 1 and not results[0].success and not results[0].ordinary_eligible, "idle timeout truthfully grants no participation")
	s.start("game-025")
	tap(s, KEY_ENTER)
	advance(s, 151.0)
	expect(results.size() == 2 and not results.back().success and results.back().ordinary_eligible and results.back().mistakes > 0, "actual load and fall then timeout qualifies ordinary only")
	expect(results.back().game_id == "game-025" and results.back().score_summary.total == s.score, "result identity and score rows agree")
	s.start("game-025")
	s.set_practice_mode(true)
	expect(solve(s, true), "real pointer sling and bridge complete practice")
	expect(results.back().practice and results.back().success and not results.back().ordinary_eligible, "practice suppresses ordinary despite real success")
	s.set_practice_mode(false)
	s.start("game-025", true)
	expect(solve(s, true), "assisted real sling and same-band bridge complete")
	expect(results.back().success and results.back().devil and results.back().assisted and results.back().score == 500, "assisted same-band success retains devil and exact score")
	s.start("game-025")
	expect(solve(s), "ordinary long bridge delivers three balls")
	expect(results.back().success and not results.back().devil and results.back().score == 400, "unslung route remains ordinary with exact score")
	var count := results.size()
	s.start("game-025")
	tap(s, KEY_SPACE)
	key(s, KEY_RIGHT)
	s._leave_from_hud()
	s._process(99.0)
	expect(s.ended and results.size() == count and s.active_driver.snapshot().grabbed == -1, "cancel releases input and emits no completion")
	s.start("game-034")
	expect(s.ended and s.game_id.is_empty() and s.active_driver == null, "upcoming game 034 remains refused")
	s.start("game-025")
	s._process(0.1)
	s._refresh_hud(true)
	expect(s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "shared HUD displays driver timer and actual transport")
	s.queue_free()
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	print("Sugar bridge Session: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
