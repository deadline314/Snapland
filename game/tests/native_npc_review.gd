extends "res://game/tests/native_layout_review.gd"

const NpcRoles := ["ticket", "imp", "announcer"]
var records: Dictionary = {}

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native NPC review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Native NPC review has no Progress autoload")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	var controller: Node = main.world.npc_activity
	if controller == null:
		await _fail("Native world has no authored NPC activity controller")
		return
	var stats: Dictionary = controller.statistics()
	if int(stats.get("registration_count", 0)) != 3 or not bool(stats.get("playing", false)):
		await _fail("Native NPC activity is not playing exactly three authored roles: " + str(stats))
		return
	for record: Dictionary in controller._records:
		if bool(record.get("active", false)): records[str(record.role)] = record
	for role in NpcRoles:
		if not records.has(role) or int(stats.get("by_role", {}).get(role, 0)) != 1:
			await _fail("Native authored NPC role is missing/duplicated: " + role)
			return
	# Freeze camera follow for clear, close views; animation playback remains live.
	# Fixture placement is not player-input walking evidence.
	main.world.set_physics_process(false)
	main.world.player.position = Vector3(15, 0.4, -24.5)
	main.world.set_time_of_day("noon")
	for role in NpcRoles:
		if not await _review_role(role): return
	main.world.apply_settings({"reduced_motion": true})
	var reduced_textures: Dictionary = {}
	var reduced_positions: Dictionary = {}
	for role in NpcRoles:
		var sprite := _sprite(role)
		var anchor := _anchor(role)
		reduced_textures[role] = sprite.texture
		reduced_positions[role] = anchor.position
	await get_tree().create_timer(0.4).timeout
	if bool(controller.statistics().get("playing", true)):
		await _fail("Reduced motion did not pause authored NPC playback")
		return
	for role in NpcRoles:
		var record: Dictionary = records[role]
		var material := _sprite(role).material_override as ShaderMaterial
		if _sprite(role).texture != reduced_textures[role] or _anchor(role).position != reduced_positions[role] or _sprite(role).texture != record.baseline_texture or material == null or material.get_shader_parameter("texture_albedo") != record.baseline_shader_texture or material.get_shader_parameter("uv_rect") != record.baseline_shader_uv_rect:
			await _fail("Reduced motion did not retain stable synchronized NPC pose/root: " + role)
			return
	main.world.apply_settings({"reduced_motion": false})
	await _frames(3)
	if not bool(controller.statistics().get("playing", false)):
		await _fail("NPC activity did not resume after reduced-motion fixture")
		return
	print("PASS: native ticket service/imp dance/announcer walk frames, shader texture synchronization, bounded announcer travel, labels and interaction-point follow, reduced motion. Framed camera/hero positions are review fixtures.")
	await main._quit_game()

func _sprite(role: String) -> Sprite3D:
	return records[role].target.get_ref() as Sprite3D

func _anchor(role: String) -> Node3D:
	return records[role].anchor.get_ref() as Node3D

func _texture_synced(sprite: Sprite3D) -> bool:
	var material := sprite.material_override as ShaderMaterial
	return sprite.texture != null and material != null and material.get_shader_parameter("texture_albedo") == sprite.texture and material.get_shader_parameter("uv_rect") == Vector4(0, 0, 1, 1)

func _review_role(role: String) -> bool:
	var sprite := _sprite(role)
	var anchor := _anchor(role)
	var record: Dictionary = records[role]
	var point: Dictionary = record.point
	var expected_point_id: String = {"ticket": "guide", "imp": "quest-001", "announcer": "quest-002"}[role]
	var expected_base: Vector3 = {"ticket": Vector3(-5, 0, 10), "imp": Vector3(-3.4, 0, -19.5), "announcer": Vector3(3.4, 0, -19.5)}[role]
	var label: Label3D = null
	for child in anchor.get_children():
		if child is Label3D: label = child
	if label == null or label.text != {"ticket": "票票", "imp": "小角", "announcer": "阿浪"}[role] or str(point.get("id", "")) != expected_point_id or Vector3(record.baseline_anchor_position).distance_to(expected_base) > 0.01:
		await _fail("NPC label/root/interaction identity mismatch: %s point=%s root=%s" % [role, point, record.baseline_anchor_position])
		return false
	main.world.camera.size = 5.0
	main.world.camera.position = expected_base + Vector3(0, 3.8, 6.5)
	main.world.camera.look_at(expected_base + Vector3(0, 1.45, 0))
	main.world.camera.current = true
	var seen: Dictionary = {}
	var first_saved := false
	var second_saved := false
	var smallest_x := INF
	var largest_x := -INF
	for sample in range(70):
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		if not _texture_synced(sprite) or not record.frames.has(sprite.texture):
			await _fail("Native authored NPC sprite/shader/source-frame mismatch: " + role)
			return false
		seen[sprite.texture.get_instance_id()] = true
		smallest_x = minf(smallest_x, anchor.position.x)
		largest_x = maxf(largest_x, anchor.position.x)
		var offset: Vector3 = anchor.position - expected_base
		var point_error: float = Vector3(point.position).distance_to(anchor.global_position + Vector3(record.point_offset))
		if absf(offset.x) > (0.601 if role == "announcer" else 0.001) or absf(offset.y) > 0.001 or absf(offset.z) > 0.001 or point_error > 0.035:
			await _fail("NPC root travel/interaction point exceeded bounds: %s offset=%s point_error=%.4f" % [role, offset, point_error])
			return false
		if not await _check_npc_visible(sprite, label, role): return false
		if not first_saved:
			if not main._capture("pm/Snapland-art/images/ART-12-%s-01.png" % role):
				await _fail("NPC first native capture failed: " + role)
				return false
			first_saved = true
		elif not second_saved and seen.size() > 1:
			if not main._capture("pm/Snapland-art/images/ART-12-%s-02.png" % role):
				await _fail("NPC second authored-pose capture failed: " + role)
				return false
			second_saved = true
	if seen.size() != 4 or not first_saved or not second_saved or (role == "announcer" and largest_x - smallest_x < 1.1):
		await _fail("NPC live playback did not demonstrate four frames/full bounded walk: %s frames=%d x_range=%.3f" % [role, seen.size(), largest_x - smallest_x])
		return false
	print("NATIVE NPC: ", role, " frames=", seen.size(), " x_range=", largest_x - smallest_x, " point=", point.id)
	return true

func _check_npc_visible(sprite: Sprite3D, label: Label3D, role: String) -> bool:
	var view: Rect2 = main.get_viewport().get_visible_rect()
	for target in [sprite, label]:
		var point: Vector3 = target.global_position
		if not target.is_visible_in_tree() or main.world.camera.is_position_behind(point) or not view.has_point(main.world.camera.unproject_position(point)):
			await _fail("NPC body/name is not visible in the native framed view: " + role)
			return false
		var query := PhysicsRayQueryParameters3D.create(main.world.camera.global_position, point, 1, [main.world.player.get_rid()])
		var hit: Dictionary = main.world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			await _fail("NPC body/name is blocked by park geometry: %s hit=%s" % [role, hit])
			return false
	return true
