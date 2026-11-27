extends Node3D
## The physical angle of the blades is the source of the bed illumination and map pin.
## The lit bed shows it four ways: barred light on the soil and the floor, a dusty
## shaft from the blades, glowing leaves, and flowers that open only in the light.

const Kit := preload("res://game/world/scenery_kit.gd")
const Props := preload("res://game/world/garden_props.gd")
const Pattern = preload("res://game/world/garden_sun_pattern.gdshader")
const Shaft = preload("res://game/world/garden_light_shaft.gdshader")
const Paving = preload("res://game/world/garden_paving.gdshader")
const Plant = preload("res://game/world/garden_plant.gdshader")
const BED_X := [-2.75, 0.0, 2.75]
const BED_Z := 1.15
const BED_SURFACE_Y := 0.49
const THROW := 3.2
const TRANSITION := 0.36
const LABELS := ["西植床 · 菱葉", "中植床 · 圓葉", "東植床 · 扇葉"]
const GLASS_IRON := Color("#344742")
const RIM := Color("#8ba99b")
const WARM_BRASS := Color("#c4a474")
const BLADE_Y := 2.52
const BRICK_STYLE := 3
const ROCK_STYLE := 5

var detent := 0
var angle := 0.0
var _from_angle := 0.0
var _elapsed := TRANSITION
var _gain := 0.58
var _slats: Array[MeshInstance3D] = []
var _plants: Array[StandardMaterial3D] = []
var _blooms: Array[ShaderMaterial] = []
var _patch: MeshInstance3D
var _pattern: ShaderMaterial
var _spill: ShaderMaterial
var _shaft: ShaderMaterial
var _light: OmniLight3D
var _lever: MeshInstance3D
var _caption: Label3D


func _ready() -> void:
	_build_window()
	_build_beds()
	_build_console()
	settle()


func choose_next(reduced_motion: bool) -> void:
	detent = (detent + 1) % BED_X.size()
	_from_angle = angle
	_elapsed = 0.0
	if reduced_motion:
		settle()
	_caption.text = LABELS[detent]


func moving() -> bool:
	return _elapsed < TRANSITION


func advance(delta: float) -> void:
	_elapsed = minf(TRANSITION, _elapsed + delta)
	var progress := smoothstep(0.0, 1.0, _elapsed / TRANSITION)
	angle = lerpf(_from_angle, _target_angle(), progress)
	_sync_illumination()


func settle() -> void:
	_elapsed = TRANSITION
	angle = _target_angle()
	_sync_illumination()


func bed_centers() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x in BED_X:
		result.append(to_global(Vector3(x, BED_SURFACE_Y, BED_Z)))
	return result


func patch_center() -> Vector3:
	return _patch.global_position


func lit_bed() -> int:
	var x := _patch.position.x
	var index := clampi(roundi(x / BED_X[-1]) + 1, 0, BED_X.size() - 1)
	return index if absf(x - BED_X[index]) < 0.91 else -1


## How open the flowers of a bed are, from 0 (closed buds) to 1.
func bloom(bed: int) -> float:
	return float(_blooms[bed].get_shader_parameter("bloom"))


func set_light_gain(gain: float) -> void:
	if gain != _gain:
		_gain = gain
		_sync_illumination()


## Sunlight by day, moonlight at night.
func set_light_color(color: Color) -> void:
	_pattern.set_shader_parameter("light_color", color)
	_spill.set_shader_parameter("light_color", color)
	_shaft.set_shader_parameter("shaft_color", color)
	_light.light_color = color


## Still dust for reduced motion.
func set_motion(moving_dust: bool) -> void:
	_shaft.set_shader_parameter("motion", 1.0 if moving_dust else 0.0)


func _target_angle() -> float:
	return atan(BED_X[detent] / THROW)


func _sync_illumination() -> void:
	var x := tan(angle) * THROW
	_patch.position.x = x
	_pattern.set_shader_parameter("yaw", angle)
	_pattern.set_shader_parameter("gain", _gain)
	_spill.set_shader_parameter("yaw", angle)
	_spill.set_shader_parameter("gain", _gain)
	_shaft.set_shader_parameter("foot_shift", x)
	_shaft.set_shader_parameter("intensity", 0.8 * _gain)
	_light.position.x = x
	_light.light_energy = 1.5 * _gain
	_lever.rotation.z = angle
	for slat in _slats:
		slat.rotation.z = angle
	for index in _plants.size():
		var lit := 1.0 - smoothstep(0.15, 1.17, absf(x - BED_X[index]))
		_plants[index].emission_energy_multiplier = lit * _gain * 0.90
		_blooms[index].set_shader_parameter("bloom", lit)


func _build_window() -> void:
	# Mirror-glass blades: pale and half clear, so the beds show through them.
	var trim := _paint(Color(RIM.lightened(0.25), 0.5))
	trim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trim.roughness = 0.25
	# The iron gantry never moves, so it is one sculpted mesh.
	var frame := Kit.Sculpt.new()
	for side: float in [-1.0, 1.0]:
		frame.box(Vector3(side * 1.49, 1.38, -0.16), Vector3(0.12, 2.38, 0.14), GLASS_IRON)
		frame.box(Vector3(side * 1.49, 0.27, -0.16), Vector3(0.26, 0.14, 0.28), GLASS_IRON.lightened(0.12))
		frame.box(Vector3(side * 1.49, 2.56, 0.47), Vector3(0.12, 0.16, 1.44), GLASS_IRON)
		frame.box(Vector3(side * 1.3, 2.25, -0.16), Vector3(0.5, 0.06, 0.08), GLASS_IRON.lightened(0.1), Basis(Vector3.BACK, side * -0.8))
		frame.tube(Vector3(side * 1.49, 2.72, -0.16), 0.09, 0.0, 0.2, WARM_BRASS, 5)
		frame.tube(Vector3(side * 1.49, 2.7, 1.16), 0.07, 0.0, 0.16, WARM_BRASS, 5)
	frame.box(Vector3(0, 2.54, -0.24), Vector3(3.10, 0.20, 0.17), GLASS_IRON)
	frame.box(Vector3(0, 2.54, 1.20), Vector3(3.10, 0.15, 0.12), RIM.darkened(0.25))
	var gantry := _mesh(frame.mesh(), Vector3.ZERO, _vertex_paint())
	gantry.name = "GardenSunGantry"
	gantry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var blade := BoxMesh.new()
	blade.size = Vector3(2.64, 0.078, 0.24)
	for index in range(7):
		var slat := _mesh(blade, Vector3(0, BLADE_Y, -0.14 + 0.22 * float(index)), trim)
		slat.name = "GardenSlat_%d" % index
		_slats.append(slat)
	var rays := PlaneMesh.new()
	rays.size = Vector2(2.22, 1.32)
	_pattern = ShaderMaterial.new()
	_pattern.shader = Pattern
	_patch = _mesh(rays, Vector3(0, BED_SURFACE_Y + 0.012, BED_Z), _pattern)
	_patch.name = "GardenSunPatch"
	# The same bars spill past the bed onto the paving; the pool rides with the patch.
	var pool := PlaneMesh.new()
	pool.size = Vector2(4.2, 3.4)
	_spill = ShaderMaterial.new()
	_spill.shader = Pattern
	_spill.set_shader_parameter("spill", true)
	var spill := _mesh(pool, Vector3(0, 0.215 - (BED_SURFACE_Y + 0.012), 0.25), _spill)
	remove_child(spill)
	_patch.add_child(spill)
	# A shaft from the blades to the bed; its foot follows the patch.
	_shaft = ShaderMaterial.new()
	_shaft.shader = Shaft
	_shaft.set_shader_parameter("bars", 7.0)
	var beam := SurfaceTool.new()
	beam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [Vector3(-1.15, BLADE_Y - 0.08, 0.5), Vector3(1.15, BLADE_Y - 0.08, 0.5), Vector3(1.05, BED_SURFACE_Y + 0.1, BED_Z), Vector3(-1.05, BED_SURFACE_Y + 0.1, BED_Z)]
	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		beam.set_uv(uvs[index])
		beam.add_vertex(corners[index])
	_mesh(beam.commit(), Vector3.ZERO, _shaft).name = "GardenSunShaft"
	_light = OmniLight3D.new()
	_light.name = "GardenSunPool"
	_light.position = Vector3(0, 1.68, BED_Z)
	_light.light_color = Color("#ffdf8e")
	_light.omni_range = 3.2
	_light.omni_attenuation = 1.17
	_light.shadow_enabled = false
	add_child(_light)


func _build_beds() -> void:
	var rim := _textured(Color("#a9674c"), BRICK_STYLE)
	var soil := _textured(Color("#4d4032"), ROCK_STYLE)
	var trim := Kit.Sculpt.new()
	var tones := [Color("#5b916b"), Color("#7e9f62"), Color("#658a7d")]
	var heads := [Color("#f6e27a"), Color("#f2a7b8"), Color("#b79be0")]
	for index in BED_X.size():
		var at := Vector3(BED_X[index], 0, BED_Z)
		var plant := _vertex_paint()
		plant.emission_enabled = true
		plant.emission = Color("#b7d36d")
		_plants.append(plant)
		_box(at + Vector3(0, 0.319, 0), Vector3(2.18, 0.238, 1.33), rim, true)
		_box(at + Vector3(0, BED_SURFACE_Y - 0.031, 0), Vector3(1.97, 0.062, 1.13), soil)
		# Stone coping and an enamel nameplate on the brick.
		for edge: float in [-1.0, 1.0]:
			trim.box(at + Vector3(0, 0.455, edge * 0.63), Vector3(2.26, 0.05, 0.12), Props.STONE)
			trim.box(at + Vector3(edge * 1.07, 0.455, 0), Vector3(0.12, 0.05, 1.38), Props.STONE.lightened(0.06))
		trim.box(at + Vector3(0, 0.352, 0.687), Vector3(0.94, 0.21, 0.045), Color("#2b453d"))
		trim.box(at + Vector3(0, 0.352, 0.69), Vector3(1.0, 0.25, 0.03), WARM_BRASS)
		_label(LABELS[index].get_slice(" · ", 1), at + Vector3(0, 0.356, 0.714), 14)
		_batch_bed(at, index, _leaf_mesh(index, tones[index]), plant, heads[index])
	_mesh(trim.mesh(), Vector3.ZERO, _vertex_paint()).name = "GardenBedTrim"


## One crop per bed: diamond leaves, round leaves, fan leaves.
func _leaf_mesh(bed: int, tone: Color) -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	for blade in range(5):
		var around := Basis(Vector3.UP, TAU / 5.0 * float(blade))
		var shade := tone if blade % 2 == 0 else tone.lightened(0.18)
		match bed:
			0:
				Props.leaf(sculpt, Vector3.ZERO, around * Vector3(0.3, 0.24, 0), 0.24, shade)
			1:
				sculpt.box(around * Vector3(0.09, 0.12, 0), Vector3(0.025, 0.24, 0.025), tone.darkened(0.2), around * Basis(Vector3.BACK, -0.5))
				sculpt.tube(around * Vector3(0.2, 0.24, 0), 0.13, 0.13, 0.02, shade, 6, around * Basis(Vector3.BACK, -0.35))
			_:
				for rib: float in [-0.3, 0.0, 0.3]:
					var fan := around * Basis(Vector3.UP, rib)
					Props.leaf(sculpt, Vector3.ZERO, fan * Vector3(0.26, 0.3, 0), 0.1, shade)
	return sculpt.mesh()


func _batch_bed(at: Vector3, bed: int, leaf_mesh: Mesh, plant: StandardMaterial3D, head: Color) -> void:
	var leaves := MultiMesh.new()
	leaves.transform_format = MultiMesh.TRANSFORM_3D
	leaves.mesh = leaf_mesh
	leaves.instance_count = 8
	var flowers := MultiMesh.new()
	flowers.transform_format = MultiMesh.TRANSFORM_3D
	flowers.use_colors = true
	flowers.mesh = Props.flower_mesh()
	flowers.instance_count = 8
	for slot in range(8):
		var offset := Vector3(-0.72 + 0.48 * float(slot % 4), BED_SURFACE_Y, -0.24 + 0.48 * float(slot / 4))
		leaves.set_instance_transform(slot, Transform3D(Basis(Vector3.UP, float(slot) * 1.3 + float(bed)).scaled(Vector3.ONE * (0.9 + 0.18 * float(slot % 3))), at + offset))
		flowers.set_instance_transform(slot, Transform3D(Basis(Vector3.UP, float(slot)).scaled(Vector3.ONE * 1.25), at + offset + Vector3(0.12, 0.0, 0.1 if slot % 2 == 0 else -0.1)))
		flowers.set_instance_color(slot, head.srgb_to_linear())
	var crop := MultiMeshInstance3D.new()
	crop.name = "GardenBedLeaves_%d" % bed
	crop.multimesh = leaves
	crop.material_override = plant
	crop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crop)
	var opening := ShaderMaterial.new()
	opening.shader = Plant
	opening.set_shader_parameter("flex", 0.05)
	_blooms.append(opening)
	var heads := MultiMeshInstance3D.new()
	heads.name = "GardenBedFlowers_%d" % bed
	heads.multimesh = flowers
	heads.material_override = opening
	heads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(heads)


func _build_console() -> void:
	var iron := _paint(GLASS_IRON)
	var brass := _paint(WARM_BRASS)
	_box(Vector3(0, 0.462, 2.70), Vector3(0.42, 0.524, 0.32), iron, true)
	_box(Vector3(0, 0.75, 2.70), Vector3(0.73, 0.10, 0.45), iron)
	_lever = _box(Vector3(0, 0.924, 2.67), Vector3(0.095, 0.34, 0.091), brass)
	_box(Vector3(0, 1.12, 2.70), Vector3(0.83, 0.25, 0.066), iron)
	_caption = _label(LABELS[0], Vector3(0, 1.12, 2.744), 18)
	_caption.name = "GardenLouverReadout"


func _label(text: String, at: Vector3, point_size: int) -> Label3D:
	var result := Label3D.new()
	result.position = at
	result.text = text
	result.font = ThemeDB.fallback_font
	result.font_size = point_size
	result.pixel_size = 0.0038
	result.modulate = Color("#e8eac8")
	result.outline_size = 1
	add_child(result)
	return result


func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.81
	return material


func _vertex_paint() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	return material


func _textured(tint: Color, style: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Paving
	material.set_shader_parameter("finish_tone", tint)
	material.set_shader_parameter("finish_style", style)
	return material


func _mesh(shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _box(at: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var instance := _mesh(shape, at, material)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		instance.add_child(body)
	return instance
