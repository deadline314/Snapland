extends SceneTree

const Model = preload("res://game/minigames/sugar_draw_model.gd")
const Driver = preload("res://game/minigames/sugar_draw_driver.gd")
const View = preload("res://game/minigames/sugar_draw_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const Session = preload("res://game/minigames/session.gd")
var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	test_temperature_and_speed()
	test_recipes()
	test_failures()
	test_input()
	test_session()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: sugar draw heat, measured strands, fold and collection")
	quit(int(not _errors.is_empty()))

func test_temperature_and_speed() -> void:
	var model := Model.new()
	model.reset(false, 0)
	model.hold(Model.SLOW, false)
	advance(model, 24)
	var slow := model.snapshot()
	model.reset(false, 0)
	model.hold(Model.FAST, false)
	advance(model, 24)
	var fast := model.snapshot()
	check(slow.width > fast.width and slow.length < fast.length and slow.tension < fast.tension, "rate changes physical thickness, length and tension")
	model.reset(false, 0)
	model.hold(Model.FAST, true)
	advance(model, 24)
	var heated := model.snapshot()
	check(heated.temperature > fast.temperature and heated.width < fast.width and heated.tension < fast.tension, "manual heat changes material and pull response")
	model.reset(false, 0)
	advance(model, 120)
	slow = model.snapshot()
	model.reset(false, 1)
	advance(model, 120)
	fast = model.snapshot()
	check(fast.temperature < slow.temperature and fast.target_lengths != slow.target_lengths, "varied recipes and cooling are physical")

func test_recipes() -> void:
	for layout in 2:
		for bonus in [false, true]:
			var model := Model.new()
			model.reset(layout == 1, layout)
			if layout == 1:
				model.toggle_helper()
			for section in 3:
				var state := model.snapshot()
				var width: float = state.target_widths[section]
				var folded: bool = bonus and width > 1.1
				var speed := Model.SLOW if width > 1.1 else (Model.FAST if width < 0.89 else Model.STEADY)
				pull(model, Model.FAST if folded else speed, state.goal_length * (2.0 if folded else 1.0), layout == 0)
				var material := model.snapshot()
				if folded:
					check(not material.cut_ready and material.fold_ready, "only a measured thin two-length strand qualifies for folding")
					model.fold()
					var sections: Array = model.snapshot().sections
					if sections.size() == section + 1:
						var measured: Dictionary = sections.back()
						check(measured.folded and is_equal_approx(measured.raw_length * 0.5, measured.length)
							and is_equal_approx(measured.width, material.avg_width * Model.FOLD_FACTOR), "fold halves actual length and combines cross sections")
				else:
					check(material.cut_ready, "one full length at the required diameter qualifies to cut")
					model.cut()
				check(model.snapshot().sections.size() == section + 1, "section receives exactly one measured strand")
			var result := model.snapshot()
			check(result.ended and result.success and result.devil == bonus and result.score == (550 if bonus else 450),
				"both layouts have honest ordinary and folded routes")
			check(model.consume_notes() == [1, 2, 3] and model.consume_notes().is_empty(), "only certified sections emit cues")

func test_failures() -> void:
	for assist in [false, true]:
		var model := Model.new()
		model.reset(assist, 0)
		pull(model, Model.SLOW, model.snapshot().goal_length, true)
		model.cut()
		check(model.snapshot().sections.size() == 1, "preservation test starts with a real section")
		pull(model, Model.STEADY, model.snapshot().goal_length * 0.6, true)
		model.fold()
		check(model.snapshot().sections.size() == 1 and model.snapshot().feedback.contains("兩倍"), "short material cannot counterfeit a fold")
		model.hold(0, true)
		advance(model, 160)
		model.hold(Model.STEADY, true)
		advance(model, 36)
		var state := model.snapshot()
		check(state.feedback.contains("過熱") and state.mistakes == 1 and state.sections.size() == (1 if assist else 0),
			"overheat melts the run and only assist reconnects the earlier material")
	var cold := Model.new()
	cold.reset(false, 0)
	advance(cold, 670)
	cold.hold(Model.FAST, false)
	advance(cold, 60)
	check(cold.snapshot().mistakes == 1 and cold.snapshot().feedback.contains("太冷"), "cold overpull snaps with distinct feedback")
	var idle := Model.new()
	idle.reset(false, 0)
	for tick in 360:
		idle.step(0.25)
	check(idle.snapshot().ended and not idle.snapshot().ordinary_eligible, "idle timeout cannot earn participation")

func test_input() -> void:
	var driver := Driver.new()
	driver.reset(true, "noon")
	var outside := Vector2(-15, -15)
	check(driver.handle_input(touch(true), Surface.button_rect(View.STEADY).get_center()), "one pointer can hold the steady handle")
	driver.handle_input(key(KEY_W, true), Vector2.ZERO)
	for tick in 16:
		driver.step(Model.TICK)
	check(driver.snapshot().pull == Model.STEADY and driver.snapshot().heating, "pointer and keyboard may independently control the two inputs")
	check(driver.handle_input(touch(false), outside) and driver.snapshot().pull == 0 and driver.snapshot().heating, "outside release clears only its own hold")
	var cancelled := touch(false)
	cancelled.canceled = true
	driver.handle_input(cancelled, outside)
	check(not driver.snapshot().heating, "cancellation clears the remaining heat input")

func test_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.start("game-036")
	session._unhandled_input(key(KEY_A, true))
	session._process(0.15)
	var before: float = session._driver_state.length
	session._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	session._process(0.20)
	check(session.paused and session.active_driver.snapshot().pull == 0 and session.active_driver.snapshot().length == before,
		"focus loss releases the handle and pauses time")
	session.set_paused(false)
	participate(session)
	for tick in 360:
		session._process(0.25)
	check(results.size() == 1 and results[0].ordinary_eligible and not results[0].success and not results[0].devil,
		"one real measured draw enables the ordinary natural timeout only")
	session.free()

static func participate(session: Control) -> void:
	session._unhandled_input(key(KEY_S, true))
	for tick in 4:
		session._process(0.14)
	session._unhandled_input(key(KEY_S, false))

func pull(model: RefCounted, speed: int, length: float, manual: bool) -> void:
	for tick in 660:
		var state: Dictionary = model.snapshot()
		if state.length >= length - 0.00001:
			break
		model.hold(speed, manual and state.temperature < 0.54)
		model.step(Model.TICK)
	model.clear_input()

func advance(model: RefCounted, ticks: int) -> void:
	for tick in ticks:
		model.step(Model.TICK)

static func key(code: int, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	return event

func touch(down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = down
	event.index = 0
	return event

func check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
