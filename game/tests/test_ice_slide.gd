extends SceneTree

const Model = preload("res://game/minigames/ice_slide_model.gd")
const View = preload("res://game/minigames/ice_slide_view.gd")
const Driver = preload("res://game/minigames/ice_slide_driver.gd")
const Session = preload("res://game/minigames/session.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

static func participate(session: Control) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_RIGHT if session._driver_state.layout == 0 else KEY_LEFT
	event.pressed = true
	session._unhandled_input(event)

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	var model := Model.new()
	for layout in 2:
		for assisted in [false, true]:
			for bonus in [false, true]:
				_play(model, layout, assisted, bonus)
	_check_open_routes(model)
	model.reset(false, 0)
	slide(model, Vector2i.RIGHT)
	_check(model.snapshot().ice[0] == Vector2i(8, 1) and model.snapshot().cooled == 1, "open ice crosses the mold before stopping on the boundary")
	slide(model, Vector2i.DOWN)
	_check(model.snapshot().ice[0] == Vector2i(8, 3) and model.snapshot().ice_stop, "moving ice is stopped by another block")
	model.reset(false, 0)
	advance(model, Model.ROUND_SECONDS - 0.03)
	model.push(Vector2i.RIGHT)
	advance(model, 0.25)
	_check(model.snapshot().ended and not model.snapshot().ordinary_eligible, "an input that cannot reach even one cell before timeout earns nothing")
	for assisted in [false, true]:
		model.reset(assisted, 0)
		place(model, Vector2i(6, 1))
		slide(model, Vector2i.RIGHT)
		slide(model, Vector2i.DOWN)
		advance(model, 10.0)
		var state := model.snapshot()
		_check(state.cooled == 2 and state.mistakes == int(not assisted)
			and state.ice[0] == (Vector2i(5, 4) if assisted else Vector2i(0, 1)), "melt only in regular mode, with cooled molds retained")
		if assisted:
			model.undo()
			var undone := model.snapshot()
			_check(undone.cooled == 1 and undone.ice[0] == Vector2i(5, 1) and undone.elapsed == state.elapsed and not undone.undo_available, "one undo restores progress, not time")
	_check_input()
	_check_session()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: ice slide routes, input, melt, undo and Session results")
	quit(0 if _failures.is_empty() else 1)

func _play(model: RefCounted, layout: int, assisted: bool, bonus: bool) -> void:
	model.reset(assisted, layout)
	model.toggle_helper()
	var direction := Vector2i.RIGHT if layout == 0 else Vector2i.LEFT
	place(model, Model.orient(Vector2i(6, 1), layout))
	_check(Model.orient(Model.MOLDS[0], layout) in model.snapshot().hints, "actual trace informs the helper stop")
	slide(model, direction)
	_check(model.snapshot().cooled == 1 and model.snapshot().ice[0] == Model.orient(Model.MOLDS[0], layout), "stopper halts at the first mold")
	slide(model, Vector2i.DOWN)
	_check(model.snapshot().cooled == 2 and model.snapshot().ice[0] == Model.orient(Model.MOLDS[1], layout), "warm tile stops on the second mold")
	if bonus:
		model.select_ice(1)
		slide(model, -direction)
		_check(model.snapshot().ice_stop and model.snapshot().ice[1] == Model.orient(Vector2i(6, 4), layout), "ice B slides and is stopped by ice A")
		slide(model, -direction)
		_check(model.snapshot().ice[1] == Model.orient(Vector2i(6, 4), layout), "adjacent blocked push does not move ice")
		model.select_ice(0)
	model.recall_stopper()
	_check(model.snapshot().stopper == Model.EMPTY, "the same stopper returns to inventory")
	place(model, Model.orient(Vector2i(1, 4), layout))
	slide(model, -direction)
	_check(model.snapshot().cooled == 3, "reused stopper controls a new approach")
	slide(model, Vector2i.DOWN if layout == 0 else Vector2i.UP)
	if layout == 1:
		_check(model.snapshot().cooled == 3 and model.snapshot().ice[0] == Vector2i(6, 2), "second layout warm tile interrupts the final approach")
		slide(model, Vector2i.UP)
	var result: Dictionary = model.snapshot()
	_check(result.ended and result.success and result.devil == bonus and result.ordinary_eligible and result.score == (620 if bonus else 520), "correct normal and optional bonus on both layouts")

func _check_input() -> void:
	var driver := Driver.new()
	driver.reset(true, "noon")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	_check(driver.handle_input(mouse, View.button_rect(5).get_center()), "mouse activates placement")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var cell := Vector2i(4, 3)
	var point := View.GRID.position + (Vector2(cell) + Vector2(0.5, 0.5)) * View.CELL
	_check(driver.handle_input(touch, point) and driver.snapshot().stopper == cell, "one finger places the physical obstacle")
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	_check(not driver.handle_input(mouse, View.button_rect(7).get_center()) and driver.snapshot().stopper == cell, "emulation cannot undo a touch")

func _check_open_routes(model: RefCounted) -> void:
	var routes := [
		[[0, Vector2i.RIGHT], [0, Vector2i.DOWN], [1, Vector2i.LEFT], [0, Vector2i.DOWN], [1, Vector2i.LEFT], [0, Vector2i.LEFT]],
		[[0, Vector2i.LEFT], [0, Vector2i.UP], [1, Vector2i.RIGHT], [1, Vector2i.RIGHT], [1, Vector2i.UP], [0, Vector2i.RIGHT]],
	]
	for layout in routes.size():
		model.reset(false, layout)
		for move in routes[layout]:
			model.select_ice(move[0])
			slide(model, move[1])
		var state: Dictionary = model.snapshot()
		_check(state.success and state.devil and state.stopper == Model.EMPTY, "both blocks can solve the layout through longer slides alone")

func _check_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	session.finished.connect(func(record: Dictionary): results.append(record))
	session.start("game-032")
	_check(session.active_driver is Driver, "canonical game opens the live driver")
	for tick in 361:
		session._process(0.25)
	_check(results.size() == 1 and not results[0].ordinary_eligible, "idle timeout is ineligible")
	session.start("game-032")
	participate(session)
	session.set_paused(true)
	var elapsed: float = session._driver_state.elapsed
	session._process(0.25)
	_check(session._driver_state.elapsed == elapsed, "real pause freezes motion and time")
	session.set_paused(false)
	for tick in 364:
		session._process(0.25)
	_check(results.size() == 2 and results[1].ordinary_eligible and not results[1].success and not results[1].devil, "timeout qualifies only after actual movement")
	session.start("game-032")
	session._leave_from_hud()
	_check(session.ended and results.size() == 2, "cancellation emits no result")
	session.free()

func place(model: RefCounted, cell: Vector2i) -> void:
	model.toggle_placement()
	model.choose_cell(cell)

func slide(model: RefCounted, direction: Vector2i) -> void:
	model.push(direction)
	advance(model, 1.0)

func advance(model: RefCounted, seconds: float) -> void:
	for tick in roundi(seconds * 100):
		model.step(0.01)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
