extends SceneTree

const Driver = preload("res://game/minigames/coin_bank_shot_driver.gd")
const Model = preload("res://game/minigames/coin_bank_shot_model.gd")
const View = preload("res://game/minigames/coin_bank_shot_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")

var _driver := Driver.new()
var _errors: Array[String] = []


func _initialize() -> void:
	_driver.reset(true, "night")
	var previous: int = _driver.snapshot().aim_degrees
	_driver.handle_input(_key(KEY_D, true), Vector2.ZERO)
	_driver.handle_input(_key(KEY_D, true, true), Vector2.ZERO)
	_driver.handle_input(_key(KEY_D, true), Vector2.ZERO)
	check(_driver.snapshot().aim_degrees == previous + 1, "echo and duplicate press do not bypass the first repeat delay")
	_driver.step(0.14)
	check(_driver.snapshot().aim_degrees == previous + 1, "short aim tap stays single")
	_driver.step(0.15)
	check(_driver.snapshot().aim_degrees == previous + 2, "held aim repeats after the delay")
	_tap(KEY_F)
	var changed: Dictionary = _driver.snapshot()
	check(changed.selected == Model.BOARD_A, "selector starts with the first board")
	for index in 10:
		_driver.step(0.07)
	check(_driver.snapshot().boards[0].detent == changed.boards[0].detent,
		"pre-existing aim hold does not adjust the new selection")
	_driver.handle_input(_key(KEY_D, false), Vector2.ZERO)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	_driver.handle_input(pad, Vector2.ZERO)
	pad.pressed = false
	_driver.handle_input(pad, Vector2.ZERO)
	check(_driver.snapshot().boards[0].placed and not _driver.snapshot().boards[1].placed,
		"controller toggles only the selected board")
	_touch_repeat()
	_shot_press()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: coin bank shot driver input cadence and release")
	quit(int(not _errors.is_empty()))


func _touch_repeat() -> void:
	var centre := Surface.button_rect(View.POWER_UP).get_center()
	var event := InputEventScreenTouch.new()
	event.index = 8
	event.pressed = true
	var power: int = _driver.snapshot().power
	check(_driver.handle_input(event, centre) and _driver.snapshot().power == power + 1, "touch adjusts power by one detent")
	var emulation := InputEventMouseButton.new()
	emulation.device = InputEvent.DEVICE_ID_EMULATION
	emulation.button_index = MOUSE_BUTTON_LEFT
	emulation.pressed = true
	check(not _driver.handle_input(emulation, centre), "touch-generated mouse input is ignored")
	event.canceled = true
	check(_driver.handle_input(event, Vector2.ZERO), "touch cancellation releases the repeat source")
	for index in 10:
		_driver.step(0.07)
	check(_driver.snapshot().power == power + 1, "cancelled touch never repeats")


func _shot_press() -> void:
	_driver.reset(false, "night")
	_driver.handle_input(_key(KEY_SPACE, true), Vector2.ZERO)
	check(_driver.snapshot().active and _driver.snapshot().shots == 1, "shot uses actual physics and consumes one coin")
	for tick in 1200:
		_driver.step(1.0 / 120.0)
		if not _driver.snapshot().active:
			break
	check(not _driver.snapshot().active and _driver.snapshot().shots == 1, "holding shot through settling spends no new coin")
	_driver.handle_input(_key(KEY_SPACE, true), Vector2.ZERO)
	check(_driver.snapshot().shots == 1, "press must be released between shots")
	_driver.handle_input(_key(KEY_SPACE, false), Vector2.ZERO)
	_tap(KEY_SPACE)
	check(_driver.snapshot().shots == 2, "fresh press can start the next attempt")
	_driver.clear_input()


func _tap(code: int) -> void:
	_driver.handle_input(_key(code, true), Vector2.ZERO)
	_driver.handle_input(_key(code, false), Vector2.ZERO)


func _key(code: int, pressed: bool, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func check(ok: bool, message: String) -> void:
	if not ok:
		_errors.append(message)
