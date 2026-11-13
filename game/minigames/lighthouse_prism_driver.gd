extends RefCounted
class_name LighthousePrismDriver

const Model = preload("res://game/minigames/lighthouse_prism_model.gd")
const View = preload("res://game/minigames/lighthouse_prism_view.gd")
const KEYS := {KEY_A: "previous", KEY_LEFT: "previous", KEY_D: "next", KEY_RIGHT: "next", KEY_Q: "rotate_left",
	KEY_E: "rotate_right", KEY_SPACE: "rotate_right", KEY_Z: "undo", KEY_ENTER: "settle", KEY_KP_ENTER: "settle"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate which fog band thins crossing beams.
	_model.reset(assisted, _rounds)
	_rounds += 1
	present(time_phase, _reduced_motion)

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command_requested.connect(_command)
		_view.tree_exiting.connect(clear_input)
		present(_time_phase, _reduced_motion)
	return _view

func handle_input(event: InputEvent, design_point: Vector2) -> bool:
	if event is InputEventKey:
		if event.echo:
			return false
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code >= KEY_1 and code < KEY_1 + Model.ELEMENTS.size():
			if event.pressed and not _model.snapshot().ended:
				_model.select_element(Model.ELEMENTS[code - KEY_1].id)
			return true
		if not KEYS.has(code):
			return false
		_command(KEYS[code], event.pressed, "key:%d" % code)
		return true
	if is_instance_valid(_view):
		return _view.handle_pointer(event, design_point)
	var source: String = View.pointer_source(event)
	if source.is_empty():
		return false
	if not event.pressed:
		var held := _owners.has(source)
		_owners.erase(source)
		return held
	if not design_point.is_finite():
		return false
	var command: String = View.command_at(design_point)
	if command.is_empty():
		return false
	_command(command, true, source)
	return true

## Every command is a discrete press; a held key or pointer acts once.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if not pressed:
		_owners.erase(source)
		return
	if _owners.has(source) or _model.snapshot().ended:
		return
	_owners[source] = command
	if command.begins_with("select:"):
		_model.select_element(command.trim_prefix("select:"))
		return
	match command:
		"previous": _model.select_next(-1)
		"next": _model.select_next(1)
		"rotate_left": _model.operate(-1)
		"rotate_right": _model.operate(1)
		"undo": _model.undo()
		"settle": _model.settle()

func clear_input() -> void:
	_owners.clear()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	_model.step(delta)
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "航標 %d / 3 · 分束 %d" % [state.main_lit, state.splits]
	state["time_text"] = "%d 秒" % ceili(state.remaining) if state.timed else "無時限"
	state["feedback_text"] = str(state.feedback)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(snapshot(), time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state: Dictionary = snapshot()
	var devil_rule := "小惡魔需只用一次分束，同時照亮三座航標與隱藏側標。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "燈塔得分", "rule": "結算時每座亮起的航標 100 分，隱藏側標再加 50 分。", "rows": [
		{"key": "beacons", "label": "點亮航標", "amount": state.main_lit * Model.BEACON_POINTS, "count": state.main_lit},
		{"key": "side", "label": "隱藏側標", "amount": Model.HIDDEN_POINTS if state.hidden_lit else 0, "count": int(state.hidden_lit)},
		{"key": "splits", "label": "分束次數（不扣分）", "amount": 0, "count": state.splits, "progress_only": true}], "qualification_text": qualification}
