extends RefCounted

const Model = preload("res://game/minigames/umbrella_lights_model.gd")
const View = preload("res://game/minigames/umbrella_lights_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const KEYS := {
	KEY_A: View.LEFT, KEY_LEFT: View.LEFT, KEY_D: View.RIGHT, KEY_RIGHT: View.RIGHT,
	KEY_SPACE: View.BRAKE, KEY_F: View.DETENT,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_LEFT: View.LEFT, JOY_BUTTON_DPAD_RIGHT: View.RIGHT,
	JOY_BUTTON_LEFT_SHOULDER: View.LEFT, JOY_BUTTON_RIGHT_SHOULDER: View.RIGHT,
	JOY_BUTTON_A: View.BRAKE, JOY_BUTTON_X: View.DETENT,
}

var _model := Model.new()
var _view: View
var _pressed: Dictionary[String, int] = {}
var _mask := 0
var _detent_mode := false
var _state: Dictionary
var _next_layout: int
static var _next_session_layout := 0


func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_state()


func reset(assisted: bool, _clock: String) -> void:
	clear_input()
	_detent_mode = false
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
	if not View.action_available(action, _state):
		return false
	_command(action, true, source)
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		if _pressed.erase(source):
			_update_controls()
			_refresh_state()
		return
	if _pressed.has(source) or not View.action_available(action, _state):
		return
	_pressed[source] = action
	if action == View.DETENT:
		_detent_mode = not _detent_mode
		_drop_turning()
	_update_controls()
	if _detent_mode and (action == View.LEFT or action == View.RIGHT):
		_model.nudge(1 if action == View.RIGHT else -1)
	_refresh_state()


func _drop_turning() -> void:
	for source in _pressed.keys():
		if _pressed[source] == View.LEFT or _pressed[source] == View.RIGHT:
			_pressed.erase(source)


func _update_controls() -> void:
	_mask = 0
	for action in _pressed.values():
		_mask |= 1 << action
	var turning := float(_held(View.RIGHT)) - float(_held(View.LEFT))
	_model.set_turn_axis(0.0 if _detent_mode else turning)
	_model.set_brake(_held(View.BRAKE))


func _held(action: int) -> bool:
	return bool(_mask & (1 << action))


func clear_input() -> void:
	_pressed.clear()
	_mask = 0
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
	_state.control_mask = _mask
	_state.detent_mode = _detent_mode
	_state.progress_text = "完成花瓣 %d / %d" % [_state.petals_done, Model.PETAL_COUNT]
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback


func snapshot() -> Dictionary:
	return _state


func consume_notes() -> Array[int]:
	return _model.consume_notes()


func present(phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion, phase)


func score_summary(practice: bool) -> Dictionary:
	return {
		"total": _state.score, "label": "投影得分",
		"rule": "每完成一片花瓣得 100 分。拼齊四片，且兩次主動停傘遮出留白，加 100 分。",
		"rows": [
			{"key": "petals", "label": "光紋花瓣", "amount": _state.petals_done * Model.PETAL_POINTS, "count": _state.petals_done},
			{"key": "center", "label": "留白花芯", "amount": int(_state.devil) * Model.CENTER_POINTS, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合轉傘接過光後，自然結算可收藏普通卡。",
	}
