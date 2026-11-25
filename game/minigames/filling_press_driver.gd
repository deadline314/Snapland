extends RefCounted

const Model = preload("res://game/minigames/filling_press_model.gd")
const View = preload("res://game/minigames/filling_press_view.gd")
const KEYS := {KEY_A: Model.LEFT, KEY_LEFT: Model.LEFT, KEY_D: Model.RIGHT, KEY_RIGHT: Model.RIGHT, KEY_SPACE: Model.BOTH, KEY_R: 0}

var _model := Model.new()
var _view: Control
var _owners: Dictionary = {}
var _latched := 0
var _assisted := false
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout

func reset(assisted: bool, _time_phase: String) -> void:
	clear_input()
	_assisted = assisted
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.pressed_input.connect(_command)
		_view.input_cancelled.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		_view.present(snapshot())
	return _view

func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not KEYS.has(key):
			return false
		if event.is_canceled():
			clear_input()
		elif not event.echo:
			_command(KEYS[key], event.pressed, str(key))
		return true
	if is_instance_valid(_view):
		return _view.handle_pointer(event, point)
	var source := View.pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		clear_input()
		return true
	if not event.pressed:
		var held := _owners.has(source)
		_command(0, false, source)
		return held
	var index := View.button_at(point) if point.is_finite() else -1
	if index < 0:
		return false
	_command(View.COMMANDS[index], true, source)
	return true

func _command(command: int, pressed: bool, source: String) -> void:
	var current := _model.snapshot()
	if pressed:
		if current.ended or _owners.has(source):
			return
		if command == 0:
			_model.toggle_helper()
			return
		if _assisted and current.phase == Model.PRESS:
			_latched = (0 if _latched == Model.BOTH else Model.BOTH) if command == Model.BOTH else (_latched ^ command)
		else:
			_owners[source] = command
	else:
		if not _owners.erase(source):
			return
	var mask := _latched
	for active: int in _owners.values():
		mask |= active
	if current.phase == Model.PRESS and current.helper and (mask & Model.LEFT) != 0:
		mask |= Model.RIGHT
	_model.set_pressed(mask)
	_clear_expired_latch()

func _clear_expired_latch() -> void:
	if _latched != 0 and not _model.is_pressing_phase():
		_latched = 0
		_model.clear_input()

func clear_input() -> void:
	_owners.clear()
	_latched = 0
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointer_input()

func consume_notes() -> Array[int]:
	return _model.consume_notes()

func step(delta: float) -> Dictionary:
	_model.step(delta)
	_clear_expired_latch()
	return snapshot()

func snapshot() -> Dictionary:
	var state := _model.snapshot()
	state.progress_text = "封口 %d / 3" % state.layers.size() + (" · 回彈置中" if state.centered else "")
	state.time_text = "%d 秒" % ceili(state.remaining)
	state.feedback_text = state.feedback
	return state

func present(_time_phase: String, _reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(snapshot())

func score_summary(practice: bool) -> Dictionary:
	var state := _model.snapshot()
	var layers: int = state.layers.size() * 140
	var bonus := 100 * int(state.devil)
	var penalty: int = mini(layers + bonus, state.mistakes * 20)
	return {"total": state.score, "label": "壓奏得分", "rule": "每層 140 分，全部封口且回彈置中加 100 分，失拍扣 20 分。",
		"rows": [
			{"key": "layers", "label": "同步封口", "amount": layers, "count": state.layers.size()},
			{"key": "center", "label": "回彈置中", "amount": bonus, "count": int(state.devil)},
			{"key": "misses", "label": "失拍", "amount": -penalty, "count": state.mistakes},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際雙側按壓，自然結算可收藏普通卡。"}
