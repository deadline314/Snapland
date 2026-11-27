extends "res://game/tests/native_sugar_bridge_main.gd"
## Scripted real Main input and fixed-step physical catches; not human play.
const CookieView = preload("res://game/minigames/cookie_mold_view.gd")

func completion_marker() -> String:
	return "PASS: native cookie Main actual mold inputs, physical catches, photos and restart"

func _run() -> void:
	review_game_id = "game-026"
	output = OS.get_environment("COOKIE_CAPTURE_DIR")
	tutorial_dir = OS.get_environment("COOKIE_TUTORIAL_DIR")
	mode = OS.get_environment("COOKIE_REVIEW_MODE")
	var dimensions := OS.get_environment("COOKIE_REVIEW_SIZE").split("x")
	if dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int():
		requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or (not tutorial_dir.is_empty() and not tutorial_dir.is_absolute_path()) or requested not in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		push_error("Native cookie requires GPU, isolated absolute paths and supported viewport")
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
		preload("res://game/tests/calm_daily_picks.gd").settle(Progress)
		Progress.prologue_seen = true
		Progress.settings["ui_scale"] = 1.25 if requested.x == 800 else 1.0
		Progress.settings["reduced_motion"] = requested.x == 800
		for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SETUP: six synthetic admission cards; no026 result or photo seeded")
		check(Progress.set_current_region("candy"), "synthetic admission enters factory")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual physical viewport")
	if mode == "read":
		check(Progress.current_region == "candy" and Progress.has_seen_tutorial("game-026") and Progress.achievements.has("ACH_GAME_026"), "restart retains factory, lesson and fixed026 achievement")
		check(photo_valid("photo-candy-game-2" if Progress.photos.has("photo-candy-game-2") else "photo-candy-devil-2"), "restart retains actual026 original and thumbnail")
		main._show_album()
		await capture("restart-album")
		await finish()
		return
	main._interact("game-026", "餅乾翻模")
	check(main.modal_kind == "game_info", "real cookie kiosk invitation")
	await capture("invite")
	var assisted := mode == "assisted"
	if tutorial_dir.is_empty():
		main._request_game_start("game-026", assisted)
		await frames(3)
		check(is_instance_valid(main.tutorial_panel), "actual first entry lesson")
		await capture("tutorial")
		main._tutorial_start("game-026")
	else:
		check(Progress.mark_game_tutorial_seen("game-026"), "asset-only bootstrap uses real026 lesson identifier")
		main._launch_game("game-026", assisted)
	await frames(4)
	session = main.session
	check(session != null and session.game_id == "game-026", "Main launches actual cookie Session")
	if session == null:
		await finish()
		return
	session.set_process(false)
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	if mode == "retake":
		await cookie_retake()
		await finish()
		return
	var coins: int = Progress.coins
	if mode == "timeout":
		await held_key(KEY_RIGHT, 0.1)
		await advance(151.0)
	else:
		await play(mode != "ordinary")
	await frames(6)
	check(main.session == null and results.size() == 1, "one natural cookie Main completion")
	if not results.is_empty():
		var result: Dictionary = results[0]
		check(result.ordinary_eligible and result.success == (mode != "timeout") and result.devil == (mode not in ["ordinary", "timeout"]), "truthful physical result and double-layer proof")
		print("ACTUAL RESULT: ", JSON.stringify(result))
	check(Progress.photos.has("photo-candy-game-2") and not Progress.photos.has("photo-candy-game-1") and Progress.coins == coins + 40 and Progress.achievements.has("ACH_GAME_026"), "only local2 card, fixed026 achievement and one40coin receipt")
	check(photo_valid("photo-candy-game-2"), "result saves rendered026 original and thumbnail")
	await capture("result", 3)
	main._close()
	main._show_album()
	await capture("album")
	main._close()
	main._show_map()
	await capture("map")
	main._close()
	check(Progress.save_progress(), "actual026 writer saves profile")
	await finish()

func play(devil: bool) -> void:
	for slot in 6:
		for knock in 180:
			if main.session == null: return
			var state: Dictionary = session.active_driver.snapshot()
			if state.phase != "molded": break
			var edge := 0
			for index in state.edges.size():
				if state.edges[index].adhesion > state.edges[edge].adhesion: edge = index
			if state.edges[edge].adhesion <= 0.15: break
			for change in state.edges.size():
				if session.active_driver.snapshot().selected_edge == edge: break
				await key(KEY_TAB)
			await held_key(KEY_SPACE, 0.16)
		var state: Dictionary = session.active_driver.snapshot()
		check(state.phase == "molded", "gentle edge loosening preserves shape %d" % slot)
		if state.phase != "molded": return
		if slot == 0: await capture("loosened-mold", 1)
		if not state.helper: await key(KEY_R)
		state = session.active_driver.snapshot()
		await pointer(CookieView.mold_handle_point(state), "press")
		for frame in 1080:
			state = session.active_driver.snapshot()
			if state.phase != "molded": break
			var aim: Dictionary = state.duplicate(true)
			aim.mold_angle = 2.8 if devil and slot == 5 else minf(PI, float(frame + 1) * 0.9 / 120.0)
			await pointer(CookieView.mold_handle_point(aim), "move")
			await advance(1.0 / 120.0)
		await pointer(CookieView.mold_handle_point(state), "release")
		state = session.active_driver.snapshot()
		check(state.phase == "flying", "actual mold releases shape %d" % slot)
		print("RELEASE: ", JSON.stringify({"slot":slot,"shape":state.shape_name,"omega":state.release_omega,"inertial":state.release_inertial,"gravity":state.release_gravity}))
		if state.phase != "flying": return
		if slot == 5:
			await advance(0.18)
			await capture("double-layer-flight", 2)
			state = session.active_driver.snapshot()
			check(state.phase == "flying", "double-layer capture shows actual separated flight")
		await pointer(CookieView.tray_point(state), "press")
		for frame in 600:
			if main.session == null: return
			state = session.active_driver.snapshot()
			if state.phase != "flying": break
			var aim: Dictionary = state.duplicate(true)
			aim.tray_x = state.cookie_position.x
			await pointer(CookieView.tray_point(aim), "move")
			await advance(1.0 / 120.0)
		if main.session == null: return
		await pointer(CookieView.tray_point(state), "release")
		state = session.active_driver.snapshot()
		check(state.phase == "caught" and state.caught == slot + 1, "whole actual cookie caught %d" % slot)
		if state.phase != "caught": return
		await advance(0.46)

func advance(seconds: float) -> void:
	var left := seconds
	var steps := 0
	while left > 0.000001 and main.session != null:
		var delta := minf(left, 1.0 / 120.0)
		session._process(delta)
		left -= delta
		steps += 1
		if steps % 18 == 0: await frames(1)

func held_key(code: Key, seconds: float) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	await advance(seconds)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)
	if main.session != null: session._process(0.0)

func cookie_retake() -> void:
	main._cancel_game(false)
	main._practice_for_retake("game-026", true)
	await frames(3)
	check(main.session != null and main.session.practice_mode, "real selected026 devil practice")
	if main.session == null: return
	session = main.session
	session.set_process(false)
	await held_key(KEY_RIGHT, 0.1)
	session._leave_from_hud()
	await frames(3)
	check(main.modal_kind == "retake" and main.retake_target == {"id":"game-026", "devil":true}, "practice cancel restores selected026 retake")
	check(not Progress.photos.has("photo-candy-game-2") and not Progress.photos.has("photo-candy-devil-2"), "practice and cancel grant no026 cards")
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
	var record: Dictionary = Progress.photos.get("photo-candy-devil-2", {})
	check(main.retake_panel._saved and record.get("acquisition_method", "") == "retake" and not record.get("challenge_earned", true), "real026 shutter saves truthful selected card")
	check(not Progress.photos.has("photo-candy-game-2") and Progress.coins == coins + 40 and Progress.achievements.has("ACH_GAME_026"), "retake grants only selected026 card and one receipt")
	check(photo_valid("photo-candy-devil-2"), "retake saves real026 original and320x180 thumbnail")
	if record.get("original_frames", []).size() == 1:
		var stored := Image.load_from_file(record.original_frames[0])
		stored.convert(Image.FORMAT_RGBA8)
		check(stored.get_data() == photograph.get_data(), "saved026 original equals arranged viewport pixels")
	await capture("retake-saved")
	await activate(main.retake_panel, "RetakeClose")
	main._show_album()
	await capture("retake-album")
	check(Progress.save_progress(), "retake026 writer saves actual profile")
