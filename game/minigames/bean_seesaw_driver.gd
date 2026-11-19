extends RefCounted

const Model = preload("res://game/minigames/bean_seesaw_model.gd")
const View = preload("res://game/minigames/bean_seesaw_view.gd")

var _model := Model.new()
var _view: Control
var _next_layout := 0
static var _next_session_layout := 0

func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = (_next_session_layout + 1) % Model.LAYOUTS.size()

func reset(assisted: bool, _time_phase: String) -> void:
	_model.reset(assisted, _next_layout)
	_next_layout = (_next_layout + 1) % Model.LAYOUTS.size()

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.input_requested.connect(handle_input)
		_view.present(snapshot())
	return _view

func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key not in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_Q, KEY_E, KEY_R, KEY_F]:
			return false
		if event.pressed and not event.echo and not event.is_canceled():
			match key:
				KEY_A, KEY_LEFT: _model.nudge_pedal(-1)
				KEY_D, KEY_RIGHT: _model.nudge_pedal(1)
				KEY_HOME: _model.move_pedal(-Model.MAX_PEDAL)
				KEY_END: _model.move_pedal(Model.MAX_PEDAL)
				KEY_Q: _model.release(0)
				KEY_E: _model.release(1)
				KEY_R: _model.toggle_helper()
				KEY_F: _model.finish()
		return true
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if not (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)):
		return false
	var button := View.button_at(point) if point.is_finite() else -1
	if button < 0:
		return false
	if event.pressed and not event.is_canceled():
		match button:
			View.HOPPER_LEFT, View.HOPPER_RIGHT: _model.release(button - View.HOPPER_LEFT)
			View.HELPER: _model.toggle_helper()
			View.FINISH: _model.finish()
			_: _model.move_pedal(button - Model.MAX_PEDAL)
	return true

func clear_input() -> void:
	# Every control commits on press, so there are no held commands to release.
	pass

func step(delta: float) -> Dictionary:
	_model.step(delta)
	return snapshot()

func snapshot() -> Dictionary:
	var state := _model.snapshot()
	state.progress_text = ("已同步" if state.paired else "等候雙盤同步") + (" · 側槽已收" if state.side_catch else "")
	state.time_text = "%d 秒" % ceili(state.remaining)
	state.feedback_text = state.feedback
	return state

func present(_time_phase: String, _reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(snapshot())

func score_summary(practice: bool) -> Dictionary:
	var state := _model.snapshot()
	var pair := 200 * int(state.paired)
	var rebound := 100 * int(state.side_catch)
	var pans: int = 60 * state.pans_hit
	var loss := mini(pans + pair + rebound, state.mistakes * 20)
	var qualification := "移踏板並開過雙料斗，自然結算可收藏普通拍貼。"
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.devil:
		qualification = "雙盤同步與回彈側槽都達成。"
	elif state.ordinary_eligible:
		qualification = "取得普通拍貼資格。小惡魔需雙盤同步及回彈側槽。"
	return {"total": state.score, "label": "稱豆得分",
		"rule": "每盤首次接豆 60 分，雙盤同步 200 分，側槽回彈 100 分，落到盤外扣 20 分。",
		"rows": [
			{"key": "pans", "label": "秤盤", "amount": pans, "count": state.pans_hit},
			{"key": "pair", "label": "同步落盤", "amount": pair, "count": int(state.paired)},
			{"key": "rebound", "label": "回彈入槽", "amount": rebound, "count": int(state.side_catch)},
			{"key": "misses", "label": "落到盤外", "amount": -loss, "count": state.mistakes},
		],
		"qualification_text": qualification}
