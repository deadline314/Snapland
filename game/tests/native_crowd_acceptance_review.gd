extends "res://game/tests/native_minigame_acceptance.gd"

## SG-19 native acceptance through the real park station and Main result flow.
## Run with --fixed-fps 60 or --write-movie so the round clock is deterministic.
## The routes decide lanes the way a player reads the board: "deadline" serves the
## lane whose head would expire first (what the red "先放這側" card and the
## patience seconds show); "oldest" serves whoever arrived first and shows the cost.
## Inputs are real Q/E keys or clicks on the signal cards; no rule state is written.

const GAME_ID := "game-004"
const SIGNAL_POINTS := [Vector2(520.0, 235.0), Vector2(760.0, 235.0)]

func _run() -> void:
	_read_arguments(".review/sg19-acceptance", 20000)
	if not await _start_main(): return
	if video_only:
		if await _standard_keyboard_route():
			print("PASS: native video route (standard formal round only)")
			await main._quit_game()
		return
	if not await _assisted_reduced_route(): return
	if not await _standard_keyboard_route(): return
	if not await _mouse_oldest_first_route(): return
	if not await _mouse_practice_route(): return
	print("PASS: native SG-19 crowd planning with real keyboard/mouse, assist/reduced-motion ordinary-only, deadline-first devil clear, oldest-first rescue loss, pause/retry, practice and return")
	await main._quit_game()

func _deadline_lane(model) -> int:
	return _crowd_priority_lane(model)

func _oldest_lane(model) -> int:
	var chosen := -1
	var oldest := INF
	for lane in 2:
		if model.queues[lane].is_empty(): continue
		var arrived := float(model.queues[lane][0].arrived_at)
		if arrived < oldest:
			oldest = arrived
			chosen = lane
	return chosen

func _request(lane: int, use_mouse: bool) -> void:
	if use_mouse: _click(SIGNAL_POINTS[lane])
	else: _key(KEY_Q if lane == 0 else KEY_E)

## Plays the whole round with real inputs, capturing named moments on the way.
func _play_round(session: Control, policy: Callable, use_mouse: bool, captures: Dictionary = {}) -> bool:
	var model = session.crowd_model
	var captured_moments: Dictionary = {}
	for _frame in 2400:
		if not is_instance_valid(session) or session.ended: return true
		var state: Dictionary = model.snapshot()
		if float(state.elapsed) >= 0.95:
			var chosen: int = policy.call(model)
			if chosen >= 0 and int(model.desired_lane) != chosen:
				_request(chosen, use_mouse)
		for moment in captures:
			if captured_moments.has(moment) or not _moment_reached(str(moment), state): continue
			captured_moments[moment] = true
			if not await _capture(str(captures[moment])): return false
		await _frames(1)
	await _fail("Crowd round did not finish inside 40 seconds of game time")
	return false

func _moment_reached(moment: String, state: Dictionary) -> bool:
	match moment:
		"opening": return float(state.elapsed) >= 0.3
		"warning":
			for risk in state.lane_risk:
				if bool((risk as Dictionary).get("must_go_next", false)): return true
			return false
		"advice": return int(state.recommended_lane) >= 0 and float(state.elapsed) >= 2.5
		"rescue":
			var active: Dictionary = state.active
			return bool(active.get("rescue", false)) and float(state.active_progress) >= 0.45
		"clearance": return str(state.phase) == "clearance"
	return false

func _assisted_reduced_route() -> bool:
	if not await _set_settings(true, true, "night"): return false
	var session := await _launch_station(GAME_ID, "開始遊玩")
	if session == null: return false
	if not session.assisted or not session.reduced_motion:
		await _fail("Assisted/reduced fixture did not reach the crowd session")
		return false
	var latched := _latch_result(session)
	if not await _play_round(session, _deadline_lane, false, {"advice": "sg19-assist-reduced-night-advice.png"}): return false
	var result: Dictionary = await _wait_result(latched)
	if result.is_empty(): return false
	if not result.success or result.devil or result.score_summary.rows.size() != 6:
		await _fail("Assisted deadline-first round must be ordinary-only with six safe groups: %s" % str(result))
		return false
	if not progress.photos.has("photo-welcome-game-4") or progress.photos.has("photo-welcome-devil-4"):
		await _fail("Assisted crowd round must collect only the ordinary photo")
		return false
	if not _result_shows(["輔助遊玩", "輔助回合不取得小惡魔拍貼", "普通拍貼已收藏"]) or _result_shows(["小惡魔也入鏡了"]):
		await _fail("Assisted crowd result did not explain ordinary-only eligibility: " + _visible_text(main.overlay))
		return false
	if not await _capture("sg19-assist-result.png"): return false
	return await _return_to_park()

func _standard_keyboard_route() -> bool:
	if not await _set_settings(false, false, "noon"): return false
	var session := await _launch_station(GAME_ID, "開始遊玩")
	if session == null: return false
	if not await _wait_frames_until(func() -> bool: return float(session.crowd_model.elapsed) >= 1.0, "first arrival", 240): return false
	_key(KEY_Q)
	if not await _wait_frames_until(func() -> bool: return str(session.crowd_model.phase) == "walk", "first crossing", 60): return false
	if not await _pause_resume_retry(session): return false
	if int(session.crowd_model.safe_count) != 0 or float(session.crowd_model.elapsed) > 0.25 or str(session.crowd_model.phase) != "red":
		await _fail("Retry did not restore a fresh red crossing: %s" % str(session.crowd_model.snapshot().phase))
		return false
	var latched := _latch_result(session)
	if not await _play_round(session, _deadline_lane, false, {"opening": "sg19-noon-opening-board.png", "warning": "sg19-noon-rescue-warning.png", "rescue": "sg19-noon-rescue-crossing.png", "clearance": "sg19-noon-clearance.png"}): return false
	var result: Dictionary = await _wait_result(latched)
	if result.is_empty(): return false
	if not result.devil or int(result.score) < 430 or int(result.mistakes) != 0:
		await _fail("Standard deadline-first keyboard round must earn devil at >= 430: %s" % str(result))
		return false
	if not progress.photos.has("photo-welcome-devil-4") or not progress.achievements.has("ACH_GAME_004"):
		await _fail("Standard crowd devil clear did not persist the devil photo and achievement")
		return false
	if not _result_shows(["本次成績 %d" % int(result.score), "標準遊玩", "已達成小惡魔條件", "小惡魔也入鏡了"]):
		await _fail("Crowd devil result did not explain its qualification: " + _visible_text(main.overlay))
		return false
	if not await _capture("sg19-standard-devil-result.png"): return false
	return true

func _mouse_oldest_first_route() -> bool:
	if not await _set_settings(false, false, "dusk"): return false
	var before := _persistent_snapshot()
	if not await _click_overlay("再玩一次", "replay crowd from the result"): return false
	if not await _wait_frames_until(func() -> bool: return main.session != null and main.modal_kind == "", "crowd replay", 240): return false
	var session: Control = main.session
	var latched := _latch_result(session)
	if not await _play_round(session, _oldest_lane, true, {"warning": "sg19-dusk-mouse-warning.png"}): return false
	var result: Dictionary = await _wait_result(latched)
	if result.is_empty(): return false
	# Main frees the session with the result, so counts come from the per-group ledger.
	var state := {"safe_count": 0, "missed_count": 0}
	for row in result.score_summary.rows:
		if str(row.label).contains("改道"): state.missed_count += 1
		elif str(row.label).contains("通行 50"): state.safe_count += 1
	if result.success or int(state.get("missed_count", 0)) < 1:
		await _fail("Oldest-first mouse round should lose at least one group: %s" % str(result))
		return false
	if _persistent_snapshot() != before:
		await _fail("A failed crowd round changed persistent progress")
		return false
	if not _result_shows(["本次 %d / 6，改道 %d" % [int(state.safe_count), int(state.missed_count)], "等太久改道"]):
		await _fail("Failed crowd result did not explain the lost group: " + _visible_text(main.overlay))
		return false
	if not await _capture("sg19-mouse-oldest-first-result.png"): return false
	return true

func _mouse_practice_route() -> bool:
	var before := _persistent_snapshot()
	if not await _click_overlay("練習操作", "start private crowd practice"): return false
	if not await _wait_frames_until(func() -> bool: return main.session != null and main.modal_kind == "" and main.session.practice_mode, "crowd practice", 240): return false
	var session: Control = main.session
	var latched := _latch_result(session)
	if not await _play_round(session, _deadline_lane, true): return false
	var result: Dictionary = await _wait_result(latched)
	if result.is_empty(): return false
	if not result.practice or _persistent_snapshot() != before or not _result_shows(["練習完成", "不保存"]):
		await _fail("Crowd practice changed progress or claimed collection: %s" % str(result))
		return false
	if not await _capture("sg19-practice-result.png"): return false
	return await _return_to_park()
