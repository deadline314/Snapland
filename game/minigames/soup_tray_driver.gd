extends RefCounted

const Model = preload("res://game/minigames/soup_tray_model.gd")
const View = preload("res://game/minigames/soup_tray_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const SLIDE_HOLD_SECONDS := 0.12

const KEYS := {
	KEY_W: View.WALK, KEY_SPACE: View.BRAKE, KEY_A: View.SAFE, KEY_D: View.CHANNEL,
	KEY_E: View.ACTION, KEY_R: View.RETRY,
	KEY_UP: View.LEAN_FORWARD, KEY_LEFT: View.LEAN_LEFT,
	KEY_DOWN: View.LEAN_BACK, KEY_RIGHT: View.LEAN_RIGHT,
}
const GAMEPAD := {
	JOY_BUTTON_LEFT_SHOULDER: View.WALK, JOY_BUTTON_RIGHT_SHOULDER: View.BRAKE,
	JOY_BUTTON_X: View.ROUTE, JOY_BUTTON_A: View.ACTION, JOY_BUTTON_Y: View.RETRY,
	JOY_BUTTON_DPAD_UP: View.LEAN_FORWARD, JOY_BUTTON_DPAD_LEFT: View.LEAN_LEFT,
	JOY_BUTTON_DPAD_DOWN: View.LEAN_BACK, JOY_BUTTON_DPAD_RIGHT: View.LEAN_RIGHT,
}

static var _next_session_layout := 0
var _next_layout: int
var _model := Model.new()
var _view: View
var _pressed: Dictionary[String, int] = {}
var _mask := 0
var _state: Dictionary
var _gap_hold_since := -1.0


func _init() -> void:
	_next_layout = _next_session_layout
	_next_session_layout = 1 - _next_session_layout
	_refresh_state()


func reset(assisted: bool, _clock: String) -> void:
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
	if not View.action_available(action, _state):
		return false
	_command(action, true, source)
	return true


func _command(action: int, pressed: bool, source: String) -> void:
	if not pressed:
		var released: int = _pressed.get(source, -1)
		if not _pressed.erase(source):
			return
		_sync_controls()
		if released == View.ACTION and not _held(View.ACTION) and _gap_hold_since >= 0.0:
			var tapped: bool = _state.elapsed - _gap_hold_since < SLIDE_HOLD_SECONDS
			_gap_hold_since = -1.0
			if tapped and _state.stage == Model.GAP:
				_perform_action()
		_refresh_state()
		return
	if _pressed.has(source) or not View.action_available(action, _state):
		return
	_pressed[source] = action
	match action:
		View.SAFE: _model.select_route(Model.SAFE)
		View.CHANNEL: _model.select_route(Model.CHANNEL)
		View.ROUTE:
			if _state.retry_ready:
				_retry()
			else:
				_model.select_route(Model.SAFE if _state.route == Model.CHANNEL else Model.CHANNEL)
		View.ACTION:
			if _state.stage == Model.GAP and not _state.return_ready:
				if _gap_hold_since < 0.0:
					_gap_hold_since = _state.elapsed
			else:
				_perform_action()
		View.RETRY: _retry()
	_sync_controls()
	_refresh_state()


func _perform_action() -> void:
	_gap_hold_since = -1.0
	if not _model.action():
		return
	_refresh_state()
	if _state.stage in [Model.FLIGHT, Model.ENDED] or _state.route_selectable:
		_release_motion()
		_sync_controls()


func _retry() -> void:
	_model.retry_bowl()
	_release_motion()


func _release_motion() -> void:
	for source in _pressed.keys():
		match _pressed[source]:
			View.WALK, View.BRAKE, View.LEAN_FORWARD, View.LEAN_LEFT, View.LEAN_BACK, View.LEAN_RIGHT:
				_pressed.erase(source)


func _sync_controls() -> void:
	_mask = 0
	for action in _pressed.values():
		_mask |= 1 << action
	_model.set_walk(_held(View.WALK))
	_model.set_brake(_held(View.BRAKE))
	var lean := Vector2(
		float(_held(View.LEAN_RIGHT)) - float(_held(View.LEAN_LEFT)),
		float(_held(View.LEAN_FORWARD)) - float(_held(View.LEAN_BACK))
	)
	_model.set_lean(lean.limit_length())


func _held(action: int) -> bool:
	return bool(_mask & (1 << action))


func clear_input() -> void:
	_pressed.clear()
	_gap_hold_since = -1.0
	_mask = 0
	_model.clear_input()
	_refresh_state()
	if is_instance_valid(_view):
		_view.clear_pointers()


func step(delta: float) -> Dictionary:
	_model.step(delta)
	_refresh_state()
	if _gap_hold_since >= 0.0:
		if _state.stage != Model.GAP:
			_gap_hold_since = -1.0
			_state.slide_held = false
		elif _state.return_ready and _state.elapsed - _gap_hold_since >= SLIDE_HOLD_SECONDS:
			_perform_action()
			_refresh_state()
	return _state


func _refresh_state() -> void:
	_state = _model.snapshot()
	_state.control_mask = _mask
	_state.slide_held = _gap_hold_since >= 0.0
	_state.progress_text = "已交湯碗 %d / 3" % _state.delivered
	_state.time_text = "%d 秒" % ceili(_state.remaining)
	_state.feedback_text = _state.feedback


func snapshot() -> Dictionary:
	return _state


func consume_notes() -> Array[int]:
	return _model.consume_notes()


func present(phase: String, reduced_motion: bool) -> void:
	if is_instance_valid(_view):
		_view.present(_state, reduced_motion, phase)


func score_summary(practice: bool) -> Dictionary:
	return {
		"total": _state.score, "label": "送湯得分",
		"rule": "每交妥一碗湯得 150 分。三碗都送達，且其中一碗乘回流過槽後交接，加 100 分。",
		"rows": [
			{"key": "bowls", "label": "穩妥交湯", "amount": int(_state.delivered) * Model.DELIVERY_POINTS, "count": _state.delivered},
			{"key": "return", "label": "回流過槽", "amount": int(_state.devil) * Model.CHALLENGE_POINTS, "count": int(_state.devil)},
		],
		"qualification_text": "練習回合不取得拍貼。" if practice else "正式回合實際運送湯碗後，自然結算可收藏普通卡。",
	}
