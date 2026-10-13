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
	_check_invalid_motion_configuration()
	_world = ParkWorldScript.new()
	root.add_child(_world)
	await process_frame
	assert(_world.npc_activity.statistics().registration_count == 3, "the world registers each named NPC once")
	assert(_world.npc_activity.statistics().by_role.get("ticket", 0) == 1, "ticket is associated with its guide point")
	assert(_world.npc_activity.statistics().by_role.get("imp", 0) == 1, "imp is associated with quest-001")
	assert(_world.npc_activity.statistics().by_role.get("announcer", 0) == 1, "announcer is associated with quest-002")
	assert(_world.avatar != null and _world.avatar.texture != null, "NPC controller integration leaves the player avatar available")
	var motion_status: Dictionary = _world.npc_activity.motion_report()
	assert(bool(motion_status.enabled), "World passes a live camera and ground provider when opting into measured NPC gait")
	assert(motion_status.supported_roles.size() == 3, "all three actual World NPCs have valid measured gait sources, not merely registered actor records")
	assert(motion_status.sprite_fallback_roles.is_empty(), "valid World motion configuration leaves no candidate NPC silently on source-only fallback")
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
		assert(motion != null and motion.supported and motion.rig.source_records.size() == 2, "%s has the actual measured left/right gait adapter" % role)
		assert(sprite.visible != motion.rig.visible, "%s world actor renders either its authored Sprite or measured rig, never both" % role)
		assert(sprite.texture == material.get_shader_parameter("texture_albedo"), "%s Sprite3D and shader uniforms use the same authored frame" % role)
		assert(material.get_shader_parameter("uv_rect") == Vector4(0.0, 0.0, 1.0, 1.0), "%s normalized action frame uses full-canvas UVs" % role)
		assert(motion.front_body_height_px > 0 and motion.target_body_height_px > 0, "%s source Sprite and gait target have measured body heights" % role)
		var expected_pixel_size: float = float(motion.target_body_height_px) * motion.rig.PIXEL_SIZE / float(motion.front_body_height_px)
		assert(is_equal_approx(sprite.pixel_size, expected_pixel_size) and is_equal_approx(sprite.pixel_size, motion.calibrated_sprite_pixel_size), "%s front Sprite scale matches its measured opaque source height and rig target" % role)
		var root: Node3D = actor_record.activity_root
		var sampled_ground: float = _world._avatar_ground_height(Vector2(root.global_position.x, root.global_position.z))
		assert(absf(root.global_position.y - sampled_ground) < 0.0001, "%s activity root is on the same sampled ground as the measured rig" % role)
		assert(sprite.has_meta("npc_world_ground_anchor_managed"), "%s front Sprite is registered with the world's Y-only billboard ground-anchor owner" % role)
		motion._sync_front_ground_anchor()
		_world._update_sprite_grounding()
		_assert_projected_contact_feet(role,sprite,root,motion,sampled_ground)
		assert(absf(float(points[role].position.x) - float(actor_record.activity_root.global_position.x)) < 0.001, "%s interaction point starts on its actor root" % role)
	var announcer: Dictionary = _actor_record_for_role("announcer")
	var announcer_root := announcer.activity_root as Node3D
	var announcer_ground: float = _world._avatar_ground_height(Vector2(3.4,-4.0))
	assert(is_equal_approx(announcer_root.position.x,3.4) and is_equal_approx(announcer_root.position.z,-4.0) and is_equal_approx(announcer_root.position.y,announcer_ground), "announcer stays at its open central-plaza x/z location with feet on sampled ground")
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
		assert(actor_record.sprite.visible and not motion.rig.visible, "%s reduced-motion world pose renders only the authored Sprite" % role)
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
			var motion: Variant = _activity_record_for_role(role).motion
			var rig := motion.rig as Node3D
			var source_sprite := actor_record.sprite as Sprite3D
			var body_height := float(actor_record.name_body_height)
			assert(is_equal_approx(body_height,float(motion.target_body_height_px)*motion.rig.PIXEL_SIZE), "%s name spacing uses its cached measured front/source target height" % role)
			var gap_key := "%s_idle_%.0f" % [role,pitch_degrees]
			label_gaps[gap_key] = gap
			# Both render paths share the same measured body-height target; exercise
			# the rig visibility state without advancing or teleporting the actor.
			var was_rig_visible := rig.visible
			var was_sprite_visible := source_sprite.visible
			rig.visible = true
			source_sprite.visible = false
			assert(is_equal_approx(_world._npc_name_projected_gap(role),gap), "%s name anchor remains above the measured gait body at pitch %.0f" % [role,pitch_degrees])
			rig.visible = was_rig_visible
			source_sprite.visible = was_sprite_visible
			assert(_world._npc_name_projected_gap(role) >= 0.07, "%s restored idle name remains clear of hair" % role)
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


func _assert_projected_contact_feet(role: String, sprite: Sprite3D, actor_root: Node3D, motion: Variant, sampled_ground: float) -> void:
	var camera_up: Vector3 = _world.camera.global_basis.y.normalized()
	var camera_right: Vector3 = _world.camera.global_basis.x.normalized()
	var foot_offset: float = (float(NpcActivityScript.ACTION_FEET_ROW)-float(NpcActivityScript.ACTION_CANVAS_SIZE.y)*0.5)*sprite.pixel_size
	var foot_center: Vector3 = sprite.global_position-camera_up*foot_offset
	assert(absf(foot_center.x-actor_root.global_position.x)<0.004 and absf(foot_center.z-actor_root.global_position.z)<0.004, "%s nested world anchor keeps the complete billboard contact row above its actual X/Z root point" % role)
	assert(foot_center.y>=sampled_ground, "%s Y-only world anchor keeps the projected contact row above its sampled surface" % role)
	var image := sprite.texture.get_image()
	var checks := 0
	for y in range(maxi(0,NpcActivityScript.ACTION_FEET_ROW-8),image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a<0.5: continue
			var pixel := Vector2(float(x)+0.5-float(image.get_width())*0.5,float(image.get_height())*0.5-float(y)-0.5)
			var point: Vector3 = sprite.global_position+camera_right*(pixel.x*sprite.pixel_size)+camera_up*(pixel.y*sprite.pixel_size)
			var surface: float = _world._ground_surface_y(point)
			assert(point.y+0.00001>=surface, "%s opaque foot pixel (%d,%d) is above its local lawn/plaza/ramp surface" % [role,x,y])
			checks+=1
	assert(checks>4 and motion.foot_samples_cache.size()<=64, "%s verifies actual per-column opaque foot pixels with a bounded texture sample cache" % role)
