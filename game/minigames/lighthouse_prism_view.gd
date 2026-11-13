extends Control
class_name LighthousePrismView

## 3D light-path miniature. Beam segments, element orientations and beacon gauges
## come straight from the model snapshot; the view never traces light itself.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/lighthouse_prism_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const GAUGE := Rect2(1046, 222, 198, 336)
const COMMANDS := ["previous", "next", "rotate_left", "rotate_right", "undo", "settle"]
const BUTTON_LABELS := ["A / ← 上一件", "D / → 下一件", "Q 逆轉", "E／空白 順轉·開合", "Z 回復上一鏡位", "Enter 點燈結算"]
const ORIENTATION_GLYPHS := ["—", "\\", "|", "/"]
const PICK_RADIUS := 34.0
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _pointer_owners: Dictionary = {}
var _viewport: SubViewport
var _container: SubViewportContainer
var _world: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _materials: Dictionary = {}
var _element_nodes: Dictionary = {}
var _element_bodies: Dictionary = {}
var _element_labels: Dictionary = {}
var _beacon_lamps: Dictionary = {}
var _beacon_labels: Dictionary = {}
var _fog_nodes: Array[MeshInstance3D] = []
var _beams: Array[MeshInstance3D] = []
var _selection: MeshInstance3D
var _fog_variant := -1

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 206, 590, 198, 56)

static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""

static func pointer_source(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch:
		return "touch:%d" % event.index
	return ""

static func cell_to_world(cell: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(cell.x - (Model.SIZE.x - 1) * 0.5, height, cell.y - (Model.SIZE.y - 1) * 0.5)

## Screen pick of an element on the stage, using the actual camera projection.
func element_at(point: Vector2) -> String:
	if _camera == null or _snapshot.is_empty() or not STAGE.has_point(point):
		return ""
	var ratio := Vector2(_viewport.size) / STAGE.size
	var local := (point - STAGE.position) * ratio
	var best := ""
	var best_distance := PICK_RADIUS * ratio.x
	for element: Dictionary in _snapshot.elements:
		var screen := _camera.unproject_position(cell_to_world(element.cell, 0.5))
		var distance := screen.distance_to(local)
		if distance < best_distance:
			best_distance = distance
			best = element.id
	return best

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
	if not point.is_finite():
		return false
	var command := command_at(point)
	if command.is_empty():
		var picked := element_at(point)
		if picked.is_empty():
			return false
		command = "select:" + picked
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

func _material(color: Color, alpha: float = 1.0, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.8
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

func _mesh_node(node_name: String, mesh: Mesh, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
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
	return _mesh_node(node_name, mesh, at, parent, material)

func _cylinder(node_name: String, radius: float, height: float, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh_node(node_name, mesh, at, parent, material)

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.011
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
	return label

func _create_stage() -> void:
	_container = SubViewportContainer.new()
	_container.name = "SpatialStage"
	_container.position = STAGE.position
	_container.size = STAGE.size
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.show_behind_parent = true
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.name = "PrismViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	_container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "PrismMiniature"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#c9d7da")
	_environment.ambient_light_energy = 0.5
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "PrismSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 30
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "PrismCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# A 40 degree miniature view keeps the 11x7 board large beside the gauge panel.
	_camera.size = 6.4
	var focus := Vector3(1.6, 0.3, 0.25)
	_camera.position = focus + Vector3(0, sin(deg_to_rad(40.0)), cos(deg_to_rad(40.0))) * 30.0
	_world.add_child(_camera)
	_camera.look_at(focus)
	_camera.current = true
	for item in [["water", "#2f5f73"], ["deck", "#8e9a93"], ["seam", "#5e6b67"], ["tower", "#ece2c8"], ["roof", "#d9785f"],
			["frame", "#4b3c2f"], ["mirror", "#cfe3ea"], ["shutter", "#7a5a3d"], ["buoy", "#e3c169"], ["buoy_dark", "#5f6f72"],
			["select", "#ffd36a"], ["lock", "#ff9b7a"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_materials.prism = _material(Color("#8fe3e8"), 0.55)
	_materials.lamp = _material(Color("#fff2b0"), 1.0, 2.5)
	_materials.lit = _material(Color("#ffe27a"), 1.0, 3.0)
	_materials.unlit = _material(Color("#3c4a50"))
	_materials.fog = _material(Color("#eef3f5"), 0.38)
	_materials.beam = _material(Color("#fff0a0"), 0.85, 2.2)
	var water := PlaneMesh.new()
	water.size = Vector2(40, 30)
	_mesh_node("Water", water, Vector3(0, -0.3, 0), _world, _materials.water)
	_box("Deck", Vector3(Model.SIZE.x + 0.4, 0.3, Model.SIZE.y + 0.4), Vector3(0, -0.15, 0), _world, _materials.deck)
	for x in Model.SIZE.x + 1:
		_box("Seam", Vector3(0.03, 0.02, Model.SIZE.y), Vector3(x - Model.SIZE.x * 0.5, 0.005, 0), _world, _materials.seam)
	for y in Model.SIZE.y + 1:
		_box("Seam", Vector3(Model.SIZE.x, 0.02, 0.03), Vector3(0, 0.005, y - Model.SIZE.y * 0.5), _world, _materials.seam)
	var lamp := cell_to_world(_snapshot.source)
	_cylinder("LighthouseTower", 0.36, 1.6, lamp + Vector3(0, 0.8, 0), _world, _materials.tower)
	_cylinder("LighthouseRoof", 0.42, 0.18, lamp + Vector3(0, 1.75, 0), _world, _materials.roof)
	var light := SphereMesh.new()
	light.radius = 0.22
	light.height = 0.44
	_mesh_node("LighthouseLamp", light, lamp + Vector3(0, 1.45, 0), _world, _materials.lamp)
	_label3d("燈塔", lamp + Vector3(0, 2.2, 0), _world)
	for element: Dictionary in _snapshot.elements:
		var node := Node3D.new()
		node.name = "Element_%s" % element.id
		node.position = cell_to_world(element.cell)
		_world.add_child(node)
		var body := Node3D.new()
		body.name = "Body"
		node.add_child(body)
		match element.kind:
			"mirror":
				_box("Frame", Vector3(0.92, 0.7, 0.1), Vector3(0, 0.4, 0), body, _materials.frame)
				_box("Glass", Vector3(0.84, 0.6, 0.12), Vector3(0, 0.42, 0), body, _materials.mirror)
			"splitter":
				_box("Prism", Vector3(0.9, 0.8, 0.22), Vector3(0, 0.45, 0), body, _materials.prism)
				_box("Base", Vector3(0.6, 0.06, 0.6), Vector3(0, 0.03, 0), node, _materials.frame)
			"shutter":
				for side in [-0.42, 0.42]:
					_box("Post", Vector3(0.08, 0.9, 0.08), Vector3(side, 0.45, 0), node, _materials.frame)
				_box("Panel", Vector3(0.78, 0.7, 0.06), Vector3(0, 0.45, 0), body, _materials.shutter)
		_element_nodes[element.id] = node
		_element_bodies[element.id] = body
		_element_labels[element.id] = _label3d("", Vector3(0, 1.25, 0), node, 26)
	for beacon: Dictionary in _snapshot.beacons:
		var node := Node3D.new()
		node.name = "Beacon_%s" % beacon.id
		node.position = cell_to_world(beacon.cell)
		_world.add_child(node)
		var factor := 0.7 if beacon.hidden else 1.0
		_cylinder("Buoy", 0.3 * factor, 0.9 * factor, Vector3(0, 0.45 * factor, 0), node, _materials.buoy_dark if beacon.hidden else _materials.buoy)
		var cap := SphereMesh.new()
		cap.radius = 0.2 * factor
		cap.height = 0.4 * factor
		_beacon_lamps[beacon.id] = _mesh_node("BeaconLamp", cap, Vector3(0, 1.0 * factor, 0), node, _materials.unlit)
		_beacon_labels[beacon.id] = _label3d("", Vector3(0, 1.55, 0), node, 28)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.58
	_selection = _mesh_node("SelectionRing", ring, Vector3.ZERO, _world, _materials.select)
	for i in Model.MAX_SEGMENTS:
		var beam := _box("Beam%d" % i, Vector3.ONE, Vector3.ZERO, _world, _materials.beam)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.visible = false
		_beams.append(beam)

func _build_fog() -> void:
	_fog_variant = int(_snapshot.variant)
	for node in _fog_nodes:
		_world.remove_child(node)
		node.queue_free()
	_fog_nodes.clear()
	for cell: Vector2i in _snapshot.fog:
		var fog := _box("Fog%d" % _fog_nodes.size(), Vector3(1.0, 0.5, 1.0), cell_to_world(cell, 0.35), _world, _materials.fog)
		fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fog_nodes.append(fog)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.variant) != _fog_variant:
		_build_fog()
	var drift := 0.0 if _reduced_motion else sin(float(_snapshot.elapsed) * 0.8) * 0.06
	for node in _fog_nodes:
		node.position.y = 0.35 + drift
	for element: Dictionary in _snapshot.elements:
		var body: Node3D = _element_bodies[element.id]
		var label: Label3D = _element_labels[element.id]
		# Only the selected element carries its full name; others keep a short glyph.
		var glyph: String = ("開" if element.state == 1 else "關") if element.kind == "shutter" else ORIENTATION_GLYPHS[element.state]
		if element.kind == "shutter":
			body.position.y = 0.0 if element.state == 0 else -0.7
		else:
			# Line orientation s*45 degrees in grid space (+y is south, i.e. +Z).
			body.rotation.y = -deg_to_rad(45.0 * element.state)
		label.text = "%s %s" % [element.name, glyph] if element.selected else glyph
		if element.locked:
			label.text += " 鎖"
		label.modulate = Paper.GOLD if element.selected else (Color("#ffb39e") if element.locked else Paper.PAPER)
		if element.selected:
			_selection.position = cell_to_world(element.cell, 0.02)
	for beacon: Dictionary in _snapshot.beacons:
		_beacon_lamps[beacon.id].material_override = _materials.lit if beacon.lit else _materials.unlit
		var shown := "？" if beacon.hidden and beacon.received <= 0.0 else "%d%%" % roundi(beacon.received * 100)
		_beacon_labels[beacon.id].text = "%s %s" % [beacon.name if not beacon.hidden or beacon.received > 0.0 else "側標", shown]
		_beacon_labels[beacon.id].modulate = Paper.GOLD if beacon.lit else Paper.PAPER
	var segments: Array = _snapshot.segments
	for i in _beams.size():
		var beam: MeshInstance3D = _beams[i]
		beam.visible = i < segments.size()
		if not beam.visible:
			continue
		var segment: Dictionary = segments[i]
		var from := cell_to_world(segment.from, 0.55)
		var to := cell_to_world(segment.to, 0.55)
		var width := clampf(0.05 + float(segment.power) * 0.16, 0.05, 0.21)
		beam.position = (from + to) * 0.5
		beam.scale = Vector3(maxf(0.01, from.distance_to(to)), width, width)
		beam.rotation = Vector3(0, -atan2(to.z - from.z, to.x - from.x), 0)
	var night := _time_phase == "night"
	_environment.background_color = Color("#16293a") if night else Color("#a9bfc2")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.7 if night else 1.1
	_sun.rotation_degrees = Vector3(-48, {"dawn": -70.0, "noon": -30.0, "dusk": 40.0, "night": 70.0}.get(_time_phase, -30.0), 0)

func _element_name(id: String) -> String:
	for element: Dictionary in _snapshot.get("elements", []):
		if element.id == id:
			return "%s %s" % [element.name, ("開" if element.state == 1 else "關") if element.kind == "shutter" else ORIENTATION_GLYPHS[element.state]]
	return ""

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	return "選取：%s   |   %s（直向光較弱）   |   分束 %d 次   |   亮起 %d / 3%s" % [_element_name(_snapshot.selected), _snapshot.fog_name, _snapshot.splits, _snapshot.main_lit, "，側標亮" if _snapshot.hidden_lit else ""]

func beacon_text() -> String:
	if _snapshot.is_empty():
		return ""
	var parts: Array[String] = []
	for beacon: Dictionary in _snapshot.beacons:
		if beacon.hidden and beacon.received <= 0.0:
			parts.append("側標 ？")
		else:
			parts.append("%s %d%%%s" % [beacon.name, roundi(beacon.received * 100), "亮" if beacon.lit else ""])
	return "接收（門檻 %d%%）：%s" % [roundi(Model.THRESHOLD * 100), "　".join(parts)]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), beacon_text(), 1200, 17)
		_draw_gauges()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held := _pointer_owners.values().has(command)
		var unavailable: bool = command == "undo" and not _snapshot.get("assisted", false)
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else (Paper.DEEP if unavailable else Paper.TEAL), false, 2)
		_text(rect.position + Vector2(10, 34), BUTTON_LABELS[i] + ("（輔助）" if unavailable else ""), rect.size.x - 16, 16, Color(Paper.PAPER, 0.55) if unavailable else Paper.PAPER)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "選鏡後 Q／E 轉 45 度，遮光板按空白開合；可直接點選鏡面。光線越粗越亮，經霧帶、分束與航標都會減弱。", 1210, 17)

## Bars show received light against the threshold, so lit state never relies on color.
func _draw_gauges() -> void:
	draw_rect(GAUGE, Color(Paper.DEEP, 0.86))
	draw_rect(GAUGE, Paper.TEAL, false, 2)
	_text(GAUGE.position + Vector2(10, 22), "航標接收刻度", 170, 16, Paper.GOLD)
	var beacons: Array = _snapshot.beacons
	var bar_width := 30.0
	var spacing := (GAUGE.size.x - 20) / beacons.size()
	var top := GAUGE.position.y + 40
	var bottom := GAUGE.end.y - 40
	for i in beacons.size():
		var beacon: Dictionary = beacons[i]
		var x := GAUGE.position.x + 10 + spacing * i + (spacing - bar_width) * 0.5
		var bar := Rect2(x, top, bar_width, bottom - top)
		draw_rect(bar, Color("#22404a"))
		var fill := clampf(float(beacon.received), 0.0, 1.0) * bar.size.y
		draw_rect(Rect2(x, bottom - fill, bar_width, fill), Color("#ffe27a") if beacon.lit else Color("#6f8f97"))
		var threshold_y := bottom - Model.THRESHOLD * bar.size.y
		draw_line(Vector2(x - 4, threshold_y), Vector2(x + bar_width + 4, threshold_y), Paper.PAPER, 2)
		var short := "側" if beacon.hidden else str(beacon.name).left(1)
		_text(Vector2(x + 4, bottom + 22), short + ("✓" if beacon.lit else ""), 40, 15, Paper.GOLD if beacon.lit else Paper.PAPER)
