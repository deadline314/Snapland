extends RefCounted
class_name TideSandbarDriver

const Model = preload("res://game/minigames/tide_sandbar_model.gd")
const View = preload("res://game/minigames/tide_sandbar_view.gd")
const KEYS := {KEY_W: "up", KEY_UP: "up", KEY_S: "down", KEY_DOWN: "down", KEY_A: "left", KEY_LEFT: "left",
	KEY_D: "right", KEY_RIGHT: "right", KEY_SHIFT: "run", KEY_SPACE: "mark", KEY_E: "mark", KEY_T: "tide_pause"}
const HELD := ["up", "down", "left", "right", "run"]
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate the tide period and the safe highland side.
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

func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
		match command:
			"mark": _model.interact()
			"tide_pause": _model.toggle_tide_pause()
	else:
		_owners.erase(source)
	var held: Array = _owners.values()
	var direction := Vector2(float(held.has("right")) - float(held.has("left")), float(held.has("down")) - float(held.has("up")))
	_model.set_move(direction.normalized())
	_model.set_running(held.has("run"))

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
	state["progress_text"] = "礁石 %d / 3 · 落水 %d" % [state.reefs_marked, state.falls]
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
	var devil_rule := "小惡魔需在第一輪潮內先標好高地與沙丘回路，再標三礁並回營。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "沙路得分", "rule": "每座礁插上路標 100 分，三礁後回營再加 100 分；落水不扣分。", "rows": [
		{"key": "reefs", "label": "連接礁石", "amount": state.reefs_marked * Model.REEF_POINTS, "count": state.reefs_marked},
		{"key": "return", "label": "平安回營", "amount": Model.RETURN_POINTS if state.success else 0, "count": int(state.success)},
		{"key": "falls", "label": "落水被拉回（不扣分）", "amount": 0, "count": state.falls, "progress_only": true}], "qualification_text": qualification}
