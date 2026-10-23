extends SceneTree

const ParkWorldScript = preload("res://game/world/park_world.gd")
const SessionScript = preload("res://game/minigames/session.gd")
const TimeOfDayScript = preload("res://game/core/time_of_day.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := ParkWorldScript.new()
	root.add_child(world)
	await process_frame
	for phase_id in TimeOfDayScript.phase_ids():
		world.set_time_of_day(phase_id)
		await process_frame
		var emitted_ray: Vector3 = -world.sun.global_basis.z
		if emitted_ray.y >= 0.0:
			_fail("The %s key-light ray points above the ground: %s" % [phase_id, emitted_ray])
		var profile: Dictionary = TimeOfDayScript.phase_for_id(phase_id)
		for record in world.contact_shadows:
			var contact: Node3D=record.node
			var ground_offset: Vector3=record.ground_offset
			if not is_equal_approx(contact.position.x,ground_offset.x) or not is_equal_approx(contact.position.z,ground_offset.z):
				_fail("The %s contact shadow is not centred below its actor."%phase_id)
		if world.environment.background_color != profile.sky_color:
			_fail("The %s sky profile was not applied." % phase_id)
		var active_lamps := 0
		for lamp in world.lamps:
			if lamp.light_energy > 0.0:
				active_lamps += 1
		if active_lamps > 8:
			_fail("The %s phase enables %d local lights (limit 8)." % [phase_id, active_lamps])
		var shadow_lamps := 0
		for lamp in world.lamps:
			if lamp.shadow_enabled:
				shadow_lamps += 1
		if shadow_lamps > 2:
			_fail("The %s phase enables %d point-shadow lights (limit 2)." % [phase_id, shadow_lamps])
		if phase_id == "noon" and shadow_lamps != 0:
			_fail("Noon must not enable point-shadow lights.")
		if phase_id in ["dusk", "night"] and active_lamps >= 2 and shadow_lamps != 2:
			_fail("The %s phase must assign both point-shadow slots to nearby active lights." % phase_id)
		for active_index in world.active_lamp_indices:
			if active_index < 0: continue
			var active_distance := world.player.global_position.distance_squared_to(world.lamps[active_index].global_position)
			for candidate_index in range(world.lamps.size()):
				if world.active_lamp_indices.has(candidate_index): continue
				var candidate_distance := world.player.global_position.distance_squared_to(world.lamps[candidate_index].global_position)
				if candidate_distance + 0.0001 < active_distance:
					_fail("The %s phase skipped a closer local lamp." % phase_id)
	if world.avatar.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("The avatar billboard still casts a card shadow.")
	if world.contact_shadows.size() != 4:
		_fail("Expected three NPC and one player contact anchors; found %d." % world.contact_shadows.size())
	if world.actor_shadow_proxies.size() != 4:
		_fail("Expected one shadow-only proxy for each player/NPC actor; found %d." % world.actor_shadow_proxies.size())
	for proxy_record in world.actor_shadow_proxies:
		var proxy := proxy_record.get("node") as Node3D
		if not is_instance_valid(proxy) or proxy.get_child_count() != 2:
			_fail("Each actor proxy must contain separate torso and head shadow volumes.")
			continue
		if proxy.get_parent() != proxy_record.get("actor"):
			_fail("An actor shadow proxy is not parented to its moving actor anchor.")
		var actor := proxy_record.get("actor") as Node3D
		if actor != world.player:
			var expected_ground_offset := world._ground_surface_y(actor.global_position) - actor.global_position.y
			if not is_equal_approx(proxy.position.y, expected_ground_offset):
				_fail("An NPC shadow proxy does not follow its moving ground anchor.")
		for volume in proxy.get_children():
			if not volume is MeshInstance3D or volume.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				_fail("Actor proxy geometry must cast shadows only.")
			if volume.find_children("*", "CollisionObject3D", true, false).size() > 0:
				_fail("Actor shadow proxy must not introduce collision geometry.")
	var moving_npc_record: Dictionary = world.actor_shadow_proxies[1]
	var moving_npc := moving_npc_record.get("actor") as Node3D
	var moving_proxy := moving_npc_record.get("node") as Node3D
	var saved_npc_position := moving_npc.position
	moving_npc.position.y += 0.25
	world._update_sprite_grounding()
	var expected_npc_ground := world._ground_surface_y(moving_npc.global_position) - moving_npc.global_position.y
	if not is_equal_approx(moving_proxy.position.y, expected_npc_ground):
		_fail("A moving NPC's cast shadow is not grounded at its current anchor.")
	for contact_record in world.contact_shadows:
		if contact_record.get("anchor") == moving_npc:
			var actor_contact := contact_record.get("node") as Node3D
			if not is_equal_approx(actor_contact.position.y, expected_npc_ground + 0.005):
				_fail("A moving NPC's contact cue is not kept at its feet.")
	moving_npc.position = saved_npc_position
	world._update_sprite_grounding()
	# Painted billboards keep their card out of the shadow map, but each tall kind
	# owns hidden volumes so lamps, planters and shrubs shade like trees and actors.
	for kind in world.SPRITE_SHADOW_VOLUMES:
		for spec: Dictionary in world.SPRITE_SHADOW_VOLUMES[kind]:
			var part_name := str(kind).capitalize() + "Shadow" + str(spec.part)
			var volumes := world.find_children(part_name + "*", "MeshInstance3D", true, false)
			if volumes.is_empty():
				_fail("No %s volume was built for %s billboards." % [spec.part, kind])
			for volume: MeshInstance3D in volumes:
				if volume.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					_fail("%s is visible in the camera pass." % volume.name)
				if volume.find_children("*", "CollisionObject3D", true, false).size() > 0:
					_fail("%s adds collision." % volume.name)
				if bool(spec.get("grounded", false)):
					# A grounded part may sink into the ground, but never hover above it.
					var bottom: float = (volume.global_transform * volume.get_aabb()).position.y
					var lift := bottom - world._ground_surface_y(volume.global_position)
					if lift > 0.05:
						_fail("%s floats %.2fm above the ground." % [volume.name, lift])
	# The lawn's top face must face the sky, or it ignores the key light and hides
	# every cast shadow that falls on grass.
	var lawn_found := false
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var lawn := node as MeshInstance3D
		if not (lawn.material_override is ShaderMaterial) or (lawn.material_override as ShaderMaterial).shader != world.GRASS: continue
		lawn_found = true
		var arrays: Array = lawn.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0, indices.size(), 3):
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			if not _front_faces_up(a, b, c):
				_fail("Lawn triangle %d faces downward; the sunlit side would be a back face." % (triangle / 3))
				break
	if not lawn_found:
		_fail("The island lawn mesh was not found.")
	# Counter-example: the former centre -> next -> current fan order is rejected.
	if _front_faces_up(Vector3.ZERO, Vector3(cos(0.2), 0, sin(0.2)), Vector3(1, 0, 0)):
		_fail("The lawn winding check accepts the old downward-facing fan order.")
	if not world.material_cache.has("contact_shadow"):
		_fail("The world contact-shadow material is not cached.")
	var session := SessionScript.new()
	root.add_child(session)
	for phase_id in TimeOfDayScript.phase_ids():
		session.set_time_of_day(phase_id)
		if session.time_phase != phase_id or session.phase_wash.a <= 0.0:
			_fail("The session backdrop did not accept phase %s." % phase_id)
	if failures == 0:
		print("PASS: daylight lighting runtime checks")
	world.queue_free()
	session.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


## Godot front faces are clockwise as seen by the viewer, so a face visible from
## above has (b-a)x(c-a) pointing down.
func _front_faces_up(a: Vector3, b: Vector3, c: Vector3) -> bool:
	return (b - a).cross(c - a).y < 0.0


func _fail(message: String) -> void:
	failures += 1
	push_error("[test_daylight_lighting] " + message)
