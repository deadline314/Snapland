extends SubViewport
## The canvas, carriage and blockers are drawn in the collision model's coordinates.

const Model = preload("res://game/minigames/banner_cart_model.gd")
const CharacterArt = preload("res://game/world/character_animation_library.gd")
const NpcArt = preload("res://game/world/npc_activity.gd")
const SurfaceShader = preload("res://game/world/coastal_material.gdshader")
const SURFACE_ATLAS := "res://assets/world/coastal-materials-v1.png"
const FABRICS := "res://assets/minigames/banner-cart-fabrics.webp"
const CABINET := Color("#563c47")
const WOOD := Color("#765450")
const METAL := Color("#b99262")
const JADE := Color("#70c9b0")
const AMBER := Color("#e0ac74")
const WINDOW := Color("#e2ba91")
const WALK_COATS := [Color("#b48860"), Color("#d6aa72")]
const FABRIC_COLORS := [Color("#aa5542"), Color("#426f65"), Color("#856080")]
const KEY_ENERGY := {"dawn": 0.75, "noon": 1.05, "dusk": 0.82, "night": 0.63}
const POOL_ENERGY := {"dawn": 0.58, "noon": 0.41, "dusk": 0.68, "night": 0.82}

var _scene := Node3D.new()
var _course: Node3D
var _cart: Node3D
var _pivot: Node3D
var _mast: MeshInstance3D
var _cloth_edge: MeshInstance3D
var _cloth_faces: Array[MeshInstance3D] = []
var _wheels: Array[Node3D] = []
var _walker: Node3D
var _walker_legs: Array[MeshInstance3D] = []
var _walker_sprite: Sprite3D
var _crossing_warning: Label3D
var _walk_frames: Dictionary[String, Array] = {}
var _walk_stride := 0.0
var _last_walk_x := 0.0
var _walk_direction := "right"
var _camera: Camera3D
var _key: DirectionalLight3D
var _pools: Array[OmniLight3D] = []
var _gate_trim: Dictionary[int, MeshInstance3D] = {}
var _roof_bodies: Dictionary[int, MeshInstance3D] = {}
var _roof_opaque: Material
var _roof_reveal: Material
var _active_roof := -1
var _surface_atlas: Texture2D
var _fabric_materials: Array[StandardMaterial3D] = []
var _unit_box := BoxMesh.new()
var _quad := QuadMesh.new()
var _ground_shadow := CylinderMesh.new()
var _metal: StandardMaterial3D
var _trim: StandardMaterial3D
var _blocking: StandardMaterial3D
var _last_layout := -1
var _last_banner := -1
var _last_block := -2
var _last_phase := ""
var _paint: Array = []


func _ready() -> void:
	size = Vector2i(848, 328)
	own_world_3d = true
	gui_disable_input = true
	render_target_update_mode = UPDATE_DISABLED
	msaa_3d = MSAA_2X
	add_child(_scene)
	_setup_stage()
	_build_street()
	_build_cart()
	_build_walker()


func update_stage(state: Dictionary, phase: String, reduced_motion: bool) -> void:
	if not is_node_ready() or state.is_empty():
		return
	if phase != _last_phase:
		_key.light_energy = KEY_ENERGY.get(phase, KEY_ENERGY.night)
		for pool in _pools:
			pool.light_energy = POOL_ENERGY.get(phase, POOL_ENERGY.night)
		_last_phase = phase
		_paint.clear()
	var marker := [
		state.layout, state.cart.snappedf(0.0075), snappedf(state.lift, 0.003), snappedf(state.roll, 0.005),
		state.banner_index, state.pedestrian.position.snappedf(0.009), state.block_id, state.block_kind, reduced_motion,
	]
	if marker == _paint:
		return
	_paint = marker
	if state.layout != _last_layout:
		_build_course(state)
		_walk_stride = 0.0
		_last_walk_x = state.pedestrian.position.x
		_last_layout = state.layout
		_last_block = -2
	if state.banner_index != _last_banner:
		_change_banner(state)
		_last_banner = state.banner_index
	if state.block_id != _last_block:
		_mark_blocked_gate(state.block_id)
	var cart: Vector3 = state.cart
	_cart.position = _stage_position(cart)
	_pivot.position = Vector3.UP * (Model.PIVOT_BASE + float(state.lift))
	_pivot.rotation.z = -float(state.roll)
	_reveal_current_roof(state)
	_set_mast_height(_pivot.position.y)
	for wheel in _wheels:
		wheel.rotation.x = 0.0 if reduced_motion else fposmod(cart.z / 0.14, TAU)
	_update_walker(state.pedestrian, reduced_motion)
	_crossing_warning.visible = state.block_kind == "person"
	_camera.position = Vector3(-cart.x * 0.62 + 0.74, 3.74, cart.z - 6.70)
	_camera.look_at(Vector3(-cart.x * 0.38, 0.94, cart.z + 1.43))
	render_target_update_mode = UPDATE_ONCE


func _setup_stage() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#26324d")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#b4c2e8")
	world.environment.ambient_light_energy = 0.66
	_scene.add_child(world)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = 10.45
	_camera.far = 37.0
	_scene.add_child(_camera)
	_camera.current = true
	_key = DirectionalLight3D.new()
	_key.light_color = Color("#ffe2bf")
	_key.rotation_degrees = Vector3(-54.0, 40.0, 0.0)
	_scene.add_child(_key)
	for at: Vector3 in [Vector3(2.5, 2.7, 6.3), Vector3(-2.8, 2.7, 11.2)]:
		var pool := OmniLight3D.new()
		pool.position = at
		pool.light_color = Color("#f7ba7f")
		pool.omni_range = 5.7
		pool.omni_attenuation = 1.65
		_scene.add_child(pool)
		_pools.append(pool)
	_metal = _material(METAL, 0.46, 0.30)
	_trim = _material(AMBER, 0.52, 0.08, 0.14)
	if ResourceLoader.exists(SURFACE_ATLAS):
		_surface_atlas = load(SURFACE_ATLAS) as Texture2D
	_roof_opaque = _surface(3, 4.3, Color("#8c6177"), Color("#704253"))
	var outline_mat := _material(Color(0.52, 0.24, 0.34, 0.38), 0.78)
	outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_roof_reveal = outline_mat
	_blocking = _material(Color("#fd8a76"), 0.52, 0.08, 0.35)
	var atlas := load(FABRICS) as Texture2D if ResourceLoader.exists(FABRICS) else null
	for index in FABRIC_COLORS.size():
		var fabric := _material(Color.WHITE if atlas != null else FABRIC_COLORS[index], 0.93)
		fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
		fabric.albedo_texture = atlas
		fabric.uv1_scale = Vector3(0.323, 0.98, 1.0)
		fabric.uv1_offset = Vector3(index / 3.0 + 0.005, 0.01, 0.0)
		_fabric_materials.append(fabric)


func _build_street() -> void:
	var paving := _surface(0, 4.2, Color("#696f92"), Color("#394657"))
	var stone_light := _material(Color("#435362"), 0.69)
	var curb := _surface(4, 4.6, Color("#9e8598"), Color("#5c6073"))
	var boards := _surface(1, 3.9, Color("#705271"), CABINET)
	var plaster := _material(WOOD, 0.87)
	var copper := _surface(3, 4.1, Color("#886581"), Color("#865052"))
	var pane := _material(WINDOW, 0.41, 0.0, 0.23)
	_box(_scene, Vector3(0, -0.33, 8.3), Vector3(9.2, 0.66, 28.0), paving)
	for side: float in [-1.0, 1.0]:
		var x := side * 3.97
		_box(_scene, Vector3(x, 0.074, 8.4), Vector3(0.21, 0.15, 25.0), curb)
		_box(_scene, Vector3(x * 0.92, 0.010, 8.4), Vector3(0.12, 0.021, 25.0), stone_light)
		for block in 5:
			var z := -1.5 + float(block) * 4.85 + side * 0.41
			var base := Vector3(side * 4.59, 0.0, z)
			_box(_scene, base + Vector3(0, 1.17, 0), Vector3(1.08, 2.35, 3.73), boards)
			_box(_scene, base + Vector3(-side * 0.55, 1.52, 0), Vector3(0.13, 1.2, 3.38), plaster)
			_box(_scene, base + Vector3(-side * 0.43, 2.46, 0), Vector3(1.39, 0.18, 3.99), copper).rotation.z = side * 0.16
			for stripe: float in [-1.18, 0.0, 1.18]:
				_box(_scene, base + Vector3(-side * 0.63, 1.48, stripe),
					Vector3(0.032, 0.63, 0.64), pane)
			_box(_scene, base + Vector3(-side * 0.76, 0.53, 0), Vector3(0.38, 0.12, 3.36), boards)
	_ground_shadow.height = 1.0
	_ground_shadow.top_radius = 1.0
	_ground_shadow.bottom_radius = 1.0
	_ground_shadow.radial_segments = 20
	_ground_shadow.rings = 1


func _build_course(state: Dictionary) -> void:
	if is_instance_valid(_course):
		_scene.remove_child(_course)
		_course.queue_free()
	_course = Node3D.new()
	_scene.add_child(_course)
	_gate_trim.clear()
	_roof_bodies.clear()
	_active_roof = -1
	var stone := _surface(4, 3.7, Color("#9d859e"), Color("#756276"))
	for gate: Dictionary in state.gates:
		var low: Vector3 = gate.min
		var high: Vector3 = gate.max
		var center := _stage_position(low.lerp(high, 0.5))
		var dimensions := high - low
		var is_roof: bool = gate.kind == "roof"
		var body := _box(_course, center, dimensions, _roof_opaque if is_roof else stone)
		if is_roof:
			_roof_bodies[int(gate.id)] = body
		_gate_trim[int(gate.id)] = _box(_course,
			Vector3(center.x, low.y + 0.035, low.z - 0.014), Vector3(dimensions.x, 0.06, 0.028), _trim)
		for edge: float in [-1.0, 1.0]:
			var x := center.x + edge * (dimensions.x * 0.5 - 0.056)
			_box(_course, Vector3(x, center.y, low.z - 0.018), Vector3(0.04, dimensions.y, 0.03), _metal)
	for lane: Dictionary in state.lanes:
		_lane_inlay(lane.points, JADE if lane.id == Model.BYPASS else AMBER, float(state.route_lock_z))
	var crossing: float = state.pedestrian.position.z
	var marking := _material(Color("#c8b18e"), 0.84)
	for stripe in 10:
		var x := -3.3 + float(stripe) * 0.74
		_box(_course, Vector3(x, 0.016, crossing), Vector3(0.27, 0.023, 0.65), marking)
	_box(_course, Vector3(0, 0.019, float(state.finish_z)), Vector3(4.0, 0.026, 0.10), _trim)


func _lane_inlay(points: PackedVector3Array, ink: Color, fork: float) -> void:
	var paint := ImmediateMesh.new()
	var material := _material(ink.darkened(0.23), 0.74, 0.0, 0.18)
	paint.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for index in range(1, points.size()):
		var a := _stage_position(points[index - 1]) + Vector3.UP * 0.025
		var b := _stage_position(points[index]) + Vector3.UP * 0.025
		if b.z < fork - 0.30 or b.z > Model.REJOIN_END_Z:
			continue
		_flat_strip(paint, a, b, 0.035)
	paint.surface_end()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(_course, paint, Vector3.ZERO, null)


func _flat_strip(mesh: ImmediateMesh, a: Vector3, b: Vector3, half_width: float) -> void:
	var offset := Vector3.RIGHT * half_width
	for vertex: Vector3 in [a - offset, b - offset, b + offset, a - offset, b + offset, a + offset]:
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_add_vertex(vertex)


func _build_cart() -> void:
	_cart = Node3D.new()
	_scene.add_child(_cart)
	var dark := _material(Color("#202830"), 0.82)
	var lacquer := _material(Color("#814d46"), 0.56)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.14
	hub.bottom_radius = 0.14
	hub.height = 0.074
	hub.radial_segments = 16
	hub.rings = 1
	_mesh(_cart, _ground_shadow, Vector3(0, 0.017, 0), dark).scale = Vector3(0.51, 0.012, 0.64)
	_box(_cart, Vector3(0, 0.37, 0), Vector3(Model.CARRIAGE_HALF_WIDTH * 2, 0.27, Model.CARRIAGE_HALF_DEPTH * 2), lacquer)
	_box(_cart, Vector3(0, 0.53, 0), Vector3(0.82, 0.09, 1.06), _metal)
	for side: float in [-1.0, 1.0]:
		for axle: float in [-0.39, 0.39]:
			var wheel := Node3D.new()
			wheel.position = Vector3(0.379 * side, 0.148, axle)
			_cart.add_child(wheel)
			_mesh(wheel, hub, Vector3.ZERO, dark).rotation.z = PI * 0.5
			_box(wheel, Vector3(side * 0.042, 0.0, 0.0), Vector3(0.018, 0.22, 0.027), _metal)
			_wheels.append(wheel)
	_mast = _box(_cart, Vector3.ZERO, Vector3(0.092, 1.0, 0.092), dark)
	_pivot = Node3D.new()
	_cart.add_child(_pivot)
	_cloth_edge = _box(_pivot, Vector3.ZERO, Vector3.ONE, lacquer)
	for side: float in [-1.0, 1.0]:
		var face := _mesh(_pivot, _quad, Vector3(0, 0, side * Model.CANVAS_HALF_DEPTH))
		_cloth_faces.append(face)


func _build_walker() -> void:
	_walker = Node3D.new()
	_scene.add_child(_walker)
	_crossing_warning = Label3D.new()
	_crossing_warning.name = "CrosswalkBlocked"
	_crossing_warning.text = "◆"
	_crossing_warning.modulate = Color("#ffd48c")
	_crossing_warning.outline_modulate = Color("#26303f")
	_crossing_warning.outline_size = 4
	_crossing_warning.font_size = 20
	_crossing_warning.pixel_size = 0.010
	_crossing_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_crossing_warning.no_depth_test = true
	_crossing_warning.position.y = Model.PEDESTRIAN_HEIGHT + 0.18
	_crossing_warning.hide()
	_walker.add_child(_crossing_warning)
	var ink := _material(Color("#31324a"), 0.82)
	_mesh(_walker, _ground_shadow, Vector3(0.0, 0.018, 0), ink).scale = Vector3(0.28, 0.012, 0.26)
	if _build_walker_sprite():
		return
	var raincoat := _material(WALK_COATS[0], 0.65)
	var hat := _material(WALK_COATS[1], 0.67)
	var skin := _material(Color("#e2b691"), 0.79)
	for leg: float in [-0.10, 0.10]:
		_walker_legs.append(_box(_walker, Vector3(leg, 0.28, 0.0), Vector3(0.12, 0.43, 0.18), ink))
	_box(_walker, Vector3(0, 0.79, 0), Vector3(0.48, 0.53, 0.38), raincoat)
	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.31
	head.radial_segments = 12
	head.rings = 6
	_mesh(_walker, head, Vector3(0, 1.22, 0), skin)
	_mesh(_walker, head, Vector3(0, 1.39, 0), hat).scale = Vector3(1.4, 0.41, 1.30)


func _build_walker_sprite() -> bool:
	var library := CharacterArt.new()
	for direction in ["left", "right"]:
		var sequence: Dictionary = library.get_sequence("ticket", "walk", direction)
		var frames: Array = sequence.get("frames", [])
		if not sequence.get("available", false) or frames.is_empty() or frames.any(func(frame: Dictionary) -> bool: return frame.get("texture") == null):
			return false
		_walk_frames[direction] = frames
	_walker_sprite = Sprite3D.new()
	_walker_sprite.name = "CrosswalkGuide"
	_walker_sprite.texture = _walk_frames.right[0].texture
	_walker_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_walker_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_walker_sprite.pixel_size = Model.PEDESTRIAN_HEIGHT / float(NpcArt.ACTION_VISIBLE_HEIGHT)
	_walker_sprite.position.y = _walker_sprite.pixel_size * (NpcArt.ACTION_FEET_ROW - NpcArt.ACTION_CANVAS_SIZE.y * 0.5)
	_walker_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_walker_sprite.shaded = true
	_walker_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_walker.add_child(_walker_sprite)
	return true


func _update_walker(pedestrian: Dictionary, reduced_motion: bool) -> void:
	_walker.position = _stage_position(pedestrian.position)
	var x: float = pedestrian.position.x
	var speed: float = pedestrian.velocity.x
	_walk_stride = fposmod(_walk_stride + absf(x - _last_walk_x), 0.68)
	_last_walk_x = x
	if absf(speed) >= 0.01:
		_walk_direction = "right" if speed > 0.0 else "left"
	var progress := 0.0 if reduced_motion else _walk_stride / 0.68
	if is_instance_valid(_walker_sprite):
		var frames: Array = _walk_frames[_walk_direction]
		var texture: Texture2D = frames[mini(frames.size() - 1, floori(progress * frames.size()))].texture
		if _walker_sprite.texture != texture:
			_walker_sprite.texture = texture
	else:
		var stride := sin(progress * TAU) * 0.18
		_walker_legs[0].rotation.x = stride
		_walker_legs[1].rotation.x = -stride


func _change_banner(state: Dictionary) -> void:
	var banner: Dictionary = state.banners[int(state.banner_index)]
	var size := Vector2(float(banner.width), float(banner.height))
	for face in _cloth_faces:
		face.position.y = size.y * 0.5
		face.scale = Vector3(size.x, size.y, 1.0)
		face.material_override = _fabric_materials[int(banner.id)]
	_cloth_edge.position.y = size.y * 0.5
	_cloth_edge.scale = Vector3(size.x, size.y, Model.CANVAS_HALF_DEPTH * 1.98)


func _reveal_current_roof(state: Dictionary) -> void:
	# A translucent canopy shows the actual canvas while it is under that canopy.
	# The solid rim remains visible as the exact collision boundary.
	var active := -1
	var z: float = state.cart.z
	for gate: Dictionary in state.gates:
		if gate.kind == "roof" and gate.route == state.route and z >= gate.min.z - 0.48 and z <= gate.max.z + 0.12:
			active = gate.id
			break
	if active == _active_roof:
		return
	if _roof_bodies.has(_active_roof):
		_roof_bodies[_active_roof].material_override = _roof_opaque
	if _roof_bodies.has(active):
		_roof_bodies[active].material_override = _roof_reveal
	_active_roof = active


func _set_mast_height(height: float) -> void:
	var base := Model.CARRIAGE_TOP
	_mast.position.y = (height + base) * 0.5
	_mast.scale.y = maxf(0.10, height - base)


func _mark_blocked_gate(id: int) -> void:
	if _gate_trim.has(_last_block):
		_gate_trim[_last_block].material_override = _trim
	if _gate_trim.has(id):
		_gate_trim[id].material_override = _blocking
	_last_block = id


func _stage_position(at: Vector3) -> Vector3:
	# Camera faces positive Z. Mirror stage X so the operator's right stays screen-right.
	return Vector3(-at.x, at.y, at.z)


func _box(parent: Node3D, at: Vector3, extent: Vector3, material: Material) -> MeshInstance3D:
	var mesh := _mesh(parent, _unit_box, at, material)
	mesh.scale = extent
	return mesh


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _surface(tile: int, scale_m: float, tint: Color, fallback: Color) -> Material:
	if _surface_atlas == null:
		return _material(fallback, 0.85)
	var material := ShaderMaterial.new()
	material.shader = SurfaceShader
	material.set_shader_parameter("atlas_texture", _surface_atlas)
	material.set_shader_parameter("tile_index", tile)
	material.set_shader_parameter("world_tile_size", scale_m)
	material.set_shader_parameter("tint", tint)
	return material


func _material(color: Color, roughness: float, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
