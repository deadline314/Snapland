extends RefCounted

const Model = preload("res://game/minigames/rain_courier_model.gd")
const View = preload("res://game/minigames/rain_courier_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const KEYS := {
	KEY_A: View.SHORT, KEY_LEFT: View.SHORT,
	KEY_D: View.COVERED, KEY_RIGHT: View.COVERED,
	KEY_W: View.WALK, KEY_UP: View.WALK,
	KEY_SPACE: View.UMBRELLA, KEY_E: View.ACTION, KEY_R: View.RETRY,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_LEFT: View.SHORT, JOY_BUTTON_DPAD_RIGHT: View.COVERED,
	JOY_BUTTON_DPAD_UP: View.WALK, JOY_BUTTON_X: View.UMBRELLA,
	JOY_BUTTON_A: View.ACTION, JOY_BUTTON_Y: View.RETRY,
}

var _model := Model.new()
var _view: Control
var _owners: Dictionary = {}
var _state: Dictionary
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_state()

func reset(assisted: bool, _clock: String) -> void:
	_owners.clear()
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
		if not _owners.has(source):
			return false
		clear_input()
		return true
	if not event.pressed:
		var held := _owners.has(source)
		_command(-1, false, source)
		return held
	var slot := Surface.hit_slot(point)
	if not View.action_available(slot, _state.stage) or _owners.has(source):
		return false
	_command(slot, true, source)
	return true

func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		var previous: int = _owners.get(source, -1)
		_owners.erase(source)
		if previous == View.WALK:
			_model.hold(View.WALK in _owners.values())
			_refresh_state()
		return
	if _owners.has(source) or not View.action_available(action, _state.stage):
		return
	_owners[source] = action
	match action:
		View.SHORT: _model.choose_route(Model.SHORT)
		View.COVERED: _model.choose_route(Model.COVERED)
		View.WALK: _model.hold(true)
		View.UMBRELLA: _model.toggle_umbrella()
		View.ACTION:
			if _state.stage == Model.READY:
				_model.pickup()
			else:
				_model.slide()
		View.RETRY: _model.retry_order()
	_refresh_state()

func clear_input() -> void:
	_owners.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointers()
	_refresh_state()

func step(delta: float) -> Dictionary:
	_model.step(delta)
	_refresh_state()
	return _state

func _refresh_state() -> void:
	var previous: String = _state.get("stage", "")
	_state = _model.snapshot()
	if previous == Model.CARRY and _state.stage != Model.CARRY:
		# Keep umbrella selection during handoff, and require a fresh walk press for the next order.
		for source: String in _owners.keys():
			if _owners[source] == View.WALK:
				_owners.erase(source)
	_state.progress_text = "送達 %d / %d" % [_state.delivered, Model.ORDER_COUNT]
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
	var meals: int = _state.delivered * Model.DELIVERY_POINTS
	var bonus := int(_state.devil) * Model.PUDDLE_POINTS
	var penalty := mini(meals + bonus, int(_state.mistakes) * Model.LOSS_POINTS)
	return {
		"total": _state.score, "label": "配送得分",
		"rule": "每份熱餐 150 分。三份全送達且撐傘滑過積水另加 100 分，每次失誤扣 20 分。",
		"rows": [
			{"key": "meals", "label": "乾爽熱餐", "amount": meals, "count": _state.delivered},
			{"key": "puddle", "label": "撐傘跨積水", "amount": bonus, "count": _state.umbrella_catches},
			{"key": "loss", "label": "配送失誤", "amount": -penalty, "count": _state.mistakes},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合配送足夠路程並自然結算可收藏普通卡。",
	}
