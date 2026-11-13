extends RefCounted
class_name ShellTideDriver

const Model = preload("res://game/minigames/shell_tide_model.gd")
const View = preload("res://game/minigames/shell_tide_view.gd")
const SHELL_KEYS := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_A: 0, KEY_S: 1, KEY_D: 2, KEY_F: 3}
const KEYS := {KEY_W: "wait", KEY_UP: "wait", KEY_Q: "earlier", KEY_E: "later"}
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries alternate tempo and the silent beats.
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
		if SHELL_KEYS.has(code):
			_command("shell_%d" % SHELL_KEYS[code], event.pressed, "key:%d" % code)
			return true
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

## Shells are held (long notes); a shell sounds while any owner holds it.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if pressed:
		if not View.COMMANDS.has(command) or _owners.has(source) or _model.snapshot().ended:
			return
		var already: bool = _owners.values().has(command)
		_owners[source] = command
		if command.begins_with("shell_"):
			if not already:
				_model.press(int(command.trim_prefix("shell_")))
			return
		match command:
			"wait": _model.wait_long_wave()
			"earlier": _model.calibrate(-1)
			"later": _model.calibrate(1)
		return
	if not _owners.has(source):
		return
	var released: String = _owners[source]
	_owners.erase(source)
	if released.begins_with("shell_") and not _owners.values().has(released):
		_model.release(int(released.trim_prefix("shell_")))

func clear_input() -> void:
	_owners.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func consume_notes() -> Array[int]:
	return _model.consume_notes()

func step(delta: float) -> Dictionary:
	_model.step(delta)
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "潮聲 %d / 3 段 · 誤觸靜默 %d" % [state.passed_count, state.rest_presses]
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
	var devil_rule := "小惡魔需三段都完成，而且所有靜默拍都沒有誤觸。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	return {"total": state.score, "label": "聽潮得分", "rule": "每個敲中的音 50 分、拍心再加 25；每段完成 100 分，趁短浪回應再加 50。", "rows": [
		{"key": "hits", "label": "敲中音符", "amount": state.hits * Model.HIT_POINTS + state.perfects * Model.PERFECT_POINTS, "count": state.hits},
		{"key": "phrases", "label": "完成段落", "amount": state.passed_count * Model.PHRASE_POINTS + state.short_passes * Model.SHORT_WAVE_POINTS, "count": state.passed_count},
		{"key": "rests", "label": "誤觸靜默（不扣分）", "amount": 0, "count": state.rest_presses, "progress_only": true}], "qualification_text": qualification}
