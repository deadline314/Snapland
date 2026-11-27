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
		_check_foliage_phase(world, phase_id)
	if world.avatar.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("The avatar billboard still casts a card shadow.")
	if world.contact_shadows.size() != 4:
		_fail("Expected three NPC and one player contact anchors; found %d." % world.contact_shadows.size())
	if world.actor_shadow_proxies.size() != 4:
		_fail("Expected one shadow-only proxy for each player/NPC actor; found %d." % world.actor_shadow_proxies.size())
	for proxy_record in world.actor_shadow_proxies:
		var proxy := proxy_record.get("node") as Node3D
		if not is_instance_valid(proxy) or proxy.get_child_count() != 3:
			_fail("Each actor proxy must contain its composed silhouette and two fallback volumes.")
			continue
		if proxy.get_parent() != proxy_record.get("actor"):
			_fail("An actor shadow proxy is not parented to its moving actor anchor.")
		var silhouette = proxy_record.get("silhouette")
		if not is_instance_valid(silhouette) or not silhouette.visible:
			_fail("Current actor art must use its composed alpha silhouette.")
		else:
			var active := 0
			for geometry in proxy.get_children():
				if geometry is GeometryInstance3D and geometry.visible: active += 1
			if active != 1:
				_fail("Fallback volumes must not duplicate a supported alpha silhouette.")
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
	_check_foliage_shadows(world)
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


## Painted scenery (trees, shrubs, planters, lamps, rocks) casts its own
## silhouette from a static card standing on its visible base, and rests on one
## batched contact shadow. No sphere, capsule, cylinder or box stands in for it.
func _check_foliage_shadows(world: Node) -> void:
	var kind_by_texture := {}
	for kind in world.foliage_textures:
		kind_by_texture[world.foliage_textures[kind]] = kind
	var painted: Array[Sprite3D] = []
	for node in world.find_children("*", "Sprite3D", true, false):
		if kind_by_texture.has((node as Sprite3D).texture): painted.append(node)
	if painted.size() < 40:
		_fail("Only %d painted scenery billboards were found." % painted.size())
	if world.foliage_shadow_casters.size() != painted.size():
		_fail("%d painted billboards share %d silhouette casters; each needs exactly one." % [painted.size(), world.foliage_shadow_casters.size()])
	var camera: Camera3D = world.camera
	var view_up := camera.global_basis.y
	var view_forward := -camera.global_basis.z
	var seen_sources := {}
	var seen_kinds := {}
	for caster: MeshInstance3D in world.foliage_shadow_casters:
		var sprite := caster.get("source") as Sprite3D
		if sprite == null or not painted.has(sprite) or seen_sources.has(sprite):
			_fail("%s does not belong to exactly one painted billboard." % caster.name)
			continue
		seen_sources[sprite] = true
		var kind := str(kind_by_texture[sprite.texture])
		seen_kinds[kind] = true
		var art := sprite.texture as AtlasTexture
		var quad := caster.mesh as QuadMesh
		var material := caster.material_override as StandardMaterial3D
		if sprite.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_fail("The %s billboard card itself still casts a shadow." % kind)
		if (sprite.layers & world.sun.light_cull_mask) != 0 or (sprite.layers & camera.cull_mask) == 0:
			_fail("The %s billboard would receive its own silhouette from the key light, or is hidden from the camera." % kind)
		if (caster.layers & world.sun.light_cull_mask) == 0:
			_fail("The %s silhouette is hidden from the key light and cannot cast." % kind)
		if caster.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not caster.visible:
			_fail("The %s silhouette must be an active shadow-only caster." % kind)
		if quad == null or material == null:
			_fail("The %s shadow is not a textured silhouette card." % kind)
			continue
		var atlas_size := art.atlas.get_size()
		if material.albedo_texture != art.atlas or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
				or not Vector2(material.uv1_scale.x, material.uv1_scale.y).is_equal_approx(art.region.size / atlas_size) \
				or not Vector2(material.uv1_offset.x, material.uv1_offset.y).is_equal_approx(art.region.position / atlas_size):
			_fail("The %s shadow is not cut from that sprite's own painted outline." % kind)
		if material != world.material_cache.get("foliage-shadow:" + kind):
			_fail("The %s silhouette material is not the cached one shared by its kind." % kind)
		if caster.is_processing() or caster.is_physics_processing():
			_fail("The static %s silhouette costs per-frame work." % kind)
		if caster.find_children("*", "CollisionObject3D", true, false).size() > 0:
			_fail("The %s silhouette adds collision." % kind)
		var sprite_size := art.region.size * sprite.pixel_size
		if not is_equal_approx(quad.size.x, sprite_size.x) or absf(quad.size.y * view_up.y - sprite_size.y) > 0.01:
			_fail("The %s silhouette does not cover the billboard as seen by the camera." % kind)
		# The card stands where the painted base visibly meets the ground.
		var bottom := sprite.global_position - view_up * sprite_size.y * 0.5
		var card_base := caster.global_position - Vector3.UP * quad.size.y * 0.5
		var ground_y: float = world._ground_surface_y(card_base)
		var visible_base := bottom + view_forward * ((ground_y - bottom.y) / view_forward.y)
		if Vector2(card_base.x - visible_base.x, card_base.z - visible_base.z).length() > 0.05:
			_fail("The %s shadow starts %.2f m away from its painted base." % [kind, Vector2(card_base.x - visible_base.x, card_base.z - visible_base.z).length()])
		if absf(card_base.y - ground_y) > 0.05:
			_fail("The %s shadow source floats or sinks %.2f m at the ground." % [kind, card_base.y - ground_y])
		for parameter in ["outline_soften", "ground_blend"]:
			if float((sprite.material_override as ShaderMaterial).get_shader_parameter(parameter)) <= 0.0:
				_fail("The %s billboard keeps its heavy outline or cut base line (%s)." % [kind, parameter])
	for kind in ["oak", "palm", "pine", "shrub", "planter", "lamp", "rocks"]:
		if not seen_kinds.has(kind):
			_fail("No silhouette caster was built for %s billboards." % kind)
	# Counter-example for the rule above: the former sphere/cylinder/box stand-ins.
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or mesh.mesh is QuadMesh: continue
		if mesh.is_visible_in_tree():
			_fail("%s casts a substitute shape instead of a painted silhouette." % mesh.name)
	var contacts := world.get_node_or_null("FoliageContactShadows") as MultiMeshInstance3D
	if contacts == null or contacts.multimesh.instance_count != painted.size():
		_fail("Painted billboards do not each rest on one batched contact shadow.")
	elif contacts.material_override != world.contact_shadow_material or contacts.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("The scenery contact shadows must reuse the soft contact material and cast nothing.")
	elif world._foliage_contact_transforms.size() != painted.size():
		_fail("The batched contact shadows were not built from every painted billboard.")
	else:
		# The headless renderer does not store instance transforms; read the
		# placements the batch was built from.
		for placement: Transform3D in world._foliage_contact_transforms:
			var lift: float = placement.origin.y - world._ground_surface_y(placement.origin)
			if lift < 0.0 or lift > 0.05:
				_fail("A scenery contact shadow at %s sits %.2f m off the ground." % [placement.origin, lift])


## Each phase change regrades the painted scenery and turns its shadow cards to
## the light, so the cast shape keeps the painted outline at any hour.
func _check_foliage_phase(world: Node, phase_id: String) -> void:
	var tint: Color = world.FOLIAGE_PHASE_TINT[phase_id]
	for material: ShaderMaterial in world.foliage_materials:
		if material.get_shader_parameter("tint") != tint:
			_fail("Painted scenery ignores the %s light." % phase_id)
			break
	# The grade multiplies the ambient light, the only sky light scenery receives.
	var graded: Color = world.environment.ambient_light_color * world.environment.ambient_light_energy * tint
	var noon_profile: Dictionary = TimeOfDayScript.phase_for_id("noon")
	var noon_graded: Color = noon_profile.ambient_color * float(noon_profile.ambient_energy) * 0.58 * (world.FOLIAGE_PHASE_TINT["noon"] as Color)
	if graded.get_luminance() > noon_graded.get_luminance() + 0.001:
		_fail("Painted scenery is brighter in the %s light than at noon." % phase_id)
	if phase_id == "night" and graded.get_luminance() > noon_graded.get_luminance() * 0.6:
		_fail("Painted scenery stays near daytime brightness at night.")
	if graded.get_luminance() < 0.12:
		_fail("Painted scenery is too dark to read in the %s light." % phase_id)
	var light: Vector3 = -world.sun.global_basis.z
	var light_flat := Vector3(light.x, 0.0, light.z).normalized()
	for caster: MeshInstance3D in world.foliage_shadow_casters:
		var card := caster.global_basis
		if absf(card.x.dot(light_flat)) > 0.01 or absf(card.y.y - 1.0) > 0.001:
			_fail("A scenery silhouette is not upright and facing the %s light." % phase_id)
			break
		if card.x.dot(world.camera.global_basis.x) <= 0.0:
			_fail("A scenery silhouette is mirrored against its billboard in the %s light." % phase_id)
			break


func _fail(message: String) -> void:
	failures += 1
	push_error("[test_daylight_lighting] " + message)
