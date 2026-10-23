extends "res://game/tests/native_fountain_review.gd"

## Generic first-entry and leave flow for one welcome game (real input only):
## the lesson pages appear before any Session exists (no round clock), Start
## launches a fresh round, and Pause → 離開小遊戲 → confirm returns to the park
## without changing progress. Usage: -- --flow-game=game-006 [--flow-out=.review/flow]
func _process(_delta: float) -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

func _wall_deadline_ms(simulated_milliseconds: int) -> int:
	var fixed_clock := not Engine.get_write_movie_path().is_empty() or OS.get_cmdline_args().has("--fixed-fps")
	return Time.get_ticks_msec() + ceili(float(simulated_milliseconds) * (40.0 if fixed_clock else 1.0))

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Flow review requires a display and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	var game_id := ""
	var out := ".review/flow"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--flow-game="): game_id = arg.trim_prefix("--flow-game=")
		elif arg.begins_with("--flow-out="): out = arg.trim_prefix("--flow-out=")
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.save_progress()
	main = _instantiate_main(false)
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	for point in main.world.points:
		if point.id == game_id: main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
	var deadline := _wall_deadline_ms(3500)
	while main.world.nearest.get("id", "") != game_id and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_key(KEY_E)
	if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "station details"): return
	if not await _activate_main_button("開始遊玩", "first entry " + game_id): return
	if not await _wait_until(func() -> bool: return is_instance_valid(main.tutorial_panel), "first lesson"): return
	var steps: int = main.tutorial_panel.steps.size() if main.tutorial_panel.get("steps") is Array else 3
	for step in steps:
		await _frames(4)
		if main.session != null or main.tutorial_panel.current_step != step:
			await _fail("Lesson page %d ran a round or skipped a page" % step)
			return
		await RenderingServer.frame_post_draw
		main._capture("%s/%s-lesson-%d.png" % [out, game_id, step + 1])
		if step < steps - 1 and not await _native_click_button(_find(main.tutorial_panel, "下一步"), "next lesson page"): return
	if not await _native_click_button(_find(main.tutorial_panel, "開始挑戰"), "start after lesson"): return
	if not await _wait_until(func() -> bool: return main.session != null and main.session.game_id == game_id, "fresh round"): return
	if not progress.has_seen_tutorial(game_id) or float(main.session.elapsed) > 0.5:
		await _fail("Round after the lesson was not fresh or the lesson was not recorded")
		return
	var protected := {"photos": progress.photos.duplicate(true), "achievements": progress.achievements.duplicate(true), "coins": progress.coins}
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	main._capture("%s/%s-round.png" % [out, game_id])
	var hud: Node = main.session.minigame_hud
	if not await _native_click_button(hud.find_child("PauseButton", true, false), "pause"): return
	if not await _native_click_button(hud.find_child("LeaveButton", true, false), "leave"): return
	if not await _native_click_button(hud.find_child("ConfirmAction", true, false), "confirm leave"): return
	if not await _wait_until(func() -> bool: return main.session == null and main.modal_kind == "", "back in the park"): return
	if progress.photos != protected.photos or progress.achievements != protected.achievements or progress.coins != protected.coins:
		await _fail("Leaving a round changed collection or currency")
		return
	print("PASS: %s first lesson before any round clock, fresh round after Start, pause-leave back to park with unchanged progress" % game_id)
	await main._quit_game()
