extends RefCounted
class_name CookieMoldDriver

const Model = preload("res://game/minigames/cookie_mold_model.gd")
const View = preload("res://game/minigames/cookie_mold_view.gd")
const ANGLE_SPEED := 2.8
const TRAY_SPEED := 4.0
var _model = Model.new()
var _view: Control
var _owner := ""
var _held: Dictionary = {}
var _gesture := ""
var _tray_offset := 0.0
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
		if not View.KEYS.has(code):
			return false
		var command: String = "previous" if code == KEY_TAB and event.shift_pressed else View.KEYS[code]
		# Tab release must remove the action originally pressed, even after Shift changes.
		if not event.pressed and code == KEY_TAB:
			command = "previous" if _held.has("previous") else "next"
		return _command(command, event.pressed, "keyboard")
	if is_instance_valid(_view):
		return _view.handle_pointer(event, design_point)
	var source := View.pointer_source(event)
	if source.is_empty():
		return false
	if event is InputEventScreenTouch and event.canceled:
		return _pointer("cancel", design_point, source)
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return _pointer("move", design_point, source)
	return _pointer("press" if event.pressed else "release", design_point, source)

func _command(command: String, pressed: bool, source: String) -> bool:
	if command == "clear" and source == "lifecycle":
		clear_input()
		return true
	if not View.COMMANDS.has(command) or (not _owner.is_empty() and _owner != source):
		return false
	if not pressed:
		if _owner != source or not _held.has(command):
			return false
		_held.erase(command)
		if _held.is_empty():
			_owner = ""
		if command == "tap":
			_model.release_tap()
		if command in ["turn_left", "turn_right"] and not _held.has("turn_left") and not _held.has("turn_right"):
			_model.release_mold()
		return true
	if _model.snapshot().ended or _held.has(command):
		return false
	_owner = source
	_held[command] = true
	match command:
		"previous": _model.select_edge(-1)
		"next": _model.select_edge(1)
		"tap": _model.begin_tap()
		"helper": _model.toggle_helper()
		"retry":
			clear_input()
			_model.retry_cookie()
	return true

func _pointer(action: String, point: Vector2, source: String) -> bool:
	if action == "cancel":
		if _owner != source:
			return false
		clear_input()
		return true
	if action == "release":
		if _owner != source:
			return false
		var gesture := _gesture
		var commands := _held.keys()
		_owner = ""
		_gesture = ""
		_held.clear()
		if not point.is_finite():
			_model.clear_input()
		elif gesture == "tap" or commands.has("tap"):
			_model.release_tap()
		elif gesture == "mold" or commands.has("turn_left") or commands.has("turn_right"):
			_model.release_mold()
		return true
	if not point.is_finite() or _model.snapshot().ended:
		return false
	if action == "move":
		if _owner != source:
			return false
		var state: Dictionary = _model.snapshot()
		if _gesture == "mold":
			_model.set_mold_target(View.mold_angle_at(point, state))
		elif _gesture == "tray":
			_model.set_tray_target(View.work_point(point).x - _tray_offset)
		return true
	if action != "press" or not _owner.is_empty():
		return false
	var command := View.command_at(point)
	if not command.is_empty():
		return _command(command, true, source)
	var state: Dictionary = _model.snapshot()
	if point.distance_to(View.tray_point(state)) <= 42.0:
		_gesture = "tray"
		_tray_offset = View.work_point(point).x - float(state.tray_x)
	elif state.phase == "molded" and point.distance_to(View.mold_handle_point(state)) <= 32.0:
		_gesture = "mold"
		_model.set_mold_target(View.mold_angle_at(point, state))
	elif state.phase == "molded" and View.edge_at(point, state) >= 0:
		_gesture = "tap"
		_model.select_edge_at(state.edges[View.edge_at(point, state)].point)
		_model.begin_tap()
	else:
		return false
	_owner = source
	return true

func clear_input() -> void:
	_owner = ""
	_gesture = ""
	_held.clear()
	_model.clear_input()
	if is_instance_valid(_view):
		_view.clear_pointer_input(false)

func step(delta: float) -> Dictionary:
	if is_finite(delta) and delta > 0.0 and not _owner.is_empty():
		var state: Dictionary = _model.snapshot()
		var turn := int(_held.has("turn_right")) - int(_held.has("turn_left"))
		var slide := int(_held.has("tray_right")) - int(_held.has("tray_left"))
		if turn != 0:
			_model.set_mold_target(float(state.mold_target) + turn * ANGLE_SPEED * minf(delta, 0.25))
		if slide != 0:
			_model.set_tray_target(float(state.tray_target) + slide * TRAY_SPEED * minf(delta, 0.25))
	_model.step(delta)
	if _model.snapshot().ended:
		clear_input()
	return snapshot()

func snapshot() -> Dictionary:
	var state: Dictionary = _model.snapshot()
	state["progress_text"] = "完整接住 %d／6 · 失手 %d" % [state.caught, state.mistakes]
	state["time_text"] = "%d 秒" % ceili(state.remaining)
	state["feedback_text"] = str(state.feedback)
	return state

func present(time_phase: String, reduced_motion: bool) -> void:
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(snapshot(), time_phase, reduced_motion)

func score_summary(practice: bool) -> Dictionary:
	var state := snapshot()
	var rule := "小惡魔需完成六塊，雙層餅借翻轉慣性完整脫模並接住。"
	var qualification := "有效翻模、敲擊或移盤後正常結算可得普通拍貼。" + rule
	if practice:
		qualification = "練習回合不取得拍貼。"
	elif state.ordinary_eligible:
		qualification = "已取得普通拍貼資格。" + ("已達成小惡魔條件。" if state.devil else rule)
	elif state.ended:
		qualification = "本回合未參與操作，沒有普通拍貼資格。" + rule
	return {"total": state.score, "label": "翻模得分", "rule": "每塊接住 100，六塊成功 100，雙層慣性挑戰 100；失手每次扣 20，最低零。", "rows": [
		{"key": "cookies", "label": "完整接住", "amount": state.caught * 100, "count": state.caught},
		{"key": "success", "label": "六塊完成", "amount": 100 if state.success else 0, "count": int(state.success)},
		{"key": "inertia", "label": "雙層慣性", "amount": 100 if state.devil else 0, "count": int(state.devil)},
		{"key": "mistakes", "label": "裂餅與掉落", "amount": -state.mistakes * 20, "count": state.mistakes}], "qualification_text": qualification}
