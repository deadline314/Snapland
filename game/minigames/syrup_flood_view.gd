extends Control
class_name SyrupFloodView

signal command_requested(command: String, pressed: bool, source: String)
signal pointer_requested(action: String, point: Vector2, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const StageProps = preload("res://game/minigames/stage_props.gd")
const STATUS_PLATE := Rect2(24, 140, 1232, 152)
const BUTTON_ICONS := ["left", "right", "gate", "flame", "swap", "helper", "down", "wait"]
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 300, 1232, 278)
const HEIGHT := 5.2
const CENTER_Y := 1.3
const COS_TILT := 0.894427191
const SIN_TILT := 0.4472135955
const COMMANDS := ["previous", "next", "valve", "heater", "diversion", "helper", "drain", "configuration"]
const BUTTON_KEYS := ["⇧Tab", "Tab", "Space", "H", "F", "R", "X", "C"]
const BUTTON_ACTIONS := ["上一管", "下一管", "開關閥", "切熱源", "切旁路", "指定 AI", "排空缸", "停流配置"]
const KEYS := {KEY_TAB: "next", KEY_SPACE: "valve", KEY_H: "heater", KEY_F: "diversion", KEY_R: "helper", KEY_X: "drain", KEY_C: "configuration"}
var _snapshot: Dictionary = {}
var _pointer_owner := ""
var _pointer_command := ""
var _tab_command := "next"
var _tab_held := false
var _world: Node3D
var _viewport: SubViewport
var _environment: Environment
var _materials: Dictionary = {}
var _pipes: Array[MeshInstance3D] = []
var _pipe_backs: Array[MeshInstance3D] = []
var _liquids: Array[MeshInstance3D] = []
var _flows: Array[MeshInstance3D] = []
var _valves: Array[MeshInstance3D] = []
var _levels: Array[MeshInstance3D] = []
var _bands: Array[MeshInstance3D] = []
var _heater: MeshInstance3D
var _plug: MeshInstance3D
var _leak: MeshInstance3D
var _selection: MeshInstance3D
var _reduced_motion := false
var _time_phase := "noon"

static func button_rect(command: String) -> Rect2:
	return Rect2(24 + COMMANDS.find(command) * 155, 594, 147, 74)
static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""
static func design_point(point: Vector3) -> Vector2:
	return STAGE.get_center() + Vector2(point.x, CENTER_Y - point.y * COS_TILT + point.z * SIN_TILT) * (STAGE.size.y / HEIGHT)
static func valve_world(index: int) -> Vector3:
	return Vector3((index - 1) * 6.3, 2.65, 0.26)
static func valve_point(index: int) -> Vector2:
	return design_point(valve_world(index))
static func valve_at(point: Vector2) -> int:
	for i in 3:
		if point.distance_to(valve_point(i)) <= 32:
			return i
	return -1
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
		return true
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if source == "mouse" and _pointer_owner.is_empty():
			tooltip_text = hover_text(command_at(point))
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
	if not point.is_finite() or not _pointer_owner.is_empty() or _snapshot.is_empty() or (command_at(point).is_empty() and valve_at(point) < 0):
		return false
	_pointer_owner = source
	_pointer_command = command_at(point)
	pointer_requested.emit("press", point, source)
	queue_redraw()
	return true
static func hover_text(command: String) -> String:
	match command:
		"heater": return "共用熱源同時加熱一管；關閥仍可預熱。"
		"diversion": return "選中中管並開閥：冷糖能堵裂口，熱糖會消融未成形糖塞。"
		"drain": return "免費排空所選缸；保留其他缸，時間不回復。"
		"helper": return "AI 只監看指定一缸，到 92% 關閥；不會加熱。"
		"configuration": return "停流時可配置；停止升溫、流糖與計時，續流後才結算。"
	return ""
## Exact readings stay one hover away; the board shows them as meters.
func _get_tooltip(at_position: Vector2) -> String:
	if not STATUS_PLATE.has_point(at_position) or _snapshot.is_empty():
		return tooltip_text
	var lines: PackedStringArray = []
	for i in 3:
		var branch: Dictionary = _snapshot.branches[i]
		lines.append("%d管 溫%d%% 黏%.2f 流%.1f · 長 %.2f 熱容 %.2f 容 %d" % [i + 1, roundi(branch.temperature * 100), branch.viscosity, 0.0 if _snapshot.configuration_paused else branch.flow, branch.length, branch.heat_capacity, branch.capacity])
	lines.append("熱源 %s · AI %s · 冷塞 %.1f/%d %s · 旁路用糖 %.1f · 溢出 %d" % ["關" if _snapshot.heater < 0 else "%d管" % (_snapshot.heater + 1), "關" if _snapshot.helper < 0 else "%d管" % (_snapshot.helper + 1), _snapshot.plug_amount, _snapshot.plug_required, "已堵" if _snapshot.cold_plugged else ("旁路" if _snapshot.diversion else "入缸"), _snapshot.branches[1].leaked, _snapshot.mistakes])
	return "\n".join(lines)

func clear_pointer_input(emit_cancel: bool = true) -> void:
	_pointer_owner = ""
	_pointer_command = ""
	_tab_held = false
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
				if event.pressed and _tab_held:
					accept_event()
					return
				if event.pressed:
					_tab_command = "previous" if event.shift_pressed else "next"
				_tab_held = event.pressed
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
func present(state: Dictionary, time_phase: String, reduced_motion: bool) -> void:
	_snapshot = state.duplicate(true)
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	if _world == null and is_inside_tree() and not state.is_empty():
		_create_stage()
	if _world != null:
		_apply_snapshot()
	queue_redraw()
func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.45
	return material
func _box(node_name: String, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	_world.add_child(node)
	return node
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
	_world.name = "SyrupWorkbench"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#ffe7c7")
	_environment.ambient_light_energy = 0.8
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.shadow_enabled = true
	_world.add_child(sun)
	StageProps.dress_lighting(_environment, sun)
	var camera := Camera3D.new()
	camera.name = "SyrupCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = HEIGHT
	_world.add_child(camera)
	var center := Vector3(0, CENTER_Y * COS_TILT, -CENTER_Y * SIN_TILT)
	camera.position = center + Vector3(0, SIN_TILT, COS_TILT) * 20
	camera.look_at(center, Vector3.UP)
	camera.current = true
	for item in [["metal", "#87b8bf"], ["edge", "#d3eeeb"], ["back", "#274451"], ["tank", "#4b747e"], ["band", "#5bdbad"], ["heater", "#ff713f"], ["plug", "#e3ae6a"], ["selected", "#fff19a"]]:
		_materials[item[0]] = _material(item[1])
	# Copper troughs, brass-framed vats with plum enamel backs, a planked bench.
	_materials.metal = StageProps.painted(Color("#8a4f3a"))
	_materials.edge = StageProps.painted(Color("#d9ab55"))
	_materials.tank = StageProps.painted(Color("#5a3a52"))
	_materials.heater = StageProps.solid(Color("#ff713f"), 1.0, 0.6)
	_materials.plug = StageProps.candy(Color("#e3ae6a"))
	_materials.band = StageProps.solid(Color("#5bdbad"), 1.0, 0.25)
	_box("Workbench", Vector3(24, 0.16, 3.8), Vector3(0, -0.15, 0), StageProps.wood(Color("#7a5238")))
	_box("FactoryWall", Vector3(26, 8, 0.2), Vector3(0, 2.0, -1.95), StageProps.tiled_wall())
	for i in 3:
		var x := (i - 1) * 6.3
		var syrup := StageProps.candy(Color("#cb944a"))
		_materials["syrup%d" % i] = syrup
		_pipes.append(_box("PipeFloor%d" % i, Vector3(2.1, 0.14, 0.7), Vector3(x - 0.75, 2.35, 0), _materials.metal))
		_pipe_backs.append(_box("PipeBack%d" % i, Vector3(2.1, 0.42, 0.12), Vector3(x - 0.75, 2.56, -0.35), _materials.edge))
		_liquids.append(_box("PipeSyrup%d" % i, Vector3(2.1, 0.14, 0.45), Vector3(x - 0.75, 2.48, 0), syrup))
		_box("Outlet%d" % i, Vector3(0.36, 0.55, 0.5), Vector3(x + 0.45, 2.18, 0), _materials.metal)
		_flows.append(_box("Flow%d" % i, Vector3(0.15, 0.75, 0.18), Vector3(x + 0.45, 1.62, 0.18), syrup))
		_valves.append(_box("Valve%d" % i, Vector3(0.9, 0.12, 0.22), valve_world(i), _materials.heater))
		_box("ValveStem%d" % i, Vector3(0.12, 0.5, 0.12), Vector3(x, 2.6, 0.1), _materials.edge)
		_box("TankBack%d" % i, Vector3(2.0, 1.5, 0.13), Vector3(x + 0.45, 0.75, -0.48), _materials.tank)
		for side in [-1, 1]:
			_box("TankSide%d_%d" % [i, side], Vector3(0.13, 1.5, 1.0), Vector3(x + 0.45 + side * 1.0, 0.75, 0), _materials.edge)
		_box("TankBase%d" % i, Vector3(2.1, 0.12, 1.05), Vector3(x + 0.45, 0, 0), _materials.edge)
		_levels.append(_box("TankLevel%d" % i, Vector3(1.84, 1.5, 0.82), Vector3(x + 0.45, 0, 0.03), syrup))
		_bands.append(_box("TargetBand%d" % i, Vector3(2.1, 0.15, 0.06), Vector3(x + 0.45, 1.425, 0.55), _materials.band))
	_heater = _box("Heater", Vector3(1.5, 0.25, 1.1), Vector3.ZERO, _materials.heater)
	_plug = _box("ColdPlug", Vector3(0.6, 0.8, 0.65), Vector3(1.85, 1.6, 0.2), _materials.plug)
	_box("CrackOutlet", Vector3(0.8, 0.22, 0.5), Vector3(1.6, 2.05, 0.0), _materials.metal)
	_leak = _box("SideLeak", Vector3(0.13, 1.15, 0.18), Vector3(1.85, 1.25, 0.25), _materials["syrup1"])
	_box("BypassTray", Vector3(1.1, 0.12, 1.1), Vector3(1.85, 0.65, 0.15), _materials.tank)
	_selection = _box("SelectedValve", Vector3(1.3, 0.06, 0.65), Vector3.ZERO, _materials.selected)
func _apply_snapshot() -> void:
	_environment.background_color = Color("#263a49") if _time_phase in ["night", "evening"] else Color("#6a5262")
	var paused: bool = _snapshot.configuration_paused or _snapshot.ended
	for i in 3:
		var branch: Dictionary = _snapshot.branches[i]
		var fraction := float(branch.fill) / float(branch.capacity)
		_pipes[i].scale.x = branch.length
		_pipe_backs[i].scale.x = branch.length
		_liquids[i].scale.x = branch.length
		var pipe_center := (i - 1) * 6.3 + 0.45 - 1.05 * float(branch.length)
		_pipes[i].position.x = pipe_center
		_pipe_backs[i].position.x = pipe_center
		_liquids[i].position.x = pipe_center
		var syrup: StandardMaterial3D = _materials["syrup%d" % i]
		syrup.albedo_color = Color("#c9a462").lerp(Color("#ff6838"), branch.temperature)
		_levels[i].visible = fraction > 0
		_levels[i].scale.y = maxf(0.001, minf(fraction, 1.1))
		_levels[i].position.y = 0.75 * minf(fraction, 1.1)
		_valves[i].rotation.y = PI * 0.5 if branch.valve else 0.0
		_flows[i].visible = not paused and branch.flow > 0 and not (i == 1 and _snapshot.diversion)
		_flows[i].scale.x = 1.0 if _reduced_motion else 0.85 + 0.15 * sin(float(_snapshot.elapsed) * 12.0)
		_bands[i].material_override = _materials.heater if branch.spoiled else _materials.band
		var target_ratio := float(branch.target) / float(branch.capacity)
		_bands[i].scale.y = (1.0 - target_ratio) / 0.1
		_bands[i].position.y = 1.5 * (1.0 + target_ratio) * 0.5
	_heater.visible = _snapshot.heater >= 0
	if _heater.visible:
		var index := int(_snapshot.heater)
		_heater.position = Vector3((index - 1) * 6.3 + 0.45 - 1.05 * float(_snapshot.branches[index].length), 2.12, 0)
	_selection.position = valve_world(int(_snapshot.selected)) + Vector3(0, -0.16, 0.03)
	_plug.visible = _snapshot.plug_amount > 0
	_plug.scale.y = maxf(0.02, float(_snapshot.plug_amount) / float(_snapshot.plug_required))
	_leak.visible = not paused and not _snapshot.cold_plugged and _snapshot.branches[1].flow > 0

func text_size(font_size: int) -> int:
	var physical_scale := Paper.physical_scale(self) * get_global_transform_with_canvas().x.length()
	return ceili(maxf(font_size, 14.0 / maxf(physical_scale, 0.01)) * Paper.text_scale())
func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, text_size(font_size), color)
func status_text() -> String:
	if _snapshot.is_empty():
		return "共用熱源 · 冷糖堵漏"
	if _snapshot.configuration_paused:
		return "停流配置中 · C 續流才結算"
	if _snapshot.ended:
		return "三缸關閥完成" if _snapshot.success else "時間到 · 未完成"
	return "熱糖快，冷糖堵裂口 · 90–100% 關閥"
func feedback_text() -> String:
	return str(_snapshot.get("feedback", ""))
func _draw() -> void:
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_PLUM, true)
	_text(Vector2(40, 170), status_text(), 930, 20, Paper.GOLD)
	if _snapshot.is_empty():
		return
	_text(Vector2(1000, 170), "%d 秒 · %d 分" % [ceili(_snapshot.remaining), _snapshot.score], 240, 18, Paper.TEAL)
	_text(Vector2(40, 200), feedback_text(), 1190, 17)
	# One fill meter per pipe, with the target zone marked and a heat strip under it.
	for i in 3:
		var branch: Dictionary = _snapshot.branches[i]
		var x := 40.0 + i * 410
		var selected: bool = _snapshot.selected == i
		var tint: Color = Paper.CORAL if branch.spoiled else (Paper.GOLD if selected else Paper.TEAL)
		_text(Vector2(x, 238), "%s%d管 %s" % ["▶" if selected else " ", i + 1, "溢出" if branch.spoiled else ("開" if branch.valve else "關")], 110, 18, tint)
		var meter := Rect2(x + 112, 224, 250, 14)
		Props.bar(self, meter, float(branch.fill) / float(branch.capacity), Color("#cb944a").lerp(Color("#ff6838"), branch.temperature))
		var target_x: float = meter.position.x + meter.size.x * float(branch.target) / float(branch.capacity)
		draw_rect(Rect2(target_x, meter.position.y - 4, 2, meter.size.y + 8), Color("#5bdbad"))
		Props.bar(self, Rect2(x + 112, 256, 250, 6), branch.temperature, Color("#ff8a5a"), Color("#8a6a78"))
		_text(Vector2(x + 370, 238), "%d%%" % roundi(100.0 * branch.fill / branch.capacity), 40, 16, tint)
		_text(Vector2(x + 370, 266), "冷" if branch.temperature <= 0.30 else ("熱" if branch.temperature >= 0.65 else "溫"), 40, 15, Color("#ffb08a"))
	for i in 3:
		var at := design_point(Vector3((i - 1) * 6.3 + 0.45, -0.45, 0.0))
		var branch: Dictionary = _snapshot.branches[i]
		_text(at + Vector2(-88, 4), "%d缸 %d–100%%" % [i + 1, roundi(100.0 * branch.target / branch.capacity)], 230, 16, Paper.TEAL)
	for i in COMMANDS.size():
		var rect := button_rect(COMMANDS[i])
		var held: bool = _pointer_command == COMMANDS[i] and not _pointer_owner.is_empty()
		Props.labelled_key(self, rect, held, BUTTON_ICONS[i], BUTTON_KEYS[i], "續流" if COMMANDS[i] == "configuration" and _snapshot.configuration_paused else BUTTON_ACTIONS[i], Paper.font(), text_size(15), text_size(16), true, Props.KEY_PLUM)
