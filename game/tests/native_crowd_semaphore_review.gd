extends "res://game/tests/native_review.gd"

const CROWD_GAME_ID := "game-004"
var _active_id := -1
var _pointer_lanes: Array[int] = []
var _latched_result_id := -1
var _latched_result: Dictionary = {}
var _pause_latch: Dictionary = {}
var _retry_latch: Dictionary = {}
var _watchdog_deadline := 0

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
	if _watchdog_deadline > 0 and Time.get_ticks_msec() >= _watchdog_deadline:
		_watchdog_deadline = 0
		push_error("Native crowd semaphore review exceeded its finite watchdog deadline")
		if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
		get_tree().quit(1)

func _native_preflight(label: String) -> bool:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error(label + " requires a native renderer and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return false
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return false
	return true

func _run() -> void:
	_watchdog_deadline = Time.get_ticks_msec() + 150000
	if not _native_preflight("Crowd semaphore review"):
		return
	if _safe_capture_slug("private-assisted/reduced practice-first crossing") != "private-assisted-reduced-practice-first-crossing":
		await _fail("Native screenshot slug sanitizer does not keep a slash out of output filenames")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		push_error("Could not instantiate Main for the real game-004 station route")
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout

	var progress_before_formal := _progress_snapshot()
	if not await _launch_crowd(false): return
	var formal_id := _active_id
	_pointer_lanes.clear()
	var formal_view := _live_session(formal_id).presentation as CrowdSemaphoreView
	formal_view.signal_requested.connect(func(lane: int): _pointer_lanes.append(lane))
	await _shot("formal-opening")
	if not await _wait_for_elapsed(formal_id, 0.80, 8.0): return
	_click(Vector2(760.0, 235.0))
	Input.flush_buffered_events()
	await get_tree().create_timer(0.12).timeout
	var pointer_session := _live_session(formal_id)
	if _pointer_lanes != [1] or pointer_session == null or pointer_session.crowd_model.desired_lane != 1:
		var detail := "signal_lanes=%s desired=%d phase=%s screen_mouse=%s view_rect=%s scale=%s lane_rect=%s" % [str(_pointer_lanes), int(pointer_session.crowd_model.desired_lane) if pointer_session != null else -99, str(pointer_session.crowd_model.phase) if pointer_session != null else "<freed>", str(get_viewport().get_mouse_position()), str(formal_view.get_global_rect()), str(formal_view.scale), str(formal_view.signal_card_rect(1))]
		await _fail("Actual native pointer click did not emit exactly the vertical semaphore request: " + detail)
		return
	await _shot("formal-vertical-pointer")
	_key(KEY_Q)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.12).timeout
	pointer_session = _live_session(formal_id)
	if pointer_session == null or pointer_session.crowd_model.desired_lane != 0 or pointer_session.crowd_model.phase != "walk":
		await _fail("Actual Q key did not change the live model to horizontal walk; desired=%s phase=%s" % [str(pointer_session.crowd_model.desired_lane if pointer_session != null else -99), str(pointer_session.crowd_model.phase if pointer_session != null else "<freed>")])
		return
	await _shot("formal-horizontal-key")
	if not await _pause_and_retry(formal_id, false): return
	if not await _drive_to_finish(formal_id, "formal"): return
	if _latched_result_id != formal_id or not bool(_latched_result.get("success", false)) or bool(_latched_result.get("practice", true)) or bool(_latched_result.get("assisted", true)) or int(_latched_result.get("safe_count", -1)) != 6:
		await _fail("Formal session did not naturally complete all six model groups: " + str(_latched_result))
		return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result", "formal Crowd result screen"): return
	if progress.normal_count() != 1 or not progress.photos.has("photo-welcome-game-4"):
		await _fail("Formal six-group result did not persist its actual normal photo award")
		return
	if _progress_snapshot() == progress_before_formal:
		await _fail("Formal success did not change the expected persistent award state")
		return
	await _shot("formal-result-award")
	if not await _activate_main_button("返回遊園", "return after formal Crowd award"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "formal result returns to the park"): return
	await get_tree().process_frame
	if is_instance_id_valid(formal_id):
		await _fail("Main did not free the completed formal Crowd session")
		return

	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	var progress_before_practice := _progress_snapshot()
	if not await _launch_crowd(true): return
	var practice_id := _active_id
	var practice_live := _live_session(practice_id)
	if practice_live == null or not practice_live.practice_mode or not practice_live.assisted or not practice_live.reduced_motion:
		await _fail("Private Crowd session did not apply both assist and reduced-motion settings")
		return
	_pointer_lanes.clear()
	var practice_view := practice_live.presentation as CrowdSemaphoreView
	practice_view.signal_requested.connect(func(lane: int): _pointer_lanes.append(lane))
	await _shot("practice-assisted-reduced-opening")
	if not await _wait_for_elapsed(practice_id, 0.80, 8.0): return
	_click(Vector2(760.0, 235.0))
	Input.flush_buffered_events()
	await get_tree().create_timer(0.12).timeout
	practice_live = _live_session(practice_id)
	if _pointer_lanes != [1] or practice_live == null or practice_live.crowd_model.desired_lane != 1:
		await _fail("Private practice pointer event did not reach its real vertical input path; lanes=%s desired=%s" % [str(_pointer_lanes), str(practice_live.crowd_model.desired_lane if practice_live != null else -99)])
		return
	_key(KEY_Q)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.12).timeout
	practice_live = _live_session(practice_id)
	if practice_live == null or practice_live.crowd_model.desired_lane != 0 or practice_live.crowd_model.phase != "walk":
		await _fail("Private practice keyboard input did not open the horizontal model lane")
		return
	await _shot("practice-real-input")
	if not await _pause_and_retry(practice_id, true): return
	if not await _drive_to_finish(practice_id, "private assisted/reduced practice"): return
	if _latched_result_id != practice_id or not bool(_latched_result.get("success", false)) or not bool(_latched_result.get("practice", false)) or not bool(_latched_result.get("assisted", false)) or int(_latched_result.get("safe_count", -1)) != 6:
		await _fail("Private run did not naturally finish all six groups with current assist/reduced rules: " + str(_latched_result))
		return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result", "private practice result screen"): return
	if _progress_snapshot() != progress_before_practice:
		await _fail("Completed private practice changed persistent photos, quests, achievements, or awards")
		return
	await _shot("practice-result-no-award")
	if not await _activate_main_button("返回遊園", "return after private Crowd result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "private result returns to the park"): return
	await get_tree().process_frame
	if is_instance_id_valid(practice_id):
		await _fail("Main did not free the completed private Crowd session")
		return
	print("PASS: native Main station game-004, actual pointer/key lanes, formal six-group award, retry, and assisted reduced private completion")
	_watchdog_deadline = 0
	await main._quit_game()

func _launch_crowd(practice: bool) -> bool:
	var found := false
	for point in main.world.points:
		if point.id == CROWD_GAME_ID:
			main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
			found = true
			break
	if not found:
		await _fail("Crowd semaphore station game-004 is missing from the park")
		return false
	if not await _wait_until(func() -> bool: return main.world.nearest.get("id", "") == CROWD_GAME_ID, "game-004 station becomes nearest"): return false
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "game-004 information panel opens"): return false
	var launch_label := "練習操作" if practice else "開始遊玩"
	if not await _activate_main_button(launch_label, "launch " + ("private practice" if practice else "formal game")): return false
	if not await _wait_until(func() -> bool: return main.session != null and main.session.mode == "crowd_traffic", "game-004 session launches from Main"): return false
	_active_id = main.session.get_instance_id()
	_latched_result_id = -1
	_latched_result.clear()
	main.session.finished.connect(_capture_result_by_id.bind(_active_id), CONNECT_ONE_SHOT)
	return true

func _pause_and_retry(session_id: int, practice: bool) -> bool:
	if not await _wait_for_elapsed(session_id, 1.10, 7.0): return false
	var session := _live_session(session_id)
	if session == null: return false
	_pause_latch.clear()
	var pause_button: BaseButton = session.minigame_hud.find_child("PauseButton", true, false)
	pause_button.pressed.connect(_capture_pause.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(pause_button, "pause Crowd " + ("practice" if practice else "formal")): return false
	session = _live_session(session_id)
	if session == null or int(_pause_latch.get("session_id", -1)) != session_id or not bool(_pause_latch.get("paused", false)):
		await _fail("Real PauseButton.pressed did not latch the post-handler Crowd state: " + str(_pause_latch))
		return false
	var frozen_elapsed := float(_pause_latch.get("elapsed", -1.0))
	var frozen_phase := str(_pause_latch.get("phase", ""))
	for _frame in 6: await get_tree().process_frame
	session = _live_session(session_id)
	if session == null or not session.paused or not is_equal_approx(session.crowd_model.elapsed, frozen_elapsed) or session.crowd_model.phase != frozen_phase:
		await _fail("Crowd model clock/phase advanced during actual paused frames")
		return false
	var resume_button: BaseButton = session.minigame_hud.find_child("ResumeButton", true, false)
	if not await _native_click_button(resume_button, "resume Crowd" + (" practice" if practice else " formal")): return false
	if not await _wait_for_elapsed(session_id, frozen_elapsed + 0.16, 4.0): return false
	session = _live_session(session_id)
	if session == null: return false
	pause_button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "open Crowd retry menu"): return false
	session = _live_session(session_id)
	if session == null: return false
	var retry_button: BaseButton = session.minigame_hud.find_child("RetryButton", true, false)
	if not await _native_click_button(retry_button, "request Crowd retry"): return false
	session = _live_session(session_id)
	if session == null: return false
	_retry_latch.clear()
	var confirm_button: BaseButton = session.minigame_hud.find_child("ConfirmAction", true, false)
	if confirm_button == null:
		await _fail("Crowd retry confirmation button is missing")
		return false
	confirm_button.pressed.connect(_capture_retry.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm_button, "confirm Crowd retry"): return false
	session = _live_session(session_id)
	if session == null or int(_retry_latch.get("session_id", -1)) != session_id or float(_retry_latch.get("elapsed", -1.0)) != 0.0 or str(_retry_latch.get("phase", "")) != "red" or int(_retry_latch.get("lane", -2)) != -1 or bool(_retry_latch.get("paused", true)) or bool(_retry_latch.get("practice", not practice)) != practice:
		await _fail("ConfirmAction.pressed did not synchronously observe the exact Crowd retry reset: " + str(_retry_latch))
		return false
	return true

func _drive_to_finish(session_id: int, context: String) -> bool:
	var deadline := _wall_deadline(55.0)
	var crossing_captured := false
	while Time.get_ticks_msec() < deadline:
		var session := _live_session(session_id)
		if session == null:
			if _latched_result_id == session_id:
				break
			await _fail(context + " session disappeared without matching finished-result latch")
			return false
		if session.ended:
			if _latched_result_id == session_id: break
		var chosen := _crowd_priority_lane(session.crowd_model)
		if chosen >= 0 and session.crowd_model.desired_lane != chosen:
			_key(KEY_Q if chosen == 0 else KEY_E)
			Input.flush_buffered_events()
		if not crossing_captured and session.crowd_model.phase == "walk" and not session.crowd_model.active_group.is_empty():
			await _shot(context.replace(" ", "-") + "-first-crossing")
			crossing_captured = true
		await get_tree().physics_frame
	if _latched_result_id != session_id or _latched_result.is_empty():
		await _fail(context + " exceeded its bounded actual-input completion window; model/results=" + str(_diagnostics(session_id)))
		return false
	if int(_latched_result.get("safe_count", -1)) != 6 or int(_latched_result.get("score", -1)) != int(_latched_result.get("model_score", -2)):
		await _fail(context + " finished with inconsistent six-group ledger values: " + str(_latched_result))
		return false
	return true

func _capture_result_by_id(result: Dictionary, session_id: int) -> void:
	var candidate: Object = instance_from_id(session_id)
	if not candidate is Control or not is_instance_valid(candidate) or (candidate as Control).get_instance_id() != session_id:
		push_error("Native Crowd review lost the matching session during finished callback")
		get_tree().quit(1)
		return
	var session := candidate as Control
	_latched_result = result.duplicate(true)
	_latched_result["safe_count"] = int(session.crowd_model.safe_count)
	_latched_result["mistakes"] = int(session.mistakes)
	_latched_result["model_score"] = int(session.crowd_model.score)
	_latched_result["phase"] = str(session.crowd_model.phase)
	_latched_result_id = session_id

func _capture_pause(session_id: int) -> void:
	var session := _live_session(session_id)
	if session == null: return
	_pause_latch = {"session_id": session_id, "elapsed": float(session.crowd_model.elapsed), "phase": str(session.crowd_model.phase), "paused": bool(session.paused)}

func _capture_retry(session_id: int) -> void:
	var session := _live_session(session_id)
	if session == null: return
	_retry_latch = {"session_id": session_id, "elapsed": float(session.crowd_model.elapsed), "phase": str(session.crowd_model.phase), "lane": int(session.crowd_model.desired_lane), "paused": bool(session.paused), "practice": bool(session.practice_mode)}

func _wait_for_elapsed(session_id: int, target: float, wall_seconds: float) -> bool:
	var deadline := _wall_deadline(wall_seconds)
	while Time.get_ticks_msec() < deadline:
		var session := _live_session(session_id)
		if session == null: break
		if float(session.crowd_model.elapsed) >= target: return true
		await get_tree().physics_frame
	await _fail("Crowd elapsed time did not reach %.2f; model=%s" % [target, str(_diagnostics(session_id))])
	return false

func _live_session(session_id: int) -> Control:
	if not is_instance_valid(main) or not is_instance_id_valid(session_id): return null
	var candidate: Object = instance_from_id(session_id)
	if candidate is Control and is_instance_valid(candidate) and main.session == candidate:
		return candidate as Control
	return null

func _diagnostics(session_id: int) -> Dictionary:
	var session := _live_session(session_id)
	if session == null: return {"session": "freed", "modal": str(main.modal_kind) if is_instance_valid(main) else "<no Main>"}
	return {"elapsed": session.crowd_model.elapsed, "phase": session.crowd_model.phase, "safe_count": session.crowd_model.safe_count, "score": session.score, "mistakes": session.mistakes, "desired_lane": session.crowd_model.desired_lane, "queues": session.crowd_model.snapshot().queues}

func _activate_main_button(needle: String, context: String) -> bool:
	await get_tree().process_frame
	var button := _find(main.overlay, needle)
	if button == null:
		await _fail("Missing Main button '%s' while trying to %s" % [needle, context])
		return false
	return await _native_click_button(button, context)

func _wait_until(predicate: Callable, context: String) -> bool:
	var deadline := _wall_deadline(8.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	await _fail("Timed out waiting for %s; modal=%s session=%s" % [context, str(main.modal_kind), str(main.session)])
	return false

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		await _fail("Native Crowd post-draw screenshot is empty: " + label)
		return
	var folder := ProjectSettings.globalize_path("res://.review")
	DirAccess.make_dir_recursive_absolute(folder)
	var slug := _safe_capture_slug(label)
	var filename := "crowd-semaphore-" + slug + ".png"
	var path := folder.path_join(filename)
	if slug.is_empty() or path.get_base_dir() != folder or path.get_file() != filename:
		await _fail("Native Crowd capture label did not produce a safe filename: " + label)
		return
	if image.save_png(path) != OK:
		await _fail("Could not save native Crowd screenshot: " + path)
		return
	print("CAPTURE: " + path)

func _safe_capture_slug(label: String) -> String:
	var source := label.to_lower()
	var slug := ""
	var previous_dash := false
	for index in source.length():
		var character := source.substr(index, 1)
		var code := source.unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			slug += character
			previous_dash = false
		elif not previous_dash and not slug.is_empty():
			slug += "-"
			previous_dash = true
	return slug.trim_suffix("-")

func _progress_snapshot() -> Dictionary:
	return {
		"photos": progress.photos.duplicate(true),
		"quests": progress.quests.duplicate(true),
		"achievements": progress.achievements.duplicate(true),
		"visited": progress.visited.duplicate(true),
		"settings": progress.settings.duplicate(true),
		"appearance": progress.appearance.duplicate(true),
		"equipped": progress.equipped.duplicate(true),
		"owned_clothes": progress.owned_clothes.duplicate(),
		"wardrobe_rewarded_games": progress.wardrobe_rewarded_games.duplicate(),
		"pending": progress.platform_pending_achievements.duplicate(),
		"coins": progress.coins,
		"intro_seen": progress.intro_seen,
		"normal_count": progress.normal_count(),
		"devil_count": progress.devil_count()
	}

func _wall_deadline(simulated_seconds: float) -> int:
	return Time.get_ticks_msec() + ceili(simulated_seconds / maxf(Engine.time_scale, 0.05) * 1000.0)

func _find(node: Node, needle: String) -> Button:
	if node is Button and (node as Button).text.contains(needle): return node as Button
	for child in node.get_children():
		var found := _find(child, needle)
		if found != null: return found
	return null

func _crowd_priority_lane(model) -> int:
	var chosen := -1
	var earliest_deadline := INF
	for direction in 2:
		var lane_queue: Array = model.queues[direction]
		if lane_queue.is_empty(): continue
		var head: Dictionary = lane_queue[0]
		var deadline := float(head.arrived_at) + float(head.patience)
		if deadline < earliest_deadline:
			earliest_deadline = deadline
			chosen = direction
	return chosen
