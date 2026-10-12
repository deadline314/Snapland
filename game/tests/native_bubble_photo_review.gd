extends "res://game/tests/native_fountain_review.gd"

var _earned_result: Dictionary = {}
var _earned_photos: Array = []
var _earned_progress: Dictionary = {}
var _earned_expected_score := -1
var _practice_result: Dictionary = {}
var _practice_photos: Array = []
var _practice_expected_score := -1
var _retry_reset_observed := false
var _earned_finished_id := 0
var _practice_finished_id := 0
var _finish_latch_failed := false

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

## GPU review fixture: actual park/menu input, camera controls, pause, retry and practice.
## The fixture observes the model and never assigns score, photo, or result fields.
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native bubble photo review requires GPU and isolated SNAPLAND_SAVE_PATH")
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
	if not await _require_live_main("starting the game-010 native review"):
		return
	if not await _launch_bubble(false): return
	var ordinary_session: Control = main.session
	ordinary_session.finished.connect(_capture_earned_result.bind(ordinary_session.get_instance_id()), CONNECT_ONE_SHOT)
	if not await _capture_three_photos(ordinary_session, "keyboard"): return
	if not await _wait_bubble_result(): return
	if not await _require_live_main("checking the earned normal result"):
		return
	if int(_earned_result.get("score", -1)) != _earned_expected_score or not bool(_earned_result.get("success", false)) or not bool(_earned_result.get("devil", false)):
		await _fail("Three real full-body clear-pose photographs did not match their ledger-derived ordinary/devil result: result=%s expected_score=%d" % [str(_earned_result), _earned_expected_score])
		return
	if _earned_photos.size() != 3:
		await _fail("Finished signal did not preserve the three real photo records")
		return
	for shot in _earned_photos:
		if not bool(shot.get("captured", false)) or not bool(shot.get("perfect", false)) or float(shot.get("coverage", 0.0)) < 0.999 or int(shot.get("score", -1)) != _score_from_photo(shot):
			await _fail("Photo ledger differs from three actual perfect captures: %s" % str(_earned_photos))
			return
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has("photo-welcome-game-10") or not progress.photos.has("photo-welcome-devil-10") or not progress.achievements.has("ACH_GAME_010"):
		await _fail("The real result did not persist exactly one game-010 ordinary/devil photo and achievement")
		return
	_earned_progress = _capture_progress_state()
	await RenderingServer.frame_post_draw
	if not await _require_live_main("capturing the earned normal result"):
		return
	if not main._capture(".review/native-bubble-photo-earned-result.png"):
		await _fail("Could not capture the naturally earned bubble photo result")
		return
	if not await _activate_main_button("返回遊園", "return from the earned game-010 result"):
		return
	if not await _wait_until(func() -> bool: return is_instance_valid(main) and not is_instance_valid(main.session) and main.modal_kind == "", "earned game-010 result returns to the park"):
		return
	if not await _require_live_main("launching the assisted practice run"):
		return
	progress.settings["reduced_motion"] = true
	progress.settings["time_phase"] = "night"
	if not await _launch_bubble(true): return
	var assisted_session: Control = main.session
	if not assisted_session.assisted or not assisted_session.reduced_motion:
		await _fail("Assisted/reduced-motion fixture settings were not applied to the launched session")
		return
	await RenderingServer.frame_post_draw
	if not await _require_live_session(assisted_session, "capturing assisted reduced-motion state"):
		return
	if not main._capture(".review/native-bubble-photo-assist-reduced-initial.png"):
		await _fail("Could not capture assisted and reduced-motion initial camera state")
		return
	if not await _wait_until(_photo_round_elapsed_at_least.bind(assisted_session.get_instance_id(), 0.30), "assisted photo round advances"):
		return
	if not await _require_live_session(assisted_session, "opening pause menu"):
		return
	if not await _click_session_hud(assisted_session, "PauseButton", "open pause menu for private practice"):
		return
	if not await _require_live_session(assisted_session, "checking the actual pause click"): return
	if not assisted_session.paused:
		await _fail("Pause button did not pause the assisted camera session")
		return
	var paused_elapsed: float = float(assisted_session.bubble_model.snapshot().round_elapsed)
	await _frames(15)
	if not await _require_live_session(assisted_session, "checking paused timing"):
		return
	if float(assisted_session.bubble_model.snapshot().round_elapsed) != paused_elapsed:
		await _fail("Photo timing advanced while the session was paused")
		return
	await RenderingServer.frame_post_draw
	if not await _require_live_session(assisted_session, "capturing paused camera state"):
		return
	if not main._capture(".review/native-bubble-photo-paused.png"):
		await _fail("Could not capture the paused photo camera")
		return
	if not await _click_session_hud(assisted_session, "ResumeButton", "resume after pause"):
		return
	if not await _require_live_session(assisted_session, "checking real resume control"):
		return
	if assisted_session.paused:
		await _fail("Resume button left the camera session paused")
		return
	if not await _click_session_hud(assisted_session, "PauseButton", "pause before retry"):
		return
	if not await _require_live_session(assisted_session, "checking pause before retry"):
		return
	if not assisted_session.paused:
		await _fail("Pause button did not pause the camera before retry")
		return
	if not await _click_session_hud(assisted_session, "RetryButton", "open retry confirmation"):
		return
	if not await _require_live_session(assisted_session, "finding retry confirmation"): return
	var confirm_button := assisted_session.minigame_hud.find_child("ConfirmAction", true, false) as BaseButton
	if confirm_button == null:
		await _fail("Missing retry confirmation action")
		return
	_retry_reset_observed = false
	confirm_button.pressed.connect(_latch_retry_reset.bind(assisted_session.get_instance_id()), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm_button, "confirm the real retry"):
		return
	if not _retry_reset_observed:
		await _fail("ConfirmAction.pressed did not synchronously reset the photo model")
		return
	if not await _require_live_session(assisted_session, "checking confirmed retry"):
		return
	if int(assisted_session.bubble_model.snapshot().round) != 0 or not assisted_session.bubble_model.snapshot().photos.is_empty() or not assisted_session.assisted or not assisted_session.reduced_motion:
		await _fail("Retry did not immediately clear photo progress while preserving assist and reduced-motion settings")
		return
	await RenderingServer.frame_post_draw
	if not await _require_live_session(assisted_session, "capturing confirmed retry state"):
		return
	if not main._capture(".review/native-bubble-photo-retry-reset.png"):
		await _fail("Could not capture the retry reset state")
		return
	if not await _click_session_hud(assisted_session, "PauseButton", "open pause menu for private practice"):
		return
	if not await _click_session_hud(assisted_session, "PracticeButton", "restart as private practice"):
		return
	if not await _require_live_session(assisted_session, "checking private-practice restart"):
		return
	if not assisted_session.practice_mode or not assisted_session.assisted:
		await _fail("Practice restart lost its practice or assistance state")
		return
	var practice_session: Control = assisted_session
	practice_session.finished.connect(_capture_practice_result.bind(practice_session.get_instance_id()), CONNECT_ONE_SHOT)
	if not await _capture_three_photos(practice_session, "pointer"):
		return
	if not await _wait_until(func() -> bool: return is_instance_valid(main) and main.modal_kind == "result", "three actual qualified practice photos finish"):
		return
	if not await _require_live_main("checking private-practice result"):
		return
	if int(_practice_result.get("score", -1)) != _practice_expected_score or not bool(_practice_result.get("success", false)) or not bool(_practice_result.get("devil", false)) or _practice_photos.size() != 3:
		await _fail("Pointer-only practice did not naturally produce three perfect photos and a ledger-matched devil result: result=%s expected_score=%d photos=%s" % [str(_practice_result), _practice_expected_score, str(_practice_photos)])
		return
	for shot in _practice_photos:
		if not bool(shot.get("captured", false)) or not bool(shot.get("perfect", false)) or float(shot.get("coverage", 0.0)) < 0.999 or int(shot.get("score", -1)) != _score_from_photo(shot):
			await _fail("Practice photo ledger differs from three real perfect pointer captures: %s" % str(_practice_photos))
			return
	if _capture_progress_state() != _earned_progress:
		await _fail("Practice photos changed collection, score, mission, achievement, or pending-award state")
		return
	await RenderingServer.frame_post_draw
	if not await _require_live_main("capturing qualified private-practice result"):
		return
	if not main._capture(".review/native-bubble-photo-practice-result.png"):
		await _fail("Could not capture the qualified practice-photo result")
		return
	if not _find_label_text(main.overlay, "練習完成") or not _find_label_text(main.overlay, "練習分數 %d（不保存）" % _practice_expected_score):
		await _fail("Practice result did not show the actual ledger-derived no-award score")
		return
	print("PASS: keyboard-only earned score=%d, pointer-only practice score=%d, three perfect full-coverage photos per run, actual Space/click shutter, time-of-day metadata, real pause/resume/retry and unchanged practice progress" % [_earned_expected_score, _practice_expected_score])
	await main._quit_game()

func _launch_bubble(assisted_run: bool) -> bool:
	if not await _require_live_main("finding game-010 in the park"):
		return false
	var found := false
	for point in main.world.points:
		if point.id != "game-010": continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		await _fail("Bubble photo station game-010 is missing from the real park")
		return false
	var deadline := _wall_deadline_ms(3000)
	while main.world.nearest.get("id", "") != "game-010" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not await _require_live_main("approaching the game-010 station"):
			return false
	if main.world.nearest.get("id", "") != "game-010":
		await _fail("Bubble photo station did not become the nearest interaction")
		return false
	_key(KEY_E)
	deadline = _wall_deadline_ms(2500)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("opening game-010 details"):
			return false
	if main.modal_kind != "game_info":
		await _fail("Native E input did not open bubble photo station details")
		return false
	var start_text := "輔助挑戰" if assisted_run else "開始遊玩"
	if not await _activate_main_button(start_text, "start bubble photo"):
		return false
	deadline = _wall_deadline_ms(2500)
	while is_instance_valid(main) and not is_instance_valid(main.session) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("waiting for the game-010 session"):
			return false
	if not is_instance_valid(main.session) or main.session.game_id != "game-010":
		await _fail("Native Start click did not launch game-010")
		return false
	if main.session.assisted != assisted_run or main.session.reduced_motion != bool(progress.settings.reduced_motion):
		await _fail("Bubble fixture settings mismatch: assist=%s reduced=%s" % [main.session.assisted, main.session.reduced_motion])
		return false
	if not await _require_live_session(main.session, "checking the launched photo renderer"): return false
	if not is_instance_valid(main.session.presentation) or main.session.bubble_model.subject_size != main.session.presentation.measured_subject_size():
		await _fail("Avatar alpha bounds were not synchronized before the first photo step")
		return false
	return true

func _capture_three_photos(session: Control, input_mode: String) -> bool:
	if not await _require_live_session(session, "beginning three real camera exposures"): return false
	var session_id := session.get_instance_id()
	var captured_view: Control = session.presentation
	var screenshots := [".review/native-bubble-photo-initial.png", ".review/native-bubble-photo-exposure.png", ".review/native-bubble-photo-three-prints.png"]
	var expected_running_score := 0
	await RenderingServer.frame_post_draw
	if not await _require_live_session(session, "capturing initial camera composition"):
		return false
	if not main._capture(screenshots[0]):
		await _fail("Could not capture initial whole-body camera composition")
		return false
	for round_index in 3:
		var deadline := _wall_deadline_ms(12000)
		var shot_fired := false
		while not shot_fired and Time.get_ticks_msec() < deadline:
			if not await _require_live_session(session, "aiming photo round %d" % (round_index + 1)): return false
			var state: Dictionary = session.bubble_model.snapshot()
			if str(state.phase) == "aim" and int(state.round) == round_index:
				var target_center: Vector2 = state.target_center
				if input_mode == "pointer":
					_motion(target_center)
					Input.flush_buffered_events()
				else:
					_keyboard_aim_one_step(Vector2(state.frame_center), target_center)
				if float(state.round_elapsed) >= float(session.bubble_model.BEST_POSE_TIMES[round_index]):
					var current: Dictionary = session.bubble_model.snapshot()
					if bool(current.focus_available) and Vector2(current.frame_center).distance_to(Vector2(current.target_center)) <= 16.0:
						if input_mode == "pointer": _click(Vector2(1020.0, 184.0))
						else: _key(KEY_SPACE)
						Input.flush_buffered_events()
						shot_fired = true
					elif float(current.round_elapsed) > float(session.bubble_model.BEST_POSE_TIMES[round_index]) + 0.75:
						await _fail("Camera framing did not converge before clear pose; round=%d state=%s" % [round_index, str(current)])
						return false
			await get_tree().physics_frame
			if not await _require_live_session(session, "observing the real shutter/exposure transition"): return false
		if not shot_fired:
			await _fail("Timed out waiting for real shutter input on photo %d" % (round_index + 1))
			return false
		var photo_state: Dictionary = session.bubble_model.snapshot()
		if str(photo_state.phase) != "exposure" or int(photo_state.photos.size()) != round_index + 1:
			await _fail("Real shutter did not begin the expected exposure: %s" % str(photo_state))
			return false
		var captured_score: int = int(photo_state.score)
		var captured_record: Dictionary = photo_state.photos[round_index].duplicate(true)
		expected_running_score += _score_from_photo(captured_record)
		if round_index == 0:
			if not is_instance_valid(captured_view):
				await _fail("The live camera view disappeared before the exposure hold")
				return false
			var frozen_pose: int = captured_view.pose_frame_for(photo_state)
			var exposure_started := Time.get_ticks_msec()
			while is_instance_valid(main) and is_instance_valid(session) and not session.is_queued_for_deletion() and main.session == session and str(session.bubble_model.snapshot().phase) == "exposure" and float(Time.get_ticks_msec() - exposure_started) * Engine.time_scale < 300.0:
				await get_tree().physics_frame
				if not await _require_live_session(session, "checking the exposure hold"):
					return false
			if not await _require_live_session(session, "capturing the frozen exposure"):
				return false
			var exposure_state: Dictionary = session.bubble_model.snapshot()
			if not is_instance_valid(captured_view) or captured_view.pose_frame_for(exposure_state) != frozen_pose:
				await _fail("Character pose changed while the photo was developing")
				return false
			await RenderingServer.frame_post_draw
			if not await _require_live_session(session, "capturing the exposure screenshot"):
				return false
			if not main._capture(screenshots[1]):
				await _fail("Could not capture the frozen whole-body exposure")
				return false
		if round_index == 2:
			await RenderingServer.frame_post_draw
			if not await _require_live_session(session, "capturing the three-photo row"):
				return false
			if not main._capture(screenshots[2]):
				await _fail("Could not capture all three live photo prints")
				return false
		if not await _wait_photo_exposure(session_id, round_index):
			return false
		if captured_score != expected_running_score or int(captured_record.score) != _score_from_photo(captured_record) or not bool(captured_record.perfect) or float(captured_record.coverage) < 0.999 or str(captured_record.time_of_day) != str(progress.settings.get("time_phase", "noon")):
			await _fail("Actual portrait score differs from full-body centered timing: total=%d record=%s" % [captured_score, str(captured_record)])
			return false
	return true

func _capture_earned_result(result: Dictionary, session_id: int) -> void:
	# Main's earlier finished listener removes/queues the Session. The signal is
	# synchronous, so its model is still valid here even though it is no longer live.
	var completed_session := _photo_session_for_id(session_id)
	if not is_instance_valid(completed_session):
		_reject_finish_latch("Earned Session was freed before its synchronous result capture")
		return
	_earned_result = result.duplicate(true)
	_earned_photos = completed_session.bubble_model.snapshot().photos.duplicate(true)
	_earned_expected_score = _score_from_photos(_earned_photos)
	_earned_finished_id = session_id

func _capture_practice_result(result: Dictionary, session_id: int) -> void:
	var completed_session := _photo_session_for_id(session_id)
	if not is_instance_valid(completed_session):
		_reject_finish_latch("Practice Session was freed before its synchronous result capture")
		return
	_practice_result = result.duplicate(true)
	_practice_photos = completed_session.bubble_model.snapshot().photos.duplicate(true)
	_practice_expected_score = _score_from_photos(_practice_photos)
	_practice_finished_id = session_id

func _reject_finish_latch(message: String) -> void:
	_finish_latch_failed = true
	push_error("Native Photo review: " + message)
	get_tree().quit(1)

func _photo_session_for_id(session_id: int) -> Control:
	if not is_instance_id_valid(session_id): return null
	return instance_from_id(session_id) as Control

func _photo_round_elapsed_at_least(session_id: int, target_elapsed: float) -> bool:
	var live := _photo_session_for_id(session_id)
	return is_instance_valid(main) and is_instance_valid(live) and not live.is_queued_for_deletion() and main.session == live and float(live.bubble_model.snapshot().round_elapsed) >= target_elapsed

func _latched_photo_result(session_id: int) -> Dictionary:
	if _earned_finished_id == session_id: return _earned_result
	if _practice_finished_id == session_id: return _practice_result
	return {}

func _wait_photo_exposure(session_id: int, round_index: int) -> bool:
	# Never capture a Node in a deferred predicate: Godot rejects freed lambda
	# captures before the body's own validity checks can run.
	var deadline := _wall_deadline_ms(8000)
	while Time.get_ticks_msec() < deadline:
		if not await _require_live_main("waiting for photo %d exposure" % (round_index + 1)): return false
		if _finish_latch_failed: return false
		var latched := _latched_photo_result(session_id)
		if not latched.is_empty():
			if round_index != 2:
				await _fail("Photo Session finished before all three actual exposures")
				return false
			return true
		var live := _photo_session_for_id(session_id)
		if not is_instance_valid(live) or live.is_queued_for_deletion() or main.session != live:
			await _fail("Photo %d Session disappeared without its actual finished/result latch" % (round_index + 1))
			return false
		if round_index < 2 and str(live.bubble_model.snapshot().phase) != "exposure":
			return true
		# The third exposure requires the real finished signal, even if a live
		# model has already transitioned away from exposure in the same frame.
		await get_tree().physics_frame
		if not await _require_live_main("resuming photo exposure wait"): return false
	await _fail("Timed out waiting for real photo %d exposure completion" % (round_index + 1))
	return false

func _score_from_photo(photo: Dictionary) -> int:
	return int(roundi(float(photo.get("coverage", 0.0)) * 60.0 + float(photo.get("centering", 0.0)) * 30.0 + float(photo.get("timing_quality", 0.0)) * 10.0))

func _score_from_photos(photos: Array) -> int:
	var result := 0
	for photo_variant in photos:
		if photo_variant is Dictionary:
			result += _score_from_photo(photo_variant as Dictionary)
	return result

func _keyboard_aim_one_step(center: Vector2, target: Vector2) -> void:
	var best_key := KEY_NONE
	var best_error := center.distance_squared_to(target)
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var keys: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	for index in directions.size():
		var candidate := center + directions[index] * 14.0
		var error := candidate.distance_squared_to(target)
		if error + 0.001 < best_error:
			best_error = error
			best_key = keys[index]
	if best_key != KEY_NONE:
		_key(best_key)
		Input.flush_buffered_events()

func _latch_retry_reset(session_id: int) -> void:
	var completed_session := _photo_session_for_id(session_id)
	if not is_instance_valid(completed_session) or not is_instance_valid(main) or main.session != completed_session:
		return
	var state: Dictionary = completed_session.bubble_model.snapshot()
	_retry_reset_observed = int(state.round) == 0 and float(state.round_elapsed) == 0.0 and state.photos.is_empty() and completed_session.assisted and completed_session.reduced_motion and not completed_session.practice_mode and not completed_session.paused

func _capture_progress_state() -> Dictionary:
	return {
		"photos": progress.photos.duplicate(true),
		"achievements": progress.achievements.duplicate(true),
		"quests": progress.quests.duplicate(true),
		"coins": progress.coins,
		"normal_count": progress.normal_count(),
		"devil_count": progress.devil_count("welcome"),
		"owned_clothes": progress.owned_clothes.duplicate(),
		"wardrobe_rewarded_games": progress.wardrobe_rewarded_games.duplicate(),
		"pending_achievements": progress.platform_pending_achievements.duplicate(),
	}

func _wait_bubble_result() -> bool:
	var deadline := _wall_deadline_ms(90000)
	while _earned_result.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not await _require_live_main("waiting for the actual photo result"):
			return false
	if _earned_result.is_empty():
		await _fail("Timed out waiting for the actual final exposure and result; modal=%s session=%s" % [str(main.modal_kind), "live" if main.session != null else "none"])
		return false
	return await _wait_until(func() -> bool: return is_instance_valid(main) and main.modal_kind == "result", "game-010 result modal")

func _click_session_hud(session: Control, control_name: String, context: String) -> bool:
	await _frames(3)
	if not await _require_live_session(session, context):
		return false
	var button := session.minigame_hud.find_child(control_name, true, false) as BaseButton
	if not is_instance_valid(button):
		await _fail("Missing session HUD button '%s' to %s" % [control_name, context])
		return false
	if not await _native_click_button(button, context): return false
	return await _require_live_session(session, "after " + context)

func _require_live_session(session: Control, context: String) -> bool:
	if is_instance_valid(main) and is_instance_valid(session) and not session.is_queued_for_deletion() and main.session == session:
		return true
	await _fail("Photo session ended while %s; modal=%s" % [context, str(main.modal_kind) if is_instance_valid(main) else "main-freed"])
	return false

func _require_live_main(context: String) -> bool:
	if is_instance_valid(main) and not main.is_queued_for_deletion() and is_instance_valid(progress):
		return true
	await _fail("Main/Progress disappeared while %s" % context)
	return false

func _find_label_text(node: Node, needle: String) -> bool:
	if not is_instance_valid(node): return false
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _find_label_text(child, needle):
			return true
	return false

func _wait_until(predicate: Callable, context: String = "actual phase/state transition") -> bool:
	var deadline := _wall_deadline_ms(8000)
	while Time.get_ticks_msec() < deadline:
		if not await _require_live_main(context): return false
		if _finish_latch_failed: return false
		if bool(predicate.call()): return true
		await get_tree().physics_frame
		if not await _require_live_main("after waiting for " + context): return false
	if not await _require_live_main("final check for " + context): return false
	if bool(predicate.call()): return true
	await _fail("Native Photo review timed out waiting for " + context)
	return false

func _fail(message: String) -> void:
	push_error("Native Photo review: " + message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)

func _activate_main_button(needle: String, context: String) -> bool:
	# Newly opened modal controls need layout frames before their hit rectangles
	# are stable for native pointer input.
	await _frames(3)
	if not await _require_live_main(context): return false
	var button: Button = _find(main.overlay, needle)
	if button == null:
		await _fail("Native review could not find button '%s' to %s" % [needle, context])
		return false
	if not await _scroll_control_into_view(button, "button '%s' while trying to %s" % [needle, context]):
		return false
	if not is_instance_valid(button):
		await _fail("Main action button was released during native scroll/layout: " + context)
		return false
	if not await _native_click_button(button, context): return false
	return await _require_live_main("after main action " + context)

func _scroll_control_into_view(control: Control, context: String) -> bool:
	if not is_instance_valid(control):
		await _fail("Photo scroll target is missing: " + context)
		return false
	if not await _require_live_main(context): return false
	var scrolls: Array[ScrollContainer]=[]
	var ancestor := control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: scrolls.append(ancestor as ScrollContainer)
		ancestor=ancestor.get_parent()
	for scroll in scrolls:
		scroll.ensure_control_visible(control)
	await _frames(3)
	if not await _require_live_main(context): return false
	if not is_instance_valid(control):
		await _fail("Scroll target was released during layout: " + context)
		return false
	var viewport_rect := main.get_viewport().get_visible_rect()
	for scroll in scrolls:
		if not is_instance_valid(scroll):
			await _fail("Scroll container was released during layout: " + context)
			return false
		var visible_rect := scroll.get_global_rect().intersection(viewport_rect)
		if not visible_rect.encloses(control.get_global_rect()):
			await _fail("Scroll reveal did not expose %s; control=%s scroll=%s" % [context,str(control.get_global_rect()),str(visible_rect)])
			return false
	if not viewport_rect.encloses(control.get_global_rect()):
		await _fail("Revealed control remains outside viewport: "+context)
		return false
	return true

func _native_click_button(button: BaseButton, context: String) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		await _fail("Native click target is missing, hidden or disabled: " + context)
		return false
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await get_tree().process_frame
	if not is_instance_valid(button) or not is_instance_valid(main):
		await _fail("Photo native click target was released during layout: " + context)
		return false
	await get_tree().process_frame
	if not is_instance_valid(button) or not is_instance_valid(main):
		await _fail("Photo native click target was released during layout: " + context)
		return false
	var viewport := button.get_viewport()
	var rect := button.get_global_rect()
	var visible_rect := viewport.get_visible_rect()
	ancestor = button.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible_rect = visible_rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	if not visible_rect.encloses(rect):
		await _fail("Native click target is clipped: %s rect=%s visible=%s" % [context, rect, visible_rect])
		return false
	var observation := {"down": 0, "up": 0, "pressed": 0, "gui": []}
	var on_down := func(): observation.down += 1
	var on_up := func(): observation.up += 1
	var on_pressed := func(): observation.pressed += 1
	var on_gui := func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			observation.gui.append("down" if event.pressed else "up")
	button.button_down.connect(on_down)
	button.button_up.connect(on_up)
	button.pressed.connect(on_pressed)
	button.gui_input.connect(on_gui)
	var target_path := str(button.get_path())
	var point := viewport.get_final_transform() * rect.get_center()
	# Flush queued OS/fixture events before beginning this click. No input state,
	# control signal or gameplay callback is assigned or invoked directly.
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	motion.button_mask = Input.get_mouse_button_mask()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var hovered := viewport.gui_get_hovered_control()
	var diagnostics := "target=%s rect=%s pointer=%s hovered=%s button_hovered=%s initial_mask=%d" % [target_path, rect, point, str(hovered.get_path()) if is_instance_valid(hovered) else "none", button.is_hovered(), Input.get_mouse_button_mask()]
	if not button.is_hovered() or not (hovered == button or is_instance_valid(hovered) and button.is_ancestor_of(hovered)):
		for pair in [[button.button_down, on_down], [button.button_up, on_up], [button.pressed, on_pressed], [button.gui_input, on_gui]]:
			pair[0].disconnect(pair[1])
		await _fail("Native pointer did not hover its target: %s; %s" % [context, diagnostics])
		return false
	# Dispatch and flush each distinct event without yielding to unrelated OS
	# motion or deferred focus changes between the observed down and release.
	for is_down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if is_down else 0
		event.pressed = is_down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	if is_instance_valid(button):
		for pair in [[button.button_down, on_down], [button.button_up, on_up], [button.pressed, on_pressed], [button.gui_input, on_gui]]:
			pair[0].disconnect(pair[1])
	diagnostics += " observed=%s final_mask=%d" % [observation, Input.get_mouse_button_mask()]
	if observation.down != 1 or observation.pressed != 1:
		await _fail("Native click did not activate its target: %s; %s" % [context, diagnostics])
		return false
	print("INPUT: ", context, " ", diagnostics)
	await get_tree().process_frame
	if not await _require_live_main("after native click " + context): return false
	await get_tree().process_frame
	if not await _require_live_main("after native click " + context): return false
	return true
