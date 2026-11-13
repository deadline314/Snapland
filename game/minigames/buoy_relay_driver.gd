extends RefCounted
class_name BuoyRelayDriver

const Model = preload("res://game/minigames/buoy_relay_model.gd")
const View = preload("res://game/minigames/buoy_relay_view.gd")
const KEYS := {KEY_SPACE: "action", KEY_W: "action", KEY_UP: "action", KEY_E: "action"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate tube spacing and the tide push.
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

## One action shared by keys and pointer: pressed while any owner holds it.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	var was_down := not _owners.is_empty()
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
	else:
		_owners.erase(source)
	var down := not _owners.is_empty()
	if down != was_down:
		_model.set_action(down)

## Interruptions cancel a charge or a reel instead of throwing.
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
	state["progress_text"] = "郵筒 %d / 3 · 滑脫 %d" % [state.delivered, state.slips]
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
	var devil_rule := "小惡魔需用一個浮環同時套住兩個郵筒，並送完三個郵筒。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "接力得分", "rule": "每個送上岸的郵筒 100 分；每次遠投省下一次交接再加 50 分。", "rows": [
		{"key": "tubes", "label": "送上岸", "amount": state.delivered * Model.TUBE_POINTS, "count": state.delivered},
		{"key": "direct", "label": "遠投省交接", "amount": state.direct * Model.DIRECT_BONUS, "count": state.direct},
		{"key": "slips", "label": "滑脫與落空（不扣分）", "amount": 0, "count": state.mistakes, "progress_only": true}], "qualification_text": qualification}
