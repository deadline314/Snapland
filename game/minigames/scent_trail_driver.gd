extends RefCounted

const Model = preload("res://game/minigames/scent_trail_model.gd")
const View = preload("res://game/minigames/scent_trail_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const HELPER := 8
const STICK_DEADZONE := 0.22
const KEYS := {
	KEY_W: View.MOVE_NORTH, KEY_UP: View.MOVE_NORTH,
	KEY_D: View.MOVE_EAST, KEY_RIGHT: View.MOVE_EAST,
	KEY_S: View.MOVE_SOUTH, KEY_DOWN: View.MOVE_SOUTH,
	KEY_A: View.MOVE_WEST, KEY_LEFT: View.MOVE_WEST,
	KEY_Q: View.TURN_LEFT, KEY_E: View.TURN_RIGHT, KEY_F: View.FILTER,
	KEY_SPACE: View.ACTION, KEY_R: HELPER,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_UP: View.MOVE_NORTH, JOY_BUTTON_DPAD_RIGHT: View.MOVE_EAST,
	JOY_BUTTON_DPAD_DOWN: View.MOVE_SOUTH, JOY_BUTTON_DPAD_LEFT: View.MOVE_WEST,
	JOY_BUTTON_LEFT_SHOULDER: View.TURN_LEFT, JOY_BUTTON_RIGHT_SHOULDER: View.TURN_RIGHT,
	JOY_BUTTON_X: View.FILTER, JOY_BUTTON_A: View.ACTION, JOY_BUTTON_Y: HELPER,
}

var _model := Model.new()
var _view: View
var _pressed: Dictionary[String, int] = {}
var _sticks: Dictionary[int, Vector2] = {}
var _state: Dictionary
var _move_mask := 0
var _next_layout: int
static var _next_session_layout := 0


func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_state()


func reset(assisted: bool, _clock: String) -> void:
	clear_input()
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout
	_refresh_state()


func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command.connect(_command)
		_view.pointer_cancelled.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		_view.present(_state)
	return _view


func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not KEYS.has(key):
			return false
		if event.is_canceled():
			clear_input()
		elif not event.echo:
			_command(KEYS[key], event.pressed, "key:%d" % key)
		return true
	if event is InputEventJoypadMotion:
		return _move_stick(event)
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
	var slot := Surface.hit_slot(point)
	if not View.action_available(slot, _state):
		return false
	_command(slot, true, source)
	return true


func _move_stick(event: InputEventJoypadMotion) -> bool:
	if event.axis != JOY_AXIS_LEFT_X and event.axis != JOY_AXIS_LEFT_Y:
		return false
	if event.is_canceled():
		clear_input()
	elif is_finite(event.axis_value):
		var stick: Vector2 = _sticks.get(event.device, Vector2.ZERO)
		stick[event.axis] = clampf(event.axis_value, -1.0, 1.0)
		if stick == Vector2.ZERO:
			_sticks.erase(event.device)
		else:
			_sticks[event.device] = stick
		_update_walk_axis()
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		var released: int = _pressed.get(source, -1)
		_pressed.erase(source)
		if _is_direction(released):
			_update_walk_axis()
		return
	if _pressed.has(source) or bool(_state.ended):
		return
	_pressed[source] = action
	if _is_direction(action):
		_update_walk_axis()
	else:
		match action:
			View.TURN_LEFT: _model.turn_sampler(-1)
			View.TURN_RIGHT: _model.turn_sampler(1)
			View.FILTER: _model.cycle_filter()
			View.ACTION: _model.interact()
			HELPER: _model.request_helper()
	_refresh_state()


func _is_direction(action: int) -> bool:
	return action >= View.MOVE_NORTH and action <= View.MOVE_WEST


func _update_walk_axis() -> void:
	_move_mask = 0
	for action in _pressed.values():
		if _is_direction(action):
			_move_mask |= 1 << (action - View.MOVE_NORTH)
	var axis := Vector2.ZERO
	for direction in DIRECTIONS.size():
		if _move_mask & (1 << direction):
			axis += DIRECTIONS[direction]
	for stick: Vector2 in _sticks.values():
		var length := stick.length()
		if length > STICK_DEADZONE:
			axis += stick / length * inverse_lerp(STICK_DEADZONE, 1.0, minf(length, 1.0))
	_model.set_walk_axis(axis.limit_length(1.0))
	_state["move_mask"] = _move_mask


func clear_input() -> void:
	_pressed.clear()
	_sticks.clear()
	_move_mask = 0
	_model.clear_input()
	_refresh_state()
	if is_instance_valid(_view):
		_view.clear_pointers()


func step(delta: float) -> Dictionary:
	_model.step(delta)
	_refresh_state()
	return _state


func _refresh_state() -> void:
	_state = _model.snapshot()
	_state.mistakes = 0
	_state.progress_text = "開火攤 %d / %d" % [_state.found, Model.STALL_COUNT]
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback
	_state.move_mask = _move_mask


func snapshot() -> Dictionary:
	return _state


func consume_notes() -> Array[int]:
	return _model.consume_notes()


func present(_phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion)


func score_summary(practice: bool) -> Dictionary:
	return {
		"total": _state.score, "label": "尋攤得分",
		"rule": "每確認一攤得 150 分。確認三攤並標記混香的上游匯口，加 100 分。",
		"rows": [
			{"key": "stalls", "label": "確認開火攤", "amount": _state.found * Model.STALL_POINTS, "count": _state.found},
			{"key": "merge", "label": "標記混香匯口", "amount": int(_state.devil) * Model.MIX_POINTS, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合取到香樣後，自然結算可收藏普通卡。",
	}
