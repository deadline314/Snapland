extends Control
class_name RowingCargoView

## One command owner per physical pointer. The driver merges these with keyboard owners.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/rowing_cargo_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const COMMANDS := ["left", "right", "stroke", "reverse", "slip_left", "slip_right", "interact"]
const BUTTON_LABELS := ["A / ← 左舵", "D / → 右舵", "W / ↑ 划槳", "S / ↓ 反槳", "Q 左側滑", "E 右側滑", "空白 拿／交箱"]
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _pointer_owners: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _boat: Node3D
var _oars: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _crates: Dictionary = {}
var _walls: Array[MeshInstance3D] = []
var _waves: Array[MeshInstance3D] = []
var _force: Node3D
var _materials: Dictionary = {}

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 176, 590, 168, 56)

static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""

static func feedback_text(state: Dictionary) -> String:
	var text: String = state.get("feedback", "靠近貨箱後按空白拿取")
	for crate in state.get("cargo", []):
		text = text.replace(str(crate.id), "第%s箱" % str(crate.id).trim_prefix("crate-"))
	return text

func _carrying_text() -> String:
	for crate in _snapshot.get("cargo", []):
		if crate.id == _snapshot.carrying:
			return "第%s箱 → 碼頭%d" % [str(crate.id).trim_prefix("crate-"), crate.destination]
	return "空船"

static func pointer_source(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if not event.pressed:
		if not _pointer_owners.has(source):
			return false
		var command: String = _pointer_owners[source]
		_pointer_owners.erase(source)
		command_requested.emit(command, false, source)
		queue_redraw()
		return true
	if not is_finite(point.x) or not is_finite(point.y):
		return false
	var command := command_at(point)
	if command.is_empty():
		return false
	if not _pointer_owners.has(source):
		_pointer_owners[source] = command
		command_requested.emit(command, true, source)
		queue_redraw()
	return true

func clear_pointer_input(emit_releases: bool = true) -> void:
	if emit_releases:
		for source in _pointer_owners:
			command_requested.emit(_pointer_owners[source], false, source)
	_pointer_owners.clear()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_pointer_input()
		command_requested.emit("clear", false, "lifecycle")

func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		point = event.position
	if handle_pointer(event, point):
		accept_event()

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not _snapshot.is_empty():
		_create_stage()
		_apply_snapshot()

func present(state: Dictionary, time_phase: String, reduced_motion: bool) -> void:
	_snapshot = state
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if _world == null and is_inside_tree() and not state.is_empty():
		_create_stage()
	if _world != null:
		_apply_snapshot()
	queue_redraw()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material

func _box(node_name: String, dimensions: Vector3, at: Vector3, parent: Node3D, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _sphere(node_name: String, radius: float, at: Vector3, parent: Node3D, material: StandardMaterial3D) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)

func _label3d(text: String, at: Vector3, parent: Node3D) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = 48
	label.pixel_size = 0.011
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)

func _create_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "SpatialStage"
	container.position = STAGE.position
	container.size = STAGE.size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.show_behind_parent = true
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "RowingViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "RowingBasin"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#cadbd3")
	_environment.ambient_light_energy = 0.5
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "RowingSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 35
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "RowingCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = 24.8
	_camera.position = Vector3(0, 9, 21)
	_world.add_child(_camera)
	_camera.look_at(Vector3.ZERO)
	_camera.current = true
	for item in [["water", "#346c7b"], ["shelter", "#426f73"], ["wall", "#627b7b"], ["wood", "#9b7751"], ["dark", "#253e52"], ["ivory", "#ead9af"], ["crate", "#c58c59"], ["wave", "#a0c9c0"], ["coat", "#cdad66"], ["skin", "#e4ba91"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_box("Water", Vector3(22, 0.12, 14), Vector3(0, -0.13, 0), _world, _materials.water)
	var shelter: Rect2 = _snapshot.get("shelter", Rect2(-11, 3.8, 22, 3.2))
	_box("ShelteredWater", Vector3(shelter.size.x, 0.02, shelter.size.y), Vector3(shelter.get_center().x, -0.05, shelter.get_center().y), _world, _materials.shelter)
	for z in [-7.0, 7.0]:
		_box("BasinEdge", Vector3(22.3, 0.2, 0.15), Vector3(0, 0, z), _world, _materials.dark)
	for x in [-11.0, 11.0]:
		_box("BasinEdge", Vector3(0.15, 0.2, 14), Vector3(x, 0, 0), _world, _materials.dark)
	for i in 2:
		_walls.append(_box("Breakwater%d" % i, Vector3.ONE, Vector3.ZERO, _world, _materials.wall))
	for dock in _snapshot.get("docks", []):
		var node := Node3D.new()
		node.name = "Dock%d" % dock.id
		node.position = Vector3(dock.position.x, 0, dock.position.y)
		_world.add_child(node)
		_box("DockDeck", Vector3(dock.size.x, 0.18, dock.size.y), Vector3(0, 0.04, -0.65), node, _materials.wood)
		for plank in 6:
			_box("PlankSeam", Vector3(0.025, 0.025, dock.size.y), Vector3(-1.0 + plank * 0.4, 0.145, -0.65), node, _materials.dark)
		for x in [-1.0, 1.0]:
			_box("MooringPost", Vector3(0.12, 0.65, 0.12), Vector3(x, 0.2, -0.95), node, _materials.ivory)
		_label3d("碼頭 %d" % dock.id, Vector3(0, 1.1, -0.9), node)
	for crate in _snapshot.get("cargo", []):
		var node := Node3D.new()
		node.name = crate.id
		_world.add_child(node)
		_box("CargoBox", Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), node, _materials.crate)
		_box("CargoStrap", Vector3(0.54, 0.07, 0.54), Vector3(0, 0.3, 0), node, _materials.dark)
		_label3d("%s → %d" % [str(crate.id).trim_prefix("crate-"), crate.destination], Vector3(0, 0.95, 0), node)
		_crates[crate.id] = node
	for i in 9:
		var wave := _box("Wave%d" % i, Vector3(0.035, 0.025, 0.6), Vector3(-10 + i * 2.5, 0, -4.8), _world, _materials.wave)
		for side in [-1, 1]:
			var curl := _box("WaveCurl", Vector3(0.035, 0.025, 0.45), Vector3(-0.10, 0, side * 0.49), wave, _materials.wave)
			curl.rotation.y = -side * 0.45
		_waves.append(wave)
	for x in [-6, -3, 0, 3, 6]:
		_box("LongRouteDash", Vector3(0.7, 0.025, 0.07), Vector3(x, 0, 5.3), _world, _materials.ivory)
	_label3d("堤後長路 · 弱浪", Vector3(0, 0.4, 6.3), _world)
	_force = Node3D.new()
	_force.name = "WaveForce"
	_force.position = Vector3(-5, 0.1, -5.7)
	_world.add_child(_force)
	_label3d("浪推", Vector3(-4.6, 0.6, -5.7), _world)
	_box("ForceShaft", Vector3(0.85, 0.035, 0.05), Vector3(0.4, 0, 0), _force, _materials.ivory)
	for side in [-1, 1]:
		var tip := _box("ForceTip", Vector3(0.3, 0.035, 0.05), Vector3(0.77, 0, side * 0.09), _force, _materials.ivory)
		tip.rotation.y = side * 0.65
	_create_boat()

func _create_boat() -> void:
	_boat = Node3D.new()
	_boat.name = "Boat"
	_world.add_child(_boat)
	var hull := _box("Hull", Vector3.ONE, Vector3.ZERO, _boat, _materials.dark)
	var outline := [Vector2(-0.45, -0.18), Vector2(0.23, -0.26), Vector2(0.55, 0), Vector2(0.23, 0.26), Vector2(-0.45, 0.18), Vector2(-0.52, 0)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		for vertex in [Vector3(0, 0.26, 0), Vector3(b.x, 0.26, b.y), Vector3(a.x, 0.26, a.y), Vector3(a.x, 0.26, a.y), Vector3(b.x, 0.26, b.y), Vector3(b.x * 0.7, 0.02, b.y * 0.7), Vector3(a.x, 0.26, a.y), Vector3(b.x * 0.7, 0.02, b.y * 0.7), Vector3(a.x * 0.7, 0.02, a.y * 0.7)]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	hull.mesh = surface.commit()
	_box("Deck", Vector3(0.60, 0.06, 0.34), Vector3(-0.08, 0.28, 0), _boat, _materials.wood)
	var bow := _box("Bow", Vector3(0.14, 0.06, 0.14), Vector3(0.36, 0.29, 0), _boat, _materials.ivory)
	bow.rotation.y = PI / 4
	for side in [-1, 1]:
		_box("Gunwale", Vector3(0.85, 0.12, 0.055), Vector3(-0.03, 0.28, side * 0.24), _boat, _materials.ivory)
		var oar := Node3D.new()
		oar.name = "OarLeft" if side == -1 else "OarRight"
		oar.position = Vector3(-0.08, 0.3, side * 0.22)
		_boat.add_child(oar)
		_box("OarShaft", Vector3(0.04, 0.04, 0.7), Vector3(0, 0, side * 0.28), oar, _materials.wood)
		_box("OarBlade", Vector3(0.14, 0.04, 0.28), Vector3(0, 0, side * 0.68), oar, _materials.ivory)
		_oars.append(oar)
	var crew := Node3D.new()
	crew.name = "Crew"
	crew.position.x = 0.2
	_boat.add_child(crew)
	_box("SeatedBody", Vector3(0.22, 0.27, 0.24), Vector3(-0.16, 0.43, 0), crew, _materials.coat)
	_sphere("Head", 0.14, Vector3(-0.14, 0.69, 0), crew, _materials.skin)
	_box("Hat", Vector3(0.36, 0.06, 0.34), Vector3(-0.14, 0.81, 0), crew, _materials.ivory)
	for side in [-1, 1]:
		_arms.append(_box("Arm", Vector3(0.12, 0.09, 0.26), Vector3(-0.05, 0.47, side * 0.18), crew, _materials.coat))
		_box("Leg", Vector3(0.28, 0.10, 0.09), Vector3(0, 0.29, side * 0.07), crew, _materials.dark)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	var position_2d: Vector2 = _snapshot.position
	_boat.position = Vector3(position_2d.x, 0, position_2d.y)
	_boat.rotation.y = -float(_snapshot.heading)
	var paddle := float(_snapshot.paddle_ready_in) / Model.PADDLE_COOLDOWN
	for i in _oars.size():
		_oars[i].rotation.y = sin(paddle * PI) * 0.8 * (-1 if i == 0 else 1)
		_arms[i].rotation.y = _oars[i].rotation.y * 0.4
	for crate in _snapshot.cargo:
		var node: Node3D = _crates[crate.id]
		var at: Vector2 = crate.position
		if crate.status == "carried":
			at -= Vector2.from_angle(_snapshot.heading) * 0.3
		node.position = Vector3(at.x, 0.3 if crate.status == "carried" else 0, at.y)
		node.scale = Vector3.ONE * (0.65 if crate.status == "carried" else 1.0)
	for i in _walls.size():
		var rect: Rect2 = _snapshot.breakwaters[i]
		_walls[i].position = Vector3(rect.get_center().x, 0.18, rect.get_center().y)
		_walls[i].scale = Vector3(rect.size.x, 0.46, rect.size.y)
	var force: Vector2 = _snapshot.water.force
	_force.rotation.y = -force.angle()
	_force.scale.x = clampf(force.length() * 4, 0.15, 1.6)
	for i in _waves.size():
		var phase: float = float(_snapshot.water.phase)
		_waves[i].position.x = -10 + i * 2.5 + (0 if _reduced_motion else sin(phase) * 0.25)
		_waves[i].scale.z = 1.4 if _snapshot.crest else 0.75
	var night := _time_phase == "night"
	_environment.background_color = Color("#1d3443") if night else Color("#b1c4c0")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.85 if night else 1.2
	_sun.rotation_degrees = Vector3(-38, {"dawn": -75.0, "noon": -55.0, "dusk": 45.0, "night": 75.0}.get(_time_phase, -55.0), 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	return "%s · 下次浪峰 %.1f 秒   |   潮位 %d%% · 缺口 %.2f   |   航向 %d°" % ["浪峰中" if _snapshot.crest else "平浪", _snapshot.crest_forecast, roundi(_snapshot.tide * 100), _snapshot.gap.navigable_half_width * 2, roundi(rad_to_deg(_snapshot.heading))]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), "靠岸速度 %.2f / %.2f　角度 %d° / %d°　最近碼頭 %d　%s　%s" % [_snapshot.speed, _snapshot.dock_speed_limit, roundi(rad_to_deg(_snapshot.dock_angle_error)), roundi(rad_to_deg(_snapshot.dock_angle_limit)), _snapshot.nearest_dock, "堤後遮蔽" if _snapshot.sheltered else "迎浪水域", _carrying_text()], 1200, 17)
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held := _pointer_owners.values().has(command)
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
		_text(rect.position + Vector2(10, 34), BUTTON_LABELS[i], rect.size.x - 16, 17)
	_text(Vector2(30, 673), feedback_text(_snapshot), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "舵需按住；槳與側滑每按一次出力。虛線為堤後長路；碼頭需慢速平行靠岸。", 1210, 17)
