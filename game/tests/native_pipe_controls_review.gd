extends "res://game/tests/native_pipe_orders_review.gd"

## SG pipe input review through the actual station, Session HUD, and result UI.
const ORDER_ROUTES: Array = [
	[0, 4, 6, 15],
	[0, 1, 2, 3, 4, 8, 12],
	[0, 1, 2, 3, 6, 10, 14, 15]
]
const DESIGN_BOARD := Rect2(320.0, 166.0, 640.0, 400.0)

var _case_metrics: Dictionary = {}
var _retry_event_state: Dictionary = {}

func _process(delta: float) -> void:
	super._process(delta)

func _run() -> void:
	if not _native_preflight("Pipe controls review"):
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
	await get_tree().create_timer(1.0).timeout
	if not await _require_live_main("initial station load"): return
	if not await _enter_station(): return
	if not await _launch_from_station("開始遊玩"): return
	if not await _require_live_session("formal launch"): return

	# Solve the first work order with real cursor arrows and Space, then exercise
	# the shared pause/resume and confirmed retry while the live flow timer runs.
	if not await _solve_keyboard_order(0): return
	if not await _review_flow_pause_resume_retry(): return
	for order_index in 3:
		if not await _solve_keyboard_order(order_index): return
		if order_index < 2 and not await _wait_for_order(order_index + 1): return
	if not await _wait_for_result(): return
	if not await _assert_result("keyboard-standard", false, false): return
	if not await _require_live_main("formal result collection"): return
	if not progress.photos.has("photo-welcome-game-7") or progress.normal_count() < 1:
		await _fail("Successful keyboard challenge did not follow Main's ordinary collection path")
		return
	var saved_photos: Dictionary = progress.photos.duplicate(true)
	var saved_normal: int = progress.normal_count()
	var saved_devil: int = progress.devil_count()
	var saved_achievements: Dictionary = progress.achievements.duplicate(true)
	print("PIPE CASE: keyboard-standard score=%d turns=%d devil=%s orders=%s schema=%s" % [int(observed_result.get("score", -1)), int(_case_metrics.get("turns", -1)), str(observed_result.get("devil", false)), str(_case_metrics.get("order_turns", [])), str(observed_result.keys())])

	if not await _return_to_station(): return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _enter_station(): return
	if not await _launch_from_station("練習操作"): return
	if not await _require_live_session("practice launch"): return
	if not active.assisted or not active.practice_mode or not active.reduced_motion:
		await _fail("Pipe practice launch did not preserve assisted/reduced-motion settings")
		return
	if not active.minigame_hud._badge.visible or not active.minigame_hud._badge.text.contains("練習"):
		await _fail("Pipe practice HUD omitted the no-collection badge")
		return
	await get_tree().create_timer(0.2).timeout
	if not await _require_live_session("practice ready wait"): return
	for order_index in 3:
		if not await _solve_pointer_order(order_index): return
		if order_index < 2 and not await _wait_for_order(order_index + 1): return
	if not await _wait_for_result(): return
	if not await _assert_result("pointer-assisted-reduced-practice", true, true): return
	if not await _require_live_main("practice collection verification"): return
	if progress.photos != saved_photos or progress.normal_count() != saved_normal or progress.devil_count() != saved_devil or progress.achievements != saved_achievements:
		await _fail("Successful pipe practice changed saved photos, counts, or achievements")
		return
	if not is_instance_valid(main) or main.modal_kind != "result" or not _result_has_text("分數、拍貼、任務與成就都沒有寫入紀錄") or not _result_has_text("練習分數 2620（不保存）"):
		await _fail("Practice result UI did not explain that its outcome is not recorded")
		return
	await _shot("pipe-controls-pointer-practice-result")
	if not await _require_live_main("practice result capture"): return
	print("PIPE CASE: pointer-assisted-reduced-practice score=%d turns=%d devil=%s orders=%s; saved collections unchanged" % [int(observed_result.get("score", -1)), int(_case_metrics.get("turns", -1)), str(observed_result.get("devil", false)), str(_case_metrics.get("order_turns", []))])
	print("PASS: native SG pipe keyboard cursor/Space and pointer-only three-order routes, pause/resume, retry reset, reduced-motion flow payoff, and non-collecting practice")
	await main._quit_game()

func _enter_station() -> bool:
	if not await _require_live_main("_enter_station"): return false
	var found := false
	for point in main.world.points:
		if point.id != "game-007":
			continue
		main.world.player.position = point.position + Vector3(0, 0.3, 0)
		found = true
		break
	if not found:
		await _fail("Pipe station game-007 is missing")
		return false
	var deadline := _wall_deadline(4.0)
	while main.world.nearest.get("id", "") != "game-007" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not await _require_live_main("_enter_station after frame wait"): return false
	if main.world.nearest.get("id", "") != "game-007":
		await _fail("Pipe station did not become the real nearest interaction")
		return false
	_key(KEY_E)
	deadline = _wall_deadline(3.0)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_enter_station after frame wait"): return false
	if main.modal_kind != "game_info":
		await _fail("E did not open game-007 station details")
		return false
	return true

func _launch_from_station(action: String) -> bool:
	if not await _require_live_main("_launch_from_station"): return false
	var button := _find(main.overlay, action)
	if button == null or not await _native_click_button(button, "game-007 " + action):
		await _fail("Station action did not start game-007: " + action)
		return false
	if not await _require_live_main("station action completion"): return false
	var deadline := _wall_deadline(4.0)
	while is_instance_valid(main) and not is_instance_valid(main.session) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_launch_from_station after frame wait"): return false
	if not is_instance_valid(main) or not is_instance_valid(main.session):
		await _fail("Station action left no active pipe Session")
		return false
	active = main.session
	observed_result.clear()
	_case_metrics.clear()
	active.finished.connect(_capture_result)
	return true

func _capture_result(result: Dictionary) -> void:
	observed_result = result.duplicate(true)
	if is_instance_valid(active):
		_case_metrics = {
			"score": active.score,
			"turns": active.pipe_model.total_turns,
			"order_turns": active.pipe_model.order_turns.duplicate(),
			"order_pars": active.pipe_model.orders.map(func(order: Dictionary): return int(order.turn_par)),
			"completed_beds": active.pipe_model.completed_beds,
			"elapsed": active.elapsed,
			"assisted": active.assisted,
			"practice": active.practice_mode
		}

func _solve_keyboard_order(order_index: int) -> bool:
	if not await _require_live_session("_solve_keyboard_order"): return false
	var route: Array = ORDER_ROUTES[order_index]
	var expected_turn_start: int = active.pipe_model.total_turns
	for cell_variant in route:
		var cell := int(cell_variant)
		if not await _move_keyboard_cursor_to(cell): return false
		if not await _require_live_session("keyboard cursor completion"): return false
		var turns_before: int = active.pipe_model.total_turns
		var mask_before: int = int(active.pipe_model.cells[cell])
		_key(KEY_SPACE)
		Input.flush_buffered_events()
		if active.pipe_cursor != cell or active.pipe_model.cursor != cell:
			await _fail("Keyboard selection did not land on tile %d (session/model=%d/%d)" % [cell, active.pipe_cursor, active.pipe_model.cursor])
			return false
		if active.pipe_model.total_turns != turns_before + 1 or int(active.pipe_model.cells[cell]) != _rotate_mask(mask_before):
			await _fail("Space did not make exactly one real rotation at tile %d" % cell)
			return false
		await get_tree().process_frame
		if not await _require_live_session("_solve_keyboard_order after frame wait"): return false
	if not active.pipe_model.connected or active.pipe_model.order_index != order_index:
		await _fail("Keyboard route did not truly connect order %d: %s" % [order_index + 1, str(active.pipe_model.snapshot())])
		return false
	if active.pipe_model.order_turns[order_index] != route.size() or active.pipe_model.total_turns != expected_turn_start + route.size():
		await _fail("Keyboard rotations did not match live model order/total counters")
		return false
	await _shot("pipe-controls-keyboard-flow-%d" % (order_index + 1))
	if not _session_is_live() and (order_index != 2 or observed_result.is_empty() or _case_metrics.is_empty()):
		await _fail("Keyboard pipe Session disappeared before its verified final result")
		return false
	return true

func _move_keyboard_cursor_to(cell: int) -> bool:
	if not await _require_live_session("_move_keyboard_cursor_to"): return false
	var target_column := cell % 4
	var target_row := int(cell / 4)
	while active.pipe_cursor % 4 != target_column:
		_key(KEY_RIGHT if active.pipe_cursor % 4 < target_column else KEY_LEFT)
		Input.flush_buffered_events()
		await get_tree().process_frame
		if not await _require_live_session("_move_keyboard_cursor_to after wait"): return false
	while int(active.pipe_cursor / 4) != target_row:
		_key(KEY_DOWN if int(active.pipe_cursor / 4) < target_row else KEY_UP)
		Input.flush_buffered_events()
		await get_tree().process_frame
		if not await _require_live_session("_move_keyboard_cursor_to after wait"): return false
	if active.pipe_cursor != cell:
		await _fail("Arrow-key navigation expected cell %d, actual cursor %d" % [cell, active.pipe_cursor])
		return false
	return true

func _review_flow_pause_resume_retry() -> bool:
	if not await _require_live_session("_review_flow_pause_resume_retry"): return false
	if not active.pipe_connected or active.pipe_model.flow_remaining <= 0.0:
		await _fail("First keyboard-connected order did not start its live water-flow timer")
		return false
	var pause := active.minigame_hud.find_child("PauseButton", true, false) as Button
	if not await _native_click_button(pause, "pause connected pipe order"): return false
	if not await _require_live_session("_review_flow_pause_resume_retry after native click"): return false
	if not active.paused:
		await _fail("HUD pause control did not pause the connected pipe round")
		return false
	var frozen_elapsed: float = active.elapsed
	var frozen_phase: float = active.phase
	var frozen_flow: float = active.pipe_model.flow_remaining
	await get_tree().create_timer(0.35).timeout
	if not await _require_live_session("_review_flow_pause_resume_retry after wait"): return false
	if not is_equal_approx(active.elapsed, frozen_elapsed) or not is_equal_approx(active.phase, frozen_phase) or not is_equal_approx(active.pipe_model.flow_remaining, frozen_flow):
		await _fail("Paused pipe changed elapsed, phase, or water-flow timer")
		return false
	var resume := active.minigame_hud.find_child("ResumeButton", true, false) as Button
	if not await _native_click_button(resume, "resume connected pipe order"): return false
	if not await _require_live_session("_review_flow_pause_resume_retry after native click"): return false
	if active.paused:
		await _fail("HUD resume control left pipe Session paused")
		return false
	await get_tree().create_timer(0.2).timeout
	if not await _require_live_session("_review_flow_pause_resume_retry after wait"): return false
	if active.pipe_model.flow_remaining >= frozen_flow or active.elapsed <= frozen_elapsed:
		await _fail("Resuming pipe did not continue the original live order/timer")
		return false
	if not await _native_click_button(pause, "pause before pipe retry"): return false
	if not await _require_live_session("_review_flow_pause_resume_retry after native click"): return false
	var retry := active.minigame_hud.find_child("RetryButton", true, false) as Button
	if not await _native_click_button(retry, "request pipe retry"): return false
	if not await _require_live_session("_review_flow_pause_resume_retry after native click"): return false
	var confirm := active.minigame_hud.find_child("ConfirmAction", true, false) as Button
	_retry_event_state.clear()
	confirm.pressed.connect(_capture_retry_event_state)
	if not await _native_click_button(confirm, "confirm pipe retry"): return false
	if not await _require_live_session("_review_flow_pause_resume_retry after native click"): return false
	if _retry_event_state.is_empty() or bool(_retry_event_state.get("paused", true)) or bool(_retry_event_state.get("ended", true)) or float(_retry_event_state.get("elapsed", -1.0)) != 0.0 or int(_retry_event_state.get("score", -1)) != 0 or int(_retry_event_state.get("order", -1)) != 0 or int(_retry_event_state.get("turns", -1)) != 0 or int(_retry_event_state.get("beds", -1)) != 0 or float(_retry_event_state.get("flow", -1.0)) != 0.0 or bool(_retry_event_state.get("connected", true)) or int(_retry_event_state.get("cursor", -1)) != 0:
		await _fail("ConfirmAction signal did not observe the exact instant reset: " + str(_retry_event_state))
		return false
	if main.session != active or active.paused or active.ended or active.elapsed < 0.0 or active.elapsed > 0.20 or active.pipe_model.order_index != 0 or active.pipe_model.total_turns != 0 or active.pipe_cursor != 0:
		await _fail("Pipe retry changed the live Session or advanced beyond a normal click's post-reset frames")
		return false
	print("PIPE RETRY RESET: " + str(_retry_event_state) + " post_click_elapsed=%.4f" % active.elapsed)
	await _shot("pipe-controls-retry-reset")
	if not await _require_live_session("_review_flow_pause_resume_retry after wait"): return false
	return true

func _capture_retry_event_state() -> void:
	if not is_instance_valid(active):
		return
	_retry_event_state = {
		"instance_id": active.get_instance_id(),
		"paused": active.paused,
		"ended": active.ended,
		"elapsed": active.elapsed,
		"score": active.score,
		"order": active.pipe_model.order_index,
		"turns": active.pipe_model.total_turns,
		"beds": active.pipe_model.completed_beds,
		"flow": active.pipe_model.flow_remaining,
		"connected": active.pipe_model.connected,
		"cursor": active.pipe_cursor
	}

func _solve_pointer_order(order_index: int) -> bool:
	if not await _require_live_session("_solve_pointer_order"): return false
	var route: Array = ORDER_ROUTES[order_index]
	var turns_before_order: int = active.pipe_model.total_turns
	for cell_variant in route:
		var cell := int(cell_variant)
		var turns_before: int = active.pipe_model.total_turns
		var screen_point: Vector2 = active.presentation.get_global_transform_with_canvas() * _design_cell_center(cell)
		_click(screen_point)
		Input.flush_buffered_events()
		if active.pipe_cursor != cell or active.pipe_model.cursor != cell:
			await _fail("Pointer click targeted cell %d but live cursor/model is %d/%d" % [cell, active.pipe_cursor, active.pipe_model.cursor])
			return false
		if active.pipe_model.total_turns != turns_before + 1:
			await _fail("Pointer click did not rotate exactly one live tile at cell %d" % cell)
			return false
		await get_tree().process_frame
		if not await _require_live_session("_solve_pointer_order after frame wait"): return false
	if not active.pipe_model.connected or active.pipe_model.order_index != order_index:
		await _fail("Pointer route did not truly connect order %d" % (order_index + 1))
		return false
	if active.pipe_model.order_turns[order_index] != route.size() or active.pipe_model.total_turns != turns_before_order + route.size():
		await _fail("Pointer rotations did not match live model order/total counters")
		return false
	if not active.presentation.reduced_motion or not active.presentation.bloom_visible() or not is_equal_approx(active.presentation.flow_progress, 1.0):
		await _fail("Reduced-motion successful order hid its static completed-water/flower feedback")
		return false
	await _shot("pipe-controls-pointer-reduced-flow-%d" % (order_index + 1))
	if not _session_is_live() and (order_index != 2 or observed_result.is_empty() or _case_metrics.is_empty()):
		await _fail("Pointer pipe Session disappeared before its verified final result")
		return false
	return true

func _design_cell_center(cell: int) -> Vector2:
	var column := cell % 4
	var row := int(cell / 4)
	return DESIGN_BOARD.position + Vector2((float(column) + 0.5) * DESIGN_BOARD.size.x / 4.0, (float(row) + 0.5) * DESIGN_BOARD.size.y / 4.0)

func _rotate_mask(mask: int) -> int:
	return ((mask << 1) & 15) | (mask >> 3)

func _wait_for_order(expected: int) -> bool:
	if not await _require_live_session("_wait_for_order"): return false
	var deadline := _wall_deadline(3.0)
	while _session_is_live() and active.pipe_model.order_index < expected and not active.ended and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_session("_wait_for_order after frame wait"): return false
	if not await _require_live_session("order wait completion"): return false
	if active.ended or active.pipe_model.order_index != expected or active.pipe_model.completed_beds != expected:
		await _fail("Connected order did not complete into the next work order (%d): %s" % [expected, str(active.pipe_model.snapshot())])
		return false
	if not observed_result.is_empty():
		await _fail("Pipe completed before its final third order")
		return false
	return true

func _wait_for_result() -> bool:
	if not await _require_live_main("_wait_for_result"): return false
	if not await _require_live_main("station action completion"): return false
	var deadline := _wall_deadline(4.0)
	while is_instance_valid(main) and main.modal_kind != "result" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_wait_for_result after frame wait"): return false
	if not is_instance_valid(main) or main.modal_kind != "result" or observed_result.is_empty():
		await _fail("game-007 did not produce the real Main result and Session signal")
		return false
	return true

func _assert_result(label: String, expect_assisted: bool, expect_practice: bool) -> bool:
	if str(observed_result.get("game_id", "")) != "game-007" or not bool(observed_result.get("success", false)):
		await _fail(label + " did not complete the actual game-007 objective: " + str(observed_result))
		return false
	if int(_case_metrics.get("completed_beds", -1)) != 3 or int(_case_metrics.get("turns", -1)) != 19 or _case_metrics.get("order_turns", []) != [4, 7, 8]:
		await _fail(label + " did not record the three actual orders and 19 real rotations: " + str(_case_metrics))
		return false
	if int(observed_result.get("score", -1)) != int(_case_metrics.get("score", -2)) or int(observed_result.get("score", -1)) != 2620:
		await _fail(label + " score/result does not match its three work orders: " + str(_case_metrics))
		return false
	if bool(observed_result.get("assisted", false)) != expect_assisted or bool(observed_result.get("practice", false)) != expect_practice:
		await _fail(label + " result flags do not match the live Session")
		return false
	var within_all_pars := true
	var actual_turns: Array = _case_metrics.get("order_turns", [])
	var actual_pars: Array = _case_metrics.get("order_pars", [])
	if actual_pars.size() != 3:
		await _fail(label + " omitted the actual work-order pars")
		return false
	for index in 3:
		within_all_pars = within_all_pars and int(actual_turns[index]) <= int(actual_pars[index])
	if bool(observed_result.get("devil", false)) != within_all_pars:
		await _fail(label + " devil outcome did not reflect the actual per-order pars: " + str(observed_result))
		return false
	if not observed_result.has("mistakes") or not (observed_result.get("score_summary", {}) is Dictionary) or not (observed_result.score_summary.get("rows", []) is Array):
		await _fail(label + " result omitted the established mistakes/score-summary schema")
		return false
	return true

func _return_to_station() -> bool:
	if not await _require_live_main("_return_to_station"): return false
	var button := _find(main.overlay, "返回遊園")
	if button == null or not await _native_click_button(button, "return to the harbor park"):
		return false
	if not await _require_live_main("station action completion"): return false
	var deadline := _wall_deadline(4.0)
	while is_instance_valid(main) and main.modal_kind != "" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_return_to_station after frame wait"): return false
	return is_instance_valid(main) and main.modal_kind == ""

func _result_has_text(fragment: String) -> bool:
	return _contains_label(main.overlay, fragment)

func _contains_label(node: Node, fragment: String) -> bool:
	if node is Label and str((node as Label).text).contains(fragment):
		return true
	for child in node.get_children():
		if _contains_label(child, fragment):
			return true
	return false

func _wall_deadline(simulated_seconds: float) -> int:
	return Time.get_ticks_msec() + ceili(simulated_seconds / maxf(Engine.time_scale, 0.01) * 1000.0)

func _session_is_live() -> bool:
	return is_instance_valid(main) and is_instance_valid(active) and not active.is_queued_for_deletion() and is_instance_valid(main.session) and main.session == active

func _require_live_session(context: String) -> bool:
	if _session_is_live():
		return true
	await _fail("Session disappeared or was replaced while " + context)
	return false

func _require_live_main(context: String) -> bool:
	if is_instance_valid(main) and not main.is_queued_for_deletion() and is_instance_valid(progress):
		return true
	await _fail("Main/Progress disappeared while " + context)
	return false

func _native_click_button(button: BaseButton, context: String) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		await _fail("Native click target is missing, hidden or disabled: " + context)
		return false
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await get_tree().process_frame
	if not is_instance_valid(button) or not is_instance_valid(main):
		await _fail("Native click target was released during layout wait: " + context)
		return false
	await get_tree().process_frame
	if not is_instance_valid(button) or not is_instance_valid(main):
		await _fail("Native click target was released during layout wait: " + context)
		return false
	var viewport := button.get_viewport()
	var rect := button.get_global_rect()
	var visible_rect := viewport.get_visible_rect()
	ancestor = button.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible_rect = visible_rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	if not visible_rect.encloses(rect):
		await _fail("Native click target is clipped: %s rect=%s visible=%s" % [context, rect, visible_rect])
		return false
	var observation := {"down": 0, "up": 0, "pressed": 0, "gui": []}
	var on_down := func(): observation.down += 1
	var on_up := func(): observation.up += 1
	var on_pressed := func(): observation.pressed += 1
	var on_gui := func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			observation.gui.append("down" if event.pressed else "up")
	button.button_down.connect(on_down)
	button.button_up.connect(on_up)
	button.pressed.connect(on_pressed)
	button.gui_input.connect(on_gui)
	var target_path := str(button.get_path())
	var point := viewport.get_final_transform() * rect.get_center()
	# Flush queued OS/fixture events before beginning this click. No input state,
	# control signal or gameplay callback is assigned or invoked directly.
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	motion.button_mask = Input.get_mouse_button_mask()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var hovered := viewport.gui_get_hovered_control()
	var diagnostics := "target=%s rect=%s pointer=%s hovered=%s button_hovered=%s initial_mask=%d" % [target_path, rect, point, str(hovered.get_path()) if is_instance_valid(hovered) else "none", button.is_hovered(), Input.get_mouse_button_mask()]
	if not button.is_hovered() or not (hovered == button or is_instance_valid(hovered) and button.is_ancestor_of(hovered)):
		for pair in [[button.button_down, on_down], [button.button_up, on_up], [button.pressed, on_pressed], [button.gui_input, on_gui]]:
			pair[0].disconnect(pair[1])
		await _fail("Native pointer did not hover its target: %s; %s" % [context, diagnostics])
		return false
	# Dispatch and flush each distinct event without yielding to unrelated OS
	# motion or deferred focus changes between the observed down and release.
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
	if is_instance_valid(button):
		for pair in [[button.button_down, on_down], [button.button_up, on_up], [button.pressed, on_pressed], [button.gui_input, on_gui]]:
			pair[0].disconnect(pair[1])
	diagnostics += " observed=%s final_mask=%d" % [observation, Input.get_mouse_button_mask()]
	if observation.down != 1 or observation.pressed != 1:
		await _fail("Native click did not activate its target: %s; %s" % [context, diagnostics])
		return false
	print("INPUT: ", context, " ", diagnostics)
	await get_tree().process_frame
	if not is_instance_valid(main):
		await _fail("Main was released after native click: " + context)
		return false
	await get_tree().process_frame
	if not is_instance_valid(main):
		await _fail("Main was released after native click: " + context)
		return false
	return true

func _fail(message: String) -> void:
	Input.flush_buffered_events()
	push_error(message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
