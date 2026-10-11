extends SceneTree

const Session = preload("res://game/minigames/session.gd")
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Balloon tests require isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	_test_staged_intro_freezes_round()
	_test_steering_and_brake_share_one_motion_model()
	_test_visible_wind_state_matches_forecast()
	_test_three_deliveries_finish_cleanly()
	_test_fast_approach_recovers_without_teleport()
	_test_timeout_and_retry_preserve_tutorial()
	_test_assisted_docks_are_wider()
	print("PASS: balloon delivery checks (%d cases)" % checks)
	quit()

func _test_staged_intro_freezes_round() -> void:
	var session := _new_session()
	assert(not session.balloon_started and session.balloon_intro_step == 0)
	Input.action_press("ui_right")
	session._process(0.05)
	Input.action_release("ui_right")
	assert(session.balloon_intro_step == 1 and session.p.x > 250.0)
	_key(session, KEY_SPACE)
	session._process(0.05)
	_key_release(session, KEY_SPACE)
	assert(not session.balloon_started and session.elapsed == 0.0)
	assert(session.balloon_intro_step == 2)
	_key(session, KEY_ENTER)
	assert(session.balloon_started and session.balloon_tutorial_seen)
	assert(session.elapsed == 0.0 and session.balloon_delivery_index == 0)
	session.queue_free()
	checks += 1

func _test_steering_and_brake_share_one_motion_model() -> void:
	var session := _new_session()
	_key(session, KEY_ENTER)
	var origin: Vector2 = session.p
	_mouse_move(session, origin.x + 260.0, origin.y + 40.0)
	session._process(0.25)
	assert(session.velocity.x > 0.0 and session.velocity.y > 0.0)
	assert(session.p.x > origin.x and session.p.y > origin.y)
	assert(session.velocity.length() <= Session.BALLOON_MAX_SPEED + 0.01)
	var fast_speed: float = session.velocity.length()
	_key(session, KEY_SPACE)
	for i in 8: session._process(0.05)
	_key_release(session, KEY_SPACE)
	assert(not session.balloon_braking and session.velocity.length() < fast_speed)
	var before_key: Vector2 = session.p
	Input.action_press("ui_right")
	session._process(0.05)
	Input.action_release("ui_right")
	assert(session.p.x > before_key.x)
	session.queue_free()
	checks += 1

func _test_visible_wind_state_matches_forecast() -> void:
	var session := _new_session()
	_key(session, KEY_ENTER)
	session.phase = 1.0
	session._process(0.01)
	assert(session.balloon_wind_current == session._balloon_wind_at(session.phase))
	assert(session.balloon_wind_forecast == session._balloon_wind_at(session.phase + Session.BALLOON_WIND_FORECAST_SECONDS))
	assert(session.balloon_wind_current.length() > 0.0)
	var wind_direction := signf(session.balloon_wind_current.x)
	var start_x: float = session.p.x
	session.velocity = Vector2.ZERO
	session.mouse_steering = false
	for i in 8: session._process(0.05)
	assert(signf(session.p.x - start_x) == wind_direction)
	session.queue_free()
	checks += 1

func _test_three_deliveries_finish_cleanly() -> void:
	var session := _new_session()
	var results: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	_key(session, KEY_ENTER)
	for i in 3:
		session.p = session.target
		session.velocity = Vector2.ZERO
		session.balloon_braking = true
		for tick in 15:
			session._process(0.05)
			if session.ended: break
		assert(session.balloon_delivery_index == i + 1)
	assert(results.size() == 1 and results[0].success and results[0].devil)
	assert(session.count == 3 and session.score == 450)
	session.queue_free()
	checks += 1

func _test_fast_approach_recovers_without_teleport() -> void:
	var session := _new_session()
	_key(session, KEY_ENTER)
	session.p = session.target - Vector2(1.0, 0.0)
	session.velocity = Vector2(150.0, 0.0)
	session._process(0.01)
	assert(session.balloon_delivery_index == 0 and not session.ended)
	assert(session.p.x > session.target.x and session.p.x < session.target.x + 10.0)
	assert(session.prompt.contains("減速") or session.prompt.contains("煞車"))
	session.balloon_braking = true
	for i in 20: session._process(0.05)
	assert(session.balloon_delivery_index == 1 and not session.ended)
	session.queue_free()
	checks += 1

func _test_timeout_and_retry_preserve_tutorial() -> void:
	var session := _new_session()
	_key(session, KEY_ENTER)
	session._process(55.0)
	assert(session.ended and not session.won)
	_key(session, KEY_R)
	assert(not session.ended and session.balloon_started and session.balloon_tutorial_seen)
	assert(session.elapsed == 0.0 and session.balloon_delivery_index == 0)
	session.queue_free()
	checks += 1

func _test_assisted_docks_are_wider() -> void:
	var standard := _new_session(false)
	var assisted := _new_session(true)
	assert(Session.BALLOON_ASSIST_DOCK_RADIUS > Session.BALLOON_DOCK_RADIUS)
	assert(Session.BALLOON_ASSIST_DOCK_SPEED > Session.BALLOON_DOCK_SPEED)
	assert(Session.BALLOON_ASSIST_WIND_SCALE < Session.BALLOON_WIND_SCALE)
	standard.queue_free()
	assisted.queue_free()
	checks += 1

func _new_session(with_assist: bool = false) -> Control:
	var session: Control = Session.new()
	root.add_child(session)
	session.start("game-001", with_assist)
	return session

func _key(session: Control, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	session._unhandled_input(event)

func _key_release(session: Control, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = false
	session._unhandled_input(event)

func _mouse_move(session: Control, x: float, y: float) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(x, y)
	session._unhandled_input(event)
