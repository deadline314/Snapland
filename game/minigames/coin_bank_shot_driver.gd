extends RefCounted

const Model = preload("res://game/minigames/coin_bank_shot_model.gd")
const View = preload("res://game/minigames/coin_bank_shot_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const REPEAT_DELAY := 0.28
const REPEAT_INTERVAL := 0.07
const REPEATABLE := [View.TURN_LEFT, View.TURN_RIGHT, View.POWER_DOWN, View.POWER_UP]
const KEYS := {
	KEY_A: View.TURN_LEFT, KEY_LEFT: View.TURN_LEFT,
	KEY_D: View.TURN_RIGHT, KEY_RIGHT: View.TURN_RIGHT,
	KEY_S: View.POWER_DOWN, KEY_DOWN: View.POWER_DOWN,
	KEY_W: View.POWER_UP, KEY_UP: View.POWER_UP,
	KEY_F: View.SELECT, KEY_TAB: View.SELECT, KEY_E: View.BOARD_TOGGLE,
	KEY_SPACE: View.SHOOT, KEY_R: View.HELPER,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_LEFT: View.TURN_LEFT, JOY_BUTTON_DPAD_RIGHT: View.TURN_RIGHT,
	JOY_BUTTON_DPAD_DOWN: View.POWER_DOWN, JOY_BUTTON_DPAD_UP: View.POWER_UP,
	JOY_BUTTON_RIGHT_SHOULDER: View.SELECT, JOY_BUTTON_X: View.BOARD_TOGGLE,
	JOY_BUTTON_A: View.SHOOT, JOY_BUTTON_Y: View.HELPER,
}

var _model := Model.new()
var _view: Control
var _pressed: Dictionary = {}
var _repeat_source := ""
var _repeat_left := 0.0
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
		var was_pressed := _pressed.has(source)
		_command(-1, false, source)
		return was_pressed
	var slot := Surface.hit_slot(point)
	if not View.action_available(slot, _state):
		return false
	_command(slot, true, source)
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		_pressed.erase(source)
		if source == _repeat_source:
			_repeat_source = ""
		return
	if _pressed.has(source):
		return
	_pressed[source] = action
	if not View.action_available(action, _state):
		return
	if action in REPEATABLE:
		_repeat_source = source
		_repeat_left = REPEAT_DELAY
	elif action == View.SELECT or action == View.SHOOT:
		_repeat_source = ""
	_apply(action)
	_refresh_state()


func _apply(action: int) -> void:
	match action:
		View.TURN_LEFT: _model.adjust_angle(-1)
		View.TURN_RIGHT: _model.adjust_angle(1)
		View.POWER_DOWN: _model.adjust_power(-1)
		View.POWER_UP: _model.adjust_power(1)
		View.SELECT: _model.cycle_selection()
		View.BOARD_TOGGLE: _model.toggle_board()
		View.SHOOT: _model.launch()
		View.HELPER: _model.assist_board()


func clear_input() -> void:
	_pressed.clear()
	_repeat_source = ""
	_repeat_left = 0.0
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointers()


func step(delta: float) -> Dictionary:
	_model.step(delta)
	if not _repeat_source.is_empty() and is_finite(delta) and delta > 0.0:
		_repeat_left -= minf(delta, 0.15)
		if _repeat_left <= 0.0:
			var action: int = _pressed.get(_repeat_source, -1)
			if View.action_available(action, _state):
				_apply(action)
			_repeat_left = REPEAT_INTERVAL
	_refresh_state()
	return _state


func _refresh_state() -> void:
	_state = _model.snapshot()
	_state.progress_text = "入孔 %d / %d" % [_state.sunk, Model.POCKET_COUNT]
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback


func snapshot() -> Dictionary:
	return _state


func consume_notes() -> Array[int]:
	return _model.consume_notes()


func present(_phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion)


func score_summary(practice: bool) -> Dictionary:
	var coins: int = _state.sunk * Model.POT_POINTS
	var paired := int(_state.devil) * Model.DOUBLE_POINTS
	var loss := mini(coins + paired, int(_state.mistakes) * Model.LOSS_POINTS)
	return {
		"total": _state.score, "label": "入孔得分",
		"rule": "每枚進指定孔 150 分。同一枚借彈兩片斜板後落對孔，三孔完成加 100 分。失誤每次扣 20 分。",
		"rows": [
			{"key": "coins", "label": "穩落指定孔", "amount": coins, "count": _state.sunk},
			{"key": "boards", "label": "雙板入孔", "amount": paired, "count": int(_state.devil)},
			{"key": "loss", "label": "未落指定孔", "amount": -loss, "count": _state.mistakes},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際投幣滑行，自然結算可收藏普通卡。",
	}
