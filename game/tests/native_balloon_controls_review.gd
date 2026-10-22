extends "res://game/tests/native_balloon_harbor_review.gd"

## Separate native SG-16 control review. The only launched minigame is game-001.
const ROUTE: Array[Vector2] = [
	Vector2(520, 305), Vector2(780, 270), Vector2(880, 270),
	Vector2(1000, 510), Vector2(820, 510), Vector2(1080, 320)
]

var _keyboard_axis := Vector2i.ZERO
var _space_held := false
var _right_mouse_held := false
var _case_result: Dictionary = {}
var _case_stats: Dictionary = {}
var _retry_event_state: Dictionary = {}
var _wind_pixels_verified := false

func _process(delta: float) -> void:
	super._process(delta)

func _run() -> void:
	if not _native_preflight("Balloon controls review"):
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main(false)
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _require_live_main("initial station load"): return
	if not await _enter_station(): return
	if not await _launch_from_station("開始遊玩"): return
	if not await _require_live_session("formal launch"): return

	# Keyboard-only session also checks that the shared HUD really freezes and
	# restores the same live flight, then that confirmed retry resets that round.
	_key(KEY_ENTER)
	await get_tree().create_timer(0.2).timeout
	if not await _require_live_session("formal start wait"): return
	if not OS.get_cmdline_user_args().has("--balloon-routes-only"):
		if not await _review_pause_and_retry(): return
	if OS.get_cmdline_user_args().has("--balloon-retry-only"):
		print("PASS: actual first tutorial and paused/resumed confirmed retry, exact signal-time reset and original0.20-second post-click bound")
		await main._quit_game()
		return
	if not await _drive_route(false): return
	if not await _wait_for_result(): return
	if not await _assert_completed_case("keyboard-standard", false, false): return
	if int(_case_result.mistakes) != 0 or not bool(_case_result.devil) or not progress.photos.has("photo-welcome-devil-1"):
		await _fail("Keyboard route did not earn its actual zero-error devil result");return
	if not await _require_live_main("formal result collection"): return
	if not progress.photos.has("photo-welcome-game-1") or progress.normal_count() < 1:
		await _fail("Successful formal keyboard challenge did not use the normal collection result path")
		return
	await _shot("balloon-keyboard-precise-result")
	var formal_state := _protected_progress()
	var formal_photos: Dictionary = progress.photos.duplicate(true)
	var formal_normal: int = progress.normal_count()
	var formal_devil: int = progress.devil_count()
	var formal_achievements: Dictionary = progress.achievements.duplicate(true)
	print("BALLOON CASE: keyboard-standard score=%d mistakes=%d devil=%s schema=%s" % [int(_case_result.get("score", -1)), int(_case_result.get("mistakes", -1)), str(_case_result.get("devil", false)), str(_case_result.keys())])

	# Launch the actual station's assisted practice action with reduced motion.
	if not await _return_to_station_info(): return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _enter_station(): return
	if not await _launch_from_station("練習操作"): return
	if not await _require_live_session("practice launch"): return
	if not is_instance_valid(active) or not active.practice_mode or not active.assisted or not active.reduced_motion:
		await _fail("Assisted/reduced-motion practice launch did not preserve all requested flags")
		return
	await get_tree().create_timer(0.2).timeout
	if not await _require_live_session("practice badge wait"): return
	if not active.minigame_hud._badge.visible or not active.minigame_hud._badge.text.contains("練習"):
		await _fail("The active HUD omitted its no-collection practice badge")
		return
	if not await _check_reduced_wind_legend(): return
	_key(KEY_ENTER)
	await get_tree().process_frame
	if not await _require_live_session("practice flight start"): return
	await _shot("balloon-controls-pointer-reduced-wind")
	if not await _require_live_session("practice wind capture"): return
	if not await _drive_route(true): return
	if not await _wait_for_result(): return
	if not await _assert_completed_case("pointer-assisted-reduced-practice", true, true): return
	if not await _require_live_main("practice collection verification"): return
	if _protected_progress() != formal_state:
		await _fail("Private practice changed protected progression");return
	if progress.photos != formal_photos or progress.normal_count() != formal_normal or progress.devil_count() != formal_devil or progress.achievements != formal_achievements:
		await _fail("Successful practice changed saved photos, completion counts, or achievements")
		return
	if not is_instance_valid(main) or main.modal_kind != "result" or not _result_text_contains("分數、拍貼、任務與成就都沒有寫入紀錄") or not _result_text_contains("練習分數 450（不保存）"):
		await _fail("Practice result UI did not explain that the run is not recorded")
		return
	await _shot("balloon-controls-pointer-practice-result")
	if not await _require_live_main("practice result capture"): return
	print("BALLOON CASE: pointer-assisted-reduced-practice score=%d mistakes=%d devil=%s schema=%s; saved collections unchanged" % [int(_case_result.get("score", -1)), int(_case_result.get("mistakes", -1)), str(_case_result.get("devil", false)), str(_case_result.keys())])
	print("PASS: native SG-16 independent keyboard and pointer routes, reduced-motion wind legend, and non-collecting practice")
	await main._quit_game()

func _enter_station() -> bool:
	if not await _require_live_main("_enter_station"): return false
	var found := false
	for point in main.world.points:
		if point.id != "game-001":
			continue
		main.world.player.position = point.position + Vector3(0, 0.3, 0)
		found = true
		break
	if not found:
		await _fail("Balloon station game-001 is missing")
		return false
	var deadline := _wall_deadline(4.0)
	while main.world.nearest.get("id", "") != "game-001" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if not await _require_live_main("_enter_station after frame wait"): return false
	if main.world.nearest.get("id", "") != "game-001":
		await _fail("Balloon station did not become the real nearest interaction")
		return false
	_key(KEY_E)
	deadline = _wall_deadline(3.0)
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_enter_station after frame wait"): return false
	if main.modal_kind != "game_info":
		await _fail("E did not open game-001 station details")
		return false
	return true

func _launch_from_station(button_text: String) -> bool:
	if not await _require_live_main("_launch_from_station"): return false
	var button := _find(main.overlay, button_text)
	if button == null and button_text == "練習操作":
		if not await _native_click_button(_find(main.overlay, "玩法與選項"), "open optional practice modes"): return false
		button = _find(main.overlay, button_text)
	if button == null or not await _native_click_button(button, "game-001 " + button_text):
		await _fail("Station action did not launch game-001: " + button_text)
		return false
	if not await _require_live_main("station action completion"): return false
	if is_instance_valid(main.tutorial_panel):
		if progress.has_seen_tutorial("game-001") or is_instance_valid(main.session):
			await _fail("First tutorial did not precede a fresh session");return false
		for step in 3:
			if main.tutorial_panel.current_step != step:
				await _fail("First tutorial skipped a page");return false
			await _shot("balloon-first-tutorial-%d" % (step + 1))
			if step < 2 and not await _native_click_button(_find(main.tutorial_panel, "下一步"), "next first lesson page"): return false
		if not await _native_click_button(_find(main.tutorial_panel, "開始挑戰"), "begin first balloon lesson"): return false
	var deadline := _wall_deadline(4.0)
	while is_instance_valid(main) and not is_instance_valid(main.session) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_launch_from_station after frame wait"): return false
	if not is_instance_valid(main) or not is_instance_valid(main.session):
		await _fail("Station action left no active Session")
		return false
	active = main.session
	_wind_pixels_verified = false
	_case_result.clear()
	_case_stats.clear()
	active.finished.connect(_capture_case_result)
	return true

func _capture_case_result(result: Dictionary) -> void:
	_case_result = result.duplicate(true)
	if is_instance_valid(active):
		_case_stats = {
			"score": active.score,
			"mistakes": active.mistakes,
			"devil_progress": active.devil_progress,
			"delivered": active.balloon_delivery_index,
			"elapsed": active.elapsed,
			"assisted": active.assisted,
			"practice": active.practice_mode
		}

func _review_pause_and_retry() -> bool:
	if not await _require_live_session("_review_pause_and_retry"): return false
	if active.elapsed <= 0.0 or active.balloon_delivery_index != 0:
		await _fail("Keyboard test did not enter a timer-running delivery session")
		return false
	var pause_button := active.minigame_hud.find_child("PauseButton", true, false) as Button
	if not await _native_click_button(pause_button, "pause active keyboard delivery"):
		return false
	if not await _require_live_session("_review_pause_and_retry after native click"): return false
	if not active.paused:
		await _fail("Pause control did not pause the active balloon round")
		return false
	var frozen_elapsed: float = active.elapsed
	var frozen_phase: float = active.phase
	var frozen_position: Vector2 = active.p
	await get_tree().create_timer(0.35).timeout
	if not await _require_live_session("_review_pause_and_retry after wait"): return false
	if not is_equal_approx(active.elapsed, frozen_elapsed) or not is_equal_approx(active.phase, frozen_phase) or active.p != frozen_position:
		await _fail("Paused balloon changed elapsed/phase/position")
		return false
	var resume_button := active.minigame_hud.find_child("ResumeButton", true, false) as Button
	if not await _native_click_button(resume_button, "resume same balloon round"):
		return false
	if not await _require_live_session("_review_pause_and_retry after native click"): return false
	if active.paused:
		await _fail("Resume control left the balloon round paused")
		return false
	await get_tree().create_timer(0.2).timeout
	if not await _require_live_session("_review_pause_and_retry after wait"): return false
	if active.elapsed <= frozen_elapsed:
		await _fail("Resumed balloon timer did not continue")
		return false
	if not await _native_click_button(pause_button, "pause before confirmed retry"):
		return false
	if not await _require_live_session("_review_pause_and_retry after native click"): return false
	var retry_button := active.minigame_hud.find_child("RetryButton", true, false) as Button
	if not await _native_click_button(retry_button, "request balloon retry"):
		return false
	if not await _require_live_session("_review_pause_and_retry after native click"): return false
	var confirm := active.minigame_hud.find_child("ConfirmAction", true, false) as Button
	_retry_event_state.clear()
	confirm.pressed.connect(_capture_retry_event_state)
	if not await _native_click_button(confirm, "confirm balloon retry"):
		return false
	if not await _require_live_session("_review_pause_and_retry after native click"): return false
	if _retry_event_state.is_empty() or bool(_retry_event_state.get("paused", true)) or bool(_retry_event_state.get("ended", true)) or int(_retry_event_state.get("delivery", -1)) != 0 or float(_retry_event_state.get("elapsed", -1.0)) != 0.0 or int(_retry_event_state.get("score", -1)) != 0 or int(_retry_event_state.get("mistakes", -1)) != 0 or Vector2(_retry_event_state.get("position", Vector2.ZERO)) != Vector2(250, 380):
		await _fail("ConfirmAction signal did not observe the exact instant reset: " + str(_retry_event_state))
		return false
	if main.session != active or active.paused or active.ended or active.balloon_delivery_index != 0 or active.elapsed < 0.0 or active.elapsed > 0.20:
		await _fail("Balloon retry changed the live Session or advanced beyond a normal click's post-reset frames")
		return false
	print("BALLOON RETRY RESET: " + str(_retry_event_state) + " post_click_elapsed=%.4f" % active.elapsed)
	await _shot("balloon-controls-retry-reset")
	if not await _require_live_session("_review_pause_and_retry after wait"): return false
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
		"mistakes": active.mistakes,
		"delivery": active.balloon_delivery_index,
		"position": active.p
	}

func _drive_route(pointer_only: bool) -> bool:
	if not await _require_live_session("beginning real delivery route"): return false
	var waypoint := 0
	var brake_held := false
	var first_delivery_captured := false
	var observed_events := 0
	var previous_waypoint := -1
	var deadline := _wall_deadline(62.0)
	while _session_is_live() and not active.ended and Time.get_ticks_msec() < deadline:
		if active.balloon_delivery_index >= 1 and waypoint == 0:
			waypoint = 1
		if active.balloon_delivery_index >= 2:
			waypoint = 5
		if waypoint >= 1 and waypoint <= 3 and active.p.distance_to(ROUTE[waypoint]) < 30.0:
			waypoint += 1
		if previous_waypoint != waypoint or active.score_events.size() != observed_events:
			print("BALLOON ROUTE TRACE: pointer=%s wp=%d position=%s target=%s velocity=%s phase=%.3f events=%s" % [pointer_only,waypoint,active.p,active.target,active.velocity,active.phase,active.score_events])
			previous_waypoint = waypoint
			observed_events = active.score_events.size()
		var desired_point := ROUTE[waypoint]
		if not pointer_only:
			desired_point = _keyboard_docking_aim(desired_point)
		if pointer_only:
			_motion(active.presentation.design_to_screen(desired_point))
			Input.flush_buffered_events()
		else:
			_set_keyboard_direction(desired_point)
		var distance_to_dock: float = active.p.distance_to(active.target)
		var speed: float = active.velocity.length()
		var threshold: float = active.balloon_dock_speed
		var stop_early: bool = distance_to_dock < 190.0 and speed > threshold
		var in_ring: bool = distance_to_dock <= active.balloon_dock_radius
		var controlled_approach: bool = brake_held and distance_to_dock < 190.0
		var should_brake: bool = active.balloon_delivery_index < 3 and (stop_early or in_ring or controlled_approach) and waypoint not in [1, 2, 3]
		if should_brake != brake_held:
			if pointer_only:
				_set_right_mouse(should_brake)
			else:
				_set_space(should_brake)
			brake_held = should_brake
		if pointer_only and not active.mouse_steering:
			_release_route_inputs()
			await _fail("Pointer route stopped using the actual mouse-steering path")
			return false
		if not pointer_only and active.mouse_steering:
			_release_route_inputs()
			await _fail("Keyboard-only route was contaminated by mouse steering")
			return false
		if active.balloon_delivery_index >= 1 and not first_delivery_captured:
			await _shot("balloon-controls-pointer-first-delivery" if pointer_only else "balloon-controls-keyboard-first-delivery")
			first_delivery_captured = true
			if not _session_is_live():
				break
		if pointer_only and active.reduced_motion and waypoint == 5 and _case_stats.is_empty():
			# The active 3D legend must retain both arrows while motion decoration is reduced.
			if not await _check_reduced_wind_legend():
				_release_route_inputs()
				return false
			if not _session_is_live():
				break
		await get_tree().physics_frame
		if not _session_is_live():
			break
	_release_route_inputs()
	if _session_is_live() and not active.ended:
		await _fail("Balloon route watchdog expired: delivery=%d p=%s velocity=%s target=%s elapsed=%.2f mistakes=%d" % [active.balloon_delivery_index, active.p, active.velocity, active.target, active.elapsed, active.mistakes])
		return false
	# Main may have freed the completed Session. Its synchronous finished signal
	# must already have preserved real delivery/result data before we accept exit.
	if _case_result.is_empty() or _case_stats.is_empty():
		await _fail("Balloon Session left its route without a captured finished result/stats")
		return false
	return true

func _release_route_inputs() -> void:
	_set_axis_key_state(Vector2i.ZERO)
	_set_space(false)
	_set_right_mouse(false)
	Input.flush_buffered_events()

func _exit_tree() -> void:
	_release_route_inputs()

func _keyboard_docking_aim(route_point: Vector2) -> Vector2:
	var on_delivery_leg: bool = active.balloon_delivery_index == 0 or active.balloon_delivery_index >= 2
	if not on_delivery_leg or active.p.distance_to(active.target) >= 155.0:
		return route_point
	# Lead the real target by current momentum; the held WASD/arrow keys still
	# produce all movement, while this damping term avoids rushing through the ring.
	return active.target + (active.target - active.p) * 0.18 - active.velocity * 0.34

func _set_keyboard_direction(point: Vector2) -> void:
	var offset: Vector2 = point - active.p
	var wanted := Vector2i.ZERO
	if offset.x > 12.0: wanted.x = 1
	elif offset.x < -12.0: wanted.x = -1
	if offset.y > 12.0: wanted.y = 1
	elif offset.y < -12.0: wanted.y = -1
	_set_axis_key_state(wanted)

func _set_axis_key_state(wanted: Vector2i) -> void:
	if _keyboard_axis.x != wanted.x:
		if _keyboard_axis.x < 0: _held_key(KEY_A, false)
		elif _keyboard_axis.x > 0: _held_key(KEY_D, false)
		if wanted.x < 0: _held_key(KEY_A, true)
		elif wanted.x > 0: _held_key(KEY_D, true)
		_keyboard_axis.x = wanted.x
	if _keyboard_axis.y != wanted.y:
		if _keyboard_axis.y < 0: _held_key(KEY_W, false)
		elif _keyboard_axis.y > 0: _held_key(KEY_S, false)
		if wanted.y < 0: _held_key(KEY_W, true)
		elif wanted.y > 0: _held_key(KEY_S, true)
		_keyboard_axis.y = wanted.y

func _set_space(pressed: bool) -> void:
	if _space_held == pressed:
		return
	_held_key(KEY_SPACE, pressed)
	_space_held = pressed

func _set_right_mouse(pressed: bool) -> void:
	if _right_mouse_held == pressed:
		return
	var event := InputEventMouseButton.new()
	event.position = get_viewport().get_mouse_position()
	event.global_position = event.position
	event.window_id = get_window().get_window_id()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	_right_mouse_held = pressed

func _wait_for_result() -> bool:
	if not await _require_live_main("_wait_for_result"): return false
	var deadline := _wall_deadline(5.0)
	while is_instance_valid(main) and main.modal_kind != "result" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_wait_for_result after frame wait"): return false
	if not is_instance_valid(main) or main.modal_kind != "result" or _case_result.is_empty():
		await _fail("game-001 did not deliver its actual result modal/signal")
		return false
	return true

func _assert_completed_case(label: String, expect_assisted: bool, expect_practice: bool) -> bool:
	if str(_case_result.get("game_id", "")) != "game-001" or not bool(_case_result.get("success", false)):
		await _fail(label + " did not complete the real game-001 objective: " + str(_case_result))
		return false
	if int(_case_stats.get("delivered", -1)) != 3 or int(_case_result.get("score", -1)) != int(_case_stats.get("score", -2)) or int(_case_result.get("score", -1)) != 450:
		await _fail(label + " did not record all three actual 150-point deliveries: " + str(_case_stats))
		return false
	if bool(_case_result.get("assisted", false)) != expect_assisted or bool(_case_result.get("practice", false)) != expect_practice:
		await _fail(label + " result flags do not match the launched run: " + str(_case_result))
		return false
	if int(_case_result.get("mistakes", -1)) != int(_case_stats.get("mistakes", -2)):
		await _fail(label + " result mistake count does not match the live session")
		return false
	if not _case_result.has("success") or not _case_result.has("devil") or not _case_result.has("mistakes") or not _case_result.has("score_summary") or not (_case_result.get("score_summary", {}) is Dictionary) or not (_case_result.score_summary.get("rows", []) is Array):
		await _fail(label + " result is missing the established score-summary schema")
		return false
	if bool(_case_result.devil) != (int(_case_result.mistakes) == 0 and not expect_assisted):
		await _fail(label + " contradicts the zero-error unassisted devil condition");return false
	if not expect_practice:
		var qualification := main.overlay.find_child("ResultQualification", true, false) as Label
		if qualification == null or qualification.text != str(_case_result.score_summary.get("qualification_text", "")):
			await _fail(label + " hides its actual eligibility explanation");return false
	return true

func _check_reduced_wind_legend() -> bool:
	if not await _require_live_session("_check_reduced_wind_legend"): return false
	# These are the actual forces sampled before integration. Re-sampling at the
	# new altitude compares a different wind lane, rather than the applied force.
	var current: Vector2 = active.balloon_wind_current
	var forecast: Vector2 = active.balloon_wind_forecast
	if active.presentation == null or not active.presentation._current_wind.visible or not active.presentation._forecast_wind.visible:
		await _fail("Reduced-motion mode hid a necessary current/forecast wind arrow")
		return false
	for pair in [[active.presentation._current_wind, current], [active.presentation._forecast_wind, forecast]]:
		var arrow: Node3D = pair[0]
		var force: Vector2 = pair[1]
		var direction := force if force.length_squared() >= 0.01 else Vector2.RIGHT
		var expected_size := 0.60 + 0.004 * minf(direction.length(), 60.0)
		if absf(angle_difference(arrow.rotation.y, active.presentation._wind_heading(direction))) > 0.0001 or not arrow.scale.is_equal_approx(Vector3.ONE * expected_size):
			await _fail("Reduced-motion wind arrow heading/strength differs from the applied force/forecast")
			return false
	var indicators: Array = [active.presentation._current_indicator, active.presentation._forecast_indicator]
	for index in 2:
		if not indicators[index].is_visible_in_tree() or not indicators[index].force.is_equal_approx([current,forecast][index]):
			await _fail("Visible canvas wind differs from the real force/forecast");return false
	if not _wind_pixels_verified:
		await RenderingServer.frame_post_draw
		if not await _require_live_session("rendered wind pixel check"): return false
		var image: Image = active.presentation.texture().get_image()
		for index in 2:
			var ink := Color("#62c3b0") if index == 0 else Color("#efbd71")
			var pixels := 0
			# Arrow-only interior: excludes labels, strength values and border.
			for y in range(593 + index*60,629 + index*60):
				for x in range(130,218):
					var color := image.get_pixel(x,y)
					if absf(color.r-ink.r)+absf(color.g-ink.g)+absf(color.b-ink.b) < 0.05: pixels += 1
			if pixels < 20:
				await _fail("Wind direction is covered in actual rendered pixels: row=%d pixels=%d" % [index,pixels]);return false
			print("WIND PIXELS: row=%d visible_direction_pixels=%d" % [index,pixels])
		_wind_pixels_verified = true
	return true

func _return_to_station_info() -> bool:
	if not await _require_live_main("_return_to_station_info"): return false
	var button := _find(main.overlay, "返回遊園")
	if button == null or not await _native_click_button(button, "return to harbor park"):
		return false
	if not await _require_live_main("station action completion"): return false
	var deadline := _wall_deadline(4.0)
	while is_instance_valid(main) and main.modal_kind != "" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not await _require_live_main("_return_to_station_info after frame wait"): return false
	return is_instance_valid(main) and main.modal_kind == ""

func _result_text_contains(fragment: String) -> bool:
	return _find_label_text(main.overlay, fragment)

func _find_label_text(node: Node, fragment: String) -> bool:
	if node is Label and str((node as Label).text).contains(fragment):
		return true
	for child in node.get_children():
		if _find_label_text(child, fragment):
			return true
	return false

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
	_release_route_inputs()
	push_error(message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	if not main._capture(label + ".png"):
		await _fail("Could not preserve exclusive native capture " + label)

func _protected_progress() -> Dictionary:
	return {"photos":progress.photos.duplicate(true), "achievements":progress.achievements.duplicate(true), "quests":progress.quests.duplicate(true), "coins":progress.coins, "owned_clothes":progress.owned_clothes.duplicate(), "wardrobe_rewarded_games":progress.wardrobe_rewarded_games.duplicate(), "pending_achievements":progress.platform_pending_achievements.duplicate()}
