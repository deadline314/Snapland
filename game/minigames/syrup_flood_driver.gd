extends RefCounted
class_name SyrupFloodDriver

const Model = preload("res://game/minigames/syrup_flood_model.gd")
const View = preload("res://game/minigames/syrup_flood_view.gd")
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
		if code == KEY_TAB and event.pressed and (_held.has("previous") or _held.has("next")):
			return false
		var command: String = "previous" if code == KEY_TAB and event.shift_pressed else View.KEYS[code]
		if not event.pressed and code == KEY_TAB:
			command = "previous" if _held.has("previous") else "next"
		return _command(command, event.pressed, "keyboard")
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
	if not View.COMMANDS.has(command) or (not _owner.is_empty() and _owner != source):
		return false
	if not pressed:
		if _owner != source or not _held.has(command):
			return false
		_held.erase(command)
		if _held.is_empty():
			_owner = ""
		return true
	if _model.snapshot().ended or _held.has(command):
		return false
	_owner = source
	_held[command] = true
	match command:
		"previous": _model.select_next(-1)
		"next": _model.select_next(1)
		"valve": _model.toggle_valve()
		"heater": _model.toggle_heater()
		"diversion": _model.toggle_diversion()
		"helper": _model.toggle_helper()
		"drain": _model.drain_selected()
		"configuration": _model.toggle_configuration()
	return true

func _pointer(action: String, point: Vector2, source: String) -> bool:
	if action in ["cancel", "release"]:
		if _owner != source:
			return false
		clear_input()
		return true
	if not point.is_finite() or _model.snapshot().ended:
		return false
	if action == "move":
		return _owner == source
	if action != "press" or not _owner.is_empty():
		return false
	var command := View.command_at(point)
	if not command.is_empty():
		return _command(command, true, source)
	var index := View.valve_at(point)
	if index < 0:
		return false
	_model.select_branch(index)
	return _command("valve", true, source)

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
	state["progress_text"] = "刻線內 %d／3 · 溢出 %d" % [state.filled_tanks, state.mistakes]
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
	var rule := "三缸刻線內並關閥成功；實際冷糖堵漏再成功可得小惡魔。"
	var qualification := "有效調閥、熱源、旁路或排有糖的缸後正常結算可得普通拍貼。" + rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else rule)
	elif state.ended:
		qualification = "本回合未參與操作，沒有普通拍貼資格。" + rule
	var rows := [
		{"key": "tanks", "label": "刻線內糖缸", "amount": state.filled_tanks * 100, "count": state.filled_tanks},
		{"key": "success", "label": "關閥完成", "amount": 100 if state.success else 0, "count": int(state.success)},
		{"key": "plug", "label": "冷糖堵漏", "amount": 100 if state.devil else 0, "count": int(state.devil)},
		{"key": "mistakes", "label": "溢出", "amount": -state.mistakes * 20, "count": state.mistakes}]
	var subtotal := 0
	for row in rows:
		subtotal += int(row.amount)
	if subtotal != int(state.score):
		rows.append({"key": "score_adjustment", "label": "目前計分調整", "amount": int(state.score) - subtotal, "count": 1})
	return {"total": state.score, "label": "分洪得分", "rule": "刻線內每缸 100，成功 100，冷塞挑戰 100；溢出每次扣 20，最低零。", "rows": rows, "qualification_text": qualification}
