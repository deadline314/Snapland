extends RefCounted
class_name AnchorChainDriver

const Model = preload("res://game/minigames/anchor_chain_model.gd")
const View = preload("res://game/minigames/anchor_chain_view.gd")
const KEYS := {KEY_Q: "previous", KEY_A: "previous", KEY_LEFT: "previous", KEY_E: "next", KEY_D: "next", KEY_RIGHT: "next",
	KEY_F: "place", KEY_SPACE: "reel", KEY_Z: "undo", KEY_X: "recall", KEY_R: "helper"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries mirror the stranding with another bow direction and reef layout.
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

## Reeling is held; every other command acts once per press.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	var was_reeling: bool = _owners.values().has("reel")
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
		match command:
			"previous": _model.select_next(-1)
			"next": _model.select_next(1)
			"place": _model.place()
			"undo": _model.undo()
			"recall": _model.recall()
			"helper": _model.cycle_helper()
	else:
		_owners.erase(source)
	var reeling: bool = _owners.values().has("reel")
	if reeling != was_reeling:
		_model.set_reeling(reeling)

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
	state["progress_text"] = "還差 %d° · 斷鏈 %d" % [roundi(absf(rad_to_deg(state.remaining_turn))), state.breaks]
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
	var devil_rule := "小惡魔需在同一顆礁石連繞兩圈、讓鏈條在同點兩次變向，全程不斷鏈並脫困。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "救援得分", "rule": "脫困 300 分，同礁兩次變向脫困再加 100；每次斷鏈扣 50。", "rows": [
		{"key": "freed", "label": "貨船脫困", "amount": Model.FREE_POINTS if state.success else 0, "count": int(state.success)},
		{"key": "double", "label": "同礁兩次變向", "amount": 100 if state.devil else 0, "count": int(state.devil)},
		{"key": "breaks", "label": "斷鏈", "amount": -state.breaks * Model.BREAK_PENALTY, "count": state.breaks}], "qualification_text": qualification}
