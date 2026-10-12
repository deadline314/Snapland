extends SceneTree

const Session = preload("res://game/minigames/session.gd")
var cases := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Fountain timing tests require isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	_test_timing_bands()
	_test_session_view_output_and_headless_guard()
	_test_three_jump_gate_and_equivalent_input()
	_test_misses_spam_and_slow_frames()
	_test_pause_assist_and_reduced_motion()
	if failures == 0:
		print("PASS: fountain timing checks (%d cases)" % cases)
		quit(0)
	else:
		push_error("Fountain timing checks: %d failures" % failures)
		quit(1)

func _test_timing_bands() -> void:
	for sample in [
		[-0.071, "準確", 200], [-0.070, "完美", 300],
		[0.070, "完美", 300], [0.071, "準確", 200],
		[-0.161, "踩中", 100], [0.160, "準確", 200],
		[0.161, "踩中", 100], [0.220, "踩中", 100]
	]:
		var game := _new(false)
		game._process(game.FOUNTAIN_FIRST_BEAT + float(sample[0]))
		_press_key(game)
		_expect(game.fountain_grades == [sample[1]] and game.score == int(sample[2]), "timing band at %s sec" % sample[0])
		game.queue_free()
	_expect(true, "timing bands complete")

func _test_session_view_output_and_headless_guard() -> void:
	var session := _new(false)
	if DisplayServer.get_name() == "headless":
		_expect(session.presentation_mode == "fountain_timing" and session.presentation == null and session._fountain_output == null, "headless fountain session records its mode without allocating a SubViewport or output TextureRect")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color("#75c5c0"))
	var texture := ImageTexture.create_from_image(image)
	var output: TextureRect = session.call("_attach_fountain_output", session, texture) as TextureRect
	_expect(output != null and output.get_parent() == session and output.texture == texture, "session's production output helper attaches the supplied SubViewport texture to a scaled TextureRect")
	_expect(output != null and output.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and output.stretch_mode == TextureRect.STRETCH_SCALE and output.mouse_filter == Control.MOUSE_FILTER_IGNORE, "render output fills the stage without intercepting timing input")
	session.queue_free()
	cases += 1

func _test_three_jump_gate_and_equivalent_input() -> void:
	for click_input in [false, true]:
		var game := _new(false)
		var results: Array[Dictionary] = []
		game.finished.connect(func(result: Dictionary): results.append(result))
		for index in 3:
			var target: float = game._fountain_beat_time(index) + (0.10 if index == 1 else 0.0)
			game._process(target - game.phase)
			if click_input:
				_press_click(game)
			else:
				_press_key(game)
			if index == 0:
				_press_key(game)
				_expect(game.fountain_attempts == 1, "repeat press cannot spend the following opportunity")
			if index == 2:
				_expect(game.fountain_finish_pending and not game.ended and results.is_empty(), "third jump scores immediately but remains live through animation")
		var until_landing: float = game.fountain_finish_at - game.phase
		game._process(maxf(0.0, until_landing - 0.02))
		_expect(not game.ended and results.is_empty(), "result waits through the landing-settle interval")
		game._process(0.03)
		_expect(results.size() == 1 and results[0].success and not results[0].devil and game.count == 3, "three hits unlock ordinary only")
		_expect(game.score == 800, "three jump scores reflect 300 + 200 + 300")
		game.queue_free()
		cases += 1
	var perfect := _new(false)
	for index in 3:
		perfect._process(perfect._fountain_beat_time(index) - perfect.phase)
		_press_key(perfect)
	_expect(perfect.fountain_finish_pending and not perfect.ended, "perfect third input begins an authored landing before result")
	perfect._process(perfect.FOUNTAIN_JUMP_DURATION)
	_expect(not perfect.ended, "all eight jump-frame intervals play before result")
	perfect._process(perfect.FOUNTAIN_LANDING_SETTLE_SECONDS)
	_expect(perfect.won and perfect.devil_won and perfect.score == 900, "three perfect jumps unlock devil")
	perfect.queue_free()
	cases += 1

func _test_misses_spam_and_slow_frames() -> void:
	var too_early := _new(false)
	too_early._process(too_early.FOUNTAIN_FIRST_BEAT - too_early._fountain_hit_tolerance() - 0.02)
	_press_key(too_early)
	_expect(too_early.fountain_attempts == 0 and too_early.mistakes == 0, "pre-cue input does not burn a jump")
	too_early.queue_free()
	var no_input := _new(false)
	var results: Array[Dictionary] = []
	no_input.finished.connect(func(result: Dictionary): results.append(result))
	no_input._process(4.5)
	_expect(results.size() == 1 and not results[0].success and no_input.fountain_attempts == 3 and no_input.mistakes == 3 and not no_input.fountain_finish_pending, "idle deadlines resolve all three chances once without a nonexistent last jump")
	_expect(no_input.score_events.size() == 3 and no_input.score_events.all(func(row: Dictionary): return int(row.amount) == 0), "misses remain visible zero-point score rows")
	no_input.queue_free()
	cases += 1

func _test_pause_assist_and_reduced_motion() -> void:
	var paused := _new(false)
	paused._process(paused.FOUNTAIN_FIRST_BEAT)
	_press_key(paused)
	var phase_before: float = paused.phase
	paused.set_paused(true)
	paused._process(1.0)
	_expect(is_equal_approx(paused.phase, phase_before) and paused.fountain_attempts == 1, "pause freezes the next fountain deadline")
	paused.set_paused(false)
	paused.queue_free()
	var assisted := _new(true)
	assisted._process(assisted.FOUNTAIN_FIRST_BEAT + 0.30)
	_press_key(assisted)
	_expect(assisted.count == 1 and assisted.fountain_grades == ["踩中"], "assist widens timing without autoplay")
	assisted.queue_free()
	var reduced := _new(false)
	reduced.reduced_motion = true
	for index in 3:
		reduced._process(reduced._fountain_beat_time(index) - reduced.phase)
		_press_key(reduced)
	_expect(reduced.fountain_finish_pending and not reduced.ended, "reduced-motion run still waits for landing")
	reduced._process(reduced.fountain_finish_at - reduced.phase)
	_expect(reduced.won and reduced.devil_won and reduced.score == 900, "reduced motion preserves timing and eligibility")
	reduced.queue_free()
	var settling := _new(false)
	var settle_results: Array[Dictionary] = []
	settling.finished.connect(func(result: Dictionary): settle_results.append(result))
	for index in 3:
		settling._process(settling._fountain_beat_time(index) - settling.phase)
		_press_key(settling)
	var paused_phase: float = settling.phase
	settling.set_paused(true)
	settling._process(1.0)
	_expect(settling.fountain_finish_pending and not settling.ended and settle_results.is_empty() and is_equal_approx(settling.phase, paused_phase), "pause freezes pending result until landing resumes")
	settling.set_paused(false)
	settling._process(0.01)
	var settle_remaining: float = settling.fountain_finish_at - settling.phase
	settling._process(maxf(0.0, settle_remaining - 0.02))
	_expect(not settling.ended and settle_results.is_empty(), "resume does not catch up paused landing time")
	settling._process(0.03)
	settling._process(0.3)
	_expect(settle_results.size() == 1 and settle_results[0].success and settle_results[0].devil and settle_results[0].score == 900, "pending perfect result emits exactly once after the landing")
	settling.queue_free()
	cases += 3

func _new(assist: bool) -> Control:
	var game: Control = Session.new()
	root.add_child(game)
	game.start("game-003", assist)
	return game

func _press_key(game: Control) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	game._unhandled_input(event)

func _press_click(game: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(640, 360)
	game._unhandled_input(event)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Fountain timing check failed: " + message)
		return
	cases += 1
