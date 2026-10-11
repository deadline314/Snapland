extends SceneTree

const ComponentAnimationScript = preload("res://game/world/component_animation.gd")
const LivingSpriteShader = preload("res://game/world/living_sprite.gdshader")
const ParkWorldScript = preload("res://game/world/park_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if save_path.is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	var world := Node3D.new()
	world.name = "AnimationTestWorld"
	root.add_child(world)
	var manager = ComponentAnimationScript.new()
	manager.name = "ComponentAnimation"
	world.add_child(manager)

	var marker := Node3D.new()
	marker.name = "Marker"
	marker.position = Vector3(0.0, 1.0, 0.0)
	world.add_child(marker)
	var flag := Node3D.new()
	flag.name = "Flag"
	world.add_child(flag)
	var shade := Node3D.new()
	shade.name = "LanternShade"
	world.add_child(shade)
	var imp := Sprite3D.new()
	imp.name = "Imp"
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_energy = 1.0
	world.add_child(lamp)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = LivingSpriteShader
	shader_material.set_shader_parameter("phase", 0.31)
	shader_material.set_shader_parameter("motion_kind", 1)
	imp.material_override = shader_material
	world.add_child(imp)
	assert(manager.register_component(marker, "marker", 0.23), "marker profile registers")
	assert(manager.register_component(flag, "flag", 0.13), "flag profile registers")
	assert(manager.register_component(shade, "soft_scale", 0.19), "decorative scale profile registers")
	assert(manager.register_component(imp, "character_imp", 0.31), "character idle profile registers")
	assert(manager.register_light(lamp, 0.41), "light registers")
	assert(not manager.register_component(marker, "awning"), "duplicate target is rejected")
	manager.register_shader(shader_material)
	manager.finish_registration()
	manager.finish_registration()

	var stats: Dictionary = manager.statistics()
	assert(stats.registration_count == 5, "statistics include registered active targets")
	assert(stats.by_profile.marker == 1 and stats.by_profile.character_imp == 1, "statistics count profiles")
	assert(stats.playing, "ambient AnimationPlayer starts after registration")
	assert(float(shader_material.get_shader_parameter("motion")) == 1.0, "shader registration starts motion enabled")

	var marker_baseline := Vector3(0.0, 1.0, 0.0)
	var actor_phase_baseline := 0.31
	var light_baseline := 1.0
	var start_marker := marker.position
	var start_flag := flag.rotation
	var start_scale := shade.scale
	await create_timer(0.30).timeout
	assert(not marker.position.is_equal_approx(start_marker), "marker position changes through a real AnimationPlayer value track")
	assert(not flag.rotation.is_equal_approx(start_flag), "flag rotation changes through an AnimationPlayer value track")
	assert(not shade.scale.is_equal_approx(start_scale), "decorative scale changes through an AnimationPlayer value track")
	assert(not is_equal_approx(float(shader_material.get_shader_parameter("phase")),actor_phase_baseline), "character idle track animates the shader phase seen by the actor")
	assert(not is_equal_approx(lamp.light_energy,light_baseline), "registered light energy varies gently over time")

	manager.set_reduced_motion(true)
	assert(marker.position.is_equal_approx(marker_baseline), "reduced motion immediately restores transform baseline")
	assert(shade.scale.is_equal_approx(Vector3.ONE), "reduced motion restores scale baseline")
	assert(is_equal_approx(float(shader_material.get_shader_parameter("phase")),actor_phase_baseline), "reduced motion restores the actor shader baseline")
	assert(is_equal_approx(lamp.light_energy,light_baseline), "reduced motion restores light energy baseline")
	assert(not manager.statistics().playing, "reduced motion stops the AnimationPlayer")
	assert(float(shader_material.get_shader_parameter("motion")) == 0.0, "reduced motion disables shader deformation")
	await create_timer(0.20).timeout
	assert(marker.position.is_equal_approx(marker_baseline), "reduced motion does not accumulate transform drift")

	manager.set_reduced_motion(false)
	assert(manager.statistics().playing, "restoring motion restarts the AnimationPlayer")
	await create_timer(0.30).timeout
	assert(not marker.position.is_equal_approx(marker_baseline), "restored motion resumes from its clean baseline")

	marker.queue_free()
	await process_frame
	assert(manager.statistics().registration_count == 4, "tree-exiting target is removed from active statistics")
	assert(manager.statistics().by_profile.marker == 0, "profile count decrements when a target leaves")
	await create_timer(0.20).timeout
	assert(manager.statistics().playing, "other animation tracks keep playing after one target leaves")

	manager.release()
	assert(float(shader_material.get_shader_parameter("motion")) == 1.0, "release restores shader motion state")
	world.queue_free()
	await process_frame

	var park_world = ParkWorldScript.new()
	root.add_child(park_world)
	var role_materials := {}
	for entry in park_world.character_sprites:
		var role_material := entry["sprite"].material_override as ShaderMaterial
		role_materials[str(entry["role"])] = role_material
	assert(role_materials.size() == 3, "all named NPCs have a distinct living-sprite material")
	assert(int(role_materials["ticket"].get_shader_parameter("idle_role")) == 1, "Ticket uses the lapel motion mask")
	assert(int(role_materials["imp"].get_shader_parameter("idle_role")) == 2, "Imp uses the ear and tail motion masks")
	assert(int(role_materials["announcer"].get_shader_parameter("idle_role")) == 3, "Announcer uses the head-nod motion mask")
	var ticket_rate := float(role_materials["ticket"].get_shader_parameter("breath_rate"))
	var imp_rate := float(role_materials["imp"].get_shader_parameter("breath_rate"))
	var announcer_rate := float(role_materials["announcer"].get_shader_parameter("breath_rate"))
	assert(ticket_rate != imp_rate and imp_rate != announcer_rate and ticket_rate != announcer_rate, "named NPC idle rhythms are configured differently")
	for material in role_materials.values():
		assert(float(material.get_shader_parameter("gesture_pixels")) > 0.0, "each named NPC has a visible local gesture amplitude")
	var hero_material := park_world.avatar.material_override as ShaderMaterial
	assert(int(hero_material.get_shader_parameter("idle_role")) == 0, "hero uses the hair-tip and hem motion masks")
	var shader_source := FileAccess.get_file_as_string("res://game/world/living_sprite.gdshader")
	assert(shader_source.contains("vec2 local_uv = clamp((UV - uv_rect.xy) / max(uv_rect.zw"), "atlas masks are evaluated in each character crop")
	assert(shader_source.contains("/ max(1.0, texture_size.x)"), "pixel-space horizontal gestures convert against the full atlas width")
	assert(shader_source.contains("/ max(1.0, texel_height)"), "pixel-space vertical gestures convert against the full atlas height")
	assert(not shader_source.contains("gesture_pixels * uv_rect.zw"), "atlas pixel motion is not incorrectly scaled by the crop a second time")
	assert(shader_source.contains("float chest_weight =") and shader_source.contains("float ticket_lapel =") and shader_source.contains("float imp_tail =") and shader_source.contains("float announcer_head ="), "actor breathing and role-specific masks are present in the fragment stage")
	assert(shader_source.contains("float hair_tips =") and shader_source.contains("float hem = smoothstep"), "hero hair and hem gestures avoid the anchored foot rows")
	var appearance: Dictionary = park_world.avatar_appearance.duplicate(true)
	appearance["face"] = "smiling"
	park_world.set_avatar_look(appearance,park_world.avatar_equipped.duplicate(true))
	assert(hero_material.get_shader_parameter("texture_albedo") == park_world.avatar.texture, "appearance changes refresh the shader texture uniform")
	park_world.play_action("wave")
	assert(hero_material.get_shader_parameter("texture_albedo") == park_world.avatar.texture, "action poses refresh the shader texture uniform")
	park_world.queue_free()
	await process_frame
	print("PASS: component animation runtime checks")
	quit(0)
