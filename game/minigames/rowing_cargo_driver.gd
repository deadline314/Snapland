extends RefCounted
class_name RowingCargoDriver

const Model = preload("res://game/minigames/rowing_cargo_model.gd")
const View = preload("res://game/minigames/rowing_cargo_view.gd")
const KEYS := {KEY_W: "stroke", KEY_UP: "stroke", KEY_S: "reverse", KEY_DOWN: "reverse", KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right", KEY_Q: "slip_left", KEY_E: "slip_right", KEY_SPACE: "interact"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	_model.reset(assisted)
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
		_command("", false, source)
		return held
	if not is_finite(design_point.x) or not is_finite(design_point.y):
		return false
	var command: String = View.command_at(design_point)
	if command.is_empty():
		return false
	_command(command, true, source)
	return true

func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
		match command:
			"stroke": _model.paddle(1)
			"reverse": _model.paddle(-1)
			"slip_left": _model.sideslip(-1)
			"slip_right": _model.sideslip(1)
			"interact": _model.interact()
	else:
		_owners.erase(source)
	var commands: Array = _owners.values()
	_model.set_rudder(float(commands.has("right")) - float(commands.has("left")))

func clear_input() -> void:
	_owners.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	_model.step(delta)
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "送達 %d / 3 箱 · 撞箱 %d" % [state.delivery_ledger.size(), state.crate_impacts]
	state["time_text"] = "%d 秒" % ceili(state.remaining)
	state["feedback_text"] = View.feedback_text(state)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(snapshot(), time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state: Dictionary = snapshot()
	var qualification := "回合結束可得普通拍貼；小惡魔需三箱全送達、曾浪峰側滑靠岸且零撞箱。"
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else "小惡魔需三箱全送達、曾浪峰側滑靠岸且零撞箱。")
	return {"total": state.score, "label": "運箱得分", "rule": "每箱實際送達 100 分；撞箱與碰堤分開記錄。", "rows": [
		{"key": "deliveries", "label": "實際送達", "amount": state.score, "count": state.delivery_ledger.size()},
		{"key": "crate_impacts", "label": "撞箱（不扣分）", "amount": 0, "count": state.crate_impacts, "progress_only": true},
		{"key": "wall_collisions", "label": "碰堤（不影響小惡魔）", "amount": 0, "count": state.wall_collisions, "progress_only": true}], "qualification_text": qualification}
