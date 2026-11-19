extends SceneTree

const Model = preload("res://game/minigames/bean_seesaw_model.gd")
const Driver = preload("res://game/minigames/bean_seesaw_driver.gd")
const View = preload("res://game/minigames/bean_seesaw_view.gd")
const Session = preload("res://game/minigames/session.gd")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

static func key(session: Control, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	session._unhandled_input(event)

static func advance(session: Control, seconds: float) -> void:
	for tick in roundi(seconds * 60.0):
		session._process(1.0 / 60.0)

static func participate_without_pair(session: Control) -> void:
	key(session, KEY_A if session._driver_state.pedal > 0 else KEY_D)
	advance(session, 0.55)
	key(session, KEY_Q)
	advance(session, 2.7)
	key(session, KEY_E)

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var model := Model.new()
	for layout in 2:
		for assistance in [false, true]:
			for helper in [false, true]:
				model.reset(assistance, layout)
				model.move_pedal(0)
				if helper:
					model.toggle_helper()
				_model_time(model, 0.55)
				model.release(0)
				model.release(1)
				_model_time(model, 2.8)
				var pair: Dictionary = model.snapshot()
				var masses := Vector2i(2, 1) if layout == 0 else Vector2i(1, 2)
				_check(pair.paired and pair.pans == masses, "both real pans receive the correct masses")
				_check(pair.pair_gap <= pair.sync_window and not pair.ended and not pair.side_catch, "pair stays open for an optional rebound")
				model.move_pedal(2)
				_model_time(model, 0.6)
				model.release(1)
				_model_time(model, 0.5)
				model.move_pedal(-2)
				var flew := false
				for tick in 280:
					model.step(Model.STEP)
					flew = flew or bool(model.snapshot().beans[1].rebounded)
				var result := model.snapshot()
				_check(flew and result.side_catch and result.devil and result.ordinary_eligible and result.score == 420,
					"physical rebound awards both goals in layout %d assist %s helper %s" % [layout, assistance, helper])
	model.reset(false, 0)
	model.move_pedal(-2)
	_model_time(model, 1.25)
	model.release(1)
	_model_time(model, 1.1)
	var held := model.snapshot()
	_model_time(model, 0.25)
	_check(held.beans[1].phase == Model.Flight.BOARD and model.snapshot().beans[1].position.distance_to(held.beans[1].position) < 0.035, "high guide physically retains the light bean")
	model.release(0)
	var max_rise := 0.0
	for tick in 120:
		model.step(Model.STEP)
		max_rise = maxf(max_rise, model.snapshot().angular_speed)
	_check(max_rise > 0.17, "a falling heavy bean lifts the opposite end with a measured angular impulse")
	_check_inputs()
	_check_session()
	for failure in _failures:
		push_error(failure)
	print("Bean seesaw gameplay: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _check_inputs() -> void:
	var driver := Driver.new()
	driver.reset(false, "noon")
	var layout: int = driver.snapshot().layout
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	_check(driver.handle_input(mouse, View.button_rect(2).get_center()) and driver.snapshot().pedal == 0, "mouse moves the pedal to the visible centre")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	_check(driver.handle_input(touch, View.button_rect(View.HOPPER_LEFT).get_center()) and driver.snapshot().beans[0].phase == Model.Flight.DROP, "one finger opens the visible left hopper")
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	_check(not driver.handle_input(mouse, View.button_rect(View.HOPPER_RIGHT).get_center()) and driver.snapshot().beans[1].phase == Model.Flight.EMPTY, "emulated mouse never duplicates a touch")
	var before := driver.snapshot()
	driver.step(NAN)
	driver.step(-4.0)
	_check(driver.snapshot() == before, "non-finite and negative time leave the round intact")
	driver.reset(false, "noon")
	_check(driver.snapshot().layout != layout and driver.snapshot().pans == Vector2i.ZERO and driver.snapshot().elapsed == 0.0, "retry changes the actual configuration and clears the board")

func _check_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	var cancellations: Array[int] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.cancelled.connect(func(): cancellations.append(1))
	session.start("game-031")
	_check(session.active_driver is Driver, "catalog loads the real driver through Session")
	advance(session, 75.15)
	_check(results.size() == 1 and not results[0].ordinary_eligible and not results[0].success, "an idle deadline cannot yield a card")
	session.start("game-031")
	participate_without_pair(session)
	var paused_time: float = session._driver_state.elapsed
	session.set_paused(true)
	key(session, KEY_HOME)
	advance(session, 3.0)
	_check(session._driver_state.elapsed == paused_time and session._driver_state.pedal == 0, "pause blocks clock and new inputs")
	session.set_paused(false)
	advance(session, 76.0)
	_check(results.size() == 2 and results[1].ordinary_eligible and not results[1].success and not results[1].devil, "separate untimed catches qualify through actual participation only")
	session.start("game-031", true)
	session.set_practice_mode(true)
	key(session, KEY_A if session._driver_state.pedal > 0 else KEY_D)
	advance(session, 0.55)
	key(session, KEY_Q)
	key(session, KEY_E)
	advance(session, 2.8)
	key(session, KEY_F)
	advance(session, 0.02)
	_check(results.size() == 3 and results[2].success and not results[2].ordinary_eligible and not results[2].devil, "ordinary finish in practice grants no eligibility")
	_check(results.size() == 3 and results[2].score_summary.rows.reduce(func(total: int, row: Dictionary) -> int: return total + row.amount, 0) == results[2].score, "score rows add up to the actual result")
	session.start("game-031")
	session._leave_from_hud()
	advance(session, 76.0)
	_check(results.size() == 3 and cancellations.size() == 1, "leaving never emits a result")
	session.free()

func _model_time(model: RefCounted, seconds: float) -> void:
	for tick in roundi(seconds / Model.STEP):
		model.step(Model.STEP)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
