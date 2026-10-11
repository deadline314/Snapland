extends "res://game/tests/native_review.gd"

## Native balloon delivery review. Runs the real park station, overlay controls,
## session input path, collection result, and screenshots using isolated data.
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native balloon review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _run_delivery(false, false, true): return
	# These are explicit isolated fixture settings, not native Settings UI input.
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _return_to_station(): return
	if not await _run_delivery(true, true, false): return
	print("PASS: native balloon delivery, clean devil, assisted reduced-motion ordinary clear")
	await main._quit_game()

func _run_delivery(assisted_run: bool, reduced_motion_run: bool, expect_devil: bool) -> bool:
	if not await _enter_balloon_station(): return false
	var start_button := _find(main.overlay, "開始遊玩")
	if start_button == null:
		await _fail("Balloon station Start button is missing")
		return false
	var start_rect := start_button.get_global_rect()
	if not main.get_viewport().get_visible_rect().encloses(start_rect):
		await _fail("Balloon station Start button is outside the viewport: " + str(start_rect))
		return false
	# Finish the menu hover before the click creates the session, so its queued
	# mouse motion cannot be mistaken for a separate tutorial action.
	_motion(start_rect.get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	_click(start_rect.get_center())
	var launch_deadline := Time.get_ticks_msec() + 2000
	while main.session == null and Time.get_ticks_msec() < launch_deadline:
		await get_tree().process_frame
	if main.session == null: await _fail("Balloon station Start button did not launch game-001");return false
	var session: Control = main.session
	if session.assisted != assisted_run or session.reduced_motion != reduced_motion_run:
		await _fail("Balloon review fixture mismatch assist=%s reduced_motion=%s actual=%s/%s" % [assisted_run, reduced_motion_run, session.assisted, session.reduced_motion])
		return false
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	# A native pointer transition may already demonstrate movement after launch.
	# It must not skip braking or start the delivery timer.
	if session.balloon_intro_step not in [0, 1] or session.balloon_started or session.elapsed != 0.0:
		await _fail("Balloon intro did not begin with timer-frozen movement/braking lessons: " + _lesson_state(session))
		return false
	print("BALLOON INTRO: ", _lesson_state(session))
	if not main._capture("pm/Snapland-small-game/images/SG-15-intro.png"):
		await _fail("Balloon intro screenshot failed")
		return false
	var tutorial_origin: Vector2 = session.p
	var tutorial_target := tutorial_origin + Vector2(150, -70)
	_motion(tutorial_target)
	await get_tree().create_timer(0.18).timeout
	# Give a possible opposite menu steering velocity time to turn around before
	# comparing Space's braking speed with the demonstrated flight speed.
	var movement_deadline := Time.get_ticks_msec() + 750
	while session.velocity.length() <= session.balloon_dock_speed + 25.0 and Time.get_ticks_msec() < movement_deadline:
		await get_tree().process_frame
	if session.balloon_intro_step != 1 or not session.mouse_steering or session.steering_target.distance_to(tutorial_target) > 1.0 or session.p.distance_to(tutorial_origin) < 1.0 or session.elapsed != 0.0:
		await _fail("Real mouse movement did not teach balloon movement; origin=%s requested_target=%s %s" % [tutorial_origin, tutorial_target, _lesson_state(session)])
		return false
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-small-game/images/SG-15-intro-move.png"):
		await _fail("Balloon movement lesson screenshot failed")
		return false
	var speed_before_brake: float = session.velocity.length()
	_key_down(KEY_SPACE)
	await get_tree().create_timer(0.25).timeout
	if session.balloon_intro_step != 2 or not session.balloon_braking or session.velocity.length() >= speed_before_brake:
		_key_up(KEY_SPACE)
		await _fail("Real Space input did not teach braking or reduce flight speed; speed_before=%.1f %s" % [speed_before_brake, _lesson_state(session)])
		return false
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-small-game/images/SG-15-intro-brake.png"):
		_key_up(KEY_SPACE)
		await _fail("Balloon braking lesson screenshot failed")
		return false
	_key_up(KEY_SPACE)
	if session.elapsed != 0.0:
		await _fail("Balloon lesson advanced the delivery timer before Enter: " + _lesson_state(session))
		return false
	_key(KEY_ENTER)
	await get_tree().physics_frame
	var launched_elapsed: float = session.elapsed
	if not session.balloon_started or not session.balloon_tutorial_seen or launched_elapsed > 0.2:
		await _fail("Enter did not start delivery after the timer-frozen lessons: " + _lesson_state(session))
		return false
	await get_tree().create_timer(0.15).timeout
	if session.elapsed <= launched_elapsed or session.elapsed > 0.8:
		await _fail("Delivery timer did not advance at a bounded rate after Enter")
		return false
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	if session.balloon_wind_current.length() <= 0.0 or session.balloon_wind_forecast != session._balloon_wind_at(session.phase + session.BALLOON_WIND_FORECAST_SECONDS, session.p.y):
		await _fail("Visible wind current/forecast state is not live")
		return false
	if not main._capture("pm/Snapland-small-game/images/SG-15-wind.png"):
		await _fail("Balloon wind screenshot failed")
		return false
	var result_rows: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary): result_rows.append(result))
	if not await _drive_balloon_route(session, not assisted_run): return false
	var result_deadline := Time.get_ticks_msec() + 5000
	while main.modal_kind != "result" and Time.get_ticks_msec() < result_deadline:
		await get_tree().process_frame
	if main.modal_kind != "result" or result_rows.size() != 1:
		await _fail("Balloon delivery did not produce a result modal: " + str(result_rows))
		return false
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var actual_result: Dictionary = result_rows[0] if result_rows.size() == 1 else {}
	var capture_suffix := "assist-" if assisted_run else ""
	capture_suffix += "devil" if bool(actual_result.get("devil", false)) else "ordinary"
	if not main._capture("pm/Snapland-small-game/images/SG-15-result-%s.png" % capture_suffix):
		await _fail("Balloon result screenshot failed")
		return false
	if not bool(actual_result.get("success", false)) or (expect_devil and not bool(actual_result.get("devil", false))) or bool(actual_result.get("assisted", false)) != assisted_run:
		await _fail("Balloon route result mismatch expected success/assisted=true/%s got %s" % [assisted_run, str(actual_result)])
		return false
	if not progress.photos.has("photo-welcome-game-1"):
		await _fail("Balloon ordinary photo was not collected")
		return false
	if expect_devil and not progress.photos.has("photo-welcome-devil-1"):
		await _fail("Clean balloon delivery did not award devil photo")
		return false
	return true

func _lesson_state(session: Control) -> String:
	return "step=%d started=%s elapsed=%.3f pos=%s velocity=%s speed=%.1f mouse=%s steering_target=%s braking=%s" % [session.balloon_intro_step, session.balloon_started, session.elapsed, session.p, session.velocity, session.velocity.length(), session.mouse_steering, session.steering_target, session.balloon_braking]

func _enter_balloon_station() -> bool:
	var station_found := false
	for point in main.world.points:
		if point.id != "game-001": continue
		main.world.player.position = point.position + Vector3(0, 0.3, 0)
		station_found = true
		break
	if not station_found:
		await _fail("Balloon station game-001 is missing from the park")
		return false
	var deadline := Time.get_ticks_msec() + 2000
	while main.world.nearest.get("id", "") != "game-001" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if main.world.nearest.get("id", "") != "game-001":
		await _fail("Balloon station did not become the real nearest interaction")
		return false
	_key(KEY_E)
	var modal_deadline := Time.get_ticks_msec() + 2000
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < modal_deadline:
		await get_tree().process_frame
	if main.modal_kind != "game_info":
		await _fail("E did not open balloon station details")
		return false
	return true

func _return_to_station() -> bool:
	_button("返回遊園")
	await get_tree().process_frame
	if main.session != null or main.modal_kind != "":
		await _fail("Could not return to the park before the assisted retry")
		return false
	return true

func _drive_balloon_route(session: Control, use_mouse: bool) -> bool:
	var points: Array[Vector2] = [Vector2(520, 305), Vector2(780, 270), Vector2(880, 270), Vector2(960, 360), Vector2(820, 480), Vector2(1080, 320)]
	var waypoint := 0
	var brake_held := false
	var held_keys: Array[int] = []
	var dock_two_captured := false
	var last_captured := false
	var last_delivery := 0
	var last_mistakes := 0
	var deadline := Time.get_ticks_msec() + 40000
	while not session.ended and Time.get_ticks_msec() < deadline:
		if session.balloon_delivery_index == 1 and waypoint == 0: waypoint = 1
		if session.balloon_delivery_index >= 2: waypoint = 5
		if waypoint >= 1 and waypoint <= 3 and session.p.distance_to(points[waypoint]) < 30.0: waypoint += 1
		var point: Vector2 = points[waypoint]
		if use_mouse:
			_motion(point)
		else:
			var desired_keys: Array[int] = []
			var offset: Vector2 = point - session.p
			if offset.x > 12.0: desired_keys.append(KEY_D)
			elif offset.x < -12.0: desired_keys.append(KEY_A)
			if offset.y > 12.0: desired_keys.append(KEY_S)
			elif offset.y < -12.0: desired_keys.append(KEY_W)
			_set_keys(held_keys, desired_keys)
		var distance_to_dock: float = session.p.distance_to(session.target)
		var threshold: float = session.balloon_dock_speed
		var stop_early: bool = distance_to_dock < 190.0 and session.velocity.length() > threshold
		var in_ring: bool = distance_to_dock <= session.balloon_dock_radius
		var controlled_approach: bool = brake_held and distance_to_dock < 190.0
		var should_brake: bool = session.balloon_delivery_index < 3 and (stop_early or in_ring or controlled_approach) and waypoint not in [1, 2, 3]
		if should_brake != brake_held:
			_key_down(KEY_SPACE) if should_brake else _key_up(KEY_SPACE)
			brake_held = should_brake
		if session.balloon_delivery_index == 1 and not dock_two_captured and session.p.distance_to(session.target) <= session.balloon_dock_radius and session.balloon_dock_hold > 0.12:
			await RenderingServer.frame_post_draw
			dock_two_captured = main._capture("pm/Snapland-small-game/images/SG-15-dock-2.png")
		if session.balloon_delivery_index == 2 and not last_captured and session.p.distance_to(session.target) < 125.0:
			await RenderingServer.frame_post_draw
			last_captured = main._capture("pm/Snapland-small-game/images/SG-15-last.png")
		if session.balloon_delivery_index > last_delivery:
			last_delivery = session.balloon_delivery_index
			print("BALLOON DELIVERY %d/3 pos=%s speed=%.1f mistakes=%d" % [last_delivery, session.p, session.velocity.length(), session.mistakes])
		await get_tree().physics_frame
		if session.mistakes > last_mistakes:
			var hazard_distance: float = session.p.distance_to(session._balloon_hazard_at(session.phase))
			var dock_distance: float = session.p.distance_to(session.target)
			print("BALLOON MISTAKE +%d pos=%s speed=%.1f hazard_distance=%.1f dock_distance=%.1f prompt=%s" % [session.mistakes-last_mistakes, session.p, session.velocity.length(), hazard_distance, dock_distance, session.prompt])
			last_mistakes = session.mistakes
	_set_keys(held_keys, [])
	if brake_held: _key_up(KEY_SPACE)
	if not session.ended:
		await _fail("Balloon route solver deadline; index=%d pos=%s vel=%s target=%s mistakes=%d elapsed=%.1f" % [session.balloon_delivery_index, session.p, session.velocity, session.target, session.mistakes, session.elapsed])
		return false
	if not dock_two_captured:
		await _fail("Did not capture real braking at mailbox two")
		return false
	if not last_captured:
		await _fail("Did not capture final delivery approach")
		return false
	return true

func _set_keys(held: Array[int], wanted: Array[int]) -> void:
	for key in held.duplicate():
		if not wanted.has(key): _key_up(key)
	for key in wanted:
		if not held.has(key): _key_down(key)
	# Caller owns the set, keeping transition events explicit and deterministic.
	held.assign(wanted)

func _key_down(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func _key_up(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
