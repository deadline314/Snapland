extends Control
class_name SailChaseView

## 3D sailing chase. Wind field, flags, boats and wake mirror the snapshot; the
## sail swings to the leeward side at the model's trim angle.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/sail_chase_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1066, 222, 178, 336)
const COMMANDS := ["left", "right", "sheet_in", "sheet_out"]
const BUTTON_LABELS := ["A / ← 左舵", "D / → 右舵", "Q 收帆（帆角變小）", "E 放帆（帆角變大）"]
const WAKE := 10
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
var _boat: Node3D
var _sail: Node3D
var _ship: Node3D
var _flags: Array[Node3D] = []
var _wind_marks: Array[Node3D] = []
var _wake: Array[MeshInstance3D] = []
var _wood_nodes: Array[Node3D] = []
var _wood_variant := -1

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 308, 590, 300, 56)

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

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.024
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
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
	_viewport.name = "SailViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "SailWater"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#cfdcd8")
	_environment.ambient_light_energy = 0.55
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "SailSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 50
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "SailCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 12.4
	var focus := Vector3(2.2, 0.0, 0.0)
	_camera.position = focus + Vector3(0, sin(deg_to_rad(52.0)), cos(deg_to_rad(52.0))) * 40.0
	_world.add_child(_camera)
	_camera.look_at(focus)
	_camera.current = true
	for item in [["water", "#3b7d92"], ["inner", "#4a8c9c"], ["hull", "#f1e6c8"], ["mast", "#5b4632"], ["sail", "#fff8e6"], ["ship", "#2f4f63"],
			["buoy", "#e07a5f"], ["flag", "#ffd36a"], ["wood", "#7a5a3d"], ["wind", "#d8efe8"], ["wake", "#e9f4f2"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_materials.lamp = _material(Color("#fff0a0"), 1.0, 2.5)
	_materials.wake = _material(Color("#e9f4f2"), 0.55)
	var bounds: Rect2 = _snapshot.bounds
	_box("Water", Vector3(bounds.size.x + 10, 0.1, bounds.size.y + 8), Vector3(bounds.get_center().x, -0.1, bounds.get_center().y), _world, _materials.water)
	var inner: Rect2 = _snapshot.inner
	_box("InnerLane", Vector3(inner.size.x, 0.02, inner.size.y), Vector3(inner.get_center().x, -0.03, inner.get_center().y), _world, _materials.inner)
	_label3d("內線 · 風弱", Vector3(inner.get_center().x, 0.4, inner.get_center().y), _world, 30)
	for index in _snapshot.route.size():
		var corner: Vector2 = _snapshot.route[index]
		var buoy := Node3D.new()
		buoy.name = "Buoy%d" % index
		buoy.position = Vector3(corner.x, 0, corner.y)
		_world.add_child(buoy)
		_box("Float", Vector3(0.5, 0.5, 0.5), Vector3(0, 0.15, 0), buoy, _materials.buoy)
		_box("Pole", Vector3(0.06, 1.4, 0.06), Vector3(0, 0.9, 0), buoy, _materials.mast)
		var flag := Node3D.new()
		flag.name = "Flag"
		flag.position = Vector3(0, 1.45, 0)
		buoy.add_child(flag)
		_box("Cloth", Vector3(0.7, 0.32, 0.03), Vector3(0.35, 0, 0), flag, _materials.flag)
		_flags.append(flag)
	for x in range(-12, 14, 4):
		for z in range(-6, 8, 4):
			var mark := Node3D.new()
			mark.name = "WindMark"
			mark.position = Vector3(x, 0.05, z)
			_world.add_child(mark)
			_box("Streak", Vector3(0.9, 0.02, 0.05), Vector3(0.45, 0, 0), mark, _materials.wind)
			_wind_marks.append(mark)
	_ship = Node3D.new()
	_ship.name = "Lightship"
	_world.add_child(_ship)
	_box("ShipHull", Vector3(1.4, 0.4, 0.6), Vector3(0, 0.15, 0), _ship, _materials.ship)
	_box("ShipMast", Vector3(0.1, 1.2, 0.1), Vector3(0, 0.9, 0), _ship, _materials.mast)
	var lamp := SphereMesh.new()
	lamp.radius = 0.22
	lamp.height = 0.44
	var lamp_node := MeshInstance3D.new()
	lamp_node.name = "Lamp"
	lamp_node.mesh = lamp
	lamp_node.material_override = _materials.lamp
	lamp_node.position = Vector3(0, 1.55, 0)
	_ship.add_child(lamp_node)
	_label3d("燈船", Vector3(0, 2.2, 0), _ship, 30)
	for i in WAKE:
		var wake := _box("Wake%d" % i, Vector3(0.35, 0.02, 0.35), Vector3.ZERO, _world, _materials.wake)
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wake.append(wake)
	_boat = Node3D.new()
	_boat.name = "Sailboat"
	_world.add_child(_boat)
	_box("Hull", Vector3(1.1, 0.3, 0.42), Vector3(0, 0.1, 0), _boat, _materials.hull)
	_box("Mast", Vector3(0.07, 1.6, 0.07), Vector3(0.1, 1.0, 0), _boat, _materials.mast)
	_sail = Node3D.new()
	_sail.name = "SailPivot"
	_sail.position = Vector3(0.1, 0.25, 0)
	_boat.add_child(_sail)
	_box("Sail", Vector3(0.9, 1.3, 0.03), Vector3(-0.45, 0.75, 0), _sail, _materials.sail)

func _build_wood() -> void:
	_wood_variant = int(_snapshot.variant)
	for node in _wood_nodes:
		_world.remove_child(node)
		node.queue_free()
	_wood_nodes.clear()
	for index in _snapshot.wood.size():
		var wood: Vector2 = _snapshot.wood[index]
		var node := Node3D.new()
		node.name = "Driftwood%d" % index
		node.position = Vector3(wood.x, 0.05, wood.y)
		node.rotation.y = index * 0.9
		_world.add_child(node)
		_box("Log", Vector3(1.1, 0.22, 0.3), Vector3.ZERO, node, _materials.wood)
		_wood_nodes.append(node)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.variant) != _wood_variant:
		_build_wood()
	var wind := float(_snapshot.wind)
	var drift := 0.0 if _reduced_motion else fposmod(float(_snapshot.elapsed) * 0.8, 1.5)
	for mark in _wind_marks:
		mark.rotation.y = -wind
		mark.get_child(0).position.x = 0.45 + drift
	for flag in _flags:
		flag.rotation.y = -float(_snapshot.flag_wind)
	var boat_at: Vector2 = _snapshot.position
	_boat.position = Vector3(boat_at.x, 0, boat_at.y)
	_boat.rotation.y = -float(_snapshot.heading)
	# The sail swings to leeward: the side away from where the wind comes from.
	var leeward := -signf(angle_difference(float(_snapshot.heading), wind) + 0.0001)
	_sail.rotation.y = leeward * float(_snapshot.trim)
	var ship: Vector2 = _snapshot.lightship
	_ship.position = Vector3(ship.x, 0, ship.y)
	_ship.rotation.y = -float(_snapshot.lightship_heading)
	var back := Vector2.from_angle(float(_snapshot.lightship_heading))
	for i in _wake.size():
		var at: Vector2 = ship - back * (0.9 + i * 0.45)
		_wake[i].position = Vector3(at.x, -0.02, at.y)
		_wake[i].scale = Vector3.ONE * (1.0 + i * 0.12)
	var night := _time_phase == "night"
	_environment.background_color = Color("#1b2c3a") if night else Color("#b8ccc9")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.75 if night else 1.15
	_sun.rotation_degrees = Vector3(-50, {"dawn": -70.0, "noon": -30.0, "dusk": 40.0, "night": 70.0}.get(_time_phase, -30.0), 0)

func _compass(angle: float) -> String:
	var names := ["東", "東南", "南", "西南", "西", "西北", "北", "東北"]
	return names[posmod(roundi(angle / (PI / 4.0)), 8)]

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var sail := "逆風停帆" if _snapshot.in_irons else "帆面吃風 %d%%" % roundi(float(_snapshot.efficiency) * 100)
	return "風從%s吹來   |   %s   |   帆角 %d°（建議 %d°）   |   船速 %.1f   |   %s" % [_compass(float(_snapshot.wind) + PI), sail, roundi(rad_to_deg(_snapshot.trim)), roundi(rad_to_deg(_snapshot.optimal_trim)), _snapshot.speed, "內線風弱" if _snapshot.region == "inner" else "外線風強"]

func flag_text() -> String:
	if _snapshot.is_empty():
		return ""
	var helper := "夥伴依旗子建議帆角 %d°" % roundi(rad_to_deg(_snapshot.helper_trim))
	if _snapshot.shift_visible:
		return "浮標旗預告：%.0f 秒後風改從%s吹來　｜　%s" % [_snapshot.shift["in"], _compass(float(_snapshot.shift.wind) + PI), helper]
	return "燈船與你相距 %.1f　｜　換舷 %d 次　｜　%s" % [Vector2(_snapshot.position).distance_to(_snapshot.lightship), _snapshot.gybes, helper]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), flag_text(), 1200, 17, Paper.GOLD if _snapshot.shift_visible else Paper.PAPER)
		_draw_meter()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held := _pointer_owners.values().has(command)
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
		_text(rect.position + Vector2(12, 34), BUTTON_LABELS[i], rect.size.x - 20, 17)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "帆角約為船首與來風夾角的一半最快；正對來風會停帆，要之字搶風。浮標旗會先轉向預告風向。", 1210, 17)

## Sail efficiency and speed bars with numbers.
func _draw_meter() -> void:
	draw_rect(METER, Color(Paper.DEEP, 0.86))
	draw_rect(METER, Paper.TEAL, false, 2)
	_text(METER.position + Vector2(10, 22), "吃風／船速", 160, 16, Paper.GOLD)
	var top := METER.position.y + 40
	var bottom := METER.end.y - 40
	for column in 2:
		var value := float(_snapshot.efficiency) if column == 0 else clampf(float(_snapshot.speed) / Model.MAX_BOAT_SPEED, 0.0, 1.0)
		var bar := Rect2(METER.position.x + 26 + column * 70, top, 40, bottom - top)
		draw_rect(bar, Color("#22404a"))
		draw_rect(Rect2(bar.position.x, bottom - value * bar.size.y, bar.size.x, value * bar.size.y), Color("#9fe0c8") if column == 0 else Color("#ffe27a"))
		_text(Vector2(bar.position.x - 2, bottom + 24), "%d%%" % roundi(value * 100) if column == 0 else "%.1f" % float(_snapshot.speed), 60, 14)
