extends SceneTree

const ParkWorldScript := preload("res://game/world/park_world.gd")

var _world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	_world = ParkWorldScript.new()
	root.add_child(_world)
	await process_frame
	assert(_world.npc_activity.statistics().registration_count == 3, "the world registers each named NPC once")
	assert(_world.npc_activity.statistics().by_role.get("ticket", 0) == 1, "ticket is associated with its guide point")
	assert(_world.npc_activity.statistics().by_role.get("imp", 0) == 1, "imp is associated with quest-001")
	assert(_world.npc_activity.statistics().by_role.get("announcer", 0) == 1, "announcer is associated with quest-002")
	assert(_world.avatar != null and _world.avatar.texture != null, "NPC controller integration leaves the player avatar available")
	var points := {
		"ticket": _world._point_by_id("guide"),
		"imp": _world._point_by_id("quest-001"),
		"announcer": _world._point_by_id("quest-002"),
	}
	for actor_record in _world.character_sprites:
		var role := String(actor_record.role)
		var sprite := actor_record.sprite as Sprite3D
		var material := sprite.material_override as ShaderMaterial
		assert(sprite.texture == material.get_shader_parameter("texture_albedo"), "%s Sprite3D and shader uniforms use the same authored frame" % role)
		assert(material.get_shader_parameter("uv_rect") == Vector4(0.0, 0.0, 1.0, 1.0), "%s normalized action frame uses full-canvas UVs" % role)
		assert(is_equal_approx(sprite.pixel_size, 2.4 / 420.0), "%s uses the 420 visible-pixel actor scale" % role)
		assert(absf(float(points[role].position.x) - float(actor_record.activity_root.global_position.x)) < 0.001, "%s interaction point starts on its actor root" % role)
	var announcer: Dictionary = _actor_record_for_role("announcer")
	var announcer_root := announcer.activity_root as Node3D
	var baseline_root_position: Vector3 = announcer_root.position
	var start_point: Vector3 = points["announcer"].position
	_world.npc_activity._player.seek(0.0, true)
	_world.npc_activity._player.advance(1.2)
	_world.npc_activity._process(0.0)
	assert(is_equal_approx(announcer_root.position.x, baseline_root_position.x + 0.6), "announcer side-step stays on its open route bound")
	assert(is_equal_approx(float(points["announcer"].position.x), start_point.x + 0.6), "the world interaction point follows the announcer root")
	var announcer_sprite := announcer.sprite as Sprite3D
	var baseline_texture: Texture2D = _activity_record_for_role("announcer").baseline_texture
	_world.apply_settings({"reduced_motion": true})
	assert(_world.npc_activity.statistics().reduced_motion, "world settings propagate reduced motion to NPC activity")
	assert(announcer_root.position == baseline_root_position and points["announcer"].position == start_point, "reduced motion restores NPC root and world point")
	assert(announcer_sprite.texture == baseline_texture, "reduced motion restores the original visible idle frame")
	_world.blocked = true
	_world._process(0.0)
	assert(_world.npc_activity.statistics().activity_paused, "blocked/modal world state pauses the NPC controller")
	_world.blocked = false
	_world._process(0.0)
	assert(not _world.npc_activity.statistics().activity_paused, "unblocking resumes the NPC controller")
	_world.apply_settings({"reduced_motion": false})
	assert(not _world.npc_activity.statistics().reduced_motion, "world settings restore NPC motion")
	assert(announcer_sprite.texture == _world.npc_activity._records[2].frames[0], "resumed announcer displays its authored idle frame")
	_world.queue_free()
	await process_frame
	print("PASS: NPC world activity integration")
	quit(0)


func _actor_record_for_role(role: String) -> Dictionary:
	for actor_record in _world.character_sprites:
		if String(actor_record.role) == role:
			return actor_record
	return {}


func _activity_record_for_role(role: String) -> Dictionary:
	for activity_record in _world.npc_activity._records:
		if String(activity_record.role) == role:
			return activity_record
	return {}
