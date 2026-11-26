extends SceneTree

const Driver = preload("res://game/minigames/sugar_lantern_driver.gd")
const View = preload("res://game/minigames/sugar_lantern_view.gd")

const MOVES := [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
const BODY := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [0, 4], [0, 7]]

var _driver := Driver.new()
var _errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for _layout in range(2):
		_driver.reset(false, "night")
		_check_keyboard_board()
		_check_lift_ownership()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: sugar lantern pointer, keyboard reach and shared lift hold")
	quit(int(not _errors.is_empty()))


func _check_keyboard_board() -> void:
	var reached := {0: true}
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var origin: int = pending.pop_back()
		for key in MOVES:
			_focus_with_pointer(origin)
			_tap_key(key)
			var next: int = _driver.snapshot().focus
			if not reached.has(next):
				reached[next] = true
				pending.append(next)
	_expect(reached.size() == _driver.snapshot().pegs.size(), "every peg is physically reachable by directional selection")
	_expect(_driver.snapshot().edges.is_empty(), "focus, anchors and cancelling a peg never create a sugar strand")


func _check_lift_ownership() -> void:
	_focus_with_pointer(0)
	for connection in BODY:
		var start: int = connection[0]
		var finish: int = connection[1]
		var anchor: int = _driver.snapshot().anchor
		if anchor != start:
			if anchor >= 0:
				_click_peg(anchor)
			_click_peg(start)
		_click_peg(finish)
	_expect(_driver.snapshot().edges.size() == BODY.size(), "the actual hit map places a stable body")
	_step(135)
	_expect(_driver.snapshot().wet == 0, "the actual joins finish setting")
	_key(KEY_SPACE, true)
	_pad_lift(true)
	_key(KEY_SPACE, false)
	_step(40)
	var held := _driver.snapshot()
	_expect(held.lifting and held.lift_height > 0.25, "releasing keyboard leaves the independent gamepad lift held")
	_driver.clear_input()
	_expect(not _driver.snapshot().lifting and not _driver.snapshot().lift_held and not _driver.snapshot().success,
		"focus clears and returns the frame to the bench safely")
	_expect(held.lifting and _driver.snapshot().edges.size() == BODY.size(),
		"returning to the bench preserves joints and previously published state")


func _focus_with_pointer(peg: int) -> void:
	var anchor: int = _driver.snapshot().anchor
	if anchor >= 0:
		_click_peg(anchor)
	_click_peg(peg)
	_click_peg(peg)


func _click_peg(peg: int) -> void:
	var positions: PackedVector2Array = _driver.snapshot().pegs
	var point := View.PEG_AREA.position + positions[peg] * View.PEG_AREA.size
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.pressed = true
	_expect(_driver.handle_input(event, point), "a real touch recognizes the authored peg position")
	event.pressed = false
	_driver.handle_input(event, point)


func _tap_key(code: int) -> void:
	_key(code, true)
	_key(code, false)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	_driver.handle_input(event, Vector2.ZERO)


func _pad_lift(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	event.pressed = pressed
	_driver.handle_input(event, Vector2.ZERO)


func _step(ticks: int) -> void:
	for _tick in ticks:
		_driver.step(1.0 / 60.0)


func _expect(condition: bool, issue: String) -> void:
	if not condition:
		_errors.append(issue)
