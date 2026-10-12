extends SceneTree

const Session = preload("res://game/minigames/session.gd")
const HUD = preload("res://game/ui/minigame_hud.gd")
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
	var s := _new_session("game-006", true)
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	var sequence: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]
	for i in 8:
		while not s.beat_window: s._process(0.01)
		_key(s, sequence[i])
		if i < 7: s._process(0.82)
	assert(results.size() == 1 and results[0].success and results[0].devil and results[0].assisted)
	s.queue_free()

	var wrong := _new_session("game-006", true)
	var wrong_results: Array[Dictionary] = []
	wrong.finished.connect(func(value: Dictionary): wrong_results.append(value))
	wrong._process(0.01)
	_key(wrong, KEY_RIGHT)
	assert(wrong.mistakes == 1 and wrong.beat == 1 and wrong_results.is_empty())
	wrong.queue_free()
	checks += 1

func _test_sign_boundaries() -> void:
	var s := _new_session("game-008", true)
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	while not s.ended and s.phase < 9.0:
		var wind: float = sin(s.phase * 1.7) * 0.32
		var expected: float = s.balance + wind * 0.01
		Input.action_release("ui_right"); Input.action_release("ui_left")
		if expected > 0.0: Input.action_press("ui_right")
		elif expected < 0.0: Input.action_press("ui_left")
		s._process(0.01)
	Input.action_release("ui_right"); Input.action_release("ui_left")
	assert(results.size() == 1 and results[0].success and results[0].devil)
	s.queue_free()

	var bad := _new_session("game-008", true)
	var bad_results: Array[Dictionary] = []
	bad.finished.connect(func(value: Dictionary): bad_results.append(value))
	Input.action_press("ui_left")
	for i in 250: bad._process(0.01)
	Input.action_release("ui_left")
	assert(bad_results.size() == 1 and not bad_results[0].success)
	bad.queue_free()
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
	var s := _new_session("game-012", true)
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	while s.count < 3:
		while s.sequence_showing: s._process(0.1)
		for note in s.sequence.duplicate(): _key(s, KEY_1 + note)
	assert(results.size() == 1 and results[0].success and results[0].devil and results[0].assisted)
	s.queue_free()

	var wrong := _new_session("game-012", true)
	var wrong_results: Array[Dictionary] = []
	wrong.finished.connect(func(value: Dictionary): wrong_results.append(value))
	while wrong.sequence_showing: wrong._process(0.1)
	_key(wrong, KEY_1 + ((wrong.sequence[0] + 1) % 4))
	assert(wrong.mistakes == 1 and wrong_results.is_empty())
	wrong.queue_free()
	checks += 1

func _test_bench_swaps_and_devil_boundary() -> void:
	var incomplete := _new_session("game-011", false)
	var incomplete_results: Array[Dictionary] = []
	incomplete.finished.connect(func(value: Dictionary): incomplete_results.append(value))
	_click(incomplete, 425, 340); _click(incomplete, 425, 340)
	assert(incomplete_results.is_empty() and incomplete.move_count == 1)
	incomplete.queue_free()

	var s := _new_session("game-011", false)
	var result: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): result.append(value))
	for pair in [[425.0, 560.0], [560.0, 830.0], [695.0, 830.0]]:
		_click(s, pair[0], 340)
		_click(s, pair[1], 340)
	assert(result.size() == 1)
	assert(result[0].success and result[0].devil and not result[0].assisted)
	assert(s.seats == [0, 1, 2, 3])
	s.queue_free()

	var assisted := _new_session("game-011", true)
	var assisted_result: Array[Dictionary] = []
	assisted.finished.connect(func(value: Dictionary): assisted_result.append(value))
	for pair in [[425.0, 560.0], [560.0, 830.0], [695.0, 830.0]]:
		_click(assisted, pair[0], 340)
		_click(assisted, pair[1], 340)
	assert(assisted_result.size() == 1)
	assert(assisted_result[0].success and assisted_result[0].devil and assisted_result[0].assisted)
	checks += 1

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
			var rhythm: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]
			var last_cycle := -1
			var waypoint := 0
			var balloon_steps := 0
			var pipe_order_played := -1
			if number == 1: _key(s, KEY_ENTER)
			while not s.ended:
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
					6:
						if s.beat_window and s.beat < 8: _key(s, rhythm[s.beat])
					7:
						if s.pipe_model.order_index != pipe_order_played:
							pipe_order_played = s.pipe_model.order_index
							var routes := [[0,4,6,15], [0,1,2,3,4,8,12], [0,1,2,3,6,10,14,15]]
							for cell in routes[pipe_order_played]: _click(s, 400 + (cell % 4) * 160, 216 + int(cell / 4) * 100)
					8:
						Input.action_release("ui_right"); Input.action_release("ui_left")
						var expected: float = s.balance + sin((s.phase + 0.01) * 1.7) * (0.32 if assisted else 0.50) * 0.01
						Input.action_press("ui_right" if expected > 0 else "ui_left")
					9: _mouse_move(s, 802 if assisted else 640, 420)
					10:
						var photo_state: Dictionary = s.bubble_model.snapshot()
						if str(photo_state.phase) == "aim" and float(photo_state.round_elapsed) >= float(s.bubble_model.BEST_POSE_TIMES[int(photo_state.round)]):
							var center: Vector2 = photo_state.target_center
							_mouse_move(s, center.x, center.y)
							_key(s, KEY_SPACE)
					11:
						for pair in [[425,560], [560,830], [695,830]]:
							_click(s, pair[0], 340); _click(s, pair[1], 340)
					12:
						if not s.sequence_showing:
							for note in s.sequence.duplicate(): _key(s, KEY_1 + note)
				if not s.ended:
					s._process(0.05 if number == 1 else 0.01)
					if number == 1:
						balloon_steps += 1
						assert(balloon_steps < 1100, "Balloon route solver made no bounded progress assist=%s index=%d pos=%s target=%s" % [assisted, s.balloon_delivery_index, s.p, s.target])
			Input.action_release("ui_right"); Input.action_release("ui_left")
			if number == 1:
				assert(results.size() == 1 and results[0].success and results[0].devil, "Reachability balloon assist=%s state=%s mistakes=%d elapsed=%f" % [assisted, str(results), s.mistakes, s.elapsed])
			else:
				var expected_devil: bool = (not assisted) if number == 2 else true
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
			timeout._process(60.0)
			assert(timeout_results.size() == 1 and not timeout_results[0].success and not timeout_results[0].devil)
			_expect(timeout_results[0].get("score_summary", {}).get("total", -1) == timeout.score, "timeout result includes actual score summary")
			timeout.queue_free()
			checks += 1
	var spam := _new_session("game-006")
	spam._process(0.01)
	for key in [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]: _key(spam, key)
	assert(spam.beat == 1 and not spam.ended)
	while not spam.ended: spam._process(0.01)
	assert(not spam.won and not spam.devil_won and spam.mistakes == 7)
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
		var sequence: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]
		for cycle in 8:
			while rhythm.phase < cycle * 0.82 + 0.02: rhythm._process(0.01)
			if cycle >= 2: _key(rhythm, sequence[cycle])
			else:
				while rhythm.beat <= cycle: rhythm._process(0.01)
		assert(rhythm.won and not rhythm.devil_won and rhythm.mistakes == 2)
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
