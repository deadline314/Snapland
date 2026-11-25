extends RefCounted

const Model = preload("res://game/minigames/pancake_fold_model.gd")
const View = preload("res://game/minigames/pancake_fold_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const DIRECTIONS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const KEYS := {
	KEY_W: View.NORTH, KEY_UP: View.NORTH, KEY_D: View.EAST, KEY_RIGHT: View.EAST,
	KEY_S: View.SOUTH, KEY_DOWN: View.SOUTH, KEY_A: View.WEST, KEY_LEFT: View.WEST,
	KEY_SPACE: View.POUR, KEY_Q: View.TOOL, KEY_R: View.SALVAGE, KEY_E: View.FOLD,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_UP: View.NORTH, JOY_BUTTON_DPAD_RIGHT: View.EAST,
	JOY_BUTTON_DPAD_DOWN: View.SOUTH, JOY_BUTTON_DPAD_LEFT: View.WEST,
	JOY_BUTTON_A: View.POUR, JOY_BUTTON_X: View.TOOL, JOY_BUTTON_Y: View.SALVAGE,
	JOY_BUTTON_RIGHT_SHOULDER: View.FOLD,
}

var _model := Model.new()
var _view: View
var _pressed: Dictionary[String, int] = {}
var _direction_mask := 0
var _state: Dictionary
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
	if not View.action_available(action, _state):
		return false
	_command(action, true, source)
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		var original: int = _pressed.get(source, -1)
		_pressed.erase(source)
		if _is_direction(original):
			_update_axis()
			_refresh_state()
		return
	if _pressed.has(source) or not View.action_available(action, _state):
		return
	_pressed[source] = action
	if _is_direction(action):
		_update_axis()
	else:
		match action:
			View.POUR: _model.pour()
			View.TOOL:
				if _model.toggle_tool():
					_release_directions()
			View.SALVAGE: _model.salvage_or_lay()
			View.FOLD: _model.fold()
	_refresh_state()


func _is_direction(action: int) -> bool:
	return action >= View.NORTH and action <= View.WEST


func _release_directions() -> void:
	# Holding a tilt during the tool switch must not push the ladle away.
	for source in _pressed.keys():
		if _is_direction(_pressed[source]):
			_pressed.erase(source)
	_update_axis()


func _update_axis() -> void:
	_direction_mask = 0
	for action in _pressed.values():
		if _is_direction(action):
			_direction_mask |= 1 << (action - View.NORTH)
	var axis := Vector2.ZERO
	for direction in DIRECTIONS.size():
		if _direction_mask & (1 << direction):
			axis += DIRECTIONS[direction]
	_model.set_axis(axis.limit_length(1.0))


func clear_input() -> void:
	_pressed.clear()
	_direction_mask = 0
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
	_state.progress_text = "餅皮覆蓋 %d%%" % roundi(float(_state.coverage) * 100.0)
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback
	_state.direction_mask = _direction_mask


func snapshot() -> Dictionary:
	return _state


func consume_notes() -> Array[int]:
	return _model.consume_notes()


func present(phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion, phase)


func score_summary(practice: bool) -> Dictionary:
	return {
		"total": _state.score, "label": "煎餅得分",
		"rule": "煎餅完整包餡得 450 分。以鍋邊餘糊做出完整折耳再包餡，加 100 分。",
		"rows": [
			{"key": "dish", "label": "完整包餡", "amount": int(_state.success) * Model.DISH_POINTS, "count": int(_state.success)},
			{"key": "ear", "label": "餘糊折耳", "amount": int(_state.devil) * Model.EAR_POINTS, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合有實際倒糊，自然結算可收藏普通卡。",
	}
