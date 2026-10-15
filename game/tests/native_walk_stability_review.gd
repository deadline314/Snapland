extends "res://game/tests/native_walk_review.gd"
## Real island native movement events. Appearance and open-ground placement are explicit fixtures.
var evidence_dir := ""
var captures: Array=[]
func _run() -> void:
	evidence_dir=OS.get_environment("SNAPLAND_WALK_NATIVE_DIR")
	if not evidence_dir.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Native walk regression requires isolated paths and GPU");get_tree().quit(1);return
	Engine.time_scale=0.25 if OS.get_environment("SNAPLAND_WALK_QUARTER")=="1" else 1.0
	progress=get_tree().root.get_node_or_null("Progress")
	progress.reset_progress();progress.intro_seen=true
	main=_instantiate_main();get_tree().root.add_child(main)
	await _frames(8)
	main.world.camera.size=11.0
	for fixture in [["front",[KEY_S]],["front_right",[KEY_S,KEY_D]],["right",[KEY_D]],["back_right",[KEY_W,KEY_D]],["back",[KEY_W]],["back_left",[KEY_W,KEY_A]],["left",[KEY_A]],["front_left",[KEY_S,KEY_A]]]:
		if not await _review_heading(fixture[0],fixture[1]):return
	for style in ["bob","curly"]:
		var appearance: Dictionary=WalkRenderer.DEFAULT_APPEARANCE.duplicate();appearance.hair=style
		main.world.set_avatar_look(appearance,{"outfit":"outfit-coral","hat":"hat-sailor"})
		for fixture in [["right",[KEY_D]],["left",[KEY_A]]]:
			if not await _review_heading(fixture[0],fixture[1]):return
	main.world.blocked=true
	var phase: float=main.world.walk_distance_phase
	var position: Vector3=main.world.player.position
	_held_key(KEY_D,true)
	await get_tree().create_timer(0.4).timeout
	_held_key(KEY_D,false)
	if main.world.walk_distance_phase!=phase or main.world.player.position.distance_to(position)>.001:
		await _fail("Blocked island movement changed phase/root");return
	main.world.blocked=false
	if not await _review_heading("front",[KEY_S]):return
	var audit={"result":"PASS_NATIVE_ISLAND_INPUT","time_scale":Engine.time_scale,"scope":"Real island key events, distance-driven gait, stopped hold, reversal and blocked/resumed input; appearance and open-ground placement are explicit fixtures. Pixel/root stability is independently checked by fixed-canvas native exports.","cases":captures}
	var file:=FileAccess.open(evidence_dir.path_join("audit.json"),FileAccess.WRITE);file.store_string(JSON.stringify(audit,"  "));file.close()
	print("PASS native island walk regression: ",captures.size()," headings/look cases at time scale ",Engine.time_scale)
	await main._quit_game()

func _review_heading(direction: String, keys: Array) -> bool:
	# Each case owns all four synthetic keys; drain releases before relocating its
	# fixture so a delayed native transition cannot contaminate the next heading.
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(code, false)
	await _frames(2)
	main.world.player.position = Vector3(0, 0.4, -6)
	main.world.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.2).timeout
	for code in keys: _held_key(int(code), true)
	var input_deadline := Time.get_ticks_msec() + 1000
	while not _heading_keys_match(keys) and Time.get_ticks_msec() < input_deadline:
		await get_tree().process_frame
	if not _heading_keys_match(keys):
		for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(code, false)
		await _fail("Native heading input was not acknowledged: %s vector=%s" % [direction, Input.get_vector("move_left", "move_right", "move_up", "move_down")])
		return false
	var start_position: Vector3 = main.world.player.position
	var start_phase: float = main.world.walk_distance_phase
	# Desktop inspection can generate focus-loss releases. Sustain the requested
	# hold with real key events at each physics tick, retaining the native input
	# path rather than modifying action state or moving the avatar directly.
	for _tick in range(roundi(24.0/Engine.time_scale)):
		for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(code, keys.has(code))
		await get_tree().physics_frame
		await get_tree().process_frame
	var end_position: Vector3 = main.world.player.position
	var displacement := Vector2(end_position.x - start_position.x, end_position.z - start_position.z)
	var expected_phase: float = fposmod(start_phase + displacement.length(), main.world.WALK_STRIDE_DISTANCE)
	var phase_error: float = absf(wrapf(main.world.walk_distance_phase - expected_phase, -main.world.WALK_STRIDE_DISTANCE * 0.5, main.world.WALK_STRIDE_DISTANCE * 0.5))
	if displacement.length() < 0.5 or main.world.facing != direction or not main.world.avatar_is_walking or phase_error > 0.015:
		var failed_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		for code in keys: _held_key(int(code), false)
		await _fail("Native heading/gait mismatch expected=%s actual=%s distance=%.3f phase_error=%.5f input_vector=%s position=%s/%s" % [direction, main.world.facing, displacement.length(), phase_error, failed_vector, start_position, end_position])
		return false
	if not _avatar_texture_synced():
		for code in keys: _held_key(int(code), false)
		await _fail("Walk Sprite3D and shader textures differ: " + direction)
		return false
	await RenderingServer.frame_post_draw
	if not _capture_walk(evidence_dir.path_join("%02d-%s.png" % [captures.size(),direction])):
		for code in keys: _held_key(int(code), false)
		await _fail("Walk screenshot failed: " + direction)
		return false
	for code in keys: _held_key(int(code), false)
	await get_tree().create_timer(0.15).timeout
	var stopped_phase: float = main.world.walk_distance_phase
	var stopped_position: Vector3 = main.world.player.position
	var stopped_texture: Texture2D = main.world.avatar.texture
	await _frames(5)
	if main.world.avatar_is_walking or main.world.facing != direction or main.world.last_avatar_action != "idle" or not is_equal_approx(main.world.walk_distance_phase, stopped_phase) or main.world.player.position.distance_to(stopped_position) > 0.01 or main.world.avatar.texture != stopped_texture or not _avatar_texture_synced():
		await _fail("Released native keys did not preserve stationary idle heading/gait/texture: " + direction)
		return false
	captures.append({"heading":direction,"hair":main.world.avatar_appearance.hair,"hat":main.world.avatar_equipped.hat,"distance":displacement.length(),"phase_error":phase_error})
	print("NATIVE WALK: ", direction, " distance=", displacement.length(), " phase_error=", phase_error)
	return true


func _capture_walk(path: String) -> bool:
	return get_viewport().get_texture().get_image().save_png(path)==OK
