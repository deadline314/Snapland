extends Node

const Commands = preload("res://game/tests/rowing_input_route.gd").SessionCommands
const Solver = preload("res://game/tests/rowing_input_route.gd")
var failures: Array[String] = []
var main: Node

func _ready() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): get_tree().quit(1); return
	if OS.get_cmdline_user_args().has("--failure-child"):
		await _failure_child()
		return
	Progress.reset_progress()
	Progress.intro_seen = true
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	check(main.definitions.size() == 12, "welcome definitions stay twelve")
	check(main._definition("game-013").get("mode", "") == "rowing_cargo", "Main resolves global13")
	check(main._definition("game-014").is_empty(), "Main refuses undelivered14")
	if not failures.is_empty():
		main.audio.shutdown()
		main.queue_free()
		for problem in failures: push_error(problem)
		get_tree().quit(1)
		return
	# Synthetic eligibility only; game013 must be earned through Session inputs.
	for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
	check(main._travel_to_region("harbor"), "six welcome cards admit harbor")
	for i in 4: await get_tree().process_frame
	check(main.world._point_by_id("game-013").get("id", "") == "game-013", "real harbor kiosk")
	main._show_map()
	await get_tree().process_frame
	var map_action = main.overlay.find_child("HarborGamegame-013", true, false)
	check(map_action is Button, "regional map offers normal invitation action")
	if map_action != null: map_action.pressed.emit()
	check(main.modal_kind == "game_info", "map opens normal invite")
	main._request_game_start("game-013", false)
	await get_tree().process_frame
	check(is_instance_valid(main.tutorial_panel) and main.tutorial_target == "game-013", "013 first-entry lesson")
	main._tutorial_start("game-013")
	for i in 3: await get_tree().process_frame
	check(Progress.has_seen_tutorial("game-013") and main.session != null, "first-entry saves and starts013")
	if main.session != null:
		var s: Control = main.session
		s.set_process(false)
		s.set_paused(true)
		var state: Dictionary = s.active_driver.snapshot()
		s._process(10.0)
		check(s.active_driver.snapshot() == state, "Main pause freezes real model")
		s.set_paused(false)
		s._process(0.0)
		for i in 4000:
			if main.session == null: break
			s._process(0.1)
	check(Progress.normal_count_for_zone("harbor") == 1 and Progress.devil_count("harbor") == 0, "natural failure earns only ordinary")
	check(_text(main.overlay).contains("差一點") and _text(main.overlay).contains("普通拍貼已收藏"), "failure remains truthful alongside ordinary award")
	check(Progress.wardrobe_rewarded_games.has("game-013") and Progress.achievements.has("ACH_GAME_013"), "global receipt and achievement")
	var coins: int = Progress.coins
	main._launch_game("game-013", false, true)
	var practice: Control = main.session
	practice.set_process(false)
	Solver.solve(Commands.new(practice))
	practice._process(0.0)
	check(main.session == null and Progress.coins == coins and Progress.devil_count("harbor") == 0, "real successful practice does not award")
	main._launch_game("game-013", true)
	var actual: Control = main.session
	actual.set_process(false)
	Solver.solve(Commands.new(actual))
	actual._process(0.0)
	check(main.session == null and Progress.devil_count("harbor") == 1 and Progress.coins == coins, "assisted true delivery awards devil once")
	main._launch_game("game-013", false)
	var cancelled: Control = main.session
	cancelled._leave_from_hud()
	check(main.session == null and Progress.coins == coins, "cancel awards nothing")
	main._show_achievements()
	check(_text(main.overlay).contains("碼頭"), "Main selects regional stamps")
	main._close()
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.has_seen_tutorial("game-013") and Progress.normal_count_for_zone("harbor") == 1 and Progress.devil_count("harbor") == 1, "actual profile reload preserves13")
	await _failure_contract()
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	for i in 12: await get_tree().process_frame
	for problem in failures: push_error(problem)
	print("PASS: rowing Main entry, regional map, tutorial, truthful timeout, practice, assisted reward and reload" if failures.is_empty() else "FAIL: rowing Main")
	get_tree().quit(0 if failures.is_empty() else 1)

func _text(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += "\n" + _text(child)
	return result

func _failure_contract() -> void:
	var original := OS.get_environment("SNAPLAND_SAVE_PATH")
	var child := original.get_base_dir().path_join("failure/profile.json").replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(child.get_base_dir())
	OS.set_environment("SNAPLAND_SAVE_PATH", child)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "res://game/tests/test_rowing_main.tscn", "--", "--failure-child"]), output, true, false)
	OS.set_environment("SNAPLAND_SAVE_PATH", original)
	var log := "\n".join(output)
	var child_log := FileAccess.open(original.get_base_dir().path_join("failure-output.log"), FileAccess.WRITE)
	if child_log != null:
		child_log.store_string(log)
		child_log.close()
	var errors: Array[String] = []
	for line in log.split("\n"):
		if line.contains("ERROR:"): errors.append(line)
	check(code == 0 and log.contains("PASS: rowing Main save failure and retry"), "real failed-save child completes")
	var writes := errors.filter(func(line): return line.contains("Cannot write progress temporary file") and line.contains(child+".tmp"))
	var attachment := errors.filter(func(line): return line.contains("Could not save gameplay thumbnail paths for 'photo-harbor-game-1'."))
	if errors.size() != 3 or writes.size() != 2 or attachment.size() != 1:
		print("CHILD_DIAGNOSTICS=",JSON.stringify(errors)," EXPECTED_PATH=",child)
	check(errors.size() == 3 and writes.size() == 2 and attachment.size() == 1, "child captures only exact isolated completion/attachment failures")

func _failure_child() -> void:
	Progress.reset_progress()
	Progress.intro_seen = true
	for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
	Progress.set_current_region("harbor")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main._launch_game("game-013", false)
	var s: Control = main.session
	s.set_process(false)
	var actual: Array[Dictionary] = []
	s.finished.connect(func(result: Dictionary): actual.append(result.duplicate(true)))
	var blocker := Progress._save_path()+".tmp"
	check(DirAccess.make_dir_recursive_absolute(blocker) == OK, "block isolated temporary writer")
	var before_coins: int = Progress.coins
	for i in 4000:
		if main.session == null: break
		s._process(0.1)
	check(actual.size() == 1 and not actual[0].success and actual[0].ordinary_eligible, "failure child uses actual natural timeout")
	check(Progress.coins == before_coins and Progress.normal_count_for_zone("harbor") == 0 and not Progress.achievements.has("ACH_GAME_013"), "failed completion rolls back all rewards")
	check(_text(main.overlay).contains("收藏尚未保存") and not _text(main.overlay).contains("普通拍貼已收藏"), "failed writer does not claim saved reward")
	var retry := main.overlay.find_child("RetryGameSave", true, false) as Button
	check(retry != null, "failed completion offers retry")
	DirAccess.remove_absolute(blocker)
	if retry != null: retry.pressed.emit()
	check(Progress.normal_count_for_zone("harbor") == 1 and Progress.coins == before_coins+40, "real retry saves award once")
	# Actual result replay plus an explicitly synthetic PNG attachment fixture.
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color.TEAL)
	var path := Progress._save_path().get_base_dir().path_join("test-thumbnail.png")
	check(image.save_png(path) == OK, "write labelled attachment PNG fixture")
	DirAccess.make_dir_recursive_absolute(blocker)
	var paths: Array[String] = [path]
	main._game_finished(actual[0], paths, paths)
	check(_text(main.overlay).contains("照片尚未保存") and not Progress.photos["photo-harbor-game-1"].has("frames"), "failed attachment is truthful and rolls back")
	retry = main.overlay.find_child("RetryGameSave", true, false) as Button
	DirAccess.remove_absolute(blocker)
	if retry != null: retry.pressed.emit()
	check(Progress.photos["photo-harbor-game-1"].get("frames", []) == [path] and Progress.coins == before_coins+40, "attachment retry saves same actual result with no duplicate coins")
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	for i in 12: await get_tree().process_frame
	for problem in failures: push_error(problem)
	print("PASS: rowing Main save failure and retry" if failures.is_empty() else "FAIL: rowing Main failure child")
	get_tree().quit(0 if failures.is_empty() else 1)
