extends SceneTree

const Driver = preload("res://game/minigames/lantern_crossing_driver.gd")
const Model = preload("res://game/minigames/lantern_crossing_model.gd")
const View = preload("res://game/minigames/lantern_crossing_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _errors: Array[String] = []
var _driver := Driver.new()


func _initialize() -> void:
	_driver.reset(true, "night")
	var before := _driver.snapshot()
	var choose := _pad(JOY_BUTTON_DPAD_RIGHT, true)
	check(_driver.handle_input(choose, Vector2.ZERO), "controller chooses the right endpoint")
	_driver.handle_input(_pad(JOY_BUTTON_DPAD_RIGHT, false), Vector2.ZERO)
	check(_driver.snapshot().selected_endpoint == Model.RIGHT, "controller and keyboard share selected state")
	var button := KEY_W if int(before.height_right) < Model.MAX_HEIGHT else KEY_S
	var step_direction := 1 if button == KEY_W else -1
	_driver.handle_input(_key(button, true), Vector2.ZERO)
	_driver.handle_input(_key(button, true, true), Vector2.ZERO)
	_driver.handle_input(_key(button, true), Vector2.ZERO)
	var raised := _driver.snapshot()
	check(raised.height_right == int(before.height_right) + step_direction and raised.height_left == before.height_left,
		"held or echo adjustment changes only selected winch once")
	_driver.handle_input(_key(button, false), Vector2.ZERO)
	var point := Surface.button_rect(View.HELPER).get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	check(_driver.handle_input(touch, point) and _driver.snapshot().helper_endpoint == Model.LEFT,
		"single touch holds the opposite winch in assisted mode")
	var synthetic := InputEventMouseButton.new()
	synthetic.device = InputEvent.DEVICE_ID_EMULATION
	synthetic.pressed = true
	synthetic.button_index = MOUSE_BUTTON_LEFT
	check(not _driver.handle_input(synthetic, point), "touch emulation does not toggle helper twice")
	touch.canceled = true
	check(_driver.handle_input(touch, Vector2.ZERO), "owned touch cancellation clears sources")
	_driver.handle_input(_key(KEY_A, true), Vector2.ZERO)
	_driver.handle_input(_key(KEY_A, false), Vector2.ZERO)
	check(_driver.snapshot().selected_endpoint == Model.LEFT and _driver.snapshot().helper_endpoint == -1,
		"explicit selection returns control to the held end")
	_driver.reset(false, "night")
	_driver.handle_input(_key(KEY_H, true), Vector2.ZERO)
	_driver.handle_input(_key(KEY_H, false), Vector2.ZERO)
	check(_driver.snapshot().helper_endpoint == -1, "normal mode never changes an unavailable assistant")
	_verify_real_move()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: lantern crossing driver inputs, detents and release")
	quit(int(not _errors.is_empty()))


func _verify_real_move() -> void:
	var loaded := _driver.snapshot()
	var start: Vector2 = loaded.source
	var target: Vector2 = loaded.target
	var from := KEY_A if start.x < target.x else KEY_D
	var to := KEY_D if start.x < target.x else KEY_A
	_tap(KEY_E)
	check(_driver.snapshot().loaded, "real action takes the lamp")
	_tap(from)
	for step in 8:
		_tap(KEY_W)
	_tap(to)
	for step in 8:
		_tap(KEY_S)
	if not _driver.snapshot().braking:
		_tap(KEY_SPACE)
	var held: Vector2 = _driver.snapshot().trolley
	for step in 30:
		_driver.step(1.0 / 60.0)
	check(is_equal_approx(_driver.snapshot().trolley.x, held.x), "clamp retains cart position while adjusting winch")
	_driver.handle_input(_pad(JOY_BUTTON_X, true), Vector2.ZERO)
	_driver.handle_input(_pad(JOY_BUTTON_X, false), Vector2.ZERO)
	for step in 48:
		_driver.step(1.0 / 60.0)
	var moved: Vector2 = _driver.snapshot().trolley
	check((moved.x - held.x) * (target.x - start.x) > 0.02, "release moves real loaded cart down its cable")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	var retry := Surface.button_rect(View.RECOVER).get_center()
	check(_driver.handle_input(mouse, retry), "mouse selects retry")
	mouse.pressed = false
	_driver.handle_input(mouse, Vector2.ZERO)
	var state := _driver.snapshot()
	check(not state.stalled and state.hung == 0 and is_equal_approx(state.trolley.x, start.x), "retry returns only the active lamp")


func _tap(keycode: int) -> void:
	_driver.handle_input(_key(keycode, true), Vector2.ZERO)
	_driver.handle_input(_key(keycode, false), Vector2.ZERO)


func _key(keycode: int, down: bool, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = down
	event.echo = echo
	return event


func _pad(button: int, down: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = down
	return event


func check(ok: bool, failure: String) -> void:
	if not ok:
		_errors.append(failure)
