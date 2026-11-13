extends Node
## Automated fixed-input review, not a human playtest. Copy this script and the
## adjacent buoy_relay_route.gd explicitly when a release excludes game/tests.
var Route: Script = load(get_script().resource_path.get_base_dir().path_join("buoy_relay_route.gd"))
var main: Node
var failures: Array[String] = []
var capture_dir := ""
var tutorial_dir := ""
var results: Array[Dictionary] = []
var _started := Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started > 180000:
		push_error("Native relay exceeded 180 second wall-clock guard")
		get_tree().quit(1)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--relay-preflight"):
		check(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(), "preflight has isolated absolute save")
		check(Route != null and Route.resource_path == get_script().resource_path.get_base_dir().path_join("buoy_relay_route.gd"), "native helper is the explicit adjacent resource")
		for i in range(1, 4):
			var texture: Texture2D = load("res://assets/ui/tutorials/game-019-step-%02d.png" % i)
			check(texture != null and texture.get_size() == Vector2(1280, 720), "native tutorial PNG loads 1280x720")
		await finish("PASS: relay native fixture adjacent helper and three real tutorial PNGs", false)
		return
	capture_dir = OS.get_environment("RELAY_CAPTURE_DIR")
	tutorial_dir = OS.get_environment("RELAY_TUTORIAL_DIR")
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not capture_dir.is_absolute_path() or (not tutorial_dir.is_empty() and not tutorial_dir.is_absolute_path()) or DisplayServer.get_name() == "headless":
		push_error("Native relay requires absolute isolated save/capture paths and a GPU window")
		get_tree().quit(1)
		return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var mode := OS.get_environment("RELAY_REVIEW_MODE")
	var assisted := mode == "assisted"
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		var large := OS.get_environment("RELAY_LARGE_TEXT") == "1"
		Progress.settings["ui_scale"] = 1.25 if large else 1.0
		Progress.settings["reduced_motion"] = large
		# Explicit synthetic six-card harbor admission; no game019 card is seeded.
		for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SETUP: six synthetic welcome cards; game019 must be genuinely earned")
		check(Progress.set_current_region("harbor"), "synthetic profile enters harbor")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	if mode == "read":
		check(Progress.photos.has("photo-harbor-game-7") and Progress.achievements.has("ACH_GAME_019") and Progress.has_seen_tutorial("game-019"), "restart reads earned019 card, achievement and lesson")
		check(_photo_valid(), "restart reads real original PNG")
		main._show_album()
		await capture("restart-album")
		await finish("PASS: native relay saved harbor restart, earned card and original PNG")
		return
	main._interact("game-019", "浮標接力")
	await frames(2)
	check(main.modal_kind == "game_info", "actual kiosk opens invitation")
	await capture("invite")
	if tutorial_dir.is_empty():
		main._request_game_start("game-019", assisted)
		await frames(3)
		check(is_instance_valid(main.tutorial_panel), "first entry opens the real lesson")
		await capture("tutorial")
		main._tutorial_start("game-019")
	else:
		check(Progress.mark_game_tutorial_seen("game-019"), "asset capture marks the real lesson identifier")
		main._launch_game("game-019", assisted)
	await frames(4)
	var session: Control = main.session
	check(session != null and session.game_id == "game-019" and session.assisted == assisted, "actual019 launch")
	if session == null:
		await finish()
		return
	session.set_process(false)
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	var commands: RefCounted = Route.SessionCommands.new(session)
	await capture("step-01", 1)
	var coins: int = Progress.coins
	if mode == "timeout":
		for i in 2500:
			if main.session == null: break
			session._process(0.1)
			if i % 40 == 0: await frames(1)
	else:
		await play(commands, session, mode != "main")
	await frames(5)
	check(main.session == null and results.size() == 1, "one natural Main result")
	if not results.is_empty():
		var result: Dictionary = results[0]
		var success := mode != "timeout"
		check(result.ordinary_eligible and result.success == success and result.devil == (success and mode != "main"), "truthful eligibility, success and devil")
		print("ACTUAL RESULT: ", JSON.stringify(result))
	check(Progress.normal_count_for_zone("harbor") == 1 and Progress.coins == coins + 40, "one real local card and one 40-coin receipt")
	check(_photo_valid(), "real result has bounded original PNG")
	await capture("step-03", 3 if mode == "" else 0)
	main._close()
	main._show_album()
	await capture("album")
	main._close()
	main._show_map()
	await capture("map")
	main._close()
	check(Progress.save_progress(), "actual writer saves profile")
	await finish()

## Plays the relay with the real action key; captures the handoff lock at the middle buoy.
func play(commands: RefCounted, session: Control, devil: bool) -> void:
	var captured := false
	for frame in 9000:
		if main.session == null: return
		var state: Dictionary = session.active_driver.snapshot()
		if state.ended: break
		match state.phase:
			"aim_catch":
				var landing: float = Route.plan_catch(state, devil and not state.double_catch)
				if is_nan(landing):
					commands.step(1.0 / 60.0)
				else:
					Route.throw_with(commands, Route.power_for(landing - state.station_x), 1.0 / 60.0)
			"reeling":
				commands.set_action(absf(float(state.bundle_wobble)) < (0.45 if state.held.size() > 1 else 0.65))
				commands.step(1.0 / 60.0)
			"aim_pass":
				var target := 1 if state.station == 2 else 0
				var power: float = Route.power_for(float(state.station_x) - float(state.stations[target]))
				commands.set_action(true)
				for i in 200:
					if session.active_driver.snapshot().power >= power - 0.004: break
					commands.step(1.0 / 60.0)
				if not captured and session.active_driver.snapshot().lock >= 0:
					captured = true
					await capture("step-02", 2)
				commands.set_action(false)
			_:
				commands.step(1.0 / 60.0)
		if frame % 3 == 0: await frames(1)
	commands.set_action(false)
	if main.session != null: session._process(0.0)

func _photo_valid() -> bool:
	var record: Dictionary = Progress.photos.get("photo-harbor-game-7", {})
	var originals: Array = record.get("original_frames", [])
	var thumbnails: Array = record.get("frames", [])
	if originals.is_empty() or thumbnails.is_empty(): return false
	var thumbnail := Image.load_from_file(str(thumbnails[0]))
	var image := Image.load_from_file(str(originals[0]))
	return thumbnail != null and thumbnail.get_size() == Vector2i(320, 180) and image != null and image.get_width() * image.get_height() <= 4 * 1024 * 1024

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func capture(label: String, tutorial_step: int = 0) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null, "capture actual image: " + label)
	if image == null: return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(image.save_png(capture_dir.path_join(label + ".png")) == OK, "write capture: " + label)
	if tutorial_step > 0 and not tutorial_dir.is_empty():
		check(image.get_size() == Vector2i(1280, 720), "real tutorial source is 1280x720")
		check(image.save_png(tutorial_dir.path_join("game-019-step-%02d.png" % tutorial_step)) == OK, "write real tutorial step")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func finish(marker: String = "PASS: native relay Main actual controls, truthful result, real photos and map", has_main: bool = true) -> void:
	if has_main and main != null:
		if main.session != null: main._cancel_game()
		main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		for i in 12: await get_tree().process_frame
	for problem in failures: push_error(problem)
	print(marker if failures.is_empty() else "FAIL: native relay Main")
	get_tree().quit(0 if failures.is_empty() else 1)
