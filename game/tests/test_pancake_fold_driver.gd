extends SceneTree

const Driver = preload("res://game/minigames/pancake_fold_driver.gd")
const Model = preload("res://game/minigames/pancake_fold_model.gd")
const View = preload("res://game/minigames/pancake_fold_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _driver := Driver.new()
var _errors: Array[String] = []


func _initialize() -> void:
	_driver.reset(false, "night")
	_axes_and_switch()
	_metered_pour()
	_pointer_and_pad()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: pancake fold driver tool handoff and metered inputs")
	quit(int(not _errors.is_empty()))


func _axes_and_switch() -> void:
	_key(KEY_D, true)
	_step(12)
	var held := _driver.snapshot()
	var origin: Vector2 = held.cursor
	_check(_driver.snapshot().tilt.x > 0.25 and origin.is_zero_approx(), "direction physically tilts pan without moving ladle")
	_key(KEY_Q, true)
	_step(12)
	_check(_driver.snapshot().tool == Model.LADLE and _driver.snapshot().cursor == origin
		and _driver.snapshot().direction_mask == 0, "switching tools drops previously held direction")
	_check(held.direction_mask & (1 << View.EAST) != 0, "tool switch preserves the previously published snapshot")
	_key(KEY_Q, true, true)
	_check(_driver.snapshot().tool == Model.LADLE, "tool-switch keyboard echo is ignored")
	_key(KEY_Q, false)
	_key(KEY_D, false)
	_key(KEY_D, true)
	_step(12)
	_key(KEY_D, false)
	_check(_driver.snapshot().cursor.x > 1.0, "fresh input physically moves the ladle in the current tool")


func _metered_pour() -> void:
	var original: float = _driver.snapshot().stock
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, true, true)
	_key(KEY_SPACE, true)
	_step(18)
	_check(_driver.snapshot().poured == 1 and is_equal_approx(_driver.snapshot().stock, original - Model.POUR_MASS)
		and _driver.snapshot().engaged, "one held pour adds exactly one physical dose")
	_key(KEY_SPACE, false)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(_driver.snapshot().poured == 2, "a fresh physical press adds a second dose")


func _pointer_and_pad() -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 6
	touch.pressed = true
	var center := Surface.button_rect(View.WEST).get_center()
	_check(_driver.handle_input(touch, center), "touch hold begins over the actual movement button")
	_step(14)
	var before_cancel: Vector2 = _driver.snapshot().cursor
	touch.canceled = true
	_check(_driver.handle_input(touch, Vector2.ZERO), "off-button touch cancellation reports handled")
	_step(12)
	_check(_driver.snapshot().cursor == before_cancel and _driver.snapshot().direction_mask == 0,
		"cancellation drops cursor movement")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	_check(not _driver.handle_input(emulated, center), "emulated mouse does not duplicate a real pointer")
	var pad := InputEventJoypadButton.new()
	pad.device = 4
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	_driver.handle_input(pad, Vector2.ZERO)
	pad.pressed = false
	_driver.handle_input(pad, Vector2.ZERO)
	_check(_driver.snapshot().tool == Model.TILT, "real pad input switches the tool")


func _step(count: int) -> void:
	for tick in count:
		_driver.step(Model.TICK)


func _key(code: int, down: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	_driver.handle_input(event, Vector2.ZERO)


func _check(condition: bool, error: String) -> void:
	if not condition:
		_errors.append(error)
