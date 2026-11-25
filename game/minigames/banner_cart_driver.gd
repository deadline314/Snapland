extends RefCounted

const Model = preload("res://game/minigames/banner_cart_model.gd")
const View = preload("res://game/minigames/banner_cart_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const KEYS := {
	KEY_W: View.DRIVE, KEY_UP: View.DRIVE, KEY_SPACE: View.BRAKE,
	KEY_R: View.RAISE, KEY_F: View.LOWER, KEY_Q: View.ROLL_LEFT, KEY_E: View.ROLL_RIGHT,
	KEY_LEFT: View.ROLL_LEFT, KEY_RIGHT: View.ROLL_RIGHT, KEY_A: View.DIRECT, KEY_D: View.BYPASS,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_UP: View.DRIVE, JOY_BUTTON_A: View.BRAKE,
	JOY_BUTTON_Y: View.RAISE, JOY_BUTTON_X: View.LOWER,
	JOY_BUTTON_LEFT_SHOULDER: View.ROLL_LEFT, JOY_BUTTON_RIGHT_SHOULDER: View.ROLL_RIGHT,
	JOY_BUTTON_DPAD_LEFT: View.DIRECT, JOY_BUTTON_DPAD_RIGHT: View.BYPASS,
}

var _model := Model.new()
var _view: View
var _pressed: Dictionary[String, int] = {}
var _control_mask := 0
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
	if pressed:
		if _pressed.has(source) or not View.action_available(action, _state):
			return
		_pressed[source] = action
		match action:
			View.DIRECT: _model.choose_route(Model.DIRECT)
			View.BYPASS: _model.choose_route(Model.BYPASS)
	elif not _pressed.erase(source):
		return
	_sync_controls()
	_refresh_state()


func _sync_controls() -> void:
	_control_mask = 0
	for action in _pressed.values():
		_control_mask |= 1 << action
	_model.set_drive_axis(float(_held(View.DRIVE)))
	_model.set_brake(_held(View.BRAKE))
	_model.set_lift_axis(float(_held(View.RAISE)) - float(_held(View.LOWER)))
	_model.set_roll_axis(float(_held(View.ROLL_RIGHT)) - float(_held(View.ROLL_LEFT)))


func _held(action: int) -> bool:
	return bool(_control_mask & (1 << action))


func clear_input() -> void:
	_pressed.clear()
	_control_mask = 0
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
	_state.control_mask = _control_mask
	_state.progress_text = "送達招幌 %d / %d" % [_state.delivered, Model.BANNER_COUNT]
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
	var delivered: int = _state.delivered * Model.DELIVERY_POINTS
	var challenge: int = int(_state.devil) * Model.CHALLENGE_POINTS
	return {
		"total": _state.score, "label": "運送得分",
		"rule": "每幅送達得 150 分。同一幅側傾通過兩道交錯低檐並送達三幅，加 100 分。",
		"rows": [
			{"key": "delivery", "label": "完整送達", "amount": delivered, "count": _state.delivered},
			{"key": "roll", "label": "側傾過檐", "amount": challenge, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際推車後，自然結算可收藏普通卡。",
	}
