extends "res://game/tests/native_balloon_controls_review.gd"

## Source screenshots for the safe, uncounted learn-by-doing flight.
func _run() -> void:
	if not _native_preflight("Balloon lesson source capture"): return
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _enter_station() or not await _launch_from_station("開始遊玩"): return
	if active.balloon_started or active.elapsed != 0.0:
		await _fail("Safe intro began consuming the formal clock");return
	await _shot("balloon-safe-intro")
	var origin: Vector2 = active.p
	_held_key(KEY_RIGHT, true)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.35).timeout
	_held_key(KEY_RIGHT, false)
	_set_space(true)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.2).timeout
	if active.p.x <= origin.x or not active.balloon_braking or active.balloon_started or active.elapsed != 0.0:
		await _fail("Safe movement/braking did not preserve the uncounted lesson");return
	await _shot("balloon-safe-brake")
	_release_route_inputs()
	print("PASS: actual safe intro movement and braking with zero formal elapsed, exclusive current tutorial source screenshots")
	await main._quit_game()
