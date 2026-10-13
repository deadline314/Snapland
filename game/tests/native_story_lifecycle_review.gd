extends "res://game/tests/native_bubble_photo_review.gd"

var _started_at_ms := 0
var _crowd_result: Dictionary = {}
var _crowd_session_id := 0
var _phase_failures := 0
var _crowd_finished := false
var _crowd_model_evidence: Dictionary = {}

func _ready() -> void:
	_started_at_ms = Time.get_ticks_msec()
	call_deferred("_run_story_review")

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
	if _started_at_ms > 0 and Time.get_ticks_msec() - _started_at_ms > 300000:
		_started_at_ms = 0
		push_error("Native ST-4 story review exceeded its 300-second wall-clock watchdog")
		get_tree().quit(1)

## GPU review only. Stations are reached by the same E/menu controls as play;
## the fixture teleports only the park player's position to each documented station.
## Game state, result, score, reward and mission cursor are never assigned directly.
func _run_story_review() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native ST-4 story review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = false
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	get_window().size = Vector2i(1280, 720)
	await _frames(3)
	main = _instantiate_main(false)
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	print("ST-4 PHASE: fresh arrival in anchored dialogue")
	if not await _wait_until(func() -> bool: return main.modal_kind == "dialogue", "fresh anchored arrival dialogue"): return
	if not await _capture_story("arrival-dialogue"): return
	if not await _complete_story_dialogue(): return
	if main.modal_kind != "":
		await _fail("Arrival dialogue did not naturally return to the park")
		return
	if not progress.intro_seen:
		await _fail("Natural arrival completion did not preserve intro progress")
		return

	print("ST-4 PHASE: quest-001 interaction and bench evidence")
	if not await _interact_at_station("quest-001", "quest"): return
	if int(progress.quests.get("quest-001", 0)) != 1:
		await _fail("Actual Xiao Jiao interaction did not advance quest-001 to step 1")
		return
	if not await _capture_story("quest001-step1"): return
	if not await _activate_main_button("返回遊園", "close quest-001 step 1"): return
	if not await _interact_at_station("explore-003", "explore"): return
	if not await _activate_main_button("借一個小角立牌", "borrow bench standee"): return
	if not await _activate_main_button("按下快門，留下合照", "take actual bench photo"): return
	if not await _wait_until(func() -> bool: return progress.photos.has("photo-welcome-explore-3") and int(progress.quests.get("quest-001", 0)) == 2, "real bench photo and quest-001 step 2"): return
	if not await _capture_story("quest001-step2"): return
	if main.modal_kind != "":
		await _fail("Bench shutter should return to the park without a modal")
		return

	print("ST-4 PHASE: game-010 real tutorial, keyboard captures and result")
	if not await _launch_main_game("game-010"): return
	var photo_session: Control = main.session
	photo_session.finished.connect(_capture_earned_result.bind(photo_session.get_instance_id()), CONNECT_ONE_SHOT)
	if not await _capture_three_photos(photo_session, "keyboard"): return
	if not await _wait_bubble_result(): return
	if not bool(_earned_result.get("success", false)) or bool(_earned_result.get("practice", true)):
		await _fail("game-010 did not emit a successful, non-practice result")
		return
	if int(progress.quests.get("quest-001", 0)) != 3 or not progress.photos.has("photo-welcome-quest-1") or not progress.photos.has("photo-welcome-game-10"):
		await _fail("Real game-010 result did not complete quest-001 and persist its ordinary photo/reward")
		return
	if not await _capture_story("game010-result-and-reward"): return
	if not await _activate_main_button("返回遊園", "return from game-010 result"): return
	if not await _interact_at_station("quest-001", "quest"): return
	if not _find_label_text(main.overlay, "今天的小麻煩"):
		await _fail("Reopened quest-001 ticket does not show its completed state")
		return
	if not await _capture_story("quest001-completed-reopened"): return
	if not await _activate_main_button("返回遊園", "close completed quest-001"): return
	if not await _save_reload_story_state(): return

	print("ST-4 PHASE: quest-002 inspection and game-004 natural win")
	if not await _interact_at_station("quest-002", "quest"): return
	if int(progress.quests.get("quest-002", 0)) != 1:
		await _fail("Actual Ah Lang interaction did not advance quest-002 to step 1")
		return
	if not await _capture_story("quest002-step1"): return
	if not await _activate_main_button("返回遊園", "close quest-002 step 1"): return
	if not await _interact_at_station("explore-002", "explore"): return
	var slider := _find_story_slider(main.modal_body)
	if slider == null:
		await _fail("Actual welcome-wall exploration did not expose its alignment slider")
		return
	if not await _mouse_align_story_slider(slider): return
	if absf(slider.value) > 15.0:
		await _fail("Actual mouse input did not align the welcome-wall projection; value=%s" % str(slider.value))
		return
	if not await _activate_main_button("按下快門，留下合照", "take aligned welcome-wall photo"): return
	if not await _wait_until(func() -> bool: return progress.photos.has("photo-welcome-explore-2") and int(progress.quests.get("quest-002", 0)) == 2, "real wall photo and quest-002 step 2"): return
	if not await _capture_story("quest002-step2"): return
	if main.modal_kind != "":
		await _fail("Wall shutter should return to the park without a modal")
		return
	if not await _launch_main_game("game-004"): return
	var crowd_session: Control = main.session
	_crowd_result.clear()
	_crowd_finished = false
	_crowd_model_evidence.clear()
	_crowd_session_id = crowd_session.get_instance_id()
	crowd_session.finished.connect(_latch_crowd_result.bind(_crowd_session_id), CONNECT_ONE_SHOT)
	if not await _run_crowd_with_real_inputs(_crowd_session_id): return
	if not bool(_crowd_result.get("success", false)) or bool(_crowd_result.get("practice", true)):
		await _fail("game-004 did not emit a successful, non-practice result")
		return
	if int(progress.quests.get("quest-002", 0)) != 3 or not progress.photos.has("photo-welcome-quest-2") or not progress.photos.has("photo-welcome-game-4"):
		await _fail("Real game-004 result did not complete quest-002 and persist its ordinary photo/reward")
		return
	if not await _capture_story("game004-result-and-reward"): return
	if not await _activate_main_button("返回遊園", "return from game-004 result"): return
	if not await _save_reload_story_state(): return
	if not await _interact_at_station("quest-002", "quest"): return
	if not _find_label_text(main.overlay, "今天的小麻煩"):
		await _fail("Reopened quest-002 ticket does not show its completed state")
		return
	if not await _capture_story("quest002-completed-reopened"): return
	print("PASS: native ST-4 arrival, both quests, real game-010/game-004 results, rewards and save reloads")
	await main._quit_game()

func _launch_main_game(game_id: String) -> bool:
	if not await _require_live_main("requesting " + game_id): return false
	var previous_id: int = main.session.get_instance_id() if is_instance_valid(main.session) else 0
	if not await _interact_at_station(game_id, "game_info"): return false
	if not await _activate_main_button("開始遊玩", "request " + game_id): return false
	var deadline := _wall_deadline_ms(12000)
	while Time.get_ticks_msec() < deadline:
		if not await _require_live_main("waiting for " + game_id + " first-entry tutorial"): return false
		if _fresh_story_session(game_id, previous_id) != null or is_instance_valid(main.tutorial_panel): break
		await get_tree().process_frame
	if is_instance_valid(main.tutorial_panel):
		deadline = _wall_deadline_ms(12000)
		while Time.get_ticks_msec() < deadline:
			if not await _require_live_main("waiting for " + game_id + " tutorial"): return false
			if not is_instance_valid(main.tutorial_panel): break
			if main.tutorial_panel.visible and main.tutorial_panel.current_step >= 0 and main.tutorial_panel.target_id == game_id: break
			await get_tree().process_frame
		if not is_instance_valid(main.tutorial_panel) or not main.tutorial_panel.visible or main.tutorial_panel.current_step < 0 or main.tutorial_panel.target_id != game_id or not is_instance_valid(main.tutorial_panel._start_button):
			await _fail("Actual first-entry tutorial did not become ready for " + game_id)
			return false
		if not await _capture_story(game_id + "-first-tutorial"): return false
		if not await _native_click_button(main.tutorial_panel._start_button, "begin actual " + game_id + " tutorial"): return false
	deadline = _wall_deadline_ms(12000)
	while Time.get_ticks_msec() < deadline:
		if not await _require_live_main("waiting for fresh " + game_id + " session"): return false
		var fresh := _fresh_story_session(game_id, previous_id)
		if fresh != null and not is_instance_valid(main.tutorial_panel):
			print("ST-4 SESSION: fresh ", game_id, " instance=", fresh.get_instance_id(), " previous=", previous_id)
			return true
		await get_tree().process_frame
	await _fail("Actual Start/tutorial action did not launch a fresh live " + game_id)
	return false

func _fresh_story_session(game_id: String, previous_id: int) -> Control:
	if not is_instance_valid(main) or not is_instance_valid(main.session): return null
	var candidate: Control = main.session
	if candidate.is_queued_for_deletion() or not candidate.is_inside_tree() or candidate.get_instance_id() == previous_id: return null
	return candidate if candidate.game_id == game_id and not candidate.ended else null

func _live_story_crowd_session(session_id: int) -> Control:
	if not is_instance_valid(main) or not is_instance_id_valid(session_id): return null
	var candidate := instance_from_id(session_id) as Control
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or main.session != candidate: return null
	return candidate if candidate.game_id == "game-004" else null

func _run_crowd_with_real_inputs(session_id: int) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	# Main frees its finished Session before the next physics frame. Observe the
	# synchronous finished latch first, then resolve a fresh validated reference.
	while not _crowd_finished and Time.get_ticks_msec() < deadline:
		if not await _require_live_main("routing real game-004 groups"): return false
		var live := _live_story_crowd_session(session_id)
		if live == null:
			await _fail("game-004 Session disappeared without its matching actual finished signal")
			return false
		var lane := _crowd_priority_lane(live.crowd_model)
		if lane >= 0 and live.crowd_model.desired_lane != lane:
			_key(KEY_Q if lane == 0 else KEY_E)
			Input.flush_buffered_events()
		await get_tree().physics_frame
		if Time.get_ticks_msec() - _started_at_ms > 300000:
			await _fail("Global native ST-4 watchdog expired during game-004")
			return false
	if not _crowd_finished:
		await _fail("game-004 natural-play input exceeded its 60-second wall-clock limit")
		return false
	if int(_crowd_result.get("score", -1)) != int(_crowd_model_evidence.get("score", -2)) or int(_crowd_result.get("score", -1)) != int(_crowd_model_evidence.get("model_score", -2)) or int(_crowd_model_evidence.get("safe_count", -1)) != 6:
		await _fail("Real game-004 result/model evidence mismatch: result=%s model=%s" % [str(_crowd_result), str(_crowd_model_evidence)])
		return false
	return true

func _latch_crowd_result(result: Dictionary, session_id: int) -> void:
	if session_id != _crowd_session_id: return
	# Main's earlier listener already detached/queued the node; signal emission
	# remains synchronous, so snapshot model evidence by ID before deletion.
	var completed: Control = instance_from_id(session_id) as Control if is_instance_id_valid(session_id) else null
	if not is_instance_valid(completed) or completed.game_id != "game-004":
		push_error("Native ST-4 lost its matching game-004 Session during finished capture")
		get_tree().quit(1)
		return
	_crowd_result = result.duplicate(true)
	_crowd_model_evidence = {"safe_count": int(completed.crowd_model.safe_count), "score": int(completed.score), "model_score": int(completed.crowd_model.score)}
	_crowd_finished = true

func _interact_at_station(id: String, expected_modal: String) -> bool:
	if not await _require_live_main("approaching " + id): return false
	var found := false
	for point in main.world.points:
		if str(point.id) == id:
			# Documented test shortcut: place only the player at a real station.
			main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
			found = true
			break
	if not found:
		await _fail("Missing actual park station " + id)
		return false
	var deadline := _wall_deadline_ms(6000)
	while Time.get_ticks_msec() < deadline and str(main.world.nearest.get("id", "")) != id:
		await get_tree().physics_frame
		if not await _require_live_main("reaching " + id): return false
	if str(main.world.nearest.get("id", "")) != id:
		await _fail("Teleported player did not reach actual interaction station " + id)
		return false
	print("ST-4 INPUT: E at actual station ", id, " (player-position-only setup)")
	_key(KEY_E)
	if expected_modal == "quest" and main.modal_kind == "dialogue":
		if not await _complete_story_dialogue(): return false
	deadline = _wall_deadline_ms(8000)
	while Time.get_ticks_msec() < deadline and main.modal_kind != expected_modal:
		await get_tree().process_frame
		if not await _require_live_main("opening actual " + id + " UI"): return false
	if main.modal_kind != expected_modal:
		await _fail("Actual E interaction at %s opened %s, expected %s" % [id, main.modal_kind, expected_modal])
		return false
	return true

func _complete_story_dialogue() -> bool:
	var safety: int = main.dialogue.size() * 3 + 2
	while main.modal_kind == "dialogue" and safety > 0:
		safety -= 1
		var needs_reveal: bool = main.dialogue_label != null and main.dialogue_label.visible_characters >= 0
		_key(KEY_E)
		if needs_reveal:
			_key(KEY_E)
		await get_tree().process_frame
	if main.modal_kind == "dialogue":
		await _fail("Dialogue did not naturally complete through actual E input")
		return false
	return true

func _save_reload_story_state() -> bool:
	var quests_before: Dictionary = progress.quests.duplicate(true)
	var photos_before: Dictionary = progress.photos.duplicate(true)
	if not progress.save_progress():
		await _fail("Could not save completed story state")
		return false
	progress._reset_memory()
	progress.load_progress()
	var differences: Array[String] = []
	var numeric_normalizations: Array[String] = []
	_collect_numeric_type_normalizations(quests_before, progress.quests, "quests", numeric_normalizations)
	_collect_numeric_type_normalizations(photos_before, progress.photos, "photos", numeric_normalizations)
	for normalization in numeric_normalizations:
		print("ST-4 SAVE JSON NUMBER NORMALIZATION: ", normalization)
	_collect_saved_value_differences(quests_before, progress.quests, "quests", differences)
	_collect_saved_value_differences(photos_before, progress.photos, "photos", differences)
	if not differences.is_empty():
		for difference in differences:
			print("ST-4 SAVE DIFF: ", difference)
		await _fail("Story quest/reward state changed after the real save/reload; full recursive differences=%s" % str(differences))
		return false
	print("ST-4 SAVE: complete quest/photo trees reload semantically unchanged (JSON int/float spelling may normalize)")
	return true

func _collect_saved_value_differences(before: Variant, after: Variant, path: String, differences: Array[String]) -> void:
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var before_dict: Dictionary = before
		var after_dict: Dictionary = after
		for key in before_dict:
			if not after_dict.has(key):
				differences.append("%s: key missing after reload (before=%s)" % [path + "." + str(key), _saved_value_type(before_dict[key])])
			else:
				_collect_saved_value_differences(before_dict[key], after_dict[key], path + "." + str(key), differences)
		for key in after_dict:
			if not before_dict.has(key):
				differences.append("%s: unexpected key after reload (after=%s)" % [path + "." + str(key), _saved_value_type(after_dict[key])])
		return
	if typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		var before_array: Array = before
		var after_array: Array = after
		if before_array.size() != after_array.size():
			differences.append("%s: array size %d -> %d" % [path, before_array.size(), after_array.size()])
		for index in range(mini(before_array.size(), after_array.size())):
			_collect_saved_value_differences(before_array[index], after_array[index], "%s[%d]" % [path, index], differences)
		return
	var numeric_types := [TYPE_INT, TYPE_FLOAT]
	if typeof(before) in numeric_types and typeof(after) in numeric_types:
		if float(before) != float(after):
			differences.append("%s: numeric value %s (%s) -> %s (%s)" % [path, str(before), _saved_value_type(before), str(after), _saved_value_type(after)])
		return
	if typeof(before) != typeof(after) or before != after:
		differences.append("%s: %s (%s) -> %s (%s)" % [path, str(before), _saved_value_type(before), str(after), _saved_value_type(after)])

func _collect_numeric_type_normalizations(before: Variant, after: Variant, path: String, normalizations: Array[String]) -> void:
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var before_dict: Dictionary = before
		var after_dict: Dictionary = after
		for key in before_dict:
			if after_dict.has(key):
				_collect_numeric_type_normalizations(before_dict[key], after_dict[key], path + "." + str(key), normalizations)
		return
	if typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		var before_array: Array = before
		var after_array: Array = after
		for index in range(mini(before_array.size(), after_array.size())):
			_collect_numeric_type_normalizations(before_array[index], after_array[index], "%s[%d]" % [path, index], normalizations)
		return
	if typeof(before) in [TYPE_INT, TYPE_FLOAT] and typeof(after) in [TYPE_INT, TYPE_FLOAT] and typeof(before) != typeof(after) and float(before) == float(after):
		normalizations.append("%s: %s (%s) -> %s (%s), exact numeric value preserved" % [path, str(before), _saved_value_type(before), str(after), _saved_value_type(after)])

func _saved_value_type(value: Variant) -> String:
	return type_string(typeof(value))

func _capture_story(label: String) -> bool:
	await RenderingServer.frame_post_draw
	if not await _require_live_main("capturing " + label): return false
	var safe_name := label.replace("/", "-").replace(" ", "-")
	if not main._capture(".review/native-st4-story-" + safe_name + ".png"):
		await _fail("Could not capture native story evidence: " + safe_name)
		return false
	print("ST-4 CAPTURE: ", safe_name)
	return true

func _find_story_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node as HSlider
	for child in node.get_children():
		var found := _find_story_slider(child)
		if found != null:
			return found
	return null

func _mouse_align_story_slider(slider: HSlider) -> bool:
	# The exploration is created dynamically inside a ScrollContainer. Let its
	# layout settle and reveal the slider before deriving native pointer coordinates.
	var ancestor := slider.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(slider)
		ancestor = ancestor.get_parent()
	await _frames(3)
	if not is_instance_valid(slider) or not slider.is_visible_in_tree():
		await _fail("Actual welcome-wall slider became invalid or hidden during layout")
		return false
	var viewport := slider.get_viewport()
	var rect := slider.get_global_rect()
	var point := viewport.get_final_transform() * rect.get_center()
	var visible_rect := viewport.get_visible_rect()
	ancestor = slider.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	var value_changes: Array[float] = []
	var on_value_changed := func(value: float) -> void: value_changes.append(value)
	slider.value_changed.connect(on_value_changed)
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	motion.button_mask = Input.get_mouse_button_mask()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var hovered := viewport.gui_get_hovered_control()
	var diag := "slider=%s rect=%s visible=%s pointer=%s hovered=%s initial_value=%s final_transform=%s" % [str(slider.get_path()), str(rect), str(visible_rect), str(point), str(hovered.get_path()) if is_instance_valid(hovered) else "none", str(slider.value), str(viewport.get_final_transform())]
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not visible_rect.encloses(rect):
		slider.value_changed.disconnect(on_value_changed)
		await _fail("Actual welcome-wall slider has no visible hit area after layout; " + diag)
		return false
	if hovered != slider:
		slider.value_changed.disconnect(on_value_changed)
		await _fail("Actual pointer did not hover the welcome-wall slider; " + diag)
		return false
	# Dispatch down and release as separate normal input events, with a frame for
	# the HSlider to process the press before the pointer is released.
	var initial_value := slider.value
	var initial_mask := Input.get_mouse_button_mask()
	var observed_mask := initial_mask
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
		observed_mask = Input.get_mouse_button_mask()
		if is_down:
			await get_tree().process_frame
			if not await _require_live_main("while clicking the welcome-wall slider"):
				slider.value_changed.disconnect(on_value_changed)
				return false
	await get_tree().process_frame
	slider.value_changed.disconnect(on_value_changed)
	diag += " value_after=%s value_changes=%s initial_mask=%d observed_mask=%d final_mask=%d" % [str(slider.value), str(value_changes), initial_mask, observed_mask, Input.get_mouse_button_mask()]
	print("ST-4 INPUT: welcome-wall slider ", diag)
	if value_changes.is_empty() or slider.value == initial_value:
		await _fail("Normal pointer click reached the visible slider but emitted no value change; " + diag)
		return false
	if absf(slider.value) > 15.0:
		await _fail("Normal pointer click changed the actual slider but missed its alignment tolerance; " + diag)
		return false
	return true
