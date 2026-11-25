extends SceneTree

const Model = preload("res://game/minigames/bubble_lift_model.gd")
const View = preload("res://game/minigames/bubble_lift_view.gd")
const Driver = preload("res://game/minigames/bubble_lift_driver.gd")
const Session = preload("res://game/minigames/session.gd")

var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_test_load_and_force()
	_test_delivery()
	_test_heat_and_recovery()
	_test_pointer()
	_test_session()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: bubble lift cargo, heat windows, split delivery and collection")
	quit(int(not _errors.is_empty()))

func _test_load_and_force() -> void:
	var model := Model.new()
	model.reset(false, 0)
	model.toggle_helper()
	model.set_holds(Model.LEFT_PUMP, false)
	advance(model, 30)
	check(model.snapshot().loaded == 0 and model.snapshot().gas == 0.0, "AI and pumps require load confirmation")
	model.confirm_or_split()
	model.release_basket()
	check(model.phase() == Model.DOCK, "zero gas cannot release the basket")
	advance(model, 30)
	check(model.snapshot().gas == 0.0, "confirming the load does not reactivate pre-load input")
	model.set_holds(Model.LEFT_PUMP, false)
	advance(model, 30)
	check(is_equal_approx(model.snapshot().gas, 0.91), "AI adds the actual second pump rate while the player pumps")
	model.set_holds(0, true)
	advance(model, 12)
	check(is_equal_approx(model.snapshot().gas, 0.68), "dock valve bleeds a known amount of gas")
	model.choose_count(2)
	check(model.snapshot().loaded == 0 and model.snapshot().gas == 0.0, "changing carrier clears old cargo and pressure")

	var samples: Array[Dictionary] = []
	for layout in 2:
		model.reset(false, layout)
		model.confirm_or_split()
		fill(model, 1.40)
		model.release_basket()
		advance(model, 34)
		samples.append(model.snapshot().cargo[0])
	check(samples[0].mass < samples[1].mass and samples[0].rise > samples[1].rise and samples[0].height > samples[1].height,
		"actual mass changes the movement of otherwise equally pumped bubbles")
	var before: float = samples[1].gas
	model.set_holds(0, true)
	advance(model, 12)
	check(model.snapshot().cargo[0].gas < before - 0.20, "the moving valve removes gas from the real carrier")

func _test_delivery() -> void:
	for layout in 2:
		for pair in [false, true]:
			var model := Model.new()
			model.reset(layout == 1, layout)
			if pair:
				model.choose_count(2)
				model.confirm_or_split()
				prepare_and_launch(model)
				model.confirm_or_split()
				check(model.snapshot().cargo.size() == 1, "early split never creates bonus carriers")
				wait_for_split(model)
				var before := model.snapshot()
				check(before.can_split, "charged pair reaches the actual purple fork")
				model.confirm_or_split()
				var after := model.snapshot()
				check(after.cargo.size() == 2 and after.trip_split, "fork creates two physical carriers")
				if after.cargo.size() == 2:
					var low: Dictionary = after.cargo[0]
					var high: Dictionary = after.cargo[1]
					check(low.lane == -1 and high.lane == 1 and (low.cargo & high.cargo) == 0 and (low.cargo | high.cargo) == before.loaded,
						"pair splits into distinct loads and active lanes")
					check(is_equal_approx(low.gas + high.gas, before.cargo[0].gas - Model.SPLIT_COST), "split conserves cargo and accounts for its gas cost")
					advance(model, 22)
					var moving: Array = model.snapshot().cargo
					check(moving.size() == 2 and moving[1].height > moving[0].height, "each lane advances under its own lift")
				wait_for_arrival(model)
				check(model.snapshot().delivered == 3 and model.snapshot().split_completed and not model.snapshot().ended,
					"two distinct arrivals earn the split condition, with one barrel still required")
			for trip in (1 if pair else 3):
				model.confirm_or_split()
				prepare_and_launch(model)
				wait_for_arrival(model)
			var result := model.snapshot()
			check(result.ended and result.success and result.delivered == Model.ALL_CARGO and result.ordinary_eligible,
				"each course accepts all three actual deliveries")
			check(result.devil == pair and result.score == (490 if pair else 390) and result.mistakes == 0,
				"ordinary and split routes keep separate scores")
			check(model.consume_notes() == [1, 2, 3] and model.consume_notes().is_empty(), "real arrivals alone emit bounded cues")

func _test_heat_and_recovery() -> void:
	for assist in [false, true]:
		var model := Model.new()
		model.reset(assist, 1)
		model.confirm_or_split()
		fill(model, model.snapshot().load_mass + 0.53)
		for tick in 230:
			if fposmod(model.snapshot().elapsed + 0.60, 3.75) < 0.05:
				break
			model.step(Model.TICK)
		model.release_basket()
		var thinned := false
		var returned := false
		for tick in 550:
			model.step(Model.TICK)
			var state := model.snapshot()
			if state.phase == Model.DOCK:
				break
			thinned = thinned or state.cargo[0].shell < 0.8
			returned = returned or state.cargo[0].returning
		var state := model.snapshot()
		check(thinned and state.mistakes == 1 and state.phase == Model.DOCK, "bad heat timing actually thins and fails the carrier")
		check(returned == assist and state.delivered == 0, "only assistance descends and neither loss credits cargo")
		model.confirm_or_split()
		check(model.snapshot().loaded == 1, "failed deliveries leave their cargo available to reload")
	var idle := Model.new()
	idle.reset(false, 0)
	for tick in 340:
		idle.step(0.25)
	check(idle.snapshot().ended and not idle.snapshot().ordinary_eligible, "waiting out the clock without leaving the dock earns no card")

func _test_pointer() -> void:
	var driver := Driver.new()
	driver.reset(true, "noon")
	var left := View.button_rect(View.PUMP_LEFT).get_center()
	var outside := Vector2(-40, -20)
	check(not driver.handle_input(touch(true), left), "unloaded pump is disabled under touch")
	driver.handle_input(touch(true), View.button_rect(View.CONFIRM).get_center())
	check(driver.handle_input(touch(true), left), "one finger can drive the physical left pump")
	for tick in 16:
		driver.step(Model.TICK)
	check(driver.snapshot().gas > 0.0 and driver.snapshot().pump_mask == Model.LEFT_PUMP, "touch produces charge")
	check(driver.handle_input(touch(false), outside) and driver.snapshot().pump_mask == 0, "release anywhere clears the owned pump")
	driver.handle_input(key(KEY_D, true), Vector2.ZERO)
	var cancelled := touch(false)
	cancelled.canceled = true
	driver.handle_input(cancelled, outside)
	check(driver.snapshot().pump_mask == 0, "pointer cancellation safely drops held inputs")

func _test_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.start("game-035")
	session._unhandled_input(key(KEY_E, true))
	session._unhandled_input(key(KEY_A, true))
	session._process(0.20)
	var gas: float = session._driver_state.gas
	session._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	session._process(0.20)
	check(session.paused and session.active_driver.snapshot().pump_mask == 0 and session.active_driver.snapshot().gas == gas,
		"window focus loss clears a held pump without changing pressure")
	session.set_paused(false)
	participate(session)
	for tick in 345:
		session._process(0.25)
	check(results.size() == 1 and results[0].ordinary_eligible and not results[0].success and not results[0].devil,
		"shared Session reports one honestly participated natural timeout")
	session.free()

static func participate(session: Control) -> void:
	session._unhandled_input(key(KEY_E, true))
	session._unhandled_input(key(KEY_E, false))
	session._unhandled_input(key(KEY_A, true))
	for tick in 6:
		session._process(0.10)
	session._unhandled_input(key(KEY_A, false))
	session._unhandled_input(key(KEY_SPACE, true))
	session._unhandled_input(key(KEY_SPACE, false))
	for tick in 22:
		session._process(0.10)

func prepare_and_launch(model: RefCounted) -> void:
	fill(model, model.snapshot().load_mass + 0.55)
	var saw_hot := false
	for tick in 480:
		var state: Dictionary = model.snapshot()
		if state.entry_cool and saw_hot:
			break
		saw_hot = saw_hot or not state.entry_cool
		model.step(Model.TICK)
	model.release_basket()

func fill(model: RefCounted, target: float) -> void:
	model.set_holds(Model.BOTH_PUMPS, false)
	for tick in 150:
		if model.snapshot().gas >= target:
			break
		model.step(Model.TICK)
	model.clear_input()

func wait_for_split(model: RefCounted) -> void:
	for tick in 350:
		if model.phase() != Model.TRANSIT or model.snapshot().can_split:
			return
		model.step(Model.TICK)

func wait_for_arrival(model: RefCounted) -> void:
	for tick in 550:
		if model.phase() != Model.TRANSIT:
			return
		model.step(Model.TICK)

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
