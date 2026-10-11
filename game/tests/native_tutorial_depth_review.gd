extends "res://game/tests/native_layout_review.gd"

const CatalogScript := preload("res://game/ui/tutorial_catalog.gd")
const TutorialPanelScript := preload("res://game/ui/tutorial_panel.gd")
const SCREENSHOT_DIR := "pm/Snapland-main/images"
const MAIN_SCREENSHOT_PREFIX := "MAIN-10-"

var _short_review := false
var _review_step_count := 0
var _capture_count := 0

func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _run() -> void:
	if OS.get_cmdline_user_args().has("--tutorial-review-controls-only"):
		await _run_controls_only()
		return
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native tutorial depth review requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _review_fail("Progress autoload is missing")
		return
	var catalog: RefCounted = CatalogScript.new()
	var catalog_report: Dictionary = catalog.validation_report()
	if not bool(catalog_report.get("ok", false)) or int(catalog_report.get("lesson_count", 0)) != 13:
		await _review_fail("Tutorial catalog is not complete: %s" % str(catalog_report))
		return
	_short_review = OS.get_cmdline_user_args().has("--tutorial-review-short")
	_review_step_count = 0
	_capture_count = 0
	progress.reset_progress()
	progress.intro_seen = true
	progress.set_setting("reduced_motion", false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	main = _instantiate_main()
	if main == null:
		await _review_fail("Could not instantiate the live main scene")
		return
	get_tree().root.add_child(main)
	await _frames(8)
	if not await _resize_window(Vector2i(1280, 720)):
		return
	print("TUTORIAL REVIEW FIXTURE: station entry uses fixture teleport plus real E input; no mini-game completion is simulated or asserted")
	if not await _review_park_lesson():
		return
	var lesson_ids: Array[String] = ["game-001"]
	if not _short_review:
		lesson_ids.clear()
		for lesson_id in catalog.lesson_ids():
			if lesson_id.begins_with("game-"):
				lesson_ids.append(lesson_id)
	for lesson_id in lesson_ids:
		if not await _review_game_lesson(lesson_id):
			return
	if not _short_review:
		if not await _review_responsive_reduced_motion():
			return
		if not await _review_additional_main_ui():
			return
	progress.set_setting("reduced_motion", false)
	if main.session != null:
		await _review_fail("Tutorial review ended with a live game session")
		return
	print("PASS: native tutorial depth UI review only; captures=%d lesson_steps=%d; no minigame result or completion was tested" % [_capture_count, _review_step_count])
	main.world.blocked = true
	main.world.set_process(false)
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0)

func _run_controls_only() -> void:
	var catalog: RefCounted = CatalogScript.new()
	var catalog_report: Dictionary = catalog.validation_report()
	if not bool(catalog_report.get("ok", false)) or int(catalog_report.get("lesson_count", 0)) != 13:
		await _review_fail("Tutorial catalog preflight failed: %s" % str(catalog_report))
		return
	var panel: Control = TutorialPanelScript.new()
	add_child(panel)
	await get_tree().process_frame
	var lesson_ids: Array[String] = catalog.lesson_ids()
	var verified_steps := 0
	for lesson_id in lesson_ids:
		var lesson: Dictionary = catalog.get_lesson(lesson_id)
		var opened: bool = await panel.open_tutorial(lesson_id)
		if not opened:
			await _review_fail("Tutorial panel refused lesson %s" % lesson_id)
			return
		var steps: Array = lesson.get("steps", [])
		for step_index in range(steps.size()):
			if not await _verify_panel_step(panel, lesson_id, lesson, step_index):
				return
			verified_steps += 1
			if step_index + 1 < steps.size():
				panel.next_step()
		if steps.size() > 1:
			panel.previous_step()
			if panel.current_step != steps.size() - 2:
				await _review_fail("Previous-step control did not change state for %s" % lesson_id)
				return
		panel.replay()
		if panel.current_step != 0:
			await _review_fail("Replay did not return to step 1 for %s" % lesson_id)
	print("PASS: tutorial controls/assets preflight; lessons=%d steps=%d imported_screenshots=39; GPU navigation/capture not run" % [lesson_ids.size(), verified_steps])
	panel.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _verify_panel_step(panel: Control, lesson_id: String, lesson: Dictionary, step_index: int) -> bool:
	var steps: Array = lesson.get("steps", [])
	if step_index < 0 or step_index >= steps.size() or not steps[step_index] is Dictionary:
		await _review_fail("Invalid fixture step index %s/%d" % [lesson_id, step_index])
		return false
	var step: Dictionary = steps[step_index]
	var image_path := str(step.get("image", ""))
	if not ResourceLoader.exists(image_path):
		await _review_fail("Tutorial screenshot was not imported: %s" % image_path)
		return false
	var image := ResourceLoader.load(image_path) as Texture2D
	var rendered := panel.get("_image") as TextureRect
	if image == null or image.get_width() != 1280 or image.get_height() != 720:
		await _review_fail("Tutorial source must load as 1280x720: %s" % image_path)
		return false
	if rendered == null or rendered.texture == null or rendered.texture.get_size() != Vector2(1280, 720):
		await _review_fail("Tutorial step image did not render at its authored aspect: %s" % image_path)
		return false
	if str(panel.get("target_id")) != lesson_id or int(panel.get("current_step")) != step_index:
		await _review_fail("Tutorial panel step/title state mismatched %s/%d" % [lesson_id, step_index + 1])
		return false
	for private_label in ["_step_title", "_goal_label", "_input_label", "_success_label", "_ordinary_label", "_bonus_label", "_image_alt"]:
		var label := panel.get(private_label) as Label
		if label == null or label.text.strip_edges().is_empty():
			await _review_fail("Tutorial copy is missing at %s/%d (%s)" % [lesson_id, step_index + 1, private_label])
			return false
	if (panel.get("_step_title") as Label).text != str(step.get("title", "")):
		await _review_fail("Rendered step title differs from catalog: %s/%d" % [lesson_id, step_index + 1])
		return false
	var aspect := rendered.get_parent() as AspectRatioContainer
	if aspect == null or not is_equal_approx(aspect.ratio, 16.0 / 9.0) or rendered.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		await _review_fail("Tutorial screenshot aspect-ratio container is not preserving 16:9")
		return false
	return true

func _review_park_lesson() -> bool:
	if main.modal_kind == "":
		await _tap_key(KEY_M)
		await _frames(2)
	if main.modal_kind != "ticket":
		await _review_fail("Keyboard M did not open the voyage ticket")
		return false
	await _capture_main("park-ticket", "ticket")
	var park_button := _find_text_button(main.overlay, "園區圖解教學")
	if park_button == null:
		await _review_fail("Ticket is missing its park tutorial button")
		return false
	var scroll := _find_scroll_container(main.overlay)
	if scroll != null:
		scroll.ensure_control_visible(park_button)
		await _frames(2)
	if not await _click_control(park_button): return false
	await _frames(3)
	if not await _assert_tutorial_open("park", "ticket"):
		return false
	var player_before: Vector3 = main.world.player.global_position
	if not bool(main.world.blocked):
		await _review_fail("Park tutorial did not retain the blocking ticket modal")
		return false
	await _tap_key(KEY_W)
	await get_tree().create_timer(0.35).timeout
	await _tap_key(KEY_W)
	if main.world.player.global_position.distance_to(player_before) > 0.01:
		await _review_fail("Park player moved while tutorial was open")
		return false
	if not await _capture_lesson_steps("park"):
		return false
	var tutorial := main.tutorial_panel as Control
	if not await _click_control(tutorial.get("_previous_button") as Button): return false
	await _frames(1)
	if int(tutorial.get("current_step")) != 1:
		await _review_fail("Previous button did not navigate to step 2")
		return false
	if not await _click_control(tutorial.get("_replay_button") as Button): return false
	await _frames(1)
	if int(tutorial.get("current_step")) != 0:
		await _review_fail("Replay button did not return to step 1")
		return false
	if not await _click_control(tutorial.get("_next_button") as Button): return false
	await _tap_key(KEY_RIGHT)
	if int(tutorial.get("current_step")) != 2:
		await _review_fail("Next button and Right Arrow did not advance the park tutorial")
		return false
	var ticket_focus_button := park_button
	if not await _click_control(tutorial.get("_close_button") as Button): return false
	await _frames(3)
	if is_instance_valid(main.tutorial_panel) or main.modal_kind != "ticket":
		await _review_fail("Closing the park lesson did not return to its ticket modal")
		return false
	if not await _assert_focus_returned(ticket_focus_button, "ticket after park tutorial close"):
		return false
	# The skip action returns to the same ticket without starting anything.
	park_button = _find_text_button(main.overlay, "園區圖解教學")
	if not await _click_control(park_button): return false
	await _frames(3)
	tutorial = main.tutorial_panel as Control
	if not await _click_control(tutorial.get("_skip_button") as Button): return false
	await _frames(3)
	if is_instance_valid(main.tutorial_panel) or main.modal_kind != "ticket" or main.session != null:
		await _review_fail("Park lesson skip did not return to the ticket without starting a game")
		return false
	if not await _assert_focus_returned(park_button, "ticket after park tutorial skip"):
		return false
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	return true

func _review_game_lesson(lesson_id: String) -> bool:
	var point: Dictionary = {}
	for candidate: Dictionary in main.world.points:
		if str(candidate.get("id", "")) == lesson_id:
			point = candidate
			break
	if point.is_empty():
		await _review_fail("Fixture cannot find station %s" % lesson_id)
		return false
	# The fixture positions the character at the marked station; it does not simulate play.
	main.world.player.global_position = point.get("position", Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if str(main.world.nearest.get("id", "")) != lesson_id:
		await _review_fail("Fixture placement did not activate station %s" % lesson_id)
		return false
	await _tap_key(KEY_E)
	await _frames(2)
	if main.modal_kind != "game_info":
		await _review_fail("Real E input did not open station details for %s" % lesson_id)
		return false
	var tutorial_button := _find_text_button(main.overlay, "圖解教學")
	if tutorial_button == null:
		await _review_fail("Station details have no tutorial button for %s" % lesson_id)
		return false
	if not await _click_control(tutorial_button): return false
	await _frames(3)
	if not await _assert_tutorial_open(lesson_id, "game_info"):
		return false
	if not await _capture_lesson_steps(lesson_id):
		return false
	var tutorial := main.tutorial_panel as Control
	if lesson_id == "game-001":
		if not await _click_control(tutorial.get("_replay_button") as Button): return false
		await _frames(1)
		if not await _click_control(tutorial.get("_start_button") as Button): return false
		await _frames(4)
		if main.session == null or main.session.game_id != lesson_id or main.session.practice_mode:
			await _review_fail("Start button did not launch an ordinary %s session" % lesson_id)
			return false
		if not await _review_session_pause_and_practice():
			return false
		return true
	if not await _click_control(tutorial.get("_close_button") as Button): return false
	await _frames(3)
	if is_instance_valid(main.tutorial_panel) or main.modal_kind != "game_info":
		await _review_fail("Closing %s tutorial did not return to station details" % lesson_id)
		return false
	if not await _assert_focus_returned(tutorial_button, "station details after tutorial close"):
		return false
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	return true

func _capture_lesson_steps(lesson_id: String) -> bool:
	var catalog: RefCounted = CatalogScript.new()
	var lesson: Dictionary = catalog.get_lesson(lesson_id)
	var steps: Array = lesson.get("steps", [])
	if steps.size() < 2 or steps.size() > 3:
		await _review_fail("Lesson %s does not contain two or three steps" % lesson_id)
		return false
	var tutorial := main.tutorial_panel as Control
	for step_index in range(steps.size()):
		if not await _verify_panel_step(tutorial, lesson_id, lesson, step_index):
			return false
		if not await _check_tutorial_copy_scrollable(tutorial):
			return false
		if not await _capture_main("%s-step-%02d" % [lesson_id, step_index + 1], lesson_id):
			return false
		_review_step_count += 1
		if step_index + 1 < steps.size():
			if step_index == 0:
				await _tap_key(KEY_RIGHT)
			else:
				if not await _click_control(tutorial.get("_next_button") as Button): return false
			await _frames(2)
			if int(tutorial.get("current_step")) != step_index + 1:
				await _review_fail("Next navigation did not advance %s to step %d" % [lesson_id, step_index + 2])
				return false
	return true

func _assert_tutorial_open(target_id: String, origin: String) -> bool:
	var tutorial := main.tutorial_panel as Control
	# The real button callback creates the panel and `open_tutorial()` awaits
	# the newly-added Control's `ready` signal. Allow that normal UI lifecycle
	# to settle before diagnosing a missed or misrouted click.
	for _attempt in range(30):
		if tutorial != null and tutorial.visible:
			break
		await get_tree().process_frame
		tutorial = main.tutorial_panel as Control
	if tutorial == null or not tutorial.visible or str(tutorial.get("target_id")) != target_id or main.tutorial_origin != origin:
		var actual_target := "<no panel>" if tutorial == null else str(tutorial.get("target_id"))
		var actual_visible := false if tutorial == null else tutorial.visible
		await _review_fail("Tutorial panel target/origin mismatch: expected %s from %s; actual target=%s origin=%s modal=%s visible=%s" % [target_id, origin, actual_target, main.tutorial_origin, main.modal_kind, actual_visible])
		return false
	if not _focus_is_inside(tutorial):
		await _review_fail("Tutorial did not receive initial keyboard focus for %s" % target_id)
		return false
	var viewport_rect: Rect2 = main.get_viewport().get_visible_rect()
	var card := tutorial.find_child("TutorialCard", true, false) as Control
	if card == null or not viewport_rect.encloses(card.get_global_rect()):
		await _review_fail("Tutorial card does not fit the logical viewport at %s; card=%s minimum=%s viewport=%s scale=%s" % [target_id, str(card.get_global_rect()) if card != null else "missing", str(card.get_combined_minimum_size()) if card != null else "missing", viewport_rect, str(main.get_viewport().get_final_transform())])
		return false
	if not await _inspect_controls(tutorial, viewport_rect):
		return false
	return true

func _review_session_pause_and_practice() -> bool:
	var session: Control = main.session
	var help_button := session.minigame_hud.find_child("HelpButton", true, false) as Button
	if help_button == null:
		await _review_fail("Started minigame has no live help control")
		return false
	await get_tree().create_timer(0.3).timeout
	if not await _click_control(help_button): return false
	await _frames(3)
	if main.tutorial_panel == null or not session.paused or main.tutorial_origin != "session":
		await _review_fail("Live session help did not pause and open its tutorial")
		return false
	var elapsed_before: float = session.elapsed
	await get_tree().create_timer(0.6).timeout
	if not is_equal_approx(session.elapsed, elapsed_before):
		await _review_fail("Session elapsed time advanced while its tutorial was open")
		return false
	await _capture_main("game-001-session-help-step-01", "game-001")
	var tutorial := main.tutorial_panel as Control
	if not await _click_control(tutorial.get("_close_button") as Button): return false
	await _frames(3)
	if main.tutorial_panel != null or not session.paused:
		await _review_fail("Closing session help did not return to the paused game")
		return false
	var help_from_pause := session.minigame_hud.find_child("HelpFromPauseButton", true, false) as Button
	if help_from_pause == null:
		await _review_fail("Paused game has no help button")
		return false
	if not await _click_control(help_from_pause): return false
	await _frames(3)
	tutorial = main.tutorial_panel as Control
	if tutorial == null or main.tutorial_origin != "session":
		await _review_fail("Paused-game help did not reopen the tutorial")
		return false
	if not await _click_control(tutorial.get("_practice_button") as Button): return false
	await _frames(4)
	if main.tutorial_panel != null or main.session != session or not session.practice_mode or session.paused:
		await _review_fail("Practice button did not resume the same session in practice mode")
		return false
	var pause_button := session.minigame_hud.find_child("PauseButton", true, false) as Button
	if pause_button == null:
		await _review_fail("Practice session has no pause control for cleanup")
		return false
	if not await _click_control(pause_button): return false
	await _frames(2)
	var leave_button := session.minigame_hud.find_child("LeaveButton", true, false) as Button
	if leave_button == null:
		await _review_fail("Practice pause panel has no leave control")
		return false
	if not await _click_control(leave_button): return false
	await _frames(1)
	var confirm_button := _find_text_button(session.minigame_hud, "確定")
	if confirm_button == null:
		await _review_fail("Leaving practice has no confirmation control")
		return false
	if not await _click_control(confirm_button): return false
	await _frames(4)
	if main.session != null or main.modal_kind != "":
		await _review_fail("Confirmed leave did not return the fixture to the park")
		return false
	return true

func _review_responsive_reduced_motion() -> bool:
	if not await _resize_window(Vector2i(800, 600)):
		return false
	progress.set_setting("reduced_motion", false)
	if not await _open_and_capture_park_variant("park-800-normal"):
		return false
	if not await _open_and_capture_game_variant("game-001-800-normal"):
		return false
	progress.set_setting("reduced_motion", true)
	if not await _open_and_capture_park_variant("park-800-reduced-motion"):
		return false
	if not await _open_and_capture_game_variant("game-001-800-reduced-motion"):
		return false
	progress.set_setting("reduced_motion", false)
	return await _resize_window(Vector2i(1280, 720))

func _open_and_capture_park_variant(name: String) -> bool:
	if main.modal_kind == "":
		await _tap_key(KEY_M)
		await _frames(2)
	if main.modal_kind != "ticket":
		await _review_fail("Could not open ticket for responsive park capture")
		return false
	var button := _find_text_button(main.overlay, "園區圖解教學")
	var scroll := _find_scroll_container(main.overlay)
	if button == null:
		await _review_fail("Responsive park capture has no ticket tutorial button")
		return false
	if scroll != null:
		scroll.ensure_control_visible(button)
		await _frames(2)
	if not await _click_control(button): return false
	await _frames(3)
	if not await _assert_tutorial_open("park", "ticket"):
		return false
	if not await _capture_main(name, "park"):
		return false
	if not await _review_screenshot_zoom(name, "park"): return false
	if not await _click_control((main.tutorial_panel as Control).get("_close_button") as Button): return false
	await _frames(2)
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	return true

func _open_and_capture_game_variant(name: String) -> bool:
	if not await _move_to_station("game-001"):
		return false
	var tutorial_button := _find_text_button(main.overlay, "圖解教學")
	if tutorial_button == null:
		await _review_fail("Responsive game tutorial button is missing")
		return false
	if not await _click_control(tutorial_button): return false
	await _frames(3)
	if not await _assert_tutorial_open("game-001", "game_info"):
		return false
	if not await _capture_main(name, "game-001"):
		return false
	if not await _review_screenshot_zoom(name, "game-001"): return false
	if not await _click_control((main.tutorial_panel as Control).get("_close_button") as Button): return false
	await _frames(2)
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	return true

func _review_screenshot_zoom(name: String, context: String) -> bool:
	var tutorial := main.tutorial_panel as Control
	var zoom_button := tutorial.get("_screenshot_zoom_button") as Button
	if zoom_button == null or zoom_button.disabled:
		await _review_fail("800px tutorial screenshot has no enabled zoom button")
		return false
	if not await _click_control(zoom_button): return false
	var zoom := tutorial.get("_screenshot_zoom") as Control
	var image := tutorial.get("_zoom_image") as TextureRect
	var back := tutorial.get("_zoom_back") as Button
	if not zoom.visible or image.texture == null or image.texture != (tutorial.get("_image") as TextureRect).texture:
		await _review_fail("Actual screenshot click did not open its full PNG")
		return false
	var bounds := tutorial.get_viewport().get_visible_rect()
	var scale_factor: float = tutorial.get("_layout_scale")
	if not bounds.encloses(image.get_global_rect()) or not bounds.encloses(back.get_global_rect()) or back.size.y * scale_factor < 44.0:
		await _review_fail("Zoom image/back does not fit with a 44px physical hit target")
		return false
	if not await _capture_main(name + "-screenshot-zoom", context): return false
	if not await _click_control(back): return false
	if zoom.visible or not tutorial.visible or not await _assert_focus_returned(zoom_button, "screenshot preview after zoom"):
		await _review_fail("Zoom back did not restore the same tutorial/preview focus")
		return false
	return await _capture_main(name + "-screenshot-return", context)

func _review_additional_main_ui() -> bool:
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.modal_kind != "pause":
		await _review_fail("Escape did not open the live park pause panel")
		return false
	if not await _capture_main("park-pause", "pause"):
		return false
	var ticket_button := _find_text_button(main.overlay, "打開航海旅券")
	if ticket_button == null:
		await _review_fail("Park pause has no voyage ticket action")
		return false
	if not await _click_control(ticket_button): return false
	await _frames(2)
	if main.modal_kind != "ticket":
		await _review_fail("Pause ticket button did not open the ticket")
		return false
	if not await _capture_main("park-ticket-from-pause", "ticket"):
		return false
	var settings_button := _find_text_button(main.overlay, "設定與輔助")
	if settings_button == null:
		await _review_fail("Ticket settings entry is missing")
		return false
	if not await _click_control(settings_button): return false
	await _frames(3)
	if main.modal_kind != "settings":
		await _review_fail("Ticket settings button did not open settings")
		return false
	var settings_scroll := _find_scroll_container(main.overlay)
	if settings_scroll == null:
		await _review_fail("Settings panel has no scroll container")
		return false
	settings_scroll.scroll_vertical = int(settings_scroll.get_v_scroll_bar().max_value)
	await _frames(3)
	var fullscreen_toggle := _find_text_button(main.overlay, "使用全螢幕")
	if fullscreen_toggle == null or not settings_scroll.get_global_rect().intersects(fullscreen_toggle.get_global_rect()):
		await _review_fail("Settings lower section did not scroll into view")
		return false
	if not await _capture_main("settings-lower", "settings"):
		return false
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.modal_kind != "":
		await _review_fail("Escape did not close settings")
		return false
	await _tap_key(KEY_C)
	await _frames(3)
	if main.modal_kind != "wardrobe":
		await _review_fail("C did not open wardrobe for tab captures")
		return false
	var wardrobe_tabs: Array[Array] = [["appearance", "Tab_appearance"], ["closet", "Tab_closet"], ["shop", "Tab_shop"]]
	for tab: Array in wardrobe_tabs:
		var tab_button := main.overlay.find_child(str(tab[1]), true, false) as Button
		if tab_button == null:
			await _review_fail("Wardrobe tab control is missing: %s" % str(tab[1]))
			return false
		if not await _click_control(tab_button): return false
		await _frames(2)
		if main.wardrobe_panel.current_tab != str(tab[0]):
			await _review_fail("Wardrobe tab did not activate: %s" % str(tab[0]))
			return false
		if not await _capture_main("wardrobe-%s" % str(tab[0]), "wardrobe"):
			return false
	await _tap_key(KEY_ESCAPE)
	await _frames(2)
	if main.modal_kind != "":
		await _review_fail("Escape did not close wardrobe")
		return false
	return true

func _check_tutorial_copy_scrollable(tutorial: Control) -> bool:
	var scroll := tutorial.get("_text_scroll") as ScrollContainer
	if scroll == null or scroll.size.x <= 0.0 or scroll.size.y <= 0.0:
		await _review_fail("Tutorial copy has no readable scroll viewport")
		return false
	for key in ["_goal_label", "_input_label", "_success_label"]:
		var label := tutorial.get(key) as Label
		if label == null or label.text.strip_edges().is_empty() or label.get_combined_minimum_size().y < 18.0:
			await _review_fail("Tutorial text section is missing or has no layout size: %s" % key)
			return false
		if not _text_fits(label):
			await _review_fail("Tutorial text section is clipped: %s" % key)
			return false
	return true

func _capture_main(suffix: String, context: String) -> bool:
	if not is_instance_valid(main):
		await _review_fail("Cannot capture %s without live main scene" % suffix)
		return false
	var panel := main.tutorial_panel as Control
	if context in ["park", "game-001"]:
		if panel == null or not panel.visible:
			await _review_fail("Tutorial capture has no visible panel: %s" % suffix)
			return false
		if not await _check_tutorial_copy_scrollable(panel):
			return false
	if DisplayServer.get_name() == "headless":
		await _review_fail("Screenshot capture was requested in headless mode: %s" % suffix)
		return false
	await RenderingServer.frame_post_draw
	var path := "%s/%s%s.png" % [SCREENSHOT_DIR, MAIN_SCREENSHOT_PREFIX, suffix]
	if not main._capture(path):
		await _review_fail("Could not capture tutorial evidence: " + path)
		return false
	_capture_count += 1
	print("TUTORIAL REVIEW CAPTURE context=%s suffix=%s path=%s" % [context, suffix, path])
	return true

func _move_to_station(lesson_id: String) -> bool:
	if main.modal_kind != "":
		await _tap_key(KEY_ESCAPE)
		await _frames(2)
	var point: Dictionary = {}
	for candidate: Dictionary in main.world.points:
		if str(candidate.get("id", "")) == lesson_id:
			point = candidate
			break
	if point.is_empty():
		await _review_fail("Fixture cannot locate station %s" % lesson_id)
		return false
	main.world.player.global_position = point.get("position", Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if str(main.world.nearest.get("id", "")) != lesson_id:
		await _review_fail("Fixture position is not within station range %s" % lesson_id)
		return false
	await _tap_key(KEY_E)
	await _frames(2)
	if main.modal_kind != "game_info":
		await _review_fail("E did not open the real station details for %s" % lesson_id)
		return false
	return true

func _assert_focus_returned(expected: Control, label: String) -> bool:
	await _frames(2)
	var focus_owner := get_viewport().gui_get_focus_owner()
	if expected == null or focus_owner == null or not expected.is_ancestor_of(focus_owner) and focus_owner != expected:
		await _review_fail("Keyboard focus was not restored to %s" % label)
		return false
	return true

func _find_text_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text.contains(text):
		return root as Button
	for child in root.get_children():
		var found := _find_text_button(child, text)
		if found != null:
			return found
	return null

func _find_scroll_container(root: Node) -> ScrollContainer:
	if root is ScrollContainer:
		return root as ScrollContainer
	for child in root.get_children():
		var found := _find_scroll_container(child)
		if found != null:
			return found
	return null

func _focus_is_inside(node: Node) -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner != null and node.is_ancestor_of(focus_owner)

func _review_fail(message: String) -> void:
	push_error("NATIVE TUTORIAL REVIEW FAILED: " + message)
	if is_instance_valid(main) and main.audio != null:
		main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
