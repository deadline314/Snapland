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
	_test_pause_and_practice_preserve_state_contract()
	_test_assisted_docks_are_wider()
	_test_hazard_ledger_and_assisted_qualification()
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
	assert(session.score_events.is_empty() and not session.score_summary().has("qualification_text"))
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
	assert(results[0].score_summary.rows.size() == 3)
	for index in 3:
		assert(results[0].score_summary.rows[index].key == "mailbag_%d" % (index + 1))
		assert(results[0].score_summary.rows[index].amount == 150)
	assert(results[0].score_summary.qualification_text.contains("已達成小惡魔"))
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
	assert(session.mistakes == 1 and session.score_summary().rows[0].key == "balloon_fast_dock")
	assert(session.score_summary().rows[0].amount == 0 and session.score_summary().rows[0].progress_only)
	session._process(0.01)
	assert(session.mistakes == 1 and session.score_summary().rows[0].count == 1)
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
	assert(session.score_summary().qualification_text.contains("0 / 3"))
	var hud: Control = session.get("minigame_hud")
	hud._ask_retry()
	hud.find_child("ConfirmAction", true, false).emit_signal("pressed")
	assert(not session.ended and session.balloon_started and session.balloon_tutorial_seen)
	assert(session.elapsed == 0.0 and session.balloon_delivery_index == 0)
	session.queue_free()
	checks += 1

func _test_pause_and_practice_preserve_state_contract() -> void:
	var session := _new_session()
	var intro_pos: Vector2 = session.p
	var intro_phase: float = session.phase
	session.set_paused(true)
	session._process(8.0)
	assert(session.phase == intro_phase and session.p == intro_pos and session.elapsed == 0.0)
	session.set_paused(false)
	session._process(8.0)
	assert(session.phase == intro_phase and session.p == intro_pos)
	session._process(0.05)
	assert(session.phase > intro_phase)
	_key(session, KEY_ENTER)
	session._process(0.05)
	var active_pos: Vector2 = session.p
	var active_elapsed: float = session.elapsed
	session.set_paused(true)
	_mouse_move(session, 1000, 540)
	session._process(1.0)
	assert(session.p == active_pos and session.elapsed == active_elapsed)
	var help_ids: Array[String] = []
	session.help_requested.connect(func(id: String): help_ids.append(id))
	session.request_help()
	assert(session.paused and help_ids == ["game-001"])
	session.set_paused(false)
	session.set_practice_mode(true)
	assert(session.practice_mode and session.elapsed == 0.0 and session.score == 0)
	session.reset_round()
	assert(session.practice_mode)
	var result_rows: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary): result_rows.append(value))
	session._finish(true)
	assert(result_rows.size() == 1 and result_rows[0].practice)
	session.queue_free()
	checks += 1

func _test_assisted_docks_are_wider() -> void:
	var standard := _new_session(false)
	var assisted := _new_session(true)
	assert(Session.BALLOON_ASSIST_DOCK_RADIUS > Session.BALLOON_DOCK_RADIUS)
	assert(Session.BALLOON_ASSIST_DOCK_SPEED > Session.BALLOON_DOCK_SPEED)
	assert(Session.BALLOON_ASSIST_WIND_SCALE < Session.BALLOON_WIND_SCALE)
	var results: Array[Dictionary] = []
	assisted.finished.connect(func(result: Dictionary): results.append(result))
	_key(assisted, KEY_ENTER)
	assisted.balloon_braking = true
	for index in 3:
		assisted.p = assisted.target
		assisted.velocity = Vector2.ZERO
		for tick in 15:
			assisted._process(0.05)
			if assisted.ended: break
	assert(results.size() == 1 and results[0].success and not results[0].devil)
	assert(assisted.mistakes == 0 and assisted.score == 450)
	assert(results[0].score_summary.qualification_text.contains("輔助回合不取得"))
	standard.queue_free()
	assisted.queue_free()
	checks += 1

func _test_hazard_ledger_and_assisted_qualification() -> void:
	var session := _new_session(true)
	_key(session, KEY_ENTER)
	session.p = session._balloon_hazard_at(session.phase)
	session._process(0.01)
	assert(session.mistakes == 1 and session.score_events.size() == 1)
	assert(session.score_events[0].key == "balloon_hazard" and session.score_events[0].amount == 0)
	assert(session.score_summary().rows[0].progress_only and session.score_summary().rows[0].count == 1)
	session._process(0.01)
	assert(session.mistakes == 1 and session.score_events[0].count == 1)
	for index in 3:
		session.p = session.target
		session.velocity = Vector2.ZERO
		session.balloon_braking = true
		for tick in 15:
			session._process(0.05)
			if session.ended: break
	assert(session.won and session.score == 450)
	assert(session.score_summary().qualification_text.contains("輔助回合不取得"))
	assert(session.score_summary().rows.size() == 4)
	session.set_practice_mode(true)
	assert(not session.score_summary().has("qualification_text"))
	session.queue_free()
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
