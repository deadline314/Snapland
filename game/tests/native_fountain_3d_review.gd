extends "res://game/tests/native_fountain_review.gd"

const FountainView = preload("res://game/minigames/fountain_jump_view.gd")
var _result_session_id := -1
var _result_snapshot: Dictionary = {}
var _pause_state: Dictionary = {}
var _retry_state: Dictionary = {}
var _outfit_before: Dictionary = {}
var _equipment_before: Dictionary = {}
var _review_deadline := 0

func _process(delta: float) -> void:
	if _review_deadline > 0 and Time.get_ticks_msec() >= _review_deadline:
		_review_deadline = 0
		push_error("Native Fountain 3D review exceeded its scaled finite watchdog deadline")
		if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
		get_tree().quit(1)
		return
	super._process(delta)

func _run() -> void:
	_review_deadline = _wall_deadline_ms(90000)
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native Fountain 3D review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Progress autoload is missing")
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

	if not await _launch_fountain(false): return
	var normal_id: int = main.session.get_instance_id()
	_result_session_id = -1
	_result_snapshot.clear()
	main.session.finished.connect(_capture_result_by_id.bind(normal_id), CONNECT_ONE_SHOT)
	_outfit_before = progress.appearance.duplicate(true)
	_equipment_before = progress.equipped.duplicate(true)
	if not await _capture_court_phase(normal_id, "noon", ".review/native-fountain-3d-noon.png"): return
	if not await _capture_court_phase(normal_id, "night", ".review/native-fountain-3d-night.png"): return
	if not main._select_time_phase("noon"):
		await _fail("Main rejected the noon time phase before Fountain timing")
		return
	if not await _check_pause_and_retry(normal_id): return
	if not await _play_two_hits_one_miss(normal_id): return
	if not await _wait_for_result(normal_id, 9000): return
	if int(_result_snapshot.get("score", -1)) != 500 or _result_snapshot.get("grades", []) != ["準確", "完美", "錯過"] or int(_result_snapshot.get("mistakes", -1)) != 1:
		await _fail("Native 3D Fountain two-hit/one-miss result was not 500: %s" % str(_result_snapshot))
		return
	if progress.normal_count() != 0 or progress.devil_count("welcome") != 0:
		await _fail("Incomplete 500-point Fountain run unexpectedly awarded a collection photo")
		return
	if not await _activate_main_button("返回遊園", "return from the 500-point Fountain result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "500-point Fountain result returns to park"): return

	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _launch_fountain(true): return
	var assisted_id: int = main.session.get_instance_id()
	_result_session_id = -1
	_result_snapshot.clear()
	main.session.finished.connect(_capture_result_by_id.bind(assisted_id), CONNECT_ONE_SHOT)
	if not await _capture_court_phase(assisted_id, "night", ".review/native-fountain-3d-assist-reduced-night.png"): return
	var assisted_beat_time: float = main.session._fountain_beat_time(0)
	# +300 ms is outside the assisted ±240 ms accurate band but inside its ±340 ms hit band.
	if not await _wait_for_phase(assisted_id, assisted_beat_time + 0.30): return
	var assisted_before_input := _live_session(assisted_id)
	if assisted_before_input == null:
		await _fail("Assisted Fountain session disappeared before the scheduled Space input")
		return
	var assisted_input_phase := float(assisted_before_input.phase)
	_key(KEY_SPACE)
	if not await _wait_for_attempts(assisted_id, 1): return
	var assisted_session := _live_session(assisted_id)
	if assisted_session == null or assisted_session.fountain_grades != ["踩中"] or assisted_session.score != 100:
		var actual_error_ms := int(assisted_session.fountain_errors_ms[0]) if assisted_session != null and not assisted_session.fountain_errors_ms.is_empty() else -1
		var actual_grade := str(assisted_session.fountain_grades[0]) if assisted_session != null and not assisted_session.fountain_grades.is_empty() else "<none>"
		var actual_score := int(assisted_session.score) if assisted_session != null else -1
		await _fail("Assisted Space input missed its expected ordinary-hit band: phase=%.4f beat=%.4f requested_error_ms=%.1f actual_error_ms=%d grade=%s score=%d" % [assisted_input_phase, assisted_beat_time, (assisted_input_phase - assisted_beat_time) * 1000.0, actual_error_ms, actual_grade, actual_score])
		return
	if not await _wait_for_result(assisted_id, 10000): return
	if int(_result_snapshot.get("score", -1)) != 100 or not bool(_result_snapshot.get("assisted", false)):
		await _fail("Assisted/reduced Fountain result did not preserve its live rules: %s" % str(_result_snapshot))
		return
	if not await _activate_main_button("返回遊園", "return from the assisted Fountain result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "assisted Fountain result returns to park"): return

	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	if not await _launch_fountain(false): return
	var devil_id: int = main.session.get_instance_id()
	_result_session_id = -1
	_result_snapshot.clear()
	main.session.finished.connect(_capture_result_by_id.bind(devil_id), CONNECT_ONE_SHOT)
	if not await _capture_court_phase(devil_id, "noon", ".review/native-fountain-3d-formal-noon.png"): return
	if not await _play_three_perfect_spaces(devil_id): return
	if not await _wait_for_result(devil_id, 9000): return
	if int(_result_snapshot.get("score", -1)) != 900 or _result_snapshot.get("grades", []) != ["完美", "完美", "完美"] or int(_result_snapshot.get("mistakes", -1)) != 0 or bool(_result_snapshot.get("assisted", true)):
		await _fail("Three actual Space presses did not reach the natural 900-point result: %s" % str(_result_snapshot))
		return
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has("photo-welcome-game-3") or not progress.photos.has("photo-welcome-devil-3"):
		await _fail("Three perfect live Space inputs did not persist the expected Fountain photos")
		return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-3d-formal-900.png"):
		await _fail("Could not capture the naturally reached 900-point 3D result")
		return
	print("PASS: Main game-003 3D Fountain, post-handler pause/retry latches, native 500 miss run, assisted/reduced timing, and three-Space 900-point devil result")
	await main._quit_game()

func _capture_court_phase(session_id: int, phase_id: String, path: String) -> bool:
	if not main._select_time_phase(phase_id):
		await _fail("Main rejected Fountain presentation time phase: " + phase_id)
		return false
	await _frames(3)
	var live := _live_session(session_id)
	if live == null or not live.presentation is FountainView:
		await _fail("Game-003 did not attach the Fountain 3D presentation")
		return false
	var view: FountainView = live.presentation as FountainView
	var output: TextureRect = live.presentation.find_child("FountainRenderOutput", true, false) as TextureRect
	var avatar: Sprite3D = view.avatar_sprite()
	if output == null or output.texture == null or view.get_texture() == null or not view.content_bounds().has_area() or not view.avatar_available() or avatar == null or not avatar.visible or avatar.texture == null:
		await _fail("Fountain 3D render output, bounded stage, or full-body equipped avatar is missing")
		return false
	if progress.appearance != _outfit_before or progress.equipped != _equipment_before:
		await _fail("Fountain time-phase capture changed the equipped outfit")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(path):
		await _fail("Could not capture the real Fountain stage: " + path)
		return false
	return true

func _check_pause_and_retry(session_id: int) -> bool:
	if not await _wait_for_phase(session_id, 0.16): return false
	var session := _live_session(session_id)
	if session == null: return false
	var pause_button: BaseButton = session.minigame_hud.find_child("PauseButton", true, false)
	_pause_state.clear()
	pause_button.pressed.connect(_capture_pause_state.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(pause_button, "pause 3D Fountain"): return false
	session = _live_session(session_id)
	if session == null or int(_pause_state.get("session_id", -1)) != session_id or not bool(_pause_state.get("paused", false)):
		await _fail("Real PauseButton.pressed callback did not observe the post-handler Fountain pause")
		return false
	var phase_at_pause := float(_pause_state.get("phase", -1.0))
	var attempts_at_pause := int(_pause_state.get("attempts", -1))
	for _frame in 4: await get_tree().physics_frame
	session = _live_session(session_id)
	if session == null or not session.paused or not is_equal_approx(session.phase, phase_at_pause) or session.fountain_attempts != attempts_at_pause:
		await _fail("Paused Fountain model advanced after the post-pressed state latch")
		return false
	var resume_button: BaseButton = session.minigame_hud.find_child("ResumeButton", true, false)
	if not await _native_click_button(resume_button, "resume 3D Fountain"): return false
	if not await _wait_for_phase_after(session_id, phase_at_pause): return false
	session = _live_session(session_id)
	if session == null or session.paused: return false
	pause_button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "pause before Fountain retry"): return false
	session = _live_session(session_id)
	if session == null: return false
	var retry_button: BaseButton = session.minigame_hud.find_child("RetryButton", true, false)
	if not await _native_click_button(retry_button, "open Fountain retry confirmation"): return false
	session = _live_session(session_id)
	if session == null: return false
	var confirm_button: BaseButton = session.minigame_hud.find_child("ConfirmAction", true, false)
	if confirm_button == null or not confirm_button.is_visible_in_tree():
		await _fail("Fountain retry confirmation button did not appear")
		return false
	_retry_state.clear()
	confirm_button.pressed.connect(_capture_retry_state.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm_button, "confirm 3D Fountain retry"): return false
	session = _live_session(session_id)
	if session == null or int(_retry_state.get("session_id", -1)) != session_id or float(_retry_state.get("phase", -1.0)) != 0.0 or int(_retry_state.get("attempts", -1)) != 0 or int(_retry_state.get("count", -1)) != 0 or int(_retry_state.get("score", -1)) != 0 or not _retry_state.get("grades", [1]).is_empty() or bool(_retry_state.get("paused", true)) or bool(_retry_state.get("ended", true)):
		await _fail("ConfirmAction.pressed did not synchronously observe an exact Fountain reset: " + str(_retry_state))
		return false
	return true

func _capture_pause_state(session_id: int) -> void:
	var session := _live_session(session_id)
	if session == null: return
	_pause_state = {"session_id": session_id, "phase": float(session.phase), "attempts": int(session.fountain_attempts), "paused": bool(session.paused)}

func _capture_retry_state(session_id: int) -> void:
	var session := _live_session(session_id)
	if session == null: return
	_retry_state = {"session_id": session_id, "phase": float(session.phase), "attempts": int(session.fountain_attempts), "count": int(session.count), "score": int(session.score), "grades": session.fountain_grades.duplicate(), "paused": bool(session.paused), "ended": bool(session.ended)}

func _play_two_hits_one_miss(session_id: int) -> bool:
	var session := _live_session(session_id)
	if session == null: return false
	if not await _wait_for_phase(session_id, session.FOUNTAIN_FIRST_BEAT + 0.12): return false
	_key(KEY_SPACE)
	if not await _wait_for_attempts(session_id, 1): return false
	session = _live_session(session_id)
	if session == null or session.fountain_grades != ["準確"] or session.score != 200:
		await _fail("Actual first Space did not produce the expected 200-point accurate grade")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-fountain-3d-accurate-space.png"):
		await _fail("Could not capture Fountain's live accurate Space response")
		return false
	if not await _wait_for_phase(session_id, session._fountain_beat_time(1)): return false
	_key(KEY_SPACE)
	if not await _wait_for_attempts(session_id, 2): return false
	session = _live_session(session_id)
	if session == null or session.fountain_grades != ["準確", "完美"] or session.score != 500:
		await _fail("Actual second Space did not produce the expected 500-point subtotal")
		return false
	return true

func _play_three_perfect_spaces(session_id: int) -> bool:
	for index in 3:
		var session := _live_session(session_id)
		if session == null: return false
		if not await _wait_for_phase(session_id, session._fountain_beat_time(index)): return false
		_key(KEY_SPACE)
		if index < 2:
			if not await _wait_for_attempts(session_id, index + 1): return false
			session = _live_session(session_id)
			if session == null or session.fountain_grades.size() != index + 1 or session.fountain_grades[index] != "完美" or session.score != (index + 1) * 300:
				await _fail("Actual Space press %d missed its perfect timing window" % (index + 1))
				return false
			if index == 0:
				await RenderingServer.frame_post_draw
				if not main._capture(".review/native-fountain-3d-perfect-jump.png"):
					await _fail("Could not capture actual perfect jump frame")
					return false
	return true

func _capture_result_by_id(result: Dictionary, session_id: int) -> void:
	var candidate: Object = instance_from_id(session_id)
	if not candidate is Control or not is_instance_valid(candidate) or (candidate as Control).get_instance_id() != session_id:
		push_error("Fountain native review lost its matching session during finished signal capture")
		get_tree().quit(1)
		return
	var session := candidate as Control
	_result_snapshot = result.duplicate(true)
	_result_snapshot["grades"] = session.fountain_grades.duplicate()
	_result_snapshot["mistakes"] = int(session.mistakes)
	_result_session_id = session_id

func _wait_for_result(session_id: int, timeout_ms: int) -> bool:
	var deadline := _wall_deadline_ms(timeout_ms)
	while _result_session_id != session_id and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if _result_session_id != session_id or _result_snapshot.is_empty():
		await _fail("Fountain did not finish with a latched result for session %d" % session_id)
		return false
	if main.modal_kind != "result":
		await _fail("Matching Fountain finish was latched but Main did not show the result modal")
		return false
	return true

func _wait_for_phase(session_id: int, target: float) -> bool:
	var deadline := _wall_deadline_ms(7000)
	while Time.get_ticks_msec() < deadline:
		var session := _live_session(session_id)
		if session == null: break
		if float(session.phase) >= target: return true
		await get_tree().physics_frame
	await _fail("Fountain phase did not reach %.3f for session %d" % [target, session_id])
	return false

func _wait_for_phase_after(session_id: int, previous: float) -> bool:
	var deadline := _wall_deadline_ms(3000)
	while Time.get_ticks_msec() < deadline:
		var session := _live_session(session_id)
		if session == null: break
		if not session.paused and float(session.phase) > previous: return true
		await get_tree().physics_frame
	await _fail("Fountain model phase did not resume after the actual Resume click")
	return false

func _wait_for_attempts(session_id: int, count: int) -> bool:
	var deadline := _wall_deadline_ms(2000)
	while Time.get_ticks_msec() < deadline:
		var session := _live_session(session_id)
		if session == null: break
		if int(session.fountain_attempts) >= count: return true
		await get_tree().physics_frame
	await _fail("Live Fountain model did not register attempt %d" % count)
	return false

func _live_session(session_id: int) -> Control:
	if not is_instance_id_valid(session_id): return null
	var instance: Object = instance_from_id(session_id)
	if instance is Control and is_instance_valid(instance) and is_instance_valid(main) and main.session == instance:
		return instance as Control
	return null

## Override the inherited helper so launch/HUD polling shares the same bounded budget.
func _wall_deadline_ms(simulated_milliseconds: int) -> int:
	var wall_ms := mini(3600000, ceili(float(simulated_milliseconds) / maxf(Engine.time_scale, 0.05)))
	return Time.get_ticks_msec() + wall_ms
