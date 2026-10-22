extends "res://game/tests/native_balloon_controls_review.gd"

## Genuine collision, recovery, assisted formal replay and natural timeout.
## No score, position, timer, mistake or finish assignments after session launch.
func _run() -> void:
	if not _native_preflight("Balloon outcomes review"): return
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _enter_station() or not await _launch_from_station("開始遊玩"): return
	_key(KEY_ENTER)
	# Deliberately enter the first dock at full speed using actual pointer input.
	var deadline := _wall_deadline(12.0)
	while _session_is_live() and active.mistakes == 0 and Time.get_ticks_msec() < deadline:
		_motion(active.presentation.design_to_screen(active.target))
		Input.flush_buffered_events()
		await get_tree().physics_frame
	if not _session_is_live() or active.mistakes != 1:
		await _fail("Actual fast approach did not record its first mistake");return
	await _shot("balloon-fast-approach")
	# Fly into the moving hazard, then recover without changing the model.
	deadline = _wall_deadline(12.0)
	while _session_is_live() and active.mistakes == 1 and Time.get_ticks_msec() < deadline:
		_motion(active.presentation.design_to_screen(active._balloon_hazard_at(active.phase)))
		Input.flush_buffered_events()
		await get_tree().physics_frame
	if not _session_is_live() or active.mistakes != 2:
		await _fail("Actual hazard approach did not record one collision");return
	await _shot("balloon-hazard-recovery")
	if not await _drive_route(true) or not await _wait_for_result(): return
	if not await _assert_completed_case("ordinary-after-errors", false, false): return
	if bool(_case_result.devil) or int(_case_result.mistakes) < 2 or not _result_text_contains("本次失誤"):
		await _fail("Recovered result did not explain its ordinary-only qualification");return
	var keys: Array = []
	for row in _case_result.score_summary.rows:
		keys.append(str(row.key))
		if str(row.key) in ["balloon_hazard", "balloon_fast_dock"]:
			if not bool(row.get("progress_only",false)) or not _result_text_contains("%s  ·  %d 次" % [row.label,int(row.count)]):
				await _fail("Actual result hides the counted cause of each mistake");return
	if not keys.has("balloon_hazard") or not keys.has("balloon_fast_dock") or not keys.has("mailbag_3"):
		await _fail("Result omitted actual collision, fast approach or station outcomes");return
	if not progress.photos.has("photo-welcome-game-1") or progress.photos.has("photo-welcome-devil-1"):
		await _fail("Recovered ordinary route saved the wrong photo qualification");return
	await _shot("balloon-ordinary-after-errors-result")
	if not await _return_to_station_info(): return
	# Real formal assisted route must never display or save a devil award.
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	progress.settings["time_phase"] = "night"
	var coins_before: int = progress.coins
	var achievements_before: Dictionary = progress.achievements.duplicate(true)
	if not await _enter_station() or not await _launch_from_station("開始遊玩"): return
	if not active.assisted or not active.reduced_motion or active.time_phase != "night":
		await _fail("Formal route lost assist, reduced-motion or night settings");return
	_key(KEY_ENTER)
	await _shot("balloon-assisted-night-start")
	if not await _drive_route(true) or not await _wait_for_result(): return
	if not await _assert_completed_case("assisted-formal", true, false): return
	if bool(_case_result.devil) or progress.photos.has("photo-welcome-devil-1") or not _result_text_contains("輔助回合不取得") or _result_text_contains("小惡魔也入鏡"):
		await _fail("Assisted result falsely claimed a devil award");return
	if progress.coins != coins_before or progress.achievements != achievements_before:
		await _fail("Formal replay duplicated currency or achievements");return
	await _shot("balloon-assisted-night-ordinary-result")
	if not await _return_to_station_info(): return
	# A complete nonempty save is the failure baseline. Let all55 seconds elapse.
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	progress.settings["time_phase"] = "noon"
	progress.save_progress()
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var before := FileAccess.get_file_as_bytes(save_path)
	if before.is_empty(): await _fail("Timeout baseline is empty");return
	if not await _enter_station() or not await _launch_from_station("開始遊玩"): return
	_key(KEY_ENTER)
	_release_route_inputs()
	deadline = _wall_deadline(62.0)
	while _session_is_live() and not active.ended and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if not await _wait_for_result(): return
	if bool(_case_result.success) or int(_case_result.score) != 0 or not _result_text_contains("0 / 3"):
		await _fail("Natural timeout fabricated a completed delivery");return
	if before != FileAccess.get_file_as_bytes(save_path):
		await _fail("Failed natural timeout changed the complete earned save");return
	await _shot("balloon-natural-timeout-result")
	print("PASS: actual fast approach and hazard, recovered ordinary delivery, formal assisted night/reduced ordinary-only replay, natural55-second timeout and complete earned save unchanged")
	await main._quit_game()
