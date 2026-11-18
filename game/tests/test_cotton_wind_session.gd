extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Driver = preload("res://game/minigames/cotton_wind_driver.gd")
const View = preload("res://game/minigames/cotton_wind_view.gd")
const Route = preload("res://game/tests/cotton_wind_route.gd")
const GAME := "game-030"
const DIRECTIONS := {KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_W: Vector2.UP, KEY_S: Vector2.DOWN}

var checks := 0
var failures := 0
var results: Array[Dictionary] = []
var cancellations := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.cancelled.connect(func(): cancellations += 1)
	session.start(GAME)
	var wired := session.game_id == GAME and session.mode == "cotton_wind" and session.active_driver is Driver and not session.ended
	expect(wired, "game-030 must open a live Cotton Wind Session")
	if wired:
		for source: String in ["keyboard", "mouse", "touch"]:
			for assisted: bool in [false, true]:
				for variant in 2:
					for rejoin: bool in [false, true]:
						session.start(GAME, assisted)
						if variant == 1:
							session.minigame_hud.retry_requested.emit()
						var count := results.size()
						var outcome := play(session, source, rejoin)
						var score := 500 if rejoin else 400
						expect(outcome.variant == variant and outcome.uniform and outcome.rejoins == int(rejoin) and outcome.held_commands.is_empty(),
							"route uses requested A/B and reaches actual uniformity/rejoin, then clears input: %s" % source)
						expect(results.size() == count + 1 and session.ended and session.won and session.devil_won == rejoin,
							"bounded route must emit exactly one natural result: %s" % source)
						expect(results.size() == count + 1 and _matches_result(results.back(), true, rejoin, assisted, false, true, score),
							"Session binds actual points and eligibility: %s" % source)
						print("COTTON_SESSION_ROUTE ", JSON.stringify({"source": source, "variant": "AB"[variant], "assisted": assisted,
							"rejoin": rejoin, "elapsed": outcome.elapsed, "score": outcome.score, "rejoins": outcome.rejoins, "quality": outcome.quality}))
		_lifecycle(session)
	session.free()
	print("Cotton wind Session: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))

# Headless event characterization at the Session dispatch boundary.
static func key(session: Control, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	session._unhandled_input(event)

static func pointer(session: Control, design_point: Vector2, finger: int, pressed: bool, moving := false, canceled := false) -> void:
	var scale_factor := minf(session.size.x / Session.DESIGN_SIZE.x, session.size.y / Session.DESIGN_SIZE.y)
	var position := (session.size - Session.DESIGN_SIZE * scale_factor) * 0.5 + design_point * scale_factor
	var event: InputEvent
	if finger >= 0 and moving:
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = finger
		touch_drag.position = position
		event = touch_drag
	elif finger >= 0:
		var touch := InputEventScreenTouch.new()
		touch.index = finger
		touch.position = position
		touch.pressed = pressed
		touch.canceled = canceled
		event = touch
	elif moving:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = position
		event = motion
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = position
		button.pressed = pressed
		event = button
	session._unhandled_input(event)

static func tap(session: Control, command: String, finger: int) -> void:
	var point := View.command_center(command)
	pointer(session, point, finger, true)
	pointer(session, point, finger, false)

static func play(session: Control, source: String, rejoin: bool, confirm := true) -> Dictionary:
	var driver: RefCounted = session.active_driver
	var finger := 0 if source == "touch" else -1
	var point: Vector2
	var key_direction := Vector2.ZERO
	if source == "keyboard":
		key(session, KEY_E, true)
	else:
		tap(session, "spin_right", finger)
		point = View.stick_to_design(Route.target(driver.snapshot(), rejoin))
		pointer(session, point, finger, true)
	var delta := 1.0 / 120.0 if source == "keyboard" else Route.DT
	for tick in ceili(120.0 / delta) + 1:
		var state: Dictionary = driver.snapshot()
		if state.ended:
			break
		if state.uniform and (not rejoin or state.rejoins > 0):
			if confirm:
				if source == "keyboard":
					key(session, KEY_F, true)
				else:
					pointer(session, point, finger, false)
					tap(session, "finish", finger)
				session._process(0.0)
			break
		var target := Route.target(state, rejoin)
		if source == "keyboard":
			var difference := target - Vector2(state.stick.x, state.stick.z)
			var direction := Vector2(signf(difference.x) if absf(difference.x) >= 0.5 else 0.0,
				signf(difference.y) if absf(difference.y) >= 0.5 else 0.0)
			for code: Key in DIRECTIONS:
				var basis: Vector2 = DIRECTIONS[code]
				if direction.dot(basis) != key_direction.dot(basis):
					key(session, code, direction.dot(basis) > 0)
			key_direction = direction
		else:
			point = View.stick_to_design(target)
			pointer(session, point, finger, true, true)
		session._process(delta)
	return driver.snapshot()

static func participate(session: Control) -> Dictionary:
	key(session, KEY_E, true)
	key(session, KEY_D, true)
	key(session, KEY_W, true)
	advance(session, 0.25)
	key(session, KEY_D, false)
	key(session, KEY_W, false)
	advance(session, 2.75)
	key(session, KEY_E, false)
	return session.active_driver.snapshot()

static func advance(session: Control, seconds: float) -> void:
	while seconds > 0.000001 and not session.ended:
		var delta := minf(seconds, 0.25)
		session._process(delta)
		seconds -= delta

func _lifecycle(session: Control) -> void:
	session.start(GAME)
	key(session, KEY_R, true)
	key(session, KEY_R, false)
	advance(session, 121.0)
	var idle: Dictionary = session.active_driver.snapshot()
	expect(idle.helper and idle.material.helper > 0 and is_zero_approx(idle.travel) and is_zero_approx(idle.spin_travel),
		"helper genuinely collects its own material while the player makes zero motion")
	expect(_matches_result(results.back(), false, false, false, false, false, 0), "idle helper run earns no card")

	session.start(GAME)
	key(session, KEY_F, true)
	key(session, KEY_F, false)
	expect(not session.ended and session.active_driver.snapshot().mistakes == 1, "premature F records a miss and keeps the workbench open")
	var state := participate(session)
	expect(state.participated and state.material.player >= 1 and not state.uniform, "real move, spin and deposited material satisfy only the participation threshold")
	var count := results.size()
	advance(session, 121.0)
	expect(results.size() == count + 1 and results.back().ordinary_eligible and not results.back().success and not results.back().devil
		and is_equal_approx(session.elapsed, 120.0), "participated timeout earns ordinary and never succeeds")
	advance(session, 2.0)
	expect(results.size() == count + 1, "deadline result emits only once")

	session.start(GAME)
	state = play(session, "mouse", true, false)
	expect(state.uniform and state.rejoins == 1 and not state.ended, "uniform rejoined work stays live until F or the deadline")
	var hold := View.stick_to_design(Vector2(state.stick.x, state.stick.z))
	pointer(session, hold, -1, false)
	tap(session, "spin_right", -1)
	count = results.size()
	advance(session, 121.0)
	expect(results.size() == count + 1 and _matches_result(results.back(), false, false, false, false, true, 300),
		"uniformity plus a rejoin at the deadline without F gives 300 and no success or devil")

	session.start(GAME, true)
	session.set_practice_mode(true)
	count = results.size()
	state = play(session, "touch", true)
	expect(state.success and state.devil and results.size() == count + 1 and _matches_result(results.back(), true, true, true, true, false, 500),
		"real practice devil route keeps the computed result and excludes collection")
	session.set_practice_mode(false)

	session.start(GAME)
	for interruption: String in ["pause", "blur", "touch cancel"]:
		tap(session, "spin_right", 0)
		var point := View.stick_to_design(Vector2(-85 if interruption == "blur" else 85, 120))
		var start: Vector3 = session.active_driver.snapshot().stick
		pointer(session, point, 0, true)
		advance(session, 0.25)
		var before: Dictionary = session.active_driver.snapshot()
		expect(before.omega > 0 and before.stick.distance_to(start) > 1.0, "actual touch drag and spin latch run before " + interruption)
		match interruption:
			"pause":
				session.minigame_hud.pause_requested.emit()
			"blur":
				session.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			"touch cancel":
				pointer(session, point, 0, false, false, true)
		var frozen: Dictionary = session.active_driver.snapshot()
		expect(is_zero_approx(frozen.omega) and frozen.held_commands.is_empty() and frozen.bands == before.bands,
			interruption + " clears drag and latch without removing existing material")
		if interruption != "touch cancel":
			key(session, KEY_E, true)
			session._process(10.0)
			expect(session.paused and session.active_driver.snapshot() == frozen, interruption + " freezes time and ignores held controls")
			session.minigame_hud.resume_requested.emit()
			session._process(10.0)
			expect(not session.paused and session.active_driver.snapshot() == frozen, interruption + " discards its suspended frame on resume")
		advance(session, 0.25)
		var settled: Dictionary = session.active_driver.snapshot()
		expect(settled.stick == frozen.stick and settled.angle == frozen.angle and settled.elapsed > frozen.elapsed,
			interruption + " cannot leave ghost movement after the clock advances")
	var previous_driver: RefCounted = session.active_driver
	session.minigame_hud.retry_requested.emit()
	state = session.active_driver.snapshot()
	expect(session.active_driver == previous_driver and state.variant == 1 and state.elapsed == 0.0 and state.material.player == 0.0
		and not state.participated and state.held_commands.is_empty(), "HUD retry alternates wind and resets the real workpiece")
	state = participate(session)
	expect(state.participated, "cancel fixture genuinely participates")
	count = results.size()
	var previous_cancellations := cancellations
	session.minigame_hud.leave_requested.emit()
	advance(session, 121.0)
	expect(session.ended and results.size() == count and cancellations == previous_cancellations + 1, "leave emits cancellation without a result")

func _matches_result(result: Dictionary, success: bool, devil: bool, assisted: bool, practice: bool, ordinary: bool, score: int) -> bool:
	return result.game_id == GAME and result.success == success and result.devil == devil and result.assisted == assisted \
		and result.practice == practice and result.ordinary_eligible == ordinary and result.score == score and result.score_summary.total == score

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
