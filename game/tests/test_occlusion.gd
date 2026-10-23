extends SceneTree

const OcclusionControllerScript = preload("res://game/world/occlusion_controller.gd")
const OccluderShader = preload("res://game/world/occluder.gdshader")
const CoastalMaterialShader = preload("res://game/world/coastal_material.gdshader")
const ParkWorldScript = preload("res://game/world/park_world.gd")
const OCCLUSION_LAYER := 1 << 5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if save_path.is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	var subviewport := SubViewport.new()
	subviewport.size = Vector2i(800, 600)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(subviewport)
	var world := Node3D.new()
	subviewport.add_child(world)
	var controller = OcclusionControllerScript.new()
	world.add_child(controller)
	var player := CharacterBody3D.new()
	player.collision_layer = OCCLUSION_LAYER
	player.collision_mask = 1
	var player_collision := CollisionShape3D.new()
	var player_shape := BoxShape3D.new()
	player_shape.size = Vector3(0.6, 1.8, 0.6)
	player_collision.shape = player_shape
	player_collision.position.y = 0.9
	player.add_child(player_collision)
	world.add_child(player)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0.0, 2.0, 12.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.current = true
	controller.configure(player, camera)
	await physics_frame
	controller.refresh_visibility()
	assert(not controller.statistics().active, "an open path leaves building materials unchanged")
	assert(int(controller.statistics().ray_mask) == OCCLUSION_LAYER, "ray mask includes only the dedicated building layer")
	assert(controller._ray_query.exclude.has(player.get_rid()), "player RID is explicitly excluded from obstruction rays")
	var shader_source := FileAccess.get_file_as_string("res://game/world/occluder.gdshader")
	assert(shader_source.contains("SCREEN_UV * viewport_size_px") and shader_source.contains("distance(fragment_px, body_center_px)"), "the opening is a circular mask in viewport-pixel space")
	assert(shader_source.contains("fragment_view_depth < player_view_depth") and shader_source.contains("discard;"), "only eligible fragments in front of the player are cut out")
	assert(shader_source.contains("edge_feather_px") and shader_source.contains("smoothstep(radius - edge_width, radius + edge_width, distance_px)"), "the cutaway uses a narrow soft dither band at the circle edge")
	assert(shader_source.contains("!IN_SHADOW_PASS") and not shader_source.contains("ALPHA ="), "the reveal keeps opaque shading and preserves the full shadow silhouette")
	assert(shader_source.contains("ALBEDO = COLOR.rgb * occluder_tint.rgb"), "building shading retains source colors and multimesh instance colors")
	assert(is_equal_approx(OcclusionControllerScript.reveal_radius_px(114.0,Vector2(1280,720)),85.5), "normal framing retains the compact legacy radius below its cap")
	assert(is_equal_approx(OcclusionControllerScript.reveal_radius_px(380.0,Vector2(1280,720)),228.0), "close 1280x720 framing scales enough to fit a 380px actor")
	assert(is_equal_approx(OcclusionControllerScript.reveal_radius_px(380.0,Vector2(800,600)),204.0), "close 800x600 framing fits the body under the short-edge safety cap")

	var decoy := StaticBody3D.new()
	decoy.collision_layer = 1
	decoy.collision_mask = 0
	world.add_child(decoy)
	_add_box_collider(decoy, Vector3(3.0, 3.0, 0.4))
	var player_path := _path_midpoint(camera, player)
	decoy.global_position = player_path
	await physics_frame
	controller.refresh_visibility()
	assert(not controller.statistics().active, "unregistered default-layer geometry does not trigger the cutaway")
	decoy.queue_free()
	await process_frame

	var front_a := _add_registered_building(world, controller, _path_fraction(camera, player, 0.48), Vector3(2.5, 2.5, 0.4), Color("#e9d8b6"))
	var front_b := _add_registered_building(world, controller, _path_fraction(camera, player, 0.70), Vector3(2.5, 2.5, 0.4), Color("#75a9a2"))
	await physics_frame
	controller.refresh_visibility()
	assert(controller.statistics().active, "eligible building directly in front of the player activates the mask")
	assert(int(controller.statistics().active_groups) == 2, "multiple eligible blockers before the player remain cut away")
	var first_mesh: GeometryInstance3D = front_a.mesh
	assert(first_mesh.material_override is ShaderMaterial, "registered building pieces use the shared shaded cutaway material")
	assert(first_mesh.material_override.get_shader_parameter("occluder_tint") == Color("#e9d8b6"), "source material color is retained on registered architecture")
	var player_layer_before := player.collision_layer
	var player_mask_before := player.collision_mask
	controller._process(0.05)
	assert(float(controller.statistics().fade_weight) > 0.0 and float(controller.statistics().fade_weight) < 1.0, "entry eases over the configured short interval")
	var initial_body_height := camera.unproject_position(player.global_position + Vector3.UP * 1.9).distance_to(camera.unproject_position(player.global_position))
	var initial_radius_expected := OcclusionControllerScript.reveal_radius_px(initial_body_height,Vector2(800.0,600.0))
	assert(is_equal_approx(float(controller.statistics().radius_px), initial_radius_expected), "reveal radius scales to about three quarters of projected body height")
	assert(is_equal_approx(float(controller._shader_material.get_shader_parameter("edge_feather_px")), 2.5), "edge feather remains a small logical-pixel band")
	controller.set_reduced_motion(true)
	assert(is_equal_approx(float(controller.statistics().fade_weight), 1.0), "reduced motion keeps the orientation aid and snaps it to its active target")
	assert(player.collision_layer == player_layer_before and player.collision_mask == player_mask_before, "visibility rays do not mutate player collision")
	controller.set_reduced_motion(false)
	controller._process(0.2)
	assert(is_equal_approx(float(controller.statistics().fade_weight), 1.0), "normal mode completes the eased entry")

	var behind := _add_registered_building(world, controller, _path_fraction(camera, player, 1.12), Vector3(2.5, 2.5, 0.4), Color("#b09071"))
	await physics_frame
	controller.refresh_visibility()
	assert(not controller._active_group_ids.has(int(behind.id)), "building behind the player is outside the bounded camera-to-body ray")
	var initial_viewport := Vector2i(subviewport.size)
	var initial_radius := float(controller.statistics().radius_px)
	subviewport.size = Vector2i(1000, 700)
	await process_frame
	controller._process(0.0)
	assert(controller.statistics().viewport_size == Vector2(1000.0, 700.0), "mask projection follows a resized viewport")
	assert(float(controller.statistics().radius_px) > initial_radius, "circle radius remains proportional to projected body height on resize")
	assert(initial_viewport == Vector2i(800, 600), "resize fixture began at a known viewport size")
	var resized_height := camera.unproject_position(player.global_position + Vector3.UP * 1.9).distance_to(camera.unproject_position(player.global_position))
	var resized_radius_expected := OcclusionControllerScript.reveal_radius_px(resized_height,Vector2(1000.0,700.0))
	assert(is_equal_approx(float(controller.statistics().radius_px), resized_radius_expected), "resized reveal stays proportional to logical projection with a viewport cap")
	subviewport.size = Vector2i(1280,720)
	await process_frame
	camera.size = 12.0
	controller._process(0.0)
	var normal_1280_height := camera.unproject_position(player.global_position+Vector3.UP*1.9).distance_to(camera.unproject_position(player.global_position))
	var normal_1280_radius := float(controller.statistics().radius_px)
	assert(normal_1280_radius<120.0 and is_equal_approx(normal_1280_radius,OcclusionControllerScript.reveal_radius_px(normal_1280_height,Vector2(1280.0,720.0))), "normal 1280x720 framing retains a compact actor-sized circle")
	camera.size = 3.6
	controller._process(0.0)
	var close_1280_height := camera.unproject_position(player.global_position+Vector3.UP*1.9).distance_to(camera.unproject_position(player.global_position))
	var close_1280_radius := float(controller.statistics().radius_px)
	assert(close_1280_height>370.0 and close_1280_height<390.0, "the close-view fixture projects the actor to about 380 logical pixels")
	assert(close_1280_radius>120.0 and close_1280_radius>=close_1280_height*(1.0/1.9) and close_1280_radius<=720.0*0.34, "close 1280x720 reveal covers the projected face-to-feet extent within the short-edge cap")
	subviewport.size = Vector2i(800,600)
	await process_frame
	camera.size = 3.0
	controller._process(0.0)
	var close_800_height := camera.unproject_position(player.global_position+Vector3.UP*1.9).distance_to(camera.unproject_position(player.global_position))
	var close_800_radius := float(controller.statistics().radius_px)
	assert(close_800_height>370.0 and close_800_height<390.0, "the compact-view fixture also projects the actor to about 380 logical pixels")
	assert(close_800_radius>120.0 and close_800_radius>=close_800_height*(1.0/1.9) and close_800_radius<=600.0*0.34, "close 800x600 reveal covers the projected face-to-feet extent within its smaller short-edge cap")
	subviewport.size = Vector2i(1000,700)
	await process_frame
	camera.size = 7.0
	controller._process(0.0)
	assert(float(controller.statistics().radius_px) <= 320.0 and float(controller.statistics().radius_px) >= 32.0, "orthographic zoom keeps the cutaway within its pixel bounds")
	assert(float(controller.statistics().radius_px) <= minf(1000.0, 700.0) * 0.34 + 0.001, "zoomed circle remains capped relative to the visible viewport")
	camera.size = 12.0

	front_a.body.queue_free()
	front_b.body.queue_free()
	behind.body.queue_free()
	await process_frame
	controller.refresh_visibility()
	controller._process(0.05)
	assert(float(controller.statistics().fade_weight) < 1.0, "exit starts an eased restoration")
	controller._process(0.2)
	assert(is_zero_approx(float(controller.statistics().fade_weight)), "exit restores the original building appearance")
	await process_frame
	assert(int(controller.statistics().registered_buildings) == 0, "removed building groups clean up without stale ray references")
	var survivor := _add_registered_building(world, controller, _path_fraction(camera, player, 0.45), Vector3(2.5, 2.5, 0.4), Color("#8a9f76"))
	var survivor_ray_body: CollisionObject3D = survivor.body.get_child(survivor.body.get_child_count() - 1)
	var coastal_replacement := ShaderMaterial.new()
	coastal_replacement.shader = CoastalMaterialShader
	var atlas := load("res://assets/world/coastal-materials-v1.png") as Texture2D
	coastal_replacement.set_shader_parameter("atlas_texture", atlas)
	coastal_replacement.set_shader_parameter("tile_index", 4)
	controller._fade_weight = 0.43
	controller._last_center_px = Vector2(420.0, 310.0)
	controller._last_radius_px = 57.0
	controller._last_viewport_size = Vector2(800.0,600.0)
	assert(controller.has_method("replace_registered_surface"), "registered geometry exposes a post-registration surface-material bridge")
	assert(controller.call("replace_registered_surface", survivor.mesh, coastal_replacement), "bridge accepts the project coastal shader for an already-registered building")
	controller._update_shader_uniforms(1.25)
	assert(survivor.mesh.material_override != coastal_replacement and survivor.mesh.material_override.shader == CoastalMaterialShader, "registered coastal material keeps the atlas shader in a controller-owned copy")
	assert(coastal_replacement.get_shader_parameter("occlusion_cutaway_weight") == null, "source coastal material remains immutable while its registered copy reveals")
	assert(coastal_replacement.get_shader_parameter("atlas_texture") == atlas, "post-registration cutaway keeps the selected coastal texture")
	assert(is_equal_approx(float(survivor.mesh.material_override.get_shader_parameter("occlusion_cutaway_weight")),0.43), "registered coastal surface receives the current circular cutaway weight")
	assert(is_equal_approx(float(survivor.mesh.material_override.get_shader_parameter("occlusion_body_radius_px")),57.0), "registered coastal surface receives the same projected mask radius")
	controller.release()
	assert(survivor.mesh.material_override == coastal_replacement and survivor.mesh.material_override.get_shader_parameter("atlas_texture") == atlas, "release restores the final intended coastal surface with its texture intact")
	assert(int(survivor.body.collision_layer) == 0 and int(survivor_ray_body.collision_layer) == 0, "controller release removes its ray-only collision layer")
	var direct_body := StaticBody3D.new()
	direct_body.collision_layer = 0
	direct_body.collision_mask = 0
	world.add_child(direct_body)
	_add_box_collider(direct_body, Vector3(2.0, 2.0, 0.5))
	var direct_mesh := MeshInstance3D.new()
	var direct_box := BoxMesh.new()
	direct_box.size = Vector3(2.0, 2.0, 0.5)
	direct_mesh.mesh = direct_box
	direct_body.add_child(direct_mesh)
	direct_mesh.material_override = coastal_replacement
	controller.begin_building()
	controller.register_geometry(direct_mesh, coastal_replacement)
	assert(controller.finish_building(direct_body), "a registered project coastal shader can be used as the original surface directly")
	controller._fade_weight = 0.43
	controller._update_shader_uniforms(1.25)
	assert(direct_mesh.material_override != coastal_replacement and direct_mesh.material_override.shader == CoastalMaterialShader and is_equal_approx(float(direct_mesh.material_override.get_shader_parameter("occlusion_cutaway_weight")), 0.43), "directly registered coastal geometry gets the isolated mask without replacing the atlas shader")
	controller.configure(player, camera)
	var cylinder_body := StaticBody3D.new()
	cylinder_body.collision_layer = 0
	cylinder_body.collision_mask = 0
	cylinder_body.position = _path_fraction(camera, player, 0.48)
	world.add_child(cylinder_body)
	var cylinder_mesh := MeshInstance3D.new()
	var curved_mesh := CylinderMesh.new()
	curved_mesh.top_radius = 0.65
	curved_mesh.bottom_radius = 0.65
	curved_mesh.height = 2.0
	cylinder_mesh.mesh = curved_mesh
	var cylinder_source := StandardMaterial3D.new()
	cylinder_source.albedo_color = Color("#718f7c")
	cylinder_mesh.material_override = cylinder_source
	cylinder_body.add_child(cylinder_mesh)
	controller.begin_building()
	controller.register_geometry(cylinder_mesh, cylinder_source)
	# Match ParkWorld builders that replace a registered standard surface before
	# finish_building, without calling replace_registered_surface().
	cylinder_mesh.material_override = coastal_replacement
	var cylinder_group_id := int(controller._next_group_id)
	assert(controller.finish_building(cylinder_body), "curved geometry accepts a final coastal surface selected after registration")
	var cylinder_ray_body := cylinder_body.get_child(cylinder_body.get_child_count() - 1) as StaticBody3D
	assert(cylinder_ray_body != null and cylinder_ray_body.get_child_count() == 1, "a cylinder mesh contributes one ray-only blocking box")
	var cylinder_ray_shape := cylinder_ray_body.get_child(0) as CollisionShape3D
	assert(cylinder_ray_shape != null and cylinder_ray_shape.shape is BoxShape3D, "the cylinder's bounded mesh extents become a ray shape")
	assert((cylinder_ray_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(1.3, 2.0, 1.3)), "cylinder blocker uses the mesh's conservative AABB dimensions")
	assert(cylinder_mesh.material_override == direct_mesh.material_override and cylinder_mesh.material_override.get_shader_parameter("atlas_texture") == atlas, "finish_building preserves the late-selected atlas and shares one managed material per source")
	var lantern_body := StaticBody3D.new()
	lantern_body.collision_layer = 0
	lantern_body.collision_mask = 0
	lantern_body.position = Vector3(80.0, 2.0, 80.0)
	world.add_child(lantern_body)
	var lantern_mesh := MeshInstance3D.new()
	var lantern_shape := SphereMesh.new()
	lantern_shape.radius = 0.55
	lantern_shape.height = 1.1
	lantern_mesh.mesh = lantern_shape
	var registered_surface := StandardMaterial3D.new()
	registered_surface.albedo_color = Color("#8c7257")
	lantern_mesh.material_override = registered_surface
	lantern_body.add_child(lantern_mesh)
	controller.begin_building()
	controller.register_geometry(lantern_mesh, registered_surface)
	var final_lantern_surface := StandardMaterial3D.new()
	final_lantern_surface.albedo_color = Color("#70553f")
	final_lantern_surface.emission_enabled = true
	final_lantern_surface.emission = Color("#f1a34b")
	final_lantern_surface.emission_energy_multiplier = 2.4
	final_lantern_surface.metallic = 0.63
	lantern_mesh.material_override = final_lantern_surface
	var lantern_group_id := int(controller._next_group_id)
	assert(controller.finish_building(lantern_body), "a late-selected simple standard material remains eligible for cutaway")
	assert(lantern_mesh.material_override.shader == OccluderShader and lantern_mesh.material_override != controller._shader_material, "late-selected standard surface uses the same cutaway shader with isolated authored surface parameters")
	assert(lantern_mesh.material_override.get_shader_parameter("occluder_emission") == final_lantern_surface.emission, "registered lantern keeps the final standard material emission color")
	assert(is_equal_approx(float(lantern_mesh.material_override.get_shader_parameter("occluder_emission_energy")), 2.4), "registered lantern keeps the final emission energy")
	assert(is_equal_approx(float(lantern_mesh.material_override.get_shader_parameter("occluder_metallic")), 0.63), "registered lantern keeps the final metallic response")
	assert(int(controller._collider_to_group.get(lantern_body.get_instance_id(), 0)) == lantern_group_id, "the emissive curved lantern remains a registered obstruction")
	await physics_frame
	controller.refresh_visibility()
	assert(controller._active_group_ids.has(cylinder_group_id), "the curved cylinder blocks the camera-to-avatar visibility ray")
	var sphere_body := StaticBody3D.new()
	sphere_body.collision_layer = 0
	sphere_body.collision_mask = 0
	sphere_body.position = _path_fraction(camera, player, 0.70)
	world.add_child(sphere_body)
	var sphere_mesh := MeshInstance3D.new()
	var curved_sphere := SphereMesh.new()
	curved_sphere.radius = 0.7
	curved_sphere.height = 1.4
	sphere_mesh.mesh = curved_sphere
	sphere_mesh.material_override = cylinder_source
	sphere_body.add_child(sphere_mesh)
	controller.begin_building()
	controller.register_geometry(sphere_mesh, cylinder_source)
	var sphere_group_id := int(controller._next_group_id)
	assert(controller.finish_building(sphere_body), "sphere geometry registers for obstruction rays")
	var sphere_ray_body := sphere_body.get_child(sphere_body.get_child_count() - 1) as StaticBody3D
	assert(sphere_ray_body != null and sphere_ray_body.get_child_count() == 1, "a sphere mesh contributes one ray-only blocking box")
	await physics_frame
	controller.refresh_visibility()
	assert(controller._active_group_ids.has(sphere_group_id), "the curved sphere blocks the camera-to-avatar visibility ray")
	var unregistered_coastal_mesh := MeshInstance3D.new()
	unregistered_coastal_mesh.mesh = direct_box
	unregistered_coastal_mesh.material_override = coastal_replacement
	world.add_child(unregistered_coastal_mesh)
	var unregistered_cutaway_enabled: Variant = unregistered_coastal_mesh.material_override.get_shader_parameter("occlusion_cutaway_enabled")
	assert(unregistered_cutaway_enabled == null or is_zero_approx(float(unregistered_cutaway_enabled)), "an unregistered object sharing the coastal atlas material stays outside the cutaway")
	var other_controller = OcclusionControllerScript.new()
	world.add_child(other_controller)
	var other_mesh := MeshInstance3D.new()
	other_mesh.mesh = direct_box
	other_mesh.material_override = coastal_replacement
	world.add_child(other_mesh)
	other_controller.begin_building()
	other_controller.register_geometry(other_mesh, coastal_replacement)
	other_controller._fade_weight = 0.81
	other_controller._set_coastal_cutaway(other_mesh, true)
	assert(other_mesh.material_override != direct_mesh.material_override, "separate controllers never share mutable mask materials")
	assert(is_equal_approx(float(direct_mesh.material_override.get_shader_parameter("occlusion_cutaway_weight")), float(controller._fade_weight)), "a second controller cannot change the first controller's reveal")
	assert(controller._coastal_materials.size() == 1, "repeated source registration reuses one coastal material rather than allocating per mesh")
	other_controller.release()
	assert(other_mesh.material_override == coastal_replacement and other_controller._coastal_materials.is_empty(), "release during unfinished registration restores the source and releases copies")
	controller.release()
	assert(controller._coastal_materials.is_empty(), "release drops managed coastal material references")
	assert(lantern_mesh.material_override == final_lantern_surface, "release restores the exact late-selected standard material identity")
	assert(direct_mesh.material_override == coastal_replacement and direct_mesh.material_override.get_shader_parameter("occlusion_cutaway_weight") == null, "release disables cutaway and retains directly registered coastal surfaces")
	assert(cylinder_mesh.material_override == coastal_replacement and cylinder_mesh.material_override.get_shader_parameter("atlas_texture") == atlas, "release restores the late-selected coastal surface without losing its atlas texture")
	assert(int(cylinder_body.collision_layer) == 0 and int(cylinder_ray_body.collision_layer) == 0, "release removes the curved mesh ray layer and restores the blocker layer")
	world.queue_free()
	subviewport.queue_free()
	await process_frame

	var park_world = ParkWorldScript.new()
	root.add_child(park_world)
	assert(int(park_world.occlusion_controller.statistics().registered_buildings) >= 13, "the world registers kiosk buildings and all three eligible arches")
	var player_collision_before: int = park_world.player.collision_layer
	var first_kiosk_body: CollisionObject3D
	var arch_blocker: CollisionObject3D
	for node in park_world.find_children("*", "StaticBody3D", true, false):
		if int(node.collision_layer) & OCCLUSION_LAYER:
			if first_kiosk_body == null:
				first_kiosk_body = node
			if node.global_position.distance_to(Vector3(-4.0, 1.65, -11.0)) < 0.1 and (int(node.collision_layer) & 1) != 0:
				arch_blocker = node
	assert(is_instance_valid(first_kiosk_body), "registered kiosk base colliders expose the ray-only layer")
	assert((int(first_kiosk_body.collision_layer) & 1) == 1 and (int(park_world.player.collision_mask) & 1) == 1, "kiosk/player walk collision continues to use the original layer")
	assert(is_instance_valid(arch_blocker), "the center welcome arch frame is registered for obstruction rays")
	assert((int(arch_blocker.collision_layer) & 1) == 1 and (int(arch_blocker.collision_layer) & OCCLUSION_LAYER) != 0, "arch ray registration preserves its original walk-collision layer")
	var arch_group_id := int(park_world.occlusion_controller._collider_to_group.get(arch_blocker.get_instance_id(), 0))
	var arch_surface := arch_blocker.get_parent() as GeometryInstance3D
	var arch_coastal_original: Material = park_world.occlusion_controller._building_groups.filter(func(group: Dictionary) -> bool: return group.geometry.has(arch_surface))[0].originals[arch_surface.get_instance_id()]
	var arch_coastal_material := arch_surface.material_override as ShaderMaterial
	assert(arch_coastal_material != null and arch_coastal_material.shader == CoastalMaterialShader, "registered arch surface retains its coastal material shader")
	assert(arch_coastal_material.get_shader_parameter("atlas_texture") != null, "registered arch surface retains the coastal atlas texture")
	var arch_title: Label3D
	var rear_arch_title: Label3D
	var unrelated_label: Label3D
	for label: Label3D in park_world.find_children("*", "Label3D", true, false):
		if label.text == "迎賓大道": arch_title = label
		elif label.text == "倒影大道": rear_arch_title = label
		elif label.text == "中央廣場": unrelated_label = label
	assert(is_instance_valid(arch_title) and is_instance_valid(rear_arch_title) and is_instance_valid(unrelated_label), "arch title labels and an unrelated world label exist")
	var arch_title_modulate := arch_title.modulate
	park_world.player.position = Vector3(0, 0.4, -15)
	park_world.player.velocity = Vector3.ZERO
	park_world.camera.position = park_world.player.position + Vector3(0, 15.5, 25)
	park_world.camera.look_at(park_world.player.position + Vector3(0, 1, -3))
	# Locality owns the real distant plaza title. Occlusion must preserve its
	# current owner-selected state, and must also leave a visible decoy alone.
	var visible_unregistered_title := Label3D.new()
	visible_unregistered_title.text = "Nearby unregistered occlusion fixture"
	park_world.add_child(visible_unregistered_title)
	visible_unregistered_title.position = park_world.player.position + Vector3(5, 2, 0)
	await physics_frame
	park_world._update_district_label_visibility()
	var unrelated_was_visible: bool = unrelated_label.visible
	park_world.occlusion_controller.refresh_visibility()
	assert(arch_group_id != 0 and park_world.occlusion_controller._active_group_ids.has(arch_group_id), "the actual arch beam activates the local body-centered cutaway")
	park_world.occlusion_controller._process(0.15)
	assert(not arch_title.visible and arch_title.modulate == arch_title_modulate, "only the intersecting registered arch title hides while the body mask is active")
	assert(rear_arch_title.visible and visible_unregistered_title.visible, "a title behind the player and a visible unregistered world label remain visible")
	assert(unrelated_label.visible == unrelated_was_visible, "occlusion preserves the distant plaza title state owned by player-distance visibility")
	assert(int(park_world.player.collision_layer) == player_collision_before, "arch ray setup leaves player collision unchanged")
	park_world.apply_settings({"reduced_motion": true})
	park_world.occlusion_controller._process(0.0)
	assert(not arch_title.visible, "reduced motion retains the active visibility aid and hides only the overlapping title")
	Input.action_press("move_down")
	# Cover the same 5.5m passage at the real travel speed and start acceleration.
	var arch_walk_frames := ceili((5.5/ParkWorldScript.AVATAR_RUN_SPEED+ParkWorldScript.AVATAR_ACCELERATION_SECONDS)*60.0)
	for step in range(arch_walk_frames): await physics_frame
	Input.action_release("move_down")
	await create_timer(0.2).timeout
	park_world.occlusion_controller.refresh_visibility()
	assert(park_world.player.position.z > -10.2, "the player can walk through the arch's open center passage")
	assert(not park_world.occlusion_controller._active_group_ids.has(arch_group_id), "the arch cutaway clears after the player walks beyond it")
	park_world.occlusion_controller._process(0.0)
	assert(arch_title.visible and arch_title.modulate == arch_title_modulate, "the arch title restores its original visibility and modulation after exit")
	park_world.apply_settings({"reduced_motion": false})
	var kiosk_mesh := first_kiosk_body.get_parent() as GeometryInstance3D
	var kiosk_material: Material = kiosk_mesh.material_override
	var kiosk_tint_key := "tint" if kiosk_material.shader == CoastalMaterialShader else "occluder_tint"
	var kiosk_tint: Color = kiosk_material.get_shader_parameter(kiosk_tint_key)
	park_world.set_night(true)
	assert(kiosk_mesh.material_override == kiosk_material and kiosk_mesh.material_override.get_shader_parameter(kiosk_tint_key) == kiosk_tint, "night lighting preserves architecture material and tint")
	park_world.set_night(false)
	var hero_material := park_world.avatar.material_override as ShaderMaterial
	var appearance: Dictionary = park_world.avatar_appearance.duplicate(true)
	appearance["face"] = "smiling"
	park_world.set_avatar_look(appearance, park_world.avatar_equipped.duplicate(true))
	assert(hero_material.get_shader_parameter("texture_albedo") == park_world.avatar.texture, "avatar pose texture remains synchronized with the living-sprite shader")
	assert(park_world.player.collision_layer == player_collision_before, "night changes and cutaway setup leave the player body collision unchanged")
	park_world.apply_settings({"reduced_motion": true})
	assert(park_world.occlusion_controller.reduced_motion, "world reduced-motion settings reach the occlusion controller")
	park_world.apply_settings({"reduced_motion": false})
	park_world.player.position = Vector3(0, 0.4, -15)
	park_world.camera.position = park_world.player.position + Vector3(0, 15.5, 25)
	park_world.camera.look_at(park_world.player.position + Vector3(0, 1, -3))
	await physics_frame
	park_world.occlusion_controller.refresh_visibility()
	park_world.occlusion_controller._process(0.2)
	assert(not arch_title.visible, "the title is hidden again before controller release")
	park_world.occlusion_controller.release()
	assert(arch_title.visible and arch_title.modulate == arch_title_modulate, "controller release restores the title's exact prior visibility and modulation")
	assert(arch_surface.material_override == arch_coastal_original and arch_coastal_original != arch_coastal_material, "controller release restores the registered arch's exact original material")
	assert(arch_surface.material_override.get_shader_parameter("occlusion_cutaway_weight") == null, "release leaves no active cutaway on the restored coastal surface")
	park_world.queue_free()
	await process_frame
	await _test_billboard_reveal()
	print("PASS: occlusion controller runtime checks")
	quit(0)


## A camera-facing 2.4m billboard: the opening must cover its whole canvas, and
## a blocker in front of only the head must still open the view.
func _test_billboard_reveal() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var controller = OcclusionControllerScript.new()
	world.add_child(controller)
	var player := CharacterBody3D.new()
	world.add_child(player)
	var sprite := Sprite3D.new()
	var image := Image.create(50, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = 0.04
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position.y = 1.2
	player.add_child(sprite)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	world.add_child(camera)
	camera.position = Vector3(0.0, 2.0, 12.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.current = true
	controller.configure(player, camera)
	controller.set_reveal_visual(sprite)
	await process_frame
	controller._process(0.0)
	var centre := sprite.global_position
	var screen_height := camera.unproject_position(centre + camera.global_basis.y * 1.2).distance_to(camera.unproject_position(centre - camera.global_basis.y * 1.2))
	var screen_width := camera.unproject_position(centre + camera.global_basis.x * 1.0).distance_to(camera.unproject_position(centre - camera.global_basis.x * 1.0))
	var radius := float(controller.statistics().radius_px)
	assert(is_equal_approx(radius, OcclusionControllerScript.visual_reveal_radius_px(Vector2(screen_width, screen_height), Vector2(1280, 720))), "a configured billboard sizes the opening from its drawn canvas")
	assert(radius >= Vector2(screen_width, screen_height).length() * 0.5 + 2.5, "the opening contains the whole billboard canvas plus its soft edge")
	assert(Vector2(controller.statistics().center_px).distance_to(camera.unproject_position(centre)) < 0.5, "the opening is centred on the billboard, not a fixed 1m body point")
	assert(radius > OcclusionControllerScript.reveal_radius_px(camera.unproject_position(Vector3.ZERO).distance_to(camera.unproject_position(Vector3.UP * 1.9)), Vector2(1280, 720)), "the drawn 2.4m billboard needs a larger opening than the legacy 1.9m estimate")
	# Blocker covering only the head line.
	var head_point := centre + camera.global_basis.y.normalized() * 1.2 * OcclusionControllerScript.HEAD_SAMPLE_FRACTION
	var head_screen := camera.unproject_position(head_point)
	var head_origin := camera.project_ray_origin(head_screen)
	var head_direction := camera.project_ray_normal(head_screen).normalized()
	var head_blocker := _add_registered_building(world, controller, head_origin + head_direction * head_direction.dot(head_point - head_origin) * 0.5, Vector3(1.0, 0.3, 0.3), Color("#c9a77a"))
	await physics_frame
	controller.refresh_visibility()
	assert(controller.statistics().active, "a building in front of only the head opens the view")
	controller.set_reveal_visual(null)
	controller.refresh_visibility()
	assert(not controller.statistics().active, "counter-example: the legacy single 1m ray misses a head-only blocker")
	head_blocker.body.queue_free()
	controller.release()
	viewport.queue_free()
	await process_frame


func _path_midpoint(camera: Camera3D, player: Node3D) -> Vector3:
	var target := player.global_position + Vector3.UP
	var screen := camera.unproject_position(target)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen).normalized()
	var length := direction.dot(target - origin)
	return origin + direction * length * 0.5


func _path_fraction(camera: Camera3D, player: Node3D, fraction: float) -> Vector3:
	var target := player.global_position + Vector3.UP
	var screen := camera.unproject_position(target)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen).normalized()
	var length := direction.dot(target - origin)
	return origin + direction * length * fraction


func _add_box_collider(body: StaticBody3D, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _add_registered_building(world: Node3D, controller, position: Vector3, size: Vector3, color: Color) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = position
	world.add_child(body)
	_add_box_collider(body, size)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var source_material := StandardMaterial3D.new()
	source_material.albedo_color = color
	source_material.roughness = 0.9
	mesh.material_override = source_material
	body.add_child(mesh)
	controller.begin_building()
	controller.register_geometry(mesh, source_material)
	var group_id_before := int(controller._next_group_id)
	assert(controller.finish_building(body), "eligible blocker is registered with its visible mesh")
	return {"id": group_id_before, "body": body, "mesh": mesh, "source_material": source_material}
