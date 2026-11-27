extends Node3D
## Shared "living air" layer for every region: drifting cloud shade, air motes
## that change with the time of day, and small animals that react to the
## player. A region only supplies a data profile (see AmbienceProfiles).
## All nodes and materials are created once in configure(); phase and settings
## changes only toggle and retune them.

const Profiles = preload("res://game/world/ambience_profiles.gd")
const Sprites = preload("res://game/world/ambience_sprites.gd")
const Critters = preload("res://game/world/ambience_critters.gd")
const CLOUD_SHADER := "res://game/world/cloud_shadow.gdshader"
const CRITTER_SHADER := "res://game/world/ambience_critter.gdshader"
const CLOUD_WIND := Vector2(0.62, 0.34)
const CLOUD_MAX_SLOPE := 1.2
const SHADOW_LIFT := 0.025
## Shared by the lawn and foliage shaders (see wind.gdshaderinc).
const WIND_TIME := &"snapland_wind_time"
const WIND_WALKER := &"snapland_walker"
## Parked far below the world so nothing is brushed when no walker is reported.
const NO_WALKER := Vector3(0.0, -1000.0, 0.0)

var critters: Critters
var cloud: MeshInstance3D
var emitters: Array[CPUParticles3D] = []

var _world: Node3D
var _profile: Dictionary = {}
var _phase := ""
var _reduced_motion := false
var _wind_time := 0.0
var _cloud_shade_enabled := true
var _air_particles_enabled := true
var _cloud_material: ShaderMaterial
var _cloud_drift := Vector2.ZERO
var _emitter_specs: Array[Dictionary] = []
var _critter_batch: MultiMesh
var _shadow_batch: MultiMesh


func configure(world: Node3D, region_profile: Dictionary) -> void:
	_world = world
	_profile = region_profile
	_build_cloud()
	_build_critters()
	# Particle systems only exist on a real renderer, like the market rain.
	if DisplayServer.get_name() != "headless":
		for spec: Dictionary in _profile.get("particles", []):
			_build_emitter(spec)
	if Profiles.particle_total(_profile) > Profiles.PARTICLE_BUDGET:
		push_warning("Ambience profile exceeds the %d particle budget." % Profiles.PARTICLE_BUDGET)


func set_phase(phase: String) -> void:
	_phase = phase
	if critters != null:
		critters.set_phase(phase)
	_sync()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if critters != null:
		critters.set_reduced_motion(value)
	_sync()


## Picture quality can drop the cloud shade pass and the air particles.
func set_quality(cloud_shade: bool, air_particles: bool) -> void:
	_cloud_shade_enabled = cloud_shade
	_air_particles_enabled = air_particles
	_sync()


func particle_total() -> int:
	return Profiles.particle_total(_profile)


func cloud_strength() -> float:
	return float(_profile.get("clouds", 0.0)) * float(Profiles.CLOUD_PHASE_STRENGTH.get(_phase, 0.0))


func _process(delta: float) -> void:
	advance(delta)


## One simulation and presentation step; tests drive this directly.
func advance(delta: float) -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_world.player):
		return
	var focus: Vector3 = _world.player.global_position
	# Wind stands still and nothing reacts to the walker under reduced motion.
	RenderingServer.global_shader_parameter_set(WIND_WALKER, NO_WALKER if _reduced_motion else focus)
	if not _reduced_motion:
		_wind_time += delta
		RenderingServer.global_shader_parameter_set(WIND_TIME, _wind_time)
		if cloud != null and cloud.visible:
			_cloud_drift += CLOUD_WIND * delta
			_cloud_material.set_shader_parameter("drift", _cloud_drift)
		for index in range(emitters.size()):
			if _emitter_specs[index].follows:
				emitters[index].position = focus + Vector3(0, float(_emitter_specs[index].lift), 0)
	if critters != null and critters.count > 0:
		critters.advance(delta, focus)
		_write_critters()


func _sync() -> void:
	if cloud != null:
		var strength := cloud_strength()
		cloud.visible = strength > 0.0 and _cloud_shade_enabled
		_cloud_material.set_shader_parameter("strength", strength)
		if is_instance_valid(_world) and is_instance_valid(_world.sun):
			var to_sun: Vector3 = _world.sun.global_basis.z
			var slope := Vector2(to_sun.x, to_sun.z) / maxf(to_sun.y, 0.05)
			_cloud_material.set_shader_parameter("sun_slope", slope.limit_length(CLOUD_MAX_SLOPE))
	for index in range(emitters.size()):
		var active: bool = _air_particles_enabled and not _reduced_motion and (_emitter_specs[index].phases as Array).has(_phase)
		emitters[index].visible = active
		emitters[index].emitting = active
	if critters != null and critters.count > 0 and is_inside_tree():
		_write_critters()


func _build_cloud() -> void:
	if float(_profile.get("clouds", 0.0)) <= 0.0:
		return
	if not ResourceLoader.exists(CLOUD_SHADER):
		push_warning("Cloud shade shader is missing; the region keeps flat daylight.")
		return
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = load(CLOUD_SHADER)
	# After every other transparent surface, so sprites and labels share the shade.
	_cloud_material.render_priority = RenderingServer.MATERIAL_RENDER_PRIORITY_MAX
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	# The quad is placed in clip space by its shader; it must never be culled.
	quad.custom_aabb = AABB(Vector3.ONE * -4096.0, Vector3.ONE * 8192.0)
	cloud = MeshInstance3D.new()
	cloud.name = "CloudShade"
	cloud.mesh = quad
	cloud.material_override = _cloud_material
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.visible = false
	add_child(cloud)


func _build_critters() -> void:
	critters = Critters.new()
	critters.setup(_profile, _world)
	if critters.count == 0:
		return
	if not ResourceLoader.exists(CRITTER_SHADER):
		push_warning("Critter shader is missing; ambience animals are not shown.")
		critters = null
		return
	var material := ShaderMaterial.new()
	material.shader = load(CRITTER_SHADER)
	material.set_shader_parameter("atlas", Sprites.critter_atlas())
	material.set_shader_parameter("cell_uv", Sprites.cell_uv())
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_critter_batch = _batch(quad, true)
	for index in range(critters.count):
		_critter_batch.set_instance_color(index, critters.tint[index])
	_batch_instance("Critters", _critter_batch, material)
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_texture = Sprites.shadow_blob()
	shade.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var blob := PlaneMesh.new()
	blob.size = Vector2.ONE
	_shadow_batch = _batch(blob, false)
	_batch_instance("CritterShadows", _shadow_batch, shade)


func _batch(mesh: Mesh, per_instance_data: bool) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = per_instance_data
	batch.use_custom_data = per_instance_data
	batch.mesh = mesh
	batch.instance_count = critters.count
	# Animals roam the whole region; a fixed box avoids refitting bounds every frame.
	batch.custom_aabb = AABB(Vector3(-160, -8, -160), Vector3(320, 48, 320))
	return batch


func _batch_instance(label: String, batch: MultiMesh, material: Material) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _write_critters() -> void:
	var facing := Basis.IDENTITY
	if is_instance_valid(_world.camera):
		facing = _world.camera.global_basis
	for index in range(critters.count):
		var shown := critters.visible_scale[index]
		var extent := critters.size[index] * shown
		var at := critters.position[index]
		_critter_batch.set_instance_transform(index, Transform3D(facing.x * extent.x, facing.y * extent.y, facing.z, at + facing.y * (extent.y * 0.5)))
		_critter_batch.set_instance_custom_data(index, Color(critters.frame[index], critters.sprite_row[index], critters.mirrored[index], 0.0))
		var floor_y := critters.ground[index]
		# Higher animals cast a smaller, fainter-reading blob.
		var width := critters.shadow_width[index] * shown * clampf(1.0 - (at.y - floor_y) * 0.07, 0.5, 1.0)
		_shadow_batch.set_instance_transform(index, Transform3D(Vector3(width, 0, 0), Vector3.UP, Vector3(0, 0, width * 0.62), Vector3(at.x, floor_y + SHADOW_LIFT, at.z)))


func _build_emitter(spec: Dictionary) -> void:
	var kind := String(spec.get("kind", ""))
	if not Profiles.PARTICLE_KINDS.has(kind):
		push_warning("Ambience particle kind '%s' is not defined; the emitter was skipped." % kind)
		return
	var look: Dictionary = Profiles.PARTICLE_KINDS[kind]
	var glyph := String(look.glyph)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if bool(look.get("additive", false)) else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = Sprites.mote(glyph)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	var tone: Color = look.color
	var energy := float(look.get("energy", 1.0))
	material.albedo_color = Color(tone.r * energy, tone.g * energy, tone.b * energy, tone.a)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (Sprites.mote_pixels(glyph) / Profiles.PIXELS_PER_METRE * float(look.get("scale", 1.0)))
	quad.material = material
	var emitter := CPUParticles3D.new()
	emitter.name = "Air%s" % kind.capitalize()
	emitter.mesh = quad
	emitter.amount = int(spec.get("amount", 16))
	emitter.lifetime = float(look.life)
	emitter.preprocess = emitter.lifetime
	emitter.randomness = 1.0
	emitter.lifetime_randomness = 0.35
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = spec.get("box", look.box)
	emitter.direction = (look.direction as Vector3).normalized()
	emitter.spread = float(look.spread)
	var speed: Vector2 = look.speed
	emitter.initial_velocity_min = speed.x
	emitter.initial_velocity_max = speed.y
	emitter.gravity = look.force
	emitter.scale_amount_min = 0.8
	emitter.scale_amount_max = 1.25
	if look.has("spin"):
		emitter.angle_max = 360.0
		emitter.angular_velocity_min = -float(look.spin)
		emitter.angular_velocity_max = float(look.spin)
	if look.has("scale_curve"):
		var curve := Curve.new()
		for point: Vector2 in Profiles.SCALE_CURVES[look.scale_curve]:
			curve.add_point(point)
		emitter.scale_amount_curve = curve
	var ramp := Gradient.new()
	var stops: Array = Profiles.RAMPS[look.get("ramp", "fade")]
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Vector2 in stops:
		offsets.append(stop.x)
		colors.append(Color(1, 1, 1, stop.y))
	ramp.offsets = offsets
	ramp.colors = colors
	emitter.color_ramp = ramp
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visible = false
	emitter.emitting = false
	if spec.has("at"):
		emitter.position = spec.at
	add_child(emitter)
	emitters.append(emitter)
	_emitter_specs.append({"phases": spec.get("phases", Profiles.ALWAYS), "follows": not spec.has("at"), "lift": float(look.get("lift", 0.0))})
