extends RefCounted

const Model = preload("res://game/minigames/ice_slide_model.gd")
const View = preload("res://game/minigames/ice_slide_view.gd")
const KEYS := {
	KEY_W: "up", KEY_UP: "up", KEY_A: "left", KEY_LEFT: "left",
	KEY_S: "down", KEY_DOWN: "down", KEY_D: "right", KEY_RIGHT: "right",
	KEY_Q: "swap", KEY_F: "mark", KEY_ENTER: "place", KEY_SPACE: "place",
	KEY_X: "recall", KEY_Z: "undo", KEY_R: "helper",
}

var _model := Model.new()
var _view: Control
var _state: Dictionary
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout

func reset(assisted: bool, _time_phase: String) -> void:
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout
	_sync()

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.input_requested.connect(handle_input)
		_view.present(_state)
	return _view

func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var command: String = KEYS.get(key, "")
		if command.is_empty():
			return false
		var repeat_cursor: bool = _state.cursor != Model.EMPTY and View.COMMANDS.find(command) < Model.DIRECTIONS.size()
		if event.pressed and not event.is_canceled() and (not event.echo or repeat_cursor):
			_command(command)
		return true
	if not point.is_finite() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if not (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)):
		return false
	var button := View.button_at(point)
	var cell := View.cell_at(point)
	if button < 0 and cell == Model.EMPTY:
		return false
	if event.pressed and not event.is_canceled():
		if button >= 0:
			_command(View.COMMANDS[button])
		else:
			_model.choose_cell(cell)
			_sync()
	return true

func _command(command: String) -> void:
	var index := View.COMMANDS.find(command)
	if index >= 0 and index < Model.DIRECTIONS.size():
		_model.push(Model.DIRECTIONS[index])
	else:
		match command:
			"swap": _model.swap_ice()
			"mark": _model.toggle_placement()
			"place": _model.confirm_placement()
			"recall": _model.recall_stopper()
			"undo": _model.undo()
			"helper": _model.toggle_helper()
	_sync()

func clear_input() -> void:
	pass

func step(delta: float) -> Dictionary:
	_model.step(delta)
	_sync()
	return _state

func snapshot() -> Dictionary:
	return _state

func present(_time_phase: String, _reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state)

func _sync() -> void:
	_state = _model.snapshot()
	_state.progress_text = "已冷卻 %d / 4" % _state.cooled + (" · 冰塊互擋" if _state.ice_stop else "")
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback

func score_summary(practice: bool) -> Dictionary:
	var molds: int = _state.cooled * 130
	var bonus := int(_state.devil) * 100
	var penalty: int = mini(_state.mistakes * 25, molds + bonus)
	return {"total": _state.score, "label": "冷卻得分",
		"rule": "每個模座 130 分，通關並互擋加 100 分，融化一次扣 25 分。",
		"rows": [
			{"key": "molds", "label": "冷卻模座", "amount": molds, "count": _state.cooled},
			{"key": "ice", "label": "冰塊互擋", "amount": bonus, "count": int(_state.devil)},
			{"key": "melt", "label": "融化", "amount": -penalty, "count": _state.mistakes},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際推冰並自然結算可收藏普通卡。"}
