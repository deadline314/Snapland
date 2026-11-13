extends RefCounted
class_name CargoBalanceDriver

const Model = preload("res://game/minigames/cargo_balance_model.gd")
const View = preload("res://game/minigames/cargo_balance_view.gd")
const KEYS := {KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right", KEY_W: "up", KEY_UP: "up",
	KEY_S: "down", KEY_DOWN: "down", KEY_SPACE: "grab", KEY_F: "strap", KEY_ENTER: "confirm", KEY_KP_ENTER: "confirm"}
const OFFSETS := {"left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, 1), "down": Vector2i(0, -1)}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate crate weights, destinations and port order.
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
		_owners.erase(source)
		return held
	if not design_point.is_finite():
		return false
	var command: String = View.command_at(design_point)
	if command.is_empty():
		return false
	_command(command, true, source)
	return true

## Every command is one discrete action per press.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if not pressed:
		_owners.erase(source)
		return
	if _owners.has(source) or not View.COMMANDS.has(command) or _model.snapshot().ended:
		return
	_owners[source] = command
	if OFFSETS.has(command):
		_model.move_cursor(OFFSETS[command])
		return
	match command:
		"grab": _model.grab()
		"strap": _model.toggle_strap()
		"confirm": _model.confirm()

func clear_input() -> void:
	_owners.clear()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	_model.step(delta)
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "送達 %d / 6 箱 · 安全浪 %d / 4" % [state.delivered, state.safe_waves]
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
	var devil_rule := "小惡魔需四道側浪都在安全傾斜內，且至少一次在航行中移重抗浪，並送達全部貨物。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "配重得分", "rule": "每道在安全傾斜內撐過的側浪 100 分，每箱送達 50 分。", "rows": [
		{"key": "waves", "label": "安全撐過側浪", "amount": state.safe_waves * Model.WAVE_POINTS, "count": state.safe_waves},
		{"key": "crates", "label": "送達貨箱", "amount": state.delivered * Model.CRATE_POINTS, "count": state.delivered},
		{"key": "slides", "label": "箱子滑動（不扣分）", "amount": 0, "count": state.slides, "progress_only": true}], "qualification_text": qualification}
