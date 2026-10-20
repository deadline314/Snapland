extends Node

const NativeReviewBase = preload("res://game/tests/native_review.gd")
const GLOBAL_TIMEOUT_SECONDS := 360.0
const PER_GAME_TIMEOUT_SECONDS := 60.0
var main: Node
var failures: Array[String] = []
var finished := false
var active_game := ""
var active_phase := "startup"
var global_deadline_msec := 0
var game_deadline_msec := 0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if not finished and global_deadline_msec > 0 and now >= global_deadline_msec:
		_watchdog("global 360-second wall-clock deadline")
	elif not finished and game_deadline_msec > 0 and now >= game_deadline_msec:
		_watchdog("%s exceeded 60 seconds during %s" % [active_game, active_phase])
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native tutorial lifecycle review requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	global_deadline_msec = Time.get_ticks_msec() + int(GLOBAL_TIMEOUT_SECONDS * 1000.0)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var first_game := 1
	var last_game := 12
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tutorial-first=") or argument.begins_with("--tutorial-last="):
			var value: String = argument.get_slice("=", 1)
			_check(value.is_valid_int(), "tutorial batch bounds are integers")
			if argument.begins_with("--tutorial-first="): first_game = value.to_int()
			else: last_game = value.to_int()
	_check(first_game >= 1 and last_game <= 12 and first_game <= last_game, "tutorial batch stays within the twelve real games")
	if not failures.is_empty():
		_finish(1)
		return
	var progress := get_tree().root.get_node_or_null("Progress")
	_check(progress != null, "Progress autoload exists")
	if progress == null:
		_finish()
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.save_progress()
	for number in range(1, 13):
		_check(not progress.has_seen_tutorial("game-%03d" % number), "new-player fixture leaves game-%03d unseen" % number)
	var native_review := NativeReviewBase.new()
	main = native_review._instantiate_main(false)
	native_review.free()
	get_tree().root.add_child(main)
	await get_tree().create_timer(0.5).timeout
	for number in range(first_game, last_game + 1):
		if finished: return
		_begin_game_watchdog("game-%03d" % number)
		await _review_game(number, progress)
		_end_game_watchdog()
		if not failures.is_empty():
			_finish(1)
			return
	_finish()

func _review_game(number: int, progress: Node) -> void:
	var id := "game-%03d" % number
	var game_failure_count := failures.size()
	_set_phase(id, "select station")
	var station: Dictionary = {}
	for point in main.world.points:
		if str(point.get("id", "")) == id:
			station = point
	_check(not station.is_empty(), id + " station is present")
	if station.is_empty(): return
	# Station positioning is the sole fixture shortcut; all menus, tutorial navigation,
	# pause/resume, and session help are activated through window input events.
	main.world.player.position = station.position + Vector3(0, 0.3, 0)
	await _settle_near_station(id)
	await _key(KEY_E)
	await _wait_until(func(): return main.modal_kind == "game_info", id + " info screen")
	if main.modal_kind != "game_info": return
	_check(not Progress.has_seen_tutorial(id), id + " begins with an unseen tutorial")
	_set_phase(id, "first Start opens tutorial")
	await _click_text(main.overlay, "開始遊玩")
	await _wait_until(func(): return is_instance_valid(main.tutorial_panel), id + " first-entry tutorial from Start")
	if not is_instance_valid(main.tutorial_panel): return
	var panel: Control = main.tutorial_panel
	_check(panel.current_step_data().size() > 0 and panel.current_step_data().has("image"), id + " first lesson step has real screenshot data")
	_assert_lesson_image(panel, id + " step 1")
	await _review_copy_pages(panel, id + " step 1")
	await _draw_and_capture("%s-first-step.png" % id)
	for step in range(1, 3):
		_set_phase(id, "navigate tutorial step %d" % (step + 1))
		var use_keyboard := (number + step) % 2 == 0
		if use_keyboard:
			await _key(KEY_RIGHT)
		else:
			await _click_text(panel, "下一步")
		_check(panel.current_step == step, "%s lesson reaches step %d by %s input" % [id, step + 1, "keyboard" if use_keyboard else "mouse"])
		_assert_lesson_image(panel, id + " step " + str(step + 1))
		await _review_copy_pages(panel, id + " step " + str(step + 1))
		await _draw_and_capture("%s-step-%02d.png" % [id, step + 1])
	_set_phase(id, "keyboard previous/next round trip")
	await _key(KEY_LEFT)
	_check(panel.current_step == 1, id + " keyboard Left returns to the prior step")
	_assert_lesson_image(panel, id + " keyboard Left")
	await _key(KEY_RIGHT)
	_check(panel.current_step == 2, id + " keyboard Right returns to the last step")
	_assert_lesson_image(panel, id + " keyboard Right")
	var launch_label := "開始挑戰" if number % 2 == 1 else "略過"
	_set_phase(id, "launch via " + launch_label)
	await _click_text(panel, launch_label)
	await _wait_until(func(): return main.session != null, id + " " + launch_label + " starts selected session")
	if main.session == null: return
	var session: Node = main.session
	_check(session.game_id == id, id + " begins the selected game")
	_check(Progress.has_seen_tutorial(id), id + " Begin or Skip persists learned state")
	await _wait_until(func(): return not is_instance_valid(main.tutorial_panel), id + " tutorial closes after begin")
	await _wait_frames(3)
	var before := _persistent_snapshot(progress)
	_set_phase(id, "HUD help pauses session")
	await _click_named(session, "HelpButton")
	await _wait_until(func(): return is_instance_valid(main.tutorial_panel) and session.paused, id + " HUD help pauses session")
	if not is_instance_valid(main.tutorial_panel): return
	var elapsed_before := float(session.elapsed)
	var game_time_before := float(session.game_time)
	panel = main.tutorial_panel
	_set_phase(id, "capture real HUD help")
	await _draw_and_capture("%s-help-step-01.png" % id)
	await _wait_frames(90)
	_check(is_equal_approx(float(session.elapsed), elapsed_before), id + " tutorial holds round duration")
	_check(is_equal_approx(float(session.game_time), game_time_before), id + " tutorial holds model clock")
	_check(before == _persistent_snapshot(progress), id + " help leaves progress and equipment/platform data unchanged")
	_set_phase(id, "close HUD help to paused session")
	await _click_text(panel, "關閉")
	await _wait_until(func(): return not is_instance_valid(main.tutorial_panel) and session.paused, id + " closing help returns to paused session")
	_check(before == _persistent_snapshot(progress), id + " close leaves persistent state unchanged")
	_set_phase(id, "explicit resume advances clocks")
	await _click_named(session.minigame_hud, "ResumeButton")
	await _wait_until(func(): return not session.paused, id + " ResumeButton restores the running session")
	if id == "game-001" and not session.balloon_started:
		_set_phase(id, "real Enter starts the timed Balloon round")
		await _key(KEY_ENTER)
		await _wait_until(func(): return session.balloon_started, id + " Enter starts Balloon timed play")
	await _wait_frames(45)
	_check(not session.paused and not session.ended, id + " resumed session remains active while clocks advance")
	_check(float(session.elapsed) > elapsed_before, id + " explicit resume advances duration")
	_check(float(session.game_time) > game_time_before, id + " explicit resume advances model clock")
	_set_phase(id, "pause menu replay path")
	await _click_named(session.minigame_hud, "PauseButton")
	await _wait_until(func(): return session.paused, id + " actual pause button pauses")
	await _click_named(session.minigame_hud, "HelpFromPauseButton")
	await _wait_until(func(): return is_instance_valid(main.tutorial_panel), id + " pause menu can reopen lesson")
	if not is_instance_valid(main.tutorial_panel): return
	panel = main.tutorial_panel
	_check(panel.current_step == 0, id + " manual replay starts at first step")
	_set_phase(id, "capture manually reopened help")
	await _draw_and_capture("%s-help-reopened.png" % id)
	await _click_text(panel, "關閉")
	await _wait_until(func(): return not is_instance_valid(main.tutorial_panel) and session.paused, id + " replay close retains pause")
	_check(before == _persistent_snapshot(progress), id + " replay leaves persistent state unchanged")
	_set_phase(id, "confirmed leave and direct reentry")
	await _click_named(session.minigame_hud, "LeaveButton")
	await _wait_until(func(): return session.minigame_hud.find_child("ConfirmAction", true, false) != null, id + " leave confirmation opens")
	await _click_named(session.minigame_hud, "ConfirmAction")
	await _wait_until(func(): return main.session == null, id + " confirmed leave returns to park")
	_check(main.modal_kind == "", id + " returns to park without an overlay")
	await _key(KEY_E)
	await _wait_until(func(): return main.modal_kind == "game_info", id + " reentry information screen")
	_check(not is_instance_valid(main.tutorial_panel), id + " reentry does not automatically reopen tutorial")
	await _click_text(main.overlay, "開始遊玩")
	await _wait_until(func(): return main.session != null, id + " reentry launches directly")
	_check(not is_instance_valid(main.tutorial_panel), id + " reentry skips first-entry tutorial")
	if main.session == null: return
	var practice_session: Node = main.session
	var private_before := _persistent_snapshot(progress)
	_set_phase(id, "reentry pause to private practice")
	await _click_named(practice_session.minigame_hud, "PauseButton")
	await _wait_until(func(): return practice_session.paused, id + " returning session pauses before private practice")
	await _click_named(practice_session.minigame_hud, "PracticeButton")
	await _wait_until(func(): return practice_session.practice_mode and not practice_session.paused, id + " actual pause action starts private practice")
	_check(main.session == practice_session, id + " private practice remains the actual Main session")
	_check(practice_session.practice_mode, id + " practice HUD action marks the session private")
	_check(private_before == _persistent_snapshot(progress), id + " starting private practice leaves the tracked progress snapshot unchanged")
	_set_phase(id, "private practice Help freezes clocks")
	await _click_named(practice_session.minigame_hud, "HelpButton")
	await _wait_until(func(): return is_instance_valid(main.tutorial_panel) and practice_session.paused, id + " private practice Help pauses and opens the tutorial")
	if not is_instance_valid(main.tutorial_panel): return
	var practice_elapsed_before := float(practice_session.elapsed)
	var practice_clock_before := float(practice_session.game_time)
	_check(main.tutorial_origin == "session" and main.tutorial_target == id, id + " private Help displays this game's session tutorial")
	await _wait_frames(90)
	_check(is_equal_approx(float(practice_session.elapsed), practice_elapsed_before), id + " private tutorial holds round duration")
	_check(is_equal_approx(float(practice_session.game_time), practice_clock_before), id + " private tutorial holds model clock")
	_check(private_before == _persistent_snapshot(progress), id + " private tutorial does not alter tracked progression")
	var private_panel: Control = main.tutorial_panel
	await _draw_and_capture("%s-private-help-step-01.png" % id)
	await _click_text(private_panel, "關閉")
	await _wait_until(func(): return not is_instance_valid(main.tutorial_panel) and practice_session.paused, id + " private Help closes back to paused practice")
	_check(private_before == _persistent_snapshot(progress), id + " closing private Help leaves tracked progression unchanged")
	_set_phase(id, "reopen private practice tutorial")
	await _click_named(practice_session.minigame_hud, "HelpFromPauseButton")
	await _wait_until(func(): return is_instance_valid(main.tutorial_panel), id + " private pause menu reopens its tutorial")
	if not is_instance_valid(main.tutorial_panel): return
	_check(main.tutorial_panel.current_step == 0, id + " private tutorial replay starts at its first step")
	private_panel = main.tutorial_panel
	await _click_text(private_panel, "關閉")
	await _wait_until(func(): return not is_instance_valid(main.tutorial_panel) and practice_session.paused, id + " private replay returns to paused practice")
	_check(private_before == _persistent_snapshot(progress), id + " replaying private Help leaves tracked progression unchanged")
	_set_phase(id, "confirmed private leave and post-practice reentry")
	await _click_named(practice_session.minigame_hud, "LeaveButton")
	await _wait_until(func(): return practice_session.minigame_hud.find_child("ConfirmAction", true, false) != null, id + " private leave confirmation opens")
	await _click_named(practice_session.minigame_hud, "ConfirmAction")
	await _wait_until(func(): return main.session == null, id + " confirmed private leave returns to park")
	_check(main.modal_kind == "" and not is_instance_valid(main.tutorial_panel), id + " private leave restores park without a lesson overlay")
	_check(private_before == _persistent_snapshot(progress), id + " returning from private practice leaves tracked progression unchanged")
	await _key(KEY_E)
	await _wait_until(func(): return main.modal_kind == "game_info", id + " post-practice Start information screen")
	_check(not is_instance_valid(main.tutorial_panel), id + " practice return keeps the game marked learned")
	await _click_text(main.overlay, "開始遊玩")
	await _wait_until(func(): return main.session != null, id + " post-practice Start launches directly")
	_check(not is_instance_valid(main.tutorial_panel), id + " post-practice Start does not repeat the tutorial")
	_check(main.session != null and not main.session.practice_mode, id + " direct post-practice launch remains a formal session")
	if main.session != null:
		var final_session: Node = main.session
		await _click_named(final_session.minigame_hud, "PauseButton")
		await _wait_until(func(): return final_session.paused, id + " final returning session pauses")
		await _click_named(final_session.minigame_hud, "LeaveButton")
		await _wait_until(func(): return final_session.minigame_hud.find_child("ConfirmAction", true, false) != null, id + " final leave confirmation opens")
		await _click_named(final_session.minigame_hud, "ConfirmAction")
		await _wait_until(func(): return main.session == null, id + " final confirmed leave returns to park")
	_check(private_before == _persistent_snapshot(progress), id + " all returning and private flows preserve tracked progression")
	_set_phase(id, "completed first-entry, formal help, private practice, and reentry")
	if failures.size() == game_failure_count:
		print("PASS: native tutorial lifecycle " + id)
	else:
		print("FAIL: native tutorial lifecycle %s (%d failure(s))" % [id, failures.size() - game_failure_count])

func _settle_near_station(id: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and str(main.world.nearest.get("id", "")) != id:
		await get_tree().physics_frame
	_check(str(main.world.nearest.get("id", "")) == id, id + " is selected by proximity")

func _wait_until(predicate: Callable, label: String, seconds := 3.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(predicate.call(), "timed out waiting for " + label)

func _wait_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame

func _click_text(root: Node, label: String) -> void:
	var found := _find_button(root, label)
	if found == null:
		_check(false, "button is visible for pointer click: " + label)
		return
	await _native_click(found, label)

func _click_named(root: Node, node_name: String) -> void:
	var found := root.find_child(node_name, true, false) as BaseButton
	if found == null:
		_check(false, "named button exists for pointer click: " + node_name)
		return
	await _native_click(found, node_name)

func _find_button(root: Node, label: String) -> BaseButton:
	if root == null: return null
	for child in root.get_children():
		if child is BaseButton and str(child.text) == label and child.is_visible_in_tree() and not child.disabled:
			return child
		var nested := _find_button(child, label)
		if nested != null: return nested
	return null

func _native_click(button: BaseButton, context: String) -> void:
	if not button.is_visible_in_tree() or button.disabled:
		_check(false, "click target is visible and enabled: " + context)
		return
	for ancestor in _ancestors(button):
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
	await _wait_frames(2)
	var viewport := button.get_viewport()
	var point: Vector2 = viewport.get_final_transform() * button.get_global_rect().get_center()
	Input.flush_buffered_events()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_check(button.is_hovered(), "real pointer reaches " + context)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _wait_frames(2)

func _ancestors(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	var parent := node.get_parent()
	while parent != null:
		result.append(parent)
		parent = parent.get_parent()
	return result

func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.window_id = get_window().get_window_id()
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame

func _draw_and_capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image != null and not image.is_empty(), "post-draw viewport image exists: " + filename)
	if image == null or image.is_empty(): return
	var folder := ProjectSettings.globalize_path("res://.review/main10-lifecycle-evidence")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join(filename)
	_check(image.save_png(path) == OK, "native post-draw screenshot saved: " + path)

func _assert_lesson_image(panel: Control, context: String) -> void:
	_check(panel._image.texture is Texture2D and not panel._image_placeholder.visible, context + " displays its actual tutorial screenshot")

func _review_copy_pages(panel: Control, context: String) -> void:
	await _wait_frames(4)
	var seen: Array[bool] = [false, false, false, false, false]
	_check(panel._copy_sections.size() == 5, context + " retains all five instruction fields")
	for page_index in range(panel._copy_pages.size()):
		if page_index > 0:
			await _click_named(panel, "TutorialCopyNext")
		await _wait_frames(2)
		_check(panel._copy_page == page_index, context + " actual pointer opens copy page " + str(page_index))
		var clip: Rect2 = panel._text_scroll.get_global_rect()
		var group: Control = panel._copy_pages[page_index]
		_check(clip.encloses(group.get_global_rect()), context + " complete page fits without scrolling")
		for index in range(panel._copy_sections.size()):
			var section: Control = panel._copy_sections[index]
			if not section.is_visible_in_tree() or not clip.intersects(section.get_global_rect()): continue
			var readable := clip.encloses(section.get_global_rect())
			_check(readable, context + " complete field " + str(index) + " is visible")
			if readable: seen[index] = true
			for label in section.get_children():
				if label is Label:
					_check(clip.grow(1).encloses(label.get_global_rect()), context + " visible text is not partially clipped")
	for index in range(seen.size()):
		_check(seen[index], context + " field " + str(index) + " was actually shown")
	while panel._copy_page > 0:
		await _click_named(panel, "TutorialCopyPrevious")

func _persistent_snapshot(progress: Node) -> Dictionary:
	return {
		"photos": progress.photos.duplicate(true),
		"achievements": progress.achievements.duplicate(true),
		"quests": progress.quests.duplicate(true),
		"appearance": progress.appearance.duplicate(true),
		"equipped": progress.equipped.duplicate(true),
		"owned_clothes": progress.owned_clothes.duplicate(true),
		"coins": progress.coins,
		"platform_pending_achievements": progress.platform_pending_achievements.duplicate(true),
		"tutorial_seen_games": progress.tutorial_seen_games.duplicate(true),
	}

func _begin_game_watchdog(id: String) -> void:
	active_game = id
	active_phase = "starting"
	game_deadline_msec = Time.get_ticks_msec() + int(PER_GAME_TIMEOUT_SECONDS * 1000.0)
	print("NATIVE LIFECYCLE: ", id, " phase=starting (60-second wall-clock deadline)")

func _end_game_watchdog() -> void:
	game_deadline_msec = 0
	active_game = ""
	active_phase = "between games"

func _set_phase(id: String, phase: String) -> void:
	active_game = id
	active_phase = phase
	print("NATIVE LIFECYCLE: ", id, " phase=", phase)

func _watchdog(reason: String) -> void:
	if finished: return
	finished = true
	push_error("FAIL: tutorial lifecycle watchdog %s; game=%s phase=%s" % [reason, active_game, active_phase])
	get_tree().quit(1)

func _finish(exit_code := -1) -> void:
	if finished: return
	finished = true
	if exit_code < 0: exit_code = 1 if not failures.is_empty() else 0
	if main != null and is_instance_valid(main):
		if is_instance_valid(main.world):
			main.world.set_process(false)
			main.world.set_physics_process(false)
		if is_instance_valid(main.audio): main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
