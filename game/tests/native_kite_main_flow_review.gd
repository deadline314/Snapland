extends "res://game/tests/native_fountain_review.gd"

## End-to-end fixture for SG-17 game-002. The inherited base provides genuine
## window mouse/key clicks, Main boot, safe screenshot writes and modal waits.
const MAIN_REVIEW_DIR := ".review/sg17-kite-main-flow"
const TARGET_GAME_ID := "game-002"
const EXPECTED_ACHIEVEMENT := "ACH_GAME_002"

var _guard_active := false
var _wall_started_msec := 0
var _scaled_elapsed := 0.0
var _failure_latched := false
var _ordinary_result: Dictionary = {}
var _ordinary_model_state: Dictionary = {}
var _ordinary_session_id := 0
var _ordinary_finish_signals := 0
var _retry_observed := false
var _leave_observed := false
var _practice_session_id := 0
var _progress_after_earned := {}

func _process(delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
	if not _guard_active or _failure_latched:
		return
	_scaled_elapsed += maxf(delta, 0.0)
	var wall_elapsed := Time.get_ticks_msec() - _wall_started_msec
	if _scaled_elapsed >= 180.0:
		_fail("Native SG-17 Main flow exceeded its 180-second scaled-time guard")
	elif wall_elapsed >= 300000:
		_fail("Native SG-17 Main flow exceeded its 300-second wall-clock guard")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		_fail("Native SG-17 Main flow requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		return
	_wall_started_msec = Time.get_ticks_msec()
	_guard_active = true
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		_fail("Progress autoload is missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	progress.settings["time_phase"] = "noon"
	main = _instantiate_main(false)
	if main == null:
		_fail("Could not instantiate the real Main scene")
		return
	get_tree().root.add_child(main)
	await _frames(6)
	if not await _require_park("opening the first-visit game-002 route"):
		return
	if not await _launch_from_first_tutorial():
		return
	var standard_session: Control = main.session
	_ordinary_session_id = standard_session.get_instance_id()
	standard_session.finished.connect(_latch_ordinary_finish.bind(_ordinary_session_id))
	if not await _capture_kite_route(standard_session, "ordinary", 5):
		return
	if not await _wait_for_result("the actual five-center 500-point result"):
		return
	if _ordinary_finish_signals != 1 or int(_ordinary_result.get("score", -1)) != 500 or not bool(_ordinary_result.get("success", false)) or not bool(_ordinary_result.get("devil", false)) or bool(_ordinary_result.get("practice", true)):
		_fail("Main result was not one natural unassisted five-center 500-point finish: result=%s finish_signals=%d" % [str(_ordinary_result), _ordinary_finish_signals])
		return
	if not _verify_earned_progress():
		return
	_progress_after_earned = _progress_state()
	if not progress.save_progress():
		_fail("Could not persist the real ordinary/devil result")
		return
	progress._reset_memory()
	progress.load_progress()
	if _progress_state() != _progress_after_earned:
		_fail("Reloading the isolated save changed earned Kite collections or achievement state")
		return
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/ordinary-result.png"):
		_fail("Could not capture the natural Main result screen")
		return
	if not await _capture_live_achievement():
		return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "result returns to the park"):
		return
	if _ordinary_finish_signals != 1 or _progress_state() != _progress_after_earned:
		_fail("Returning to the park repeated or changed the earned result")
		return
	if not await _launch_private_practice():
		return
	var practice_session: Control = main.session
	_practice_session_id = practice_session.get_instance_id()
	if not await _capture_kite_route(practice_session, "practice-before-retry", 1):
		return
	if not await _retry_private_session(practice_session):
		return
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/practice-retried.png"):
		_fail("Could not capture the confirmed private-practice retry state")
		return
	if not await _capture_kite_route(practice_session, "practice-after-retry", 1):
		return
	if not await _leave_private_session(practice_session):
		return
	if _progress_state() != _progress_after_earned:
		_fail("Private practice, retry, or leave changed earned collections, achievements, quests, or currency")
		return
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/park-after-private-leave.png"):
		_fail("Could not capture the live park after private practice leave")
		return
	if not progress.save_progress():
		_fail("Could not save the post-practice persistence check")
		return
	progress._reset_memory()
	progress.load_progress()
	if _progress_state() != _progress_after_earned:
		_fail("Reloading the isolated save after private practice changed the earned state")
		return
	print("PASS: first-visit tutorial, native keyboard Kite play, five center rings/500 and one ordinary+devil+achievement award, real return and achievement UI, isolated-save reload, assisted/reduced private practice with confirmed retry and leave, unchanged progression")
	_guard_active = false
	# Leaving practice just started the park audio fade. Use Main's shutdown
	# while the tree is alive so its tweens and streams are released before exit;
	# Main remains visible throughout the drain, preserving the final park frame.
	await main._quit_game()

func _launch_from_first_tutorial() -> bool:
	if not await _move_to_kite_station(): return false
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "native E opens Kite station information"):
		return false
	if not await _activate_main_button("開始遊玩", "request the first game-002 play"):
		return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel) and main.tutorial_panel.visible, "first-visit game-002 tutorial"):
		return false
	if progress.has_seen_tutorial(TARGET_GAME_ID):
		_fail("First-visit tutorial unexpectedly began in the returning-player state")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/first-visit-tutorial.png"):
		_fail("Could not capture the actual first-visit tutorial panel")
		return false
	var lesson_start := _find(main.tutorial_panel, "開始挑戰") as Button
	if lesson_start == null:
		_fail("First-visit tutorial does not expose a real start button")
		return false
	if not await _native_click_button(lesson_start, "start from the first-visit lesson"):
		return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.session) and main.session.game_id == TARGET_GAME_ID, "first-visit lesson launches the real game"):
		return false
	if not progress.has_seen_tutorial(TARGET_GAME_ID):
		_fail("Starting the real lesson did not persist the tutorial-seen marker")
		return false
	return true

func _move_to_kite_station() -> bool:
	if not await _require_park("finding the Kite station"):
		return false
	var found := false
	for point in main.world.points:
		if str(point.id) != TARGET_GAME_ID:
			continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		_fail("The real park is missing game-002")
		return false
	var deadline := _wall_deadline_ms(4000)
	while str(main.world.nearest.get("id", "")) != TARGET_GAME_ID and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not await _require_park("approaching the Kite station"):
			return false
	if str(main.world.nearest.get("id", "")) != TARGET_GAME_ID:
		_fail("Moving to the station did not activate the actual game-002 interaction")
		return false
	return true

func _launch_private_practice() -> bool:
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _move_to_kite_station(): return false
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "open game-002 details for private practice"):
		return false
	if not await _activate_main_button("練習操作", "launch private Kite practice"):
		return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.session) and main.session.game_id == TARGET_GAME_ID, "private practice launches from Main"):
		return false
	var live: Control = main.session
	if not live.practice_mode or not live.assisted or not live.reduced_motion:
		_fail("Private practice did not retain assist and reduced-motion settings")
		return false
	if not await _require_live_session(live, "capturing the private practice start"):
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/assisted-reduced-practice-start.png"):
		_fail("Could not capture the real assisted/reduced-motion practice screen")
		return false
	return true

func _capture_kite_route(live: Control, label: String, desired_centers: int) -> bool:
	if not await _require_live_session(live, "starting actual Kite route " + label):
		return false
	var session_id := live.get_instance_id()
	var initial_state: Dictionary = live.kite_model.snapshot()
	if not main._capture(MAIN_REVIEW_DIR + "/" + label + "-action.png"):
		_fail("Could not capture the live " + label + " Kite action state")
		return false
	var slow_factor := maxi(1, int(ceil(1.0 / maxf(Engine.time_scale, 0.01))))
	var local_wall_deadline := Time.get_ticks_msec() + mini(180000 * slow_factor, 300000)
	var held_key := 0
	var boost_used := false
	var boost_held := false
	var boost_started := 0.0
	var boost_observed := false
	var reel_used := false
	var reel_held := false
	var reel_started := 0.0
	var reel_observed := false
	var captured_gust := false
	var frame_count := 0
	while Time.get_ticks_msec() < local_wall_deadline:
		if label == "ordinary" and not _ordinary_result.is_empty():
			break
		if not await _require_live_session_id(session_id, "steering " + label):
			return false
		live = main.session
		var state: Dictionary = live.kite_model.snapshot()
		boost_observed = boost_observed or bool(state.get("boost", false))
		reel_observed = reel_observed or bool(state.get("reel", false))
		if int(state.get("center_hits", 0)) >= desired_centers:
			break
		if bool(state.get("finished", false)) or bool(state.get("ended", false)) or live.ended:
			break
		var ring_index := int(state.get("nextRing", 0))
		var desired_aim := 0.0
		if ring_index < live.kite_model.RING_HEIGHT.size():
			desired_aim = clampf((float(state.get("height", 380.0)) - float(live.kite_model.RING_HEIGHT[ring_index])) * 0.024 - float(state.get("vy", 0.0)) * 0.014, -1.0, 1.0)
		var next_key := KEY_UP if desired_aim > 0.25 else (KEY_DOWN if desired_aim < -0.25 else 0)
		if next_key != held_key:
			if held_key != 0: _send_key(held_key, false)
			if next_key != 0: _send_key(next_key, true)
			held_key = next_key
		if not captured_gust and absf(float(state.get("actualwind", 0.0))) >= 30.0:
			await RenderingServer.frame_post_draw
			if not main._capture(MAIN_REVIEW_DIR + "/" + label + "-gust.png"):
				_fail("Could not capture naturally rendered " + label + " gust cue")
				return false
			captured_gust = true
		var distance_to_ring := float(state.get("ring_x", -1.0)) - float(state.get("x", 0.0)) if ring_index < 5 else INF
		if not boost_used and not boost_held and ring_index < 5 and distance_to_ring > 230.0 and float(state.get("tension", 1.0)) < 0.62:
			_send_key(KEY_SPACE, true)
			boost_held = true
			boost_started = float(state.get("elapsed", 0.0))
		elif boost_held and float(state.get("elapsed", 0.0)) - boost_started >= 0.18:
			_send_key(KEY_SPACE, false)
			boost_held = false
			boost_used = true
		if not reel_used and not reel_held and int(state.get("center_hits", 0)) > 0 and float(state.get("tension", 0.0)) > 0.26:
			_send_key(KEY_SHIFT, true)
			reel_held = true
			reel_started = float(state.get("elapsed", 0.0))
		elif reel_held and float(state.get("elapsed", 0.0)) - reel_started >= 0.20:
			_send_key(KEY_SHIFT, false)
			reel_held = false
			reel_used = true
		await get_tree().physics_frame
		frame_count += 1
	if held_key != 0: _send_key(held_key, false)
	if boost_held: _send_key(KEY_SPACE, false)
	if reel_held: _send_key(KEY_SHIFT, false)
	if label == "ordinary" and not captured_gust:
		_fail("The real " + label + " input route ended without a rendered natural gust sample: " + str(live.kite_model.snapshot()))
		return false
	var after_state: Dictionary = _ordinary_model_state if label == "ordinary" and not _ordinary_result.is_empty() else live.kite_model.snapshot()
	if int(after_state.get("center_hits", 0)) < desired_centers:
		_fail("Actual keyboard inputs did not reach the requested center ring(s): start=%s end=%s frames=%d" % [str(initial_state), str(after_state), frame_count])
		return false
	if label == "ordinary" and (not bool(_ordinary_result.get("success", false)) or int(after_state.get("nextRing", -1)) != 5):
		_fail("The ordinary keyboard route did not naturally finish five rings: " + str(after_state))
		return false
	if label == "ordinary" and not (boost_used and boost_observed and reel_used and reel_observed):
		_fail("The ordinary Main route did not exercise and observe actual boost and reel inputs")
		return false
	if label.begins_with("practice") and live.ended:
		_fail("Private practice finished before the driver could inspect/retry/leave it")
		return false
	return true

func _retry_private_session(live: Control) -> bool:
	var before := _progress_state()
	if not await _click_session_button(live, "PauseButton", "pause private practice before retry"):
		return false
	if not live.paused:
		_fail("Real Pause button did not pause private practice")
		return false
	if not await _click_session_button(live, "RetryButton", "open retry confirmation"):
		return false
	var confirm := live.minigame_hud.find_child("ConfirmAction", true, false) as BaseButton
	if confirm == null:
		_fail("Retry confirmation has no ConfirmAction button")
		return false
	_retry_observed = false
	confirm.pressed.connect(_latch_retry_state.bind(live.get_instance_id()), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm, "confirm actual practice retry"):
		return false
	if not _retry_observed:
		_fail("ConfirmAction did not observe the synchronous practice reset")
		return false
	if not await _require_live_session(live, "checking confirmed private retry"):
		return false
	var state: Dictionary = live.kite_model.snapshot()
	# The pressed callback above proves the model was exactly reset synchronously.
	# Native pointer dispatch takes two process frames to return, so allow only
	# those naturally elapsed frames while still requiring a fresh, unscored run.
	var post_click_elapsed := float(state.get("elapsed", -1.0))
	var post_click_limit := 2.0 / 60.0 + 0.000001
	if int(state.get("nextRing", -1)) != 0 or int(state.get("center_hits", -1)) != 0 or int(state.get("edge_hits", -1)) != 0 or int(state.get("rescues_used", -1)) != 0 or int(state.get("misses", -1)) != 0 or int(state.get("mistakes", -1)) != 0 or post_click_elapsed < 0.0 or post_click_elapsed > post_click_limit or float(state.get("time_left", -1.0)) < 60.0 - post_click_limit or live.score != 0 or not live.practice_mode or not live.assisted or not live.reduced_motion or live.paused or bool(state.get("ended", true)):
		_fail("Confirmed retry did not remain a fresh, unscored live run while retaining private/assist/reduced settings (elapsed limit %.6f): %s" % [post_click_limit, str(state)])
		return false
	if _progress_state() != before or _progress_state() != _progress_after_earned:
		_fail("Retry changed persistent progress before or after its confirmation")
		return false
	return true

func _leave_private_session(live: Control) -> bool:
	if not await _click_session_button(live, "PauseButton", "pause private practice before leave"):
		return false
	if not await _click_session_button(live, "LeaveButton", "open leave confirmation"):
		return false
	var confirm := live.minigame_hud.find_child("ConfirmAction", true, false) as BaseButton
	if confirm == null:
		_fail("Leave confirmation has no ConfirmAction button")
		return false
	_leave_observed = false
	live.cancelled.connect(_latch_leave.bind(live.get_instance_id()), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm, "confirm leaving private practice"):
		return false
	if not _leave_observed:
		_fail("ConfirmAction did not emit the real Session cancellation")
		return false
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "leave returns to the live park"):
		return false
	if _progress_state() != _progress_after_earned:
		_fail("Leaving private practice changed the earned collection state")
		return false
	return true

func _latch_ordinary_finish(result: Dictionary, session_id: int) -> void:
	if session_id != _ordinary_session_id:
		_fail("Finished signal came from a different Session identity")
		return
	_ordinary_finish_signals += 1
	if _ordinary_finish_signals != 1:
		_fail("The ordinary Kite Session emitted more than one finish signal")
		return
	_ordinary_result = result.duplicate(true)
	if not is_instance_id_valid(session_id):
		_fail("Main freed the ordinary Session before its synchronous finish callback")
		return
	var completed := instance_from_id(session_id) as Control
	if not is_instance_valid(completed):
		_fail("Could not safely snapshot the naturally completed Kite Session")
		return
	_ordinary_model_state = completed.kite_model.snapshot().duplicate(true)
	if int(_ordinary_model_state.get("nextRing", -1)) != 5 or int(_ordinary_model_state.get("center_hits", -1)) != 5 or int(_ordinary_model_state.get("edge_hits", -1)) != 0 or int(_ordinary_model_state.get("rescues_used", -1)) != 0 or int(completed.score) != 500:
		_fail("Finish latch observed a result inconsistent with five real center hits: %s" % str(_ordinary_model_state))

func _latch_retry_state(session_id: int) -> void:
	if not is_instance_id_valid(session_id): return
	var live := instance_from_id(session_id) as Control
	if not is_instance_valid(live) or not is_instance_valid(main) or main.session != live: return
	var state: Dictionary = live.kite_model.snapshot()
	_retry_observed = int(state.get("nextRing", -1)) == 0 and int(state.get("center_hits", -1)) == 0 and int(state.get("edge_hits", -1)) == 0 and int(state.get("rescues_used", -1)) == 0 and int(state.get("misses", -1)) == 0 and int(state.get("mistakes", -1)) == 0 and float(state.get("elapsed", -1.0)) == 0.0 and float(state.get("time_left", -1.0)) == 60.0 and float(state.get("reset_cooldown", -1.0)) == 0.0 and live.score == 0 and live.practice_mode and live.assisted and live.reduced_motion and not live.paused and not bool(state.get("ended", true))

func _latch_leave(session_id: int) -> void:
	_leave_observed = session_id == _practice_session_id

func _verify_earned_progress() -> bool:
	var ordinary_id := "photo-welcome-game-2"
	var devil_id := "photo-welcome-devil-2"
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has(ordinary_id) or not progress.photos.has(devil_id) or not progress.achievements.has(EXPECTED_ACHIEVEMENT):
		_fail("Real completed play did not persist exactly one normal/devil collection and game achievement")
		return false
	if int(_ordinary_model_state.get("nextRing", -1)) != 5 or int(_ordinary_model_state.get("center_hits", -1)) != 5 or int(_ordinary_model_state.get("edge_hits", -1)) != 0 or int(_ordinary_model_state.get("rescues_used", -1)) != 0 or int(_ordinary_result.get("score", -1)) != 500:
		_fail("Awarded Main result does not agree with the latched real model ledger")
		return false
	return true

func _capture_live_achievement() -> bool:
	if not await _activate_main_button("返回遊園", "return from the ordinary/devil result"):
		return false
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "return to park before opening achievements"):
		return false
	_key(KEY_M)
	if not await _wait_until(func() -> bool: return main.modal_kind == "ticket", "open the voyage pass"):
		return false
	if not await _activate_main_button("拍貼收藏本", "open the live Kite collection book"):
		return false
	if not await _wait_until(func() -> bool: return main.modal_kind == "album", "the live collection book opens"):
		return false
	# The live book displays one collection category at a time. Verify each real
	# rendered card in its own tab instead of requiring two mutually exclusive
	# category pages to be visible simultaneously.
	var normal_entry: Control = main.overlay.find_child("AlbumPhoto_photo-welcome-game-2", true, false) as Control
	if not await _verify_live_album_card(normal_entry, "風箏穿環", "ordinary"):
		return false
	if not await _scroll_control_into_view(normal_entry, "earned game-002 ordinary album card"):
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/ordinary-album.png"):
		_fail("Could not capture the live ordinary Kite collection card")
		return false
	var devil_tab := main.overlay.find_child("AlbumTab_devil", true, false) as BaseButton
	if devil_tab == null or not await _native_click_button(devil_tab, "switch the live collection book to devil photos"):
		if not _failure_latched: _fail("Live collection book is missing its devil category tab")
		return false
	await _frames(3)
	var devil_entry: Control = main.overlay.find_child("AlbumPhoto_photo-welcome-devil-2", true, false) as Control
	if not await _verify_live_album_card(devil_entry, "風箏穿環 · 小惡魔", "devil"):
		return false
	if not await _scroll_control_into_view(devil_entry, "earned game-002 devil album card"):
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/devil-album.png"):
		_fail("Could not capture the live devil Kite collection card")
		return false
	_key(KEY_ESCAPE)
	if not await _wait_until(func() -> bool: return main.modal_kind == "", "close the live Kite collection book"):
		return false
	_key(KEY_M)
	if not await _wait_until(func() -> bool: return main.modal_kind == "ticket", "reopen the voyage pass for achievements"):
		return false
	if not await _activate_main_button("遊園成就", "open the live achievement book"):
		return false
	if not await _wait_until(func() -> bool: return main.modal_kind == "achievements", "achievement book opens"):
		return false
	var stamp: Node = main.overlay.find_child("AchievementStamp_" + EXPECTED_ACHIEVEMENT, true, false)
	if stamp == null or not stamp.is_visible_in_tree():
		_fail("The live achievement book does not show the earned game-002 stamp")
		return false
	await RenderingServer.frame_post_draw
	if not main._capture(MAIN_REVIEW_DIR + "/earned-achievement.png"):
		_fail("Could not capture the actual earned achievement book")
		return false
	_key(KEY_ESCAPE)
	return await _wait_until(func() -> bool: return main.modal_kind == "", "close the live achievement book")

func _verify_live_album_card(card: Control, expected_title: String, category: String) -> bool:
	if card == null or not card.is_visible_in_tree():
		_fail("The live %s collection book does not show its earned game-002 card" % category)
		return false
	var saw_title := false
	var saw_collected := false
	for node in [card] + card.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null: continue
		var text := label.text.strip_edges()
		saw_title = saw_title or text == expected_title
		saw_collected = saw_collected or text == "已收藏"
	if not saw_title or not saw_collected:
		_fail("Live %s album card text mismatch: expected title '%s' and collected status; title=%s collected=%s" % [category, expected_title, str(saw_title), str(saw_collected)])
		return false
	return true

func _click_session_button(live: Control, name: String, context: String) -> bool:
	if not await _require_live_session(live, context): return false
	var button := live.minigame_hud.find_child(name, true, false) as BaseButton
	if button == null:
		_fail("Missing actual Session HUD control %s to %s" % [name, context])
		return false
	return await _native_click_button(button, context)

func _wait_for_result(context: String) -> bool:
	var deadline := _wall_deadline_ms(90000)
	while Time.get_ticks_msec() < deadline:
		if _failure_latched: return false
		if is_instance_valid(main) and main.modal_kind == "result" and not _ordinary_result.is_empty(): return true
		if not is_instance_valid(main):
			_fail("Main was released while waiting for " + context)
			return false
		await get_tree().physics_frame
	_fail("Timed out waiting for " + context + "; modal=%s result=%s" % [str(main.modal_kind) if is_instance_valid(main) else "released", str(_ordinary_result)])
	return false

func _wait_until(predicate: Callable, context: String = "real input transition") -> bool:
	var deadline := _wall_deadline_ms(10000)
	while Time.get_ticks_msec() < deadline:
		if _failure_latched: return false
		if not is_instance_valid(main) or main.is_queued_for_deletion():
			_fail("Main disappeared while waiting for " + context)
			return false
		if bool(predicate.call()): return true
		await get_tree().physics_frame
	if bool(predicate.call()): return true
	_fail("Timed out waiting for " + context + "; modal=%s" % str(main.modal_kind) if is_instance_valid(main) else "Main released")
	return false

func _require_park(context: String) -> bool:
	if not is_instance_valid(main) or not is_instance_valid(main.world) or not is_instance_valid(progress):
		_fail("Live Main park/Progress missing while " + context)
		return false
	return true

func _require_live_session(live: Control, context: String) -> bool:
	if is_instance_valid(main) and is_instance_valid(live) and not live.is_queued_for_deletion() and main.session == live:
		return true
	_fail("Live Kite Session disappeared while " + context)
	return false

func _require_live_session_id(session_id: int, context: String) -> bool:
	if not is_instance_valid(main) or not is_instance_valid(main.session) or main.session.get_instance_id() != session_id or main.session.is_queued_for_deletion():
		_fail("Session %d disappeared while %s" % [session_id, context])
		return false
	return true

func _progress_state() -> Dictionary:
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

func _send_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _wall_deadline_ms(scaled_milliseconds: int) -> int:
	return Time.get_ticks_msec() + ceili(float(scaled_milliseconds) / maxf(Engine.time_scale, 0.01))

func _fail(message: String) -> void:
	if _failure_latched:
		return
	_failure_latched = true
	_guard_active = false
	push_error("Native SG-17 Main flow: " + message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	get_tree().quit(1)
