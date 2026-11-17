extends RefCounted
class_name JellyTrampolineDriver

const Model = preload("res://game/minigames/jelly_trampoline_model.gd")
const View = preload("res://game/minigames/jelly_trampoline_view.gd")
var _model = Model.new()
var _view: Control
var _owner := ""
var _held: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	_model.reset(assisted, _rounds)
	_rounds = 1 - _rounds
	present(time_phase, _reduced_motion)

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command_requested.connect(_command)
		_view.pointer_requested.connect(_pointer)
		_view.tree_exiting.connect(clear_input)
		present(_time_phase, _reduced_motion)
	return _view

func handle_input(event: InputEvent, design_point: Vector2) -> bool:
	if event is InputEventKey:
		if event.echo:
			return false
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not View.KEYS.has(code):
			return false
		return _command(View.KEYS[code], event.pressed, "keyboard:%d" % code)
	if is_instance_valid(_view):
		return _view.handle_pointer(event, design_point)
	var source := View.pointer_source(event)
	if source.is_empty():
		return false
	if event is InputEventScreenTouch and event.canceled:
		return _pointer("cancel", design_point, source)
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return _pointer("move", design_point, source)
	return _pointer("press" if event.pressed else "release", design_point, source)

func _command(command: String, pressed: bool, source: String) -> bool:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return true
	if not View.COMMANDS.has(command):
		return false
	# Distinct physical keys may configure a held shot; other input sources cannot steal it.
	var same_keyboard := _owner.begins_with("keyboard:") and source.begins_with("keyboard:")
	if not _owner.is_empty() and _owner != source and not same_keyboard:
		return false
	if not pressed:
		if _held.get(command, "") != source:
			return false
		_held.erase(command)
		if command == "charge":
			_model.release_charge()
		if _held.is_empty():
			_owner = ""
		return true
	if _model.snapshot().ended or _held.has(command):
		return false
	_owner = source
	_held[command] = source
	match command:
		"bed_left": _model.move_bed(-1)
		"bed_right": _model.move_bed(1)
		"tilt_left": _model.adjust_tilt(-1)
		"tilt_right": _model.adjust_tilt(1)
		"charge": _model.begin_charge()
		"helper": _model.toggle_helper()
		"reset_fruit":
			_model.reset_fruit()
			clear_input()
	return true

func _pointer(action: String, point: Vector2, source: String) -> bool:
	if action in ["cancel", "release"]:
		if _owner != source:
			return false
		if action == "release" and point.is_finite() and View.command_at(point) == "charge" and _held.has("charge"):
			_model.release_charge()
		clear_input()
		return true
	if not point.is_finite() or _model.snapshot().ended:
		return false
	if action == "move":
		return _owner == source
	if action != "press" or not _owner.is_empty():
		return false
	var command := View.command_at(point)
	return false if command.is_empty() else _command(command, true, source)

func clear_input() -> void:
	_owner = ""
	_held.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	_model.step(delta)
	if _model.snapshot().ended:
		clear_input()
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "送達 %d／3 · 同顆碰鈴送達 %d" % [state.delivered, state.bell_deliveries]
	state["time_text"] = "%d 秒" % ceili(state.remaining)
	state["feedback_text"] = str(state.feedback)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(snapshot(), time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state := snapshot()
	var rule := "三顆送達成功；碰鈴的同顆果實送達可得小惡魔。"
	var qualification := "實際蓄彈放開發射後正常結算可得普通拍貼。" + rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else rule)
	elif state.ended:
		qualification = "本回合未實際發射，沒有普通拍貼資格。" + rule
	var rows := [
		{"key": "deliveries", "label": "高台送達", "amount": state.delivered * 100, "count": state.delivered},
		{"key": "success", "label": "三顆完成", "amount": 100 if state.success else 0, "count": int(state.success)},
		{"key": "bell", "label": "同顆碰鈴送達", "amount": 100 if state.devil else 0, "count": int(state.devil)},
		{"key": "mistakes", "label": "果實失誤", "amount": -state.mistakes * 20, "count": state.mistakes}]
	var subtotal := 0
	for row in rows:
		subtotal += int(row.amount)
	if subtotal != int(state.score):
		rows.append({"key": "score_adjustment", "label": "最低零分", "amount": int(state.score) - subtotal, "count": 1})
	return {"total": state.score, "label": "彈床得分", "rule": "送達每顆100，成功100，碰鈴送達挑戰100；失誤每次扣20，最低零。", "rows": rows, "qualification_text": qualification}
