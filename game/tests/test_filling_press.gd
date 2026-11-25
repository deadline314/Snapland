extends SceneTree

const Model = preload("res://game/minigames/filling_press_model.gd")
const Driver = preload("res://game/minigames/filling_press_driver.gd")
const View = preload("res://game/minigames/filling_press_view.gd")
const Session = preload("res://game/minigames/session.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_test_recipes()
	_test_timing_and_cancel()
	_test_driver_input()
	_test_session_result()
	for message in _failures:
		push_error(message)
	if _failures.is_empty():
		print("PASS: filling press timing, rebound, controls and results")
	quit(int(not _failures.is_empty()))

func _test_recipes() -> void:
	for layout in 2:
		var model := Model.new()
		model.reset(layout == 1, layout)
		var recipe: Array = [1, 2, 1] if layout == 0 else [2, 1, 2]
		check(model.snapshot().recipe == recipe, "different recipes have different layer orders")
		for index in recipe.size():
			var cue := model.snapshot()
			advance_model(model, cue.start)
			model.set_pressed(Model.BOTH)
			advance_model(model, cue.target)
			model.set_pressed(0)
			var sealed := model.snapshot()
			check(sealed.phase == Model.REBOUND and sealed.layers.size() == index + 1, "release seals the corresponding layer")
			if sealed.layers.size() == index + 1:
				check(is_equal_approx(sealed.layers[index], cue.beat * recipe[index]), "layer measures actual physical hold duration")
			advance_model(model, sealed.target)
			if layout == 1:
				var side := Model.RIGHT if sealed.offset > 0.0 else Model.LEFT
				model.set_pressed(side)
				model.set_pressed(0)
				check(absf(model.snapshot().offset) <= Model.CENTER_LIMIT, "correct single side moves the filling to the physical center")
			advance_model(model, sealed.target + sealed.window + 0.025)
			if index < recipe.size() - 1:
				advance_model(model, sealed.beat + 0.025)
		var result := model.snapshot()
		check(result.ended and result.success and result.ordinary_eligible, "all three layers finish one formal round")
		check(result.devil == (layout == 1) and result.score == (520 if layout == 1 else 420), "bonus is optional for ordinary success and affects score")

func _test_timing_and_cancel() -> void:
	var model := Model.new()
	model.reset(false, 0)
	model.set_pressed(Model.BOTH)
	check(model.snapshot().phase == Model.REST and model.snapshot().mistakes == 1, "empty beat rejects an early chord")
	model.set_pressed(0)
	advance_model(model, 0.65)
	var cue := model.snapshot()
	advance_model(model, cue.start - 0.12)
	model.set_pressed(Model.LEFT)
	advance_model(model, cue.start + 0.10)
	model.set_pressed(Model.BOTH)
	advance_model(model, cue.target)
	model.set_pressed(0)
	check(model.snapshot().layers.is_empty() and model.snapshot().mistakes == 2, "two individually timely sides still require synchronization")
	advance_model(model, 0.65)
	cue = model.snapshot()
	advance_model(model, cue.start)
	model.set_pressed(Model.BOTH)
	advance_model(model, cue.start + 0.20)
	model.set_pressed(0)
	check(model.snapshot().layers.is_empty() and model.snapshot().mistakes == 3, "short release spills before the required duration")
	advance_model(model, 0.65)
	cue = model.snapshot()
	advance_model(model, cue.start)
	model.set_pressed(Model.BOTH)
	advance_model(model, cue.target + 0.15)
	check(model.snapshot().layers.is_empty() and model.snapshot().mistakes == 4, "overholding fails when the release window closes")
	model.clear_input()
	advance_model(model, 0.65)
	cue = model.snapshot()
	advance_model(model, cue.start)
	model.set_pressed(Model.BOTH)
	var elapsed: float = model.snapshot().elapsed
	model.clear_input()
	check(model.snapshot().held == 0 and model.snapshot().clock == 0.0 and model.snapshot().elapsed == elapsed, "focus cancellation clears a half-finished layer without rewinding the round")
	cue = model.snapshot()
	advance_model(model, cue.start)
	model.set_pressed(Model.BOTH)
	advance_model(model, cue.target)
	model.set_pressed(0)
	advance_model(model, cue.beat)
	var offset: float = model.snapshot().offset
	model.set_pressed(Model.LEFT)
	model.set_pressed(0)
	model.set_pressed(Model.RIGHT)
	check(absf(model.snapshot().offset) > absf(offset) and not model.snapshot().centered, "wrong-side contact worsens the offset and cannot be retried on the same beat")
	model.reset(false, 0)
	for tick in 310:
		model.step(0.25)
	check(model.snapshot().ended and not model.snapshot().ordinary_eligible and model.snapshot().remaining == 0.0, "idle timeout cannot record participation")

func _test_driver_input() -> void:
	var driver := Driver.new()
	driver.reset(false, "noon")
	advance_driver(driver, driver.snapshot().start)
	var left := View.button_rect(0).get_center()
	var right := View.button_rect(2).get_center()
	check(driver.handle_input(touch(0, true), left) and driver.handle_input(touch(1, true), right), "two fingers own separate hitboxes")
	check(driver.snapshot().held == Model.BOTH, "two contact sources really close both molds")
	advance_driver(driver, driver.snapshot().target)
	var outside := Vector2(-30, -30)
	check(driver.handle_input(touch(0, false), outside) and driver.snapshot().held == Model.RIGHT, "release outside clears only the pointer that owned that mold")
	check(driver.handle_input(touch(1, false), outside) and driver.snapshot().layers.size() == 1, "outside releases seal at the actual release time")
	driver.reset(true, "noon")
	driver.handle_input(key(KEY_R, true), Vector2.ZERO)
	advance_driver(driver, driver.snapshot().start)
	driver.handle_input(touch(0, true), left)
	driver.handle_input(touch(0, false), left)
	check(driver.snapshot().held == Model.BOTH, "single assisted tap latches the left mold and AI supplies its pair")
	advance_driver(driver, driver.snapshot().target)
	driver.handle_input(touch(0, true), left)
	driver.handle_input(touch(0, false), left)
	check(driver.snapshot().held == 0 and driver.snapshot().layers.size() == 1, "same tap releases both at the visual cue")
	driver.reset(true, "noon")
	driver.handle_input(key(KEY_SPACE, true), Vector2.ZERO)
	advance_driver(driver, driver.snapshot().beat + 0.015)
	check(driver.snapshot().phase == Model.PRESS and driver.snapshot().held == 0, "early assisted tap never leaves a stuck latch")
	advance_driver(driver, driver.snapshot().start)
	driver.handle_input(touch(0, true), View.button_rect(1).get_center())
	var cancelled := touch(0, false)
	cancelled.canceled = true
	driver.handle_input(cancelled, outside)
	check(driver.snapshot().held == 0 and driver.snapshot().clock == 0.0, "cancelled touch drops its latch without treating it as a release")

func _test_session_result() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.start("game-033")
	participate(session)
	for tick in 310:
		session._process(0.25)
	check(results.size() == 1 and results[0].ordinary_eligible and not results[0].success and not results[0].devil, "only natural finish records an honest participated result")
	session.free()

static func participate(session: Control) -> void:
	for tick in roundi(session._driver_state.start * 100.0):
		session._process(0.01)
	session._unhandled_input(key(KEY_SPACE, true))
	session._process(0.20)
	session._unhandled_input(key(KEY_SPACE, false))

static func key(code: int, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	return event

func touch(index: int, down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	return event

func advance_model(model: RefCounted, target: float) -> void:
	var remaining: float = target - model.snapshot().clock
	while remaining > 0.000001:
		var step := minf(remaining, 0.01)
		remaining -= step
		model.step(step)

func advance_driver(driver: RefCounted, target: float) -> void:
	var remaining: float = target - driver.snapshot().clock
	while remaining > 0.000001:
		var step := minf(remaining, 0.01)
		remaining -= step
		driver.step(step)

func check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
