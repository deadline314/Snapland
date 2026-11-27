extends Control
class_name SugarBridgeView

signal command_requested(command: String, pressed: bool, source: String)
signal pointer_requested(action: String, point: Vector2, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const StageProps = preload("res://game/minigames/stage_props.gd")
const STATUS_PLATE := Rect2(24, 140, 1232, 62)
const SIDE_PANEL := Rect2(966, 210, 290, 364)
const BUTTON_ICONS := ["swap", "grab", "anchor", "up", "undo", "helper"]
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 210, 928, 364)
const WORLD := Rect2(-6.3077, -3.2, 21.4154, 8.4)
const COMMANDS := ["next", "grab", "pin", "load", "recall", "helper"]
const KEYS := {KEY_TAB: "next", KEY_SPACE: "grab", KEY_F: "pin", KEY_ENTER: "load", KEY_KP_ENTER: "load", KEY_X: "recall", KEY_R: "helper",
	KEY_LEFT: "left", KEY_RIGHT: "right", KEY_UP: "up", KEY_DOWN: "down"}
const BUTTON_KEYS := ["Tab", "Space", "F", "Enter", "X", "R"]
const BUTTON_ACTIONS := ["換端", "抓／放", "固定／鬆開", "上料／重送", "回收糖帶", "AI 保持端點"]
const SEGMENTS := 32
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _pointer_owners: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _materials: Dictionary = {}
var _bands: Array = []
var _handles: Array[MeshInstance3D] = []
var _supports: Array[Node3D] = []
var _balls: Array[MeshInstance3D] = []
var _preview: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _endpoint_labels: Array[Label3D] = []
var _bean: MeshInstance3D
var _hopper: Node3D
var _selection: MeshInstance3D

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 206, 590, 198, 56)

static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""

static func design_point(point: Vector2) -> Vector2:
	var normalized := (point - WORLD.position) / WORLD.size
	return STAGE.position + Vector2(normalized.x, 1.0 - normalized.y) * STAGE.size

static func work_point(point: Vector2) -> Vector2:
	var normalized := (point - STAGE.position) / STAGE.size
	return WORLD.position + Vector2(normalized.x, 1.0 - normalized.y) * WORLD.size

static func endpoint_at(point: Vector2, state: Dictionary) -> int:
	var closest := 30.0
	var result := -1
	for endpoint: Dictionary in state.get("endpoints", []):
		var distance := point.distance_to(design_point(endpoint.position))
		if distance < closest:
			closest = distance
			result = int(endpoint.id)
	if result >= 0:
		for endpoint: Dictionary in state.get("endpoints", []):
			var distance := point.distance_to(design_point(endpoint.position))
			if int(endpoint.id) == int(state.get("selected", -1)) and distance < 30.0 and absf(distance - closest) <= 0.001:
				return int(endpoint.id)
	return result

func _get_tooltip(at_position: Vector2) -> String:
	if button_rect("next").has_point(at_position):
		return "共用支點先換端，再抓端點。"
	if STATUS_PLATE.has_point(at_position):
		return "搭長橋或中央短橋，三球送到右岸。Enter 上料，也可免費重送落球。先彈中料斗，再用同帶運送三球得小惡魔；X 回收會清除命中。"
	if SIDE_PANEL.has_point(at_position):
		return "糖帶越長越細、越下垂。金色端點已固定，白色抓取中，藍色由 AI 保持，圓圈是選中的端點。"
	return ""

static func pointer_source(event: InputEvent) -> String:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventMouseMotion) and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d" % event.index
	return ""

func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	var source := pointer_source(event)
	if source.is_empty():
		return false
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not _pointer_owners.has(source) or not point.is_finite():
			return false
		pointer_requested.emit("move", point, source)
		return true
	if not event.pressed:
		if not _pointer_owners.has(source):
			return false
		_pointer_owners.erase(source)
		pointer_requested.emit("release", point, source)
		queue_redraw()
		return true
	if not point.is_finite() or _pointer_owners.has(source):
		return false
	if command_at(point).is_empty() and (not STAGE.has_point(point) or endpoint_at(point, _snapshot) < 0):
		return false
	_pointer_owners[source] = command_at(point)
	pointer_requested.emit("press", point, source)
	queue_redraw()
	return true

func clear_pointer_input(emit_cancel: bool = true) -> void:
	_pointer_owners.clear()
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
			command_requested.emit(KEYS[code], event.pressed, "key:%d" % code)
			accept_event()
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		if handle_pointer(event, event.position):
			accept_event()

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not _snapshot.is_empty():
		_create_stage()
		_apply_snapshot()

func present(state: Dictionary, time_phase: String, _reduced_motion: bool) -> void:
	_snapshot = state
	_time_phase = time_phase
	if _world == null and is_inside_tree() and not state.is_empty():
		_create_stage()
	if _world != null:
		_apply_snapshot()
	queue_redraw()

func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.5
	return material

func _mesh(node_name: String, mesh: Mesh, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _box(node_name: String, size: Vector3, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(node_name, mesh, at, parent, material)

func _sphere(node_name: String, radius: float, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh(node_name, mesh, at, parent, material)

func _label(text: String, at: Vector3, parent: Node3D) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = 34
	label.pixel_size = 0.015
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
	_labels.append(label)
	return label

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
	_viewport.name = "SugarViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "SugarWorkbench"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#f1d1ba")
	_environment.ambient_light_energy = 0.65
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-40, -25, 0)
	_sun.shadow_enabled = true
	_world.add_child(_sun)
	StageProps.dress_lighting(_environment, _sun)
	_camera = Camera3D.new()
	_camera.name = "SugarCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = WORLD.size.y
	_camera.position = Vector3(WORLD.get_center().x, WORLD.get_center().y, 24)
	_world.add_child(_camera)
	_camera.current = true
	for item in [["table", "#653d45"], ["edge", "#bd8066"], ["support", "#f1dcaa"], ["pin", "#e6ae3f"], ["pink", "#e995a9"], ["mint", "#6ecab1"], ["selected", "#ffdc64"], ["held", "#fff4df"], ["helper", "#82a7f0"], ["ball", "#ba653c"], ["bean", "#e6bf55"], ["hopper", "#c68758"], ["hit", "#8bd9a8"], ["broken", "#9b8e87"]]:
		_materials[item[0]] = StageProps.candy(Color(item[1])) if item[0] in ["pink", "mint", "hit", "held", "helper", "selected", "bean"] else _material(item[1])
	_materials["sculpt"] = StageProps.sculpt_material()
	# Pastel tiled factory wall, a cream wainscot and a planked biscuit bench.
	_box("WorkbenchBack", Vector3(24, 10, 0.2), Vector3(4.4, 1.0, -1.6), _world, StageProps.tiled_wall())
	_box("Wainscot", Vector3(24, 1.6, 0.3), Vector3(4.4, -2.4, -1.45), _world, StageProps.wood(Color("#efd9b8"), 0.3, true))
	_box("WorkbenchEdge", Vector3(24, 0.3, 3), Vector3(4.4, -3, -0.4), _world, StageProps.wood(Color("#7a5238")))
	_box("BenchFront", Vector3(24, 1.2, 0.2), Vector3(4.4, -3.7, 1.1), _world, StageProps.wood(Color("#8f6444"), 0.3, true))
	var pillar := StageProps.candy_pillar_mesh(0.4, 2.4, Color("#f4e2c2"), Color("#e58aa0"))
	for i in 3:
		var support := Node3D.new()
		support.name = "Support%d" % i
		_world.add_child(support)
		StageProps.add(support, "Pedestal", pillar, _materials.sculpt, Vector3(0, -2.4, -0.4))
		_box("Top", Vector3(1.1, 0.16, 1.5), Vector3(0, -0.08, -0.25), support, _materials.pin)
		_sphere("Pin", 0.12, Vector3.ZERO, support, _materials.pin)
		_label(["左岸", "中央", "右岸"][i], Vector3(0, -1.85, 0.4), support)
		_supports.append(support)
	for band in 2:
		var links: Array[MeshInstance3D] = []
		for i in SEGMENTS:
			links.append(_box("Sugar%dSegment%d" % [band, i], Vector3(1, 1, 0.22), Vector3.ZERO, _world, _materials.pink if band == 0 else _materials.mint))
		_bands.append(links)
	for i in 4:
		_handles.append(_sphere("Endpoint%d" % i, 0.23, Vector3.ZERO, _world, _materials.pink if i < 2 else _materials.mint))
		_endpoint_labels.append(_label(str(i + 1), Vector3(0, 0.43, 0.3), _handles[-1]))
	var sweet := StageProps.sweet_mesh(0.21, Color("#d0703f"), Color("#f6dcb0"))
	for i in 3:
		_balls.append(StageProps.add(_world, "DeliveryBall%d" % i, sweet, _materials.sculpt))
	_bean = _sphere("TrialBean", 0.16, Vector3.ZERO, _world, _materials.bean)
	for i in 30:
		_preview.append(_sphere("Preview%d" % i, 0.045, Vector3.ZERO, _world, _materials.bean))
	_hopper = Node3D.new()
	_hopper.name = "SideHopper"
	_world.add_child(_hopper)
	StageProps.add(_hopper, "Bowl", StageProps.copper_pan_mesh(0.5, 0.6), _materials.sculpt, Vector3(0, -0.375, -0.15))
	_label("試料斗", Vector3(0, 0.65, 0.2), _hopper)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.29
	ring.outer_radius = 0.36
	_selection = _mesh("SelectedEndpoint", ring, Vector3.ZERO, _world, _materials.selected)
	_selection.rotation.x = PI / 2.0

func _at(point: Vector2, depth: float = 0.0) -> Vector3:
	return Vector3(point.x, point.y, depth)

func _apply_snapshot() -> void:
	for i in mini(3, _snapshot.anchors.size()):
		_supports[i].position = _at(_snapshot.anchors[i])
	for band: Dictionary in _snapshot.bands:
		var links: Array = _bands[int(band.id)]
		var points: Array = band.points
		for i in SEGMENTS:
			var link: MeshInstance3D = links[i]
			link.visible = i + 1 < points.size() and not band.broken
			if not link.visible:
				continue
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			link.position = _at((a + b) * 0.5)
			link.rotation.z = (b - a).angle()
			link.scale = Vector3(maxf(a.distance_to(b), 0.001), clampf(band.thickness * 0.18, 0.045, 0.35), 1)
			link.material_override = _materials.hit if band.hit else (_materials.pink if band.id == 0 else _materials.mint)
	for endpoint: Dictionary in _snapshot.endpoints:
		var i := int(endpoint.id)
		_handles[i].position = _at(endpoint.position, 0.18)
		_handles[i].material_override = _materials.held if endpoint.held else (_materials.helper if _snapshot.helper[i] else (_materials.pin if endpoint.pin >= 0 else (_materials.pink if i < 2 else _materials.mint)))
		var coincident: Array[int] = []
		for other: Dictionary in _snapshot.endpoints:
			if Vector2(endpoint.position).distance_to(other.position) < 0.45:
				coincident.append(int(other.id))
		_endpoint_labels[i].position.x = (coincident.find(i) - (coincident.size() - 1) * 0.5) * 0.65
	_selection.position = _at(_snapshot.endpoints[int(_snapshot.selected)].position, 0.5)
	_selection.visible = not _snapshot.ended
	for ball: Dictionary in _snapshot.balls:
		var node := _balls[int(ball.id)]
		node.position = _at(ball.position, 0.25)
		node.visible = ball.state not in ["unused", "fallen"]
	_bean.position = _at(_snapshot.bean.position, 0.3)
	_bean.visible = _snapshot.bean.active
	_hopper.position = _at(_snapshot.hopper)
	_hopper.scale = Vector3.ONE * (float(_snapshot.hopper_radius) / 0.45)
	for i in _preview.size():
		_preview[i].visible = i < _snapshot.preview.size()
		if _preview[i].visible:
			_preview[i].position = _at(_snapshot.preview[i], 0.25)
	var night := _time_phase == "night"
	_environment.background_color = Color("#302b42") if night else Color("#c99a96")
	_sun.light_color = Color("#b6c9ed") if night else Color("#fff0d4")
	_sun.light_energy = 0.8 if night else 1.1
	var physical_scale := Paper.physical_scale(self) * get_global_transform_with_canvas().x.length()
	for label in _labels:
		var projected_scale := float(_viewport.size.y) / _camera.size * physical_scale * label.global_transform.basis.y.length()
		label.pixel_size = maxf(0.015, 14.0 / maxf(float(label.font_size) * projected_scale, 0.01)) * Paper.text_scale()

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var endpoint: Dictionary = _snapshot.endpoints[int(_snapshot.selected)]
	var state := "抓住中" if endpoint.held else ("固定" if endpoint.pin >= 0 else "自由")
	return "端點 %d · %s%s　｜　方向鍵移動；近支點放手固定，遠處放手彈射" % [int(endpoint.id) + 1, state, " · AI" if _snapshot.helper[int(endpoint.id)] else ""]

func text_size(font_size: int) -> int:
	var physical_scale := Paper.physical_scale(self) * get_global_transform_with_canvas().x.length()
	return ceili(maxf(font_size, 14.0 / maxf(physical_scale, 0.01)) * Paper.text_scale())

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, text_size(font_size), color)

func _draw() -> void:
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_PLUM, true)
	_text(Vector2(40, 166), status_text(), 1190, 17)
	_text(Vector2(40, 193), str(_snapshot.get("feedback", "")), 1190, 18, Paper.GOLD)
	Props.wood_panel(self, SIDE_PANEL, Props.SIGN_PLUM, true)
	if not _snapshot.is_empty():
		_text(Vector2(982, 240), "糖帶材料", 250, 20, Paper.GOLD)
		for i in 2:
			var band: Dictionary = _snapshot.bands[i]
			var y := 280 + i * 92
			Props.token(self, Vector2(990, y - 6), 7.0, Color("#e995a9") if i == 0 else Color("#6ecab1"))
			_text(Vector2(1004, y), "糖帶 %d  %s" % [i + 1, "已斷 · X 回收" if band.broken else ("已命中料斗" if band.hit else "可拉伸")], 240, 17)
			_text(Vector2(982, y + 30), ("長 %.1f · 厚 %.2f · 載 %.1f／%.1f" % [band.length, band.thickness, band.load, band.capacity]) if _snapshot.assisted else ("長 %.1f · 厚 %.2f" % [band.length, band.thickness]), 260, 16)
		_text(Vector2(982, 480), "重 %.2f · 彈 %.2f" % [_snapshot.weight, _snapshot.elasticity], 250, 16)
	for i in COMMANDS.size():
		var rect := button_rect(COMMANDS[i])
		var held := _pointer_owners.values().has(COMMANDS[i])
		Props.control_key(self, rect, held, BUTTON_ICONS[i], BUTTON_ACTIONS[i], Paper.font(), text_size(15), true, Props.KEY_PLUM)
		draw_string(Paper.font(), rect.position + Vector2(0, 17 + (6 if held else 0)), BUTTON_KEYS[i], HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 10, text_size(12), Color(Paper.GOLD, 0.85))
