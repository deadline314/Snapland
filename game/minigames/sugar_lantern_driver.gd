extends RefCounted

const Model = preload("res://game/minigames/sugar_lantern_model.gd")
const View = preload("res://game/minigames/sugar_lantern_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const KEYS := {
	KEY_W: View.NORTH, KEY_UP: View.NORTH, KEY_D: View.EAST, KEY_RIGHT: View.EAST,
	KEY_S: View.SOUTH, KEY_DOWN: View.SOUTH, KEY_A: View.WEST, KEY_LEFT: View.WEST,
	KEY_E: View.JOIN, KEY_Q: View.GAUGE, KEY_SPACE: View.LIFT, KEY_F: View.REWARM,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_UP: View.NORTH, JOY_BUTTON_DPAD_RIGHT: View.EAST,
	JOY_BUTTON_DPAD_DOWN: View.SOUTH, JOY_BUTTON_DPAD_LEFT: View.WEST,
	JOY_BUTTON_A: View.JOIN, JOY_BUTTON_X: View.GAUGE,
	JOY_BUTTON_RIGHT_SHOULDER: View.LIFT, JOY_BUTTON_Y: View.REWARM,
}

static var _next_session_layout := 0
var _next_layout: int
var _model := Model.new()
var _view: View
var _state: Dictionary
var _pressed: Dictionary[String, int] = {}
var _notes: Array[int] = []
var _focus := 0
var _anchor := -1
var _doubled := false


func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_state()


func reset(assisted: bool, _clock: String) -> void:
	clear_input()
	_anchor = -1
	_focus = 0
	_doubled = false
	_notes.clear()
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout
	_refresh_state()


func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command.connect(_command)
		_view.peg_tapped.connect(_tap_peg)
		_view.pointer_cancelled.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		_view.present(_state)
	return _view


func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not KEYS.has(code):
			return false
		if event.is_canceled():
			clear_input()
		elif not event.echo:
			_command(KEYS[code], event.pressed, "key:%d" % code)
		return true
	if event is InputEventJoypadButton:
		if not GAMEPAD.has(event.button_index):
			return false
		_command(GAMEPAD[event.button_index], event.pressed, "pad:%d:%d" % [event.device, event.button_index])
		return true
	if is_instance_valid(_view):
		return _view.handle_pointer(event, point)
	var source := Surface.pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		if not _pressed.has(source):
			return false
		clear_input()
		return true
	if not event.pressed:
		if not _pressed.has(source):
			return false
		_command(-1, false, source)
		return true
	var action := Surface.hit_slot(point)
	if View.action_available(action, _state):
		_command(action, true, source)
		return true
	var peg := View.hit_peg(point, _state)
	if not View.action_available(View.JOIN, _state) or peg < 0:
		return false
	_tap_peg(peg)
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		var released: int = _pressed.get(source, -1)
		if _pressed.erase(source):
			if released == View.LIFT:
				_model.set_lift(View.LIFT in _pressed.values())
			_refresh_state()
		return
	if _pressed.has(source) or not View.action_available(action, _state):
		return
	var was_lifting: bool = _state.lifting
	_pressed[source] = action
	match action:
		View.NORTH, View.EAST, View.SOUTH, View.WEST:
			_move_focus(DIRECTIONS[action])
		View.JOIN: _join()
		View.GAUGE: _doubled = not _doubled
		View.LIFT: _model.set_lift(true)
		View.REWARM:
			if _model.rewarm():
				_anchor = -1
				_notes.append(67)
	_refresh_state()
	if action == View.LIFT and _state.lifting and not was_lifting:
		_notes.append(76)


func _tap_peg(index: int) -> void:
	if not View.action_available(View.JOIN, _state):
		return
	_focus = index
	_join()
	_refresh_state()


func _join() -> void:
	if _anchor == _focus:
		_anchor = -1
	elif _anchor < 0:
		_anchor = _focus
	elif _model.place_strand(_anchor, _focus, _doubled):
		_anchor = _focus
		_notes.append(72)


func _move_focus(direction: Vector2) -> void:
	var pegs: PackedVector2Array = _state.pegs
	var origin: Vector2 = pegs[_focus]
	var best := INF
	var target := _focus
	for index in pegs.size():
		var offset := (pegs[index] - origin) * View.PEG_AREA.size
		if offset.dot(direction) <= 2.0:
			continue
		var fit := offset.length() + absf(offset.cross(direction)) * 1.35
		if fit < best:
			best = fit
			target = index
	_focus = target


func clear_input() -> void:
	_pressed.clear()
	_model.clear_input()
	_refresh_state()
	if is_instance_valid(_view):
		_view.clear_pointers()


func step(delta: float) -> Dictionary:
	var was_successful: bool = _state.success
	_model.step(delta)
	_refresh_state()
	if _state.success and not was_successful:
		_notes.append(84)
	return _state


func _refresh_state() -> void:
	_state = _model.snapshot()
	_state.focus = _focus
	_state.anchor = _anchor
	_state.doubled = _doubled
	var mask := 0
	for action in _pressed.values():
		mask |= 1 << action
	_state.control_mask = mask
	_state.progress_text = "已接 %d 條糖線" % _state.edges.size()
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback


func snapshot() -> Dictionary:
	return _state


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func present(phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion, phase)


func score_summary(practice: bool) -> Dictionary:
	return {
		"total": _state.score, "label": "提燈得分",
		"rule": "穩定提起糖畫得 450 分。用餘糖接成活動尾巴，提起時保持完整並實際擺動，加 150 分。",
		"rows": [
			{"key": "body", "label": "完整提燈", "amount": int(_state.success) * Model.BODY_POINTS, "count": int(_state.success)},
			{"key": "tail", "label": "活動尾巴", "amount": int(_state.devil) * Model.TAIL_POINTS, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際接過糖線，自然結算可收藏普通卡。",
	}
