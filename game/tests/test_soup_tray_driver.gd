extends SceneTree

const Driver = preload("res://game/minigames/soup_tray_driver.gd")
const Model = preload("res://game/minigames/soup_tray_model.gd")
const View = preload("res://game/minigames/soup_tray_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _driver := Driver.new()
var _issues: Array[String] = []


func _initialize() -> void:
	_check_held_sources()
	_check_route_and_lean()
	_check_gap_resume()
	_check_held_return()
	for issue in _issues:
		push_error(issue)
	if _issues.is_empty():
		print("PASS: soup tray driver controls and gap approach")
	quit(int(not _issues.is_empty()))


func _check_held_sources() -> void:
	_driver.reset(false, "night")
	_key(KEY_W, true)
	_pad(JOY_BUTTON_LEFT_SHOULDER, true)
	var finger := _touch(4, true)
	_expect(_driver.handle_input(finger, Surface.button_rect(View.BRAKE).get_center()), "real brake slot takes an independent touch")
	_step(45)
	var careful := _driver.snapshot()
	_expect(is_equal_approx(careful.speed, Model.CAREFUL_SPEED) and careful.participated, "walk and touch brake have a real careful pace")
	_key(KEY_W, false)
	_step(20)
	_expect(is_equal_approx(_driver.snapshot().speed, Model.CAREFUL_SPEED), "releasing keyboard cannot release held controller walk")
	finger.pressed = false
	_expect(_driver.handle_input(finger, Vector2(-15, -22)), "owned touch release is accepted outside the control")
	_step(15)
	_expect(_driver.snapshot().speed > Model.CAREFUL_SPEED, "releasing brake while walking resumes normal acceleration")
	var lean := _touch(6, true)
	_expect(_driver.handle_input(lean, Surface.button_rect(View.LEAN_RIGHT).get_center()), "another finger owns its lean")
	lean.canceled = true
	_expect(_driver.handle_input(lean, Vector2.ZERO) and _driver.snapshot().control_mask == 0, "cancel clears every held source")
	_step(62)
	_expect(_driver.snapshot().speed == 0.0 and careful.speed == Model.CAREFUL_SPEED, "coast ends and old published state stays stable")


func _check_route_and_lean() -> void:
	_driver.reset(false, "night")
	_expect(_driver.snapshot().route == Model.SAFE, "new bowl begins on the safer path")
	_pad(JOY_BUTTON_X, true)
	_pad(JOY_BUTTON_X, true)
	_expect(_driver.snapshot().route == Model.CHANNEL, "repeated controller press switches the route exactly once")
	_pad(JOY_BUTTON_X, false)
	_key(KEY_A, true)
	_key(KEY_A, false)
	_expect(_driver.snapshot().route == Model.SAFE, "keyboard explicitly selects the safer route before leaving")
	_key(KEY_UP, true)
	_step(6)
	_expect(_driver.snapshot().lean.y > 0.0 and _driver.snapshot().liquid_slope.y > 0.0, "forward arrow physically tilts toward the far lip")
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	_step(9)
	_expect(_driver.snapshot().lean.y == 0.0, "opposing sources cancel without losing either input")
	_key(KEY_UP, false)
	_step(10)
	_expect(_driver.snapshot().lean.y < 0.0 and not _driver.snapshot().participated, "opposite hold resumes, stationary tilt does not earn a card")
	_driver.clear_input()


func _check_gap_resume() -> void:
	_driver.reset(true, "night")
	_key(KEY_D, true)
	_key(KEY_D, false)
	_key(KEY_SPACE, true)
	_key(KEY_W, true)
	var state := _driver.snapshot()
	for _tick in 1100:
		state = _driver.step(Model.TICK)
		if state.stage == Model.GAP:
			break
	_expect(state.stage == Model.GAP and state.path_position < state.gap.near_progress, "actual movement enters the edge approach with distance still available")
	_key(KEY_W, false)
	_step(25)
	var stopped := _driver.snapshot()
	_key(KEY_E, true)
	_key(KEY_E, false)
	_expect(not _driver.snapshot().airborne and stopped.lean == Vector2.ZERO, "a stopped level tray cannot fly")
	_key(KEY_W, true)
	_step(34)
	_key(KEY_W, false)
	_key(KEY_SPACE, false)
	_step(36)
	state = _driver.snapshot()
	_expect(not state.airborne and not state.crossed and absf(state.path_position - state.gap.near_progress) < 0.0001,
		"fresh walk resumes the short approach while the physical lip blocks ground crossing")


func _check_held_return() -> void:
	_key(KEY_E, true)
	_step(25)
	_expect(_driver.snapshot().slide_held and not _driver.snapshot().airborne, "held slide cannot make a flat tray cross")
	_key(KEY_E, false)
	_expect(not _driver.snapshot().slide_held and not _driver.snapshot().airborne, "releasing a hold before the physical window cancels it")
	_key(KEY_E, true)
	_key(KEY_DOWN, true)
	_step(6)
	_driver.clear_input()
	_step(25)
	_expect(not _driver.snapshot().slide_held and not _driver.snapshot().airborne, "suspension cancels prepared slide")
	_step(58)
	_key(KEY_E, true)
	_key(KEY_DOWN, true)
	_step(8)
	_key(KEY_DOWN, false)
	_key(KEY_UP, true)
	for _tick in 24:
		_step(1)
		if _driver.snapshot().airborne:
			break
	var launched := _driver.snapshot()
	_expect(launched.airborne and launched.launch_return and not launched.slide_held,
		"held slide fires only at the genuine return crest and releases steering")
	_key(KEY_E, false)
	_step(45)
	_expect(_driver.snapshot().crossed and _driver.snapshot().crossing_proven,
		"real unsupported flight and catch still decide whether to grant proof")


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	_driver.handle_input(event, Vector2.ZERO)


func _pad(code: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.button_index = code
	event.pressed = pressed
	_driver.handle_input(event, Vector2.ZERO)


func _touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event


func _step(ticks: int) -> void:
	for _tick in ticks:
		_driver.step(Model.TICK)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_issues.append(message)
