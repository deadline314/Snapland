extends "res://game/tests/native_walk_review.gd"
## Real island input; relocation/appearance/camera are explicit test fixtures.
var evidence_dir := ""
var checks: Dictionary = {}
var motion_cases: Array = []
var source_inset: TextureRect
var selected_look: Dictionary = WalkRenderer.DEFAULT_APPEARANCE.duplicate()

func _run() -> void:
	evidence_dir = OS.get_environment("SNAPLAND_ISLAND_HAIR_DIR")
	if not evidence_dir.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name() == "headless":
		await _fail("Island hair acceptance requires native rendering and isolated paths")
		return
	Engine.time_scale = 0.25 if OS.get_environment("SNAPLAND_ISLAND_HAIR_QUARTER") == "1" else 1.0
	selected_look.hair = OS.get_environment("SNAPLAND_ISLAND_HAIR_STYLE") if not OS.get_environment("SNAPLAND_ISLAND_HAIR_STYLE").is_empty() else "windswept"
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	get_tree().root.add_child(main)
	# Cloud software rendering: reduce only environment raster cost. The actor's
	# 280x360 source viewport, original billboard, lights and occlusion remain.
	if OS.get_environment("SNAPLAND_ISLAND_HAIR_SOFTWARE") == "1":
		get_viewport().scaling_3d_scale = 0.25
		main.world.environment.ssao_enabled = false
		main.world.environment.glow_enabled = false
		main.world.sun.shadow_enabled = false
		main.hud.hide()
		var layer := CanvasLayer.new()
		add_child(layer)
		var background := ColorRect.new()
		background.position = Vector2(940, 150)
		background.size = Vector2(300, 380)
		background.color = Color("#344557")
		layer.add_child(background)
		source_inset = TextureRect.new()
		source_inset.position = Vector2(950, 160)
		source_inset.size = Vector2(280, 360)
		source_inset.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(source_inset)
	await _frames(4)
	main.world.set_avatar_look(selected_look, {"outfit": "outfit-tide", "hat": "hat-none"})
	main.world.camera.size = 6.5
	if OS.get_cmdline_user_args().has("--hair-reverse-only"):
		await _reverse_and_live_swap()
		return
	for fixture in [["front", [KEY_S]], ["front_right", [KEY_S, KEY_D]], ["right", [KEY_D]], ["back_right", [KEY_W, KEY_D]], ["back", [KEY_W]], ["back_left", [KEY_W, KEY_A]], ["left", [KEY_A]], ["front_left", [KEY_S, KEY_A]]]:
		if not await _walk(str(fixture[0]), fixture[1]): return
	checks.eight_headings = motion_cases.size() == 8
	for hat in ["hat-straw", "hat-sailor", "hat-flower", "hat-none"]:
		main.world.set_avatar_look(selected_look, {"outfit": "outfit-coral", "hat": hat})
		if not await _walk("right", [KEY_D]): return
	checks.all_hat_states = true
	# Pause while there is still actual rebound, through the real Escape route.
	await _tap(KEY_ESCAPE)
	if not main.world.blocked: await _fail("Escape did not pause island"); return
	var before: Dictionary = main.world.avatar_hair_rig.receipt()
	var clock: float = main.world.time
	await _frames(5)
	checks.pause_freezes_bones = main.world.avatar_hair_rig.receipt() == before and main.world.time == clock
	if not checks.pause_freezes_bones: await _fail("pause changed hair/root/pose clock"); return
	await _capture("paused")
	var camera_transform: Transform3D = main.world.camera.transform
	var camera_size: float = main.world.camera.size
	var paused_pixels: PackedByteArray = main.world.avatar.texture.get_image().get_data()
	main.world.camera.size = 10.0
	main.world.camera.position += Vector3(1.0, 1.0, 0.0)
	await _capture("paused-camera-change")
	checks.camera_keeps_actor_pixels = main.world.avatar.texture.get_image().get_data() == paused_pixels and main.world.avatar_hair_rig.receipt() == before
	if not checks.camera_keeps_actor_pixels: await _fail("camera changed paused actor pixels or bones"); return
	main.world.camera.transform = camera_transform
	main.world.camera.size = camera_size
	await _tap(KEY_ESCAPE)
	if main.world.blocked: await _fail("Escape did not resume island"); return
	await _tap(KEY_P)
	checks.photo_original = main.world.avatar_action == "photograph" and not main.world.avatar_hair_rig.active
	if not checks.photo_original: await _fail("photo must preserve complete hand/camera pose"); return
	await _capture("photograph")
	# Movement must interrupt photo and re-enter the same authored gait.
	if not await _walk("left", [KEY_A]): return
	checks.photo_interruption = main.world.avatar_action == ""
	main.world.apply_settings({"reduced_motion": true})
	checks.reduced_motion_original = not main.world.avatar_hair_rig.active
	if not checks.reduced_motion_original: await _fail("reduced motion did not restore original"); return
	await _capture("reduced-motion-original")
	main.world.apply_settings({"reduced_motion": false})
	if not await _walk("right", [KEY_D]): return
	checks.reduced_motion_resume = main.world.avatar_hair_rig.active
	for style in ["windswept", "bob", "curly"]:
		var look: Dictionary = WalkRenderer.DEFAULT_APPEARANCE.duplicate()
		look.hair = style
		main.world.set_avatar_look(look, {"outfit": "outfit-tide", "hat": "hat-none"})
		if not main.world.avatar_hair_rig.active: await _fail("covered hairstyle must bind its own profile"); return
		await _capture(style + "-bound")
	checks.live_style_swap = true
	main.world.set_avatar_look(selected_look, {"outfit": "outfit-tide", "hat": "hat-none"})
	await get_tree().create_timer(1.6).timeout
	checks.settled = main.world.avatar_hair_rig.spring.angles.length() < 0.0001
	checks.real_bones = main.world.avatar_hair_rig.skeleton.get_bone_count() == 4
	checks.original_shader_and_grounding = _avatar_texture_synced() and main.world.avatar.material_override.shader == main.world.LIVING_SPRITE
	checks.sprite_visible = main.world.avatar.visible
	for label in checks:
		if not checks[label]: await _fail("island hair check failed: " + label); return
	await _capture("settled")
	var file := FileAccess.open(evidence_dir.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"result": "PASS_NATIVE_ISLAND_HAIR_BINDING", "style": selected_look.hair, "time_scale": Engine.time_scale, "engine": Engine.get_version_info(), "renderer": RenderingServer.get_video_adapter_name(), "software_environment_fixture": OS.get_environment("SNAPLAND_ISLAND_HAIR_SOFTWARE") == "1", "checks": checks, "movement_cases": motion_cases, "scope": "Actual island native key events; relocation, camera and appearance are explicit fixtures. Software mode reduces environment rendering; no human playtest, full lighting-quality or realtime performance claim."}, "  "))
	file.close()
	print("PASS: native island hair binding normal/quarter ", Engine.time_scale, " cases ", motion_cases.size())
	await main._quit_game()

func _process(_delta: float) -> void:
	if source_inset != null and main != null and is_instance_valid(main.world.avatar):
		source_inset.texture = main.world.avatar.texture

func _reverse_and_live_swap() -> void:
	main.world.player.position = Vector3(-4, 0.4, -6)
	main.world.player.velocity = Vector3.ZERO
	await _frames(2)
	await _hold_for([KEY_D], 0.4)
	var deadline: float = main.world.time + 1.0
	while main.world.last_avatar_frame < 2 and main.world.time < deadline: await get_tree().physics_frame
	var frame: int = main.world.last_avatar_frame
	var phase: float = main.world.walk_distance_phase
	main.world.set_avatar_look(selected_look, {"outfit": "outfit-coral", "hat": "hat-sailor"})
	checks.live_swap_keeps_step = frame >= 2 and main.world.last_avatar_frame == frame and main.world.walk_distance_phase == phase
	for style in ["windswept", "bob", "curly"]:
		var look := selected_look.duplicate()
		look.hair = style
		main.world.set_avatar_look(look, {"outfit":"outfit-coral", "hat":"hat-sailor"})
		checks["live_"+style+"_keeps_step"] = main.world.last_avatar_frame == frame and main.world.walk_distance_phase == phase and main.world.avatar_hair_rig.active and main.world.avatar_hair_rig.receipt().style == style
	main.world.set_avatar_look(selected_look, {"outfit": "outfit-coral", "hat": "hat-sailor"})
	main.world.set_avatar_hair_motion_enabled(false)
	checks.live_motion_off_keeps_step = main.world.last_avatar_frame == frame and main.world.walk_distance_phase == phase and not main.world.avatar_hair_rig.active
	main.world.set_avatar_hair_motion_enabled(true)
	checks.live_motion_on_keeps_step = main.world.last_avatar_frame == frame and main.world.walk_distance_phase == phase and main.world.avatar_hair_rig.active
	main.world.apply_settings({"reduced_motion": true})
	checks.live_reduced_keeps_step = main.world.last_avatar_frame == frame and main.world.walk_distance_phase == phase and not main.world.avatar_hair_rig.active
	main.world.apply_settings({"reduced_motion": false})
	checks.live_restore_keeps_step = main.world.last_avatar_frame == frame and main.world.walk_distance_phase == phase and main.world.avatar_hair_rig.active
	await _capture("live-swap")
	var start: Vector3 = main.world.player.global_position
	# Switch held keys directly; there is no relocation or velocity reset here.
	await _hold_for([KEY_A], 0.65)
	checks.continuous_reverse = main.world.facing == "left" and main.world.player.global_position.x < start.x - 0.1 and main.world.avatar_hair_rig.active
	checks.reverse_root_fixed = main.world.avatar_hair_rig.root_bone.transform == Transform2D.IDENTITY
	await _capture("continuous-reverse")
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(key, false)
	await get_tree().create_timer(1.6).timeout
	checks.reverse_settles = main.world.avatar_hair_rig.spring.angles.length() < 0.0001
	for label in checks:
		if not checks[label]: await _fail("live reverse/swap check failed: " + label); return
	var file := FileAccess.open(evidence_dir.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"result": "PASS_NATIVE_ISLAND_HAIR_BINDING", "mode": "continuous reverse and live pose swap", "style": selected_look.hair, "time_scale": Engine.time_scale, "engine": Engine.get_version_info(), "checks": checks, "held_cel": frame, "held_phase": phase, "software_environment_fixture": OS.get_environment("SNAPLAND_ISLAND_HAIR_SOFTWARE") == "1"}, "  "))
	file.close()
	print("PASS: native island continuous reverse and live swap at ", Engine.time_scale, " held cel ", frame)
	await main._quit_game()

func _hold_for(keys: Array, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		for key in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(key, keys.has(key))
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()

func _walk(view: String, keys: Array) -> bool:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(key, false)
	await _frames(1)
	main.world.player.position = Vector3(-4, 0.4, -6)
	main.world.player.velocity = Vector3.ZERO
	await _frames(2)
	var start: Vector3 = main.world.player.global_position
	var observed_motion := 0.0
	var seconds := 0.0
	while seconds < 0.40:
		for key in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(key, keys.has(key))
		await get_tree().physics_frame
		seconds += get_physics_process_delta_time()
		observed_motion = maxf(observed_motion, main.world.avatar_hair_rig.spring.angles.length())
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(key, false)
	var distance: float = (main.world.player.global_position - start).length()
	if main.world.facing != view or distance < 0.1 or not main.world.avatar_hair_rig.active or observed_motion < 0.0001:
		await _fail("native movement/hair failed: %s facing=%s distance=%f motion=%f reason=%s" % [view, main.world.facing, distance, observed_motion, main.world.avatar_hair_rig.fallback_reason])
		return false
	if main.world.avatar_hair_rig.root_bone.transform != Transform2D.IDENTITY: await _fail("native root drift"); return false
	await _capture("%02d-%s-walk" % [motion_cases.size(), view])
	await get_tree().create_timer(0.18).timeout
	if main.world.avatar_is_walking: await _fail("native release did not stop walking"); return false
	await _capture("%02d-%s-stop" % [motion_cases.size(), view])
	motion_cases.append({"style": main.world.avatar_appearance.hair, "heading": view, "hat": main.world.avatar_equipped.hat, "distance": distance, "max_angle": observed_motion})
	return true

func _tap(key: int) -> void:
	_held_key(key, true)
	await _frames(1)
	_held_key(key, false)
	await _frames(2)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(evidence_dir.path_join(label + ".png"))
	main.world.avatar.texture.get_image().save_png(evidence_dir.path_join(label + "-pixels.png"))
