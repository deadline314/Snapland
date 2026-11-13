extends RefCounted
class_name CrabMarblesDriver

const Model = preload("res://game/minigames/crab_marbles_model.gd")
const View = preload("res://game/minigames/crab_marbles_view.gd")
const KEYS := {KEY_A: "aim_left", KEY_LEFT: "aim_left", KEY_D: "aim_right", KEY_RIGHT: "aim_right", KEY_SPACE: "charge", KEY_W: "charge", KEY_UP: "charge"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate the slope patches and gate positions.
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

## Aim is held; charging starts when the first owner presses and fires when the last releases.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	var was_charging: bool = _owners.values().has("charge")
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		_owners[source] = command
	else:
		_owners.erase(source)
	var held: Array = _owners.values()
	_model.set_aim_input(float(held.has("aim_right")) - float(held.has("aim_left")))
	var charging: bool = held.has("charge")
	if charging != was_charging:
		_model.set_charging(charging)

## Lifecycle interruptions cancel a charge instead of firing it.
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
	state["progress_text"] = "蟹門 %d / 3 · 彈珠剩 %d" % [state.opened, state.balls_left]
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
	var devil_rule := "小惡魔需讓一顆彈珠反彈後，同一次撞開兩扇蟹門，並開完三扇。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "彈珠得分", "rule": "每扇蟹門 100 分；三扇全開時，每顆沒用到的彈珠再加 50 分。", "rows": [
		{"key": "gates", "label": "撞開蟹門", "amount": state.opened * Model.GATE_POINTS, "count": state.opened},
		{"key": "spare", "label": "剩餘彈珠", "amount": state.balls_left * Model.SPARE_POINTS if state.success else 0, "count": state.balls_left},
		{"key": "shots", "label": "出手次數（不扣分）", "amount": 0, "count": state.shots.size(), "progress_only": true}], "qualification_text": qualification}
