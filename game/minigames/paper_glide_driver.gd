extends RefCounted

const Model = preload("res://game/minigames/paper_glide_model.gd")
const View = preload("res://game/minigames/paper_glide_view.gd")
const KEYS := {KEY_A: View.LEFT, KEY_LEFT: View.LEFT, KEY_D: View.RIGHT, KEY_RIGHT: View.RIGHT,
	KEY_SPACE: View.THROW, KEY_ENTER: View.THROW, KEY_R: View.AI, KEY_1: View.WIDE, KEY_2: View.NARROW,
	KEY_S: View.LESS, KEY_DOWN: View.LESS, KEY_W: View.MORE, KEY_UP: View.MORE}

var _model := Model.new()
var _view: Control
var _steering: Dictionary = {}
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout

func reset(assisted: bool, _clock: String) -> void:
	clear_input()
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command.connect(_command)
		_view.pointer_cancelled.connect(clear_input)
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
			_command(KEYS[key], event.pressed, "key:%d" % key)
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
		var owned := _steering.has(source)
		_command(-1, false, source)
		return owned
	var slot := View.hit_slot(point)
	if slot == -1 or not View.is_active(slot, _model.snapshot()):
		return false
	_command(slot, true, source)
	return true

func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		if _steering.erase(source):
			_sync_steering()
		return
	match action:
		View.LEFT, View.RIGHT:
			if _model.phase() == Model.FLIGHT:
				if not _steering.has(source):
					_steering[source] = -1 if action == View.LEFT else 1
					_sync_steering()
			elif _model.phase() == Model.SETUP:
				_model.fold_side(Model.LEFT if action == View.LEFT else Model.RIGHT)
		View.THROW:
			_model.launch_or_recover()
			if _model.phase() != Model.FLIGHT:
				_steering.clear()
		View.AI: _model.toggle_helper()
		View.WIDE, View.NARROW: _model.select_fold(int(action == View.NARROW))
		View.LESS, View.MORE: _model.change_power(-1 if action == View.LESS else 1)

func _sync_steering() -> void:
	var direction := 0
	for value: int in _steering.values():
		direction += value
	_model.steer(signf(direction))

func clear_input() -> void:
	_steering.clear()
	_model.steer(0.0)
	if is_instance_valid(_view):
		_view.clear_pointers()

func step(delta: float) -> Dictionary:
	_model.step(delta)
	if not _steering.is_empty() and _model.phase() != Model.FLIGHT:
		clear_input()
	return snapshot()

func consume_notes() -> Array[int]:
	return _model.consume_notes()

func snapshot() -> Dictionary:
	var state := _model.snapshot()
	state.progress_text = "風窗 %d / 2" % state.passed + (" · 已擦鈴" if state.braked else "")
	state.time_text = "%d 秒" % ceili(state.remaining)
	state.feedback_text = state.feedback
	return state

func present(_time_phase: String, _reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(snapshot())

func score_summary(practice: bool) -> Dictionary:
	var state := _model.snapshot()
	var windows: int = state.best * Model.WINDOW_POINTS
	var landing := int(state.success) * Model.LANDING_POINTS
	var bell := int(state.devil) * Model.BELL_POINTS
	var misses: int = mini(windows + landing + bell, state.mistakes * Model.MISS_PENALTY)
	return {"total": state.score, "label": "滑翔得分", "rule": "每窗 80 分，落籃 240 分，擦鈴後落籃加 100 分，失誤扣 20 分。",
		"rows": [
			{"key": "windows", "label": "穿過風窗", "amount": windows, "count": state.best},
			{"key": "landing", "label": "落入包裝籃", "amount": landing, "count": int(state.success)},
			{"key": "bell", "label": "擦鈴減速", "amount": bell, "count": int(state.devil)},
			{"key": "misses", "label": "飛行失誤", "amount": -misses, "count": state.mistakes},
		], "qualification_text": "練習回合不取得拍貼。" if practice else "正式回合投出紙機並飛離試飛台後，自然結算可收藏普通卡。"}
