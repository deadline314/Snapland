extends SubViewport
## Small independent 3D scene. Re-render only when an input or visible heat band changes.

const Model = preload("res://game/minigames/skewer_grill_model.gd")
const FOOD_TEXTURE := "res://assets/minigames/skewer-grill-grain.webp"
const FOOD_CROSS_SECTION := [
	Vector2(-0.36, -0.5), Vector2(0.36, -0.5), Vector2(0.5, -0.36), Vector2(0.5, 0.36),
	Vector2(0.36, 0.5), Vector2(-0.36, 0.5), Vector2(-0.5, 0.36), Vector2(-0.5, -0.36),
]
const FOOD_ENDS := [-0.5, -0.36, 0.36, 0.5]
const FOOD_BEVEL := [0.70, 1.0, 0.98, 0.76]
const FACE_INK := {
	"raw": Color("#e89b88"),
	"warming": Color("#db8950"),
	"ready": Color("#b75d35"),
	"danger": Color("#80422d"),
	"charred": Color("#31282c"),
}
const LANE_X := [-3.12, 0.0, 3.12]
const INGREDIENT_COLORS := [Color("#e9cda1"), Color("#e3b9a5"), Color("#cfea9c")]
const SELECTED_COLOR := Color("#ffb553")
const FOOD_TINTS := {
	"scallion": Color("#cfea9c"),
	"king_oyster": Color("#e9cda1"),
	"sweet_pepper": Color("#e9967f"),
}

var _stage := Node3D.new()
var _unit_box := BoxMesh.new()
var _food_mesh: ArrayMesh
var _food_texture: Texture2D
var _ingredient_pieces: Array[Array] = []
var _skewers: Array[Node3D] = []
var _faces: Array[Array] = []
var _face_cues: Array[Array] = []
var _gloss := PackedInt32Array([-1, -1, -1])
var _markers: Array[MeshInstance3D] = []
var _coal: StandardMaterial3D
var _ember_light: OmniLight3D
var _metal: StandardMaterial3D
var _last_heat := -1
var _last_layout := -1
var _last_elapsed := -1.0
var _last_selected := -1
var _last_motion := false

func _ready() -> void:
	size = Vector2i(758, 290)
	msaa_3d = MSAA_2X
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = UPDATE_DISABLED
	gui_disable_input = true
	add_child(_stage)
	_build_lighting()
	_build_grill()
	_food_mesh = _build_food_mesh()
	if ResourceLoader.exists(FOOD_TEXTURE):
		_food_texture = load(FOOD_TEXTURE) as Texture2D
	for index in Model.SKEWER_COUNT:
		_build_skewer(index)
	render_target_update_mode = UPDATE_ONCE

func _build_lighting() -> void:
	var ambient := WorldEnvironment.new()
	ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_color = Color("#afdcd8")
	ambient.environment.ambient_light_energy = 0.50
	_stage.add_child(ambient)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 11.25
	_stage.add_child(camera)
	camera.position = Vector3(-1.05, 8.5, 10.6)
	camera.look_at(Vector3(0, 0, 0.09))
	camera.current = true
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe0b6")
	key.light_energy = 0.94
	key.rotation_degrees = Vector3(-56, -34, 0)
	_stage.add_child(key)
	_ember_light = OmniLight3D.new()
	_ember_light.position = Vector3(-0.65, 0.68, 0.53)
	_ember_light.light_color = Color("#ff823d")
	_ember_light.omni_range = 4.5
	_ember_light.omni_attenuation = 1.24
	_stage.add_child(_ember_light)

func _build_grill() -> void:
	var cast_iron := _material(Color("#332b2b"), 0.58, 0.54)
	var copper := _material(Color("#955941"), 0.47, 0.46)
	_metal = _material(Color("#656677"), 0.55, 0.63)
	_coal = _material(Color("#a6482c"), 0.86)
	_coal.emission_enabled = true
	_coal.emission = Color("#ed541d")
	_box(_stage, Vector3(0, -0.22, -0.38), Vector3(10.05, 0.46, 3.15), cast_iron)
	_box(_stage, Vector3(0, -0.02, -0.38), Vector3(9.67, 0.24, 2.78), _material(Color("#262024"), 0.9))
	for z in [-1.96, 1.17]:
		_box(_stage, Vector3(0, 0.08, z), Vector3(10.14, 0.30, 0.15), copper)
	for x in [-5.00, 5.00]:
		_box(_stage, Vector3(x, 0.08, -0.39), Vector3(0.24, 0.30, 3.23), copper)
		_box(_stage, Vector3(x, 0.15, -0.39), Vector3(0.34, 0.10, 1.18), cast_iron)
	for index in 40:
		var column := index % 10
		var row := floori(float(index) / 10.0)
		var x := (column - 4.5) * 0.93 + cos(float(index) * 4.3) * 0.24
		var z := float(row) * 0.44 - 1.14 + sin(float(index) * 3.83) * 0.13
		var material: StandardMaterial3D = _coal if index % 5 in [0, 1] else cast_iron
		var charcoal := _box(_stage, Vector3(x, 0.055 + sin(index) * 0.042, z), Vector3(0.49, 0.20, 0.32), material)
		charcoal.rotation_degrees = Vector3(18.0 * sin(index), fmod(25.0 + float(index) * 37.0, 90.0), 15.0 * cos(index))
	for row in 10:
		var z := -1.71 + float(row) * 0.30
		_box(_stage, Vector3(0, 0.25, z), Vector3(9.68, 0.07, 0.046), _metal)
	for lane in LANE_X:
		var tray := CylinderMesh.new()
		tray.top_radius = 1.0
		tray.bottom_radius = 0.91
		tray.height = 0.12
		tray.radial_segments = 20
		var rim := _mesh(_stage, tray, Vector3(lane, -0.08, 1.87), _material(Color("#547d70"), 0.34))
		rim.scale = Vector3(1.26, 1.0, 0.72)
		var inset := _mesh(_stage, tray, Vector3(lane, -0.055, 1.87), _material(Color("#2c4743"), 0.51))
		inset.scale = Vector3(1.11, 0.72, 0.59)
		_box(_stage, Vector3(lane, 0.22, -0.89), Vector3(2.44, 0.048, 0.11), _metal)
		var mark := _material(SELECTED_COLOR, 0.65)
		mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_markers.append(_box(_stage, Vector3(lane, 0.08, 2.42), Vector3(1.80, 0.045, 0.064), mark))

func _build_skewer(index: int) -> void:
	var skewer := Node3D.new()
	skewer.position = Vector3(LANE_X[index], 0.62, 1.69)
	_stage.add_child(skewer)
	_skewers.append(skewer)
	var bamboo := _material(Color("#e4b483"), 0.87)
	var rod := CylinderMesh.new()
	rod.height = 2.24
	rod.top_radius = 0.031
	rod.bottom_radius = 0.053
	rod.radial_segments = 7
	rod.rings = 1
	var handle := _mesh(skewer, rod, Vector3(0, 0, 0.18), bamboo)
	handle.rotation_degrees.x = 90
	var materials: Array[StandardMaterial3D] = []
	for face in Model.FACE_COUNT:
		var skin := _material(FACE_INK.raw, 0.53)
		skin.albedo_texture = _food_texture
		materials.append(skin)
	_faces.append(materials)
	_face_cues.append(["", "", "", ""])
	var pieces: Array[MeshInstance3D] = []
	for piece in 4:
		var z := -0.61 + float(piece) * 0.43
		var body := _mesh(skewer, _food_mesh, Vector3(0, 0, z), null)
		for face in Model.FACE_COUNT:
			body.set_surface_override_material(face, materials[face])
		body.set_surface_override_material(Model.FACE_COUNT, materials[0])
		body.rotation_degrees.z = 5.0 * sin(index + piece * 2.3)
		pieces.append(body)
	_ingredient_pieces.append(pieces)


func _build_food_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for face in Model.FACE_COUNT:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var first := face * 2
		for strip in range(FOOD_ENDS.size() - 1):
			for segment in 3:
				var edge := posmod(first + segment - 1, FOOD_CROSS_SECTION.size())
				var right := (edge + 1) % FOOD_CROSS_SECTION.size()
				var a: Vector2 = FOOD_CROSS_SECTION[edge]
				var b: Vector2 = FOOD_CROSS_SECTION[right]
				if segment == 0:
					a = a.lerp(b, 0.5)
				if segment == 2:
					b = b.lerp(a, 0.5)
				var front: float = FOOD_BEVEL[strip]
				var back: float = FOOD_BEVEL[strip + 1]
				var z0: float = FOOD_ENDS[strip]
				var z1: float = FOOD_ENDS[strip + 1]
				var points: Array[Vector3] = [Vector3(a.x * front, a.y * front, z0), Vector3(a.x * back, a.y * back, z1),
					Vector3(b.x * back, b.y * back, z1), Vector3(b.x * front, b.y * front, z0)]
				var uv: Array[Vector2] = [Vector2(segment / 3.0, z0 + 0.5), Vector2(segment / 3.0, z1 + 0.5),
					Vector2((segment + 1) / 3.0, z1 + 0.5), Vector2((segment + 1) / 3.0, z0 + 0.5)]
				for point in [0, 1, 2, 0, 2, 3]:
					surface.set_uv(uv[point])
					surface.add_vertex(points[point])
		surface.generate_normals()
		surface.commit(mesh)
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sign_z in [-1.0, 1.0]:
		for index in FOOD_CROSS_SECTION.size():
			var a: Vector2 = FOOD_CROSS_SECTION[index] * 0.74
			var b: Vector2 = FOOD_CROSS_SECTION[(index + 1) % FOOD_CROSS_SECTION.size()] * 0.74
			var triangle := PackedVector2Array([Vector2.ZERO, a, b] if sign_z < 0.0 else [Vector2.ZERO, b, a])
			for point in triangle:
				ends.set_uv(point + Vector2.ONE * 0.5)
				ends.add_vertex(Vector3(point.x, point.y, sign_z * 0.48))
	ends.generate_normals()
	ends.commit(mesh)
	return mesh


func _set_ingredient(index: int, recipe: String) -> void:
	for piece in _ingredient_pieces[index].size():
		var item: MeshInstance3D = _ingredient_pieces[index][piece]
		var variation := cos(index * 1.8 + piece * 2.4)
		match recipe:
			"scallion":
				item.scale = Vector3(0.40 + variation * 0.04, 0.36, 0.30)
			"sweet_pepper":
				item.scale = Vector3(0.58 + variation * 0.055, 0.32, 0.34)
			_:
				item.scale = Vector3(0.49 + variation * 0.065, 0.50, 0.35)

func present(state: Dictionary, reduced: bool) -> void:
	if not is_node_ready():
		return
	var elapsed: float = state.elapsed
	var delta := clampf(elapsed - _last_elapsed, 0.0, 0.12)
	var reset := _last_layout != int(state.layout) or elapsed < _last_elapsed or (reduced and not _last_motion)
	_last_layout = state.layout
	_last_elapsed = elapsed
	_last_motion = reduced
	var dirty := reset
	var heat := roundi(float(state.near_heat) * 22.0)
	if _last_heat != heat:
		_last_heat = heat
		var level := float(heat) / 22.0
		_coal.emission_energy_multiplier = lerpf(0.04, 0.92, level)
		_ember_light.light_energy = lerpf(0.12, 1.32, level)
		dirty = true
	if _last_selected != int(state.selected):
		_last_selected = state.selected
		for index in _markers.size():
			_markers[index].visible = index == _last_selected
		dirty = true
	for index in _skewers.size():
		var entry: Dictionary = state.skewers[index]
		var body := _skewers[index]
		if reset:
			body.scale = Vector3.ONE * float(entry.size)
			_set_ingredient(index, entry.ingredient_id)
		var gloss := 0 if reduced else roundi(float(entry.turn_gloss) * 8.0)
		var gloss_changed := gloss != _gloss[index]
		_gloss[index] = gloss
		var zone: int = entry.zone
		var target := Vector3(LANE_X[index], 0.28, 1.75)
		match zone:
			Model.NEAR: target = Vector3(LANE_X[index], 0.53, 0.46)
			Model.FAR: target = Vector3(LANE_X[index], 0.52, -0.82)
			Model.SERVED: target = Vector3(LANE_X[index], 0.25, 1.97)
		var angle := -float(entry.down_face) * PI * 0.5
		var twist := angle_difference(body.rotation.z, angle)
		var distance := body.position.distance_to(target)
		var can_move := reset or reduced or delta > 0.0
		if can_move and (distance > 0.003 or absf(twist) > 0.004):
			body.position = target if reset or reduced else body.position.move_toward(target, delta * 10.5)
			if reset or reduced:
				body.rotation.z = angle
			else:
				body.rotation.z += clampf(twist, -delta * 12.5, delta * 12.5)
			dirty = true
		for face in Model.FACE_COUNT:
			var cue: String = entry.face_states[face]
			if cue == _face_cues[index][face] and not reset and not gloss_changed:
				continue
			_face_cues[index][face] = cue
			var material: StandardMaterial3D = _faces[index][face]
			var base_color: Color = FACE_INK.get(cue, FACE_INK.raw)
			var tint: Color = FOOD_TINTS.get(entry.ingredient_id, INGREDIENT_COLORS[index])
			material.albedo_color = base_color.lerp(tint, 0.58 if cue in ["raw", "warming"] else 0.23)
			var base_roughness := 0.29 if cue == "ready" else 0.64
			material.roughness = base_roughness - float(gloss) * 0.016
			dirty = true
	if dirty:
		render_target_update_mode = UPDATE_ONCE

func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(parent: Node3D, at: Vector3, box_size: Vector3, material: Material) -> MeshInstance3D:
	var box := _mesh(parent, _unit_box, at, material)
	box.scale = box_size
	return box

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item
