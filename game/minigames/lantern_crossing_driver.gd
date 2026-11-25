extends RefCounted

const Model = preload("res://game/minigames/lantern_crossing_model.gd")
const View = preload("res://game/minigames/lantern_crossing_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const KEYS := {
	KEY_A: View.LEFT, KEY_LEFT: View.LEFT,
	KEY_D: View.RIGHT, KEY_RIGHT: View.RIGHT,
	KEY_W: View.RAISE, KEY_UP: View.RAISE,
	KEY_S: View.LOWER, KEY_DOWN: View.LOWER,
	KEY_SPACE: View.BRAKE, KEY_E: View.ACTION, KEY_R: View.RECOVER, KEY_H: View.HELPER,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_LEFT: View.LEFT, JOY_BUTTON_DPAD_RIGHT: View.RIGHT,
	JOY_BUTTON_DPAD_UP: View.RAISE, JOY_BUTTON_DPAD_DOWN: View.LOWER,
	JOY_BUTTON_X: View.BRAKE, JOY_BUTTON_A: View.ACTION,
	JOY_BUTTON_Y: View.RECOVER, JOY_BUTTON_RIGHT_SHOULDER: View.HELPER,
}

var _model := Model.new()
var _view: Control
var _pressed: Dictionary = {}
var _state: Dictionary
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_model.reset(false, _next_layout)
	_refresh_state()

func reset(assisted: bool, _clock: String) -> void:
	_pressed.clear()
	if is_instance_valid(_view):
		_view.clear_pointers()
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
		return _pressed.erase(source)
	var slot := Surface.hit_slot(point)
	if not View.action_available(slot, _state):
		return false
	_command(slot, true, source)
	return true

func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		_pressed.erase(source)
		return
	if _pressed.has(source):
		return
	_pressed[source] = true
	if not View.action_available(action, _state):
		return
	match action:
		View.LEFT: _model.select_endpoint(Model.LEFT)
		View.RIGHT: _model.select_endpoint(Model.RIGHT)
		View.RAISE: _model.adjust_endpoint(1)
		View.LOWER: _model.adjust_endpoint(-1)
		View.BRAKE: _model.toggle_brake()
		View.ACTION: _model.interact()
		View.RECOVER: _model.recover()
		View.HELPER: _model.toggle_helper()
	_refresh_state()

func clear_input() -> void:
	_pressed.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointers()

func step(delta: float) -> Dictionary:
	_model.step(delta)
	_refresh_state()
	return _state

func _refresh_state() -> void:
	_state = _model.snapshot()
	_state.progress_text = "掛燈 %d / %d" % [_state.hung, Model.LAMP_COUNT]
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
	var lamps: int = _state.hung * Model.LAMP_POINTS
	var swing_bonus := int(_state.devil) * Model.SWING_POINTS
	var loss := mini(lamps + swing_bonus, int(_state.mistakes) * Model.LOSS_POINTS)
	return {
		"total": _state.score, "label": "掛燈得分",
		"rule": "每盞 150 分。掛好四盞，且同一盞靠擺盪越牌後上鉤，加 100 分。重送或碰撞扣 20 分。",
		"rows": [
			{"key": "lamps", "label": "屋簷掛燈", "amount": lamps, "count": _state.hung},
			{"key": "swing", "label": "擺盪越牌", "amount": swing_bonus, "count": int(_state.devil)},
			{"key": "loss", "label": "搬運失誤", "amount": -loss, "count": _state.mistakes},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合運送過燈籠，自然結算可收藏普通卡。",
	}
