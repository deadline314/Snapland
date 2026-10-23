extends "res://game/tests/native_fountain_review.gd"

var _result_snapshot: Dictionary = {}
var _ledger_snapshot: Array = []
var _result_session_id := -1
var _retry_evidence: Dictionary = {}
var _practice_retry_evidence: Dictionary = {}
var _pause_evidence: Dictionary = {}
var _pointer_down_events := 0
var _pointer_up_events := 0
var _formal_mid_captured := false
var _catch_sequence_captured := false
var _catch_sequence_tracking := false
var _catch_sequence_last_index := -1
var _catch_sequence_mask := 0
var _catch_sequence_count := 0
var _walk_capture_session_id := -1
var _walk_capture_enabled := false
var _walk_capture_failed := false
var _walk_left_mask := 0
var _walk_right_mask := 0
var _walk_capture_count := 0
var _moving_catch_seen := false
var _stationary_pose_mask := 0
var _stationary_pose_count := 0

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

## Native integration evidence only. Hat movement, catch timing, scoring, and
## completion come from real Main-routed input and HatRescueModel snapshots.
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native hat rescue review requires GPU and isolated SNAPLAND_SAVE_PATH")
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
	RenderingServer.frame_post_draw.connect(_observe_formal_walk_frame)
	await _frames(3)
	if not await _launch_hat(false): return
	if not await _review_stationary_reach(main.session.get_instance_id()): return
	if not await _launch_hat(false): return
	var formal_id: int = main.session.get_instance_id()
	main.session.finished.connect(_capture_result.bind(formal_id), CONNECT_ONE_SHOT)
	if not await _check_pause_resume_retry(formal_id): return
	_walk_capture_session_id = formal_id
	_walk_capture_enabled = true
	if not await _drive_six_hats(formal_id, true, "formal"): return
	_walk_capture_enabled = false
	if _walk_capture_failed or _walk_left_mask != 255 or _walk_right_mask != 255 or _walk_capture_count != 16:
		await _fail("Formal real movement did not render every cached walk pose in both directions: left_mask=%d right_mask=%d count=%d capture_failed=%s" % [_walk_left_mask, _walk_right_mask, _walk_capture_count, str(_walk_capture_failed)])
		return
	if not _moving_catch_seen:
		await _fail("Formal review never observed locomotion during a still-active model catch cue")
		return
	if _result_session_id != formal_id or main.modal_kind != "result" or not bool(_result_snapshot.get("success", false)) or not bool(_result_snapshot.get("devil", false)):
		await _fail("Six real keyboard rescues did not earn the formal ordinary/devil result: " + str(_result_snapshot))
		return
	var formal_model: Dictionary = _result_snapshot.get("model", {})
	if int(_result_snapshot.get("score", -1)) < 720 or _ledger_snapshot.size() != 6 or not _all_center_catches(_ledger_snapshot) or not bool(formal_model.get("devil", false)) or int(formal_model.get("center_catches", -1)) != 6 or int(formal_model.get("misses", -1)) != 0 or _ledger_points(_ledger_snapshot) != int(_result_snapshot.get("score", -2)):
		await _fail("Formal score/result did not match the six center-catch model ledger: " + str(_ledger_snapshot))
		return
	if progress.normal_count() != 1 or progress.devil_count("welcome") != 1 or not progress.photos.has("photo-welcome-game-5") or not progress.photos.has("photo-welcome-devil-5"):
		await _fail("Formal game-005 result did not persist exactly one ordinary and devil collection photo")
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(main) or not main._capture(".review/native-hat-rescue-formal-816.png"):
		await _fail("Could not capture the natural formal result")
		return
	if not await _activate_main_button("返回遊園", "return from formal game-005 result"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "formal result return to park"): return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	var saved_private_progress: Dictionary = _capture_private_progress(progress)
	if not await _launch_hat(true): return
	var practice_id: int = main.session.get_instance_id()
	if not await _enter_practice(practice_id): return
	_pointer_down_events = 0
	_pointer_up_events = 0
	var practice := _session_by_id(practice_id)
	if practice == null:
		await _fail("Practice session disappeared before pointer observation")
		return
	practice.presentation.gui_input.connect(_observe_pointer_event)
	_result_snapshot.clear()
	_ledger_snapshot.clear()
	_result_session_id = -1
	practice.finished.connect(_capture_result.bind(practice_id), CONNECT_ONE_SHOT)
	if not await _drive_six_hats(practice_id, false, "practice"): return
	if _result_session_id != practice_id or main.modal_kind != "result" or not bool(_result_snapshot.get("success", false)) or bool(_result_snapshot.get("devil", false)) or not bool(_result_snapshot.get("practice", false)) or not bool(_result_snapshot.get("assisted", false)):
		await _fail("Assisted/reduced-motion pointer practice did not reach its natural practice result: " + str(_result_snapshot))
		return
	var practice_model: Dictionary = _result_snapshot.get("model", {})
	if not bool(practice_model.get("success", false)) or bool(practice_model.get("devil", true)) or int(practice_model.get("caught", -1)) != 6 or int(practice_model.get("center_catches", -1)) != 6 or int(practice_model.get("misses", -1)) != 0 or _ledger_snapshot.size() != 6 or not _all_center_catches(_ledger_snapshot) or _ledger_points(_ledger_snapshot) != int(_result_snapshot.get("score", -2)) or int(practice_model.get("score", -1)) != int(_result_snapshot.get("score", -2)):
		await _fail("Practice result, score and six center catches did not agree with its own model ledger: " + str(practice_model) + " ledger=" + str(_ledger_snapshot))
		return
	if _pointer_down_events < 6 or _pointer_up_events < 6:
		await _fail("Pointer practice did not deliver both press and release events through the STOP game surface: down=%d up=%d" % [_pointer_down_events, _pointer_up_events])
		return
	var current_private_progress: Dictionary = _capture_private_progress(progress)
	if current_private_progress != saved_private_progress:
		await _fail("Practice changed private progress after settings were configured: before=" + str(saved_private_progress) + " after=" + str(current_private_progress))
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(main) or not main._capture(".review/native-hat-rescue-practice.png"):
		await _fail("Could not capture the assisted pointer practice result")
		return
	print("PASS: game-005 Main launch, pause/resume, confirmed retry reset, six keyboard-timed rescues, then six assisted reduced-motion pointer catches in non-collecting practice")
	await main._quit_game()

func _observe_formal_walk_frame() -> void:
	if (not _walk_capture_enabled and _moving_catch_seen) or _walk_capture_failed or not is_instance_valid(main):
		return
	var session := _session_by_id(_walk_capture_session_id)
	if session == null:
		return
	var view: HatRescueView = session.presentation as HatRescueView
	if view!=null and not _moving_catch_seen:
		var state: Dictionary = session.hat_model.snapshot()
		if float(state.get("catch_pose",0.0))>0.0 and absf(float(state.player_velocity))>HatRescueView.STILL_SPEED and view.visible_walk_frame_index()>=0 and view.visible_catch_frame_index()==-1:
			_moving_catch_seen=true
			print("HAT_MOVING_CATCH_WALK movie_frame=%d model_elapsed=%.3f velocity=%.3f walk_index=%d"%[Engine.get_frames_drawn(),float(state.elapsed),float(state.player_velocity),view.visible_walk_frame_index()])
	if not _walk_capture_enabled:
		return
	if view == null or view.visible_catch_frame_index() >= 0:
		return
	var frame_index: int = view.visible_walk_frame_index()
	if frame_index < 0 or frame_index >= 8:
		return
	var velocity := float(view._snapshot.get("player_velocity", 0.0))
	var moving_left := velocity < 0.0
	var bit := 1 << frame_index
	var mask := _walk_left_mask if moving_left else _walk_right_mask
	if (mask & bit) != 0:
		return
	var direction := "left" if moving_left else "right"
	if not main._capture(".review/native-hat-rescue-walk-%s-%02d.png" % [direction, frame_index]):
		_walk_capture_failed = true
		push_error("Could not capture actual post-draw %s walk frame %d" % [direction, frame_index])
		return
	if moving_left:
		_walk_left_mask |= bit
	else:
		_walk_right_mask |= bit
	_walk_capture_count += 1
	print("HAT_WALK_POST_DRAW direction=%s index=%d movie_frame=%d left_mask=%d right_mask=%d count=%d" % [direction, frame_index, Engine.get_frames_drawn(), _walk_left_mask, _walk_right_mask, _walk_capture_count])
	if _walk_left_mask == 255 and _walk_right_mask == 255:
		_walk_capture_enabled = false
		print("HAT_WALK_SEQUENCE_PASS movie_frame=%d directions=left,right frames=0..7" % Engine.get_frames_drawn())

func _capture_private_progress(value: Node) -> Dictionary:
	var fields := ["photos", "achievements", "quests", "visited", "settings", "appearance", "equipped", "owned_clothes", "coins", "wardrobe_rewarded_games", "platform_pending_achievements", "intro_seen", "tutorial_seen_games"]
	var available: Dictionary = {}
	for property in value.get_property_list(): available[str(property.get("name", ""))] = true
	var required := ["photos", "achievements", "quests", "visited", "settings", "appearance", "equipped", "owned_clothes", "coins", "wardrobe_rewarded_games", "platform_pending_achievements", "intro_seen"]
	var snapshot: Dictionary = {}
	for field in fields:
		if not available.has(field):
			if field in required:
				push_error("Progress is missing required isolation field: " + field)
				get_tree().quit(1)
			continue
		var field_value: Variant = value.get(field)
		snapshot[field] = field_value.duplicate(true) if field_value is Array or field_value is Dictionary else field_value
	return snapshot

func _launch_hat(expect_assisted: bool) -> bool:
	var found := false
	for point in main.world.points:
		if point.id != "game-005": continue
		main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		found = true
		break
	if not found:
		await _fail("Hat rescue station game-005 is missing from the live park")
		return false
	var deadline := _wall_deadline_ms(3500)
	while main.world.nearest.get("id", "") != "game-005" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not is_instance_valid(main): return false
	if main.world.nearest.get("id", "") != "game-005":
		await _fail("Game-005 did not become the live nearest station")
		return false
	_key(KEY_E)
	deadline = _wall_deadline_ms(3000)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not is_instance_valid(main): return false
	if main.modal_kind != "game_info":
		await _fail("Native E input did not open game-005 station details")
		return false
	if not await _activate_main_button("開始遊玩", "start hat rescue game-005"): return false
	deadline = _wall_deadline_ms(3000)
	while main.session == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not is_instance_valid(main): return false
	if main.session == null or main.session.game_id != "game-005":
		await _fail("Start did not create the real game-005 session")
		return false
	if bool(main.session.assisted) != expect_assisted or bool(main.session.reduced_motion) != expect_assisted:
		await _fail("Hat rescue settings were not applied: assist=%s reduced=%s" % [str(main.session.assisted), str(main.session.reduced_motion)])
		return false
	return true

func _check_pause_resume_retry(session_id: int) -> bool:
	var session := _session_by_id(session_id)
	if session == null: return false
	if not await _wait_until(func() -> bool: return _hat_elapsed(session_id) >= 0.15, "hat model live frames"): return false
	session = _session_by_id(session_id)
	if session == null: return false
	var pause_button: Button = session.minigame_hud.find_child("PauseButton", true, false)
	_pause_evidence.clear()
	pause_button.pressed.connect(_capture_pause_state.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(pause_button, "pause game-005"): return false
	session = _session_by_id(session_id)
	if session == null: await _fail("Session disappeared after pause"); return false
	if not bool(_pause_evidence.get("paused", false)) or int(_pause_evidence.get("session_id", -1)) != session_id or not session.paused:
		await _fail("Pause button callback did not latch the live model clock after the session pause handler")
		return false
	var elapsed_before: float = float(_pause_evidence.get("elapsed", -1.0))
	var revision_before: int = int(_pause_evidence.get("revision", -1))
	for _frame in 4: await get_tree().physics_frame
	session = _session_by_id(session_id)
	if session == null or float(session.hat_model.snapshot().elapsed) != elapsed_before or int(session.hat_model.snapshot().revision) != revision_before:
		await _fail("Paused hat physics continued to advance after the post-pressed clock latch: before=%s after=%s" % [str(_pause_evidence), str(session.hat_model.snapshot() if session != null else {})])
		return false
	var resume_button: Button = session.minigame_hud.find_child("ResumeButton", true, false)
	if not await _native_click_button(resume_button, "resume game-005"): return false
	session = _session_by_id(session_id)
	if session == null: await _fail("Session disappeared after resume"); return false
	if not is_instance_valid(session) or session.paused: await _fail("Resume did not restore the live hat session"); return false
	if not await _wait_until(func() -> bool: return _hat_elapsed(session_id) > elapsed_before, "resumed hat model clock"): return false
	session = _session_by_id(session_id)
	if session == null: return false
	pause_button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "pause before game-005 retry"): return false
	session = _session_by_id(session_id)
	if session == null: return false
	var retry_button: Button = session.minigame_hud.find_child("RetryButton", true, false)
	if not await _native_click_button(retry_button, "open game-005 retry confirmation"): return false
	session = _session_by_id(session_id)
	if session == null: return false
	var confirm_button: Button = session.minigame_hud.find_child("ConfirmAction", true, false)
	if confirm_button == null or not confirm_button.is_visible_in_tree(): await _fail("Retry did not open its confirmation dialog"); return false
	_retry_evidence.clear()
	confirm_button.pressed.connect(_capture_retry_state.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm_button, "confirm synchronous game-005 retry"): return false
	session = _session_by_id(session_id)
	if session == null: await _fail("Retry unexpectedly freed the continuing game session"); return false
	if int(_retry_evidence.get("session_id", -1)) != session_id or float(_retry_evidence.get("elapsed", -1.0)) != 0.0 or int(_retry_evidence.get("score", -1)) != 0 or int(_retry_evidence.get("caught", -1)) != 0 or int(_retry_evidence.get("misses", -1)) != 0 or bool(_retry_evidence.get("paused", true)) or bool(_retry_evidence.get("ended", true)) or bool(_retry_evidence.get("practice", true)) or not _retry_evidence.get("events", [1]).is_empty() or not bool(_retry_evidence.get("hats_waiting", false)):
		await _fail("ConfirmAction signal did not observe a complete synchronous hat model reset: " + str(_retry_evidence))
		return false
	var current: Dictionary = session.hat_model.snapshot()
	if not is_finite(float(current.elapsed)) or float(current.elapsed) < 0.0 or float(current.elapsed) > 0.5 or session.score != 0 or session.mistakes != 0 or not session.score_events.is_empty() or session.ended or session.paused:
		await _fail("Confirmed retry did not leave the same active session clean and advancing: " + str(current))
		return false
	_catch_sequence_captured = false
	_catch_sequence_tracking = false
	_catch_sequence_last_index = -1
	_catch_sequence_mask = 0
	_catch_sequence_count = 0
	return true

func _enter_practice(session_id: int) -> bool:
	var session := _session_by_id(session_id)
	if session == null: return false
	var pause_button: Button = session.minigame_hud.find_child("PauseButton", true, false)
	if not await _native_click_button(pause_button, "pause before game-005 practice"): return false
	session = _session_by_id(session_id)
	if session == null: return false
	var practice_button: Button = session.minigame_hud.find_child("PracticeButton", true, false)
	_practice_retry_evidence.clear()
	practice_button.pressed.connect(_capture_practice_reset.bind(session_id), CONNECT_ONE_SHOT)
	if not await _native_click_button(practice_button, "restart as game-005 practice"): return false
	session = _session_by_id(session_id)
	if session == null or not bool(_practice_retry_evidence.get("exact_reset", false)) or not session.practice_mode or session.paused or session.score != 0 or not is_finite(float(session.hat_model.snapshot().elapsed)) or float(session.hat_model.snapshot().elapsed) > 0.5:
		await _fail("Practice action did not reset a clean active hat round")
		return false
	return true

func _drive_six_hats(session_id: int, keyboard: bool, label: String) -> bool:
	var result_deadline := _wall_deadline_ms(35000)
	var held_direction := 0
	var last_axis_report_ms := 0
	while _result_snapshot.is_empty() and Time.get_ticks_msec() < result_deadline:
		await get_tree().physics_frame
		if _result_session_id == session_id and not _result_snapshot.is_empty(): break
		var session := _session_by_id(session_id)
		if session == null:
			await _fail("The actual game-005 session was freed before the finished result signal")
			return false
		var state: Dictionary = session.hat_model.snapshot()
		var target_x := float(state.next_spawn_x)
		var active_index := -1
		for index in state.hats.size():
			var hat: Dictionary = state.hats[index]
			if bool(hat.active) and not bool(hat.resolved):
				target_x = float(hat.landing_x)
				active_index = index
				break
		if keyboard:
			var velocity := float(state.player_velocity)
			var distance: float = target_x - float(state.player_x)
			var braking_distance: float = velocity * velocity / (2.0 * session.hat_model.PLAYER_ACCEL) + 24.0
			var direction := 0
			if absf(velocity) > 24.0 and signf(distance) == signf(velocity) and absf(distance) <= braking_distance:
				direction = -int(signf(velocity))
			elif absf(distance) > 18.0:
				direction = int(signf(distance))
			if direction != held_direction:
				if held_direction != 0: _held_key(KEY_RIGHT if held_direction > 0 else KEY_LEFT, false)
				if direction != 0: _held_key(KEY_RIGHT if direction > 0 else KEY_LEFT, true)
				print("HAT_KEY_STATE session=%d hat=%d requested=%d model_axis_before=%+.0f engine_pressed_left=%s engine_pressed_right=%s elapsed=%.3f" % [session_id, active_index, direction, float(session.hat_model.axis), str(Input.is_key_pressed(KEY_LEFT)), str(Input.is_key_pressed(KEY_RIGHT)), float(state.elapsed)])
				held_direction = direction
			var now_ms := Time.get_ticks_msec()
			if now_ms - last_axis_report_ms >= 250:
				print("HAT_AXIS_SAMPLE session=%d hat=%d held=%d model_axis=%+.0f engine_pressed_left=%s engine_pressed_right=%s elapsed=%.3f" % [session_id, active_index, held_direction, float(session.hat_model.axis), str(Input.is_key_pressed(KEY_LEFT)), str(Input.is_key_pressed(KEY_RIGHT)), float(state.elapsed)])
				last_axis_report_ms = now_ms
		else:
			var point := _hat_viewport_point(session, Vector2(target_x, 540.0))
			_motion(point)
		if active_index >= 0:
			var active_hat: Dictionary = state.hats[active_index]
			if float(active_hat.eta) <= 0.30 and float(state.catch_window) <= 0.0:
				if keyboard:
					_key(KEY_SPACE)
				else:
					_click(_hat_viewport_point(session, Vector2(target_x, 540.0)))
		if label == "formal" and int(state.caught) == 2 and not _formal_mid_captured:
			await RenderingServer.frame_post_draw
			if not is_instance_valid(main) or not main._capture(".review/native-hat-rescue-formal-mid.png"):
				await _fail("Could not capture the live keyboard round")
				return false
			_formal_mid_captured = true
	if held_direction != 0: _held_key(KEY_RIGHT if held_direction > 0 else KEY_LEFT, false)
	if _result_session_id != session_id or _result_snapshot.is_empty():
		await _fail("Six input-driven hats did not reach a natural result before deadline")
		return false
	if label == "formal" and (_stationary_pose_mask!=4095 or _stationary_pose_count!=12):
		await _fail("The separate stationary source rehearsal did not retain twelve verified frames")
		return false
	return true

func _review_stationary_reach(session_id: int) -> bool:
	# Separate harmless input rehearsal: a planted gesture must be reviewed
	# while stationary, rather than withholding movement during a scored run.
	var saved: Dictionary = _capture_private_progress(progress)
	var session := _session_by_id(session_id)
	if session==null:return false
	var initial_x: float = session.hat_model.player_x
	_key(KEY_SPACE)
	var deadline := _wall_deadline_ms(3000)
	while not _catch_sequence_captured and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		session=_session_by_id(session_id)
		if session==null:return false
		if absf(float(session.hat_model.player_x)-initial_x)>0.001:
			await _fail("Stationary source rehearsal moved its actual model root")
			return false
		if not await _capture_formal_catch_frame(session_id):return false
	if not _catch_sequence_captured:
		await _fail("Stationary real Space input did not display all twelve planted reach frames")
		return false
	_stationary_pose_mask=_catch_sequence_mask
	_stationary_pose_count=_catch_sequence_count
	if not await _wait_until(func() -> bool: return session.presentation.visible_catch_frame_index()<0,"complete stationary reach recovery"):return false
	if not await _native_click_button(session.minigame_hud.find_child("PauseButton",true,false),"leave stationary source rehearsal"):return false
	if not await _native_click_button(session.minigame_hud.find_child("LeaveButton",true,false),"request rehearsal exit"):return false
	if not await _native_click_button(session.minigame_hud.find_child("ConfirmAction",true,false),"confirm rehearsal exit"):return false
	if not await _wait_until(func() -> bool:return main.session==null and main.modal_kind=="","stationary rehearsal returns to park"):return false
	if _capture_private_progress(progress)!=saved:
		await _fail("Cancelled stationary rehearsal changed private collection or progress")
		return false
	print("PASS: separate stationary twelve-frame input rehearsal; no collection/progress change")
	return true

func _capture_formal_catch_frame(session_id: int) -> bool:
	var session := _session_by_id(session_id)
	if session == null:
		await _fail("Formal session vanished while observing the live catch animation")
		return false
	var catch_view: HatRescueView = session.presentation as HatRescueView
	if catch_view == null:
		await _fail("Formal presentation is not the live HatRescueView")
		return false
	var action_index: int = catch_view.visible_catch_frame_index()
	if action_index < 0:
		_catch_sequence_tracking = false
		_catch_sequence_last_index = -1
		_catch_sequence_mask = 0
		_catch_sequence_count = 0
		return true
	if action_index >= 12:
		await _fail("Hat catch view exposed out-of-range authored frame index %d" % action_index)
		return false
	if action_index == 0 and (not _catch_sequence_tracking or _catch_sequence_last_index > 0):
		_catch_sequence_tracking = true
		_catch_sequence_last_index = -1
		_catch_sequence_mask = 0
		_catch_sequence_count = 0
	if not _catch_sequence_tracking:
		return true
	if _catch_sequence_last_index >= 0 and action_index > _catch_sequence_last_index + 1:
		# A skipped display pose means this attempt cannot be represented as a
		# full observed sequence. Wait for the next real frame-0 event.
		_catch_sequence_tracking = false
		_catch_sequence_last_index = -1
		_catch_sequence_mask = 0
		_catch_sequence_count = 0
		return true
	if action_index < _catch_sequence_last_index:
		_catch_sequence_tracking = false
		_catch_sequence_last_index = -1
		_catch_sequence_mask = 0
		_catch_sequence_count = 0
		return true
	var bit := 1 << action_index
	if (_catch_sequence_mask & bit) != 0:
		return true
	await RenderingServer.frame_post_draw
	if not is_instance_valid(main):
		await _fail("Main vanished before the live catch pose could be captured")
		return false
	session = _session_by_id(session_id)
	if session == null:
		await _fail("Formal session ended before the live catch pose could be captured")
		return false
	catch_view = session.presentation as HatRescueView
	if catch_view == null or catch_view.visible_catch_frame_index() != action_index:
		return true
	if not main._capture(".review/native-hat-rescue-catch-pose-%02d.png" % action_index):
		await _fail("Could not capture actual live authored catch pose index %d" % action_index)
		return false
	_catch_sequence_mask |= bit
	_catch_sequence_count += 1
	_catch_sequence_last_index = action_index
	var movie_frame := Engine.get_frames_drawn()
	var model_elapsed := float(session.hat_model.snapshot().elapsed)
	print("HAT_CATCH_POSE index=%d movie_frame=%d model_elapsed=%.3f mask=%d count=%d" % [action_index, movie_frame, model_elapsed, _catch_sequence_mask, _catch_sequence_count])
	if _catch_sequence_mask == 4095 and _catch_sequence_count == 12:
		_catch_sequence_captured = true
		print("HAT_CATCH_SEQUENCE_PASS movie_frame=%d elapsed=%.3f indices=0..11" % [movie_frame, model_elapsed])
	return true

## Hang guards only: a fixed-FPS (or Movie Maker) run on a loaded host renders far slower
## than real time, so wall-clock limits are stretched there (unchanged otherwise).
func _wall_deadline_ms(simulated_milliseconds: int) -> int:
	var fixed_clock := not Engine.get_write_movie_path().is_empty() or OS.get_cmdline_args().has("--fixed-fps")
	var slack := 40.0 if fixed_clock else 1.0
	return Time.get_ticks_msec() + ceili(float(simulated_milliseconds) * slack / maxf(Engine.time_scale, 0.01))

func _hat_viewport_point(session: Control, design_point: Vector2) -> Vector2:
	var canvas_point: Vector2 = session.presentation.get_global_transform_with_canvas() * design_point
	return get_viewport().get_final_transform() * canvas_point

func _capture_result(result: Dictionary, session_id: int) -> void:
	# Main's earlier finished listener clears/queues the Session. The signal is
	# synchronous; its node/model remains readable until all listeners return.
	var session := _session_for_finish_id(session_id)
	if session == null:
		push_error("Native Hat review: Session vanished before synchronous finish capture")
		get_tree().quit(1)
		return
	var saved_result: Dictionary = result.duplicate(true)
	var model_state: Dictionary = session.hat_model.snapshot().duplicate(true)
	var saved_ledger: Array = model_state.ledger.duplicate(true)
	saved_result["model"] = model_state
	_result_snapshot = saved_result
	_ledger_snapshot = saved_ledger
	_result_session_id = session_id

func _capture_retry_state(session_id: int) -> void:
	var session := _session_by_id(session_id)
	if session == null or not is_instance_valid(main) or main.session != session: return
	var state: Dictionary = session.hat_model.snapshot()
	_retry_evidence = {
		"session_id": session_id,
		"elapsed": state.elapsed,
		"score": session.score,
		"caught": state.caught,
		"misses": state.misses,
		"paused": session.paused,
		"ended": session.ended,
		"practice": session.practice_mode,
		"events": session.score_events.duplicate(true),
		"hats_waiting": _hats_waiting(state.hats) and _ledger_waiting(state.ledger),
	}

func _capture_practice_reset(session_id: int) -> void:
	var session := _session_by_id(session_id)
	if session == null or not is_instance_valid(main) or main.session != session: return
	var state: Dictionary = session.hat_model.snapshot()
	_practice_retry_evidence = {
		"exact_reset": float(state.elapsed) == 0.0 and int(state.caught) == 0 and int(state.misses) == 0 and int(session.score) == 0 and _ledger_waiting(state.ledger) and _hats_waiting(state.hats) and session.score_events.is_empty() and session.practice_mode and not session.paused and not session.ended,
		"elapsed": state.elapsed,
	}

func _capture_pause_state(session_id: int) -> void:
	var session := _session_by_id(session_id)
	if session == null: return
	var state: Dictionary = session.hat_model.snapshot()
	_pause_evidence = {
		"session_id": session_id,
		"elapsed": float(state.elapsed),
		"revision": int(state.revision),
		"paused": session.paused,
	}

func _session_by_id(session_id: int) -> Control:
	if session_id<=0 or not is_instance_id_valid(session_id):return null
	var instance: Object = instance_from_id(session_id)
	if instance is Control and is_instance_valid(instance) and is_instance_valid(main) and main.session == instance:
		return instance as Control
	return null

func _session_for_finish_id(session_id: int) -> Control:
	if not is_instance_id_valid(session_id): return null
	var instance: Object = instance_from_id(session_id)
	return instance as Control if instance is Control and is_instance_valid(instance) else null

func _hat_elapsed(session_id: int) -> float:
	var session := _session_by_id(session_id)
	return float(session.hat_model.snapshot().elapsed) if session != null else -1.0

func _hats_waiting(hats: Array) -> bool:
	if hats.size() != 6: return false
	for hat in hats:
		if bool(hat.get("active", true)) or bool(hat.get("resolved", true)): return false
	return true

func _ledger_waiting(ledger: Array) -> bool:
	if ledger.size() != 6: return false
	for entry in ledger:
		if str(entry.get("status", "")) != "waiting" or int(entry.get("points", -1)) != 0 or float(entry.get("contact_time", -1.0)) != 0.0: return false
	return true

func _all_center_catches(ledger: Array) -> bool:
	if ledger.size() != 6: return false
	for entry in ledger:
		if str(entry.get("status", "")) != "center" or str(entry.get("grade", "")) != "中心" or int(entry.get("points", 0)) < 120: return false
	return true

func _ledger_points(ledger: Array) -> int:
	var points := 0
	for entry in ledger:
		points += int(entry.get("points", 0))
	return points

func _observe_pointer_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_pointer_down_events += 1
		else:
			_pointer_up_events += 1
