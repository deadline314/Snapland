extends SubViewport
## The table, cushions and puck use the same planar coordinates as the model.

const Model = preload("res://game/minigames/coin_bank_shot_model.gd")
const StageProps = preload("res://game/minigames/stage_props.gd")
const SURFACES := "res://assets/minigames/coin-bank-surfaces.webp"
const FRAME := Color("#775240")
const COPPER := Color("#db9c57")
const MINT := Color("#86c8ad")
const BOARD_TONES := [Color("#4aa7a6"), Color("#c56867")]

var _table := Node3D.new()
var _camera: Camera3D
var _unit_box := BoxMesh.new()
var _dish := CylinderMesh.new()
var _felt: MeshInstance3D
var _coin: Node3D
var _boards: Array[Node3D] = []
var _board_half_lengths: Array[float] = []
var _rims: Array[MeshInstance3D] = []
var _wells: Array[Node3D] = []
var _rim_plain: StandardMaterial3D
var _rim_called: StandardMaterial3D
var _rim_filled: StandardMaterial3D
var _last_layout := -1
var _last_called := -1
var _last_sunk := -1


func _ready() -> void:
	size = Vector2i(803, 328)
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = UPDATE_DISABLED
	gui_disable_input = true
	msaa_3d = MSAA_2X
	add_child(_table)
	_build_camera_and_lights()


func _build_camera_and_lights() -> void:
	var ambient := WorldEnvironment.new()
	ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_color = Color("#b7dfdb")
	ambient.environment.ambient_light_energy = 0.53
	_table.add_child(ambient)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = 14.55
	_table.add_child(_camera)
	_camera.position = Vector3(-0.92, 14.7, 10.2)
	_camera.look_at(Vector3(0, 0, -0.06))
	_camera.current = true
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe4bd")
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-52, -33, 0)
	key.shadow_enabled = true
	_table.add_child(key)
	var pool := OmniLight3D.new()
	pool.position = Vector3(3.3, 1.6, -2.5)
	pool.light_color = Color("#82bcc5")
	pool.light_energy = 0.62
	pool.omni_range = 7.5
	_table.add_child(pool)


func _build_geometry(state: Dictionary) -> void:
	_dish.height = 1.0
	_dish.top_radius = 1.0
	_dish.bottom_radius = 1.0
	_dish.radial_segments = 32
	_dish.rings = 1
	var tray: Rect2 = state.tray
	var centre := tray.get_center()
	# Lacquered planks for the cabinet and cushions instead of flat paint.
	var lacquer := StageProps.wood(Color("#5a2d33"), 0.16)
	var rim := StageProps.wood(FRAME, 0.08)
	var inset := _material(Color("#704d40"), 0.49, 0.08)
	var cloth := _material(Color("#395e69"), 0.94)
	if ResourceLoader.exists(SURFACES):
		var atlas := load(SURFACES) as Texture2D
		inset.albedo_texture = atlas
		inset.albedo_color = Color("#e7d4c2")
		inset.uv1_scale = Vector3(0.98, 0.45, 1.0)
		inset.uv1_offset = Vector3(0.01, 0.025, 0.0)
		cloth.albedo_texture = atlas
		cloth.albedo_color = Color("#d7e8e5")
		cloth.uv1_scale = Vector3(0.98, 0.44, 1.0)
		cloth.uv1_offset = Vector3(0.01, 0.53, 0.0)
	var surface := PlaneMesh.new()
	surface.size = Vector2.ONE
	var gold := _material(COPPER, 0.42, 0.64)
	var dark := StageProps.painted(Color("#1a1418"))
	_box(_table, _position(centre, -0.16), Vector3(tray.size.x + 0.38, 0.33, tray.size.y + 0.38), lacquer)
	var cut := _mesh(_table, surface, _position(centre, 0.032), inset)
	cut.scale = Vector3(tray.size.x, 1.0, tray.size.y)
	for z in [tray.position.y - 0.07, tray.end.y + 0.07]:
		_box(_table, Vector3(centre.x, 0.05, z), Vector3(tray.size.x + 0.25, 0.14, 0.11), rim)
		for end_x in [tray.position.x + 0.12, tray.end.x - 0.12]:
			_disc(_table, Vector3(end_x, 0.13, z), 0.063, 0.027, gold)
	for x in [tray.position.x - 0.07, tray.end.x + 0.07]:
		_box(_table, Vector3(x, 0.05, centre.y), Vector3(0.11, 0.14, tray.size.y + 0.19), rim)
	_felt = _mesh(_table, surface, Vector3.ZERO, cloth)
	_rim_plain = _material(Color("#b58e66"), 0.50, 0.43)
	_rim_called = _material(Color("#ffd990"), 0.33, 0.58)
	_rim_filled = _material(MINT, 0.40, 0.44)
	var ring := _make_ring(Model.POT_RADIUS + Model.COIN_RADIUS, Model.RIM_RADIUS)
	for index in Model.POCKET_COUNT:
		var well := Node3D.new()
		_table.add_child(well)
		_wells.append(well)
		_disc(well, Vector3(0, 0.010, 0), Model.RIM_RADIUS, 0.018, dark)
		# A cup inside the hole catches the lamp on its far wall.
		_disc(well, Vector3(0, 0.016, 0), Model.POT_RADIUS * 0.72, 0.014, StageProps.painted(Color("#3a2a24")))
		_rims.append(_mesh(well, ring, Vector3(0, 0.025, 0), _rim_plain))
	for index in 2:
		var board_row: Dictionary = state.boards[index]
		_build_board(index, float(board_row.half_length), rim)
	var launch_pad: Vector2 = state.launcher
	_mesh(_table, _make_ring(Model.COIN_RADIUS * 1.57, Model.COIN_RADIUS * 2.01), _position(launch_pad, 0.064), gold)
	_coin = Node3D.new()
	_table.add_child(_coin)
	_disc(_coin, Vector3.ZERO, Model.COIN_RADIUS, 0.048, gold)
	_disc(_coin, Vector3(0, 0.031, 0), Model.COIN_RADIUS * 0.68, 0.020, _material(Color("#9b633d"), 0.55, 0.64))
	_box(_coin, Vector3(0, 0.047, 0), Vector3(0.070, 0.009, 0.070), dark)


func _build_board(index: int, half_length: float, rim: Material) -> void:
	var body := Node3D.new()
	_table.add_child(body)
	_boards.append(body)
	_board_half_lengths.append(half_length)
	var length := half_length * 2.0
	var tone := StageProps.wood(BOARD_TONES[index], 0.1)
	_box(body, Vector3(0, 0.07, 0), Vector3(length, 0.12, Model.BOARD_RADIUS * 2.0), tone)
	_box(body, Vector3(0, 0.141, 0), Vector3(length, 0.036, Model.BOARD_RADIUS * 2.24), rim)
	for side in [-1.0, 1.0]:
		_disc(body, Vector3(half_length * side, 0.05, 0), Model.BOARD_RADIUS * 1.16, 0.12, tone)


func present(state: Dictionary, reduced_motion: bool) -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(_coin):
		_build_geometry(state)
	var layout_changed := _last_layout != int(state.layout)
	var dirty := layout_changed
	if layout_changed:
		_last_layout = state.layout
		var felt: Rect2 = state.felt
		_felt.position = _position(felt.get_center(), 0.041)
		_felt.scale = Vector3(felt.size.x, 1.0, felt.size.y)
		for index in _wells.size():
			_wells[index].position = _position(state.pockets[index].center, 0.047)
	var called: int = state.called
	var sunk: int = state.sunk
	if layout_changed or _last_sunk != sunk or _last_called != called:
		_last_sunk = sunk
		_last_called = called
		for index in _rims.size():
			var entry: Dictionary = state.pockets[index]
			_rims[index].material_override = _rim_filled if entry.filled else (_rim_called if index == called else _rim_plain)
		dirty = true
	for index in _boards.size():
		var row: Dictionary = state.boards[index]
		var body := _boards[index]
		if layout_changed:
			body.scale.x = float(row.half_length) / _board_half_lengths[index]
		var at := _position(row.center, 0.04)
		var yaw := -float(row.angle)
		if body.visible != bool(row.placed) or absf(angle_difference(body.rotation.y, yaw)) > 0.001 or not body.position.is_equal_approx(at):
			body.position = at
			body.rotation.y = yaw
			body.visible = row.placed
			dirty = true
	var coin_at: Vector2 = state.coin if state.active else state.launcher
	var wanted := _position(coin_at, 0.105)
	var wanted_spin := fmod(float(state.shot_elapsed) * 8.0, TAU) if state.active and not reduced_motion else 0.0
	if not _coin.position.is_equal_approx(wanted) or absf(angle_difference(_coin.rotation.y, wanted_spin)) > 0.002:
		_coin.position = wanted
		_coin.rotation.y = wanted_spin
		dirty = true
	if dirty:
		render_target_update_mode = UPDATE_ONCE


func project(point: Vector2, height := 0.102) -> Vector2:
	return _camera.unproject_position(_position(point, height))


func _make_ring(inner_radius: float, outer_radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 32:
		var a := Vector2.from_angle(TAU * float(index) / 32.0)
		var b := Vector2.from_angle(TAU * float(index + 1) / 32.0)
		for point: Vector2 in [a * inner_radius, a * outer_radius, b * outer_radius, a * inner_radius, b * outer_radius, b * inner_radius]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(_position(point, 0.0))
	return surface.commit()


func _material(color: Color, roughness: float, metal := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	return material


func _position(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)


func _disc(parent: Node3D, at: Vector3, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var item := _mesh(parent, _dish, at, material)
	item.scale = Vector3(radius, thickness, radius)
	return item


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var item := _mesh(parent, _unit_box, at, material)
	item.scale = dimensions
	return item


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = at
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item
