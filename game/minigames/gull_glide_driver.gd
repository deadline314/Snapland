extends RefCounted
class_name GullGlideDriver

const Model = preload("res://game/minigames/gull_glide_model.gd")
const View = preload("res://game/minigames/gull_glide_view.gd")
const TUCK_KEYS := [KEY_SPACE, KEY_S, KEY_DOWN]
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	# Retries swap thermals, feathers, the rock gap and nest height.
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
		if not TUCK_KEYS.has(code):
			return false
		_command("tuck", event.pressed, "key:%d" % code)
		return true
	if is_instance_valid(_view):
		return _view.handle_pointer(event, design_point)
	var source: String = View.pointer_source(event)
	if source.is_empty():
		return false
	if not event.pressed:
		var held := _owners.has(source)
		_command("tuck", false, source)
		return held
	if not design_point.is_finite() or View.command_at(design_point).is_empty():
		return false
	_command("tuck", true, source)
	return true

## Every key, mouse or finger holding tuck owns it; wings spread when the last lets go.
func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if command != "tuck":
		return
	if pressed:
		if _model.snapshot().ended:
			return
		_owners[source] = true
	else:
		_owners.erase(source)
	_model.set_tucked(not _owners.is_empty())

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
	state["progress_text"] = "羽毛 %d／3 · 墜落 %d" % [state.feather_count, state.crashes]
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
	var devil_rule := "小惡魔需收翼穿過岩縫，再展翼帶三根羽毛回巢。"
	var qualification := "回合結束可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	var home_bonus: int = Model.HOME_POINTS + int(Model.ROUND_SECONDS - float(state.elapsed)) if state.success else 0
	return {"total": state.score, "label": "借風得分", "rule": "每根羽毛 50；帶齊回巢 200 加剩餘秒數；穿岩縫回巢再加 100；每次墜落扣 30。", "rows": [
		{"key": "feathers", "label": "羽毛", "amount": state.feather_count * Model.FEATHER_POINTS, "count": state.feather_count},
		{"key": "home", "label": "帶齊回巢", "amount": home_bonus, "count": int(state.success)},
		{"key": "gap", "label": "收翼穿岩縫", "amount": Model.DEVIL_POINTS if state.devil else 0, "count": int(state.devil)},
		{"key": "crashes", "label": "墜落", "amount": -state.crashes * Model.CRASH_PENALTY, "count": state.crashes}], "qualification_text": qualification}
