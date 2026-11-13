extends RefCounted
class_name TideLockDriver

const Model = preload("res://game/minigames/tide_lock_model.gd")
const View = preload("res://game/minigames/tide_lock_view.gd")
const KEYS := {KEY_Q: "lower", KEY_E: "upper", KEY_A: "drain", KEY_D: "fill", KEY_R: "helper"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries change ship lengths, drafts, arrival spacing and the outer tide.
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

## Every command is a toggle that acts once per press of its owner.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if not pressed:
		_owners.erase(source)
		return
	if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
		return
	_owners[source] = command
	match command:
		"lower": _model.toggle_gate(false)
		"upper": _model.toggle_gate(true)
		"drain": _model.toggle_valve(-1)
		"fill": _model.toggle_valve(1)
		"helper": _model.toggle_helper()

func clear_input() -> void:
	_owners.clear()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	_model.step(delta)
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "過閘 %d／%d · 擱淺 %d" % [state.passed, state.ships.size(), state.groundings]
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
	var devil_rule := "小惡魔需一次蓄水同時送兩艘船上港，而且全程沒有船擱淺。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	var water: int = roundi(maxf(0.0, float(state.basin) - Model.BASIN_MIN) * 100.0) if state.success else 0
	return {"total": state.score, "label": "合閘得分", "rule": "每船過閘 100；安全關水 100 加港池存水；一次蓄水送雙船再加 100；擱淺扣 50、鳴笛扣 20。", "rows": [
		{"key": "ships", "label": "過閘船隻", "amount": state.passed * Model.SHIP_POINTS, "count": state.passed},
		{"key": "close", "label": "安全關水與存水", "amount": Model.CLOSE_POINTS + water if state.success else 0, "count": int(state.success)},
		{"key": "pair", "label": "一次蓄水送雙船", "amount": Model.DEVIL_POINTS if state.devil else 0, "count": int(state.devil)},
		{"key": "ground", "label": "擱淺", "amount": -state.groundings * Model.GROUND_PENALTY, "count": state.groundings},
		{"key": "horn", "label": "鳴笛抗議", "amount": -state.horns * Model.HORN_PENALTY, "count": state.horns}], "qualification_text": qualification}
