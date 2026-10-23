extends "res://game/tests/native_minigame_acceptance.gd"

## SG-18 native acceptance through the real park station and Main result flow.
## Run with --write-movie so the game clock advances exactly 1/60 s per frame.
## Routes: assisted + reduced-motion keyboard (ordinary only), standard keyboard
## with early press, pause/resume/retry and a three-perfect devil clear, mouse-only
## round with a real miss, private mouse practice, then leaving to the park.

const FountainModel = preload("res://game/minigames/fountain_jump_model.gd")
const GAME_ID := "game-003"
const POINTER := Vector2(640, 420)

func _run() -> void:
	_read_arguments(".review/sg18-acceptance", 20000)
	if not await _start_main(): return
	if video_only:
		if await _standard_keyboard_route():
			print("PASS: native video route (standard formal round only)")
			await main._quit_game()
		return
	if not await _assisted_reduced_keyboard_route(): return
	if not await _standard_keyboard_route(): return
	if not await _mouse_miss_route(): return
	if not await _mouse_practice_route(): return
	print("PASS: native SG-18 fountain phrases with real keyboard/mouse, assist/reduced-motion ordinary-only, three-perfect devil, real miss, pause/retry, practice and return")
	await main._quit_game()

## Main frees the session when it opens the result, so grades come from the result ledger.
func _grades(result: Dictionary) -> Array[String]:
	var grades: Array[String] = []
	for row in result.get("score_summary", {}).get("rows", []):
		for grade in ["完美", "準確", "踩中", "錯過"]:
			if str(row.get("label", "")).contains(grade):
				grades.append(grade)
				break
	return grades

func _jump_with(session: Control, use_mouse: bool) -> void:
	if use_mouse: _click(POINTER)
	else: _key(KEY_SPACE)

## Presses at beat + offset for each phrase; a null offset means no input.
func _play_offsets(session: Control, offsets: Array, use_mouse: bool, captures: Dictionary = {}) -> bool:
	for index in offsets.size():
		var counts: Array[Dictionary] = FountainModel.counts(index)
		if captures.has("count_%d" % index):
			if not await _wait_for_session_phase(session, float(counts[1].time) + 0.08): return false
			if not await _capture(str(captures["count_%d" % index])): return false
		if captures.has("rest_%d" % index):
			if not await _wait_for_session_phase(session, float(counts[2].time) + 0.08): return false
			if not await _capture(str(captures["rest_%d" % index])): return false
		var beat := FountainModel.beat_time(index)
		if offsets[index] == null:
			if not await _wait_frames_until(func() -> bool: return not is_instance_valid(session) or session.ended or int(session.fountain_attempts) > index, "jump %d to resolve as a miss" % (index + 1)): return false
			continue
		if not await _wait_for_session_phase(session, beat + float(offsets[index])): return false
		_jump_with(session, use_mouse)
		if not await _wait_frames_until(func() -> bool: return int(session.fountain_attempts) > index, "jump %d to register" % (index + 1), 30): return false
		if captures.has("air_%d" % index):
			if not await _wait_for_session_phase(session, beat + float(offsets[index]) + 0.30): return false
			if not await _capture(str(captures["air_%d" % index])): return false
		if captures.has("land_%d" % index):
			if not await _wait_for_session_phase(session, float(session.fountain_jump_started) + session.FOUNTAIN_JUMP_DURATION + 0.08): return false
			if not await _capture(str(captures["land_%d" % index])): return false
	return true


func _assisted_reduced_keyboard_route() -> bool:
	if not await _set_settings(true, true, "night"): return false
	var before := _persistent_snapshot()
	var session := await _launch_station(GAME_ID, "開始遊玩")
	if session == null: return false
	if not session.assisted or not session.reduced_motion:
		await _fail("Assisted/reduced fixture did not reach the session")
		return false
	var result_wait := _latch_result(session)
	# Assist widens perfect to ±110 ms: +90 ms late is still perfect, three perfect jumps.
	if not await _play_offsets(session, [0.09, 0.0, -0.08], false, {"count_0": "sg18-assist-reduced-night-count.png", "rest_2": "sg18-assist-reduced-night-rest.png"}): return false
	var result: Dictionary = await _wait_result(result_wait)
	if result.is_empty(): return false
	if int(result.score) != 900 or not result.success or result.devil:
		await _fail("Assisted three-perfect round must be 900 ordinary-only: %s" % str(result))
		return false
	if not progress.photos.has("photo-welcome-game-3") or progress.photos.has("photo-welcome-devil-3"):
		await _fail("Assisted round must collect only the ordinary photo")
		return false
	if not _result_shows(["本次成績 900", "輔助遊玩", "輔助回合不取得小惡魔拍貼", "普通拍貼已收藏"]) or _result_shows(["小惡魔也入鏡了"]):
		await _fail("Assisted result did not explain ordinary-only eligibility: " + _visible_text(main.overlay))
		return false
	if not await _capture("sg18-assist-result.png"): return false
	if before.photos.has("photo-welcome-game-3"):
		await _fail("Fresh profile unexpectedly started with the fountain photo")
		return false
	return await _return_to_park()

func _standard_keyboard_route() -> bool:
	if not await _set_settings(false, false, "noon"): return false
	var session := await _launch_station(GAME_ID, "開始遊玩")
	if session == null: return false
	if not await _wait_for_session_phase(session, float(FountainModel.counts(0)[0].time) + 0.05): return false
	# An early press during the count-in only gives feedback and keeps all three chances.
	_key(KEY_SPACE)
	await _frames(3)
	if int(session.fountain_attempts) != 0 or int(session.mistakes) != 0 or not str(session.prompt).contains("還沒到起跳拍"):
		await _fail("Early count-in press consumed a jump or gave no guidance: attempts=%d prompt=%s" % [session.fountain_attempts, session.prompt])
		return false
	if not await _capture("sg18-early-press-feedback.png"): return false
	if not await _pause_resume_retry(session): return false
	var result_wait := _latch_result(session)
	if not await _play_offsets(session, [0.0, 0.0, 0.0], false, {"count_0": "sg18-noon-slow-count.png", "count_1": "sg18-noon-quick-count.png", "rest_2": "sg18-noon-rest-phrase.png", "air_0": "sg18-noon-airborne.png", "land_1": "sg18-noon-landing-splash.png"}): return false
	var result: Dictionary = await _wait_result(result_wait)
	if result.is_empty(): return false
	if int(result.score) != 900 or not result.devil or _grades(result) != ["完美", "完美", "完美"]:
		await _fail("Standard keyboard three-perfect round must earn devil at 900: %s" % str(result))
		return false
	if not progress.photos.has("photo-welcome-devil-3") or not progress.achievements.has("ACH_GAME_003"):
		await _fail("Standard devil clear did not persist the devil photo and achievement")
		return false
	if not _result_shows(["本次成績 900", "標準遊玩", "已達成小惡魔條件", "小惡魔也入鏡了"]):
		await _fail("Devil result did not explain its qualification: " + _visible_text(main.overlay))
		return false
	if not await _capture("sg18-standard-devil-result.png"): return false
	return true

func _mouse_miss_route() -> bool:
	# Retry from the result screen with the same standard settings, now mouse only, at dusk.
	if not await _set_settings(false, false, "dusk"): return false
	var before := _persistent_snapshot()
	if not await _click_overlay("再玩一次", "replay from the result"): return false
	if not await _wait_frames_until(func() -> bool: return main.session != null and main.modal_kind == "", "replay session", 240): return false
	var session: Control = main.session
	var result_wait := _latch_result(session)
	if not await _play_offsets(session, [0.12, null, -0.18], true, {"air_0": "sg18-dusk-mouse-airborne.png"}): return false
	var result: Dictionary = await _wait_result(result_wait)
	if result.is_empty(): return false
	if int(result.score) != 300 or result.success or _grades(result) != ["準確", "錯過", "踩中"]:
		await _fail("Mouse miss route must be 300 without ordinary: %s" % str(result))
		return false
	if _persistent_snapshot() != before:
		await _fail("A failed round changed persistent progress")
		return false
	if not _result_shows(["本次成績 300", "本次 2 / 3，錯過 1", "第2跳・快拍・錯過拍點"]):
		await _fail("Failed result did not explain hits, misses and the missed phrase: " + _visible_text(main.overlay))
		return false
	if not await _capture("sg18-mouse-miss-result.png"): return false
	return true

func _mouse_practice_route() -> bool:
	var before := _persistent_snapshot()
	if not await _click_overlay("練習操作", "start private practice"): return false
	if not await _wait_frames_until(func() -> bool: return main.session != null and main.modal_kind == "" and main.session.practice_mode, "practice session", 240): return false
	var session: Control = main.session
	var result_wait := _latch_result(session)
	if not await _play_offsets(session, [0.0, -0.05, 0.05], true): return false
	var result: Dictionary = await _wait_result(result_wait)
	if result.is_empty(): return false
	if not result.practice or _persistent_snapshot() != before or not _result_shows(["練習完成", "不保存"]):
		await _fail("Practice round changed progress or claimed collection: %s" % str(result))
		return false
	if not await _capture("sg18-practice-result.png"): return false
	return await _return_to_park()
