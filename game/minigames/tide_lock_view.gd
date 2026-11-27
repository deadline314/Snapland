extends Control
class_name TideLockView

## 3D lock cross-section: sea, chamber and basin water rise and fall as boxes, gates
## lift out when open, and safety lights show which gate may open now.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/tide_lock_model.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const StageProps = preload("res://game/minigames/stage_props.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STATUS_PLATE := Rect2(24, 140, 1232, 62)
const BUTTON_ICONS := ["gate", "gate", "down", "up", "lamp"]
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1046, 222, 198, 336)
const COMMANDS := ["lower", "upper", "drain", "fill", "helper"]
const BUTTON_LABELS := ["Q 開／關下閘", "E 開／關上閘", "A 放水到外海", "D 從港池蓄水", "R 閘工（安全燈）"]
const SEA_FROM := -14.0
const BASIN_TO := 22.0
const WALL_TOP := 4.6
var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _pointer_owners: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _materials: Dictionary = {}
var _sea: MeshInstance3D
var _chamber: MeshInstance3D
var _basin: MeshInstance3D
var _gates: Array[MeshInstance3D] = []
var _lights: Array[MeshInstance3D] = []
var _bell: Node3D
var _ship_nodes: Array[Node3D] = []
var _layout_variant := -1
var _sky: MeshInstance3D

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 246, 590, 236, 56)

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

func _box(node_name: String, size: Vector3, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 26) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
	return label

## A unit-height water box scaled to the level each frame (bottom stays at the floor).
func _water(node_name: String, from_x: float, to_x: float) -> MeshInstance3D:
	var water := _box(node_name, Vector3(to_x - from_x, 1.0, 3.0), Vector3((from_x + to_x) * 0.5, 0.5, 0), _world, _materials.water)
	return water

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
	_viewport.name = "LockViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "LockSection"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#d4dcda")
	_environment.ambient_light_energy = 0.6
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "LockSun"
	_sun.shadow_enabled = true
	_world.add_child(_sun)
	StageProps.dress_lighting(_environment, _sun)
	_camera = Camera3D.new()
	_camera.name = "SectionCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 8.4
	_camera.rotation_degrees = Vector3(-8, 0, 0)
	_camera.position = Vector3(4.6, 2.4 + tan(deg_to_rad(8.0)) * 20.0, 20.0)
	_world.add_child(_camera)
	_camera.current = true
	_materials.stone = StageProps.stone(Color("#8f8b7e"), 0.0, 3.3)
	_materials.floor = StageProps.stone(Color("#6a665c"), 0.0, 3.3)
	_materials.gate = StageProps.wood(Color("#7a5a3d"), 0.3, true)
	_materials.safe = StageProps.solid(Color("#7fe0a0"), 1.0, 1.6)
	_materials.unsafe = StageProps.solid(Color("#e2674f"), 1.0, 1.4)
	_materials.hull = StageProps.wood(Color("#c9573f"), 0.18)
	_materials.grounded = StageProps.wood(Color("#7a2d24"), 0.18)
	_materials.deck = StageProps.painted(Color("#efe2bd"))
	_materials.sculpt = StageProps.sculpt_material()
	_materials.water = StageProps.water(Color("#2f7f8f"), true)
	_sky = StageProps.sky_card(_world, Vector3(4.6, 6.2, -3.2), Vector2(48, 9), 2.0)
	_box("Floor", Vector3(BASIN_TO - SEA_FROM, 0.4, 3.4), Vector3((SEA_FROM + BASIN_TO) * 0.5, -0.2, 0), _world, _materials.floor)
	# The far quay wall of the lock, so the chamber reads as a stone basin.
	_box("ChamberWall", Vector3(Model.CHAMBER + 0.3, WALL_TOP - 0.4, 0.3), Vector3(Model.CHAMBER * 0.5, (WALL_TOP - 0.4) * 0.5, -1.7), _world, _materials.stone)
	_box("ChamberCoping", Vector3(Model.CHAMBER + 0.6, 0.18, 0.5), Vector3(Model.CHAMBER * 0.5, WALL_TOP - 0.3, -1.6), _world, StageProps.stone(Color("#bdb6a2")))
	_sea = _water("SeaWater", SEA_FROM, -0.15)
	_chamber = _water("ChamberWater", 0.15, Model.CHAMBER - 0.15)
	_basin = _water("BasinWater", Model.CHAMBER + 0.15, BASIN_TO)
	var bollard := StageProps.pile_mesh(0.14, 0.4, Color("#4f5b60"))
	for gate_x in [0.0, Model.CHAMBER]:
		_box("Wall%d" % roundi(gate_x), Vector3(0.3, WALL_TOP, 0.5), Vector3(gate_x, WALL_TOP * 0.5, -1.45), _world, _materials.stone)
		var gate := _box("Gate%d" % roundi(gate_x), Vector3(0.24, WALL_TOP, 2.9), Vector3(gate_x, WALL_TOP * 0.5, 0), _world, _materials.gate)
		# Iron straps across the timber leaf.
		for strap in 3:
			_box("GateStrap", Vector3(0.28, 0.12, 2.94), Vector3(0, -WALL_TOP * 0.35 + strap * WALL_TOP * 0.35, 0), gate, StageProps.solid(Color("#4f5b60")))
		_gates.append(gate)
		_lights.append(_box("Light%d" % roundi(gate_x), Vector3(0.4, 0.4, 0.4), Vector3(gate_x, WALL_TOP + 0.5, -1.45), _world, _materials.unsafe))
		_box("LightPost", Vector3(0.12, 0.5, 0.12), Vector3(gate_x, WALL_TOP + 0.1, -1.45), _world, StageProps.solid(Color("#4f5b60")))
		StageProps.add(_world, "Bollard", bollard, _materials.sculpt, Vector3(gate_x + 0.7, WALL_TOP - 0.2, -1.6))
	_label3d("外海", Vector3(-5.0, WALL_TOP + 0.3, 0), _world)
	_label3d("閘室", Vector3(Model.CHAMBER * 0.5, WALL_TOP + 0.3, 0), _world)
	_label3d("港池", Vector3(Model.CHAMBER + 2.0, WALL_TOP + 0.3, 0), _world)
	_bell = Node3D.new()
	_bell.name = "TideBell"
	_bell.position = Vector3(-3.0, WALL_TOP + 0.9, -1.4)
	_world.add_child(_bell)
	StageProps.add(_bell, "Bell", StageProps.canister_mesh(0.32, 0.7, Color("#d7b24e"), Color("#a9802f")), _materials.sculpt, Vector3(0, -0.35, 0))
	_box("BellYoke", Vector3(0.9, 0.1, 0.12), Vector3(0, 0.05, 0), _bell, StageProps.wood(Color("#6d5236")))

func _build_ships() -> void:
	_layout_variant = int(_snapshot.variant)
	for node in _ship_nodes:
		node.get_parent().remove_child(node)
		node.queue_free()
	_ship_nodes.clear()
	var index := 0
	for ship: Dictionary in _snapshot.ships:
		var node := Node3D.new()
		node.name = "Ship%d" % index
		_world.add_child(node)
		var hull := _box("Hull", Vector3(ship.length, ship.draft + 0.4, 1.6), Vector3(-ship.length * 0.5, (0.4 - ship.draft) * 0.5, 0), node, _materials.hull)
		hull.set_meta("draft", ship.draft)
		_box("Gunwale", Vector3(ship.length + 0.06, 0.1, 1.66), Vector3(-ship.length * 0.5, 0.42, 0), node, StageProps.wood(Color("#efe2bd")))
		_box("Boot", Vector3(ship.length + 0.02, 0.12, 1.62), Vector3(-ship.length * 0.5, 0.06, 0), node, StageProps.solid(Color("#2f566a")))
		var deck := _box("Deck", Vector3(ship.length * 0.5, 0.4, 1.0), Vector3(-ship.length * 0.55, 0.6, 0), node, _materials.deck)
		_box("Windows", Vector3(ship.length * 0.42, 0.1, 1.02), Vector3(0, 0.04, 0), deck, StageProps.solid(Color("#2f4f63")))
		_box("Roof", Vector3(ship.length * 0.54, 0.06, 1.1), Vector3(0, 0.23, 0), deck, StageProps.solid(Color("#c9573f")))
		_box("Funnel", Vector3(0.22, 0.5, 0.22), Vector3(-ship.length * 0.7, 1.0, 0), node, StageProps.solid(Color("#2f566a")))
		_label3d("%s 吃水%.1f" % [ship.name, ship.draft], Vector3(-ship.length * 0.5, 1.3, 0.8), node, 22)
		_ship_nodes.append(node)
		index += 1

func _set_water(water: MeshInstance3D, level: float) -> void:
	water.scale.y = maxf(0.01, level)
	water.position.y = level * 0.5

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.variant) != _layout_variant:
		_build_ships()
	var sea := float(_snapshot.sea)
	var level := float(_snapshot.level)
	var basin := float(_snapshot.basin)
	_set_water(_sea, sea)
	_set_water(_chamber, level)
	_set_water(_basin, basin)
	var open := [bool(_snapshot.lower_open), bool(_snapshot.upper_open)]
	var safe := [bool(_snapshot.lower_safe), bool(_snapshot.upper_safe)]
	for i in 2:
		_gates[i].position.y = WALL_TOP * 0.5 + (WALL_TOP - 0.3 if open[i] else 0.0)
		_lights[i].material_override = _materials.safe if safe[i] or open[i] else _materials.unsafe
	for i in _ship_nodes.size():
		var ship: Dictionary = _snapshot.ships[i]
		var node := _ship_nodes[i]
		node.visible = ship.present and not ship.passed
		var center: float = ship.front - ship.length * 0.5
		var water := sea if center < 0.0 else (level if center <= Model.CHAMBER else basin)
		node.position = Vector3(ship.front, maxf(water, ship.draft), 0.2)
		var hull: MeshInstance3D = node.get_child(0)
		hull.material_override = _materials.grounded if ship.grounded else _materials.hull
	var ringing: bool = str(_snapshot.last_event) == "bell" and not _reduced_motion
	_bell.rotation.z = sin(float(_snapshot.elapsed) * 10.0) * 0.4 if ringing else 0.0
	var night := _time_phase == "night"
	_environment.background_color = Color("#1d2b38") if night else Color("#c3d3d2")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.75 if night else 1.15
	_sun.rotation_degrees = Vector3(-50, {"dawn": -60.0, "noon": -20.0, "dusk": 30.0, "night": 60.0}.get(_time_phase, -20.0), 0)
	StageProps.set_motion(_materials.water, _reduced_motion)
	StageProps.set_sky_phase(_sky, _time_phase, _reduced_motion)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var gate := func(open: bool, safe: bool) -> String: return "開" if open else ("關·綠燈" if safe else "關·紅燈")
	return "外海 %.2f m　閘室 %.2f m　港池 %.2f m　|　下閘 %s　上閘 %s　|　閥門 %s　|　閘工%s" % [
		_snapshot.sea, _snapshot.level, _snapshot.basin, gate.call(_snapshot.lower_open, _snapshot.lower_safe), gate.call(_snapshot.upper_open, _snapshot.upper_safe),
		["放水中", "關", "蓄水中"][int(_snapshot.valve) + 1], "上崗" if _snapshot.helper else "休息"]

func bell_text() -> String:
	if _snapshot.is_empty():
		return ""
	var wait := ceili(float(_snapshot.next_extreme) - float(_snapshot.elapsed))
	return "潮鐘：%d 秒後%s　｜　%s" % [wait, "滿潮（正在漲）" if _snapshot.next_high else "乾潮（正在退）", _snapshot.feedback]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

## The fine print stays one hover away instead of filling the screen.
func _get_tooltip(at_position: Vector2) -> String:
	if _snapshot.is_empty() or not STATUS_PLATE.has_point(at_position):
		return ""
	return "閘室水位要和那一側對齊、而且另一道閘關著才亮綠燈。兩船能擠進同一閘可省一次蓄水，但退潮時等太久會擱淺。"

func _draw() -> void:
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_TEAL, true)
	if not _snapshot.is_empty():
		_text(Vector2(46, 166), status_text(), 1190, 17)
		_text(Vector2(46, 193), bell_text(), 1190, 17, Paper.GOLD)
		_draw_meter()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var active: bool = {"lower": _snapshot.get("lower_open", false), "upper": _snapshot.get("upper_open", false), "drain": int(_snapshot.get("valve", 0)) < 0,
			"fill": int(_snapshot.get("valve", 0)) > 0, "helper": _snapshot.get("helper", false)}[command]
		Props.control_key(self, button_rect(command), _pointer_owners.values().has(command) or active, BUTTON_ICONS[i], BUTTON_LABELS[i], Paper.font(), roundi(16 * Paper.text_scale()), true)

## Levels against each ship's draft; assisted rounds also preview the next 20 s of tide.
func _draw_meter() -> void:
	Props.wood_panel(self, METER, Props.SIGN_TEAL, true)
	_text(METER.position + Vector2(12, 24), "水位與吃水", 180, 16, Paper.GOLD)
	var top := METER.position.y + 44
	var bottom := METER.end.y - 30
	var to_y := func(height: float) -> float: return bottom - clampf(height / 4.0, 0.0, 1.0) * (bottom - top)
	var columns := [["外海", float(_snapshot.sea)], ["閘室", float(_snapshot.level)], ["港池", float(_snapshot.basin)]]
	for i in columns.size():
		var x := METER.position.x + 16 + i * 44
		var y: float = to_y.call(columns[i][1])
		Props.gauge(self, Rect2(x, top, 30, bottom - top), (bottom - y) / (bottom - top), Color("#3d96a8"))
		_text(Vector2(x - 2, bottom + 20), columns[i][0], 44, 13)
	for ship: Dictionary in _snapshot.ships:
		if ship.present and not ship.passed:
			var y: float = to_y.call(float(ship.draft) + Model.CLEARANCE)
			draw_line(Vector2(METER.position.x + 10, y), Vector2(METER.position.x + 146, y), Color("#ff8a6a") if ship.grounded else Color("#efe2bd"), 2)
	if _snapshot.assisted:
		var points := PackedVector2Array()
		var preview: Array = _snapshot.preview
		for i in preview.size():
			points.append(Vector2(METER.position.x + 152 + i * 4.0, to_y.call(float(preview[i]))))
		draw_polyline(points, Paper.GOLD, 2)
		_text(Vector2(METER.position.x + 146, top - 6), "下一潮", 60, 12, Paper.GOLD)
