extends Node
## Automated Main input/GPU evidence with synthetic admission; not a human playtest.
const View = preload("res://game/minigames/sugar_bridge_view.gd")
var main: Node
var session: Control
var failures: Array[String] = []
var captures: Array[String] = []
var results: Array[Dictionary] = []
var output := ""
var tutorial_dir := ""
var mode := ""
var requested := Vector2i(1280, 720)
var started := Time.get_ticks_msec()
var review_game_id := "game-025"

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - started > 180000:
		push_error("Native %s Main exceeded 180 second wall-clock guard" % review_game_id)
		get_tree().quit(1)

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int = 2) -> void:
	for i in count: await get_tree().process_frame

func _run() -> void:
	output = OS.get_environment("SUGAR_CAPTURE_DIR")
	tutorial_dir = OS.get_environment("SUGAR_TUTORIAL_DIR")
	mode = OS.get_environment("SUGAR_REVIEW_MODE")
	var dimensions := OS.get_environment("SUGAR_REVIEW_SIZE").split("x")
	if dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int():
		requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or (not tutorial_dir.is_empty() and not tutorial_dir.is_absolute_path()) or requested not in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		push_error("Native sugar requires GPU, isolated absolute paths and supported viewport")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if not tutorial_dir.is_empty(): DirAccess.make_dir_recursive_absolute(tutorial_dir)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = requested
	get_window().size = requested
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		Progress.settings["ui_scale"] = 1.25 if requested.x == 800 else 1.0
		Progress.settings["reduced_motion"] = requested.x == 800
		for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SETUP: six synthetic admission cards; no game025 result or photo seeded")
		check(Progress.set_current_region("candy"), "synthetic admission enters candy")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual physical viewport")
	if mode == "read":
		check(Progress.current_region == "candy" and Progress.has_seen_tutorial("game-025") and Progress.achievements.has("ACH_GAME_025") and (Progress.photos.has("photo-candy-game-1") or Progress.photos.has("photo-candy-devil-1")), "restart retains actual candy rewards and lesson")
		check(photo_valid("photo-candy-game-1" if Progress.photos.has("photo-candy-game-1") else "photo-candy-devil-1"), "restart retains rendered original and thumbnail")
		main._show_album()
		await capture("restart-album")
		await finish()
		return
	main._interact("game-025", "拉糖橋")
	check(main.modal_kind == "game_info", "real factory kiosk invitation")
	await capture("invite")
	var assisted := mode == "assisted"
	if tutorial_dir.is_empty():
		main._request_game_start("game-025", assisted)
		await frames(3)
		check(is_instance_valid(main.tutorial_panel), "actual first entry lesson")
		await capture("tutorial")
		main._tutorial_start("game-025")
	else:
		check(Progress.mark_game_tutorial_seen("game-025"), "asset-only bootstrap uses actual lesson identifier")
		main._launch_game("game-025", assisted)
	await frames(4)
	session = main.session
	check(session != null and session.game_id == "game-025", "actual Main launches sugar Session")
	if session == null:
		await finish()
		return
	session.set_process(false)
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	if mode == "retake":
		await retake()
		await finish()
		return
	var coins: int = Progress.coins
	if mode == "timeout":
		await key(KEY_ENTER)
		await advance(151.0)
	elif mode == "ordinary":
		await drag(0, Vector2.ZERO)
		await drag(1, session.active_driver.snapshot().anchors[2])
		await capture("long-bridge", 1)
		for i in 3:
			await key(KEY_ENTER)
			await advance(14.0)
	else:
		for endpoint in 4:
			await drag(endpoint, session.active_driver.snapshot().anchors[[0, 1, 1, 2][endpoint]])
		await capture("short-bridge", 1)
		var state: Dictionary = session.active_driver.snapshot()
		var pull: Vector2 = (Vector2(state.hopper) + Vector2(0, 2.4 * 0.9 * 0.9)) / (1.0 - 4.0 * float(state.elasticity) * 0.9)
		await select_endpoint(1)
		await pointer(View.design_point(state.endpoints[1].position), "press")
		await pointer(View.design_point(pull), "move")
		check(session.active_driver.snapshot().grabbed == 1, "actual sling endpoint held")
		await capture("trial-pull", 2)
		await pointer(View.design_point(pull), "release")
		await advance(1.25)
		check(session.active_driver.snapshot().bands[0].hit, "actual ballistic bean hits side hopper")
		await drag(1, session.active_driver.snapshot().anchors[1])
		for i in 3: await key(KEY_ENTER)
		await advance(1.2)
		check(session.active_driver.snapshot().balls.filter(func(ball): return ball.state == "rolling").size() == 3, "three spaced balls really roll on short material")
		await capture("same-band-loaded")
		await advance(20.0)
	await frames(6)
	check(main.session == null and results.size() == 1, "one natural Main completion")
	if not results.is_empty():
		var result: Dictionary = results[0]
		check(result.ordinary_eligible and result.success == (mode != "timeout") and result.devil == (mode not in ["ordinary", "timeout"]), "truthful real result and same-band proof")
		print("ACTUAL RESULT: ", JSON.stringify(result))
	check(Progress.normal_count_for_zone("candy") == 1 and Progress.coins == coins + 40 and Progress.achievements.has("ACH_GAME_025"), "one fixed candy card, achievement and 40 coin receipt")
	check(photo_valid(), "result saves rendered original and bounded thumbnail")
	await capture("result", 3)
	main._close()
	main._show_album()
	await capture("album")
	main._close()
	main._show_map()
	await capture("map")
	main._close()
	check(Progress.save_progress(), "actual writer saves profile")
	await finish()

func pointer(point: Vector2, action: String) -> void:
	var screen: Vector2 = session.presentation.get_global_transform_with_canvas() * point
	if action == "move":
		var event := InputEventMouseMotion.new()
		event.position = screen
		event.global_position = screen
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.global_position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = action == "press"
		Input.parse_input_event(event)
	await frames(1)
	if main.session != null: session._process(0.0)

func drag(endpoint: int, destination: Vector2) -> void:
	await select_endpoint(endpoint)
	await pointer(View.design_point(session.active_driver.snapshot().endpoints[endpoint].position), "press")
	check(session.active_driver.snapshot().grabbed == endpoint, "actual pointer grabs endpoint %d" % endpoint)
	await pointer(View.design_point(destination), "move")
	await pointer(View.design_point(destination), "release")

func select_endpoint(endpoint: int) -> void:
	for i in 4:
		if session.active_driver.snapshot().selected == endpoint: return
		await key(KEY_TAB)
	check(false, "actual Tab selects requested endpoint")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	if main.session != null: session._process(0.0)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)

func advance(seconds: float) -> void:
	for i in ceili(seconds * 60):
		if main.session == null: return
		session._process(1.0 / 60.0)
		if i % 18 == 0: await frames(1)

func photo_valid(photo_id: String = "photo-candy-game-1") -> bool:
	var record: Dictionary = Progress.photos.get(photo_id, {})
	var originals: Array = record.get("original_frames", [])
	var thumbs: Array = record.get("frames", [])
	if originals.is_empty() or thumbs.is_empty(): return false
	var image := Image.load_from_file(str(originals[0]))
	var thumb := Image.load_from_file(str(thumbs[0]))
	return image != null and image.get_width() * image.get_height() <= 4 * 1024 * 1024 and thumb != null and thumb.get_size() == Vector2i(320, 180)

func activate(parent: Node, button_name: String) -> void:
	var button = parent.find_child(button_name, true, false)
	check(button is Button and not button.disabled, "real enabled button " + button_name)
	if button is Button and not button.disabled:
		button.grab_focus()
		await key(KEY_ENTER)
		await frames(3)

func retake() -> void:
	main._cancel_game(false)
	main._practice_for_retake("game-025", true)
	await frames(3)
	check(main.session != null and main.session.practice_mode, "real selected devil practice")
	if main.session == null: return
	session = main.session
	session.set_process(false)
	await key(KEY_ENTER)
	session._leave_from_hud()
	await frames(3)
	check(main.modal_kind == "retake" and main.retake_target == {"id":"game-025", "devil":true}, "practice cancel returns selected candy retake")
	check(not Progress.photos.has("photo-candy-game-1") and not Progress.photos.has("photo-candy-devil-1"), "practice and cancel give no target card")
	if main.retake_panel == null: return
	var coins: int = Progress.coins
	await capture("retake-demonstration")
	await activate(main.retake_panel, "RetakeNext")
	await activate(main.retake_panel, "DecorationChoice")
	await activate(main.retake_panel, "FramingChoice")
	await capture("retake-arranged")
	await activate(main.retake_panel, "RetakeNext")
	var photograph: Image = main.retake_panel._viewport.get_texture().get_image()
	photograph.convert(Image.FORMAT_RGBA8)
	await activate(main.retake_panel, "RetakeShutter")
	await frames(8)
	var record: Dictionary = Progress.photos.get("photo-candy-devil-1", {})
	check(main.retake_panel._saved and record.get("acquisition_method", "") == "retake" and not record.get("challenge_earned", true), "real rendered shutter saves truthful selected retake")
	check(not Progress.photos.has("photo-candy-game-1") and Progress.coins == coins + 40 and Progress.achievements.has("ACH_GAME_025"), "retake grants only selected card and one fixed receipt")
	check(photo_valid("photo-candy-devil-1"), "retake stores actual original and320x180 thumbnail")
	if record.get("original_frames", []).size() == 1:
		var stored := Image.load_from_file(record.original_frames[0])
		stored.convert(Image.FORMAT_RGBA8)
		check(stored.get_data() == photograph.get_data(), "saved retake original equals actual arranged viewport pixels")
	await capture("retake-saved")
	await activate(main.retake_panel, "RetakeClose")
	main._show_album()
	await capture("retake-album")
	check(Progress.save_progress(), "retake writer saves actual profile")

func capture(label: String, tutorial_step: int = 0) -> void:
	if is_instance_valid(session) and main.session != null: session._process(0.0)
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and image.get_size() == requested, "actual viewport image " + label)
	if image == null: return
	check(image.save_png(output.path_join(label + ".png")) == OK, "write capture " + label)
	captures.append(label + ".png")
	if tutorial_step > 0 and not tutorial_dir.is_empty():
		check(image.get_size() == Vector2i(1280, 720), "tutorial source is actual 1280x720")
		check(image.save_png(tutorial_dir.path_join("%s-step-%02d.png" % [review_game_id, tutorial_step])) == OK, "write real tutorial PNG")

func completion_marker() -> String:
	return "PASS: native sugar Main actual controls, material result, fixed photos and restart"

func finish() -> void:
	var report := {"scope":"automated Main actual input/GPU, synthetic admission, no human play or listening claim", "mode":mode, "viewport":requested, "captures":captures, "failures":failures, "results":results, "save_path":OS.get_environment("SNAPLAND_SAVE_PATH")}
	if is_instance_valid(main):
		main.quitting = true
		var playbacks: Array[WeakRef] = []
		for player in main.audio.get_children():
			if player is AudioStreamPlayer and player.has_stream_playback(): playbacks.append(weakref(player.get_stream_playback()))
		main.audio.shutdown()
		main.queue_free()
		await frames(3)
		var deadline := Time.get_ticks_msec() + 2000
		while playbacks.any(func(playback: WeakRef): return playback.get_ref() != null):
			if Time.get_ticks_msec() >= deadline:
				check(false, "native audio releases stopped playback before exit")
				break
			await frames(1)
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	for problem in failures: push_error(problem)
	print(completion_marker() if failures.is_empty() else "FAIL: native " + review_game_id + " Main")
	get_tree().quit(0 if failures.is_empty() else 1)
