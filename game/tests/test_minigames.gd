extends SceneTree

const Session = preload("res://game/minigames/session.gd")
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Minigame tests require isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	await _test_native_input_routing()
	_test_photo_and_rhythm_grades()
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
	_test_vertical_input_and_hat_consumption()
	_test_flower_pipe_route()
	_test_escape_cancels()
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
	missed.queue_free()

	var flown := _new_session("game-002", true)
	var flown_results: Array[Dictionary] = []
	flown.finished.connect(func(value: Dictionary): flown_results.append(value))
	for i in 5:
		while flown.p.x < flown.ring_x[i] - 14.0: flown._process(0.05)
		_mouse_move(flown, 640, flown.ring_y[i])
		flown._process(0.15)
	while not flown.ended: flown._process(0.05)
	assert(flown_results.size() == 1 and flown_results[0].success and flown_results[0].devil)
	flown.queue_free()
	checks += 1

func _test_crowd_boundaries() -> void:
	var wrong := _new_session("game-004", false)
	var wrong_results: Array[Dictionary] = []
	wrong.finished.connect(func(value: Dictionary): wrong_results.append(value))
	while wrong.count == 0: wrong._process(0.01)
	for i in 5:
		while fposmod(wrong.phase, 2.2) < 2.10: wrong._process(0.01)
		_key(wrong, KEY_Q)
		while wrong.count < i + 2: wrong._process(0.01)
	wrong._process(0.01)
	assert(wrong_results.size() == 1 and wrong_results[0].success and wrong_results[0].devil)
	wrong.queue_free()

	var assisted := _new_session("game-004", true)
	var assisted_results: Array[Dictionary] = []
	assisted.finished.connect(func(value: Dictionary): assisted_results.append(value))
	for i in 7: assisted._process(2.2)
	assert(assisted_results.size() == 1 and assisted_results[0].success and assisted_results[0].devil and assisted_results[0].assisted)
	assisted.queue_free()

	var missed := _new_session("game-004", false)
	var missed_results: Array[Dictionary] = []
	missed.finished.connect(func(value: Dictionary): missed_results.append(value))
	while not missed.ended: missed._process(0.05)
	assert(missed_results.size() == 1 and not missed_results[0].success)
	missed.queue_free()
	checks += 1

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
	var s := _new_session("game-010", true)
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	var failed := _new_session("game-010", true)
	_click(failed, 790, 380) # Outside timing: aiming does not take a photo.
	_click(failed, 790, 380)
	assert(failed.beat == 0 and failed.mistakes == 1)
	failed.queue_free()
	# The live bubble envelope uses the same normal/assist tolerance as the aim判定.
	for assist_edge in [false, true]:
		var aim_limit := 180.0 if assist_edge else 130.0
		var inside := _new_session("game-010", assist_edge)
		inside.phase = 1.6
		inside._process(0.01)
		assert(inside.beat_window)
		_click(inside, 790.0 + aim_limit - 1.0, inside.target.y)
		assert(inside.bubble_ready and inside._bubble_display_radius() >= aim_limit - 1.0 + inside.BUBBLE_MASCOT_RADIUS)
		_click(inside, 790, inside.target.y)
		assert(inside.beat == 1 and inside.mistakes == 0)
		inside.queue_free()

		var outside := _new_session("game-010", assist_edge)
		outside.phase = 1.6
		outside._process(0.01)
		_click(outside, 790.0 + aim_limit + 1.0, outside.target.y)
		_click(outside, 790, outside.target.y)
		assert(outside.beat == 0 and outside.mistakes == 1)
		outside.queue_free()
	for shot in 3:
		while s.phase < shot * 2.0 + 1.65: s._process(0.01)
		_click(s, 790, s.target.y)
		s._process(0.01)
		_click(s, 790, s.target.y)
		if shot < 2:
			_click(s, 790, s.target.y)
			_click(s, 790, s.target.y)
			assert(s.beat == shot + 1)
	assert(results.size() == 1 and results[0].success and results[0].devil and results[0].assisted)
	s.queue_free()
	checks += 1

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
	var s := _new_session("game-003")
	var results: Array[Dictionary] = []
	s.finished.connect(func(value: Dictionary): results.append(value))
	_key(s, KEY_SPACE) # Miss the first cycle deliberately.
	assert(s.mistakes == 1 and s.count == 0)
	for cycle in 2:
		s._process(2.35 if cycle == 0 else 1.35)
		_key(s, KEY_SPACE)
		assert(s.count == cycle + 1)
		_key(s, KEY_SPACE)
		assert(s.count == cycle + 1)
	assert(results.size() == 1)
	assert(results[0].success and not results[0].devil)
	s.queue_free()

	var perfect := _new_session("game-003", true)
	var perfect_results: Array[Dictionary] = []
	perfect.finished.connect(func(value: Dictionary): perfect_results.append(value))
	for cycle in 3:
		perfect._process(1.0 if cycle == 0 else 1.35)
		_key(perfect, KEY_SPACE)
		_key(perfect, KEY_SPACE)
	assert(perfect_results.size() == 1)
	assert(perfect_results[0].success and perfect_results[0].devil and perfect_results[0].assisted)
	checks += 1

func _test_vertical_input_and_hat_consumption() -> void:
	var kite := _new_session("game-002")
	var start_y: float = kite.p.y
	Input.action_press("ui_up")
	kite._process(0.1)
	Input.action_release("ui_up")
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
	for point in [[426.0,237.0], [426.0,322.0], [696.0,322.0]]:
		_click(s, point[0], point[1])
	assert(results.is_empty())
	_click(s, 831, 492)
	assert(results.size() == 1)
	assert(results[0].success and results[0].devil)
	assert(s.move_count == 4)
	checks += 1

func _test_escape_cancels() -> void:
	var s := _new_session("game-002")
	var cancelled_count := [0]
	var finished_count := [0]
	s.cancelled.connect(func(): cancelled_count[0] += 1)
	s.finished.connect(func(_result: Dictionary): finished_count[0] += 1)
	_key(s, KEY_ESCAPE)
	assert(s.get_viewport().is_input_handled())
	assert(cancelled_count[0] == 1 and finished_count[0] == 0)
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




func _test_all_modes() -> void:
	for assisted in [false, true]:
		for number in range(1, 13):
			var s := _new_session("game-%03d" % number, assisted)
			var results: Array[Dictionary] = []
			s.finished.connect(func(value: Dictionary): results.append(value))
			var rhythm: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]
			var last_cycle := -1
			var waypoint := 0
			while not s.ended:
				match number:
					1:
						var points := [Vector2(570, 530), Vector2(875, 530), Vector2(1060, 345)]
						_mouse_move(s, points[waypoint].x, points[waypoint].y)
						if waypoint < 2 and s.p.distance_to(points[waypoint]) < 20: waypoint += 1
					2:
						if s.count < 5: _mouse_move(s, 640, s.ring_y[s.count])
					3:
						if s.beat_window: _key(s, KEY_SPACE)
					4:
						if s.lane != s.count % 2: _key(s, KEY_Q)
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
						for point in [[426,237], [426,322], [696,322], [831,492]]: _click(s, point[0], point[1])
					8:
						Input.action_release("ui_right"); Input.action_release("ui_left")
						var expected: float = s.balance + sin((s.phase + 0.01) * 1.7) * (0.32 if assisted else 0.50) * 0.01
						Input.action_press("ui_right" if expected > 0 else "ui_left")
					9: _mouse_move(s, 802 if assisted else 640, 420)
					10:
						var cycle := int(floor(s.phase / 2.0))
						if fposmod(s.phase, 2.0) >= 1.65 and last_cycle != cycle:
							_click(s, 790, s.target.y); _click(s, 790, s.target.y)
							last_cycle = cycle
					11:
						for pair in [[425,560], [560,830], [695,830]]:
							_click(s, pair[0], 340); _click(s, pair[1], 340)
					12:
						if not s.sequence_showing:
							for note in s.sequence.duplicate(): _key(s, KEY_1 + note)
				if not s.ended: s._process(0.01)
			Input.action_release("ui_right"); Input.action_release("ui_left")
			assert(results.size() == 1 and results[0].success and results[0].devil, "Reachability game-%03d assist=%s" % [number, assisted])
			s.queue_free()
			var timeout := _new_session("game-%03d" % number, assisted)
			var timeout_results: Array[Dictionary] = []
			timeout.finished.connect(func(value: Dictionary): timeout_results.append(value))
			timeout._process(60.0)
			assert(timeout_results.size() == 1 and not timeout_results[0].success and not timeout_results[0].devil)
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
	for assisted in [false, true]:
		var photo := _new_session("game-010", assisted)
		for cycle in 3:
			while photo.phase < cycle * 2.0 + 1.4: photo._process(0.01)
			# Broad timing and off-center framing earn ordinary, never devil.
			_click(photo, 790, photo.target.y)
			_click(photo, 855, photo.target.y)
			var photos: int = photo.beat
			for i in 6: _click(photo, 790, photo.target.y)
			assert(photo.beat == photos)
		assert(photo.won and not photo.devil_won and photo.beat == 3)
		photo.queue_free()
		var two := _new_session("game-010", assisted)
		_click(two, 790, 380); _click(two, 790, 380)
		for cycle in [1, 2]:
			while two.phase < cycle * 2.0 + 1.65: two._process(0.01)
			_click(two, 790, two.target.y); _click(two, 790, two.target.y)
		assert(two.won and not two.devil_won and two.beat == 2 and two.mistakes == 1)
		two.queue_free()
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
	var click := InputEventMouseButton.new()
	click.position = Vector2(790, 380)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	Input.flush_buffered_events()
	await process_frame
	assert(bubble.bubble_ready and bubble.bubble_aim == Vector2(790, 380))
	click = InputEventMouseButton.new()
	click.position = Vector2(790, 380)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	root.push_input(click, true)
	Input.flush_buffered_events()
	bubble.queue_free()
	await process_frame
	checks += 1
