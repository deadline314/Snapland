extends RefCounted

const Model = preload("res://game/minigames/skewer_grill_model.gd")
const View = preload("res://game/minigames/skewer_grill_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const KEYS := {
	KEY_A: View.PREVIOUS, KEY_LEFT: View.PREVIOUS,
	KEY_D: View.NEXT, KEY_RIGHT: View.NEXT,
	KEY_W: View.NEAR, KEY_UP: View.NEAR,
	KEY_S: View.FAR, KEY_DOWN: View.FAR,
	KEY_SPACE: View.TURN, KEY_E: View.SERVE, KEY_Q: View.COAL, KEY_R: View.HELPER,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_LEFT: View.PREVIOUS, JOY_BUTTON_DPAD_RIGHT: View.NEXT,
	JOY_BUTTON_DPAD_UP: View.NEAR, JOY_BUTTON_DPAD_DOWN: View.FAR,
	JOY_BUTTON_X: View.TURN, JOY_BUTTON_A: View.SERVE,
	JOY_BUTTON_Y: View.COAL, JOY_BUTTON_RIGHT_SHOULDER: View.HELPER,
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
	# Even a disabled press needs release before it can become an action.
	_pressed[source] = true
	if not View.action_available(action, _state):
		return
	match action:
		View.PREVIOUS: _model.select_skewer(posmod(int(_state.selected) - 1, Model.SKEWER_COUNT))
		View.NEXT: _model.select_skewer(posmod(int(_state.selected) + 1, Model.SKEWER_COUNT))
		View.NEAR: _model.move(Model.NEAR)
		View.FAR: _model.move(Model.FAR)
		View.TURN: _model.turn()
		View.SERVE:
			if _state.skewers[_state.selected].ruined:
				_model.replace_skewer()
			else:
				_model.serve()
		View.COAL: _model.add_coal()
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
	_state.progress_text = "上桌 %d / %d" % [_state.served, Model.SKEWER_COUNT]
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
	var skewers: int = _state.served * Model.SKEWER_POINTS
	var finish := int(_state.devil) * Model.RESIDUAL_POINTS
	var loss := mini(skewers + finish, int(_state.mistakes) * Model.LOSS_POINTS)
	return {
		"total": _state.score, "label": "炭火得分",
		"rule": "每串 150 分。最後一面靠餘溫熟成且全程未添炭，加 100 分。每次失誤扣 20 分。",
		"rows": [
			{"key": "served", "label": "四面熟透", "amount": skewers, "count": _state.served},
			{"key": "rest", "label": "餘溫收火", "amount": finish, "count": int(_state.devil)},
			{"key": "loss", "label": "烤焦失誤", "amount": -loss, "count": _state.mistakes},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際烘烤後自然結算可收藏普通卡。",
	}
