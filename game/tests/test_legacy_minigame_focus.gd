extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SignView = preload("res://game/minigames/sign_balance_view.gd")
const ShadowView = preload("res://game/minigames/shadow_theatre_view.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Focus regression requires an isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var ids: Array[String] = ["game-013", "game-036"]
	for definition: Dictionary in Catalog.definitions("welcome"):
		ids.append(str(definition.id))
	for id in ids:
		_test_round_clock(id)
	_test_balloon_inputs()
	_test_kite_inputs()
	_test_sign_drag()
	_test_shadow_hold()
	_test_ribbon_hold()
	if failures == 0:
		print("PASS: minigame focus interrupts held input and preserves the paused round (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _test_round_clock(id: String) -> void:
	var session := _new_session(id)
	session._process(0.1)
	var before := Vector4(session.elapsed, session.game_time, session.score, session.count)
	session.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	session.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(session.paused and session.minigame_hud.find_child("PauseOverlay", true, false).visible,
		"%s shows one paused HUD and does not resume on refocus" % id)
	session._process(20.0)
	_check(Vector4(session.elapsed, session.game_time, session.score, session.count) == before and not session.ended,
		"%s does not spend time, progress or score while the window is inactive" % id)
	session._unhandled_input(_key(KEY_ESCAPE, true, true))
	_check(session.paused, "%s does not let a held Escape echo resume play" % id)
	_resume(session)
	session._process(20.0)
	_check(not session.paused and is_equal_approx(session.elapsed, before.x) and is_equal_approx(session.game_time, before.y),
		"%s resumes explicitly and discards the suspended frame delta" % id)
	session.free()

func _test_balloon_inputs() -> void:
	var session := _new_session("game-001")
	session._unhandled_input(_key(KEY_ENTER))
	session._unhandled_input(_key(KEY_SPACE))
	session._unhandled_input(_motion(Vector2(780, 340)))
	Input.action_press(&"move_right")
	_check(session.balloon_started and session.balloon_braking and session.mouse_steering and session._axis_x() > 0.0,
		"balloon has the real active brake, pointer target and polled movement")
	session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_resume(session)
	_check(not session.balloon_braking and not session.mouse_steering and is_zero_approx(session._axis_x()) and Input.is_action_pressed(&"move_right"),
		"focus clears the brake and steering, suppressing only the stale axis action")
	Input.action_press(&"move_left", 0.6)
	_check(is_equal_approx(session._axis_x(), -0.6), "a different fresh direction still works while the old key is held")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	_check(is_zero_approx(session._axis_x()), "neutral movement re-arms the original direction")
	Input.action_press(&"move_right")
	_check(is_equal_approx(session._axis_x(), 1.0), "normal movement returns after a new press")
	Input.action_release(&"move_right")
	session._unhandled_input(_key(KEY_SPACE, true, true))
	_check(not session.balloon_braking, "stale brake echo has no effect")
	session._unhandled_input(_key(KEY_SPACE))
	_check(session.balloon_braking, "fresh brake uses the same key")
	session.free()

func _test_kite_inputs() -> void:
	var session := _new_session("game-002")
	session._unhandled_input(_key(KEY_UP))
	session._unhandled_input(_key(KEY_SPACE))
	_check(session.kite_model.aim > 0.0 and session.kite_model.boost, "kite keys actually aim and accelerate")
	session.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_resume(session)
	session._unhandled_input(_key(KEY_UP, true, true))
	session._unhandled_input(_key(KEY_SPACE, false))
	_check(is_zero_approx(session.kite_model.aim) and not session.kite_model.boost and not session.kite_model.reel,
		"old key echo/release cannot restore aim or boost")
	session._unhandled_input(_key(KEY_SHIFT))
	_check(session.kite_model.reel and not session.kite_model.boost, "fresh reel retains the original mapping")
	session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_resume(session)
	_check(not session.kite_model.reel, "focus also releases reel")
	session.free()

func _test_sign_drag() -> void:
	var session := _new_session("game-008")
	# Session deliberately skips its 3D view in headless mode. Install the real control and signal.
	var view := SignView.new()
	session.presentation = view
	session.add_child(view)
	view.balance_requested.connect(session._on_sign_balance_requested)
	var start := SignView.WEIGHT_RAIL.position + Vector2(42, SignView.WEIGHT_RAIL.size.y * 0.5)
	var end := SignView.WEIGHT_RAIL.end - Vector2(42, SignView.WEIGHT_RAIL.size.y * 0.5)
	view._gui_input(_click(start))
	var original: float = session.sign_model.balance
	_check(original < 0.0, "a click at the left weight rail actually changes the sign balance")
	session.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_resume(session)
	view._gui_input(_motion(end, true))
	_check(is_equal_approx(session.sign_model.balance, original), "drag without a fresh press cannot move the sign")
	view._gui_input(_click(end))
	_check(session.sign_model.balance > original, "a new drag works on the original rail")
	session.free()

func _test_shadow_hold() -> void:
	var session := _new_session("game-009")
	var view := ShadowView.new()
	session.presentation = view
	session.add_child(view)
	var requests: Array[Vector2] = []
	view.lamp_target_requested.connect(func(point: Vector2) -> void: requests.append(point))
	view._gui_input(_key(KEY_SHIFT))
	view._gui_input(_key(KEY_RIGHT))
	view._gui_input(_click(Vector2(610, 320)))
	_check(view._fine_down and view._right_down and requests.size() == 1, "the shadow control owns a real drag and fine movement")
	session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_resume(session)
	view._gui_input(_motion(Vector2(740, 400), true))
	_check(not view._fine_down and not view._right_down and requests.size() == 1, "focus clears both the fine modifier and the old drag")
	view._gui_input(_click(Vector2(710, 350)))
	view._gui_input(_motion(Vector2(800, 405), true))
	_check(requests.size() == 3 and not requests[1].is_equal_approx(requests[2]), "fresh shadow drag still updates the projection")
	session.free()

func _test_ribbon_hold() -> void:
	var session := _new_session("game-006")
	var keys := [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_LEFT]
	for code in keys:
		var cue: Dictionary = session.ribbon_model.snapshot().current_gesture
		_step_ribbon_model(session, float(cue.time) - float(session.ribbon_model.elapsed))
		session._unhandled_input(_key(code))
	var before: Dictionary = session.ribbon_model.snapshot().duplicate(true)
	_check(before.correct_count == 3 and before.hold_action == "left", "three scored presses and an unjudged held ribbon are present")
	session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_resume(session)
	session._unhandled_input(_key(KEY_LEFT, false))
	var after: Dictionary = session.ribbon_model.snapshot()
	_check(after.hold_action.is_empty() and after.error_count == before.error_count and after.score == before.score and after.elapsed == before.elapsed,
		"focus cancels the hold without judging the stale release or changing earned points")
	session._unhandled_input(_key(KEY_LEFT))
	_check(session.ribbon_model.snapshot().hold_action == "left", "a fresh press can restart the same cue while its timing window is open")
	_step_ribbon_model(session, float(before.hold_required))
	session._unhandled_input(_key(KEY_LEFT, false))
	_check(session.ribbon_model.snapshot().correct_count == 4 and session.ribbon_model.snapshot().error_count == 0,
		"normal rhythm timing and score qualification still apply after re-arming")
	session.free()

func _step_ribbon_model(session: Session, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var step := minf(0.12, remaining)
		session.ribbon_model.step(step)
		remaining -= step

func _new_session(id: String) -> Session:
	var session := Session.new()
	root.add_child(session)
	session.start(id)
	session.set_process(false)
	return session

func _resume(session: Session) -> void:
	var button := session.minigame_hud.find_child("ResumeButton", true, false) as Button
	_check(button != null and button.is_visible_in_tree(), "the actual resume action is visible")
	if button != null:
		button.pressed.emit()

func _key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func _motion(position: Vector2, held := false) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	return event

func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)
