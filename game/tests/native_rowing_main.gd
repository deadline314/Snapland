extends Node
## Automated fixed-input review, not a human playtest. Copy this script and
## adjacent rowing_input_route.gd explicitly when release excludes game/tests.
var Route: Script = load(get_script().resource_path.get_base_dir().path_join("rowing_input_route.gd"))
var main: Node
var failures: Array[String] = []
var capture_dir := ""
var tutorial_dir := ""
var finish_results: Array[Dictionary] = []
var _dock_captured := false
var _started := Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec()-_started > 180000:
		push_error("Native rowing exceeded180second wall-clock guard")
		get_tree().quit(1)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--rowing-preflight"):
		var isolated := OS.get_environment("SNAPLAND_SAVE_PATH")
		check(isolated.is_absolute_path(), "preflight has isolated absolute save")
		check(Route != null and Route.resource_path == get_script().resource_path.get_base_dir().path_join("rowing_input_route.gd"), "native helper is explicit adjacent resource")
		for i in range(1,4):
			var path := "res://assets/ui/tutorials/game-013-step-%02d.png" % i
			var texture: Texture2D = load(path)
			check(texture != null and texture.get_size() == Vector2(1280,720), "native tutorial PNG loads1280x720")
		for problem in failures: push_error(problem)
		print("PASS: rowing native fixture adjacent helper and three real tutorial PNGs" if failures.is_empty() else "FAIL: native rowing preflight")
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	var profile := OS.get_environment("SNAPLAND_SAVE_PATH")
	capture_dir = OS.get_environment("ROWING_CAPTURE_DIR")
	tutorial_dir = OS.get_environment("ROWING_TUTORIAL_DIR")
	if not profile.is_absolute_path() or not capture_dir.is_absolute_path() or (not tutorial_dir.is_empty() and not tutorial_dir.is_absolute_path()) or DisplayServer.get_name() == "headless":
		push_error("Native rowing requires absolute isolated save/capture paths and GPU")
		get_tree().quit(1)
		return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var mode := OS.get_environment("ROWING_REVIEW_MODE")
	var assisted := mode == "assisted"
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		Progress.settings["ui_scale"] = 1.25 if OS.get_environment("ROWING_LARGE_TEXT") == "1" else 1.0
		Progress.settings["reduced_motion"] = OS.get_environment("ROWING_LARGE_TEXT") == "1"
		# Explicit synthetic six-card eligibility setup; no game013 card is seeded.
		for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SETUP: six synthetic welcome cards; game013 must be genuinely earned")
		check(Progress.set_current_region("harbor"), "synthetic profile enters harbor")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	check(main.world_region == "harbor" and main.definitions.size() == 12, "saved harbor startup and welcome12 default")
	if mode == "read":
		check(Progress.photos.has("photo-harbor-game-1") and Progress.achievements.has("ACH_GAME_013") and Progress.wardrobe_rewarded_games.has("game-013"), "restart reads actual013 card, global achievement and receipt")
		check(Progress.has_seen_tutorial("game-013"), "restart reads actual tutorial seen")
		check(_photo_valid(), "restart reads real original PNG")
		main._show_album()
		await capture("restart-album")
		await finish("PASS: native rowing saved harbor restart, earned card and original PNG")
		return
	main._interact("game-013", "浪間小艇")
	await frames(2)
	check(main.modal_kind == "game_info", "actual kiosk opens normal invitation")
	main.overlay.find_child("InviteRules", true, false).pressed.emit()
	await frames(2)
	check(main.modal_kind == "game_rules", "actual rules action")
	if tutorial_dir.is_empty():
		button("圖解教學").pressed.emit()
		await frames(2)
		await capture("tutorial")
		button("練習操作").pressed.emit()
		await frames(2)
		check(main.session != null and main.session.practice_mode, "tutorial practice route")
		if mode == "gap": await play_gap(main.session)
		await pause_help_cancel()
		if mode == "gap":
			check(Progress.normal_count_for_zone("harbor") == 0, "gap practice awards nothing")
			await finish("PASS: native rowing exposed tide-gap public-input crossing")
			return
		check(Progress.normal_count_for_zone("harbor") == 0, "practice and cancel award nothing")
		main._show_game_info("game-013")
		main._request_game_start("game-013", assisted)
		await frames(2)
		check(is_instance_valid(main.tutorial_panel), "first normal entry opens unseen lesson")
		button("開始挑戰").pressed.emit()
		await frames(3)
	else:
		# Initial asset capture bootstraps the real lesson images from real gameplay.
		check(Progress.mark_game_tutorial_seen("game-013"), "asset capture marks real lesson identifier")
		main._launch_game("game-013", assisted)
	await frames(4)
	var session: Control = main.session
	check(session != null and session.game_id == "game-013" and session.assisted == assisted, "actual013 launch")
	if session == null:
		await finish()
		return
	session.set_process(false)
	session.finished.connect(record_finished.bind(session))
	await capture("step-01", 1)
	var coins: int = Progress.coins
	if mode == "timeout":
		for i in 4000:
			if main.session == null: break
			session._process(0.1)
			if i % 40 == 0: await frames(1)
	else:
		await play_route(session, assisted)
		check(_dock_captured, "real docking gameplay capture produced")
	await frames(5)
	check(main.session == null and finish_results.size() == 1, "one natural Main result")
	if not finish_results.is_empty():
		var result: Dictionary = finish_results[0]
		check(result.ordinary_eligible and result.success == (mode != "timeout"), "truthful ordinary eligibility and actual success")
		check(result.devil == (mode != "timeout") and result.score == (0 if mode == "timeout" else 300), "actual three-delivery devil or natural zero-score failure")
		print("ACTUAL RESULT: ", JSON.stringify(result))
	check(Progress.normal_count_for_zone("harbor") == 1 and Progress.devil_count("harbor") == (0 if mode == "timeout" else 1), "one real local card and truthful devil")
	check(Progress.coins == coins + 40 and Progress.wardrobe_rewarded_games.count("game-013") == 1, "only one global40coin receipt")
	check(_photo_valid(), "real result has bounded original PNG")
	await capture("step-03", 3 if mode != "timeout" else 0)
	main._close()
	main._show_album()
	await capture("album")
	main._close()
	main._show_achievements()
	await capture("stamps")
	main._close()
	main._show_map()
	await capture("map")
	var player_before: Vector3 = main.world.player.position
	main.overlay.find_child("HarborGamegame-013", true, false).pressed.emit()
	check(main.modal_kind == "game_info" and main.world.player.position == player_before, "read-only map opens invitation without teleport")
	main._request_game_start("game-013", assisted)
	await frames(3)
	check(main.session != null and not is_instance_valid(main.tutorial_panel), "seen tutorial skips on replay")
	var replay: Control = main.session
	replay.set_process(false)
	if mode != "timeout": await play_route(replay, assisted)
	else: replay._leave_from_hud()
	await frames(3)
	check(Progress.coins == coins + 40 and Progress.normal_count_for_zone("harbor") == 1, "real replay does not duplicate reward")
	check(Progress.save_progress(), "actual writer saves profile")
	await finish()

func record_finished(result: Dictionary, completed: Control) -> void:
	finish_results.append(result.duplicate(true))
	var actual: Dictionary = completed.active_driver.snapshot()
	check(actual.success == result.success and actual.score == result.score, "actual model and emitted result agree")
	check(actual.delivery_ledger.size() == (3 if result.success else 0), "actual ledger matches genuine deliveries")
	print("ACTUAL MODEL LEDGER: ",actual.delivery_ledger," crate_impacts=",actual.crate_impacts," walls=",actual.wall_collisions)

func play_route(session: Control, assisted: bool) -> void:
	var delta := float(OS.get_environment("ROWING_STEP")) if not OS.get_environment("ROWING_STEP").is_empty() else 0.025
	check(delta >= 1.0/120.0 and delta <= 0.05, "bounded fixed-input cadence")
	var planned: RefCounted = Route.RecordingCommands.new(assisted, delta)
	Route.solve(planned)
	check(planned.snapshot().success and planned.snapshot().devil, "public-command planner found real route")
	await play_commands(session, planned, true)
	if main.session != null: session._process(0.0)
	print("PUBLIC INPUT PLAYBACK: step=", delta, " planned ledger=", planned.snapshot().delivery_ledger)

func play_commands(session: Control, planned: RefCounted, capture_dock: bool = false) -> void:
	var commands: RefCounted = Route.SessionCommands.new(session)
	var ticks := 0
	for event in planned.events:
		if main.session == null: break
		match event[0]:
			"interact", "clear_input": commands.call(event[0])
			_: commands.call(event[0], event[1])
		if event[0] == "step":
			ticks += 1
			if ticks % 8 == 0: await frames(1)
			var state: Dictionary = session.active_driver.snapshot()
			if capture_dock and not _dock_captured and state.position.distance_to(Vector2(8.0,-3.0)) < state.dock_radius and state.speed < 0.6 and absf(state.heading) < 0.15 and state.crest and state.delivery_ledger.is_empty():
				_dock_captured = true
				await capture("step-02", 2)

func play_gap(session: Control) -> void:
	session.set_process(false)
	var planned: RefCounted = Route.RecordingCommands.new(false)
	Route.navigate(planned, Vector2(-4.0, 0.0))
	await play_commands(session, planned)
	var near: Dictionary = session.active_driver.snapshot()
	check(near.position.distance_to(Vector2(-4,0)) < 0.6, "public keys reach exposed near-gap approach")
	await capture("gap-near")
	planned.events.clear()
	Route.navigate(planned, Vector2(4.0, 0.0))
	await play_commands(session, planned)
	var far: Dictionary = session.active_driver.snapshot()
	check(far.position.distance_to(Vector2(4,0)) < 0.6 and not far.sheltered, "public keys cross real exposed central tide gap")
	print("ACTUAL EXPOSED GAP: near=",near.position," far=",far.position," half_width=",far.gap.half_width," elapsed=",far.elapsed," walls=",far.wall_collisions)
	await capture("gap-far")

func pause_help_cancel() -> void:
	var session: Control = main.session
	session.set_process(false)
	var commands: RefCounted = Route.SessionCommands.new(session)
	commands.key(KEY_D, true)
	session.minigame_hud.find_child("PauseButton", true, false).pressed.emit()
	await frames(2)
	var frozen: Dictionary = session.active_driver.snapshot()
	session._process(5.0)
	check(session.paused and frozen.rudder == 0 and frozen == session.active_driver.snapshot(), "real pause clears rudder and freezes")
	session.minigame_hud.find_child("HelpButton", true, false).pressed.emit()
	await frames(2)
	check(is_instance_valid(main.tutorial_panel), "session help opens real lesson")
	button("關閉").pressed.emit()
	await frames(2)
	check(session.paused and session.active_driver.snapshot() == frozen, "help close preserves paused real state")
	session.minigame_hud.find_child("ResumeButton", true, false).pressed.emit()
	session._process(99.0)
	check(not session.paused and session.active_driver.snapshot() == frozen, "resume discards suspended delta")
	session.minigame_hud.find_child("PauseButton", true, false).pressed.emit()
	await frames(2)
	session.minigame_hud.find_child("LeaveButton", true, false).pressed.emit()
	await frames(2)
	session.minigame_hud.find_child("ConfirmAction", true, false).pressed.emit()
	await frames(3)

func _photo_valid() -> bool:
	var record: Dictionary = Progress.photos.get("photo-harbor-game-1", {})
	var originals: Array = record.get("original_frames", [])
	var thumbnails: Array = record.get("frames", [])
	if originals.is_empty() or thumbnails.is_empty(): return false
	var thumbnail := Image.load_from_file(str(thumbnails[0]))
	if thumbnail == null or thumbnail.get_size() != Vector2i(320,180): return false
	var image := Image.load_from_file(str(originals[0]))
	return image != null and image.get_width() > 0 and image.get_height() > 0 and image.get_width()*image.get_height() <= 4*1024*1024

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func capture(label: String, tutorial_step: int = 0) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(get_viewport().get_visible_rect().size), "capture actual dimensions: " + label)
	if image == null: return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(image.save_png(capture_dir.path_join(label+".png")) == OK, "write actual capture: " + label)
	if tutorial_step > 0 and not tutorial_dir.is_empty():
		check(image.get_size() == Vector2i(1280,720), "real tutorial source1280x720")
		check(image.save_png(tutorial_dir.path_join("game-013-step-%02d.png" % tutorial_step)) == OK, "write real tutorial step")

func button(text: String) -> Button:
	return _button(main.tutorial_panel if is_instance_valid(main.tutorial_panel) else main.ui, text)

func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null: return found
	return null

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func finish(marker: String = "PASS: native rowing Main actual controls, truthful result, real photos, replay and restart") -> void:
	if main.session != null: main._cancel_game()
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	for i in 12: await get_tree().process_frame
	for problem in failures: push_error(problem)
	print(marker if failures.is_empty() else "FAIL: native rowing Main")
	get_tree().quit(0 if failures.is_empty() else 1)
