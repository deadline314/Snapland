extends SceneTree

const Driver = preload("res://game/minigames/scent_trail_driver.gd")
const Model = preload("res://game/minigames/scent_trail_model.gd")
const View = preload("res://game/minigames/scent_trail_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _driver := Driver.new()
var _failures: Array[String] = []


func _initialize() -> void:
	_driver.reset(false, "night")
	var spawn: Vector2 = _driver.snapshot().player
	_key(KEY_W, true)
	_key(KEY_UP, true)
	_driver.step(0.20)
	_check(is_equal_approx(_driver.snapshot().player.y, spawn.y - 0.60), "duplicate direction doesn't multiply speed")
	_key(KEY_W, false)
	_driver.step(0.20)
	_check(is_equal_approx(_driver.snapshot().player.y, spawn.y - 1.20), "remaining keyboard source owns north")
	_key(KEY_S, true)
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx(), "opposite directions cancel")
	_key(KEY_UP, false)
	_driver.step(0.20)
	_check(is_equal_approx(_driver.snapshot().player.y, spawn.y - 0.60), "release restores the opposite held direction")
	_driver.clear_input()
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx() and _driver.snapshot().move_mask == 0, "explicit suspension drops key ownership")
	_check_stick()
	_check_pointer()
	_check_commands()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: scent trail driver movement ownership and input release")
	quit(int(not _failures.is_empty()))


func _check_stick() -> void:
	_driver.reset(false, "night")
	_stick(-0.16)
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx(), "small analog drift is ignored")
	_stick(-0.72)
	_driver.step(0.20)
	var speed: float = _driver.snapshot().velocity.length()
	_check(speed > 1.75 and speed < 2.1, "left stick scales walking speed above the deadzone")
	_stick(0.0)
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx(), "centered stick stops walking")
	_stick(-1.0)
	_driver.clear_input()
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx(), "suspension also clears analog ownership")


func _check_pointer() -> void:
	_driver.reset(false, "night")
	var event := InputEventScreenTouch.new()
	event.index = 3
	event.pressed = true
	var center := Surface.button_rect(View.MOVE_NORTH).get_center()
	_check(_driver.handle_input(event, center), "touch movement begins on the actual hit slot")
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.y < -2.95, "held touch moves through the corridor")
	event.pressed = false
	_check(_driver.handle_input(event, Vector2.ZERO), "release outside the hit slot is consumed")
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx(), "release outside the button stops walking")
	event.pressed = true
	_driver.handle_input(event, center)
	event.canceled = true
	_check(_driver.handle_input(event, Vector2.ZERO), "touch cancellation clears held controls")
	_driver.step(0.20)
	_check(_driver.snapshot().velocity.is_zero_approx(), "cancelled touch never resumes motion")


func _check_commands() -> void:
	_driver.reset(false, "night")
	_key(KEY_E, true)
	_key(KEY_E, true, true)
	_key(KEY_E, true)
	_driver.step(0.25)
	_check(_driver.snapshot().sampler_turn == 1, "sampler rotation takes exactly one octant for a held input")
	_key(KEY_E, false)
	_key(KEY_Q, true)
	_key(KEY_Q, false)
	_check(_driver.snapshot().sampler_turn == 0, "opposite sampler input returns to initial heading")
	var gamepad := InputEventJoypadButton.new()
	gamepad.device = 8
	gamepad.button_index = JOY_BUTTON_X
	gamepad.pressed = true
	_driver.handle_input(gamepad, Vector2.ZERO)
	_driver.handle_input(gamepad, Vector2.ZERO)
	_check(_driver.snapshot().filter == Model.TEA, "one physical controller press cycles exactly one filter")
	gamepad.pressed = false
	_driver.handle_input(gamepad, Vector2.ZERO)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(_driver.snapshot().sampled_mask == 1 << Model.TEA and _driver.consume_notes().size() == 1,
		"context key establishes real focused participation")


func _key(code: int, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_driver.handle_input(event, Vector2.ZERO)


func _stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 8
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	_driver.handle_input(event, Vector2.ZERO)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
