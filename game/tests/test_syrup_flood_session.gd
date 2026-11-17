extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const View = preload("res://game/minigames/syrup_flood_view.gd")
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

static func select(session: Control, branch: int) -> void:
	for i in 3:
		if session.active_driver.snapshot().selected == branch: return
		tap(session, KEY_TAB)

static func solve(session: Control, devil: bool = false, helper: bool = false, pointer: bool = false) -> bool:
	if session == null or session.active_driver == null: return false
	session.set_process(false)
	for branch in 3:
		if pointer:
			InputRoute.pointer(session, View.valve_point(branch), "press")
			InputRoute.pointer(session, View.valve_point(branch), "release")
		else:
			select(session, branch)
			tap(session, KEY_SPACE)
	if devil:
		select(session, 1)
		tap(session, KEY_F)
	select(session, 0)
	tap(session, KEY_H)
	for frame in 5000:
		if not is_instance_valid(session) or session.ended: break
		var state: Dictionary = session.active_driver.snapshot()
		for branch in 3:
			if state.branches[branch].valve and state.branches[branch].fill >= state.branches[branch].capacity * 0.92:
				select(session, branch)
				tap(session, KEY_SPACE)
		state = session.active_driver.snapshot()
		if state.ended:
			advance(session, 1.0 / 60.0)
			break
		for branch in 3:
			if state.branches[branch].fill < state.branches[branch].capacity * 0.92 and not (branch == 1 and state.diversion):
				select(session, branch)
				if helper and state.helper != branch: tap(session, KEY_R)
				if state.heater != branch: tap(session, KEY_H)
				break
		advance(session, 1.0 / 60.0)
	print("Syrup route: ", {"devil":devil,"helper":helper,"pointer":pointer,"state":session.active_driver.snapshot()})
	return session.ended and session.won and session.devil_won == devil

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	expect(Catalog.find("game-027").get("mode", "") == "syrup_flood", "game027 must be the delivered third factory game")
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
	s.start("game-027")
	expect(s.mode == "syrup_flood" and s.active_driver != null and not s.ended, "Session routes027 to independent driver")
	if s.active_driver == null:
		s.free()
		_finish()
		return
	var driver = s.active_driver
	InputRoute.key(s, KEY_SPACE)
	s._process(0.1)
	s.set_paused(true)
	var frozen: Dictionary = driver.snapshot()
	tap(s, KEY_H)
	s._process(20.0)
	expect(driver.snapshot() == frozen and frozen.branches[0].valve, "Esc pause clears ownership but preserves latched valve and blocks all controls/time")
	s.set_paused(false)
	s._process(20.0)
	expect(driver.snapshot() == frozen, "resume discards suspended delta")
	tap(s, KEY_SPACE)
	expect(not driver.snapshot().branches[0].valve, "pause clear permits a fresh press without a late release action")
	var old_view = s.presentation
	s._retry_from_hud()
	expect(s.active_driver == driver and s.presentation == old_view and driver.snapshot().variant == 1 and s.elapsed == 0.0, "retry retains driver/view and alternates actual B configuration")
	advance(s, 76.0)
	expect(results.size() == 1 and not results.back().success and not results.back().ordinary_eligible and results.back().score == 0, "idle timeout is ineligible and score0")
	s.start("game-027")
	tap(s, KEY_TAB)
	tap(s, KEY_R)
	tap(s, KEY_C)
	tap(s, KEY_C)
	advance(s, 76.0)
	expect(not results.back().ordinary_eligible, "selection helper configuration alone do not grant participation")
	s.start("game-027")
	tap(s, KEY_SPACE)
	tap(s, KEY_SPACE)
	advance(s, 76.0)
	expect(results.back().ordinary_eligible and not results.back().success and not results.back().devil, "real valve operation then timeout earns ordinary only")
	for assisted in [false,true]:
		for devil in [false,true]:
			for variant in 2:
				s.start("game-027", assisted)
				if variant == 1: s._retry_from_hud()
				expect(s.active_driver.snapshot().variant == variant, "actual retry chooses requested A/B")
				expect(solve(s, devil, assisted, variant == 1), "real keyboard/pointer A/B ordinary/devil assisted route")
				expect(results.back().score == (500 if devil else 400) and results.back().ordinary_eligible and results.back().assisted == assisted and results.back().game_id == "game-027", "real route identity eligibility and exact score")
				expect(results.back().score_summary.total == s.score, "score rows agree with model source")
	s.start("game-027")
	s.set_practice_mode(true)
	expect(solve(s, true), "practice still requires actual cold material and three closed filled tanks")
	expect(results.back().practice and not results.back().ordinary_eligible and results.back().devil, "practice suppresses awards without falsifying physical result")
	s.set_practice_mode(false)
	var count := results.size()
	s.start("game-027")
	InputRoute.key(s, KEY_SPACE)
	s._leave_from_hud()
	s._process(100.0)
	expect(s.ended and results.size() == count and cancels.size() == 1, "cancel never emits a result")
	s.start("game-027")
	InputRoute.key(s, KEY_H)
	s._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	frozen = s.active_driver.snapshot()
	s._process(99.0)
	expect(s.paused and s.active_driver.snapshot() == frozen, "blur pauses and preserves shared heat")
	s.set_paused(false)
	s._process(99.0)
	s._process(0.1)
	s._refresh_hud(true)
	expect(s.minigame_hud._time.text == s.active_driver.snapshot().time_text and s.minigame_hud._progress.text == s.active_driver.snapshot().progress_text, "HUD reads actual model timer and fill")
	s.queue_free()
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	print("Syrup flood Session: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
