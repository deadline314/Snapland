extends RefCounted

const Model = preload("res://game/minigames/bubble_lift_model.gd")
const View = preload("res://game/minigames/bubble_lift_view.gd")
const KEYS := {KEY_1: View.SINGLE, KEY_2: View.PAIR, KEY_E: View.CONFIRM, KEY_F: View.CONFIRM, KEY_R: View.HELPER,
	KEY_A: View.PUMP_LEFT, KEY_LEFT: View.PUMP_LEFT, KEY_D: View.PUMP_RIGHT, KEY_RIGHT: View.PUMP_RIGHT,
	KEY_SPACE: View.RELEASE, KEY_Q: View.VENT}

var _model := Model.new()
var _view: Control
var _owners: Dictionary = {}
var _next_layout: int
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout

func reset(assisted: bool, _time_phase: String) -> void:
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
		var held := _owners.has(source)
		_command(-1, false, source)
		return held
	var slot := View.hit_slot(point)
	if not View.enabled(slot, _model.snapshot()):
		return false
	_command(slot, true, source)
	return true

func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		if _owners.erase(source):
			_sync_holds()
		return
	var state := _model.snapshot()
	if not View.enabled(action, state):
		return
	match action:
		View.SINGLE, View.PAIR:
			var count := 1 if action == View.SINGLE else 2
			if count != state.selection:
				_model.choose_count(count)
				clear_input()
		View.CONFIRM: _model.confirm_or_split()
		View.HELPER: _model.toggle_helper()
		View.RELEASE:
			_model.release_basket()
			if _model.phase() != state.phase:
				clear_input()
		View.PUMP_LEFT, View.PUMP_RIGHT, View.VENT:
			if not _owners.has(source):
				_owners[source] = action
				_sync_holds()

func _sync_holds() -> void:
	var pumps := 0
	var venting := false
	for action: int in _owners.values():
		match action:
			View.PUMP_LEFT: pumps |= Model.LEFT_PUMP
			View.PUMP_RIGHT: pumps |= Model.RIGHT_PUMP
			View.VENT: venting = true
	_model.set_holds(pumps, venting)

func clear_input() -> void:
	_owners.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointers()

func step(delta: float) -> Dictionary:
	var previous := _model.phase()
	_model.step(delta)
	if _model.phase() != previous:
		clear_input()
	return snapshot()

func snapshot() -> Dictionary:
	var state := _model.snapshot()
	state.progress_text = "送達 %d / 3 桶" % Model.cargo_count(state.delivered) + (" · 雙泡分送" if state.split_completed else "")
	state.time_text = "%d 秒" % ceili(state.remaining)
	state.feedback_text = state.feedback
	return state

func consume_notes() -> Array[int]:
	return _model.consume_notes()

func present(_time_phase: String, _reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(snapshot())

func score_summary(practice: bool) -> Dictionary:
	var state := _model.snapshot()
	var count := Model.cargo_count(state.delivered)
	var cargo := count * Model.DELIVERY_POINTS
	var bonus := int(state.devil) * Model.SPLIT_POINTS
	var penalty: int = mini(cargo + bonus, state.mistakes * Model.MISS_PENALTY)
	return {"total": state.score, "label": "升降運送得分", "rule": "每桶 130 分。三桶送達且完成雙泡分送加 100 分，失誤扣 20 分。",
		"rows": [
			{"key": "cargo", "label": "原料桶送達", "amount": cargo, "count": count},
			{"key": "split", "label": "雙泡分送", "amount": bonus, "count": int(state.devil)},
			{"key": "misses", "label": "運送失誤", "amount": -penalty, "count": state.mistakes},
		], "qualification_text": "練習回合不取得拍貼。" if practice else "正式回合讓乘籃離台運行後，自然結算可收藏普通卡。"}
