extends Node

const ParkWorldScript = preload("res://game/world/park_world.gd")
const OUTPUT_DIR := "res://pm/Snapland-art/images"

var park_world: Node3D
var last_capture_size := Vector2i.ZERO


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native atmosphere review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1280, 720)
	park_world = ParkWorldScript.new()
	park_world.name = "AtmosphereReviewPark"
	get_tree().root.add_child(park_world)
	park_world.camera.size = 11.0
	await get_tree().create_timer(0.8).timeout
	var motion_stats: Dictionary = park_world.component_motion.statistics()
	if not bool(motion_stats.get("playing", false)) or int(motion_stats.get("registration_count", 0)) < 100:
		await _fail("Component animation tracks are not running: " + str(motion_stats))
		return
	print("ATMOSPHERE MOTION: ", motion_stats)

	# Keep the world camera physics follow paused while inspecting the two
	# avenue NPCs. The camera sits behind them, so the gate is behind the actors.
	park_world.set_physics_process(false)
	_set_player(Vector3(15.0, 0.4, -15.0))
	park_world.set_night(false)
	park_world.apply_settings({"reduced_motion": false})
	_frame_camera(Vector3(0, 1.2, -15), Vector3(0, 5.0, -20), 8.5)
	await get_tree().create_timer(1.0).timeout
	if not await _capture("ART-9-npc-idle-01.png"):
		return
	await get_tree().create_timer(2.4).timeout
	if not await _capture("ART-9-npc-idle-02.png"):
		return
	var imp_sprite: Sprite3D = _find_character_sprite("imp")
	_set_player(Vector3(15.0, 0.4, -15.0))
	_frame_camera(imp_sprite.global_position + Vector3(0, 0.1, 0), imp_sprite.global_position + Vector3(0, 0.25, -4.2), 4.5)
	await get_tree().create_timer(1.4).timeout
	if not await _capture("ART-9-npc-imp-close.png"):
		return
	var announcer_sprite: Sprite3D = _find_character_sprite("announcer")
	_set_player(Vector3(15.0, 0.4, -15.0))
	_frame_camera(announcer_sprite.global_position + Vector3(0, 0.1, 0), announcer_sprite.global_position + Vector3(0, 0.25, -4.2), 4.5)
	await get_tree().create_timer(1.4).timeout
	if not await _capture("ART-9-npc-announcer-close.png"):
		return
	var ticket_sprite: Sprite3D = _find_character_sprite("ticket")
	_set_player(Vector3(15.0, 0.4, -15.0))
	_frame_camera(ticket_sprite.global_position + Vector3(0, 0.1, 0), ticket_sprite.global_position + Vector3(0, 0.25, 4.2), 4.5)
	await get_tree().create_timer(1.4).timeout
	if not await _capture("ART-9-npc-ticket-close.png"):
		return
	park_world.set_physics_process(true)
	park_world.camera.size = 11.0
	_restore_follow_camera()

	# Capture the animated flowerbed and the dock flags as separate views so their
	# small frame-to-frame changes remain easy to inspect.
	_set_player(Vector3(7.6, 0.4, -14.0))
	await get_tree().create_timer(0.8).timeout
	if not await _capture("ART-9-foliage-01.png"):
		return
	await get_tree().create_timer(1.6).timeout
	if not await _capture("ART-9-foliage-02.png"):
		return

	_set_player(Vector3(0.0, 0.4, 11.0))
	await get_tree().create_timer(0.8).timeout
	if not await _capture("ART-9-flag-01.png"):
		return
	await get_tree().create_timer(1.6).timeout
	if not await _capture("ART-9-flag-02.png"):
		return

	# Start with the requested kiosk fixture; use a small bounded grid only if its
	# body-center ray misses the actual kiosk geometry at this camera elevation.
	var occlusion_position := await _find_kiosk_occlusion(Vector3(-6.0, 0.4, 2.0))
	if occlusion_position == Vector3.INF:
		await _fail("No actual eligible kiosk obstruction found in the bounded fixture search")
		return
	print("OCCLUSION FIXTURE: player=", occlusion_position, " stats=", park_world.occlusion_controller.statistics())
	if not await _capture("ART-10-cutaway-day.png"):
		return
	var kiosk_position_right := await _find_kiosk_occlusion(Vector3(6.0, 0.4, 2.0))
	if kiosk_position_right == Vector3.INF:
		await _fail("No actual eligible right kiosk obstruction found")
		return
	print("RIGHT KIOSK FIXTURE: player=", kiosk_position_right, " stats=", park_world.occlusion_controller.statistics())
	if not await _capture("ART-10-cutaway-right-kiosk.png"):
		return
	occlusion_position = await _find_arch_occlusion()
	if occlusion_position == Vector3.INF:
		await _fail("The center welcome arch did not trigger a local cutaway")
		return
	park_world.set_night(false)
	if not await _capture("ART-10-arch-cutaway-day.png"):
		return
	var arch_hits: Dictionary = park_world.occlusion_controller._active_group_ids.duplicate()
	if arch_hits.is_empty() or not _has_active_cutaway():
		await _fail("Arch cutaway is not active around the player")
		return
	# Check resize projection and refreshed avatar equipment while the arch aid is active.
	var original_window_size := get_window().size
	var original_capture_size := last_capture_size
	var resized_window_size := Vector2i(1600, 900)
	get_window().size = resized_window_size
	await get_tree().create_timer(0.3).timeout
	var resized_stats: Dictionary = park_world.occlusion_controller.statistics()
	if get_window().size != resized_window_size:
		await _fail("Native window did not accept the requested resize: " + str(get_window().size))
		return
	var stats_viewport: Vector2 = resized_stats.get("viewport_size", Vector2.ZERO)
	var visible_viewport := Vector2(get_viewport().get_visible_rect().size)
	var body_point: Vector3 = park_world.player.global_position + Vector3.UP
	var expected_center: Vector2 = park_world.camera.unproject_position(body_point)
	var reported_center: Vector2 = resized_stats.get("center_px", Vector2.ZERO)
	var normalized_center_error: float = (reported_center / stats_viewport - expected_center / visible_viewport).length() if stats_viewport.x > 0.0 and visible_viewport.x > 0.0 else INF
	var projected_body_height: float = park_world.camera.unproject_position(park_world.player.global_position).distance_to(park_world.camera.unproject_position(park_world.player.global_position + Vector3.UP * 1.9))
	var expected_radius: float = clampf(projected_body_height * 0.48, 24.0, 84.0)
	if not _has_active_cutaway() or normalized_center_error > 0.005 or absf(float(resized_stats.get("radius_px", 0.0)) - expected_radius) > 0.5:
		await _fail("Resized arch projection no longer matches the player's normalized center/body height: " + str(resized_stats) + " center_error=" + str(normalized_center_error) + " expected_radius=" + str(expected_radius))
		return
	var equipped: Dictionary = park_world.avatar_equipped.duplicate(true)
	equipped["outfit"] = "outfit-coral"
	equipped["hat"] = "hat-straw"
	park_world.set_avatar_look(park_world.avatar_appearance.duplicate(true), equipped)
	var avatar_material := park_world.avatar.material_override as ShaderMaterial
	if avatar_material == null or avatar_material.get_shader_parameter("texture_albedo") != park_world.avatar.texture:
		await _fail("Equipping the avatar did not refresh the living-sprite texture")
		return
	if not await _capture("ART-10-arch-cutaway-resized-equipped.png"):
		return
	# Compare completed readbacks. A live texture's reported size can refer to a
	# different backing allocation during a native window/DPI transition.
	if last_capture_size.x <= original_capture_size.x or last_capture_size.y <= original_capture_size.y:
		await _fail("Resized review image did not grow in both pixel dimensions: original=" + str(original_capture_size) + " resized=" + str(last_capture_size))
		return
	get_window().size = original_window_size
	await get_tree().create_timer(0.25).timeout
	var arch_entry_z: float = park_world.player.position.z
	var move_through_arch := InputEventKey.new()
	move_through_arch.keycode = KEY_S
	move_through_arch.physical_keycode = KEY_S
	move_through_arch.pressed = true
	Input.parse_input_event(move_through_arch)
	await get_tree().create_timer(1.35).timeout
	move_through_arch.pressed = false
	Input.parse_input_event(move_through_arch)
	await get_tree().create_timer(0.25).timeout
	if park_world.player.position.z < arch_entry_z + 1.0:
		await _fail("Mapped S movement did not carry the player through the arch")
		return
	if _has_active_cutaway():
		await _fail("Arch cutaway remained active after mapped S movement: " + str(park_world.occlusion_controller.statistics()))
		return
	if not await _capture("ART-10-arch-cutaway-clear.png"):
		return
	# Return to the left kiosk fixture for the day/night/reduced-motion pair below.
	occlusion_position = await _find_kiosk_occlusion(Vector3(-6.0, 0.4, 2.0))
	if occlusion_position == Vector3.INF:
		await _fail("Left kiosk obstruction could not be restored after arch checks")
		return

	park_world.set_night(true)
	await get_tree().create_timer(0.35).timeout
	if not _has_active_cutaway():
		await _fail("Night transition lost the active kiosk cutaway")
		return
	if not await _capture("ART-10-cutaway-night.png"):
		return

	park_world.apply_settings({"reduced_motion": true})
	await get_tree().create_timer(0.2).timeout
	var reduced_stats: Dictionary = park_world.occlusion_controller.statistics()
	if not bool(reduced_stats.get("active", false)) or not is_equal_approx(float(reduced_stats.get("fade_weight", 0.0)), 1.0):
		await _fail("Reduced motion must retain the active cutaway immediately: " + str(reduced_stats))
		return
	if not await _capture("ART-10-cutaway-reduced-motion.png"):
		return

	park_world.apply_settings({"reduced_motion": false})
	_set_player(Vector3(occlusion_position.x, 0.4, 8.0))
	await get_tree().create_timer(0.9).timeout
	if _has_active_cutaway():
		await _fail("Kiosk in front of the player incorrectly kept the cutaway active: " + str(park_world.occlusion_controller.statistics()))
		return
	if not await _capture("ART-10-cutaway-clear.png"):
		return

	print("PASS: native atmosphere and obstruction review. Deterministic fixture positions and framed camera views are review setup, not a player-input playthrough.")
	park_world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _find_kiosk_occlusion(start: Vector3) -> Vector3:
	var candidates: Array[Vector3] = [start]
	for z_value in [2.7, 3.1, 1.2, 0.4]:
		for x_offset in [0.0, -0.45, 0.45]:
			var candidate := Vector3(start.x + x_offset, 0.4, z_value)
			if not candidates.has(candidate):
				candidates.append(candidate)
	for index in candidates.size():
		var candidate: Vector3 = candidates[index]
		_set_player(candidate)
		await get_tree().create_timer(0.9 if index == 0 else 0.35).timeout
		await get_tree().physics_frame
		park_world.occlusion_controller.refresh_visibility()
		if _has_active_cutaway():
			return park_world.player.position
	return Vector3.INF


func _set_player(position: Vector3) -> void:
	park_world.player.velocity = Vector3.ZERO
	park_world.player.position = position
	park_world.camera.position = position + Vector3(0, 15.5, 25)
	park_world.camera.look_at(position + Vector3(0, 1, -3))
	park_world.camera.current = true


func _restore_follow_camera() -> void:
	park_world.camera.position = park_world.player.position + Vector3(0, 15.5, 25)
	park_world.camera.look_at(park_world.player.position + Vector3(0, 1, -3))
	park_world.camera.current = true


func _find_character_sprite(role: String) -> Sprite3D:
	for character: Dictionary in park_world.character_sprites:
		if str(character.get("role", "")) == role:
			return character.get("sprite") as Sprite3D
	push_error("Atmosphere review cannot find NPC role: " + role)
	return null


func _frame_camera(target: Vector3, camera_position: Vector3, camera_size: float) -> void:
	park_world.camera.position = camera_position
	park_world.camera.size = camera_size
	park_world.camera.look_at(target)
	park_world.camera.current = true


func _find_arch_occlusion() -> Vector3:
	var candidates: Array[Vector3] = [Vector3(0, 0.4, -15.0), Vector3(0, 0.4, -14.0), Vector3(0, 0.4, -16.0)]
	var arch_group_id := 0
	for node in park_world.find_children("*", "StaticBody3D", true, false):
		if (int(node.collision_layer) & 1) != 0 and node.global_position.distance_to(Vector3(-4.0, 1.65, -11.0)) < 0.1:
			arch_group_id = int(park_world.occlusion_controller._collider_to_group.get(node.get_instance_id(), 0))
			break
	for index in candidates.size():
		var candidate: Vector3 = candidates[index]
		_set_player(candidate)
		await get_tree().create_timer(0.75 if index == 0 else 0.35).timeout
		await get_tree().physics_frame
		park_world.occlusion_controller.refresh_visibility()
		if arch_group_id != 0 and park_world.occlusion_controller._active_group_ids.has(arch_group_id) and _has_active_cutaway():
			return park_world.player.position
	return Vector3.INF


func _has_active_cutaway() -> bool:
	var stats: Dictionary = park_world.occlusion_controller.statistics()
	return bool(stats.get("active", false)) and int(stats.get("active_groups", 0)) > 0 and float(stats.get("radius_px", 0.0)) >= 20.0


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		await _fail("Cannot create atmosphere image directory: " + path.get_base_dir())
		return false
	var capture_image := get_viewport().get_texture().get_image()
	if capture_image == null or capture_image.is_empty():
		await _fail("Atmosphere frame readback is empty: " + path)
		return false
	last_capture_size = capture_image.get_size()
	var minimum_size := Vector2i(get_viewport().get_visible_rect().size)
	if last_capture_size.x < minimum_size.x or last_capture_size.y < minimum_size.y or last_capture_size.x * 9 != last_capture_size.y * 16:
		await _fail("Atmosphere frame must cover the logical viewport with 16:9 pixels: image=" + str(last_capture_size) + " minimum=" + str(minimum_size))
		return false
	# PNG stores these exact RGBA8 source pixels. Validate the persisted frame
	# against this readback, rather than querying a mutable texture again.
	capture_image.convert(Image.FORMAT_RGBA8)
	var error := capture_image.save_png(path)
	if error != OK:
		await _fail("Cannot save atmosphere evidence: " + path + " error=" + str(error))
		return false
	var saved_image := Image.new()
	var load_error := saved_image.load(path)
	if load_error != OK or saved_image.get_size() != last_capture_size:
		await _fail("Persisted atmosphere PNG does not match the source frame dimensions: " + path + " error=" + str(load_error) + " source=" + str(last_capture_size) + " saved=" + str(saved_image.get_size()))
		return false
	saved_image.convert(Image.FORMAT_RGBA8)
	if saved_image.get_data() != capture_image.get_data():
		await _fail("Persisted atmosphere PNG pixels differ from the source frame: " + path)
		return false
	print("CAPTURED: ", path, " pixels=", last_capture_size)
	return true


func _fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(park_world):
		park_world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1)
