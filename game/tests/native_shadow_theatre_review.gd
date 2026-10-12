extends "res://game/tests/native_fountain_review.gd"

## Windowed end-to-end review for the game-009 station and its live point-light scene.
## Only native key and pointer events drive a Session; completed values are latched by ID.
const ShadowModel := preload("res://game/minigames/shadow_theatre_model.gd")
const SHADOW_PHOTO := "photo-welcome-game-9"
const SHADOW_DEVIL_PHOTO := "photo-welcome-devil-9"
const REVIEW_FRAME_GUARD := 900

var _finished_id := 0
var _finished_result: Dictionary = {}
var _finished_model: Dictionary = {}
var _finished_summary: Dictionary = {}
var _finished_events: Array = []
var _retry_seen := false
var _retry_state: Dictionary = {}
var _retry_flags: Dictionary = {}
var _retry_instance_id := 0
var _review_deadline := 0

func _process(_delta: float) -> void:
	if _review_deadline > 0 and Time.get_ticks_msec() >= _review_deadline:
		_review_deadline = 0
		push_error("Native Shadow Theatre review exceeded its scaled finite watchdog deadline")
		if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
		get_tree().quit(1)
		return
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	_review_deadline = _wall_deadline_ms(180000)
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native Shadow Theatre review requires a windowed GPU run and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Native Shadow Theatre review could not find the Progress autoload")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	progress.settings["time_phase"] = "noon"
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _launch_shadow(false, false): return
	var formal_id: int = main.session.get_instance_id()
	main.session.finished.connect(_latch_finished.bind(formal_id), CONNECT_ONE_SHOT)
	if not await _exercise_pause_and_confirmed_retry(formal_id, false, false, false): return
	if not await _play_keyboard_route(formal_id): return
	if not await _wait_for_latched_result(formal_id): return
	if not await _validate_formal_result(): return
	var formal_progress := _progress_snapshot()
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-shadow-theatre-formal-result.png"):
		await _fail("Could not capture the actual formal score summary")
		return
	if not await _activate_main_button("返回遊園", "return from the formal game-009 result"):
		return
	if not await _wait_until(func() -> bool: return is_instance_valid(main) and not is_instance_valid(main.session) and main.modal_kind == "", "formal game-009 result returns to the park"):
		return
	if not await _require_live_main("launching the assisted reduced-motion practice"):
		return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	progress.settings["time_phase"] = "night"
	if not await _launch_shadow(true, true): return
	var practice_id: int = main.session.get_instance_id()
	main.session.finished.connect(_latch_finished.bind(practice_id), CONNECT_ONE_SHOT)
	if not await _exercise_pause_and_confirmed_retry(practice_id, true, true, true): return
	if not await _play_pointer_practice_route(practice_id): return
	if not await _wait_for_latched_result(practice_id): return
	if not await _validate_practice_result(formal_progress): return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-shadow-theatre-practice-result.png"):
		await _fail("Could not capture the actual private-practice score summary")
		return
	print("PASS: real game-009 station/menu launch, keyboard lateral/depth and Space captures, pause/resume and confirmed retry reset, formal three-round photo awards, and assisted night practice via pointer lamp plus real mouse shutter with unchanged progress")
	await main._quit_game()

func _launch_shadow(assisted_run: bool, practice_run: bool) -> bool:
	_finished_id = 0
	_finished_result.clear()
	_finished_model.clear()
	_finished_summary.clear()
	_finished_events.clear()
	if not await _require_live_main("finding the game-009 station"):
		return false
	var found := false
	for point in main.world.points:
		if point.id != "game-009": continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		await _fail("Shadow Theatre station game-009 is missing from the live park")
		return false
	var deadline := _wall_deadline_ms(3500)
	while main.world.nearest.get("id", "") != "game-009" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not await _require_live_main("approaching game-009"):
			return false
	if main.world.nearest.get("id", "") != "game-009":
		await _fail("Game-009 did not become the nearest real park interaction")
		return false
	_key(KEY_E)
	deadline = _wall_deadline_ms(2500)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.modal_kind != "game_info":
		await _fail("Native E did not open the shadow station menu")
		return false
	var button_text := "練習操作" if practice_run else "開始遊玩"
	if not await _activate_main_button(button_text, "launch game-009 %s" % ("practice" if practice_run else "formal mode")):
		return false
	deadline = _wall_deadline_ms(2500)
	while not is_instance_valid(main.session) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not is_instance_valid(main.session) or main.session.game_id != "game-009":
		await _fail("The real station menu did not launch a game-009 Session")
		return false
	var session: Control = main.session
	if session.assisted != assisted_run or session.reduced_motion != assisted_run or session.practice_mode != practice_run:
		await _fail("Launched mode flags differ: assist=%s reduced=%s practice=%s" % [session.assisted, session.reduced_motion, session.practice_mode])
		return false
	if not is_instance_valid(session.presentation) or session.presentation.shutter_button() == null:
		await _fail("Live game-009 Session has no actual 3D theatre or mouse shutter control")
		return false
	return true

func _exercise_pause_and_confirmed_retry(session_id: int, expected_assist: bool, expected_reduced: bool, expected_practice: bool) -> bool:
	var session := _session_for_id(session_id)
	if not is_instance_valid(session) or main.session != session:
		await _fail("Session disappeared before pause/retry input")
		return false
	var initial: Dictionary = session.shadow_model.snapshot().duplicate(true)
	_send_key(KEY_RIGHT, true)
	for _frame in 8:
		await get_tree().process_frame
	_send_key(KEY_RIGHT, false)
	if not await _require_live_session_id(session_id, "after real lamp movement"): return false
	var moved: Dictionary = _session_for_id(session_id).shadow_model.snapshot().duplicate(true)
	var focused := session.get_viewport().gui_get_focus_owner()
	print("SHADOW_NATIVE_HELD_RIGHT: id=%d initial_elapsed=%f moved_elapsed=%f initial_lamp=%s moved_lamp=%s paused=%s focused=%s right_held=%s" % [session_id, float(initial.elapsed), float(moved.elapsed), str(initial.lamp_position), str(moved.lamp_position), session.paused, str(focused.get_path()) if is_instance_valid(focused) else "none", session.presentation.get("_right_down")])
	if float(moved.elapsed) <= float(initial.elapsed) or Vector2(moved.lamp_position).x <= Vector2(initial.lamp_position).x:
		await _fail("Actual held right input did not advance the model clock and lamp: initial=%s moved=%s" % [str(initial), str(moved)])
		return false
	if not await _click_session_hud(session_id, "PauseButton", "pause after a real lamp movement"):
		return false
	if not await _require_live_session_id(session_id, "checking paused game-009 scalar freeze"):
		return false
	var paused_snapshot: Dictionary = _pause_scalars(session)
	_send_key(KEY_RIGHT, false)
	await _frames(12)
	if not await _require_live_session_id(session_id, "after paused wait"):
		return false
	if not session.paused or _pause_scalars(session) != paused_snapshot:
		await _fail("Pause did not preserve exact model/timer/progress scalars after the key was released")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-shadow-theatre-paused.png"):
		await _fail("Could not capture the frozen pause state")
		return false
	if not await _click_session_hud(session_id, "ResumeButton", "resume the frozen lamp session"):
		return false
	if not await _require_live_session_id(session_id, "checking real resume control"):
		return false
	if session.paused or _pause_nonclock_scalars(session) != _pause_nonclock_from(paused_snapshot):
		await _fail("Resume changed the lamp, round, score, or capture state rather than resuming it")
		return false
	if not await _click_session_hud(session_id, "PauseButton", "pause before retry"):
		return false
	if not await _click_session_hud(session_id, "RetryButton", "open the session retry confirmation"):
		return false
	if not await _require_live_session_id(session_id, "locating retry confirmation"):
		return false
	var confirm_button := _visible_hud_button(session.minigame_hud, "ConfirmAction")
	if confirm_button == null:
		await _fail("Retry menu did not create its ConfirmAction control")
		return false
	_retry_seen = false
	_retry_state.clear()
	_retry_flags.clear()
	confirm_button.pressed.connect(_latch_retry_reset.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm_button, "confirm actual shadow retry"):
		return false
	if not await _require_live_session_id(session_id, "after confirmed retry"): return false
	if not _retry_seen or _retry_instance_id != session_id:
		await _fail("Confirmed retry did not synchronously report a live same-session reset")
		return false
	var expected_position: Vector2 = ShadowModel.ROUND_SOLUTIONS[0] + ShadowModel.ROUND_START_OFFSETS[0]
	if float(_retry_state.elapsed) != 0.0 or int(_retry_state.round) != 0 or Vector2(_retry_state.lamp_position) != expected_position or int(_retry_state.score) != 0 or int(_retry_state.qualified_count) != 0 or int(_retry_state.perfect_count) != 0 or int(_retry_state.misses) != 0 or bool(_retry_state.finished):
		await _fail("Confirmed retry callback did not observe exact-zero model state: %s" % str(_retry_state))
		return false
	if _retry_flags != {"assist": expected_assist, "reduced": expected_reduced, "practice": expected_practice, "paused": false} or not session.score_events.is_empty() or session.score != 0:
		await _fail("Confirmed retry lost settings or retained awards: flags=%s events=%s" % [str(_retry_flags), str(session.score_events)])
		return false
	return true

func _play_keyboard_route(session_id: int) -> bool:
	for round_index in 3:
		var session := _session_for_id(session_id)
		if not await _require_live_session_id(session_id, "moving to formal round %d" % (round_index + 1)):
			return false
		if int(session.shadow_model.snapshot().round) != round_index:
			await _fail("Formal route expected round %d but the live model is on %s" % [round_index + 1, str(session.shadow_model.snapshot().round)])
			return false
		var target: Vector2 = session.shadow_model.round_solution(round_index)
		if not await _move_keyboard_lamp_to(session_id, target):
			return false
		var live := _session_for_id(session_id)
		var pre_capture: Dictionary = live.shadow_model.snapshot()
		if float(pre_capture.shape_error) > float(pre_capture.perfect_error_limit):
			await _fail("Actual arrow movement did not reach precise round %d projection: error=%f limit=%f" % [round_index + 1, float(pre_capture.shape_error), float(pre_capture.perfect_error_limit)])
			return false
		var old_round := int(pre_capture.round)
		if not await _capture_live_cast(session_id, "formal", round_index): return false
		_key(KEY_SPACE)
		await _frames(2)
		if round_index < 2:
			if not await _require_live_session_id(session_id, "checking Space shutter round %d" % (round_index + 1)):
				return false
			var after: Dictionary = _session_for_id(session_id).shadow_model.snapshot()
			if int(after.round) != old_round + 1 or str(after.ledger[round_index].status) != "perfect":
				await _fail("Space did not capture a real precise keyboard-aligned shadow: %s" % str(after.ledger[round_index]))
				return false
		else:
			if _finished_id != session_id or int(_finished_model.round) != old_round or str(_finished_model.ledger[round_index].status) != "perfect":
				await _fail("Final Space did not synchronously latch the actual third precise shadow")
				return false
	return true

func _move_keyboard_lamp_to(session_id: int, target: Vector2) -> bool:
	var guard := 0
	var deadline := _wall_deadline_ms(30000)
	var frame_limit := ceili(float(REVIEW_FRAME_GUARD) / maxf(Engine.time_scale, 0.05))
	var last_state: Dictionary = {}
	while guard < frame_limit and Time.get_ticks_msec() < deadline:
		if not await _require_live_session_id(session_id, "using arrow keys to align lamp"):
			return false
		var session := _session_for_id(session_id)
		var state: Dictionary = session.shadow_model.snapshot()
		last_state = state.duplicate(true)
		if guard % 60 == 0:
			var focus := session.get_viewport().gui_get_focus_owner()
			print("SHADOW_NATIVE_NAV: iteration=%d round=%d elapsed=%f target=%s lamp=%s shape_error=%f perfect_limit=%f paused=%s focus=%s" % [guard, int(state.round), float(state.elapsed), str(target), str(state.lamp_position), float(state.shape_error), float(state.perfect_error_limit), session.paused, str(focus.get_path()) if is_instance_valid(focus) else "none"])
		if float(state.shape_error) <= float(state.perfect_error_limit):
			return true
		var lamp: Vector2 = state.lamp_position
		var difference := target - lamp
		var key := KEY_RIGHT if difference.x > 0.0 else KEY_LEFT
		if absf(difference.y) > absf(difference.x):
			key = KEY_UP if difference.y > 0.0 else KEY_DOWN
		_send_key(KEY_SHIFT, difference.length() <= 0.08)
		_send_key(key, true)
		# Hold across an actual idle update; physics ticks can precede View._process.
		await get_tree().process_frame
		await get_tree().process_frame
		_send_key(key, false)
		_send_key(KEY_SHIFT, false)
		await get_tree().process_frame
		guard += 1
	await _fail("Keyboard lamp navigation exceeded %d input frames; target=%s last=%s" % [frame_limit, str(target), str(last_state)])
	return false

func _play_pointer_practice_route(session_id: int) -> bool:
	for round_index in 3:
		if not await _require_live_session_id(session_id, "pointer lamp for practice round %d" % (round_index + 1)):
			return false
		var session := _session_for_id(session_id)
		if int(session.shadow_model.snapshot().round) != round_index:
			await _fail("Practice route expected round %d but model advanced unexpectedly" % (round_index + 1))
			return false
		var target: Vector2 = session.shadow_model.round_solution(round_index)
		if not await _native_pointer_lamp(session_id, target):
			return false
		var live := _session_for_id(session_id)
		var before: Dictionary = live.shadow_model.snapshot()
		if Vector2(before.lamp_position).distance_to(target) > 0.00002 or float(before.shape_error) > float(before.perfect_error_limit):
			await _fail("Real pointer click failed to position the lamp on the current target: %s" % str(before))
			return false
		if not await _capture_live_cast(session_id, "practice", round_index): return false
		if not await _require_live_session_id(session_id, "before real practice shutter"): return false
		var shutter: Button = _session_for_id(session_id).presentation.shutter_button()
		if not await _native_click_button(shutter, "click real on-screen shutter for practice round %d" % (round_index + 1)):
			return false
		await _frames(2)
		if round_index < 2:
			if not await _require_live_session_id(session_id, "checking pointer/button shutter"):
				return false
			var after: Dictionary = _session_for_id(session_id).shadow_model.snapshot()
			if int(after.round) != round_index + 1 or str(after.ledger[round_index].status) != "perfect":
				await _fail("Real mouse shutter did not capture the assisted pointer-aligned shadow: %s" % str(after.ledger[round_index]))
				return false
		elif _finished_id != session_id or str(_finished_model.ledger[round_index].status) != "perfect":
			await _fail("Final mouse shutter did not latch the actual assisted practice capture")
			return false
	return true

func _native_pointer_lamp(session_id: int, target: Vector2) -> bool:
	var session := _session_for_id(session_id)
	if not is_instance_valid(session) or not is_instance_valid(session.presentation):
		await _fail("Pointer rail has no live ShadowTheatreView")
		return false
	var design := Vector2(
		160.0 + (target.x - ShadowModel.LAMP_X_MIN) / (ShadowModel.LAMP_X_MAX - ShadowModel.LAMP_X_MIN) * 960.0,
		176.0 + (ShadowModel.LAMP_Z_MAX - target.y) / (ShadowModel.LAMP_Z_MAX - ShadowModel.LAMP_Z_MIN) * 440.0
	)
	var view: Control = session.presentation
	var local := Vector2(design.x * view.size.x / 1280.0, design.y * view.size.y / 720.0)
	var point: Vector2 = view.get_viewport().get_final_transform() * (view.get_global_transform_with_canvas() * local)
	_motion(point)
	_click(point)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	if not await _require_live_session_id(session_id, "after native pointer lamp click"):
		return false
	if Vector2(_session_for_id(session_id).shadow_model.snapshot().lamp_position).distance_to(target) > 0.00002:
		await _fail("Actual pointer lamp did not reach its visible target"); return false
	return true

func _latch_finished(result: Dictionary, session_id: int) -> void:
	var session := _session_for_id(session_id)
	if not is_instance_valid(session):
		push_error("Native Shadow Theatre review: Session was freed before synchronous finish latch")
		get_tree().quit(1)
		return
	if str(result.get("game_id", "")) != "game-009":
		push_error("Matching Shadow Session emitted another game result")
		get_tree().quit(1); return
	_finished_id = session_id
	_finished_result = result.duplicate(true)
	_finished_model = session.shadow_model.snapshot().duplicate(true)
	_finished_summary = session.score_summary().duplicate(true)
	_finished_events = session.score_events.duplicate(true)

func _latch_retry_reset(session_id: int) -> void:
	var session := _session_for_id(session_id)
	if not is_instance_valid(session) or not is_instance_valid(main) or main.session != session:
		return
	_retry_instance_id = session_id
	_retry_state = session.shadow_model.snapshot().duplicate(true)
	_retry_flags = {"assist": session.assisted, "reduced": session.reduced_motion, "practice": session.practice_mode, "paused": session.paused}
	_retry_seen = true

func _validate_formal_result() -> bool:
	if not await _wait_result_modal(): return false
	if _finished_id == 0 or not bool(_finished_result.get("success", false)) or not bool(_finished_result.get("devil", false)) or bool(_finished_result.get("assisted", true)) or bool(_finished_result.get("practice", true)):
		await _fail("Three unassisted precise model captures did not produce the formal ordinary+devil result: %s" % str(_finished_result))
		return false
	if not await _validate_three_capture_ledger(): return false
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has(SHADOW_PHOTO) or not progress.photos.has(SHADOW_DEVIL_PHOTO):
		await _fail("Actual game-009 result did not persist exactly one ordinary and devil collection photo")
		return false
	return true

func _validate_practice_result(formal_progress: Dictionary) -> bool:
	if not await _wait_result_modal(): return false
	if _finished_id == 0 or not bool(_finished_result.get("success", false)) or bool(_finished_result.get("devil", true)) or not bool(_finished_result.get("assisted", false)) or not bool(_finished_result.get("practice", false)):
		await _fail("Assisted practice did not return a qualified no-devil private result: %s" % str(_finished_result))
		return false
	if not await _validate_three_capture_ledger(): return false
	if _progress_snapshot() != formal_progress:
		await _fail("Practice changed photos, achievements, quests, pending achievements, or coins")
		return false
	if not _find_label_text(main.overlay, "練習完成"):
		await _fail("Practice result modal did not identify its no-save route")
		return false
	return true

func _validate_three_capture_ledger() -> bool:
	var ledger: Array = _finished_model.get("ledger", [])
	if ledger.size() != 3 or int(_finished_model.get("qualified_count", -1)) != 3 or int(_finished_model.get("perfect_count", -1)) != 3 or int(_finished_model.get("misses", -1)) != 0:
		await _fail("Three-round result differs from its actual capture ledger: %s" % str(_finished_model))
		return false
	for row in ledger:
		if str(row.get("status", "")) != "perfect" or not bool(row.get("qualified", false)) or not bool(row.get("perfect", false)):
			await _fail("A result row was not judged perfect by the model: %s" % str(row))
			return false
	var summary_rows: Array = _finished_summary.get("rows", [])
	var event_total := 0
	for event in _finished_events:
		event_total += int(event.get("amount", 0))
	if summary_rows.size() != 3 or int(_finished_summary.get("total", -1)) != int(_finished_result.get("score", -2)) or int(_finished_model.get("score", -3)) != int(_finished_result.get("score", -4)) or event_total != int(_finished_result.get("score", -5)):
		await _fail("Three scored captures did not reconcile through result summary, model, and actual award ledger: %s" % str(_finished_summary))
		return false
	for round_index in 3:
		var expected_key := "shadow_round_%d" % (round_index + 1)
		var found := false
		for row in summary_rows:
			if str(row.get("key", "")) == expected_key and int(row.get("amount", -1)) == int(ledger[round_index].get("score", -2)):
				found = true
		if not found:
			await _fail("Score summary is missing the actual model award for round %d" % (round_index + 1))
			return false
	return true

func _wait_for_latched_result(session_id: int) -> bool:
	var deadline := _wall_deadline_ms(12000)
	while Time.get_ticks_msec() < deadline:
		if _finished_id == session_id:
			return await _wait_result_modal()
		if not await _require_live_main("waiting for the actual game-009 result"):
			return false
		await get_tree().physics_frame
	await _fail("The real third shadow capture did not produce a finished result")
	return false

func _wait_result_modal() -> bool:
	var deadline := _wall_deadline_ms(5000)
	while is_instance_valid(main) and main.modal_kind != "result" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not is_instance_valid(main) or main.modal_kind != "result":
		await _fail("Completed game-009 result did not reach Main's result modal")
		return false
	return true

func _click_session_hud(session_id: int, control_name: String, context: String) -> bool:
	if not await _require_live_session_id(session_id, context): return false
	var session := _session_for_id(session_id)
	var button := _visible_hud_button(session.minigame_hud, control_name)
	if not is_instance_valid(button):
		await _fail("Missing session HUD control '%s' for %s" % [control_name, context])
		return false
	if not await _native_click_button(button, context): return false
	return await _require_live_session_id(session_id, "after " + context)

func _require_live_session_id(session_id: int, context: String) -> bool:
	var session := _session_for_id(session_id)
	if is_instance_valid(main) and is_instance_valid(session) and not session.is_queued_for_deletion() and main.session == session:
		return true
	await _fail("Shadow Session disappeared while %s; modal=%s" % [context, str(main.modal_kind) if is_instance_valid(main) else "Main freed"])
	return false

func _session_for_id(session_id: int) -> Control:
	if not is_instance_id_valid(session_id): return null
	return instance_from_id(session_id) as Control

func _pause_scalars(session: Control) -> Dictionary:
	var state: Dictionary = session.shadow_model.snapshot()
	return {"elapsed": float(state.elapsed), "round": int(state.round), "lamp": Vector2(state.lamp_position), "score": int(state.score), "qualified": int(state.qualified_count), "perfect": int(state.perfect_count), "misses": int(state.misses), "ledger": state.ledger.duplicate(true)}

func _pause_nonclock_scalars(session: Control) -> Dictionary:
	var result := _pause_scalars(session)
	result.erase("elapsed")
	return result

func _pause_nonclock_from(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	result.erase("elapsed")
	return result

func _progress_snapshot() -> Dictionary:
	return {
		"photos": progress.photos.duplicate(true),
		"achievements": progress.achievements.duplicate(true),
		"quests": progress.quests.duplicate(true),
		"pending_awards": progress.platform_pending_achievements.duplicate(true),
		"owned_clothes": progress.owned_clothes.duplicate(),
		"wardrobe_rewarded_games": progress.wardrobe_rewarded_games.duplicate(),
		"normal_count": progress.normal_count(),
		"devil_count": progress.devil_count("welcome"),
		"coins": int(progress.coins),
		"equipped": progress.equipped.duplicate(true),
	}

func _require_live_main(context: String) -> bool:
	if is_instance_valid(main) and not main.is_queued_for_deletion() and is_instance_valid(progress):
		return true
	await _fail("Main/Progress disappeared while %s" % context)
	return false

func _find_label_text(node: Node, needle: String) -> bool:
	if not is_instance_valid(node): return false
	if node is Label and (node as Label).text.contains(needle): return true
	for child in node.get_children():
		if _find_label_text(child, needle): return true
	return false

func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.window_id = get_window().get_window_id()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _visible_hud_button(hud: Node, control_name: String) -> BaseButton:
	for candidate in hud.find_children(control_name, "", true, false):
		if candidate is BaseButton and candidate.is_visible_in_tree() and not candidate.disabled:
			return candidate as BaseButton
	return null

func _wall_deadline_ms(simulated_milliseconds: int) -> int:
	var wall_ms := mini(3600000, ceili(float(simulated_milliseconds) / maxf(Engine.time_scale, 0.05)))
	return Time.get_ticks_msec() + wall_ms

func _capture_live_cast(session_id: int, route: String, round_index: int) -> bool:
	if not await _require_live_session_id(session_id, "before actual cast screenshot"): return false
	var session := _session_for_id(session_id)
	var viewport: SubViewport = session.presentation.sub_viewport()
	print("SHADOW_NATIVE_RENDER: route=%s round=%d own_world=%s atlas=%d lamp=%s elapsed=%f" % [route, round_index + 1, viewport.own_world_3d, viewport.positional_shadow_atlas_size, str(session.shadow_model.snapshot().lamp_position), float(session.shadow_model.snapshot().elapsed)])
	if not viewport.own_world_3d or viewport.positional_shadow_atlas_size <= 0:
		await _fail("Live theatre has no isolated positional shadow rendering budget"); return false
	await RenderingServer.frame_post_draw
	if not await _require_live_session_id(session_id, "after actual cast render"): return false
	if not main._capture(".review/native-shadow-theatre-%s-round-%d-cast.png" % [route, round_index + 1]):
		await _fail("Could not capture actual pre-shutter 3D cast for " + route); return false
	return true
