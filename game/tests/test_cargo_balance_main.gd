extends Node

const Route = preload("res://game/tests/cargo_balance_route.gd")
var failures: Array[String] = []
var main: Node

func _ready() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func solve(session: Control, devil: bool) -> void:
	session.set_process(false)
	Route.solve(Route.SessionCommands.new(session), devil)
	if main.session == session: session._process(0.0)

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): get_tree().quit(1); return
	Progress.reset_progress()
	Progress.intro_seen = true
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	check(main.definitions.size() == 12, "welcome definitions stay twelve")
	check(main._definition("game-018").get("mode", "") == "cargo_balance", "Main resolves global18")
	check(main._definition("game-120").is_empty(), "Main refuses an undelivered game")
	# Synthetic harbor admission only; the game018 cards are earned through Session inputs.
	for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
	check(main._travel_to_region("harbor"), "six welcome cards admit harbor")
	for i in 4: await get_tree().process_frame
	check(main.world._point_by_id("game-018").get("id", "") == "game-018", "real cargo kiosk for game018")
	main._show_map()
	await get_tree().process_frame
	var map_action = main.overlay.find_child("HarborGamegame-018", true, false)
	check(map_action is Button, "regional map offers game018 invitation")
	if map_action != null: map_action.pressed.emit()
	check(main.modal_kind == "game_info", "map opens normal invite")
	main._request_game_start("game-018", false)
	await get_tree().process_frame
	check(is_instance_valid(main.tutorial_panel) and main.tutorial_target == "game-018", "018 first-entry lesson")
	main._tutorial_start("game-018")
	for i in 3: await get_tree().process_frame
	check(Progress.has_seen_tutorial("game-018") and main.session != null, "first entry saves lesson and starts018")
	if main.session != null:
		var s: Control = main.session
		s.set_process(false)
		for i in 3000:
			if main.session == null: break
			s._process(0.1)
	check(Progress.photos.has("photo-harbor-game-6") and Progress.normal_count_for_zone("harbor") == 1 and Progress.devil_count("harbor") == 0, "timeout earns the harbor 6 ordinary card only")
	check(_text(main.overlay).contains("普通拍貼已收藏"), "timeout result states the saved ordinary card")
	check(Progress.wardrobe_rewarded_games.has("game-018") and Progress.achievements.has("ACH_GAME_018"), "global receipt and achievement018")
	var coins: int = Progress.coins
	main._launch_game("game-018", false, true)
	solve(main.session, true)
	check(main.session == null and Progress.coins == coins and Progress.devil_count("harbor") == 0, "practice bank double awards nothing")
	main._launch_game("game-018", false)
	solve(main.session, false)
	check(Progress.devil_count("harbor") == 0 and Progress.coins == coins, "normal success stays ordinary without new coins")
	main._launch_game("game-018", true)
	solve(main.session, true)
	check(main.session == null and Progress.photos.has("photo-harbor-devil-6") and Progress.devil_count("harbor") == 1 and Progress.coins == coins, "assisted bank double awards devil once")
	main._launch_game("game-018", false)
	main.session._leave_from_hud()
	check(main.session == null and Progress.coins == coins, "cancel awards nothing")
	check(not Progress.photos.has("photo-harbor-game-1") and not Progress.photos.has("photo-harbor-game-5"), "other harbor cards are not unlocked by game018")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.has_seen_tutorial("game-018") and Progress.normal_count_for_zone("harbor") == 1 and Progress.devil_count("harbor") == 1 and Progress.achievements.has("ACH_GAME_018"), "profile reload preserves game018")
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	for i in 12: await get_tree().process_frame
	for problem in failures: push_error(problem)
	print("PASS: cargo Main entry, regional map, tutorial, truthful timeout, practice, routes, assisted devil and reload" if failures.is_empty() else "FAIL: cargo Main")
	get_tree().quit(0 if failures.is_empty() else 1)

func _text(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += "\n" + _text(child)
	return result
