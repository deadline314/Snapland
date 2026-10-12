extends "res://game/tests/native_review.gd"

const GAME_IDS: Array[String] = [
	"game-001", "game-002", "game-003", "game-004", "game-005", "game-006",
	"game-007", "game-008", "game-009", "game-010", "game-011", "game-012"
]
const COMPACT_REPRESENTATIVES: Array[String] = ["game-005", "game-010", "game-012"]
const CAPTURE_ROOT := ".review/native-hud-hierarchy"
const STANDARD_CAPTURE_ROOT := ".review/native-hud-hierarchy-standard"
const MAX_WALL_SECONDS := 120.0

var _wall_started_ms := 0
var _capture_count := 0
var _watchdog_expired := false
var _standard_only := false
var _capture_root := CAPTURE_ROOT

func _process(_delta: float) -> void:
	if _wall_started_ms > 0 and not _watchdog_expired and Time.get_ticks_msec() - _wall_started_ms > int(MAX_WALL_SECONDS * 1000.0):
		_watchdog_expired = true
		push_error("Native HUD hierarchy review exceeded its 120-second wall-clock watchdog")
		if is_instance_valid(main) and is_instance_valid(main.audio):
			main.audio.shutdown()
		get_tree().quit(1)
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	_wall_started_ms = Time.get_ticks_msec()
	_standard_only = OS.get_cmdline_user_args().has("--hud-capture-standard-only")
	if _standard_only:
		_capture_root = STANDARD_CAPTURE_ROOT
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native HUD hierarchy review requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _review_fail("Progress autoload is missing")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	main = _instantiate_main()
	if main == null:
		await _review_fail("Could not instantiate the live Main scene")
		return
	get_tree().root.add_child(main)
	await _frames(8)
	if not await _resize_window(Vector2i(1280, 720)):
		return
	print("NATIVE HUD REVIEW: actual Main station/E/Start, HUD button clicks, screenshots only; no minigame input or result is injected; standard_only=%s" % _standard_only)
	for game_id in GAME_IDS:
		if not await _review_game(game_id):
			return
	if main.session != null:
		await _review_fail("Review left a live minigame session")
		return
	var capture_summary := "12 real station launches, playing/pause/details/help captures"
	if not _standard_only:
		capture_summary += ", compact 800x600 for 005/010/012"
	print("PASS: native HUD hierarchy; %s; captures=%d; no result/completion was tested" % [capture_summary, _capture_count])
	main.world.blocked = true
	main.world.set_process(false)
	main.audio.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0)

func _review_game(game_id: String) -> bool:
	if not _within_watchdog():
		await _review_fail("120-second wall watchdog reached before " + game_id)
		return false
	var station: Dictionary = {}
	for candidate: Dictionary in main.world.points:
		if str(candidate.get("id", "")) == game_id:
			station = candidate
			break
	if station.is_empty():
		await _review_fail("Real park has no station " + game_id)
		return false
	# NativeReview fixtures may position the player at a real point; all menu,
	# session, and HUD actions below go through actual input events.
	main.world.player.global_position = station.get("position", Vector3.ZERO) + Vector3(0.0, 0.3, 0.0)
	if not await _wait_until(func() -> bool: return str(main.world.nearest.get("id", "")) == game_id, "station proximity " + game_id):
		return false
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "E opens details " + game_id):
		return false
	if not await _click_named(main.overlay, "開始遊玩", "Start " + game_id):
		return false
	if not await _wait_until(func() -> bool: return main.session != null and main.session.game_id == game_id, "live session " + game_id):
		return false
	var session_id: int = int(main.session.get_instance_id())
	var hud := main.session.minigame_hud as Control
	if hud == null:
		await _review_fail("Session has no real shared HUD for " + game_id)
		return false
	await _frames(3)
	if not _check_hud_layout(hud, game_id, Vector2i(1280, 720)):
		return false
	if not await _capture("%s-playing-1280.png" % game_id):
		return false

	if not _standard_only and COMPACT_REPRESENTATIVES.has(game_id):
		if not await _resize_window(Vector2i(800, 600)):
			return false
		await _frames(3)
		if not _check_hud_layout(hud, game_id, Vector2i(800, 600)):
			return false
		if not await _capture("%s-playing-800.png" % game_id):
			return false
		if not await _review_details(hud, game_id, "800"):
			return false
		if not await _review_pause(hud, game_id, "800", session_id):
			return false
		if not await _resize_window(Vector2i(1280, 720)):
			return false
		if not await _wait_standard_layout(hud, game_id):
			return false
		if not _check_hud_layout(hud, game_id, Vector2i(1280, 720)):
			return false

	if not await _review_pause(hud, game_id, "1280", session_id):
		return false
	if not await _review_details(hud, game_id, "1280"):
		return false
	if not await _review_help(hud, game_id):
		return false
	if not await _leave_without_result(hud, game_id, session_id):
		return false
	return true

func _review_pause(hud: Control, game_id: String, size_tag: String, session_id: int) -> bool:
	var button := hud.find_child("PauseButton", true, false) as Button
	if not await _click_button(button, "%s pause %s" % [game_id, size_tag]):
		return false
	if not await _wait_until(func() -> bool: return _live_session(session_id) and bool(main.session.paused), "pause callback " + game_id):
		return false
	if size_tag == "1280":
		if not await _standard_panel_height(hud, game_id, "after Pause"):
			return false
		if not _check_hud_layout(hud, game_id, Vector2i(1280, 720)):
			return false
	var overlay := hud.find_child("PauseOverlay", true, false) as Control
	var resume := hud.find_child("ResumeButton", true, false) as Button
	if overlay == null or not overlay.visible or resume == null or not _physical_target_at_least(resume, 44.0):
		await _review_fail("Pause overlay or physical Resume target is missing at %s (%s)" % [game_id, size_tag])
		return false
	if not await _capture("%s-pause-%s.png" % [game_id, size_tag]):
		return false
	if not await _click_button(resume, "%s resume %s" % [game_id, size_tag]):
		return false
	return await _wait_until(func() -> bool: return _live_session(session_id) and not bool(main.session.paused) and not overlay.visible, "resume callback " + game_id)

func _review_details(hud: Control, game_id: String, size_tag: String) -> bool:
	var button := hud.find_child("DetailsButton", true, false) as Button
	if not await _click_button(button, "%s details %s" % [game_id, size_tag]):
		return false
	var overlay := hud.find_child("ScoreDetailsOverlay", true, false) as Control
	var back := hud.find_child("ScoreDetailsBackButton", true, false) as Button
	if overlay == null or not overlay.visible or back == null or not _physical_target_at_least(button, 44.0) or not _physical_target_at_least(back, 44.0):
		await _review_fail("Actual Details click did not expose readable details/back targets for %s at %s" % [game_id, size_tag])
		return false
	if not await _capture("%s-details-%s.png" % [game_id, size_tag]):
		return false
	if not await _click_button(back, "%s details return %s" % [game_id, size_tag]):
		return false
	if overlay.visible:
		await _review_fail("Details return did not restore active play for " + game_id)
		return false
	return true

func _review_help(hud: Control, game_id: String) -> bool:
	var button := hud.find_child("HelpButton", true, false) as Button
	if not await _click_button(button, "%s help" % game_id):
		return false
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel) and main.tutorial_panel.visible and main.tutorial_panel.target_id == game_id, "real session tutorial " + game_id):
		return false
	if not await _capture("%s-help.png" % game_id):
		return false
	var close := main.tutorial_panel.get("_close_button") as Button
	if not await _click_button(close, "%s close tutorial" % game_id):
		return false
	if not await _wait_until(func() -> bool: return not is_instance_valid(main.tutorial_panel) and _live_session(main.session.get_instance_id()) and main.session.paused, "tutorial returns to paused session " + game_id):
		return false
	return true

func _leave_without_result(hud: Control, game_id: String, session_id: int) -> bool:
	if not bool(main.session.paused):
		if not await _click_button(hud.find_child("PauseButton", true, false) as Button, game_id + " pause before exit"):
			return false
		if not await _wait_until(func() -> bool: return _live_session(session_id) and main.session.paused, "pause before exit " + game_id):
			return false
	if not await _click_button(hud.find_child("LeaveButton", true, false) as Button, game_id + " ask leave"):
		return false
	var confirm := hud.find_child("ConfirmOverlay", true, false) as Control
	var confirm_button := hud.find_child("ConfirmAction", true, false) as Button
	if confirm == null or not confirm.visible or confirm_button == null:
		await _review_fail("Leave confirmation did not open for " + game_id)
		return false
	if not await _click_button(confirm_button, game_id + " confirm leave"):
		return false
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "return to park without result " + game_id):
		return false
	print("HUD_NATIVE_GAME_EXIT game=%s session=%d result=none" % [game_id, session_id])
	return true

func _check_hud_layout(hud: Control, game_id: String, physical_size: Vector2i) -> bool:
	var viewport_rect := hud.get_viewport().get_visible_rect()
	var left := hud.find_child("MinigameHeader", true, false) as Control
	var right := hud.find_child("MinigameStatusRail", true, false) as Control
	if left == null or right == null:
		push_error("HUD corner plates are missing for %s" % game_id)
		return false
	var left_rect := left.get_global_rect()
	var right_rect := right.get_global_rect()
	if not viewport_rect.encloses(left_rect) or not viewport_rect.encloses(right_rect) or left_rect.end.x >= right_rect.position.x:
		push_error("HUD plates leave no actual center gap or exceed viewport for %s: left=%s right=%s viewport=%s" % [game_id, left_rect, right_rect, viewport_rect])
		return false
	for name in ["DetailsButton", "HelpButton", "PauseButton"]:
		var button := hud.find_child(name, true, false) as Button
		if button == null or not _physical_target_at_least(button, 44.0):
			push_error("HUD physical target is below 44px for %s/%s at window %s" % [game_id, name, physical_size])
			return false
	print("HUD_BOUNDS game=%s window=%s left=%s right=%s details=%s help=%s pause=%s" % [game_id, physical_size, left_rect, right_rect, _physical_rect(hud.find_child("DetailsButton", true, false) as Button), _physical_rect(hud.find_child("HelpButton", true, false) as Button), _physical_rect(hud.find_child("PauseButton", true, false) as Button)])
	return true

func _wait_standard_layout(hud: Control, game_id: String) -> bool:
	for _frame in 10:
		await get_tree().process_frame
		var header := hud.find_child("MinigameHeader", true, false) as Control
		var rail := hud.find_child("MinigameStatusRail", true, false) as Control
		if is_equal_approx(float(hud.get("_effective_scale")), 1.0) and header != null and rail != null and is_equal_approx(header.size.y, 84.0) and is_equal_approx(rail.size.y, 84.0):
			return true
	await _review_fail("Standard 1280 layout did not recover after compact resize for " + game_id)
	return false

func _standard_panel_height(hud: Control, game_id: String, phase: String) -> bool:
	var header := hud.find_child("MinigameHeader", true, false) as Control
	var rail := hud.find_child("MinigameStatusRail", true, false) as Control
	if header == null or rail == null or not is_equal_approx(header.size.y, 84.0) or not is_equal_approx(rail.size.y, 84.0):
		await _review_fail("Standard HUD plates must be 84 logical pixels after %s for %s: header=%s rail=%s" % [phase, game_id, str(header.size.y if header != null else -1), str(rail.size.y if rail != null else -1)])
		return false
	return true

func _physical_target_at_least(control: Control, minimum: float) -> bool:
	var rect := _physical_rect(control)
	return rect.size.x >= minimum and rect.size.y >= minimum

func _physical_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var transform := control.get_viewport().get_final_transform()
	return transform * control.get_global_rect()

func _click_named(root_node: Node, text: String, context: String) -> bool:
	await _frames(2)
	var button := _find_text_button(root_node, text)
	return await _click_button(button, context)

func _click_button(button: BaseButton, context: String) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		await _review_fail("Native HUD click target missing/hidden/disabled: " + context)
		return false
	# Station/tutorial controls may live in a clipped, scrollable modal. Expose
	# the actual target before sampling its hit rectangle, then wait for the
	# modal's responsive layout to settle.
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _frames(3)
	var viewport := button.get_viewport()
	var logical_rect := button.get_global_rect()
	if not viewport.get_visible_rect().encloses(logical_rect):
		await _review_fail("Native HUD target outside logical viewport: %s rect=%s" % [context, logical_rect])
		return false
	ancestor = button.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			var visible_clip := (ancestor as Control).get_global_rect().intersection(viewport.get_visible_rect())
			if not visible_clip.encloses(logical_rect):
				await _review_fail("Native HUD target remains clipped after scroll reveal: %s rect=%s clip=%s" % [context, logical_rect, visible_clip])
				return false
		ancestor = ancestor.get_parent()
	var observations := {"down": 0, "up": 0, "pressed": 0}
	var on_down := func() -> void: observations.down += 1
	var on_up := func() -> void: observations.up += 1
	var on_pressed := func() -> void: observations.pressed += 1
	button.button_down.connect(on_down)
	button.button_up.connect(on_up)
	button.pressed.connect(on_pressed)
	var point: Vector2 = viewport.get_final_transform() * logical_rect.get_center()
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	motion.button_mask = Input.get_mouse_button_mask()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var hovered := viewport.gui_get_hovered_control()
	if not button.is_hovered() or not (hovered == button or (is_instance_valid(hovered) and button.is_ancestor_of(hovered))):
		button.button_down.disconnect(on_down)
		button.button_up.disconnect(on_up)
		button.pressed.disconnect(on_pressed)
		await _review_fail("Native mouse did not hover HUD target %s: rect=%s point=%s hovered=%s" % [context, logical_rect, point, str(hovered)])
		return false
	for pressed_state in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed_state else 0
		event.pressed = pressed_state
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	if is_instance_valid(button):
		button.button_down.disconnect(on_down)
		button.button_up.disconnect(on_up)
		button.pressed.disconnect(on_pressed)
	if observations.down != 1 or observations.up != 1 or observations.pressed != 1:
		await _review_fail("Native click did not complete exactly one down/up/pressed for %s: %s" % [context, observations])
		return false
	await _frames(2)
	if not _within_watchdog():
		await _review_fail("120-second wall watchdog expired during " + context)
		return false
	return true

func _find_text_button(root_node: Node, text: String) -> Button:
	if root_node is Button and (root_node as Button).text.contains(text):
		return root_node as Button
	for child in root_node.get_children():
		var found := _find_text_button(child, text)
		if found != null:
			return found
	return null

func _live_session(instance_id: int) -> bool:
	return is_instance_valid(main) and is_instance_valid(main.session) and main.session.get_instance_id() == instance_id

func _resize_window(target: Vector2i) -> bool:
	DisplayServer.window_set_size(target)
	var deadline := Time.get_ticks_msec() + ceili(2500.0 / maxf(Engine.time_scale, 0.01))
	while DisplayServer.window_get_size() != target and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if DisplayServer.window_get_size() != target:
		await _review_fail("Native window size mismatch; requested=%s actual=%s" % [target, DisplayServer.window_get_size()])
		return false
	await _frames(4)
	await RenderingServer.frame_post_draw
	return true

func _wait_until(predicate: Callable, context: String) -> bool:
	var deadline := Time.get_ticks_msec() + ceili(8000.0 / maxf(Engine.time_scale, 0.01))
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not _within_watchdog():
			await _review_fail("120-second wall watchdog while waiting for " + context)
			return false
	if not predicate.call():
		await _review_fail("Native HUD review timed out waiting for " + context)
		return false
	return true

func _capture(suffix: String) -> bool:
	await RenderingServer.frame_post_draw
	if not main._capture(_capture_root + "/" + suffix):
		await _review_fail("Could not write native HUD capture " + suffix)
		return false
	_capture_count += 1
	return true

func _within_watchdog() -> bool:
	return float(Time.get_ticks_msec() - _wall_started_ms) <= MAX_WALL_SECONDS * 1000.0

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _review_fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(1)
