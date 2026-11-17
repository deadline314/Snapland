extends Control
class_name CookieMoldView

signal command_requested(command: String, pressed: bool, source: String)
signal pointer_requested(action: String, point: Vector2, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 212, 880, 370)
const HEIGHT := 5.3
const CENTER_Y := 1.43
const COS_TILT := 0.894427191
const SIN_TILT := 0.4472135955
const COMMANDS := ["turn_left", "turn_right", "previous", "next", "tap", "tray_left", "tray_right", "helper", "retry"]
const BUTTON_KEYS := ["A", "D", "⇧Tab", "Tab", "Space", "←", "→", "R", "X"]
const BUTTON_ACTIONS := ["左翻", "右翻", "上一角", "下一角", "按住輕敲", "左移盤", "右移盤", "AI 扶盤", "重做此餅"]
const KEYS := {KEY_A: "turn_left", KEY_D: "turn_right", KEY_TAB: "next", KEY_SPACE: "tap", KEY_LEFT: "tray_left", KEY_RIGHT: "tray_right", KEY_R: "helper", KEY_X: "retry"}
var _snapshot: Dictionary = {}
var _pointer_owner := ""
var _pointer_command := ""
var _tab_command := "next"
var _world: Node3D
var _viewport: SubViewport
var _camera: Camera3D
var _environment: Environment
var _materials: Dictionary = {}
var _mold: Node3D
var _cookie: Node3D
var _tray: Node3D
var _left_hand: Node3D
var _right_hand: Node3D
var _cookie_layers: Array[MeshInstance3D] = []
var _rim: Array[MeshInstance3D] = []
var _gaps: Array[MeshInstance3D] = []
var _cracks: Array[MeshInstance3D] = []
var _edge_markers: Array[MeshInstance3D] = []
var _selection: MeshInstance3D
var _mold_floor: MeshInstance3D
var _shape_key := ""
var _seen_polygons: Array = [null, null, null, null, null, null]
var _right_fingers: Array[MeshInstance3D] = []
var _reduced_motion := false

static func button_rect(command: String) -> Rect2:
	return Rect2(24 + COMMANDS.find(command) * 137, 602, 130, 70)

static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""

# These helpers use the camera's exact orthographic basis, including polygon depth.
static func design_point(point: Vector2, depth: float = 0.0) -> Vector2:
	var scale_factor := STAGE.size.y / HEIGHT
	return STAGE.get_center() + Vector2(point.x, CENTER_Y - point.y * COS_TILT + depth * SIN_TILT) * scale_factor

static func work_point(point: Vector2, depth: float = 0.0) -> Vector2:
	var projected := (point - STAGE.get_center()) / (STAGE.size.y / HEIGHT)
	return Vector2(projected.x, (CENTER_Y + depth * SIN_TILT - projected.y) / COS_TILT)

static func mold_handle_world(state: Dictionary) -> Vector3:
	var angle := float(state.mold_angle)
	return Vector3(state.pivot.x - 1.05 * cos(angle), state.pivot.y + 1.05 * sin(angle), 0.0)

static func mold_handle_point(state: Dictionary) -> Vector2:
	var p := mold_handle_world(state)
	return design_point(Vector2(p.x, p.y), p.z)

static func mold_angle_at(point: Vector2, state: Dictionary) -> float:
	var relative := work_point(point) - Vector2(state.pivot)
	return atan2(relative.y, -relative.x)

static func edge_world(state: Dictionary, index: int) -> Vector3:
	var local: Vector2 = state.edges[index].point
	var angle := float(state.mold_angle)
	var gap := (1.0 - float(state.edges[index].adhesion)) * 0.055
	var center: Vector2 = state.outlet
	var height := float(state.thickness) * 0.5 + 0.025 + gap
	return Vector3(center.x + local.x * cos(angle) + height * sin(angle), center.y - local.x * sin(angle) + height * cos(angle), local.y)

static func edge_point(state: Dictionary, index: int) -> Vector2:
	var p := edge_world(state, index)
	return design_point(Vector2(p.x, p.y), p.z)

static func edge_at(point: Vector2, state: Dictionary) -> int:
	var closest := 22.0
	var found := -1
	for i in state.get("edges", []).size():
		var distance := point.distance_to(edge_point(state, i))
		if distance < closest:
			closest = distance
			found = i
	return found

static func tray_point(state: Dictionary) -> Vector2:
	return design_point(Vector2(float(state.tray_x) + 1.4, float(state.tray_y) - 0.05), 0.0)

static func pointer_source(event: InputEvent) -> String:
	if ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventMouseMotion) and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d" % event.index
	return ""

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if event is InputEventScreenTouch and event.canceled:
		if source != _pointer_owner:
			return false
		_pointer_owner = ""
		_pointer_command = ""
		pointer_requested.emit("cancel", point, source)
		queue_redraw()
		return true
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if source != _pointer_owner or not point.is_finite():
			return false
		pointer_requested.emit("move", point, source)
		return true
	if not event.pressed:
		if source != _pointer_owner:
			return false
		_pointer_owner = ""
		_pointer_command = ""
		pointer_requested.emit("release", point, source)
		queue_redraw()
		return true
	if not point.is_finite() or not _pointer_owner.is_empty() or _snapshot.is_empty():
		return false
	if command_at(point).is_empty() and point.distance_to(mold_handle_point(_snapshot)) > 32 and point.distance_to(tray_point(_snapshot)) > 42 and edge_at(point, _snapshot) < 0:
		return false
	_pointer_owner = source
	_pointer_command = command_at(point)
	pointer_requested.emit("press", point, source)
	queue_redraw()
	return true

func clear_pointer_input(emit_cancel: bool = true) -> void:
	_pointer_owner = ""
	_pointer_command = ""
	if emit_cancel:
		command_requested.emit("clear", false, "lifecycle")
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_pointer_input()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if KEYS.has(code) and not event.echo:
			var command: String = KEYS[code]
			if code == KEY_TAB:
				if event.pressed:
					_tab_command = "previous" if event.shift_pressed else "next"
				command = _tab_command
			command_requested.emit(command, event.pressed, "keyboard")
			accept_event()
	elif (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag) and handle_pointer(event, event.position):
		accept_event()

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not _snapshot.is_empty():
		_create_stage()
		_apply_snapshot()

func present(state: Dictionary, _time_phase: String, reduced_motion: bool) -> void:
	_snapshot = state
	_reduced_motion = reduced_motion
	if _world == null and is_inside_tree() and not state.is_empty():
		_create_stage()
	if _world != null:
		_apply_snapshot()
	queue_redraw()

func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _mesh(node_name: String, mesh: Mesh, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _box(node_name: String, dimensions: Vector3, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(node_name, mesh, at, parent, material)

func _hand(node_name: String) -> Node3D:
	var hand := Node3D.new()
	hand.name = node_name
	_world.add_child(hand)
	_box("Cuff", Vector3(0.32, 0.26, 0.43), Vector3(-0.38, 0, 0), hand, _materials.cuff)
	_box("Palm", Vector3(0.49, 0.25, 0.52), Vector3(-0.05, 0, 0), hand, _materials.glove)
	for finger in 4:
		var z := -0.21 + finger * 0.14
		var knuckle := _box("Finger%dKnuckle" % finger, Vector3(0.22, 0.16, 0.105), Vector3(0.22, -0.025, z), hand, _materials.finger)
		knuckle.rotation.z = -0.25
		var tip := _box("Finger%dTip" % finger, Vector3(0.15, 0.17, 0.11), Vector3(0.34, -0.10, z), hand, _materials.finger)
		tip.rotation.z = -0.85
		if node_name == "RightTappingHand":
			_right_fingers.append(tip)
	var thumb := _box("WrappedThumb", Vector3(0.25, 0.17, 0.15), Vector3(0.15, 0.16, 0.24), hand, _materials.glove)
	thumb.rotation.z = -0.45
	return hand

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
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "CookieWorkbench"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("#b99a8c")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#ffead2")
	_environment.ambient_light_energy = 0.75
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.shadow_enabled = true
	_world.add_child(sun)
	_camera = Camera3D.new()
	_camera.name = "CookieCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = HEIGHT
	_world.add_child(_camera)
	var center := Vector3(0, CENTER_Y * COS_TILT, -CENTER_Y * SIN_TILT)
	_camera.position = center + Vector3(0, SIN_TILT, COS_TILT) * 15.0
	_camera.look_at(center, Vector3.UP)
	_camera.current = true
	for item in [["table", "#5c4145"], ["mold", "#91b9be"], ["rim", "#d3eff0"], ["cookie", "#db9a4f"], ["cream", "#fff0cf"], ["tray", "#c9dbe4"], ["glove", "#fff3db"], ["finger", "#dccfb9"], ["cuff", "#af6474"], ["gap", "#352c36"], ["crack", "#74372e"], ["selected", "#ffe36b"]]:
		_materials[item[0]] = _material(item[1])
	_box("WorkbenchBack", Vector3(13, 6, 0.15), Vector3(0, 1.2, -1.5), _world, _materials.table)
	_mold = Node3D.new()
	_mold.name = "MoldAssembly"
	_world.add_child(_mold)
	_mold_floor = _mesh("ShapedMoldFloor", ArrayMesh.new(), Vector3.ZERO, _mold, _materials.mold)
	_box("MoldHandle", Vector3(0.65, 0.16, 0.25), Vector3(-1.05, -0.45, 0), _mold, _materials.rim)
	_cookie = Node3D.new()
	_cookie.name = "ActualCookie"
	_world.add_child(_cookie)
	for i in 3:
		_cookie_layers.append(_mesh("CookieLayer%d" % i, ArrayMesh.new(), Vector3.ZERO, _cookie, _materials.cream if i == 1 else _materials.cookie))
	for i in 32:
		_rim.append(_box("MoldSide%d" % i, Vector3.ONE, Vector3.ZERO, _mold, _materials.rim))
		_gaps.append(_box("AdhesionGap%d" % i, Vector3.ONE, Vector3.ZERO, _world, _materials.gap))
		_cracks.append(_box("CrackWarning%d" % i, Vector3.ONE, Vector3.ZERO, _world, _materials.crack))
		var marker := SphereMesh.new()
		marker.radius = 0.025
		marker.height = 0.05
		_edge_markers.append(_mesh("EdgePoint%d" % i, marker, Vector3.ZERO, _world, _materials.selected))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.09
	_selection = _mesh("SelectedEdge", ring, Vector3.ZERO, _world, _materials.selected)
	_tray = Node3D.new()
	_tray.name = "CatchTray"
	_world.add_child(_tray)
	_box("TrayBody", Vector3(2.3, 0.10, 1.7), Vector3(0, -0.08, 0), _tray, _materials.tray)
	for side in [-1, 1]:
		_box("TrayLipX", Vector3(0.08, 0.18, 1.7), Vector3(side * 1.15, -0.01, 0), _tray, _materials.rim)
		_box("TrayLipZ", Vector3(2.3, 0.18, 0.08), Vector3(0, -0.01, side * 0.85), _tray, _materials.rim)
	_box("TrayHandle", Vector3(0.5, 0.12, 0.25), Vector3(1.4, -0.05, 0), _tray, _materials.cuff)
	_left_hand = _hand("LeftGrippingHand")
	_right_hand = _hand("RightTappingHand")

func _scaled_polygon(polygon: PackedVector2Array, factor: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for p in polygon:
		scaled.append(p * factor)
	return scaled

func _extruded(polygon: PackedVector2Array, thickness: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := Geometry2D.triangulate_polygon(polygon)
	for face in [-1.0, 1.0]:
		for index in range(0, indices.size(), 3):
			for offset in ([2, 1, 0] if face < 0 else [0, 1, 2]):
				var p := polygon[indices[index + offset]]
				vertices.append(Vector3(p.x, face * thickness * 0.5, p.y))
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		for p in [Vector3(a.x, -thickness * 0.5, a.y), Vector3(b.x, -thickness * 0.5, b.y), Vector3(b.x, thickness * 0.5, b.y), Vector3(a.x, -thickness * 0.5, a.y), Vector3(b.x, thickness * 0.5, b.y), Vector3(a.x, thickness * 0.5, a.y)]:
			vertices.append(p)
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	# Flat face normals keep the concave silhouette and side thickness readable.
	var normals := PackedVector3Array()
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _line(node: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	node.position = (a + b) * 0.5
	node.scale = Vector3(width, maxf(a.distance_to(b), 0.001), width)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized()) if a.distance_to(b) > 0.00001 else Quaternion.IDENTITY

func _apply_snapshot() -> void:
	var polygon := PackedVector2Array(_snapshot.polygon)
	var key := "%d:%d" % [int(_snapshot.shape_index), int(_snapshot.variant)]
	var thickness := float(_snapshot.thickness)
	if key != _shape_key:
		_shape_key = key
		_seen_polygons[int(_snapshot.shape_index)] = polygon
		_mold_floor.mesh = _extruded(_scaled_polygon(polygon, 1.13), 0.09)
		_mold_floor.position.y = -thickness * 0.5 - 0.06
		var single := (thickness - 0.035) * 0.5 if _snapshot.double_layer else thickness
		_cookie_layers[0].mesh = _extruded(polygon, single)
		_cookie_layers[0].position.y = -(single + 0.035) * 0.5 if _snapshot.double_layer else 0.0
		_cookie_layers[1].mesh = _extruded(_scaled_polygon(polygon, 0.97), 0.035)
		_cookie_layers[2].mesh = _extruded(polygon, single)
		_cookie_layers[2].position.y = (single + 0.035) * 0.5
		for i in 32:
			_rim[i].visible = i < polygon.size()
			if i < polygon.size():
				var a := polygon[i]
				var b := polygon[(i + 1) % polygon.size()]
				_rim[i].mesh = _extruded(PackedVector2Array([a * 1.14, b * 1.14, b * 1.035, a * 1.035]), thickness + 0.12)
	_mold.position = Vector3(_snapshot.outlet.x, _snapshot.outlet.y, 0)
	_mold.rotation.z = -float(_snapshot.mold_angle)
	_cookie.position = Vector3(_snapshot.cookie_position.x, _snapshot.cookie_position.y, 0)
	_cookie.rotation.z = -float(_snapshot.cookie_angle)
	_cookie.visible = _snapshot.phase not in ["missed"]
	_cookie_layers[1].visible = _snapshot.double_layer
	_cookie_layers[2].visible = _snapshot.double_layer
	_tray.position = Vector3(_snapshot.tray_x, _snapshot.tray_y, 0)
	var molded: bool = _snapshot.phase == "molded"
	for i in 32:
		var visible_edge: bool = i < _snapshot.edges.size() and _snapshot.phase in ["molded", "cracked"]
		_gaps[i].visible = visible_edge
		_cracks[i].visible = visible_edge and float(_snapshot.edges[i].stress) >= float(_snapshot.crack_limit) * 0.65
		_edge_markers[i].visible = visible_edge
		if not visible_edge:
			continue
		var edge: Dictionary = _snapshot.edges[i]
		var p := edge_world(_snapshot, i)
		_edge_markers[i].position = p
		var along := Vector3(cos(_snapshot.mold_angle), -sin(_snapshot.mold_angle), 0)
		_line(_gaps[i], p - along * 0.055, p + along * 0.055, maxf(0.005, (1.0 - float(edge.adhesion)) * 0.055))
		_line(_cracks[i], p, p - along * (0.10 + float(edge.stress) * 0.12) + Vector3(0, 0, -0.09), 0.022)
	_selection.visible = molded
	if molded:
		_selection.position = edge_world(_snapshot, int(_snapshot.selected_edge))
		_selection.rotation.z = -float(_snapshot.mold_angle)
	_left_hand.position = mold_handle_world(_snapshot) + Vector3(-0.10, 0, 0)
	_left_hand.rotation.z = -float(_snapshot.mold_angle)
	if molded and _snapshot.charging and absf(float(_snapshot.tray_target) - float(_snapshot.tray_x)) < 0.03:
		var selected := edge_world(_snapshot, int(_snapshot.selected_edge))
		_right_hand.position = selected + Vector3(0.22, 0.14 + float(_snapshot.charge) * 0.20, 0.0)
		_right_hand.rotation.z = -0.3 - float(_snapshot.charge) * 0.55
	else:
		_right_hand.position = _tray.position + Vector3(1.45, 0.09, 0)
		_right_hand.rotation.z = PI
	for tip in _right_fingers:
		tip.rotation.z = -0.85 - float(_snapshot.charge) * 0.7

func text_size(font_size: int) -> int:
	var physical_scale := Paper.physical_scale(self) * get_global_transform_with_canvas().x.length()
	return ceili(maxf(font_size, 14.0 / maxf(physical_scale, 0.01)) * Paper.text_scale())

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, text_size(font_size), color)

func status_text() -> String:
	return "先鬆黏角，再翻模滑接" if _snapshot.is_empty() else "%s · %s" % [_snapshot.shape_name, "雙層：借慣性取出" if _snapshot.double_layer else "先鬆黏角，再翻模滑接"]

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 64), Paper.DEEP_TEAL)
	_text(Vector2(38, 166), status_text(), 1200, 18, Paper.GOLD)
	_text(Vector2(38, 196), "拖把手翻模 · 點角按住再放開 · 拖盤柄滑接", 1200, 17)
	draw_rect(Rect2(918, 212, 338, 370), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(932, 244), "完整接住 %d／6" % _snapshot.caught, 310, 21, Paper.GOLD)
		_text(Vector2(932, 278), "模角 %d° · 慣性 %.1f" % [roundi(rad_to_deg(_snapshot.mold_angle)), absf(_snapshot.mold_omega)], 310, 17)
		_text(Vector2(932, 310), "AI 只扶盤，翻模由你", 310, 17)
		_text(Vector2(932, 342), "蓄力：放開才敲", 310, 18)
		draw_rect(Rect2(932, 354, 306, 16), Paper.FRAME)
		draw_rect(Rect2(932, 354, 306 * clampf(float(_snapshot.charge) / 0.9, 0, 1), 16), Paper.GOLD)
		var selected: Dictionary = _snapshot.edges[int(_snapshot.selected_edge)]
		_text(Vector2(932, 402), "角 %d · 黏附 %d%%" % [int(_snapshot.selected_edge) + 1, roundi(float(selected.adhesion) * 100)], 310, 18)
		_text(Vector2(932, 434), "裂損 %d%% · 換角輕敲" % roundi(float(selected.stress) / float(_snapshot.crack_limit) * 100), 310, 17, Paper.CORAL)
		for i in 6:
			var at := Vector2(946 + i * 49, 472)
			if _seen_polygons[i] != null:
				var outline := PackedVector2Array()
				for point: Vector2 in _seen_polygons[i]:
					outline.append(at + Vector2(point.x, -point.y) * 30.0)
				outline.append(outline[0])
				draw_polyline(outline, Paper.TEAL if _snapshot.completed[i] else Paper.GOLD, 2.0, true)
			else:
				draw_circle(at, 13, Paper.FRAME)
				_text(at + Vector2(-6, 7), str(i + 1), 28, 15)
		_text(Vector2(932, 520), "失手：X 免費重做", 310, 17)
		_text(Vector2(932, 553), "保留進度，時間不回復", 310, 17)
	for i in COMMANDS.size():
		var rect := button_rect(COMMANDS[i])
		var held: bool = _pointer_command == COMMANDS[i] and not _pointer_owner.is_empty()
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
		_text(rect.position + Vector2(7, 24), BUTTON_KEYS[i], 118, 14)
		_text(rect.position + Vector2(7, 57), BUTTON_ACTIONS[i], 118, 16)
	_text(Vector2(28, 708), str(_snapshot.get("feedback", "")), 1220, 17, Paper.GOLD)
