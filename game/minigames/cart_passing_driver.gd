extends RefCounted

const Model = preload("res://game/minigames/cart_passing_model.gd")
const View = preload("res://game/minigames/cart_passing_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const SLIDE_SECONDS := 0.10
const REPEAT_DELAY := 0.29
const REPEAT_INTERVAL := 0.15
const KEYS := {
	KEY_Q:View.SELECT, KEY_SPACE:View.UNLOAD, KEY_Z:View.UNDO, KEY_R:View.RESTART,
	KEY_LEFT:View.WEST, KEY_A:View.WEST, KEY_UP:View.NORTH, KEY_W:View.NORTH,
	KEY_RIGHT:View.EAST, KEY_D:View.EAST, KEY_DOWN:View.SOUTH, KEY_S:View.SOUTH,
}
const GAMEPAD := {
	JOY_BUTTON_X:View.SELECT, JOY_BUTTON_LEFT_SHOULDER:View.SELECT, JOY_BUTTON_A:View.UNLOAD,
	JOY_BUTTON_Y:View.UNDO, JOY_BUTTON_RIGHT_SHOULDER:View.RESTART,
	JOY_BUTTON_DPAD_LEFT:View.WEST, JOY_BUTTON_DPAD_UP:View.NORTH,
	JOY_BUTTON_DPAD_RIGHT:View.EAST, JOY_BUTTON_DPAD_DOWN:View.SOUTH,
}

static var _next_session_layout := 0
var _model := Model.new()
var _view: View
var _state: Dictionary
var _participated := false
var _next_layout: int
var _pressed: Dictionary[String, int] = {}
var _repeat_source := ""
var _repeat_left := 0.0
var _queued_action := -1
var _attempted_action := -1
var _restart_armed := false
var _reduced_motion := false
var _slide_left := 0.0
var _slide_cart := -1
var _slide_from := Vector2.ZERO


func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_state()


func reset(assisted: bool, _clock: String) -> void:
	_participated = false
	clear_input()
	_model.reset(assisted, _next_layout)
	_next_layout = 1 - _next_layout
	_refresh_state()


func create_view() -> Control:
	if DisplayServer.get_name() == "headless":
		return null
	if not is_instance_valid(_view):
		_view = View.new()
		_view.command.connect(_command)
		_view.board_command.connect(_dispatch)
		_view.pointer_cancelled.connect(clear_input)
		_view.tree_exiting.connect(clear_input)
		_view.present(_state, _reduced_motion)
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
	if View.action_available(action, _state):
		_command(action, true, source)
		return true
	var board_action := View.hit_board_command(point, _state)
	if board_action < 0:
		return false
	_dispatch(board_action)
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		if _pressed.erase(source):
			if _repeat_source == source:
				_repeat_source = ""
			_refresh_state()
		return
	if _pressed.has(source) or not View.action_available(action, _state):
		return
	_pressed[source] = action
	_dispatch(action)
	if View.STEPS.has(action):
		_repeat_source = source
		_repeat_left = REPEAT_DELAY


func _dispatch(action: int) -> void:
	_repeat_source = ""
	if _slide_left > 0.0:
		# One buffered tap can follow the rendered step. Holding a direction has a separate repeat cadence.
		_queued_action = action
	else:
		_apply(action)


func _apply(action: int) -> void:
	if _state.ended:
		return
	if action != View.RESTART:
		_restart_armed = false
	_attempted_action = action if View.STEPS.has(action) else -1
	var selected: int = _state.selected
	var before: Rect2i = _state.carts[selected].rect
	if View.STEPS.has(action):
		_model.move(View.STEPS[action])
	elif action == View.SELECT:
		_model.cycle_selection()
	elif action == View.UNLOAD:
		_model.unload()
	elif action == View.UNDO:
		_model.undo()
	elif action == View.RESTART:
		if _restart_armed:
			_model.restart()
			_restart_armed = false
		else:
			_restart_armed = true
	elif action >= View.POCKET_ACTION:
		_model.assist_toward_pocket(action - View.POCKET_ACTION)
	elif action >= View.CART_ACTION:
		_model.select(action - View.CART_ACTION)
	_refresh_state()
	var movement_action := View.STEPS.has(action) or action >= View.POCKET_ACTION
	var after: Rect2i = _state.carts[selected].rect
	if movement_action and before.position != after.position:
		_participated = true
		if not _reduced_motion:
			_slide_cart = selected
			_slide_from = Vector2(before.position)
			_slide_left = SLIDE_SECONDS
		_refresh_state()


func step(delta: float) -> Dictionary:
	var safe_delta := maxf(0.0, delta) if is_finite(delta) else 0.0
	_model.step(safe_delta)
	_slide_left = maxf(0.0, _slide_left - safe_delta)
	_repeat_left = maxf(0.0, _repeat_left - safe_delta)
	_refresh_state()
	if _state.ended:
		return _state
	if _slide_left > 0.0:
		return _state
	if _queued_action >= 0:
		var action := _queued_action
		_queued_action = -1
		_apply(action)
	elif not _repeat_source.is_empty() and _repeat_left == 0.0 and _pressed.has(_repeat_source):
		_repeat_left = REPEAT_INTERVAL
		_apply(_pressed[_repeat_source])
	return _state


func clear_input() -> void:
	_pressed.clear()
	_repeat_source = ""
	_repeat_left = 0.0
	_queued_action = -1
	_attempted_action = -1
	_restart_armed = false
	_slide_left = 0.0
	_refresh_state()
	if is_instance_valid(_view):
		_view.clear_pointers()


func _refresh_state() -> void:
	_state = _model.snapshot()
	_state.ended = _state.status != &"live"
	_state.success = _state.status == &"won"
	_state.devil = _state.qualified
	_state.participated = _participated
	_state.ordinary_eligible = _state.ended and _participated
	_state.mistakes = 0
	_state.progress_text = "卸貨 %d / %d" % [_state.deliveries, Model.CART_COUNT]
	_state.time_text = "不限時" if _state.assisted else "%d 秒" % ceili(_state.time_remaining)
	_state.feedback_text = View.guide(_state) if not _restart_armed else View.RESTART_GUIDE
	_state.restart_armed = _restart_armed
	_state.attempted_action = _attempted_action
	_state.slide_cart = _slide_cart if _slide_left > 0.0 else -1
	_state.slide_from = _slide_from
	_state.slide_weight = _slide_left / SLIDE_SECONDS
	var mask := 0
	for action: int in _pressed.values():
		mask |= 1 << action
	_state.control_mask = mask


func snapshot() -> Dictionary:
	return _state


func present(phase: String, reduced_motion: bool) -> void:
	if reduced_motion and not _reduced_motion:
		_slide_left = 0.0
		_refresh_state()
	_reduced_motion = reduced_motion
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion, phase)


func score_summary(practice: bool) -> Dictionary:
	var deliveries: int = _state.deliveries * Model.DELIVERY_POINTS
	var challenge: int = int(_state.qualified) * Model.CHALLENGE_POINTS
	return {
		"total":_state.score, "label":"卸貨得分",
		"rule":"每輛卸貨得 150 分。只進一次側袋、兩組對向車完整交會、三車卸完且未重置，加 100 分。",
		"rows":[
			{"key":"delivery", "label":"卸貨完成", "amount":deliveries, "count":_state.deliveries},
			{"key":"passing", "label":"一次側袋交會", "amount":challenge, "count":int(_state.qualified)},
		],
		"qualification_text":"練習回合不取得拍貼。" if practice else "正式回合有合法移車，自然結算可收藏普通卡。",
	}
