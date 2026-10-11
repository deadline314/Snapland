extends SceneTree

const Catalog = preload("res://game/ui/tutorial_catalog.gd")
const TutorialPanelScript = preload("res://game/ui/tutorial_panel.gd")
const Paper = preload("res://game/ui/paper_ui.gd")

var _failures: Array[String] = []
var _finished := false

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("tutorial checks require an isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	create_timer(45.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	for failure in _failures:
		push_error("FAIL: " + failure)
	if _failures.is_empty():
		print("PASS: tutorial panel/catalog checks")
		quit(0)
	else:
		quit(1)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	push_error("FAIL: tutorial panel/catalog checks exceeded the 45 second watchdog")
	_finished = true
	quit(1)

func _run() -> void:
	var catalog := Catalog.new()
	var report: Dictionary = catalog.validation_report()
	_check(report.ok and report.lesson_count == 13, "catalog includes park and all twelve welcome games")
	_check(catalog.lesson_ids()[0] == "park" and catalog.lesson_ids()[-1] == "game-012", "catalog keeps stable lesson order")
	for lesson_id in catalog.lesson_ids():
		var lesson: Dictionary = catalog.get_lesson(lesson_id)
		_check(lesson.steps.size() >= 2 and lesson.steps.size() <= 3, "%s uses two or three steps" % lesson_id)
		for step in lesson.steps:
			_check(step.image.begins_with("res://assets/ui/tutorials/") and step.image.ends_with(".png"), "screenshot paths are in the runtime directory")
			_check(ResourceLoader.exists(step.image), "%s references an imported screenshot" % lesson_id)
	var altered: Dictionary = catalog.get_lesson("park")
	altered.steps[0].goal = "caller mutation"
	_check(catalog.get_lesson("park").steps[0].goal != "caller mutation", "catalog returns isolated lesson copies")

	var malformed_path := "user://tutorial-invalid-fixture.json"
	var malformed := FileAccess.open(malformed_path, FileAccess.WRITE)
	_check(malformed != null, "malformed fixture can be written to the isolated user directory")
	if malformed == null:
		_finish()
		return
	malformed.store_string('{"schema_version":1,"lessons":[{"id":"park","title":"x","goal":"x","ordinary":"x","bonus":"x","steps":[{"id":"bad","title":"x","image":"res://outside.png","alt":"x","goal":"x","input":"x","success":"x"},{"id":"bad","title":"x","image":"res://assets/ui/tutorials/ok.png","alt":"x","goal":"x","input":"x","success":"x"}]}]}')
	malformed.close()
	var invalid_catalog := Catalog.new(malformed_path)
	var invalid_report: Dictionary = invalid_catalog.validation_report()
	_check(not invalid_report.ok and invalid_report.lesson_count == 0, "malformed lessons are rejected instead of partially accepted")
	_check(not invalid_report.diagnostics.is_empty(), "malformed lesson reports field/path and missing required lessons")

	var panel := TutorialPanelScript.new()
	root.add_child(panel)
	await process_frame
	var changes: Array = []
	var skipped: Array = []
	var practices: Array = []
	var starts: Array = []
	var closed: Array = []
	panel.step_changed.connect(func(id: String, index: int, count: int): changes.append([id, index, count]))
	panel.skip_requested.connect(func(id: String): skipped.append(id))
	panel.practice_requested.connect(func(id: String): practices.append(id))
	panel.start_requested.connect(func(id: String): starts.append(id))
	panel.close_requested.connect(func(): closed.append(true))
	var opened: bool = await panel.open_tutorial("game-001")
	_check(opened, "valid lesson opens")
	if not opened:
		panel.queue_free()
		await process_frame
		_finish()
		return
	_check(panel.visible and panel.current_step == 0, "open starts at the first step")
	var focused := root.gui_get_focus_owner()
	_check(focused is Button and (focused as Button).text == "略過", "opening places keyboard focus on the skip button")
	_check(panel._image.texture is Texture2D and not panel._image_placeholder.visible, "a real imported screenshot loads into the image view")
	_check(panel._image.texture.get_width() > 0 and panel._image.texture.get_height() > 0, "loaded screenshot retains a non-empty image size")
	_check(panel._image_alt.text == panel.current_step_data().alt and not panel._image_alt.text.contains("預留") and not panel._image_alt.text.contains("正式截圖"), "alt text describes the lesson visual instead of a development placeholder")
	_check(changes.size() == 1 and changes[0][1] == 0, "open emits the current step")

	# Replace exactly one fixture path after proving the real-image branch above.
	# This exercises the player-facing missing-image state without making a real lesson image missing.
	var broken_lesson: Dictionary = panel.catalog.get_lesson("game-001")
	broken_lesson.steps[0].image = "res://assets/ui/tutorials/fixture-deliberately-missing.png"
	panel.catalog._lessons["game-001"] = broken_lesson
	_check(await panel.open_tutorial("game-001"), "fixture lesson reopens for the missing-image branch")
	_check(panel._image.texture == null and panel._image_placeholder.visible, "a deliberately missing screenshot uses the visible text fallback")
	_check(panel._screenshot_zoom_button.disabled and not panel._open_screenshot_zoom() and not panel._screenshot_zoom.visible, "missing screenshot keeps the readable fallback and disables zoom")
	_check(panel._image_placeholder.text == "教學圖片暫時無法載入，請參考右側操作說明。" and not panel._image_placeholder.text.contains("res://"), "missing screenshot fallback stays player-facing and hides resource paths")
	_check(panel._image_alt.text == broken_lesson.steps[0].alt, "missing screenshot retains meaningful player-facing alt text")
	# Restore the real fixture before checking navigation and signals.
	panel.catalog._lessons["game-001"] = catalog.get_lesson("game-001")
	_check(await panel.open_tutorial("game-001"), "real lesson restores after fallback check")
	panel.next_step()
	_check(panel.current_step == 1, "next advances one step")
	panel.previous_step()
	_check(panel.current_step == 0, "previous returns one step")
	panel.request_practice()
	panel.request_skip()
	panel.request_start()
	_check(practices == ["game-001"] and skipped == ["game-001"] and starts == ["game-001"], "practice, skip, and start emit target-specific requests")
	_check(not paused and panel.visible, "tutorial emits requests without taking ownership of game pause or transitions")
	panel.replay()
	_check(panel.current_step == 0, "replay resets the lesson to its first step")
	panel.request_close()
	_check(closed.size() == 1, "close emits a request for the owner to handle")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._input(escape)
	_check(closed.size() == 2 and panel.visible, "Escape requests owner-handled close without mutating session state")
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	panel._input(right)
	_check(panel.current_step == 1, "Right Arrow navigates to the next tutorial step")
	panel.dismiss()
	_check(not panel.visible, "owner can dismiss the panel")
	var focus_restore := Button.new()
	focus_restore.text = "Return Focus"
	focus_restore.focus_mode = Control.FOCUS_ALL
	root.add_child(focus_restore)
	focus_restore.grab_focus()
	_check(await panel.open_tutorial("game-001"), "lesson opens while an owner control has focus")
	_check(root.gui_get_focus_owner() == panel._skip_button, "lesson opening transfers focus into its controls")
	panel.dismiss()
	_check(root.gui_get_focus_owner() == focus_restore, "dismiss restores focus to the control active before opening")
	panel.dismiss()
	_check(root.gui_get_focus_owner() == focus_restore, "repeated dismiss is harmless and keeps restored focus")
	focus_restore.grab_focus()
	_check(await panel.open_tutorial("game-001"), "lesson opens for a disappearing prior-focus target")
	focus_restore.queue_free()
	await process_frame
	await process_frame
	panel.dismiss()
	var focus_after_freed := root.gui_get_focus_owner()
	_check(not is_instance_valid(focus_restore) and (focus_after_freed == null or focus_after_freed == panel._skip_button), "dismiss safely ignores a prior-focus control freed while the lesson was open")
	panel.dismiss()
	var repeated_focus := root.gui_get_focus_owner()
	_check(repeated_focus == null or repeated_focus == panel._skip_button, "repeated dismiss remains safe after the prior control was freed")
	_check(await panel.open_tutorial("game-001"), "lesson reopens for compact-layout checks")
	_check(root.gui_get_focus_owner() == panel._skip_button, "compact-layout lesson begins with keyboard focus inside the panel")
	# Reproduce the expanded logical viewport used by the 800x600 window:
	# 1280x960 at physical scale 0.625. Check settled container geometry for
	# every screenshot/copy combination, not just one freshly reflowed lesson.
	for logical_size in [Vector2i(1280, 720), Vector2i(1280, 960)]:
		root.content_scale_size = logical_size
		root.size = logical_size
		await process_frame
		await process_frame
		for lesson_id in catalog.lesson_ids():
			await panel.open_tutorial(lesson_id)
			for step_index in range(catalog.get_lesson(lesson_id).steps.size()):
				panel._apply_responsive_layout(0.625)
				for frame_index in range(10):
					await process_frame
				var bounds := panel.get_viewport().get_visible_rect()
				var card_rect := panel._card.get_global_rect()
				_check(panel._text_scroll.size.y * 0.625 >= 80.0, "compact %s step %d copy preserves an 80px physical viewport" % [lesson_id, step_index])
				_check(panel._aspect.size.y > 0.0 and is_equal_approx(panel._aspect.size.x / panel._aspect.size.y, 16.0 / 9.0), "compact %s step %d preview keeps its rendered 16:9 aspect" % [lesson_id, step_index])
				_check(bounds.size == Vector2(logical_size), "compact regression uses the requested logical geometry: %s" % bounds)
				_check(bounds.encloses(card_rect), "compact %s step %d full card fits: card=%s viewport=%s min=%s" % [lesson_id, step_index, card_rect, bounds, panel._card.get_combined_minimum_size()])
				for element in [panel._image_column, panel._aspect, panel._image_alt, panel._text_scroll, panel._footer]:
					_check(card_rect.encloses(element.get_global_rect()) and bounds.encloses(element.get_global_rect()), "compact %s step %d content/control fits: %s %s" % [lesson_id, step_index, element.name, element.get_global_rect()])
				for button in panel._footer_buttons:
					_check(bounds.encloses(button.get_global_rect()) and button.size.y * 0.625 >= 44.0, "compact %s step %d action stays visible at 44px: %s %s" % [lesson_id, step_index, button.text, button.get_global_rect()])
				# The copy's final result remains reachable by scrolling, even when
				# the preview above it consumes most of the compact content height.
				panel._text_scroll.ensure_control_visible(panel._bonus_label)
				await process_frame
				await process_frame
				_check(panel._text_scroll.get_global_rect().encloses(panel._bonus_label.get_global_rect()), "compact %s step %d final result copy can scroll into view" % [lesson_id, step_index])
				panel.next_step()
	await panel.open_tutorial("game-001")
	panel._apply_responsive_layout(0.625)
	await process_frame
	await process_frame
	var compact_focus := root.gui_get_focus_owner()
	_check(compact_focus == panel._skip_button, "responsive footer reparenting preserves keyboard focus after two render frames (actual=%s)" % str(compact_focus))
	_check(panel._content.vertical, "800px physical layout reflows image and copy into one column")
	_check(panel._aspect.size.x > 0.0 and panel._text_scroll.size.x > 0.0 and panel._text_scroll.size.y > 0.0, "compact layout retains screenshot aspect and a scrollable copy pane")
	_check(panel.get_viewport().get_visible_rect().encloses(panel._card.get_global_rect()), "compact tutorial card stays inside the viewport")
	_check(panel._footer.size.y * 0.625 >= 88.0, "compact footer wraps its fixed actions into multiple full-size hit-target rows")
	_check(is_equal_approx(panel._aspect.ratio, 16.0 / 9.0) and is_equal_approx(float(panel._image.texture.get_width()) / float(panel._image.texture.get_height()), 16.0 / 9.0), "responsive reflow keeps the actual lesson image at its 16:9 aspect")
	var readable_sizes := true
	var hit_targets := true
	for node in panel.find_children("*", "Control", true, false):
		var control := node as Control
		if (control is Label or control is Button) and control.is_visible_in_tree():
			readable_sizes = readable_sizes and float(control.get_theme_font_size("font_size")) * 0.625 >= 18.0
		if control is Button and control.is_visible_in_tree():
			hit_targets = hit_targets and control.get_global_rect().size.y * 0.625 >= 44.0
	_check(readable_sizes, "compact tutorial labels and buttons preserve at least 18px physical type")
	_check(hit_targets, "compact tutorial buttons preserve 44px physical hit targets")
	# Enter opens the actual image-area Button; Escape first returns to the
	# tutorial, then requests the existing owner-handled tutorial close.
	panel._screenshot_zoom_button.grab_focus()
	await _send_key(KEY_ENTER)
	_check(panel._screenshot_zoom.visible and panel._zoom_image.texture == panel._image.texture and root.gui_get_focus_owner() == panel._zoom_back, "Enter opens the real screenshot and focuses the 44px back control")
	_check(panel._open_screenshot_zoom(), "opening an already visible zoom is harmless")
	_check(panel._zoom_image.size.x > panel._aspect.size.x * 1.5 and is_equal_approx(panel._zoom_image.size.x / panel._zoom_image.size.y, 16.0 / 9.0), "zoom makes the full PNG substantially larger and preserves 16:9")
	var zoom_step := panel.current_step
	await _send_key(KEY_RIGHT)
	_check(panel.current_step == zoom_step and root.gui_get_focus_owner() == panel._zoom_back, "zoom keyboard navigation does not advance the underlying lesson")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	panel._apply_responsive_layout(0.625)
	await process_frame
	_check(panel.get_viewport().get_visible_rect().encloses(panel._zoom_image.get_global_rect()) and panel.get_viewport().get_visible_rect().encloses(panel._zoom_back.get_global_rect()) and panel._zoom_back.size.y * 0.625 >= 44.0, "visible zoom image/back remain in bounds after resizing at 44px")
	var closes_before_zoom := closed.size()
	await _send_key(KEY_ESCAPE)
	_check(not panel._screenshot_zoom.visible and panel.visible and closed.size() == closes_before_zoom and root.gui_get_focus_owner() == panel._screenshot_zoom_button, "first Escape closes zoom and restores preview focus without closing the lesson")
	panel._close_screenshot_zoom()
	_check(root.gui_get_focus_owner() == panel._screenshot_zoom_button, "repeated zoom close preserves the restored focus")
	await _send_key(KEY_ESCAPE)
	_check(closed.size() == closes_before_zoom + 1, "second Escape requests the ordinary tutorial close")
	panel._screenshot_zoom_button.grab_focus()
	await _send_key(KEY_ENTER)
	await _send_key(KEY_ENTER)
	_check(not panel._screenshot_zoom.visible and root.gui_get_focus_owner() == panel._screenshot_zoom_button, "Enter also activates the focused zoom back button and returns to preview")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	panel._apply_responsive_layout(1.0)
	await process_frame
	_check(not panel._content.vertical and panel._desktop_footer.visible and panel._previous_button.get_parent() == panel._desktop_footer, "large layout restores the two-column panel and single-row footer")
	panel.queue_free()
	await process_frame
	_finish()

func _send_key(code: int) -> void:
	for is_down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = is_down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await process_frame
