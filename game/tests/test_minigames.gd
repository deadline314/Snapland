extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const HUD = preload("res://game/ui/minigame_hud.gd")
const RibbonView = preload("res://game/minigames/ribbon_rhythm_view.gd")
const Model = preload("res://game/minigames/melody_memory_model.gd")
var checks := 0
var failed_checks := 0
var _kite_pointer_test_completed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Minigame tests require isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--kite-pointer-only"):
		await _test_kite_native_pointer_routing()
		_expect(_kite_pointer_test_completed,"standalone kite pointer coroutine reached its final assertion")
		if failed_checks > 0:
			push_error("FAIL: standalone kite pointer routing (%d expectations)" % failed_checks)
			quit(1)
			return
		print("PASS: standalone kite pointer GUI routing")
		quit(0)
		return
	await _test_native_input_routing()
	await _test_kite_native_pointer_routing()
	_expect(_kite_pointer_test_completed,"kite pointer coroutine completed without a runtime error")
	_test_hud_signals_and_state()
	_test_photo_and_rhythm_grades()
	_test_pause_practice_and_score_summary()
	_test_bounded_score_ledger_and_hud_rate()
	_test_all_modes()
	_test_definition_catalog()
	_test_balloon_boundaries()
	_test_kite_boundaries()
	_test_crowd_boundaries()
	_test_hat_boundaries()
	_test_ribbon_boundaries()
	_test_sign_boundaries()
	_test_sign_seven_stage_score_ledger()
	_test_shadow_boundaries()
	_test_bubble_boundaries()
	_test_melody_boundaries()
	_test_bench_swaps_and_devil_boundary()
	_test_timed_action()
	_test_fountain_quality()
	_test_vertical_input_and_hat_consumption()
	_test_flower_pipe_route()
	_test_escape_cancels()
	if failed_checks > 0:
		push_error("FAIL: %d new HUD/runtime expectations" % failed_checks)
		quit(1)
		return
	print("PASS: welcome minigame checks (%d cases)" % checks)
	quit()

func _test_definition_catalog() -> void:
	var defs := Session.definitions()
	assert(defs.size() == 12)
	for i in 12: assert(defs[i].id == "game-%03d" % (i + 1))
	var ids: Array[String] = []
	var unique: Dictionary = {}
	for def in defs:
		assert(not str(def.id).is_empty())
		assert(not str(def.goal).is_empty())
		assert(not str(def.ordinary).is_empty())
		assert(not str(def.devil).is_empty())
		assert(not unique.has(def.id))
		unique[def.id] = true
		ids.append(def.id)
	assert(ids.size() == unique.size())
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/welcome_games.json"))
	assert(data is Array and data.size() == 12)
	var bench_definition: Dictionary = defs[10]
	var tutorial_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/tutorials.json"))
	var lessons: Array = tutorial_data.get("lessons", [])
	var bench_tutorial: Dictionary = lessons.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) == "game-011")[0]
	_expect(str(bench_definition.instructions).contains("1–6") and str(bench_definition.ordinary).contains("三桌"), "game-011 catalog teaches six numbered seats and all three rule-based orders")
	_expect(str(bench_tutorial.ordinary).contains("三桌") and str(bench_tutorial.bonus).contains("最少") and str(bench_tutorial.steps[0].input).contains("1–6"), "game-011 tutorial matches its six-seat interaction and exact-minimum devil target")
	var missing := _new_session("unknown-game-id")
	assert(missing.ended and missing.game_id.is_empty())
	missing.queue_free()
	checks += 1

func _test_balloon_boundaries() -> void:
	var bad := _new_session("game-001", true)
	var bad_results: Array[Dictionary] = []
	bad.finished.connect(func(value: Dictionary): bad_results.append(value))
	_key(bad, KEY_ENTER)
	Input.action_press("ui_up")
	var start_y: float = bad.p.y
	bad._process(0.05)
	Input.action_release("ui_up")
	assert(bad.p.y < start_y) # Up moves toward the top of the screen.
	_mouse_move(bad, 300, 520)
	bad._process(0.1)
	assert(bad_results.is_empty())
	var before: Vector2 = bad.p
	_mouse_move(bad, 1060, 345)
	assert(bad.p == before)
	bad._process(0.01)
	assert(bad_results.is_empty() and bad.p.distance_to(before) < 3.0)
	bad.queue_free()
	checks += 1

func _test_kite_boundaries() -> void:
	var missed := _new_session("game-002", true)
	var missed_results: Array[Dictionary] = []
	missed.finished.connect(func(value: Dictionary): missed_results.append(value))
	while not missed.ended: missed._process(0.05)
	assert(missed_results.size() == 1 and not missed_results[0].success)
	assert(missed.kite_model.rescues_used == missed.kite_model.MAX_RESCUES)
	missed.queue_free()

	var flown := _new_session("game-002", false)
	var flown_results: Array[Dictionary] = []
	flown.finished.connect(func(value: Dictionary): flown_results.append(value))
	var budget := 5000
	while not flown.ended and budget > 0:
		_kite_drive_step(flown, 0.01)
		budget -= 1
	assert(budget > 0 and flown_results.size() == 1 and flown_results[0].success and flown_results[0].devil, "actual input-driven flight must center all five rings: %s" % str(flown.kite_model.snapshot()))
	assert(flown.kite_model.center_hits == 5 and flown.kite_model.edge_hits == 0 and flown.kite_model.rescues_used == 0)
	assert(flown.score == 500 and flown.mistakes == 0 and flown.score_summary().total == flown.score)
	flown.queue_free()

	var keyed := _new_session("game-002", true)
	var keyed_results: Array[Dictionary] = []
	keyed.finished.connect(func(value: Dictionary): keyed_results.append(value))
	budget = 7000
	while not keyed.ended and budget > 0:
		_kite_keyboard_drive_step(keyed, 0.01)
		budget -= 1
	assert(budget > 0 and keyed_results.size() == 1 and keyed_results[0].success and not keyed_results[0].devil, "assisted keyboard controls must fly the complete route: %s" % str(keyed.kite_model.snapshot()))
	assert(keyed.kite_model.ring_index == 5 and keyed.kite_model.assisted)
	_key_release(keyed, KEY_UP); _key_release(keyed, KEY_DOWN)
	keyed.queue_free()
	checks += 1

func _kite_keyboard_drive_step(session: Control, delta: float = 0.01) -> void:
	var model = session.kite_model
	var target_height := float(model.RING_HEIGHT[model.ring_index]) if model.ring_index < 5 else 390.0
	var desired := clampf((float(model.height) - target_height) * 0.024 - float(model.vy) * 0.014, -1.0, 1.0)
	var up := desired > 0.25
	var down := desired < -0.25
	if up != session._kite_up_held: _key(session, KEY_UP) if up else _key_release(session, KEY_UP)
	if down != session._kite_down_held: _key(session, KEY_DOWN) if down else _key_release(session, KEY_DOWN)
	session._process(delta)

func _kite_drive_step(session: Control, delta: float = 0.01) -> void:
	var model = session.kite_model
	var target_height := float(model.RING_HEIGHT[model.ring_index]) if model.ring_index < 5 else 390.0
	var error := float(model.height) - target_height
	var aim := clampf(error * 0.024 - float(model.vy) * 0.014, -1.0, 1.0)
	_mouse_move(session, 640.0, 390.0 - aim * 235.0)
	session._process(delta)

func _test_crowd_boundaries() -> void:
	for use_assist in [false, true]:
		var played := _new_session("game-004", use_assist)
		var results: Array[Dictionary] = []
		played.finished.connect(func(value: Dictionary): results.append(value))
		var budget := 1000
		# Model the 0.65-second opening instruction and 0.30-second response.
		while played.crowd_model.elapsed < 0.95 and budget > 0:
			played._process(minf(0.05, 0.95 - played.crowd_model.elapsed))
			budget -= 1
		while not played.ended and budget > 0:
			var chosen := _crowd_priority_lane(played.crowd_model)
			if chosen >= 0 and played.crowd_model.desired_lane != chosen:
				_key(played, KEY_Q if chosen == 0 else KEY_E)
			played._process(0.05)
			budget -= 1
		assert(budget > 0 and results.size() == 1)
		assert(results[0].success and results[0].devil and results[0].assisted == use_assist)
		assert(played.crowd_model.safe_count == 6 and played.score == played.crowd_model.score)
		assert(played.score_summary().total == played.score and played.mistakes == 0)
		played.queue_free()
	var missed := _new_session("game-004", false)
	var missed_results: Array[Dictionary] = []
	missed.finished.connect(func(value: Dictionary): missed_results.append(value))
	for index in 500:
		if missed.ended: break
		missed._process(0.05)
	assert(missed_results.size() == 1 and not missed_results[0].success)
	assert(missed.mistakes == 6 and missed.score == 0)
	missed.queue_free()
	checks += 1

func _crowd_priority_lane(model) -> int:
	var chosen := -1
	var earliest_deadline := INF
	for direction in 2:
		var lane_queue: Array = model.queues[direction]
		if lane_queue.is_empty(): continue
		# A lane's queue remains FIFO; compare only its head's true patience deadline.
		var head: Dictionary = lane_queue[0]
		var deadline := float(head.arrived_at) + float(head.patience)
		if deadline < earliest_deadline:
			earliest_deadline = deadline
			chosen = direction
	return chosen

func _test_hat_boundaries() -> void:
	var missed := _new_session("game-005", true)
	var missed_results: Array[Dictionary] = []
	missed.finished.connect(func(value: Dictionary): missed_results.append(value))
	while not missed.ended: missed._process(0.05)
	assert(missed_results.size() == 1 and not missed_results[0].success)
	missed.queue_free()

	var caught := _new_session("game-005", true)
	var caught_results: Array[Dictionary] = []
	caught.finished.connect(func(value: Dictionary): caught_results.append(value))
	while not caught.ended:
		var closest := -1
		var closest_y := -INF
		for i in caught.hat_y.size():
			if not caught.hats_consumed[i] and caught.hat_y[i] > closest_y and caught.hat_y[i] > 535.0:
				closest = i; closest_y = caught.hat_y[i]
		if closest >= 0: _mouse_move(caught, caught.hat_x[closest], 570)
		caught._process(0.02)
	assert(caught_results.size() == 1 and caught_results[0].success and caught_results[0].devil and caught_results[0].assisted)
	caught.queue_free()
	checks += 1

func _test_ribbon_boundaries() -> void:
	var s := _new_session("game-006")
	var ribbon_view := s.presentation as RibbonView
	var feedback_anchor: Vector2 = s._feedback_anchor()
	s.minigame_hud.set_feedback_at("節拍狀態", feedback_anchor)
	var feedback_control := s.minigame_hud.find_child("ContextFeedback", true, false) as Control
	_expect(feedback_control != null and feedback_anchor == Vector2(640, 230), "Ribbon feedback uses the clear strip below the HUD")
	if feedback_control != null and ribbon_view != null:
		var toast_rect := Rect2(feedback_control.position, feedback_control.size)
		for pose in ["walk_left", "wave_front", "jump_front"]:
			var dancer_bounds := ribbon_view.avatar_bounds_for_pose(pose)
			var partner_bounds := ribbon_view.avatar_bounds_for_pose(pose, true)
			_expect(not toast_rect.intersects(dancer_bounds) and not toast_rect.intersects(partner_bounds), "Ribbon feedback misses both dancers during %s choreography" % pose)
		for cue_rect in [RibbonView.CURRENT_CUE_RECT, RibbonView.UPCOMING_CUE_RECTS[0], RibbonView.UPCOMING_CUE_RECTS[1]]:
			_expect(not toast_rect.intersects(cue_rect), "Ribbon feedback never covers a visible gesture card")
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary) -> void: results.append(value.duplicate(true)))
	_expect(s.ribbon_model.snapshot().upcoming.size() == 2, "ribbon opening presents two authored upcoming gestures")
	_advance_ribbon_to(s, 1.02)
	s._on_ribbon_action_pressed("right")
	_expect(s.mistakes == 1 and s.devil_progress == 0 and results.is_empty(), "wrong direction records an error without auto-advancing or answering")
	s._on_ribbon_action_pressed("left")
	_expect(s.devil_progress == 1 and s.ribbon_model.snapshot().gesture_index == 1, "correct action remains available after a wrong direction")
	var gestures: Array = s.ribbon_model.GESTURES
	for index in range(1, gestures.size()):
		var cue_time := 1.02 + float(index) * 0.94
		_advance_ribbon_to(s, cue_time)
		var action := str(gestures[index].action)
		s._on_ribbon_action_pressed(action)
		if float(gestures[index].hold) > 0.0:
			_advance_ribbon_to(s, cue_time + float(gestures[index].hold))
			s._on_ribbon_action_released(action)
	_expect(results.size() == 1 and bool(results[0].success) and not bool(results[0].devil), "eight correct gestures with an earlier error finish ordinary, never devil")
	var ledger_score := 0
	for event in s.score_events: ledger_score += int(event.amount)
	_expect(s.score == ledger_score and s.score == s.ribbon_model.score and s._ribbon_score_cursor == 8, "Session score summary mirrors all eight actual gesture ledger entries")
	_expect(s._ribbon_note_cursor == int(s.ribbon_model.snapshot().note_played_serial) and s.mistakes == 1 and s.ribbon_model.snapshot().precise_count >= 6, "audio cue cursor and precision/error ledgers stay independently observable")
	s.queue_free()
	var assisted := _new_session("game-006", true)
	_advance_ribbon_to(assisted, 1.02)
	var assist_elapsed: float = float(assisted.ribbon_model.snapshot().elapsed)
	assisted._on_ribbon_action_pressed("left")
	_expect(assisted.ribbon_model.snapshot().elapsed == assist_elapsed and assisted.devil_progress == 1, "assistance does not automate an input and only widens timing tolerance")
	assisted.set_paused(true)
	var frozen: float = float(assisted.ribbon_model.snapshot().elapsed)
	assisted._process(0.2)
	_expect(is_equal_approx(float(assisted.ribbon_model.snapshot().elapsed), frozen), "paused ribbon clock freezes all gesture timing")
	assisted.reset_round()
	_expect(assisted.score == 0 and assisted._ribbon_note_cursor == 0 and assisted.ribbon_model.snapshot().gesture_index == 0, "retry clears ribbon score, cue cursor and hold state")
	_expect(assisted.score_summary().rule.contains("四個重拍") and not bool(assisted.ribbon_model.snapshot().devil_success), "score rules expose strong beats and assisted devil exclusion")
	assisted.queue_free()
	checks += 1

func _advance_ribbon_to(session: Control, target: float) -> void:
	var iterations := 0
	while float(session.ribbon_model.snapshot().elapsed) + 0.00001 < target and iterations < 1200:
		session._process(minf(0.02, target - float(session.ribbon_model.snapshot().elapsed)))
		iterations += 1
	_expect(iterations < 1200, "ribbon clock reaches each scheduled cue within a bounded number of steps")

func _test_sign_boundaries() -> void:
	var s := _new_session("game-008", true)
	var initial: Dictionary = s.sign_model.snapshot().duplicate(true)
	Input.action_press("ui_right")
	s._process(0.1)
	Input.action_release("ui_right")
	var moved: Dictionary = s.sign_model.snapshot()
	assert(float(moved.balance) > float(initial.balance), "held right input moves the physical counterweight through the session: axis=%f initial=%s moved=%s" % [s._axis_x(), str(initial), str(moved)])
	assert(float(moved.angle) > float(initial.angle), "counterweight torque turns the sign through the session model")
	assert(s.score_summary().total == s.score and s.score_summary().rule.contains("0.52 秒"), "session score summary follows the seven-stage model rules")
	var elapsed_before_pause: float = moved.elapsed
	s.set_paused(true)
	Input.action_press("ui_left")
	s._process(0.2)
	Input.action_release("ui_left")
	assert(is_equal_approx(float(s.sign_model.snapshot().elapsed), elapsed_before_pause), "paused sign model does not advance")
	s.reset_round()
	assert(float(s.sign_model.snapshot().elapsed) == 0.0 and s.sign_model.snapshot().stage == 0 and s.score == 0, "retry resets sign physics and stage ledger immediately")
	s.set_practice_mode(true)
	assert(s.practice_mode and not s.ended and s.sign_model.snapshot().elapsed == 0.0, "practice starts a clean sign route")
	s.queue_free()

	var wrong := _new_session("game-008")
	var failure_results: Array[Dictionary] = []
	wrong.finished.connect(func(value: Dictionary) -> void: failure_results.append(value.duplicate(true)))
	Input.action_press("ui_left")
	var failure_steps := 0
	while not wrong.ended and failure_steps < 2600:
		wrong._process(0.01)
		failure_steps += 1
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	var completed_failure: bool = wrong.ended and failure_steps < 2600 and failure_results.size() == 1 and not bool(failure_results[0].success) and not bool(failure_results[0].devil)
	_expect(completed_failure, "held left input reaches exactly one real unsuccessful Sign result through collision or timeout")
	if completed_failure:
		var failure_summary: Dictionary = wrong.score_summary()
		var failure_event_total := 0
		for event in wrong.score_events:
			failure_event_total += int(event.amount)
		_expect(int(failure_summary.get("total", -1)) == wrong.score and failure_event_total == wrong.score and int(failure_results[0].get("score_summary", {}).get("total", -1)) == wrong.score, "failed Sign result and score summary retain the earned score ledger")
	wrong.queue_free()

func _test_sign_seven_stage_score_ledger() -> void:
	var session := _new_session("game-008")
	var result: Array[Dictionary] = []
	session.finished.connect(func(value: Dictionary) -> void: result.append(value.duplicate(true)))
	var iterations := 0
	while not session.ended and iterations < 2600:
		var state: Dictionary = session.sign_model.snapshot().duplicate(true)
		var target := float(state.target_angle)
		var error := float(state.angle) - target
		var torque := float(state.wind_torque)
		if bool(state.forecast_visible): torque = float(state.forecast_torque)
		var desired_accel := -8.0 * error - 4.0 * float(state.angular_velocity)
		var restoring: float = -session.sign_model.RESTORE_TORQUE * error
		var desired_balance := clampf((desired_accel - torque - restoring + session.sign_model.ANGULAR_DAMPING * float(state.angular_velocity)) / session.sign_model.COUNTERWEIGHT_TORQUE, -1.0, 1.0)
		var axis := 1 if desired_balance > float(state.balance) + 0.02 else (-1 if desired_balance < float(state.balance) - 0.02 else 0)
		Input.action_release("ui_left")
		Input.action_release("ui_right")
		if axis < 0: Input.action_press("ui_left")
		if axis > 0: Input.action_press("ui_right")
		session._process(0.01)
		iterations += 1
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	var final_state: Dictionary = session.sign_model.snapshot().duplicate(true)
	var ledger: Array = final_state.stage_results
	var ledger_precise := 0
	var ledger_score := 0
	for entry in ledger:
		if bool(entry.passed):
			ledger_score += 100 if bool(entry.precise) else 70
			if bool(entry.precise): ledger_precise += 1
	var awarded_score := 0
	for event in session.score_events:
		awarded_score += int(event.amount)
	_expect(session.ended and result.size() == 1 and bool(result[0].success) and bool(result[0].devil), "seven-stage sign session reaches its actual devil result through direction input")
	_expect(ledger.size() == 7 and ledger_precise == 7 and ledger_score == 700, "seven completed model ledger entries are all precise and total 700")
	_expect(session.score == ledger_score and awarded_score == 700 and session._sign_stage_cursor == 7, "session awards every completed ledger entry including final index six")
	var summary: Dictionary = session.score_summary()
	var rows: Array = summary.get("rows", [])
	_expect(rows.size() == 7 and int(summary.get("total", -1)) == 700, "seven distinct Sign stage awards create seven readable summary rows totaling 700")
	for index in mini(7, rows.size()):
		var expected_label := "第 %d 段・中心精準" % (index + 1)
		_expect(str(rows[index].get("label", "")) == expected_label and int(rows[index].get("amount", -1)) == 100, "score summary exposes the actual precise label and 100-point award for stage %d" % (index + 1))
	var event_count: int = session.score_events.size()
	session._process(0.01)
	var post_finish_awards := 0
	for event in session.score_events:
		post_finish_awards += int(event.amount)
	_expect(session.score == 700 and post_finish_awards == 700 and session.score_events.size() == event_count, "post-finish processing does not duplicate sign stage awards")
	if not (session.ended and ledger_precise == 7 and session.score == 700):
		push_error("Sign seven-stage regression evidence: iterations=%d result=%s stage=%s ledger_precise=%d ledger_score=%d score=%d cursor=%d" % [iterations, str(result), str(final_state), ledger_precise, ledger_score, session.score, session._sign_stage_cursor])
	session.queue_free()
	checks += 1

func _test_shadow_boundaries() -> void:
	var s := _new_session("game-009", true)
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	_mouse_move(s, 802, 420)
	s._process(3.1)
	assert(results.size() == 1 and results[0].success and results[0].devil and results[0].assisted)
	s.queue_free()

	var bad := _new_session("game-009", true)
	var bad_results: Array[Dictionary] = []
	bad.finished.connect(func(value: Dictionary): bad_results.append(value))
	bad._process(3.1)
	assert(bad_results.is_empty() and bad.alignment_hold == 0.0)
	bad.queue_free()
	checks += 1

func _test_bubble_boundaries() -> void:
	var input_session := _new_session("game-010")
	var start_center: Vector2 = input_session.bubble_model.snapshot().frame_center
	_key(input_session, KEY_RIGHT)
	assert(input_session.bubble_model.snapshot().frame_center == start_center + Vector2(14, 0), "arrow input moves the real camera frame")
	_mouse_move(input_session, 700, 390)
	assert(input_session.bubble_model.snapshot().frame_center == Vector2(700, 390), "mouse movement positions the camera frame")
	_key(input_session, KEY_SPACE)
	assert(input_session.bubble_model.snapshot().photos.size() == 1 and input_session.mistakes == 1, "an early shutter consumes exactly one real photo opportunity")
	input_session.queue_free()

	var perfect := _new_session("game-010", true)
	var results: Array[Dictionary] = []
	perfect.finished.connect(func(value: Dictionary): results.append(value))
	for round_index in 3:
		_bubble_capture_session_round(perfect, true)
	assert(results.size() == 1 and results[0].success and results[0].devil and results[0].assisted, "three actual full-body perfect exposures meet ordinary and devil thresholds")
	assert(perfect.score == 300 and perfect.score_summary().total == perfect.score, "three actual captured score events sum to 300")
	perfect.queue_free()

	var miss := _new_session("game-010")
	var miss_results: Array[Dictionary] = []
	miss.finished.connect(func(value: Dictionary): miss_results.append(value))
	for _round in 3: _key(miss, KEY_SPACE)
	assert(miss_results.size() == 1 and not miss_results[0].success and not miss_results[0].devil and miss.mistakes == 3, "three early shutters fail honestly without awarding either sticker")
	miss.queue_free()

	for light_phase in ["dawn", "noon", "dusk", "night"]:
		var lit := _new_session("game-010")
		lit.set_time_of_day(light_phase)
		_bubble_capture_session_round(lit, true)
		assert(str(lit.bubble_model.snapshot().photos[0].time_of_day) == light_phase, "each canonical park light phase is stored on the actual captured photo: %s" % light_phase)
		lit.queue_free()

	var paused := _new_session("game-010", true)
	paused._process(0.20)
	paused.set_paused(true)
	var paused_state: Dictionary = paused.bubble_model.snapshot()
	var frozen_photo_time := float(paused_state.round_elapsed)
	paused._process(4.0)
	assert(float(paused.bubble_model.snapshot().round_elapsed) == frozen_photo_time, "pause freezes portrait motion and its shutter clock")
	paused.set_paused(false)
	paused._process(8.0)
	assert(float(paused.bubble_model.snapshot().round_elapsed) == frozen_photo_time, "resume discards the suspended-frame delta instead of catching up")
	for _frame in 3: paused._process(0.05)
	assert(float(paused.bubble_model.snapshot().round_elapsed) > frozen_photo_time, "photo simulation advances again after a normal resumed frame")
	paused.set_practice_mode(true)
	assert(paused.practice_mode and paused.assisted and paused.bubble_model.snapshot().photos.is_empty(), "practice reset retains assistance but clears every photo and score")
	paused.queue_free()
	checks += 1

func _bubble_capture_session_round(session: Control, perfect: bool, offset: Vector2 = Vector2.ZERO) -> void:
	var model = session.bubble_model
	var state: Dictionary = model.snapshot()
	var round_index := int(state.round)
	var target_time := float(model.BEST_POSE_TIMES[round_index])
	while str(model.phase) == "aim" and float(model.snapshot().round_elapsed) < target_time:
		session._process(0.05)
	state = model.snapshot()
	model.set_frame_center(Vector2(state.target_center) + (Vector2.ZERO if perfect else offset))
	session._sync_presentation()
	_key(session, KEY_SPACE)
	assert(str(model.phase) == "exposure" and session.score == int(model.snapshot().score), "the shutter records its actual score immediately and starts exposure")
	while str(model.phase) == "exposure" and not session.ended:
		session._process(0.05)

func _test_melody_boundaries() -> void:
	var s := _new_session("game-012", false)
	var model: Variant = s.get("melody_model")
	_expect(model != null and model.has_method("snapshot"), "game-012 session owns its finite melody model")
	if model == null:
		s.queue_free()
		return
	var results: Array[Dictionary] = []
	var played: Array[int] = []
	s.finished.connect(func(value: Dictionary): results.append(value.duplicate(true)))
	s.note_played.connect(func(note: int): played.append(note))
	var cached_snapshot: Dictionary = model.snapshot()
	var initial_heard := _wait_melody_active(s, model)
	_expect(initial_heard == Model.PHRASES[0], "session playback follows the authored phrase before accepting input")
	_expect(played == Model.PHRASES[0] and int(model.snapshot().note_start_serial) == 3, "session emits each model cue to the audio owner exactly once")
	_expect(is_same(cached_snapshot, model.snapshot()), "session consumes the model's stable cached snapshot without cloning")
	var index_before := int(model.snapshot().input_index)
	_key(s, KEY_1)
	var audio_count_after_first := played.size()
	var echoed := InputEventKey.new()
	echoed.keycode = KEY_3
	echoed.pressed = true
	echoed.echo = true
	s._unhandled_input(echoed)
	s._process(0.03)
	_key(s, KEY_3)
	_expect(int(model.snapshot().input_index) == index_before + 1 and int(model.snapshot().error_count) == 0, "echoes and a second chorded key cannot register rapid duplicate notes")
	_expect(played.size() == audio_count_after_first, "one accepted note input makes one audio event and a chorded retry makes none")
	_expect(s.score == int(model.snapshot().score) and s.score_summary().total == s.score, "session scoring mirrors the model score without a parallel completion bonus")
	s._retry_from_hud()
	_expect(not s.ended and s.score == 0 and model.snapshot().phase == "listen" and int(model.snapshot().input_index) == 0, "retry resets session and melody model together")
	s.set_practice_mode(true)
	_expect(s.practice_mode and model.snapshot().assisted == s.assisted and int(model.snapshot().score) == 0, "practice restarts the same model while preserving the chosen assist setting")
	var model_view_snapshot: Dictionary = model.snapshot()
	s._process(0.025)
	_expect(is_same(model_view_snapshot, model.snapshot()), "practice frames preserve the cached snapshot identity")
	_drive_melody_keys(s, model)
	_expect(results.size() == 1 and bool(results[0].success) and bool(results[0].practice) and not bool(results[0].devil), "model-complete practice emits one ordinary-only result")
	_expect(s.score == int(model.snapshot().score) and s.count == 3 and s.devil_progress == 15, "session completion fields match all three fixed phrases and actual precise notes")
	s.queue_free()

	var formal := _new_session("game-012", false)
	var formal_model: RefCounted = formal.melody_model
	var formal_results: Array[Dictionary] = []
	formal.finished.connect(func(value: Dictionary): formal_results.append(value.duplicate(true)))
	_drive_melody_keys(formal, formal_model)
	_expect(formal_results.size() == 1 and bool(formal_results[0].success) and bool(formal_results[0].devil) and not bool(formal_results[0].practice), "a clean unassisted 3/5/7-note session earns its model-verified devil result exactly once")
	var formal_result: Dictionary = formal_results[0] if not formal_results.is_empty() else {}
	var formal_summary: Dictionary = formal_result.get("score_summary", {})
	_expect(formal.score == int(formal_model.snapshot().score) and int(formal_model.snapshot().precise_notes) == 15 and int(formal_summary.get("total", -1)) == formal.score, "formal session result and score ledger remain aligned with all fifteen notes")
	formal.queue_free()

	var assisted := _new_session("game-012", true)
	var assisted_model: RefCounted = assisted.melody_model
	var assisted_results: Array[Dictionary] = []
	assisted.finished.connect(func(value: Dictionary): assisted_results.append(value.duplicate(true)))
	_drive_melody_keys(assisted, assisted_model)
	_expect(assisted_results.size() == 1 and bool(assisted_results[0].success) and not bool(assisted_results[0].devil) and bool(assisted_results[0].assisted), "assisted timing keeps ordinary completion while the model disqualifies the devil award")
	assisted.queue_free()

	var unbounded := _new_session("game-012")
	unbounded._process(60.0)
	_expect(not unbounded.ended and unbounded.minigame_hud._time.text == "自由節奏", "melody keeps no countdown and cannot succeed while notes remain unreproduced")
	unbounded.queue_free()

	var wrong := _new_session("game-012", true)
	var wrong_model: Variant = wrong.get("melody_model")
	var wrong_results: Array[Dictionary] = []
	var wrong_played: Array[int] = []
	wrong.finished.connect(func(value: Dictionary): wrong_results.append(value.duplicate(true)))
	wrong.note_played.connect(func(note: int): wrong_played.append(note))
	_wait_melody_active(wrong, wrong_model)
	_key(wrong, KEY_4)
	_expect(int(wrong_model.snapshot().error_count) == 1 and str(wrong_model.snapshot().phase) == "wrong_pause" and wrong_results.is_empty(), "wrong instrument uses model retry and cannot finish early")
	_expect(wrong_played.size() == 4 and wrong_played.back() == 3, "wrong attempt still sends its actual instrument note to audio exactly once")
	var retried_heard := _wait_melody_active(wrong, wrong_model)
	_expect(retried_heard == Model.PHRASES[0], "wrong-note retry replays the same fixed phrase")
	wrong.queue_free()
	checks += 1

func _test_bench_swaps_and_devil_boundary() -> void:
	var failed_route := _new_session("game-011", false)
	var failed_results: Array[Dictionary] = []
	failed_route.finished.connect(func(value: Dictionary): failed_results.append(value))
	var failed_model: Variant = failed_route.get("bench_model")
	_expect(failed_model != null and failed_route.presentation != null, "bench Session installs the view and finite model")
	if failed_model == null:
		failed_route.queue_free()
		return
	var initial: Dictionary = failed_model.snapshot()
	_expect(initial.seats.size() == 6, "bench Session starts with six numbered seats")
	_expect(not _bench_rules_satisfied(initial.seats, initial.rules), "first six-seat order is not already solved by its visible rules")
	for attempt in 3:
		_bench_select_keys(failed_route, 0, 2)
		failed_route._process(0.15); failed_route._process(0.15)
		if attempt < 2: _expect(failed_results.is_empty() and int(failed_model.level) == 0, "wrong route remains active before the move budget is exhausted")
	_expect(failed_results.is_empty() and int(failed_model.moves) == 0 and str(failed_model.last_event).contains("次數用完"), "spending the wrong-route budget retries without emitting a result")
	failed_route.queue_free()

	var exact := _new_session("game-011", false)
	var exact_model: Variant = exact.get("bench_model")
	if exact_model == null:
		_expect(false, "ordinary bench Session exposes its independently solvable model")
		exact.queue_free()
		return
	var exact_results: Array[Dictionary] = []
	exact.finished.connect(func(value: Dictionary): exact_results.append(value))
	var expected_points := 0
	for level_index in 3:
		var state: Dictionary = exact_model.snapshot()
		var route := _bench_visible_rule_plan(state.seats, state.rules)
		_expect(route.size() == int(state.optimal_moves) and route.size() == level_index + 1, "visible-rule BFS independently finds the %d-swap target" % (level_index + 1))
		expected_points += 300 - route.size() * 25
		for pair in route:
			_bench_select_keys(exact, int(pair[0]), int(pair[1]))
			exact._process(0.15); exact._process(0.15)
	var final_state: Dictionary = exact_model.snapshot()
	_expect(exact_results.size() == 1 and exact_results[0].success and exact_results[0].devil and not exact_results[0].assisted, "natural exact solution of all three visible-rule orders earns devil success")
	_expect(final_state.finished and final_state.ledger.filter(func(row: Dictionary) -> bool: return bool(row.solved)).size() == 3, "model ledger carries all three naturally solved orders")
	_expect(exact.score == expected_points and exact.score_summary().total == exact.score and exact.score_events.size() == 3, "three per-table score events reconcile exactly to summary total")
	exact.queue_free()

	var assisted := _new_session("game-011", true)
	var assisted_model: Variant = assisted.get("bench_model")
	if assisted_model == null:
		_expect(false, "assisted bench Session exposes its finite model")
		assisted.queue_free()
		return
	var assisted_results: Array[Dictionary] = []
	assisted.finished.connect(func(value: Dictionary): assisted_results.append(value))
	_bench_select_keys(assisted, 0, 2)
	_expect(not assisted_model.snapshot().hint_pair.is_empty() and not assisted_model.rules_satisfied(assisted_model.seats), "assisted hint gives a useful next exchange but does not solve automatically")
	assisted._process(0.15); assisted._process(0.15)
	for level_index in 3:
		var state: Dictionary = assisted_model.snapshot()
		_expect(int(state.level) == level_index, "assisted route reached visible table %d before solving" % (level_index + 1))
		for pair in _bench_visible_rule_plan(state.seats, state.rules):
			_bench_select_keys(assisted, int(pair[0]), int(pair[1]))
			assisted._process(0.15); assisted._process(0.15)
	_expect(assisted_results.size() == 1 and assisted_results[0].success and not assisted_results[0].devil and assisted_results[0].assisted, "assisted exact route keeps ordinary success and excludes devil: %s %s" % [str(assisted_results), str(assisted_model.snapshot())])
	assisted.queue_free()
	checks += 1

func _bench_select_keys(session: Control, first: int, second: int) -> void:
	_key(session, KEY_1 + first)
	_key(session, KEY_1 + second)

func _bench_visible_rule_plan(start: Array, rules: Array) -> Array:
	var queue: Array = [start.duplicate()]
	var parents := {_bench_order_key(start): {"previous":"", "swap":[]}}
	var cursor := 0
	var goal := ""
	while cursor < queue.size():
		var order: Array = queue[cursor]
		cursor += 1
		var key := _bench_order_key(order)
		if _bench_rules_satisfied(order, rules):
			goal = key
			break
		for a in 6:
			for b in range(a + 1, 6):
				var next: Array = order.duplicate()
				var hold: Variant = next[a]
				next[a] = next[b]; next[b] = hold
				var next_key := _bench_order_key(next)
				if parents.has(next_key): continue
				parents[next_key] = {"previous":key, "swap":[a,b]}
				queue.append(next)
	var plan: Array = []
	if goal.is_empty(): return plan
	while str(parents[goal].previous) != "":
		plan.push_front(parents[goal].swap)
		goal = str(parents[goal].previous)
	return plan

func _bench_rules_satisfied(order: Array, rules: Array) -> bool:
	if order.size() != 6: return false
	var sorted: Array = order.duplicate(); sorted.sort()
	if sorted != [0, 1, 2, 3, 4, 5]: return false
	for rule in rules:
		var a := order.find(int(rule.get("a", rule.get("guest", -1))))
		var b := order.find(int(rule.get("b", -1)))
		match str(rule.get("kind", "")):
			"seat": if a != int(rule.seat): return false
			"together": if absi(a - b) != 1: return false
			"apart": if absi(a - b) < 2: return false
	return true

func _bench_order_key(order: Array) -> String:
	return ",".join(order.map(func(value: Variant) -> String: return str(value)))

func _test_timed_action() -> void:
	var exact := _new_session("game-003")
	var results: Array[Dictionary] = []
	exact.finished.connect(func(value: Dictionary): results.append(value))
	_advance_to(exact, exact.FOUNTAIN_FIRST_BEAT)
	_key(exact, KEY_SPACE)
	assert(exact.count == 1 and exact.fountain_attempts == 1)
	_key(exact, KEY_SPACE) # A repeated press before the next pre-cue is ignored.
	assert(exact.count == 1 and exact.fountain_attempts == 1 and exact.score == 300)
	_advance_to(exact, exact._fountain_beat_time(1) + 0.12)
	_click(exact, 640, 360)
	assert(exact.count == 2 and exact.fountain_attempts == 2 and exact.score == 500)
	_advance_to(exact, exact._fountain_beat_time(2) - 0.20)
	_key(exact, KEY_SPACE)
	assert(results.is_empty() and exact.fountain_finish_pending and not exact.ended and exact.score == 600)
	exact._process(exact.fountain_finish_at - exact.phase)
	assert(results.size() == 1)
	assert(results[0].success and not results[0].devil and exact.count == 3 and exact.score == 600)
	assert(results[0].score_summary.rows.size() == 3)
	assert(results[0].score_summary.rows[0].label.contains("完美") and results[0].score_summary.rows[1].label.contains("準確") and results[0].score_summary.rows[2].label.contains("踩中"))
	exact.queue_free()

	var perfect := _new_session("game-003", true)
	var perfect_results: Array[Dictionary] = []
	perfect.finished.connect(func(value: Dictionary): perfect_results.append(value))
	for index in 3:
		_advance_to(perfect, perfect._fountain_beat_time(index) + 0.05)
		_key(perfect, KEY_SPACE)
		if index == 2:
			assert(perfect_results.is_empty() and perfect.fountain_finish_pending and not perfect.ended)
	perfect._process(perfect.fountain_finish_at - perfect.phase)
	assert(perfect_results.size() == 1)
	assert(perfect_results[0].success and perfect_results[0].devil and perfect_results[0].assisted and perfect.score == 900)
	checks += 1

func _test_fountain_quality() -> void:
	# Both sides of each scoring threshold have intentionally distinct outcomes.
	for sample in [[-0.071, "準確", 200], [-0.070, "完美", 300], [0.070, "完美", 300], [0.071, "準確", 200], [-0.161, "踩中", 100], [0.160, "準確", 200], [0.161, "踩中", 100], [0.220, "踩中", 100]]:
		var timing := _new_session("game-003")
		_advance_to(timing, timing.FOUNTAIN_FIRST_BEAT + float(sample[0]))
		_key(timing, KEY_SPACE)
		if timing.fountain_grades != [sample[1]] or timing.score != int(sample[2]):
			print("FOUNTAIN boundary mismatch input=", sample[0], " phase=", timing.phase, " grades=", timing.fountain_grades, " score=", timing.score)
		assert(timing.fountain_grades == [sample[1]] and timing.score == int(sample[2]))
		timing.queue_free()
	checks += 1

	var too_early := _new_session("game-003")
	_advance_to(too_early, too_early.FOUNTAIN_FIRST_BEAT - too_early._fountain_hit_tolerance() - 0.01)
	_key(too_early, KEY_SPACE)
	assert(too_early.fountain_attempts == 0 and too_early.mistakes == 0)
	too_early.queue_free()
	checks += 1

	var normal_miss := _new_session("game-003")
	var miss_results: Array[Dictionary] = []
	normal_miss.finished.connect(func(value: Dictionary): miss_results.append(value))
	normal_miss._process(normal_miss.FOUNTAIN_FIRST_BEAT + normal_miss._fountain_hit_tolerance() + 0.01)
	assert(normal_miss.fountain_attempts == 1 and normal_miss.count == 0 and normal_miss.mistakes == 1)
	assert(normal_miss.score_events[0].label.contains("錯過") and int(normal_miss.score_events[0].amount) == 0)
	# Two successes do not unlock the ordinary sticker when the third opportunity is missed.
	for index in range(1, 3):
		_advance_to(normal_miss, normal_miss._fountain_beat_time(index))
		_key(normal_miss, KEY_SPACE)
		normal_miss._process(normal_miss._fountain_hit_tolerance() + 0.01)
		if index == 2:
			assert(miss_results.is_empty() and normal_miss.fountain_finish_pending and not normal_miss.ended)
	if normal_miss.fountain_finish_pending:
		normal_miss._process(normal_miss.fountain_finish_at - normal_miss.phase)
	assert(miss_results.size() == 1 and not miss_results[0].success and not miss_results[0].devil)
	normal_miss.queue_free()
	checks += 1

	var assisted := _new_session("game-003", true)
	_advance_to(assisted, assisted.FOUNTAIN_FIRST_BEAT + 0.30)
	_key(assisted, KEY_SPACE)
	assert(assisted.count == 1 and assisted.score == 100 and assisted.fountain_grades[0] == "踩中")
	assisted.queue_free()
	var standard := _new_session("game-003")
	_advance_to(standard, standard.FOUNTAIN_FIRST_BEAT + 0.30)
	assert(standard.fountain_attempts == 1 and standard.mistakes == 1 and standard.count == 0)
	standard.queue_free()
	checks += 1

	var paused := _new_session("game-003")
	_advance_to(paused, paused.FOUNTAIN_FIRST_BEAT)
	_key(paused, KEY_SPACE)
	var stopped_phase: float = paused.phase
	paused.set_paused(true)
	paused._process(2.0)
	assert(is_equal_approx(paused.phase, stopped_phase) and paused.fountain_attempts == 1)
	paused.set_paused(false)
	paused._process(0.15) # First frame is discarded after resume.
	assert(is_equal_approx(paused.phase, stopped_phase))
	paused._process(0.15)
	assert(is_equal_approx(paused.phase, stopped_phase + 0.15))
	paused.queue_free()
	checks += 1

	var slow_frame := _new_session("game-003")
	var slow_results: Array[Dictionary] = []
	slow_frame.finished.connect(func(value: Dictionary): slow_results.append(value))
	slow_frame._process(4.5)
	assert(slow_results.size() == 1 and slow_frame.fountain_attempts == 3 and slow_frame.count == 0 and slow_frame.mistakes == 3)
	slow_frame.queue_free()
	checks += 1

	var reduced := _new_session("game-003")
	reduced.reduced_motion = true
	for index in 3:
		_advance_to(reduced, reduced._fountain_beat_time(index))
		_key(reduced, KEY_SPACE)
		if index == 2:
			assert(reduced.fountain_finish_pending and not reduced.ended)
	reduced._process(reduced.fountain_finish_at - reduced.phase)
	assert(reduced.won and reduced.devil_won and reduced.score == 900)
	reduced.queue_free()
	checks += 1

func _advance_to(session: Control, target_phase: float) -> void:
	var amount := target_phase - float(session.phase)
	assert(amount >= 0.0)
	if amount > 0.0:
		session._process(amount)

func _test_vertical_input_and_hat_consumption() -> void:
	var kite := _new_session("game-002")
	var start_y: float = kite.p.y
	_key(kite, KEY_UP)
	kite._process(0.1)
	_key_release(kite, KEY_UP)
	assert(kite.p.y < start_y)
	kite.queue_free()

	var hats := _new_session("game-005")
	hats.p.x = hats.hat_x[0]
	hats.hat_y[0] = 561.0
	hats._process(0.01)
	assert(hats.count == 1 and hats.hats_consumed[0])
	hats._process(0.01)
	assert(hats.count == 1 and hats.mistakes == 0)
	hats.queue_free()
	checks += 1

func _test_flower_pipe_route() -> void:
	var s := _new_session("game-007")
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	var routes := [[0,4,6,15], [0,1,2,3,4,8,12], [0,1,2,3,6,10,14,15]]
	for order in 3:
		for cell in routes[order]:
			_click(s, 400 + (cell % 4) * 160, 216 + int(cell / 4) * 100)
		assert(s.pipe_connected and results.is_empty())
		s._process(0.5)
		assert(results.is_empty() and s.pipe_model.order_index == order)
		s._process(0.7)
		assert(results.is_empty())
		if order < 2: assert(s.pipe_model.order_index == order + 1 and not s.pipe_connected)
	s._process(0.21)
	assert(results.size() == 1 and results[0].success and results[0].devil)
	assert(s.move_count == 19 and s.score == 2620 and s.score_summary().total == 2620)
	checks += 1

func _test_escape_cancels() -> void:
	var s := _new_session("game-002")
	var cancelled_count := [0]
	var finished_count := [0]
	s.cancelled.connect(func(): cancelled_count[0] += 1)
	s.finished.connect(func(_result: Dictionary): finished_count[0] += 1)
	_key(s, KEY_ESCAPE)
	assert(s.get_viewport().is_input_handled())
	_expect(s.get("paused") == true and cancelled_count[0] == 0 and finished_count[0] == 0, "Escape pauses instead of leaving")
	var hud: Object = s.get("minigame_hud")
	_expect(hud != null and hud.has_signal("leave_requested"), "HUD exposes explicit leave request")
	if hud != null and hud.has_signal("leave_requested"):
		hud.emit_signal("leave_requested")
	_expect(cancelled_count[0] == 1 and finished_count[0] == 0, "explicit HUD leave cancels once")
	s.queue_free()
	checks += 1

func _test_pause_practice_and_score_summary() -> void:
	var balloon := _new_session("game-001")
	var intro_pos: Vector2 = balloon.p
	var intro_phase: float = balloon.phase
	if balloon.has_method("set_paused"):
		balloon.set_paused(true)
	else:
		_expect(false, "session exposes set_paused")
	balloon._process(2.0)
	_key(balloon, KEY_RIGHT)
	_expect(balloon.get("paused") == true and balloon.elapsed == 0.0, "paused intro freezes timer")
	_expect(balloon.phase == intro_phase and balloon.p == intro_pos, "paused intro freezes simulation")
	if balloon.has_method("set_paused"):
		balloon.set_paused(false)
	balloon._process(0.05)
	_expect(balloon.phase == intro_phase and balloon.p == intro_pos, "resume discards one stale frame")
	balloon._process(0.05)
	_expect(balloon.phase > intro_phase and balloon.p != intro_pos, "resume advances the intro")
	_key(balloon, KEY_ENTER)
	balloon._process(0.05)
	var active_pos: Vector2 = balloon.p
	var active_phase: float = balloon.phase
	var active_elapsed: float = balloon.elapsed
	balloon.set_paused(true)
	_mouse_move(balloon, 900, 500)
	balloon._process(10.0)
	_expect(balloon.p == active_pos and balloon.phase == active_phase and balloon.elapsed == active_elapsed, "paused active flight ignores input and long delta")
	balloon.set_paused(false)
	balloon._process(10.0)
	_expect(balloon.phase == active_phase and balloon.elapsed == active_elapsed, "first resumed frame discards suspended delta")
	balloon._process(0.05)
	_expect(balloon.phase > active_phase and balloon.elapsed > active_elapsed, "normal frames resume after the stale delta")
	var helped: Array[String] = []
	balloon.help_requested.connect(func(id: String): helped.append(id))
	balloon.request_help()
	_expect(balloon.paused and helped == ["game-001"], "help request pauses and passes the game id")
	balloon.queue_free()

	var practice := _new_session("game-002")
	practice.score = 123
	if practice.has_method("set_practice_mode"):
		practice.set_practice_mode(true)
	else:
		_expect(false, "session exposes set_practice_mode")
	_expect(practice.get("practice_mode") == true and practice.score == 0 and practice.elapsed == 0.0, "practice resets the active round")
	var results: Array[Dictionary] = []
	practice.finished.connect(func(value: Dictionary): results.append(value))
	practice._finish(true, true)
	_expect(results.size() == 1 and results[0].get("practice", false) == true, "practice result is marked")
	_expect(results[0].success and results[0].devil, "practice retains actual qualification results")
	_expect(results[0].get("score_summary", {}).get("total", -1) == practice.score, "result includes current score summary")
	practice.queue_free()

	for number in range(1, 13):
		var session := _new_session("game-%03d" % number)
		var summary: Dictionary = {}
		if session.has_method("score_summary"):
			summary = session.score_summary()
		else:
			_expect(false, "session exposes score_summary for mode %d" % number)
		_expect(summary.get("total", -1) == session.score, "mode %d summary totals actual score" % number)
		_expect(summary.get("rows", []) is Array and not summary.get("rows", []).is_empty(), "mode %d has score detail rows" % number)
		session.queue_free()
	checks += 1

func _test_hud_signals_and_state() -> void:
	var hud: Control = HUD.new()
	root.add_child(hud)
	var pause_count := [0]
	var help_count := [0]
	hud.pause_requested.connect(func(): pause_count[0] += 1)
	hud.help_requested.connect(func(): help_count[0] += 1)
	hud.set_state({"title":"彩帶節拍", "objective":"按下節拍", "progress_text":"第 2 拍", "score":75, "time_text":"00:42", "assisted":true, "reduced_motion":true})
	_expect(hud._title.text == "彩帶節拍", "HUD updates the title")
	_expect(hud._objective.text == "按下節拍" and hud._progress.text == "第 2 拍", "HUD updates goal and progress")
	_expect(hud._score.text == "0075" and hud._time.text == "00:42", "HUD updates score and time")
	hud.find_child("PauseButton", true, false).emit_signal("pressed")
	hud.find_child("HelpButton", true, false).emit_signal("pressed")
	_expect(pause_count[0] == 1 and help_count[0] == 1, "header controls emit requests once")
	hud.set_score_details({"total":75, "label":"分數", "rule":"命中節拍加分", "rows":[{"label":"踩中節拍", "count":1, "amount":75}, {"label":"失誤", "count":1, "amount":0, "progress_only":true}]})
	hud.open_score_details()
	_expect(hud._score_layer.visible and hud._score_rows.get_child_count() == 4, "score details show rule, actual events, and total")
	hud.queue_free()
	checks += 1

func _test_bounded_score_ledger_and_hud_rate() -> void:
	var session := _new_session("game-001")
	for index in 40:
		session._award_points("source_%02d" % index, "來源 %02d" % index, index + 1)
	_expect(session.score_events.size() <= 32, "score ledger stays within fixed category bound")
	var summary: Dictionary = session.score_summary()
	_expect(summary.total == session.score, "bounded aggregation preserves exact score total")
	_expect(session.score_events[-1].key == "other_events" and session.score_events[-1].count == 9, "overflow categories aggregate without dropping counts")
	session._hud_refresh_clock = 0.0
	session._hud_dirty = false
	var previous_score_text: String = session.minigame_hud._score.text
	session._refresh_hud()
	_expect(session._hud_dirty and session.minigame_hud._score.text == previous_score_text, "HUD refreshes are throttled between 10 Hz updates")
	session._process(0.1)
	_expect(session.minigame_hud._score.text == "%04d" % session.score, "dirty HUD state publishes on the next 10 Hz tick")
	session.queue_free()
	checks += 1

func _wait_melody_active(session: Control, model: RefCounted) -> Array[int]:
	var heard: Array[int] = []
	var budget := 1000
	while str(model.snapshot().phase) != "active" and budget > 0:
		session._process(0.025)
		var current: Array = model.snapshot().get("heard_notes", [])
		for index in range(heard.size(), current.size()):
			heard.append(int(current[index]))
		budget -= 1
	return heard

func _drive_melody_keys(session: Control, model: RefCounted) -> void:
	var phrase_cursor := -1
	var next_input_time := 0.05
	var budget := 10000
	while not bool(model.snapshot().ended) and budget > 0:
		var state: Dictionary = model.snapshot()
		if str(state.phase) != "active":
			session._process(0.025)
		else:
			var phrase_index := int(state.phrase_index)
			if phrase_cursor != phrase_index:
				phrase_cursor = phrase_index
				next_input_time = 0.05
			var phase_time := float(state.phase_elapsed)
			if phase_time + 0.0001 < next_input_time:
				session._process(minf(0.025, next_input_time - phase_time))
			else:
				var input_index := int(state.input_index)
				_key(session, KEY_1 + int(Model.PHRASES[phrase_index][input_index]))
				var next_index := input_index + 1
				if next_index < Model.PHRASES[phrase_index].size():
					next_input_time = float(model.snapshot().phase_elapsed) + float(Model.RHYTHMS[phrase_index][next_index])
		budget -= 1


func _new_session(id: String, assisted: bool = false) -> Control:
	var session: Control = Session.new()
	root.add_child(session)
	session.start(id, assisted)
	return session

func _click(session: Control, x: float, y: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(x, y)
	session._unhandled_input(event)

func _mouse_move(session: Control, x: float, y: float) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(x, y)
	session._unhandled_input(event)

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

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed_checks += 1
	push_error("FAIL: " + message)




func _test_all_modes() -> void:
	for assisted in [false, true]:
		for number in range(1, 13):
			var s := _new_session("game-%03d" % number, assisted)
			var definition: Dictionary = Session.definitions()[number - 1]
			assert(s.minigame_hud._title.text == str(definition.name), "HUD title must be correct immediately after start: %s" % definition.id)
			assert(s.minigame_hud._objective.text == str(definition.goal), "HUD objective must be correct immediately after start: %s" % definition.id)
			var results: Array[Dictionary] = []
			s.finished.connect(func(value: Dictionary): results.append(value))
			var last_cycle := -1
			var waypoint := 0
			var balloon_steps := 0
			var pipe_order_played := -1
			var bench_order_played := -1
			if number == 1: _key(s, KEY_ENTER)
			if number == 6:
				var gestures: Array = s.ribbon_model.GESTURES
				for gesture_index in gestures.size():
					var cue_time := 1.02 + float(gesture_index) * 0.94
					_advance_ribbon_to(s, cue_time)
					var action := str(gestures[gesture_index].action)
					var keycode := KEY_LEFT if action == "left" else (KEY_RIGHT if action == "right" else KEY_SPACE)
					_key(s, keycode)
					if float(gestures[gesture_index].hold) > 0.0:
						_advance_ribbon_to(s, cue_time + float(gestures[gesture_index].hold))
						_key_release(s, keycode)
			while not s.ended and number != 6:
				match number:
					1:
						var points: Array[Vector2] = [Vector2(520, 305), Vector2(780, 270), Vector2(820, 480), Vector2(1080, 320)]
						if s.balloon_delivery_index == 1 and waypoint == 0: waypoint = 1
						if s.balloon_delivery_index == 2: waypoint = 3
						var point: Vector2 = points[waypoint]
						_mouse_move(s, point.x, point.y)
						if waypoint == 1 and s.p.distance_to(point) < 30.0: waypoint = 2
						var dock_distance: float = s.p.distance_to(s.target)
						var stop_early: bool = dock_distance < 150.0 and s.velocity.length() > s.balloon_dock_speed
						var hold_at_dock: bool = dock_distance <= s.balloon_dock_radius
						var finish_braking: bool = s.balloon_braking and dock_distance <= s.balloon_dock_radius + 40.0
						var should_brake: bool = s.balloon_delivery_index < 3 and (stop_early or hold_at_dock or finish_braking) and waypoint != 1
						if should_brake != s.balloon_braking:
							_key(s, KEY_SPACE) if should_brake else _key_release(s, KEY_SPACE)
					2:
						_kite_drive_step(s, 0.01)
					3:
						if s.beat_window: _key(s, KEY_SPACE)
					4:
						var chosen := _crowd_priority_lane(s.crowd_model)
						if chosen >= 0 and s.crowd_model.desired_lane != chosen:
							_key(s, KEY_Q if chosen == 0 else KEY_E)
					5:
						var closest := -1
						var closest_y := -INF
						for i in s.hat_y.size():
							if not s.hats_consumed[i] and s.hat_y[i] > closest_y:
								closest = i; closest_y = s.hat_y[i]
						if closest >= 0: _mouse_move(s, s.hat_x[closest], 570)
					7:
						if s.pipe_model.order_index != pipe_order_played:
							pipe_order_played = s.pipe_model.order_index
							var routes := [[0,4,6,15], [0,1,2,3,4,8,12], [0,1,2,3,6,10,14,15]]
							for cell in routes[pipe_order_played]: _click(s, 400 + (cell % 4) * 160, 216 + int(cell / 4) * 100)
					8:
						var sign_state: Dictionary = s.sign_model.snapshot()
						var target_angle := float(sign_state.target_angle)
						var torque := float(sign_state.wind_torque)
						if bool(sign_state.forecast_visible): torque = float(sign_state.forecast_torque)
						var angle_error := float(sign_state.angle) - target_angle
						var desired_accel := -8.0 * angle_error - 4.0 * float(sign_state.angular_velocity)
						var restoring: float = -s.sign_model.RESTORE_TORQUE * angle_error
						s.sign_model.set_balance(clampf((desired_accel - torque - restoring + s.sign_model.ANGULAR_DAMPING * float(sign_state.angular_velocity)) / s.sign_model.COUNTERWEIGHT_TORQUE, -1.0, 1.0))
					9: _mouse_move(s, 802 if assisted else 640, 420)
					10:
						var photo_state: Dictionary = s.bubble_model.snapshot()
						if str(photo_state.phase) == "aim" and float(photo_state.round_elapsed) >= float(s.bubble_model.BEST_POSE_TIMES[int(photo_state.round)]):
							var center: Vector2 = photo_state.target_center
							_mouse_move(s, center.x, center.y)
							_key(s, KEY_SPACE)
					11:
						if int(s.bench_model.level) != bench_order_played:
							bench_order_played = int(s.bench_model.level)
							var bench_state: Dictionary = s.bench_model.snapshot()
							var plan := _bench_visible_rule_plan(bench_state.seats, bench_state.rules)
							assert(plan.size() == int(bench_state.optimal_moves) and plan.size() == bench_order_played + 1)
							for pair in plan:
								_bench_select_keys(s, int(pair[0]), int(pair[1]))
								s._process(0.15); s._process(0.15)
					12:
						_drive_melody_keys(s, s.melody_model)
				if not s.ended:
					s._process(0.05 if number == 1 else 0.01)
					if number == 1:
						balloon_steps += 1
						assert(balloon_steps < 1100, "Balloon route solver made no bounded progress assist=%s index=%d pos=%s target=%s" % [assisted, s.balloon_delivery_index, s.p, s.target])
			Input.action_release("ui_right"); Input.action_release("ui_left")
			if number == 1:
				assert(results.size() == 1 and results[0].success and results[0].devil, "Reachability balloon assist=%s state=%s mistakes=%d elapsed=%f" % [assisted, str(results), s.mistakes, s.elapsed])
			else:
				var expected_devil: bool = (not assisted) if number in [2, 6, 11, 12] else true
				assert(results.size() == 1 and results[0].success and results[0].devil == expected_devil, "Reachability game-%03d assist=%s results=%s" % [number, assisted, str(results)])
			var score_detail: Dictionary = results[0].get("score_summary", {})
			var displayed_total := 0
			for row in score_detail.get("rows", []):
				displayed_total += int(row.get("amount", 0))
			_expect(score_detail.get("total", -1) == s.score and displayed_total == s.score, "mode %d score rows match actual total" % number)
			s.queue_free()
			var timeout := _new_session("game-%03d" % number, assisted)
			var timeout_results: Array[Dictionary] = []
			timeout.finished.connect(func(value: Dictionary): timeout_results.append(value))
			if number == 1: _key(timeout, KEY_ENTER)
			if number == 11:
				timeout._process(60.0)
				_expect(not timeout.ended and timeout_results.is_empty(), "Bench has no countdown and cannot complete before satisfying all table rules")
			elif number == 12:
				timeout._process(60.0)
				_expect(not timeout.ended and timeout_results.is_empty(), "Melody Memory has no timer and cannot complete without reproducing its phrases")
			else:
				timeout._process(60.0)
				assert(timeout_results.size() == 1 and not timeout_results[0].success and not timeout_results[0].devil)
				_expect(timeout_results[0].get("score_summary", {}).get("total", -1) == timeout.score, "timeout result includes actual score summary")
			timeout.queue_free()
			checks += 1
	var spam := _new_session("game-006")
	spam._process(0.01)
	for key in [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]: _key(spam, key)
	assert(spam.beat == 0 and not spam.ended and spam.ribbon_model.snapshot().correct_count == 0, "early spam does not advance cues or create an automatic answer")
	while not spam.ended: spam._process(0.01)
	var spam_state: Dictionary = spam.ribbon_model.snapshot()
	assert(not spam.won and not spam.devil_won and spam.mistakes == int(spam_state.error_count) and int(spam_state.correct_count) == 0 and int(spam_state.missed_count) == 8 and spam.score == 0, "spam earns no answers or score; each scheduled cue resolves as a miss")
	spam.queue_free()

func _test_photo_and_rhythm_grades() -> void:
	var repeated_photo := _new_session("game-010")
	var repeated_state: Dictionary = repeated_photo.bubble_model.snapshot()
	var repeat_target_time := float(repeated_photo.bubble_model.BEST_POSE_TIMES[int(repeated_state.round)])
	while float(repeated_photo.bubble_model.snapshot().round_elapsed) < repeat_target_time:
		repeated_photo._process(0.05)
	repeated_state = repeated_photo.bubble_model.snapshot()
	repeated_photo.bubble_model.set_frame_center(repeated_state.target_center)
	_key(repeated_photo, KEY_SPACE)
	var captured_once: int = repeated_photo.bubble_model.snapshot().photos.size()
	var score_once: int = repeated_photo.score
	_key(repeated_photo, KEY_SPACE)
	assert(captured_once == 1 and repeated_photo.bubble_model.snapshot().photos.size() == captured_once and repeated_photo.score == score_once, "a repeated shutter during one exposure cannot create another photo or score")
	while str(repeated_photo.bubble_model.phase) == "exposure":
		repeated_photo._process(0.05)
	assert(repeated_photo.bubble_model.snapshot().photos.size() == 1, "exposure completion advances without replaying the previous shutter")
	repeated_photo.queue_free()

	var two_and_timeout := _new_session("game-010")
	_bubble_capture_session_round(two_and_timeout, true)
	_bubble_capture_session_round(two_and_timeout, true)
	while not two_and_timeout.ended:
		two_and_timeout._process(0.25)
	var timeout_photos: Array = two_and_timeout.bubble_model.snapshot().photos
	var captured_score_total := 0
	for photo_entry in timeout_photos:
		captured_score_total += int(photo_entry.get("score", 0))
	var ledger_total := int(two_and_timeout.score_summary().total)
	assert(two_and_timeout.won and not two_and_timeout.devil_won and timeout_photos.size() == 3 and str(timeout_photos[2].reason) == "timeout", "two qualified full-body photos and a genuine third-round timeout award ordinary success only")
	assert(two_and_timeout.score == captured_score_total and ledger_total == captured_score_total, "timeout result and score ledger equal the scores of the two actual captures")
	two_and_timeout.queue_free()

	for assisted in [false, true]:
		var photo := _new_session("game-010", assisted)
		_bubble_capture_session_round(photo, true)
		_bubble_capture_session_round(photo, true)
		_bubble_capture_session_round(photo, false, Vector2(32, 0))
		assert(photo.won and not photo.devil_won and photo.beat == 3 and photo.devil_progress == 2, "two perfect plus one slightly offset photo reach ordinary only")
		assert(photo.score == 294 and photo.mistakes == 0, "off-center image receives the actual lower composition score without a fabricated miss")
		photo.queue_free()
		var rhythm := _new_session("game-006", assisted)
		var gestures: Array = rhythm.ribbon_model.GESTURES
		for cycle in gestures.size():
			var cue_time := 1.02 + float(cycle) * 0.94
			_advance_ribbon_to(rhythm, cue_time)
			var action := str(gestures[cycle].action)
			rhythm._on_ribbon_action_pressed(action)
			if float(gestures[cycle].hold) > 0.0:
				_advance_ribbon_to(rhythm, cue_time + float(gestures[cycle].hold))
				rhythm._on_ribbon_action_released(action)
		assert(rhythm.won and rhythm.devil_won == not assisted and rhythm.mistakes == 0)
		rhythm.queue_free()
		checks += 1

func _test_native_input_routing() -> void:
	var s := _new_session("game-001")
	s.set_process(false)
	await process_frame
	var before: Vector2 = s.p
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1060, 345)
	root.push_input(motion, true)
	Input.flush_buffered_events()
	await process_frame
	assert(s.mouse_steering and s.steering_target == Vector2(1060, 345))
	assert(s.p == before and not s.ended)
	s._process(0.01)
	assert(s.p.distance_to(before) < 3.0)
	s.queue_free()
	await process_frame
	var bubble := _new_session("game-010")
	bubble.set_process(false)
	await process_frame
	var frame_motion := InputEventMouseMotion.new()
	frame_motion.position = Vector2(700, 390)
	root.push_input(frame_motion, true)
	Input.flush_buffered_events()
	await process_frame
	assert(bubble.bubble_model.snapshot().frame_center == Vector2(700, 390), "native mouse motion moves the model-backed camera frame")
	var click := InputEventMouseButton.new()
	click.position = Vector2(1020, 184)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	Input.flush_buffered_events()
	await process_frame
	assert(bubble.bubble_model.snapshot().photos.size() == 1 and bubble.mistakes == 1, "native shutter click consumes one premature exposure")
	bubble.queue_free()
	await process_frame
	checks += 1

func _test_kite_native_pointer_routing() -> void:
	_kite_pointer_test_completed = false
	# Match native/Main fullscreen GUI ancestry; an ancestor STOP must not steal
	# the flight surface's mouse events before Session._unhandled_input.
	var host := Control.new()
	host.name = "KiteStopControlHost"
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var kite: Control = Session.new()
	host.add_child(kite)
	kite.start("game-002")
	kite.set_process(false)
	kite._sync_presentation()
	await process_frame
	_expect(is_instance_valid(kite.presentation),"kite pointer regression has a real headless flight Control")
	if not is_instance_valid(kite.presentation):
		host.queue_free()
		await process_frame
		return
	var design_point := Vector2(640,446.6233)
	var viewport_point: Vector2 = kite.presentation.get_global_transform_with_canvas() * design_point
	var physical_point := root.get_final_transform() * viewport_point
	var motion := InputEventMouseMotion.new()
	motion.position = physical_point
	motion.global_position = physical_point
	motion.relative = physical_point-root.get_final_transform()*root.get_mouse_position()
	motion.window_id = root.get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_expect(is_equal_approx(float(kite.kite_model.snapshot().aim),(390.0-design_point.y)/235.0),"native kite window-coordinate pointer dispatch applies the height aim through GUI/input")
	_expect(root.get_mouse_position().distance_to(viewport_point)<0.01,"native kite event uses the actual window-to-viewport stretch transform")
	_expect(root.gui_get_hovered_control()==kite.presentation,"kite GUI target is the flight surface instead of its STOP ancestor")
	await process_frame
	for input_case in [[MOUSE_BUTTON_LEFT,true],[MOUSE_BUTTON_LEFT,false],[MOUSE_BUTTON_RIGHT,true],[MOUSE_BUTTON_RIGHT,false]]:
		var flight_button := InputEventMouseButton.new()
		flight_button.position = physical_point
		flight_button.global_position = physical_point
		flight_button.button_index = input_case[0]
		flight_button.pressed = input_case[1]
		flight_button.button_mask = (MOUSE_BUTTON_MASK_LEFT if input_case[0]==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if input_case[1] else 0
		flight_button.window_id = root.get_window_id()
		Input.parse_input_event(flight_button)
		Input.flush_buffered_events()
		var action_active: bool = kite.kite_model.boost if input_case[0]==MOUSE_BUTTON_LEFT else kite.kite_model.reel
		_expect(action_active==bool(input_case[1]),"real flight GUI mouse button %d changes boost/reel to %s" % [input_case[0],str(input_case[1])])
	var before_hud: float = kite.kite_model.snapshot().aim
	var pause_button: Button = kite.minigame_hud.find_child("PauseButton",true,false)
	_expect(is_instance_valid(pause_button),"kite pointer regression retains the real PauseButton")
	if not is_instance_valid(pause_button):
		host.queue_free()
		await process_frame
		return
	var pause_point := root.get_final_transform() * pause_button.get_global_rect().get_center()
	motion = InputEventMouseMotion.new()
	motion.position = pause_point
	motion.global_position = pause_point
	motion.window_id = root.get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_expect(is_equal_approx(float(kite.kite_model.snapshot().aim),before_hud),"kite pointer over the real HUD does not steer through GUI")
	_expect(root.gui_get_hovered_control()==pause_button,"native kite hover remains on the actual PauseButton")
	for pressed in [true,false]:
		var button := InputEventMouseButton.new()
		button.position = pause_point
		button.global_position = pause_point
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.pressed = pressed
		button.window_id = root.get_window_id()
		Input.parse_input_event(button)
		Input.flush_buffered_events()
	_expect(kite.paused and not kite.kite_model.boost,"real kite HUD pause click pauses instead of boosting")
	motion = InputEventMouseMotion.new()
	motion.position = physical_point
	motion.global_position = physical_point
	motion.window_id = root.get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_expect(is_equal_approx(float(kite.kite_model.snapshot().aim),before_hud),"paused native kite ignores play-area pointer motion")
	host.queue_free()
	await process_frame
	checks += 1
	_kite_pointer_test_completed = true
