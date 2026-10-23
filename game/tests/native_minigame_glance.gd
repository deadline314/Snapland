extends "res://game/tests/native_fountain_review.gd"

## Developer glance capture: launch listed welcome games from their real station
## and save a few timed frames. It drives no gameplay input beyond Start/Enter and
## asserts nothing about play quality. Usage (non-headless, isolated save):
##   godot --path . res://game/tests/native_minigame_glance.tscn -- --glance=game-005 --glance-out=.review/glance
func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Glance capture requires a display and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	var ids: PackedStringArray = []
	var out := ".review/glance"
	var phase := "noon"
	var times: PackedFloat64Array = [2.0, 4.0, 6.0]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glance="): ids = arg.trim_prefix("--glance=").split(",", false)
		elif arg.begins_with("--glance-out="): out = arg.trim_prefix("--glance-out=")
		elif arg.begins_with("--glance-phase="): phase = arg.trim_prefix("--glance-phase=")
		elif arg.begins_with("--glance-at="): times = arg.trim_prefix("--glance-at=").split_floats(",", false)
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["time_phase"] = phase
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	for id in ids:
		for point in main.world.points:
			if point.id == id: main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
		var deadline := Time.get_ticks_msec() + 3000
		while main.world.nearest.get("id", "") != id and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		_key(KEY_E)
		if not await _wait_until(func() -> bool: return main.modal_kind == "game_info", "station info " + id): return
		if not await _activate_main_button("開始遊玩", "start " + id): return
		if not await _wait_until(func() -> bool: return main.session != null, "session " + id): return
		await get_tree().create_timer(0.4).timeout
		main._capture("%s/%s-0-start.png" % [out, id])
		_key(KEY_ENTER)
		var waited := 0.0
		for shot in times.size():
			await get_tree().create_timer(maxf(0.0, times[shot] - waited)).timeout
			waited = maxf(waited, times[shot])
			await RenderingServer.frame_post_draw
			main._capture("%s/%s-%d.png" % [out, id, shot + 1])
		# One game per process keeps each capture independent of the previous round.
		break
	print("PASS: glance captures saved to " + out)
	await main._quit_game()
