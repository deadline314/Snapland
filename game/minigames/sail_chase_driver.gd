extends RefCounted
class_name SailChaseDriver

const Model = preload("res://game/minigames/sail_chase_model.gd")
const View = preload("res://game/minigames/sail_chase_view.gd")
const KEYS := {KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right", KEY_Q: "sheet_in", KEY_E: "sheet_out"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate the wind shifts and driftwood.
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
	if not design_point.is_finite():
		return false
	var command: String = View.command_at(design_point)
	if command.is_empty():
		return false
	_command(command, true, source)
	return true

## Rudder and sheet are held controls combined across keys and pointers.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
	else:
		_owners.erase(source)
	var held: Array = _owners.values()
	_model.set_rudder(float(held.has("right")) - float(held.has("left")))
	_model.set_trim_input(float(held.has("sheet_out")) - float(held.has("sheet_in")))

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
	state["progress_text"] = "追上燈船 %d / %d · 撞浮木 %d" % [state.catches, Model.CATCHES, state.bumps]
	state["time_text"] = "%d 秒" % ceili(state.remaining)
	state["feedback_text"] = str(state.feedback)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(snapshot(), time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state: Dictionary = snapshot()
	var devil_rule := "小惡魔需在順風換舷後 %d 秒內追上燈船一次，並追上三次。" % int(Model.GYBE_WINDOW)
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "追逐得分", "rule": "每追上燈船一次 100 分；撞浮木另記不扣分。", "rows": [
		{"key": "catches", "label": "追上燈船", "amount": state.catches * Model.CATCH_POINTS, "count": state.catches},
		{"key": "gybes", "label": "順風換舷", "amount": 0, "count": state.gybes, "progress_only": true},
		{"key": "bumps", "label": "撞浮木（不扣分）", "amount": 0, "count": state.bumps, "progress_only": true}], "qualification_text": qualification}
