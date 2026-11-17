extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const View = preload("res://game/minigames/jelly_trampoline_view.gd")
const InputRoute = preload("res://game/tests/test_cookie_mold_session.gd")
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
	InputRoute.key(session, code, pressed)

static func tap(session: Control, code: Key) -> void:
	InputRoute.tap(session, code)

static func advance(session: Control, seconds: float) -> void:
	InputRoute.advance(session, seconds)

static func configure(session: Control, x: float, tilt: float) -> void:
	for i in 20:
		var state: Dictionary = session.active_driver.snapshot()
		if is_equal_approx(state.bed.x, x): break
		tap(session, KEY_D if state.bed.x < x else KEY_A)
	for i in 12:
		var angle: float = session.active_driver.snapshot().tilt
		if is_equal_approx(angle, tilt): break
		tap(session, KEY_E if angle < tilt else KEY_Q)

static func launch(session: Control, seconds: float, pointer: bool = false) -> void:
	var point: Vector2 = View.button_rect("charge").get_center()
	if pointer: InputRoute.pointer(session, point, "press")
	else: key(session, KEY_SPACE)
	advance(session, seconds)
	if pointer: InputRoute.pointer(session, point, "release")
	else: key(session, KEY_SPACE, false)

static func wait_ready(session: Control) -> bool:
	for frame in 900:
		if session.ended or session.active_driver.snapshot().fruit.ready: return true
		advance(session, 1.0 / 120.0)
	return false

static func shot(session: Control, bell: bool = false, pointer: bool = false) -> bool:
	var state: Dictionary = session.active_driver.snapshot()
	var delivered: int = state.delivered
	var recipe: Array = [380.0, 21.0, 1.28]
	if is_equal_approx(state.fruit.mass, 1.15): recipe = [420.0, 28.0, 1.28]
	elif is_equal_approx(state.fruit.mass, 0.9): recipe = [340.0, 21.0, 1.26]
	configure(session, recipe[0] + (80.0 if bell else 0.0), recipe[1])
	launch(session, recipe[2], pointer)
	if not wait_ready(session): return false
	return session.active_driver.snapshot().delivered == delivered + 1

static func solve(session: Control, devil: bool = false, helper: bool = false, pointer: bool = false) -> bool:
	if session == null or session.active_driver == null: return false
	session.set_process(false)
	var driver = session.active_driver
	if helper:
		configure(session, 340, 0)
		tap(session, KEY_R)
		launch(session, 0.8, pointer)
		if not wait_ready(session): return false
		var caught: Dictionary = driver.snapshot()
		if not caught.fruit.ready or caught.charging or caught.delivered != 0 or caught.mistakes != 0 or caught.fruit.vx != 0 or caught.fruit.vy != 0: return false
		tap(session, KEY_R)
	for fruit in 3:
		if not shot(session, devil and fruit == 0, pointer): return false
	var final: Dictionary = driver.snapshot()
	print("Jelly Session route: ", {"variant":final.variant,"assisted":final.assisted,"helper":helper,"pointer":pointer,"delivered":final.delivered,"bell_deliveries":final.bell_deliveries,"elapsed":final.elapsed,"score":final.score})
	return session.ended and session.won and session.devil_won == devil and final.delivered == 3 and final.bell_deliveries == int(devil)

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	expect(Catalog.find("game-028").get("mode", "") == "jelly_trampoline", "game028 must route to the fourth delivered factory game")
	if failures:
		_finish()
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var s = Session.new()
	root.add_child(s)
	s.set_process(false)
	var results: Array[Dictionary] = []
	var cancels: Array[int] = []
	s.finished.connect(func(result: Dictionary): results.append(result))
	s.cancelled.connect(func(): cancels.append(1))
	s.start("game-028")
	expect(s.mode == "jelly_trampoline" and s.active_driver != null and not s.ended, "Session uses independent Jelly driver")
	if s.active_driver == null:
		s.free()
		_finish()
		return
	var driver = s.active_driver
	key(s, KEY_SPACE)
	advance(s, 0.7)
	expect(driver.snapshot().charging and not driver.snapshot().participated and driver.snapshot().depth > 0.4, "real held key charges without participation")
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	key(s, KEY_SPACE, false)
	s._process(20.0)
	expect(driver.snapshot() == frozen and not frozen.charging and frozen.fruit.ready, "pause cancels held charge and blocks time/input")
	s.set_paused(false)
	s._process(20.0)
	key(s, KEY_SPACE, false)
	expect(driver.snapshot() == frozen and not driver.snapshot().participated, "resume drops suspended delta and late release cannot ghost launch")
	key(s, KEY_SPACE)
	advance(s, 0.2)
	key(s, KEY_SPACE, false)
	expect(driver.snapshot().participated and not driver.snapshot().fruit.ready, "fresh real press hold release launches after pause")
	var old_view = s.presentation
	s._retry_from_hud()
	expect(s.active_driver == driver and s.presentation == old_view and driver.snapshot().variant == 1 and s.elapsed == 0.0 and not driver.snapshot().participated, "retry retains driver/view but clears ownership and selects B")
	key(s, KEY_SPACE, false)
	advance(s, 61.0)
	expect(results.size() == 1 and not results.back().success and not results.back().ordinary_eligible and results.back().score == 0, "idle natural timeout remains ineligible")
	s.start("game-028")
	for code in [KEY_A, KEY_E, KEY_R, KEY_X]: tap(s, code)
	key(s, KEY_SPACE)
	advance(s, 2.0)
	s.set_paused(true)
	s.set_paused(false)
	s._process(0.1)
	advance(s, 61.0)
	expect(not results.back().ordinary_eligible, "configuration helper reset and canceled hold never grant ordinary")
	s.start("game-028")
	launch(s, 0.15)
	advance(s, 61.0)
	expect(results.back().ordinary_eligible and not results.back().success and not results.back().devil, "real launch then natural timeout earns ordinary only")
	for assisted in [false, true]:
		for devil in [false, true]:
			for variant in 2:
				s.start("game-028", assisted)
				if variant == 1: s._retry_from_hud()
				expect(s.active_driver.snapshot().variant == variant, "actual retry chooses requested A/B")
				expect(solve(s, devil, assisted, variant == 1), "actual keyboard/pointer A/B ordinary/bell route, assisted real AI catch/manual release")
				expect(results.back().score == (500 if devil else 400) and results.back().ordinary_eligible and results.back().assisted == assisted and results.back().game_id == "game-028", "natural result has fixed028 identity and score")
				expect(results.back().score_summary.total == s.score, "score summary reads actual source")
	s.start("game-028")
	expect(shot(s) and shot(s), "recatch route starts with two actual ordinary deliveries")
	configure(s, 500, 35)
	tap(s, KEY_R)
	launch(s, 1.34)
	for i in 3: tap(s, KEY_D)
	expect(wait_ready(s), "same-fruit bell trajectory returns to moved bed")
	var caught: Dictionary = s.active_driver.snapshot()
	expect(caught.delivered == 2 and caught.bell_deliveries == 0 and caught.fruit.bell_touched and caught.fruit.ready and not caught.charging and caught.mistakes == 0, "real bell bed catch retains same-fruit flag at2/3 without premature award")
	advance(s, 0.25)
	expect(s.active_driver.snapshot().fruit.ready and not s.active_driver.snapshot().charging, "AI caught fruit waits without automatic launch")
	expect(shot(s) and results.back().devil and results.back().score == 500, "manual recharge release truly delivers the bell fruit")
	s.start("game-028")
	s.set_practice_mode(true)
	expect(solve(s, true), "practice still requires real three deliveries and bell")
	expect(results.back().practice and not results.back().ordinary_eligible and results.back().devil, "practice suppresses awards while retaining honest physical result")
	s.set_practice_mode(false)
	var count := results.size()
	s.start("game-028")
	key(s, KEY_SPACE)
	advance(s, 0.5)
	s._leave_from_hud()
	key(s, KEY_SPACE, false)
	s._process(100.0)
	expect(s.ended and results.size() == count and cancels.size() == 1 and not s.active_driver.snapshot().participated, "cancel clears charge and emits no result")
	s.start("game-028")
	key(s, KEY_SPACE)
	advance(s, 0.5)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	frozen = s.active_driver.snapshot()
	s._process(99.0)
	expect(s.paused and not frozen.charging and s.active_driver.snapshot() == frozen, "blur pauses and cancels actual held charge")
	s.set_paused(false)
	s._process(99.0)
	key(s, KEY_SPACE, false)
	s._refresh_hud(true)
	expect(not s.active_driver.snapshot().participated and s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "blur late release cannot launch and HUD reads actual source")
	s.queue_free()
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	print("Jelly trampoline Session: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
