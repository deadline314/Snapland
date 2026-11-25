extends Node3D
## The physical angle of the blades is the source of the bed illumination and map pin.

const Pattern = preload("res://game/world/garden_sun_pattern.gdshader")
const BED_X := [-2.75, 0.0, 2.75]
const BED_Z := 1.15
const BED_SURFACE_Y := 0.49
const THROW := 3.2
const TRANSITION := 0.36
const LABELS := ["西植床 · 菱葉", "中植床 · 圓葉", "東植床 · 扇葉"]
const GLASS_IRON := Color("#344742")
const RIM := Color("#8ba99b")
const WARM_BRASS := Color("#c4a474")

var detent := 0
var angle := 0.0
var _from_angle := 0.0
var _elapsed := TRANSITION
var _gain := 0.58
var _slats: Array[MeshInstance3D] = []
var _plants: Array[StandardMaterial3D] = []
var _patch: MeshInstance3D
var _pattern: ShaderMaterial
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


func set_light_gain(gain: float) -> void:
	if gain != _gain:
		_gain = gain
		_sync_illumination()


func _target_angle() -> float:
	return atan(BED_X[detent] / THROW)


func _sync_illumination() -> void:
	var x := tan(angle) * THROW
	_patch.position.x = x
	_pattern.set_shader_parameter("yaw", angle)
	_pattern.set_shader_parameter("gain", _gain)
	_light.position.x = x
	_light.light_energy = 0.72 * _gain
	_lever.rotation.z = angle
	for slat in _slats:
		slat.rotation.z = angle
	for index in _plants.size():
		var glow := (1.0 - smoothstep(0.15, 1.17, absf(x - BED_X[index]))) * _gain
		_plants[index].emission_energy_multiplier = glow * 0.90


func _build_window() -> void:
	var frame := _paint(GLASS_IRON)
	var trim := _paint(RIM)
	var blade := BoxMesh.new()
	blade.size = Vector3(2.64, 0.078, 0.24)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.49, 1.38, -0.16), Vector3(0.12, 2.38, 0.14), frame)
		_box(Vector3(side * 1.49, 2.56, 0.47), Vector3(0.12, 0.16, 1.44), frame)
	_box(Vector3(0, 2.54, -0.24), Vector3(3.10, 0.20, 0.17), frame)
	_box(Vector3(0, 2.54, 1.20), Vector3(3.10, 0.15, 0.12), trim)
	for index in range(7):
		var position := Vector3(0, 2.52, -0.14 + 0.22 * float(index))
		var slat := _mesh(blade, position, trim)
		slat.name = "GardenSlat_%d" % index
		_slats.append(slat)
	var rays := PlaneMesh.new()
	rays.size = Vector2(2.22, 1.32)
	_pattern = ShaderMaterial.new()
	_pattern.shader = Pattern
	_patch = _mesh(rays, Vector3(0, BED_SURFACE_Y + 0.012, BED_Z), _pattern)
	_patch.name = "GardenSunPatch"
	_light = OmniLight3D.new()
	_light.name = "GardenSunPool"
	_light.position = Vector3(0, 1.68, BED_Z)
	_light.light_color = Color("#ffdf8e")
	_light.omni_range = 2.72
	_light.omni_attenuation = 1.17
	_light.shadow_enabled = false
	add_child(_light)


func _build_beds() -> void:
	var rim := _paint(Color("#758174"))
	var soil := _paint(Color("#4d5040"))
	var nameplate := _paint(Color("#2b453d"))
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radial_segments = 9
	leaf_mesh.rings = 4
	var tones := [Color("#5b916b"), Color("#7e9f62"), Color("#658a7d")]
	for index in BED_X.size():
		var at := Vector3(BED_X[index], 0, BED_Z)
		var plant := _paint(tones[index])
		plant.emission_enabled = true
		plant.emission = Color("#b7d36d")
		_plants.append(plant)
		_box(at + Vector3(0, 0.319, 0), Vector3(2.18, 0.238, 1.33), rim, true)
		_box(at + Vector3(0, BED_SURFACE_Y - 0.031, 0), Vector3(1.97, 0.062, 1.13), soil)
		_box(at + Vector3(0, 0.352, 0.687), Vector3(0.94, 0.21, 0.045), nameplate)
		_label(LABELS[index].get_slice(" · ", 1), at + Vector3(0, 0.356, 0.714), 14)
		_batch_bed_leaves(at, index, leaf_mesh, plant)


func _batch_bed_leaves(at: Vector3, bed: int, leaf_mesh: SphereMesh, plant: StandardMaterial3D) -> void:
	var petals := 3 + bed
	var shapes := MultiMesh.new()
	shapes.transform_format = MultiMesh.TRANSFORM_3D
	shapes.mesh = leaf_mesh
	shapes.instance_count = 3 * petals
	var leaf_size := Vector3(0.18 if bed != 1 else 0.26, 0.059, 0.39 if bed != 1 else 0.26)
	var slot := 0
	for seed in [-0.66, 0.0, 0.66]:
		for petal in range(petals):
			var turn := float(petal) * TAU / float(petals)
			var local := Vector3(cos(turn), 0, sin(turn))
			var offset := at + Vector3(seed, BED_SURFACE_Y + 0.10, 0) + local * 0.122
			var orientation := Basis.from_euler(Vector3(-0.35 - float(bed) * 0.08, -turn + PI * 0.5, 0))
			shapes.set_instance_transform(slot, Transform3D(orientation.scaled_local(leaf_size), offset))
			slot += 1
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "GardenBedLeaves_%d" % bed
	leaves.multimesh = shapes
	leaves.material_override = plant
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leaves)


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
