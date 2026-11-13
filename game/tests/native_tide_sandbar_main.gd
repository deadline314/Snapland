extends Node
## Automated fixed-input review, not a human playtest. Copy this script and the
## adjacent tide_sandbar_route.gd explicitly when a release excludes game/tests.
var Route: Script = load(get_script().resource_path.get_base_dir().path_join("tide_sandbar_route.gd"))
var main: Node
var failures: Array[String] = []
var capture_dir := ""
var tutorial_dir := ""
var results: Array[Dictionary] = []
var _started := Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started > 180000:
		push_error("Native sandbar exceeded 180 second wall-clock guard")
		get_tree().quit(1)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--sandbar-preflight"):
		check(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(), "preflight has isolated absolute save")
		check(Route != null and Route.resource_path == get_script().resource_path.get_base_dir().path_join("tide_sandbar_route.gd"), "native helper is the explicit adjacent resource")
		for i in range(1, 4):
			var texture: Texture2D = load("res://assets/ui/tutorials/game-014-step-%02d.png" % i)
			check(texture != null and texture.get_size() == Vector2(1280, 720), "native tutorial PNG loads 1280x720")
		await finish("PASS: sandbar native fixture adjacent helper and three real tutorial PNGs", false)
		return
	var profile := OS.get_environment("SNAPLAND_SAVE_PATH")
	capture_dir = OS.get_environment("SANDBAR_CAPTURE_DIR")
	tutorial_dir = OS.get_environment("SANDBAR_TUTORIAL_DIR")
	if not profile.is_absolute_path() or not capture_dir.is_absolute_path() or (not tutorial_dir.is_empty() and not tutorial_dir.is_absolute_path()) or DisplayServer.get_name() == "headless":
		push_error("Native sandbar requires absolute isolated save/capture paths and a GPU window")
		get_tree().quit(1)
		return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var mode := OS.get_environment("SANDBAR_REVIEW_MODE")
	var assisted := mode == "assisted"
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		var large := OS.get_environment("SANDBAR_LARGE_TEXT") == "1"
		Progress.settings["ui_scale"] = 1.25 if large else 1.0
		Progress.settings["reduced_motion"] = large
		# Explicit synthetic six-card harbor admission; no game014 card is seeded.
		for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SETUP: six synthetic welcome cards; game014 must be genuinely earned")
		check(Progress.set_current_region("harbor"), "synthetic profile enters harbor")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	if mode == "read":
		check(Progress.photos.has("photo-harbor-game-2") and Progress.achievements.has("ACH_GAME_014") and Progress.has_seen_tutorial("game-014"), "restart reads earned014 card, achievement and lesson")
		check(_photo_valid(), "restart reads real original PNG")
		main._show_album()
		await capture("restart-album")
		await finish("PASS: native sandbar saved harbor restart, earned card and original PNG")
		return
	main._interact("game-014", "潮汐沙路")
	await frames(2)
	check(main.modal_kind == "game_info", "actual kiosk opens invitation")
	await capture("invite")
	if tutorial_dir.is_empty():
		main._request_game_start("game-014", assisted)
		await frames(3)
		check(is_instance_valid(main.tutorial_panel), "first entry opens the real lesson")
		await capture("tutorial")
		main._tutorial_start("game-014")
	else:
		check(Progress.mark_game_tutorial_seen("game-014"), "asset capture marks the real lesson identifier")
		main._launch_game("game-014", assisted)
	await frames(4)
	var session: Control = main.session
	check(session != null and session.game_id == "game-014" and session.assisted == assisted, "actual014 launch")
	if session == null:
		await finish()
		return
	session.set_process(false)
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	await capture("step-01", 1)
	var coins: int = Progress.coins
	if mode == "fall":
		await fall_and_rope(session)
		await finish("PASS: native sandbar visible rope recovery from a real flooded crossing")
		return
	if mode == "timeout":
		for i in 2000:
			if main.session == null: break
			session._process(0.1)
			if i % 40 == 0: await frames(1)
	else:
		await play(session, Route.FAR_FIRST if mode == "far" else Route.SECURE_FIRST)
	await frames(5)
	check(main.session == null and results.size() == 1, "one natural Main result")
	if not results.is_empty():
		var result: Dictionary = results[0]
		var success := mode != "timeout"
		check(result.ordinary_eligible and result.success == success and result.devil == (success and mode != "far"), "truthful eligibility, success and devil")
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

## Replays public key inputs in real frames and captures the reef marking moment.
func play(session: Control, route: Array) -> void:
	var commands: RefCounted = Route.SessionCommands.new(session)
	var captured := false
	for leg: Array in route:
		for frame in 6000:
			if main.session == null: return
			var state: Dictionary = session.active_driver.snapshot()
			var offset: Vector2 = Route.anchor_position(state, leg[0]) - state.position
			if offset.length() <= 0.3 and not state.rescuing:
				commands.clear_input()
				break
			commands.set_running(true)
			commands.set_move(offset.normalized())
			commands.step(1.0 / 60.0)
			if frame % 3 == 0: await frames(1)
		if leg[1]:
			commands.interact()
			if not captured and leg[0] == "reef_far":
				captured = true
				await capture("step-02", 2)
	for i in 30:
		if main.session == null: return
		commands.step(1.0 / 60.0)

## Walks (no running) across the far shallow after it floods; the helper's rope is captured mid-pull.
func fall_and_rope(session: Control) -> void:
	var commands: RefCounted = Route.SessionCommands.new(session)
	for leg in [["dune", true], ["reef_far", false]]:
		for frame in 6000:
			var state: Dictionary = session.active_driver.snapshot()
			if state.rescuing:
				break
			var offset: Vector2 = Route.anchor_position(state, leg[0]) - state.position
			if offset.length() <= 0.3:
				commands.clear_input()
				break
			commands.set_move(offset.normalized())
			commands.step(1.0 / 60.0)
			if frame % 3 == 0: await frames(1)
		if leg[1]: commands.interact()
	commands.clear_input()
	var state: Dictionary = session.active_driver.snapshot()
	check(state.rescuing and state.falls == 1, "slow crossing actually falls into the flooded shallow")
	for i in 50:
		session._process(1.0 / 60.0)
	await frames(2)
	check(session.active_driver.snapshot().rope.pulling, "rope is visibly pulling")
	await capture("rope")
	for i in 300:
		if not session.active_driver.snapshot().rescuing: break
		session._process(1.0 / 60.0)
	await capture("rope-recovered")
	check(Route.anchor_position(session.active_driver.snapshot(), "dune").distance_to(session.active_driver.snapshot().position) < 0.01, "rope lands on the marked dune")

func _photo_valid() -> bool:
	var record: Dictionary = Progress.photos.get("photo-harbor-game-2", {})
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
		check(image.save_png(tutorial_dir.path_join("game-014-step-%02d.png" % tutorial_step)) == OK, "write real tutorial step")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func finish(marker: String = "PASS: native sandbar Main actual controls, truthful result, real photos and map", has_main: bool = true) -> void:
	if has_main and main != null:
		if main.session != null: main._cancel_game()
		main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		for i in 12: await get_tree().process_frame
	for problem in failures: push_error(problem)
	print(marker if failures.is_empty() else "FAIL: native sandbar Main")
	get_tree().quit(0 if failures.is_empty() else 1)
