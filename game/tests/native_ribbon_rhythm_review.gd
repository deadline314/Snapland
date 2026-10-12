extends "res://game/tests/native_review.gd"

const Model := preload("res://game/minigames/ribbon_rhythm_model.gd")
var _finish_latch: Dictionary = {}
var _finished_session_id := 0
var _retry_latch: Dictionary = {}
var _review_deadline := 0
var _failure_latched := false
var _formal_engine_scale := 1.0

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
	if _review_deadline > 0 and Time.get_ticks_msec() >= _review_deadline and not _failure_latched:
		_review_deadline = 0
		call_deferred("_fail", "Native Ribbon Rhythm review exceeded its finite 180-second watchdog")

func _run() -> void:
	_formal_engine_scale = Engine.time_scale
	_review_deadline = _wall_deadline(180.0)
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		await _fail("Native Ribbon Rhythm review requires windowed rendering and isolated SNAPLAND_SAVE_PATH"); return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null: await _fail("Progress autoload is missing"); return
	progress.reset_progress(); progress.intro_seen = true
	progress.settings["assist"] = false; progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null: get_tree().quit(1); return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _launch_station(false, false): return
	var formal: Control = main.session
	var formal_id := formal.get_instance_id()
	formal.finished.connect(_capture_finish.bind(formal_id), CONNECT_ONE_SHOT)
	if not is_instance_valid(formal.presentation) or not formal.presentation.avatar_assets_ready():
		await _fail("Ribbon Session did not load its authored full-body avatar actions"); return
	var before_formal := _private_progress()
	if not await _wrong_press_pause_retry(formal, formal_id, before_formal): return
	if not await _play_phrase(formal_id, false): return
	if _finished_session_id != formal_id or _finish_latch.is_empty(): await _fail("Formal result was not synchronously latched for its matching Session"); return
	var formal_result: Dictionary = _finish_latch.result
	var formal_state: Dictionary = _finish_latch.snapshot
	if not bool(formal_result.success) or not bool(formal_result.devil) or bool(formal_result.assisted) or int(formal_result.score) != 900 or int(formal_state.precise_count) != 8 or int(formal_state.error_count) != 0 or formal_state.ribbon_trail.size() != 8:
		await _fail("Formal keyboard phrase did not produce the eight-gesture exact devil ledger: %s" % str(_finish_latch)); return
	if not progress.photos.has("photo-welcome-game-6") or not progress.photos.has("photo-welcome-devil-6"):
		await _fail("Formal Main result did not persist its real ordinary/devil collection entries"); return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-ribbon-formal-result.png"): await _fail("Could not capture formal Ribbon result"); return
	print("PASS: Main park station/menu, wrong-action retry, keyboard eight gestures/two holds, exact devil score ledger and ordinary/devil persistence; formal Engine.time_scale=%.2fx" % _formal_engine_scale)
	if not await _activate_button("返回遊園", "return to park after formal Ribbon"): return
	var private_before := _private_progress()
	progress.settings["assist"] = true; progress.settings["reduced_motion"] = true
	Engine.time_scale = 0.25
	var practice_engine_scale := Engine.time_scale
	if not await _launch_station(true, true): return
	var practice: Control = main.session
	var practice_id := practice.get_instance_id()
	_finish_latch = {}; _finished_session_id = 0
	practice.finished.connect(_capture_finish.bind(practice_id), CONNECT_ONE_SHOT)
	practice.set_process(true)
	if not practice.assisted or not practice.practice_mode or not practice.reduced_motion or practice.presentation.visual_motion_enabled():
		await _fail("Assisted reduced-motion practice settings did not reach the live Session/view"); return
	if not await _play_phrase(practice_id, true): return
	Engine.time_scale = 1.0
	var result_capture_engine_scale := Engine.time_scale
	if _finished_session_id != practice_id or _finish_latch.is_empty(): await _fail("Assisted pointer result was not synchronously latched"); return
	var practice_result: Dictionary = _finish_latch.result
	var practice_state: Dictionary = _finish_latch.snapshot
	if not bool(practice_result.success) or bool(practice_result.devil) or not bool(practice_result.assisted) or not bool(practice_result.practice) or int(practice_state.correct_count) != 8 or int(practice_state.error_count) != 0 or int(practice_result.score) != 900:
		await _fail("Assisted pointer route should be an ordinary eight-action private result: %s" % str(_finish_latch)); return
	if _private_progress() != private_before: await _fail("Private assisted practice changed collection, achievement, quest, coin or wardrobe data"); return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-ribbon-assisted-result.png"): await _fail("Could not capture assisted reduced-motion result"); return
	print("PASS: assisted reduced-motion station launch and pointer gameplay at Engine.time_scale=%.2fx; pointer phrase required all eight player inputs; result capture at %.2fx; ordinary-only private result and unchanged Progress" % [practice_engine_scale, result_capture_engine_scale])
	Engine.time_scale = 1.0
	await main._quit_game()

func _launch_station(assist: bool, practice: bool) -> bool:
	for point in main.world.points:
		if point.id == "game-006": main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
	var deadline := _wall_deadline(4.0)
	while main.world.nearest.get("id", "") != "game-006" and Time.get_ticks_msec() < deadline: await get_tree().physics_frame
	if main.world.nearest.get("id", "") != "game-006": await _fail("Ribbon station did not become the nearest park interaction"); return false
	_key(KEY_E)
	deadline = _wall_deadline(3.0)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if main.modal_kind != "game_info": await _fail("E did not open the real Ribbon station menu"); return false
	if assist: progress.settings["assist"] = true
	if not await _activate_button("練習操作" if practice else "開始遊玩", "launch game-006 from station menu"): return false
	deadline = _wall_deadline(3.0)
	while main.session == null and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if main.session == null or main.session.game_id != "game-006" or main.session.mode != "ribbon_rhythm": await _fail("Station menu did not launch RibbonRhythm Session"); return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-ribbon-%s-gameplay.png" % ("assisted" if assist else "formal")): await _fail("Could not capture live Ribbon gameplay"); return false
	return true

func _wrong_press_pause_retry(session: Control, sid: int, progress_before: Dictionary) -> bool:
	if not await _wait_ribbon_elapsed(sid, 1.02): return false
	_send_key(KEY_RIGHT, true); _send_key(KEY_RIGHT, false)
	if not await _require_live(sid): return false
	if int(session.ribbon_model.snapshot().error_count) != 1 or int(session.ribbon_model.snapshot().gesture_index) != 0 or int(session.ribbon_model.snapshot().correct_count) != 0:
		await _fail("Wrong direction must be a real recorded error without advancing or auto-answering"); return false
	if not await _click_hud(session, "PauseButton", "pause after real wrong action"): return false
	if not await _require_live(sid) or not session.paused: await _fail("Pause button did not pause Ribbon Session"); return false
	var frozen := float(session.ribbon_model.snapshot().elapsed)
	await get_tree().physics_frame; await get_tree().physics_frame
	if float(session.ribbon_model.snapshot().elapsed) != frozen: await _fail("Ribbon cue clock advanced while paused"); return false
	# The confirmation control exists from HUD construction but stays hidden until
	# RetryButton opens the confirm overlay. Always follow the same visible UI path
	# as the other native fixtures instead of treating find_child as visibility.
	if not await _click_hud(session, "RetryButton", "open retry confirmation"): return false
	var confirm := session.minigame_hud.find_child("ConfirmAction", true, false) as BaseButton
	if confirm == null or not confirm.is_visible_in_tree(): await _fail("Retry confirmation action did not become visible"); return false
	_retry_latch = {}
	confirm.pressed.connect(_capture_retry.bind(sid, progress_before), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm, "confirm exact-zero Ribbon retry"): return false
	if not await _require_live(sid): return false
	if _retry_latch.is_empty() or not bool(_retry_latch.get("zero", false)): await _fail("Confirmed retry did not synchronously expose exact zero model/session/ledger state"); return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-ribbon-retry-zero.png"): await _fail("Could not capture exact-zero retry"); return false
	return true

func _play_phrase(sid: int, pointer: bool) -> bool:
	var gestures: Array = Model.GESTURES
	for index in gestures.size():
		if not await _wait_ribbon_elapsed(sid, Model.FIRST_BEAT_TIME + float(index) * Model.BEAT_INTERVAL): return false
		var live := _node_for_id(sid)
		if live == null: await _fail("Ribbon Session disappeared before gesture %d" % index); return false
		var state: Dictionary = live.ribbon_model.snapshot()
		if int(state.gesture_index) != index or str(state.current_gesture.get("action", "")) != str(gestures[index].action):
			await _fail("Visible cue does not match authored gesture %d: %s" % [index, str(state)]); return false
		await RenderingServer.frame_post_draw
		if not main._capture(".review/native-ribbon-%s-cue-%02d.png" % ["pointer" if pointer else "keyboard", index + 1]): await _fail("Could not capture gesture cue %d" % index); return false
		var action := str(gestures[index].action)
		if pointer:
			if not await _pointer_action(sid, action, true): return false
		else:
			var keycode := KEY_LEFT if action == "left" else (KEY_RIGHT if action == "right" else KEY_SPACE)
			_send_key(keycode, true)
		# The final authored tap ends the Session during this real input dispatch.
		# Its finished handler copies scalars before Main queues Session deletion.
		if index == gestures.size() - 1 and (_finished_session_id != sid or _finish_latch.is_empty()):
			await _fail("Final gesture did not synchronously close and latch its matching Session on input")
			return false
		if float(gestures[index].hold) > 0.0:
			var release_at := Model.FIRST_BEAT_TIME + float(index) * Model.BEAT_INTERVAL + float(gestures[index].hold)
			if not await _wait_ribbon_elapsed(sid, release_at): return false
			if pointer:
				if not await _pointer_action(sid, action, false): return false
			else:
				var release_key := KEY_LEFT if action == "left" else KEY_RIGHT
				_send_key(release_key, false)
		else:
			if pointer:
				if not await _pointer_action(sid, action, false): return false
			else:
				var release_key := KEY_LEFT if action == "left" else (KEY_RIGHT if action == "right" else KEY_SPACE)
				_send_key(release_key, false)
		if not await _live_or_finished(sid): return false
	return await _wait_for_finish(sid)

func _wait_ribbon_elapsed(sid: int, target: float) -> bool:
	var live_at_start := _node_for_id(sid)
	var elapsed_at_start := float(live_at_start.ribbon_model.snapshot().elapsed) if live_at_start != null else target
	var game_budget := maxf(3.0, target - elapsed_at_start + 3.0)
	# Movie Maker renders well below real time on some GPUs. Preserve a finite
	# clock budget scaled by Engine.time_scale and add a bounded capture allowance.
	var capture_multiplier := 8.0 if not Engine.get_write_movie_path().is_empty() else 2.0
	var deadline := _wall_deadline(game_budget * capture_multiplier)
	var frame_budget := mini(216000, int(ceil(game_budget * 60.0 * capture_multiplier)))
	var waited_frames := 0
	while Time.get_ticks_msec() < deadline and waited_frames < frame_budget:
		var live := _node_for_id(sid)
		if live == null: return await _live_or_finished(sid)
		if float(live.ribbon_model.snapshot().elapsed) >= target: return true
		waited_frames += 1
		await get_tree().physics_frame
	var stalled := _node_for_id(sid)
	var diagnostic := {"target": target, "waited_frames": waited_frames, "frame_budget": frame_budget, "session_valid": stalled != null, "session_paused": stalled.paused if stalled != null else null, "session_ended": stalled.ended if stalled != null else null, "session_processing": stalled.is_processing() if stalled != null else null, "time_scale": Engine.time_scale, "snapshot": stalled.ribbon_model.snapshot().duplicate(true) if stalled != null else {}}
	await _fail("Ribbon model elapsed clock stalled: " + str(diagnostic)); return false

func _wait_for_finish(sid: int) -> bool:
	var deadline := _wall_deadline(5.0)
	while Time.get_ticks_msec() < deadline and _finished_session_id != sid:
		await get_tree().physics_frame
	return _finished_session_id == sid or await _live_or_finished(sid)

func _pointer_action(sid: int, action: String, down: bool) -> bool:
	var live := _node_for_id(sid)
	if live == null or not is_instance_valid(live.presentation): await _fail("Ribbon pointer action lost live View"); return false
	var view: Control = live.presentation
	var point: Vector2 = view.get_global_transform_with_canvas() * view.control_center(action)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion); Input.flush_buffered_events()
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.window_id = get_window().get_window_id(); event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()
	return await _live_or_finished(sid)

func _send_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

func _capture_retry(sid: int, progress_before: Dictionary) -> void:
	var live := _node_for_id(sid)
	if live == null or main.session != live: return
	var snapshot: Dictionary = live.ribbon_model.snapshot().duplicate(true)
	var zero: bool = float(snapshot.elapsed) == 0.0 and int(snapshot.gesture_index) == 0 and int(snapshot.score) == 0 and int(snapshot.error_count) == 0 and int(snapshot.note_played_serial) == 0 and snapshot.ribbon_trail.is_empty() and live.score == 0 and live.score_events.is_empty() and live._ribbon_note_cursor == 0 and live._ribbon_score_cursor == 0 and live._ribbon_error_cursor == 0 and not live.paused and not live.ended
	_retry_latch = {"zero":zero,"snapshot":snapshot,"session_score":live.score,"events":live.score_events.duplicate(true),"progress_unchanged":_private_progress() == progress_before}

func _capture_finish(result: Dictionary, sid: int) -> void:
	var live := _node_for_id(sid)
	if live == null or str(result.get("game_id", "")) != "game-006":
		call_deferred("_fail", "Ribbon finished signal did not match a live game-006 Session"); return
	_finish_latch = {"result":result.duplicate(true),"snapshot":live.ribbon_model.snapshot().duplicate(true),"session_score":live.score,"events":live.score_events.duplicate(true),"summary":live.score_summary().duplicate(true),"session_id":sid}
	_finished_session_id = sid

func _node_for_id(sid: int) -> Control:
	return instance_from_id(sid) as Control if is_instance_id_valid(sid) else null

func _require_live(sid: int) -> bool:
	var live := _node_for_id(sid)
	if not is_instance_valid(live) or live.is_queued_for_deletion() or main.session != live: await _fail("Ribbon Session %d disappeared before its expected result" % sid); return false
	return true

func _live_or_finished(sid: int) -> bool:
	if _finished_session_id == sid and not _finish_latch.is_empty(): return true
	return await _require_live(sid)

func _click_hud(session: Control, name: String, context: String) -> bool:
	var button := session.minigame_hud.find_child(name, true, false) as BaseButton
	if button == null: await _fail("Missing Ribbon HUD button " + name); return false
	return await _native_click_button(button, context)

func _activate_button(needle: String, context: String) -> bool:
	await get_tree().process_frame
	var button := _find(main.overlay, needle)
	if button == null: await _fail("Missing station menu button for " + context); return false
	return await _native_click_button(button, context)

func _find(node: Node, needle: String) -> Button:
	if node is Button and (node as Button).text.contains(needle): return node as Button
	for child in node.get_children():
		var result: Button = _find(child, needle)
		if result != null: return result
	return null

## Treat every budget as game-time seconds. Slow-motion practice gets a
## proportionally longer wall budget, bounded by a one-hour safety ceiling.
func _wall_deadline(game_seconds: float) -> int:
	var wall_ms := mini(3600000, int(ceil(game_seconds * 1000.0 / maxf(Engine.time_scale, 0.05))))
	return Time.get_ticks_msec() + wall_ms

func _private_progress() -> Dictionary:
	return {"photos":progress.photos.duplicate(true),"achievements":progress.achievements.duplicate(true),"quests":progress.quests.duplicate(true),"coins":progress.coins,"owned":progress.owned_clothes.duplicate(true),"equipped":progress.equipped.duplicate(true),"pending":progress.platform_pending_achievements.duplicate(true),"normal_count":progress.normal_count(),"devil_count":progress.devil_count()}

func _fail(message: String) -> void:
	if _failure_latched: return
	_failure_latched = true
	_review_deadline = 0
	push_error("Native RibbonRhythm review: " + message)
	if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
