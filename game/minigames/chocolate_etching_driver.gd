extends RefCounted
class_name ChocolateEtchingDriver

const Model = preload("res://game/minigames/chocolate_etching_model.gd")
const View = preload("res://game/minigames/chocolate_etching_view.gd")
const DIRECTIONS := ["left", "right", "up", "down"]
var _model := Model.new()
var _view: Control
var _keys: Dictionary = {}
var _pointer_source := ""
var _pointer_command := ""
var _tool_source := ""
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false
var _presented_stock_revision := -1

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	_model.reset(assisted, _rounds)
	_rounds = (_rounds + 1) % 2
	present(time_phase, _reduced_motion)

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_presented_stock_revision = -1
		_view.input_requested.connect(handle_input)
		_view.clear_requested.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		present(_time_phase, _reduced_motion)
	return _view

func handle_input(event: InputEvent, design_point: Vector2) -> bool:
	if event is InputEventKey:
		return _key(event)
	var source := View.pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		if source != _pointer_source:
			return false
		clear_input()
		return true
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if source != _pointer_source:
			return false
		if _pointer_command == "board" or (_pointer_command == "tool" and _model.snapshot().cutting):
			if not design_point.is_finite():
				clear_input()
			else:
				_model.move_cursor_to(View.design_to_board(design_point))
		return true
	if not event.pressed:
		if source != _pointer_source:
			return false
		_release_pointer(design_point, source)
		return true
	if not _pointer_source.is_empty() or not _keys.is_empty() or not design_point.is_finite():
		return false
	var state := _model.snapshot()
	var command := View.command_at(design_point)
	if state.ended or (command.is_empty() and not View.WORKSPACE.has_point(design_point)):
		return false
	_pointer_source = source
	_pointer_command = "board" if command.is_empty() else command
	if _pointer_command == "board":
		_model.move_cursor_to(View.design_to_board(design_point))
		if state.phase == "craft":
			_command("tool", source)
	else:
		_command(command, source)
	return true

func _key(event: InputEventKey) -> bool:
	var code := View.key_code(event)
	if not View.KEYS.has(code) or event.echo:
		return false
	if not _pointer_source.is_empty():
		return true
	var command: String = View.KEYS[code]
	var source := "key:%d" % code
	if event.pressed:
		if _keys.has(code) or _model.snapshot().ended:
			return true
		_keys[code] = command
		_command(command, source)
	else:
		_keys.erase(code)
		if _tool_source == source:
			_model.release_tool()
			_tool_source = ""
		_update_motion()
	return true

func _release_pointer(point: Vector2, source: String) -> void:
	var inside := point.is_finite() and View.WORKSPACE.has_point(point)
	var state := _model.snapshot()
	if _pointer_command == "board":
		if inside and state.phase == "assembly":
			_model.move_cursor_to(View.design_to_board(point))
			_model.place_selected(View.design_to_board(point))
		elif inside and _tool_source == source:
			_model.move_cursor_to(View.design_to_board(point))
			_model.release_tool()
		else:
			_model.cancel_tool()
	elif _tool_source == source:
		if state.phase == "assembly":
			_model.release_tool()
		elif inside:
			_model.move_cursor_to(View.design_to_board(point))
			_model.release_tool()
		else:
			_model.cancel_tool()
	_pointer_source = ""
	_pointer_command = ""
	_tool_source = ""
	_update_motion()

func _command(command: String, source: String) -> void:
	if command in DIRECTIONS:
		_update_motion()
		return
	if command in ["select", "shallow", "deep", "fold", "phase", "undo"]:
		_model.cancel_tool()
		_tool_source = ""
	match command:
		"select": _model.cycle_piece()
		"shallow": _model.adjust_depth(-1)
		"deep": _model.adjust_depth(1)
		"tool":
			_tool_source = source
			_model.begin_tool()
		"fold": _model.fold_or_mount()
		"phase": _model.toggle_phase()
		"undo": _model.undo()
		"helper": _model.toggle_helper()
	_update_motion()

func _update_motion() -> void:
	var held := _keys.values()
	if not _pointer_command.is_empty():
		held.append(_pointer_command)
	_model.set_motion(Vector2(float(held.has("right")) - float(held.has("left")), float(held.has("down")) - float(held.has("up"))))

func clear_input() -> void:
	_keys.clear()
	_pointer_source = ""
	_pointer_command = ""
	_tool_source = ""
	_model.clear_input()

func step(delta: float) -> Dictionary:
	_model.step(delta)
	var state := snapshot()
	if state.ended:
		clear_input()
		state.held_commands.clear()
	return state

func snapshot() -> Dictionary:
	var state := _model.snapshot()
	var freed := 0
	for i in 3:
		freed += int(state.parts[i].freed)
	state["main_freed"] = freed
	state["progress_text"] = "主輪 %d / 3 · 出口 %d%%" % [freed, state.output_percent]
	state["time_text"] = "%d 秒" % ceili(state.remaining)
	state["feedback_text"] = str(state.feedback)
	state["held_commands"] = _keys.values()
	if not _pointer_command.is_empty():
		state.held_commands.append(_pointer_command)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		var state := snapshot()
		if _presented_stock_revision != state.stock_revision:
			state["stock_strokes"] = _model.stock_strokes()
			_presented_stock_revision = state.stock_revision
		_view.present(state, time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state := snapshot()
	var qualification := "有實際切入的正式回合自然結束可得普通拍貼。小惡魔須讓剩料惰輪串入出口路徑。"
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else "小惡魔須讓剩料惰輪串入出口路徑。")
	return {"total": state.score, "label": "工藝得分", "rule": "每個主輪 100 分，出口轉滿一圈 100 分，小惡魔再加 100 分，每次失誤扣 20 分。",
		"rows": [
			{"key": "main_gears", "label": "折出主輪", "amount": state.main_freed * 100, "count": state.main_freed},
			{"key": "transmission", "label": "出口轉滿一圈", "amount": 100 * int(state.success), "count": int(state.success)},
			{"key": "idler", "label": "剩料惰輪傳動", "amount": 100 * int(state.devil), "count": int(state.devil)},
			{"key": "mistakes", "label": "失誤", "amount": -20 * state.mistakes, "count": state.mistakes}],
		"qualification_text": qualification}
