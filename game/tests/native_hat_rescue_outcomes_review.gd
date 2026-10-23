extends "res://game/tests/native_hat_rescue_review.gd"

## SG-20 outcome paths with real Main input: first-entry lesson before any round
## clock, in-round lesson pause, a cautious one-per-pair keyboard route that only
## earns the ordinary print, an assisted formal pointer round at dusk, and a
## zero-input failure that leaves the earned save byte-identical. The fixture never
## assigns score, catch, ledger or finish fields; it only sends input events.
const OUT := ".review/hat-outcomes"
var _shot_index := 0

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Hat outcomes review requires a display and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	progress.settings["time_phase"] = "noon"
	main = _instantiate_main(false)
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _first_entry_lesson(): return
	if OS.get_cmdline_user_args().has("--lesson-only"):
		print("PASS: SG-20 first lesson pages shown before any round clock (lesson-only capture)")
		await main._quit_game()
		return
	var formal_id: int = main.session.get_instance_id()
	main.session.finished.connect(_capture_result.bind(formal_id), CONNECT_ONE_SHOT)
	if not await _in_round_lesson_pause(formal_id): return
	if not await _drive_route(formal_id, true, [3, 5]): return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result", "cautious route result"): return
	var model: Dictionary = _result_snapshot.get("model", {})
	if not bool(_result_snapshot.get("success", false)) or bool(_result_snapshot.get("devil", true)) or int(model.get("caught", -1)) != 4 or int(model.get("misses", -1)) != 2:
		await _fail("One-per-pair route did not produce its real four-catch ordinary result: " + str(model))
		return
	if str(_ledger_snapshot[3].status) != "miss" or str(_ledger_snapshot[5].status) != "miss" or _ledger_points(_ledger_snapshot) != int(_result_snapshot.get("score", -1)):
		await _fail("Skipped pair members or score rows disagree with the model ledger")
		return
	if not _overlay_text_contains("小惡魔需六頂全中心") or not _overlay_text_contains("漏接 2"):
		await _fail("Ordinary result does not explain the unmet devil condition with real counts")
		return
	if not progress.photos.has("photo-welcome-game-5") or progress.photos.has("photo-welcome-devil-5"):
		await _fail("Cautious ordinary route saved the wrong collection")
		return
	await _review_all_result_pages("ordinary")
	var coins_after_first: int = progress.coins
	var achievements_after_first: Dictionary = progress.achievements.duplicate(true)
	if not await _activate_main_button("返回遊園", "return from ordinary result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "return to park"): return

	# Assisted formal round (not practice) with pointer input at dusk and reduced motion.
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	progress.settings["time_phase"] = "dusk"
	if not await _launch_hat(true): return
	var assisted_id: int = main.session.get_instance_id()
	if main.session.practice_mode or main.session.time_phase != "dusk":
		await _fail("Assisted formal launch lost its formal/dusk state")
		return
	_result_snapshot.clear()
	_ledger_snapshot.clear()
	main.session.finished.connect(_capture_result.bind(assisted_id), CONNECT_ONE_SHOT)
	if not await _drive_route(assisted_id, false, []): return
	if not await _wait_until(func() -> bool: return main.modal_kind == "result", "assisted formal result"): return
	model = _result_snapshot.get("model", {})
	if not bool(_result_snapshot.get("success", false)) or bool(_result_snapshot.get("devil", true)) or int(model.get("caught", -1)) != 6 or not bool(model.get("assisted", false)):
		await _fail("Assisted pointer formal round did not reach a six-catch ordinary-only result: " + str(model))
		return
	if not _overlay_text_contains("輔助回合不取得小惡魔") or progress.photos.has("photo-welcome-devil-5"):
		await _fail("Assisted formal result claimed or saved a devil print")
		return
	if progress.coins != coins_after_first or progress.achievements != achievements_after_first:
		await _fail("Repeating an earned ordinary result duplicated coins or achievements")
		return
	await _review_all_result_pages("assisted-dusk")
	if not await _activate_main_button("返回遊園", "return from assisted result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "return to park"): return

	# Zero input: every hat falls; the complete earned save must stay byte-identical.
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	progress.settings["time_phase"] = "night"
	progress.save_progress()
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var before := FileAccess.get_file_as_bytes(save_path)
	if before.is_empty():
		await _fail("Failure baseline save is empty")
		return
	if not await _launch_hat(false): return
	var idle_id: int = main.session.get_instance_id()
	_result_snapshot.clear()
	main.session.finished.connect(_capture_result.bind(idle_id), CONNECT_ONE_SHOT)
	var idle_ticks := 30 * Engine.physics_ticks_per_second
	while main.modal_kind != "result" and idle_ticks > 0:
		await get_tree().physics_frame
		idle_ticks -= 1
	if main.modal_kind != "result" or bool(_result_snapshot.get("success", true)) or int(_result_snapshot.get("score", -1)) != 0:
		await _fail("Zero-input round did not end in a real zero-score failure")
		return
	if not _overlay_text_contains("救回 0 / 6"):
		await _fail("Failure result does not state the unmet ordinary count")
		return
	await _shot("night-zero-input-failure")
	if FileAccess.get_file_as_bytes(save_path) != before:
		await _fail("Failed round changed the complete earned save")
		return
	print("PASS: SG-20 first lesson before the round clock, in-round lesson pause, one-per-pair keyboard ordinary result with all pages, assisted formal pointer dusk ordinary-only, zero-input night failure with byte-identical save")
	await main._quit_game()

func _first_entry_lesson() -> bool:
	for point in main.world.points:
		if point.id == "game-005": main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
	var deadline := _wall_deadline_ms(3500)
	while main.world.nearest.get("id", "") != "game-005" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "station details"): return false
	if not await _activate_main_button("開始遊玩", "first entry"): return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel), "first lesson"): return false
	for step in 3:
		await _frames(4)
		if main.session != null or main.tutorial_panel.current_step != step:
			await _fail("First lesson page %d ran a session clock or skipped a page" % step)
			return false
		await _shot("first-lesson-%d" % (step + 1))
		if step < 2 and not await _native_click_button(_find(main.tutorial_panel, "下一步"), "next lesson page"): return false
	if not await _native_click_button(_find(main.tutorial_panel, "開始挑戰"), "start after lesson"): return false
	if not await _wait_until(func() -> bool: return main.session != null and main.session.game_id == "game-005", "round after lesson"): return false
	var state: Dictionary = main.session.hat_model.snapshot()
	if float(state.elapsed) > 0.4 or float(state.lead_in_left) <= 0.0 or not progress.has_seen_tutorial("game-005"):
		await _fail("Round did not begin fresh in its calm lead-in after the lesson: " + str(state.elapsed))
		return false
	await _shot("lead-in")
	return true

func _in_round_lesson_pause(session_id: int) -> bool:
	if not await _wait_until(func() -> bool: return _hat_elapsed(session_id) >= 0.6, "early round clock"): return false
	var session := _session_by_id(session_id)
	if not await _native_click_button(session.minigame_hud.find_child("HelpButton", true, false), "open lesson mid-round"): return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel), "mid-round lesson"): return false
	var frozen := _hat_elapsed(session_id)
	await _frames(30)
	if absf(_hat_elapsed(session_id) - frozen) > 0.0001 or not _session_by_id(session_id).paused:
		await _fail("Reading the lesson mid-round consumed round time")
		return false
	await _shot("mid-round-lesson")
	if not await _native_click_button(_find(main.tutorial_panel, "關閉"), "close lesson"): return false
	session = _session_by_id(session_id)
	if not await _wait_until(func() -> bool: return session.minigame_hud.find_child("ResumeButton", true, false).is_visible_in_tree(), "paused HUD after lesson"): return false
	if absf(_hat_elapsed(session_id) - frozen) > 0.0001:
		await _fail("Closing the lesson resumed the clock without the player")
		return false
	return await _native_click_button(session.minigame_hud.find_child("ResumeButton", true, false), "resume after lesson")

## Real keyboard or pointer route that targets the earliest-arriving airborne hat
## not in `skip`; skipped brims are left to fall into the sea.
func _drive_route(session_id: int, keyboard: bool, skip: Array) -> bool:
	# Engine-time budget (physics ticks), independent of how slowly a loaded host renders.
	var ticks_left := 40 * Engine.physics_ticks_per_second
	var held := 0
	var pair_shot := false
	while _result_snapshot.is_empty() and ticks_left > 0:
		await get_tree().physics_frame
		ticks_left -= 1
		var session := _session_by_id(session_id)
		if session == null:
			break
		var state: Dictionary = session.hat_model.snapshot()
		var target_index := -1
		var best_eta := INF
		for index in state.hats.size():
			var hat: Dictionary = state.hats[index]
			if bool(hat.active) and not bool(hat.resolved) and not skip.has(index) and float(hat.eta) < best_eta:
				best_eta = float(hat.eta)
				target_index = index
		var target_x := float(state.player_x)
		if target_index >= 0:
			target_x = float(state.hats[target_index].landing_x)
		elif int(state.next_hat_index) >= 0 and not skip.has(int(state.next_hat_index)):
			target_x = float(state.next_spawn_x)
		if keyboard:
			var velocity := float(state.player_velocity)
			var distance: float = target_x - float(state.player_x)
			var braking: float = velocity * velocity / (2.0 * session.hat_model.PLAYER_ACCEL) + 24.0
			var direction := 0
			if absf(velocity) > 24.0 and signf(distance) == signf(velocity) and absf(distance) <= braking:
				direction = -int(signf(velocity))
			elif absf(distance) > 18.0:
				direction = int(signf(distance))
			if direction != held:
				if held != 0: _held_key(KEY_RIGHT if held > 0 else KEY_LEFT, false)
				if direction != 0: _held_key(KEY_RIGHT if direction > 0 else KEY_LEFT, true)
				held = direction
		else:
			_motion(_hat_viewport_point(session, Vector2(target_x, 540.0)))
		if target_index >= 0 and best_eta <= 0.30 and float(state.catch_window) <= 0.0:
			if keyboard:
				_key(KEY_SPACE)
			else:
				_click(_hat_viewport_point(session, Vector2(target_x, 540.0)))
		if not pair_shot and int(state.airborne_count) == 2 and float(state.wind_strength) != 0.0:
			pair_shot = true
			await _shot("pair-gust-%s" % ("keyboard" if keyboard else "pointer"))
	if held != 0: _held_key(KEY_RIGHT if held > 0 else KEY_LEFT, false)
	if _result_snapshot.is_empty():
		await _fail("Route did not reach a natural result")
		return false
	return true

func _review_all_result_pages(label: String) -> void:
	await _frames(6)
	await _shot("result-%s-page-1" % label)
	var page := 1
	while page < 4:
		var next: Button = main.overlay.find_child("ResultScorePagesNext", true, false) as Button
		if next == null or next.disabled or not next.is_visible_in_tree():
			break
		if not await _native_click_button(next, "next result page"):
			return
		page += 1
		await _frames(4)
		await _shot("result-%s-page-%d" % [label, page])

func _overlay_text_contains(fragment: String) -> bool:
	return _label_contains(main.overlay, fragment)

func _label_contains(node: Node, fragment: String) -> bool:
	if node is Label and (node as Label).text.contains(fragment):
		return true
	for child in node.get_children():
		if _label_contains(child, fragment):
			return true
	return false

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_shot_index += 1
	if not main._capture("%s/%02d-%s.png" % [OUT, _shot_index, name]):
		push_error("Could not capture " + name)
