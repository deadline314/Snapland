extends RefCounted
class_name RopeTugDriver

const Model = preload("res://game/minigames/rope_tug_model.gd")
const View = preload("res://game/minigames/rope_tug_view.gd")
const KEYS := {KEY_W: "ahead", KEY_UP: "ahead", KEY_S: "astern", KEY_DOWN: "astern", KEY_A: "left", KEY_LEFT: "left",
	KEY_D: "right", KEY_RIGHT: "right", KEY_Q: "reel_in", KEY_E: "reel_out", KEY_SPACE: "hook"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate pontoon weight and cleat position.
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

## Held commands combine across keys and pointers; hook acts once per press.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
		if command == "hook":
			_model.interact()
	else:
		_owners.erase(source)
	var held: Array = _owners.values()
	_model.set_thrust(float(held.has("ahead")) - float(held.has("astern")))
	_model.set_turn(float(held.has("right")) - float(held.has("left")))
	_model.set_reel(float(held.has("reel_out")) - float(held.has("reel_in")))

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
	state["progress_text"] = "狹灣 %d / 3 · 斷繩 %d" % [state.gates_passed.size(), state.breaks]
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
	var devil_rule := "小惡魔需從第三道的側灣拖過浮台、全程不斷繩並送進碼頭。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "拖船得分", "rule": "浮台每通過一道狹灣 100 分，送進碼頭再加 100 分；斷繩與卡角分開記錄。", "rows": [
		{"key": "gates", "label": "通過狹灣", "amount": state.gates_passed.size() * 100, "count": state.gates_passed.size()},
		{"key": "dock", "label": "送進碼頭", "amount": 100 if state.success else 0, "count": int(state.success)},
		{"key": "breaks", "label": "斷繩（不扣分）", "amount": 0, "count": state.breaks, "progress_only": true},
		{"key": "snags", "label": "卡角（不扣分）", "amount": 0, "count": state.snags, "progress_only": true}], "qualification_text": qualification}
