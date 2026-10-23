extends "res://game/tests/native_hat_rescue_review.gd"

## Captures the three current lesson screenshots from a real keyboard round:
## 1 a gust pushing an airborne brim with the bow pennant and sea wind lines,
## 2 the reach moment just before a brim crosses the hand line,
## 3 a paired gust with numbered landing rings. Only input events are sent.
const OUT := ".review/hat-lesson"

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Hat lesson capture requires a display and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	progress.settings["time_phase"] = "noon"
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _launch_hat(false): return
	var session_id: int = main.session.get_instance_id()
	var wanted := {"wind": false, "reach": false, "pair": false}
	var held := 0
	var ticks_left := 30 * Engine.physics_ticks_per_second
	while ticks_left > 0 and wanted.values().has(false):
		await get_tree().physics_frame
		ticks_left -= 1
		var session := _session_by_id(session_id)
		if session == null:
			break
		var state: Dictionary = session.hat_model.snapshot()
		var target_index := -1
		var best_eta := INF
		for index in state.hats.size():
			var hat: Dictionary = state.hats[index]
			if bool(hat.active) and not bool(hat.resolved) and float(hat.eta) < best_eta:
				best_eta = float(hat.eta)
				target_index = index
		var target_x := float(state.hats[target_index].landing_x) if target_index >= 0 else float(state.next_spawn_x) if int(state.next_hat_index) >= 0 else float(state.player_x)
		var velocity := float(state.player_velocity)
		var distance: float = target_x - float(state.player_x)
		var braking: float = velocity * velocity / (2.0 * session.hat_model.PLAYER_ACCEL) + 24.0
		var direction := 0
		if absf(velocity) > 24.0 and signf(distance) == signf(velocity) and absf(distance) <= braking:
			direction = -int(signf(velocity))
		elif absf(distance) > 18.0:
			direction = int(signf(distance))
		if direction != held:
			if held != 0: _held_key(KEY_RIGHT if held > 0 else KEY_LEFT, false)
			if direction != 0: _held_key(KEY_RIGHT if direction > 0 else KEY_LEFT, true)
			held = direction
		if target_index >= 0 and best_eta <= 0.30 and float(state.catch_window) <= 0.0:
			_key(KEY_SPACE)
		if not wanted.wind and target_index >= 0 and absf(float(state.wind_strength)) > 120.0 and int(state.airborne_count) == 1 and float(state.hats[target_index].y) > 300.0:
			wanted.wind = await _save("game-005-step-01")
		elif not wanted.reach and wanted.wind and float(state.catch_window) > 0.0 and best_eta < 0.12 and absf(velocity) < 60.0:
			wanted.reach = await _save("game-005-step-02")
		elif not wanted.pair and int(state.airborne_count) == 2 and absf(float(state.wind_strength)) > 60.0:
			wanted.pair = await _save("game-005-step-03")
	if held != 0: _held_key(KEY_RIGHT if held > 0 else KEY_LEFT, false)
	if wanted.values().has(false):
		await _fail("Lesson capture missed a moment: " + str(wanted))
		return
	print("PASS: SG-20 lesson screenshots captured from real keyboard play (wind push, reach moment, paired gust)")
	await main._quit_game()

func _save(name: String) -> bool:
	await RenderingServer.frame_post_draw
	if not main._capture("%s/%s.png" % [OUT, name]):
		push_error("Could not capture " + name)
		return false
	return true
