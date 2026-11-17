extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var session = Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	var cancelled: Array[int] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.cancelled.connect(func(): cancelled.append(1))
	for definition: Dictionary in Catalog.all_definitions():
		session.start(definition.id)
		if definition.mode == "jelly_trampoline":
			preload("res://game/tests/test_jelly_trampoline_session.gd").launch(session, 0.15)
		if definition.mode == "sugar_bridge":
			var load_ball := InputEventKey.new()
			load_ball.keycode = KEY_ENTER
			load_ball.pressed = true
			session._unhandled_input(load_ball)
			load_ball.pressed = false
			session._unhandled_input(load_ball)
		if definition.mode == "syrup_flood":
			var valve := InputEventKey.new()
			valve.keycode = KEY_SPACE
			for pressed in [true,false,true,false]:
				valve.pressed = pressed
				session._unhandled_input(valve)
		if definition.mode == "cookie_mold":
			var move_tray := InputEventKey.new()
			move_tray.keycode = KEY_RIGHT
			move_tray.pressed = true
			session._unhandled_input(move_tray)
			session._process(0.1)
			move_tray.pressed = false
			session._unhandled_input(move_tray)
		if session.active_driver != null:
			for tick in 4000:
				if session.ended: break
				session._process(0.1)
		else:
			session._finish(false, true)
		_check(results.back().get("ordinary_eligible", false) and not results.back().success and not results.back().devil, definition.id + " natural false stays honest and ordinary eligible")
		var result_count := results.size()
		session._finish(true, true)
		_check(results.size() == result_count, "natural finish emits once")
		session.start(definition.id)
		session.set_practice_mode(true)
		if definition.mode == "jelly_trampoline":
			preload("res://game/tests/test_jelly_trampoline_session.gd").launch(session, 0.15)
			preload("res://game/tests/test_jelly_trampoline_session.gd").advance(session, 61.0)
		elif definition.mode == "syrup_flood":
			var practice_valve := InputEventKey.new()
			practice_valve.keycode = KEY_SPACE
			for pressed in [true,false,true,false]:
				practice_valve.pressed = pressed
				session._unhandled_input(practice_valve)
			for tick in 310:
				if session.ended: break
				session._process(0.25)
		elif session.active_driver != null: session._driver_state["ordinary_eligible"] = true
		session._finish(false)
		_check(results.back().has("ordinary_eligible") and not results.back().ordinary_eligible and results.back().practice, definition.id + " practice excluded explicitly")
		session.set_practice_mode(false)
		session.start(definition.id)
		result_count = results.size()
		var cancel_count := cancelled.size()
		session._leave_from_hud()
		session._finish(false)
		_check(results.size() == result_count and cancelled.size() == cancel_count + 1, definition.id + " cancellation is separate")
	session.start("game-013")
	session._driver_state["ordinary_eligible"] = false
	session._finish(false)
	_check(not results.back().ordinary_eligible, "driver natural ineligibility is retained")
	session.free()
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: every delivered participation result, practice, cancellation and driver eligibility")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
