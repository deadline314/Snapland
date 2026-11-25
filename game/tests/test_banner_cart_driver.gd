extends SceneTree

const Driver = preload("res://game/minigames/banner_cart_driver.gd")
const Model = preload("res://game/minigames/banner_cart_model.gd")
const View = preload("res://game/minigames/banner_cart_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _driver := Driver.new()
var _failures: Array[String] = []


func _initialize() -> void:
	_driver.reset(false, "night")
	_key(KEY_W, true)
	_key(KEY_UP, true)
	_step(27)
	var began: float = _driver.snapshot().cart.z
	_check(began > 0.25 and _driver.snapshot().engaged, "ordinary eligibility requires actual cart travel")
	_key(KEY_W, false)
	_step(12)
	_check(_driver.snapshot().cart.z > began + 0.25, "releasing one keyboard alias preserves the other held source")
	_key(KEY_SPACE, true)
	_step(32)
	_check(_driver.snapshot().braking and is_zero_approx(_driver.snapshot().speed), "brake overrides held throttle")
	_key(KEY_SPACE, false)
	_step(16)
	_check(_driver.snapshot().speed > 0.3, "releasing brake lets the held throttle resume")
	_driver.clear_input()
	_step(15)
	_check(_driver.snapshot().control_mask == 0 and is_zero_approx(_driver.snapshot().speed), "suspension clears held movement and momentum")
	_pose_controls()
	_route_choice()
	_touch_release()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: banner cart driver held controls and safe release")
	quit(int(not _failures.is_empty()))


func _pose_controls() -> void:
	_driver.reset(true, "night")
	var lift: float = _driver.snapshot().lift
	_key(KEY_F, true)
	_key(KEY_R, true)
	_step(12)
	_check(is_equal_approx(_driver.snapshot().lift, lift), "opposed lift inputs cancel without movement")
	_key(KEY_R, false)
	_step(12)
	_check(_driver.snapshot().lift < lift - 0.12, "released lift source leaves the other axis active")
	_driver.clear_input()
	var pad := InputEventJoypadButton.new()
	pad.device = 9
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	pad.pressed = true
	_driver.handle_input(pad, Vector2.ZERO)
	_step(13)
	var roll: float = _driver.snapshot().roll
	_check(roll > 0.20, "physical shoulder input raises the cart's right side")
	pad.pressed = false
	_driver.handle_input(pad, Vector2.ZERO)
	_step(14)
	_check(is_equal_approx(_driver.snapshot().roll, roll), "returning the shoulder holds the current cloth pose")


func _route_choice() -> void:
	_driver.reset(false, "night")
	_key(KEY_A, true)
	_key(KEY_A, false)
	_check(_driver.snapshot().route == Model.DIRECT, "near lane is chosen before the actual fork")
	_key(KEY_W, true)
	for tick in 180:
		_step(1)
		if _driver.snapshot().route_locked:
			break
	_key(KEY_W, false)
	_key(KEY_D, true)
	_key(KEY_D, false)
	_check(_driver.snapshot().route_locked and _driver.snapshot().route == Model.DIRECT, "the other route only works before the physical fork")


func _touch_release() -> void:
	_driver.reset(false, "night")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	var held := Surface.button_rect(View.DRIVE).get_center()
	_check(_driver.handle_input(touch, held), "actual drive button starts a pointer-owned hold")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.pressed = true
	emulated.button_index = MOUSE_BUTTON_LEFT
	_check(not _driver.handle_input(emulated, held), "emulated touch mouse input never adds an owner")
	_step(27)
	touch.canceled = true
	_check(_driver.handle_input(touch, Vector2.ZERO), "cancelled touch is consumed even outside the button")
	var stop: float = _driver.snapshot().cart.z
	_step(18)
	_check(is_equal_approx(_driver.snapshot().cart.z, stop) and _driver.snapshot().control_mask == 0,
		"cancelled pointer clears input and the cart stops")


func _step(count: int) -> void:
	for tick in count:
		_driver.step(Model.TICK)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	_driver.handle_input(event, Vector2.ZERO)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
