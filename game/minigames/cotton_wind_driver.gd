extends RefCounted
class_name CottonWindDriver

const Model = preload("res://game/minigames/cotton_wind_model.gd")
const View = preload("res://game/minigames/cotton_wind_view.gd")
const MOVES := ["left", "right", "near", "far"]
const SPINS := ["spin_left", "spin_right"]

var _model := Model.new()
var _view: Control
var _keys: Dictionary = {}
var _pointer_source := ""
var _pointer_command := ""
var _spin_latch := ""
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

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
		if _pointer_command == "drag":
			if design_point.is_finite():
				_model.move_stick_to(View.design_to_stick(design_point))
			else:
				clear_input()
		return true
	if not event.pressed:
		if source != _pointer_source:
			return false
		_pointer_source = ""
		_pointer_command = ""
		_update_motion()
		return true
	if not _pointer_source.is_empty() or not _keys.is_empty() or not design_point.is_finite() or _model.snapshot().ended:
		return false
	var command := View.command_at(design_point)
	if command.is_empty() and not View.WORKSPACE.has_point(design_point):
		return false
	_pointer_source = source
	_pointer_command = "drag" if command.is_empty() else command
	if _pointer_command == "drag":
		_model.move_stick_to(View.design_to_stick(design_point))
	else:
		if command in SPINS:
			_spin_latch = "" if _spin_latch == command else command
		_command(command)
		_update_motion()
	return true

func _key(event: InputEventKey) -> bool:
	var code := View.key_code(event)
	if not View.KEYS.has(code):
		return false
	if event.echo or not _pointer_source.is_empty():
		return true
	if event.pressed:
		if _keys.has(code) or _model.snapshot().ended:
			return true
		var command: String = View.KEYS[code]
		_keys[code] = command
		_command(command)
	else:
		_keys.erase(code)
	_update_motion()
	return true

func _command(command: String) -> void:
	match command:
		"finish":
			_model.finish()
			if _model.snapshot().ended:
				clear_input()
		"helper": _model.toggle_helper()

func _update_motion() -> void:
	var held := _keys.values()
	if _pointer_command in MOVES:
		held.append(_pointer_command)
	_model.set_motion(Vector2(int(held.has("right")) - int(held.has("left")), int(held.has("far")) - int(held.has("near"))))
	var left := held.has("spin_left")
	var right := held.has("spin_right")
	if not left and not right:
		left = _spin_latch == "spin_left"
		right = _spin_latch == "spin_right"
	_model.set_spin(int(right) - int(left))

func clear_input() -> void:
	_keys.clear()
	_pointer_source = ""
	_pointer_command = ""
	_spin_latch = ""
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
	var ready := 0
	for band: Dictionary in state.quality:
		ready += int(band.ready)
	state["progress_text"] = "達標 %d / 3 · 接回 %d 次" % [ready, state.rejoins]
	state["time_text"] = "%d 秒" % ceili(state.remaining)
	state["feedback_text"] = str(state.feedback)
	state["held_commands"] = []
	for command in View.COMMANDS:
		if _keys.values().has(command) or (_pointer_command == command and command not in SPINS) or _spin_latch == command:
			state.held_commands.append(command)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(snapshot(), time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state := snapshot()
	var ready := 0
	for band: Dictionary in state.quality:
		ready += int(band.ready)
	var qualification := "正式回合自然結束時，實際收絲、移棒及轉棒即可收藏普通拍貼。小惡魔需均勻成品與實際接回。"
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else "小惡魔需均勻成品與實際接回。")
	return {"total": state.score, "label": "捲糖得分", "rule": "每個達標段 100 分，確認均勻成品 100 分，成品接回再加 100 分，每次失誤扣 20 分。",
		"rows": [
			{"key": "bands", "label": "達標段", "amount": 100 * ready, "count": ready},
			{"key": "uniform", "label": "確認均勻成品", "amount": 100 * int(state.success), "count": int(state.success)},
			{"key": "rejoin", "label": "成品接回", "amount": 100 * int(state.devil), "count": int(state.devil)},
			{"key": "mistakes", "label": "失誤", "amount": -20 * state.mistakes, "count": state.mistakes}],
		"qualification_text": qualification}
