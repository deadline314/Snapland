extends SceneTree

const ParkWorldScript := preload("res://game/world/park_world.gd")
const NpcActivityScript := preload("res://game/world/npc_activity.gd")

var _world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or save_path.contains("://") or not save_path.is_absolute_path():
		push_error("SNAPLAND_SAVE_PATH must be an isolated absolute OS filesystem path.")
		quit(1)
		return
	await _check_invalid_motion_configuration()
	_world = ParkWorldScript.new()
	root.add_child(_world)
	await process_frame
	# Sample route, action and interaction point at the same authored time;
	# AnimationPlayer may have advanced before this deferred coroutine resumed.
	_world.npc_activity._player.seek(0.0, true)
	_world.npc_activity._action_clock = 0.0
	_world.npc_activity._process(0.0)
	assert(_world.npc_activity.statistics().registration_count == 3, "the world registers each named NPC once")
	assert(_world.npc_activity.statistics().by_role.get("ticket", 0) == 1, "ticket is associated with its guide point")
	assert(_world.npc_activity.statistics().by_role.get("imp", 0) == 1, "imp is associated with quest-001")
	assert(_world.npc_activity.statistics().by_role.get("announcer", 0) == 1, "announcer is associated with quest-002")
	assert(_world.avatar != null and _world.avatar.texture != null, "NPC controller integration leaves the player avatar available")
	var motion_status: Dictionary = _world.npc_activity.motion_report()
	assert(not bool(motion_status.enabled) and motion_status.supported_roles.is_empty(), "production world never enables or counts the rejected procedural gait")
	assert(motion_status.sprite_fallback_roles.size() == 3, "all three production NPCs retain their complete authored Sprite")
	assert(_world.find_children("NpcMeasuredMotion_*", "", true, false).is_empty(), "production scene allocates no hidden measured gait adapters")
	var points := {
		"ticket": _world._point_by_id("guide"),
		"imp": _world._point_by_id("quest-001"),
		"announcer": _world._point_by_id("quest-002"),
	}
	for actor_record in _world.character_sprites:
		var role := String(actor_record.role)
		var sprite := actor_record.sprite as Sprite3D
		var material := sprite.material_override as ShaderMaterial
		var activity_record := _activity_record_for_role(role)
		var motion: Variant = activity_record.get("motion")
		assert(motion == null and sprite.visible, "%s renders only its complete authored Sprite, with no hidden rig" % role)
		assert(sprite.texture == material.get_shader_parameter("texture_albedo"), "%s Sprite3D and shader uniforms use the same authored frame" % role)
		assert(material.get_shader_parameter("uv_rect") == Vector4(0.0, 0.0, 1.0, 1.0), "%s normalized action frame uses full-canvas UVs" % role)
		assert(sprite.texture.get_size() == Vector2(NpcActivityScript.ACTION_CANVAS_SIZE), "%s preserves its complete registered source canvas" % role)
		assert(sprite.scale == Vector3.ONE and is_equal_approx(sprite.pixel_size, 2.4 / float(NpcActivityScript.ACTION_VISIBLE_HEIGHT)), "%s uses the authored fixed pixel scale without procedural body stretch" % role)
		var actor_root: Node3D = actor_record.activity_root
		assert(actor_root.global_position.is_finite(), "%s activity root has a valid world position" % role)
		assert(sprite.has_meta("npc_world_ground_anchor_managed"), "%s front Sprite is registered with the world's Y-only billboard ground-anchor owner" % role)
		_world._update_sprite_grounding()
		_assert_projected_contact_feet(role, sprite)
		var original_sprite_position := sprite.position
		sprite.position.y -= 0.2
		assert(float(_source_foot_clearance(sprite).minimum) < 0.0, "%s independent visible-foot check rejects an intentionally submerged source Sprite" % role)
		sprite.position = original_sprite_position
		_assert_projected_contact_feet(role, sprite)
		assert(absf(float(points[role].position.x) - float(actor_record.activity_root.global_position.x)) < 0.001, "%s interaction point starts on its actor root" % role)
	var announcer: Dictionary = _actor_record_for_role("announcer")
	var announcer_root := announcer.activity_root as Node3D
	assert(is_equal_approx(announcer_root.position.x,3.4) and is_equal_approx(announcer_root.position.z,-4.0) and is_zero_approx(announcer_root.position.y), "announcer keeps its authored root; the separate billboard anchor owns visible feet on sampled ground")
	var baseline_root_position: Vector3 = announcer_root.position
	var start_point: Vector3 = points["announcer"].position
	_world.npc_activity._player.seek(0.0, true)
	_world.npc_activity._player.advance(1.2)
	_world.npc_activity._process(0.0)
	assert(is_equal_approx(announcer_root.position.x, baseline_root_position.x + 0.6), "announcer side-step stays on its open route bound (actual %.12f, expected %.12f)" % [announcer_root.position.x, baseline_root_position.x + 0.6])
	assert(is_equal_approx(float(points["announcer"].position.x), start_point.x + 0.6), "the world interaction point follows the announcer root")
	var announcer_sprite := announcer.sprite as Sprite3D
	var baseline_texture: Texture2D = _activity_record_for_role("announcer").baseline_texture
	var activity: Variant = _world.npc_activity
	var event_counts_before: Array[int] = []
	for record in activity._records:
		event_counts_before.append(int(record.idle_event_count))
	activity.set_dialogue_hold(true)
	_world.blocked = true
	_world._process(0.0)
	assert(activity.statistics().activity_paused and activity.statistics().dialogue_hold, "dialogue hold keeps the route controller paused while actors may pose")
	var held_root_position: Vector3 = announcer_root.position
	var held_point: Vector3 = points["announcer"].position
	assert(activity.greet(announcer_sprite,"front"), "the current NPC greeting can start during dialogue hold")
	var greeting_texture: Texture2D = announcer_sprite.texture
	activity._process(0.24)
	var greeting_record := _activity_record_for_role("announcer")
	assert(float(greeting_record.action_elapsed)>0.2 and announcer_sprite.texture!=greeting_texture, "authored greeting frames continue while dialogue is open")
	assert(announcer_root.position==held_root_position and points["announcer"].position==held_point, "dialogue hold freezes NPC routes and their interaction points")
	for index in range(activity._records.size()):
		assert(int(activity._records[index].idle_event_count)==event_counts_before[index], "dialogue hold does not launch random idle actions")
	activity.set_reduced_motion(true)
	var reduced_elapsed: float=float(_activity_record_for_role("announcer").action_elapsed)
	activity._process(0.4)
	assert(is_equal_approx(float(_activity_record_for_role("announcer").action_elapsed),reduced_elapsed), "reduced motion stops authored dialogue-hold animation")
	activity.set_reduced_motion(false)
	activity.set_dialogue_hold(false)
	var paused_greeting_elapsed: float=float(_activity_record_for_role("announcer").action_elapsed)
	activity._process(0.5)
	assert(is_equal_approx(float(_activity_record_for_role("announcer").action_elapsed),paused_greeting_elapsed), "a true modal pause still stops NPC action frames")
	_world.blocked = false
	_world._process(0.0)
	activity._process(0.1)
	for index in range(activity._records.size()):
		assert(int(activity._records[index].idle_event_count)==event_counts_before[index], "unblocking does not burst overdue idle actions")
	_world.apply_settings({"reduced_motion": true})
	assert(_world.npc_activity.statistics().reduced_motion, "world settings propagate reduced motion to NPC activity")
	for actor_record in _world.character_sprites:
		var role := String(actor_record.role)
		var motion: Variant = _activity_record_for_role(role).get("motion")
		assert(actor_record.sprite.visible and motion == null, "%s reduced-motion world pose renders only the authored Sprite" % role)
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
	var label_gaps := {}
	for pitch_degrees in [18.0, 30.0]:
		var pitch := deg_to_rad(float(pitch_degrees))
		_world.camera.look_at(_world.camera.global_position + Vector3(0.0,-sin(pitch),-cos(pitch)), Vector3.UP)
		_world._update_npc_name_labels(true)
		for actor_record in _world.character_sprites:
			var role := String(actor_record.role)
			var gap: float = _world._npc_name_projected_gap(role)
			assert(gap >= 0.07 and gap <= 0.085, "%s cached name label leaves the measured 75mm hair clearance at camera pitch %.0f (actual %.4fm)" % [role,pitch_degrees,gap])
			var source_sprite := actor_record.sprite as Sprite3D
			var body_height := float(actor_record.name_body_height)
			var baseline: Texture2D = _activity_record_for_role(role).baseline_texture
			var expected_body_height := float(baseline.get_image().get_used_rect().size.y) * source_sprite.pixel_size
			assert(is_equal_approx(body_height, expected_body_height), "%s name spacing uses its cached authored visible body height, independent of any rig" % role)
			label_gaps["%s_idle_%.0f" % [role,pitch_degrees]] = gap
			_world._update_sprite_grounding()
			_assert_projected_contact_feet(role, source_sprite)
			assert(source_sprite.visible and _activity_record_for_role(role).motion == null, "%s camera change cannot silently enable a gait rig" % role)
	assert(announcer_sprite.texture == _world.npc_activity._records[2].frames[0], "resumed announcer displays its authored idle frame")
	_world.queue_free()
	await process_frame
	print("PASS: NPC world activity integration")
	quit(0)


func _check_invalid_motion_configuration() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var controller := NpcActivityScript.new()
	holder.add_child(controller)
	var actor := Node3D.new()
	actor.position = Vector3(1.0, 0.055, -3.0)
	holder.add_child(actor)
	var sprite := Sprite3D.new()
	sprite.texture = NpcActivityScript.load_action_frames("ticket")[0]
	sprite.pixel_size = 0.01
	actor.add_child(sprite)
	assert(controller.register_actor(sprite, "ticket", NpcActivityScript.load_action_frames("ticket"), actor), "isolated motion guard test registers a measured-source role")
	controller.finish_registration()
	controller.configure_motion(null, Callable(self, "_test_ground_height"), true)
	var missing_camera: Dictionary = controller.motion_report()
	assert(not bool(missing_camera.enabled) and missing_camera.supported_roles.is_empty() and missing_camera.sprite_fallback_roles.has("ticket"), "an enabled request with a missing camera emits a safe source-Sprite fallback instead of false motion coverage")
	var camera := Camera3D.new()
	holder.add_child(camera)
	controller.configure_motion(camera, Callable(), true)
	var missing_ground: Dictionary = controller.motion_report()
	assert(not bool(missing_ground.enabled) and missing_ground.supported_roles.is_empty() and missing_ground.sprite_fallback_roles.has("ticket"), "an enabled request with a missing ground callable is explicitly disabled")
	controller.configure_motion(camera, Callable(self, "_test_ground_height"), true)
	var valid: Dictionary = controller.motion_report()
	assert(bool(valid.enabled) and valid.supported_roles == ["ticket"] and valid.sprite_fallback_roles.is_empty(), "a later valid camera and ground provider enables the measured role")
	controller.release()
	holder.queue_free()
	await process_frame


func _test_ground_height(_point: Vector2) -> float:
	return 0.055


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


func _assert_projected_contact_feet(role: String, sprite: Sprite3D) -> void:
	var measured := _source_foot_clearance(sprite)
	assert(int(measured.samples) > 4, "%s tests nonempty actual alpha-visible foot pixels" % role)
	assert(float(measured.minimum) >= -0.00001, "%s complete source-foot pixels remain above their local terrain" % role)


func _source_foot_clearance(sprite: Sprite3D) -> Dictionary:
	# Independent source-pixel projection: do not reuse the grounding function
	# under test, and never measure a hidden/deactivated rig as the visible actor.
	var image := sprite.texture.get_image()
	var result := {"samples": 0, "minimum": INF}
	var camera_up: Vector3 = _world.camera.global_basis.y.normalized()
	var camera_right: Vector3 = _world.camera.global_basis.x.normalized()
	for y in range(maxi(0, NpcActivityScript.ACTION_FEET_ROW - 8), image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.5: continue
			var pixel := Vector2(float(x) + 0.5 - float(image.get_width()) * 0.5, float(image.get_height()) * 0.5 - float(y) - 0.5)
			var point: Vector3 = sprite.global_position + (camera_right * pixel.x + camera_up * pixel.y) * sprite.pixel_size
			result.samples += 1
			result.minimum = minf(float(result.minimum), point.y - _world._ground_surface_y(point))
	return result
