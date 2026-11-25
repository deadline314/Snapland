extends SceneTree

const Driver = preload("res://game/minigames/umbrella_lights_driver.gd")
const Model = preload("res://game/minigames/umbrella_lights_model.gd")
const View = preload("res://game/minigames/umbrella_lights_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _driver := Driver.new()
var _errors: Array[String] = []


func _initialize() -> void:
	_drive_and_suspend()
	_brake_turn()
	_detent_once()
	_touch_cancel()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: umbrella lights driver brake and detent controls")
	quit(int(not _errors.is_empty()))


func _drive_and_suspend() -> void:
	_driver.reset(false, "night")
	_tap(KEY_F)
	_check(not _driver.snapshot().detent_mode, "normal controls never activate assisted detents")
	var start: float = _driver.snapshot().angle
	_key(KEY_A, true)
	_key(KEY_LEFT, true)
	_step(18)
	var held := _driver.snapshot()
	_check(angle_difference(start, held.angle) < -0.12 and held.velocity < 0.0, "held keyboard turns actual umbrella angle")
	_key(KEY_A, false)
	_step(12)
	_check(angle_difference(held.angle, _driver.snapshot().angle) < -0.1, "keyboard alias retains independent rotation ownership")
	_driver.clear_input()
	var stopped: float = _driver.snapshot().angle
	_step(10)
	_check(is_equal_approx(stopped, _driver.snapshot().angle) and _driver.snapshot().control_mask == 0,
		"explicit suspension halts motion")
	_check((held.control_mask & (1 << View.LEFT)) != 0, "new input never alters a prior published snapshot")


func _brake_turn() -> void:
	_driver.reset(false, "night")
	_key(KEY_D, true)
	_step(19)
	var driven: float = _driver.snapshot().velocity
	var brake := InputEventJoypadButton.new()
	brake.device = 5
	brake.button_index = JOY_BUTTON_A
	brake.pressed = true
	_driver.handle_input(brake, Vector2.ZERO)
	_step(21)
	_check(driven > 0.4 and _driver.snapshot().braking and absf(_driver.snapshot().velocity) < 0.02,
		"controller brake decelerates against held rotation")
	brake.pressed = false
	_driver.handle_input(brake, Vector2.ZERO)
	_step(15)
	_check(_driver.snapshot().velocity > 0.3, "releasing brake returns the held rotation")
	_driver.clear_input()


func _detent_once() -> void:
	_driver.reset(true, "night")
	_key(KEY_A, true)
	_step(8)
	_tap(KEY_F)
	_check(_driver.snapshot().detent_mode and (_driver.snapshot().control_mask & (1 << View.LEFT)) == 0,
		"assisted detent mode drops prior motion ownership")
	_key(KEY_A, false)
	_step(30)
	var start: float = _driver.snapshot().angle
	_key(KEY_D, true)
	_key(KEY_D, true)
	_key(KEY_D, true, true)
	_step(45)
	_check(is_equal_approx(angle_difference(start, _driver.snapshot().angle), Model.DETENT_ANGLE),
		"one held press moves through one real angular detent")
	_key(KEY_D, false)
	_tap(KEY_D)
	_step(35)
	_check(is_equal_approx(angle_difference(start, _driver.snapshot().angle), Model.DETENT_ANGLE * 2.0),
		"a fresh press advances a second angular detent")


func _touch_cancel() -> void:
	_driver.reset(false, "night")
	var event := InputEventScreenTouch.new()
	event.index = 5
	event.pressed = true
	var center := Surface.button_rect(View.RIGHT).get_center()
	_check(_driver.handle_input(event, center), "touch hold begins at the real right-hand control")
	_step(15)
	var current: float = _driver.snapshot().angle
	event.canceled = true
	_check(_driver.handle_input(event, Vector2.ZERO), "out-of-bounds pointer cancellation consumes the owned hold")
	_step(25)
	_check(is_equal_approx(current, _driver.snapshot().angle), "cancelled pointer does not continue physical rotation")


func _tap(code: int) -> void:
	_key(code, true)
	_key(code, false)


func _key(code: int, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_driver.handle_input(event, Vector2.ZERO)


func _step(count: int) -> void:
	for tick in count:
		_driver.step(Model.TICK)


func _check(condition: bool, issue: String) -> void:
	if not condition:
		_errors.append(issue)
