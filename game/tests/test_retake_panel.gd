extends SceneTree

const Catalog = preload("res://game/core/game_catalog.gd")
const Lessons = preload("res://game/ui/tutorial_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("retake panel checks require an absolute isolated save")
		quit(1)
		return
	create_timer(85.0).timeout.connect(func(): push_error("retake panel watchdog"); quit(1))
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var script = load("res://game/ui/retake_panel.gd")
	check(script != null, "retake panel script exists")
	if script == null:
		finish()
		return
	var lessons := Lessons.new()
	for definition in Catalog.all_definitions():
		var panel = script.new()
		panel.setup(definition, false, lessons.get_lesson(definition.id))
		root.add_child(panel)
		await process_frame
		check(panel.current_step == 0 and not panel._next.disabled, "canonical delivered target opens at observation: " + definition.id)
		check(panel._viewport.size == Vector2i(1280,720), "one fixed photograph viewport")
		panel.queue_free()
		await process_frame
	for invalid in ["game-014", "balloon_delivery", "park", ""]:
		var panel = script.new()
		panel.setup({"id":invalid}, false, lessons.get_lesson("game-001"))
		root.add_child(panel)
		await process_frame
		check(panel._next.disabled and panel._shutter.disabled and not panel._status.text.is_empty(), "noncanonical target refuses capture: " + invalid)
		panel.queue_free()
		await process_frame
	var mismatch = script.new()
	mismatch.setup(Catalog.find("game-001"), false, lessons.get_lesson("game-013"))
	root.add_child(mismatch)
	await process_frame
	check(mismatch._next.disabled, "lesson mismatch refuses capture")
	mismatch.queue_free()
	await process_frame
	var panel = script.new()
	var definition := Catalog.find("game-013")
	var lesson := lessons.get_lesson("game-013")
	panel.setup(definition, true, lesson)
	definition.id = "game-014"
	lesson.steps[0].image = "res://outside.png"
	panel.setup(Catalog.find("game-001"), false, lessons.get_lesson("game-001"))
	root.add_child(panel)
	await process_frame
	check(panel._definition.id == "game-013" and panel._devil, "target is immutable including caller mutation/repeated setup")
	check(root.gui_get_focus_owner() == panel._next, "opening focuses sequential next button")
	var captures: Array = []
	var closes: Array = []
	panel.capture_requested.connect(func(image: Image): captures.append(image))
	panel.close_requested.connect(func(): closes.append(true))
	panel._shutter.pressed.emit()
	check(captures.is_empty() and panel.current_step == 0, "early shutter cannot capture")
	panel._next.pressed.emit()
	check(panel.current_step == 1 and panel._choices.visible, "first next reaches adjust")
	for button in panel._choice_buttons:
		button.grab_focus()
		await send_key(KEY_ENTER)
	check(panel._framing == 2 and panel._decoration == 1 and panel._distance == 2, "Enter cycles each visible bounded choice")
	for button in panel._choice_buttons:
		for turn in range(3): button.pressed.emit()
	check(panel._framing == 2 and panel._decoration == 1 and panel._distance == 2, "choices cycle within three bounded values")
	panel._back.pressed.emit()
	check(panel.current_step == 0, "back reaches observe")
	panel._next.pressed.emit()
	check(panel._framing == 2 and panel._decoration == 1 and panel._distance == 2, "back preserves choices")
	panel._next.pressed.emit()
	panel._back.pressed.emit()
	check(panel.current_step == 1 and panel._framing == 2, "shutter back returns to preserved adjustment")
	panel._next.pressed.emit()
	panel._next.pressed.emit()
	check(panel.current_step == 2 and panel._next.disabled and not panel._shutter.disabled, "ordered navigation stops at shutter")
	if DisplayServer.get_name() == "headless":
		panel._shutter.pressed.emit()
		check(captures.is_empty() and not panel._awaiting_result, "headless refuses to fabricate a rendered photograph")
	# State-only acknowledgement coverage; rendered capture is covered by the native fixture.
	panel._awaiting_result = true
	panel.set_capture_result(false, "保存失敗，請重試")
	check(not panel._shutter.disabled and panel._status.text.contains("重試"), "failed save re-enables retry")
	panel._awaiting_result = true
	panel.set_capture_result(true, "保存完成")
	panel._shutter.pressed.emit()
	panel.set_capture_result(false, "late failure")
	check(panel._shutter.disabled and captures.is_empty(), "success and unsolicited late ack cannot duplicate award")
	await send_key(KEY_ESCAPE)
	panel._shutter.pressed.emit()
	check(closes.size() == 1 and panel._closed and captures.is_empty(), "Escape invalidates capture")
	panel.queue_free()
	await process_frame
	var altered := lessons.get_lesson("game-001")
	altered.steps[0].image = "res://assets/ui/tutorials/../outside.png"
	var rejected = script.new()
	rejected.setup(Catalog.find("game-001"),false,altered)
	root.add_child(rejected)
	await process_frame
	check(rejected._next.disabled, "altered lesson path rejected")
	rejected.queue_free()
	await process_frame
	var canonical_path: String = lessons.get_lesson("game-001").steps[0].image
	var original: Texture2D = load(canonical_path)
	var missing := PlaceholderTexture2D.new()
	missing.size = Vector2(1280,720)
	missing.take_over_path(canonical_path)
	var fallback = script.new()
	fallback.setup(Catalog.find("game-001"),false,lessons.get_lesson("game-001"))
	root.add_child(fallback)
	await process_frame
	check(not fallback._valid and fallback._source == null and fallback._preview.texture == null and fallback._shutter.disabled, "missing decoded source clears preview and refuses capture")
	fallback.queue_free()
	await process_frame
	original.take_over_path(canonical_path)
	var source := ImageTexture.create_from_image(Image.create(2049,2049,false,Image.FORMAT_RGBA8))
	check(not script._valid_texture(source), "oversized source rejected before image readback")
	check(not script._valid_texture(null), "missing source rejected")
	finish()

func send_key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await process_frame

func finish() -> void:
	for failure in failures: push_error("FAIL: " + failure)
	print("PASS: retake panel canonical targets, reversible state, keyboard and capture guards" if failures.is_empty() else "FAIL: retake panel")
	quit(0 if failures.is_empty() else 1)
