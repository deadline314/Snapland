extends RefCounted

const Model = preload("res://game/minigames/stall_loadout_model.gd")
const View = preload("res://game/minigames/stall_loadout_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const REPEAT_DELAY := 0.30
const REPEAT_INTERVAL := 0.12
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const KEYS := {
	KEY_UP: View.NORTH, KEY_W: View.NORTH, KEY_RIGHT: View.EAST, KEY_D: View.EAST,
	KEY_DOWN: View.SOUTH, KEY_S: View.SOUTH, KEY_LEFT: View.WEST, KEY_A: View.WEST,
	KEY_E: View.PLACE, KEY_ENTER: View.PLACE, KEY_Q: View.ROTATE, KEY_R: View.LEVEL,
	KEY_F: View.PHASE, KEY_U: View.UNDO, KEY_C: View.CYCLE,
}
const GAMEPAD := {
	JOY_BUTTON_DPAD_UP: View.NORTH, JOY_BUTTON_DPAD_RIGHT: View.EAST,
	JOY_BUTTON_DPAD_DOWN: View.SOUTH, JOY_BUTTON_DPAD_LEFT: View.WEST,
	JOY_BUTTON_A: View.PLACE, JOY_BUTTON_X: View.ROTATE, JOY_BUTTON_Y: View.LEVEL,
	JOY_BUTTON_RIGHT_SHOULDER: View.PHASE, JOY_BUTTON_BACK: View.UNDO, JOY_BUTTON_LEFT_SHOULDER: View.CYCLE,
}

static var _next_session_layout := 0
var _next_layout: int
var _model := Model.new()
var _view: View
var _state: Dictionary
var _notes: Array[int] = []
var _pressed: Dictionary[String, int] = {}
var _repeat_source := ""
var _repeat_time := 0.0
var _selected := 0
var _focus := Vector2i.ZERO
var _layer := 0
var _angle := 0
var _hinted_cell := Vector2i(-1, -1)


func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_geometry()


func reset(assisted: bool, _clock: String) -> void:
	clear_input()
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout
	_notes.clear()
	_selected = 0
	_focus = Vector2i.ZERO
	_layer = 0
	_angle = 0
	_hinted_cell = Vector2i(-1, -1)
	_refresh_geometry()


func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command.connect(_command)
		_view.piece_tapped.connect(_select)
		_view.cell_tapped.connect(_tap_cell)
		_view.pointer_cancelled.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		_view.present(_state)
	return _view


func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not KEYS.has(code):
			return false
		if event.is_canceled():
			clear_input()
		elif not event.echo:
			_command(KEYS[code], event.pressed, "key:%d" % code)
		return true
	if event is InputEventJoypadButton:
		if not GAMEPAD.has(event.button_index):
			return false
		_command(GAMEPAD[event.button_index], event.pressed, "pad:%d:%d" % [event.device, event.button_index])
		return true
	if is_instance_valid(_view):
		return _view.handle_pointer(event, point)
	var source := Surface.pointer_source(event)
	if source.is_empty():
		return false
	if event.is_canceled():
		if not _pressed.has(source):
			return false
		clear_input()
		return true
	if not event.pressed:
		if not _pressed.has(source):
			return false
		_command(-1, false, source)
		return true
	var action := Surface.hit_slot(point)
	if View.hit_undo(point):
		action = View.UNDO
	if View.action_available(action, _state):
		_command(action, true, source)
		return true
	var piece := View.hit_piece(point)
	if piece >= 0 and View.action_available(View.CYCLE, _state):
		_select(piece)
		return true
	var cell := View.hit_cell(point, _layer)
	if cell.x >= 0 and View.action_available(View.NORTH, _state):
		_tap_cell(cell)
		return true
	return false


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		if _pressed.erase(source):
			if _repeat_source == source:
				_repeat_source = ""
			_update_button_mask()
		return
	if _pressed.has(source) or not View.action_available(action, _state):
		return
	_pressed[source] = action
	_hinted_cell = Vector2i(-1, -1)
	_repeat_source = ""
	_apply(action)
	if action >= View.NORTH and action <= View.WEST:
		_repeat_source = source
		_repeat_time = REPEAT_DELAY


func _apply(action: int) -> void:
	var placed := false
	match action:
		View.NORTH, View.EAST, View.SOUTH, View.WEST:
			_focus = (_focus + DIRECTIONS[action]).clamp(Vector2i.ZERO, Vector2i(Model.DECK.x - 1, Model.DECK.z - 1))
		View.PLACE:
			if _state.secured:
				if _model.finish():
					_notes.append(83)
			else:
				placed = _model.place(_selected, Vector3i(_focus.x, _layer, _focus.y), _angle)
		View.ROTATE: _angle = (_angle + 1) % 4
		View.LEVEL: _layer = (_layer + 1) % Model.DECK.y
		View.PHASE:
			if _state.secured:
				if _model.extract_pot():
					_notes.append(79)
			elif _model.toggle_straps():
				_notes.append(72)
		View.UNDO:
			if _state.secured:
				_model.toggle_straps()
			else:
				_model.undo()
		View.CYCLE:
			_select((_selected + 1) % Model.PIECE_COUNT)
			return
	if placed:
		_notes.append(65)
	_refresh_geometry()


func _select(piece: int) -> void:
	if not View.action_available(View.CYCLE, _state) or piece < 0 or piece >= Model.PIECE_COUNT:
		return
	_selected = piece
	_angle = int(_state.pieces[piece].angle)
	var anchor: Vector3i = _state.pieces[piece].anchor
	_layer = 0
	if anchor != Model.UNPLACED:
		_focus = Vector2i(anchor.x, anchor.z)
		_layer = anchor.y
	_hinted_cell = Vector2i(-1, -1)
	_repeat_source = ""
	_refresh_geometry()


func _tap_cell(cell: Vector2i) -> void:
	if not View.action_available(View.NORTH, _state) or cell.x < 0 or cell.y < 0 or cell.x >= Model.DECK.x or cell.y >= Model.DECK.z:
		return
	_repeat_source = ""
	_focus = cell
	if _hinted_cell == cell:
		_hinted_cell = Vector2i(-1, -1)
		_apply(View.PLACE)
	else:
		_hinted_cell = cell
		_refresh_geometry()


func clear_input() -> void:
	_pressed.clear()
	_repeat_source = ""
	_hinted_cell = Vector2i(-1, -1)
	_update_button_mask()
	if is_instance_valid(_view):
		_view.clear_pointers()


func step(delta: float) -> Dictionary:
	if _model.step(delta):
		_refresh_geometry()
	if not _repeat_source.is_empty() and not _state.ended and is_finite(delta) and delta > 0.0:
		_repeat_time -= delta
		if _repeat_time <= 0.0:
			_repeat_time = REPEAT_INTERVAL
			_apply(_pressed[_repeat_source])
	_update_clock()
	return _state


func _refresh_geometry() -> void:
	_state = _model.snapshot()
	_state.selected = _selected
	_state.focus = _focus
	_state.layer = _layer
	_state.angle = _angle
	var anchor := Vector3i(_focus.x, _layer, _focus.y)
	var ghost: Array[Vector3i] = []
	if not _state.secured and not _state.ended:
		for cell in _model.shape(_selected, _angle):
			ghost.append(anchor + cell)
	_state.ghost = ghost
	_state.fit = _model.place_reason(_selected, anchor, _angle) if not ghost.is_empty() else &"locked"
	_state.progress_text = "湯鍋已卸" if _state.devil else "裝妥 %d／%d 件" % [_state.placed, Model.PIECE_COUNT]
	_state.feedback_text = _state.feedback
	_update_clock()
	_update_button_mask()


func _update_clock() -> void:
	var elapsed := _model.elapsed()
	var remaining := maxf(0.0, Model.TIME_LIMIT - elapsed)
	if _state.get("elapsed", -1.0) == elapsed and _state.has("time_text"):
		return
	_state.elapsed = elapsed
	_state.remaining = remaining
	if _state.get("time_second", -1) != ceili(remaining):
		_state.time_second = ceili(remaining)
		_state.time_text = "不限時" if _state.assisted else "%d 秒" % _state.time_second


func _update_button_mask() -> void:
	var mask := 0
	for action in _pressed.values():
		mask |= 1 << action
	if _state != null:
		_state.control_mask = mask


func snapshot() -> Dictionary:
	return _state


func present(phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion, phase)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func score_summary(practice: bool) -> Dictionary:
	return {
		"total": _state.score, "label": "收攤得分",
		"rule": "穩固裝車得 450 分。從保留的開口先卸湯鍋，其餘攤具仍穩固，加 150 分。",
		"rows": [
			{"key": "packed", "label": "裝妥綁帶", "amount": int(_state.success) * 450, "count": int(_state.success)},
			{"key": "unloaded", "label": "先卸湯鍋", "amount": int(_state.devil) * 150, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合放妥過攤具，自然結算可收藏普通卡。",
	}
