extends RefCounted
class_name SugarBridgeDriver

const Model = preload("res://game/minigames/sugar_bridge_model.gd")
const View = preload("res://game/minigames/sugar_bridge_view.gd")
const KEYS := View.KEYS
const MOVE_SPEED := 3.5
var _model = Model.new()
var _view: Control
var _owners: Dictionary = {}
var _drag_owner := ""
var _rounds := 0
var _time_phase := "noon"
var _reduced_motion := false

func reset(assisted: bool, time_phase: String) -> void:
	clear_input()
	_model.reset(assisted, _rounds)
	_rounds += 1
	present(time_phase, _reduced_motion)

func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command_requested.connect(_command)
		_view.pointer_requested.connect(_pointer)
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
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return _pointer("move", design_point, source)
	return _pointer("press" if event.pressed else "release", design_point, source)

func _command(command: String, pressed: bool, source: String) -> void:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return
	if not pressed:
		_owners.erase(source)
		return
	if _owners.has(source) or _model.snapshot().ended or not (View.COMMANDS.has(command) or command in ["left", "right", "up", "down"]):
		return
	_owners[source] = command
	match command:
		"next":
			_model.select_next(1)
			_drag_owner = ""
		"grab":
			if _drag_owner != "" and _drag_owner != "keyboard":
				return
			if _model.snapshot().grabbed >= 0:
				_model.release_selected()
				_drag_owner = ""
			else:
				_model.grab_selected()
				_drag_owner = "keyboard"
		"pin":
			_model.toggle_pin()
			if _model.snapshot().grabbed < 0:
				_drag_owner = ""
		"load": _model.load_ball()
		"recall":
			_model.recall_selected()
			_drag_owner = ""
		"helper":
			_model.cycle_helper()
			if _model.snapshot().grabbed < 0:
				_drag_owner = ""

func _pointer(action: String, point: Vector2, source: String) -> bool:
	if action == "release":
		var handled := _owners.has(source) or _drag_owner == source
		_owners.erase(source)
		if _drag_owner == source:
			if point.is_finite():
				_model.move_selected(View.work_point(point))
				_model.release_selected()
			else:
				_model.clear_input()
			_drag_owner = ""
		return handled
	if not point.is_finite() or _model.snapshot().ended:
		return false
	if action == "move":
		if _drag_owner != source:
			return false
		_model.move_selected(View.work_point(point))
		return true
	if action != "press" or _owners.has(source) or _drag_owner == source:
		return false
	var command: String = View.command_at(point)
	if not command.is_empty():
		_command(command, true, source)
		return true
	if not _drag_owner.is_empty() or not View.STAGE.has_point(point):
		return false
	var state: Dictionary = _model.snapshot()
	var endpoint := View.endpoint_at(point, state)
	if endpoint < 0:
		return false
	for i in 4:
		if int(_model.snapshot().selected) == endpoint:
			break
		_model.select_next(1)
	_model.grab_selected()
	_drag_owner = source
	return true

func clear_input() -> void:
	_owners.clear()
	_drag_owner = ""
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	if is_finite(delta) and delta > 0.0 and _drag_owner == "keyboard":
		var direction := Vector2(int(_owners.values().has("right")) - int(_owners.values().has("left")), int(_owners.values().has("up")) - int(_owners.values().has("down")))
		if not direction.is_zero_approx():
			var state: Dictionary = _model.snapshot()
			if int(state.grabbed) >= 0:
				_model.move_selected(Vector2(state.endpoints[int(state.selected)].position) + direction.normalized() * MOVE_SPEED * minf(delta, 0.25))
	_model.step(delta)
	if _model.snapshot().ended:
		clear_input()
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "送達 %d／3 · 落球 %d · 斷帶 %d" % [state.delivered, state.falls, state.breaks]
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
	var devil_rule := "小惡魔需先彈中料斗，再用同一條糖帶實際運送，並送達三球；回收會清除該帶資格。"
	var qualification := "移動、固定、上料或彈射後正常結算可得普通拍貼；" + devil_rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else devil_rule)
	elif state.ended:
		qualification = "本回合未參與操作，沒有普通拍貼資格。" + devil_rule
	return {"total": state.score, "label": "運糖得分", "rule": "每球送達 100，三球成功 100，先彈後橋 100；落球與斷帶每次各扣 20，最低零。", "rows": [
		{"key": "balls", "label": "送達運料球", "amount": state.delivered * 100, "count": state.delivered},
		{"key": "success", "label": "三球完成", "amount": 100 if state.success else 0, "count": int(state.success)},
		{"key": "sling", "label": "同帶先彈後橋", "amount": 100 if state.devil else 0, "count": int(state.devil)},
		{"key": "falls", "label": "落球", "amount": -state.falls * 20, "count": state.falls},
		{"key": "breaks", "label": "斷帶", "amount": -state.breaks * 20, "count": state.breaks}], "qualification_text": qualification}
