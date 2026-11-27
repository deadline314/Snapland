extends Control
class_name AnchorChainView

## 3D top-down rescue. The hull pivots at its stern; chain links follow the model's
## path, and the torque arrow and reason text explain why a pull works or not.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/anchor_chain_model.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const StageProps = preload("res://game/minigames/stage_props.gd")
const Scenery = preload("res://game/world/scenery_kit.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1066, 222, 178, 336)
const COMMANDS := ["previous", "next", "place", "reel", "helper", "recall", "undo"]
const BUTTON_LABELS := ["Q／A 上一個", "E／D 下一個", "F 繞礁／下錨", "按住空白 收鏈", "R 船員舵", "X 收錨重來", "Z 回溯（輔助）"]
const BUTTON_ICONS := ["left", "right", "anchor", "hook", "turn_right", "undo", "undo"]
const STATUS_PLATE := Rect2(24, 140, 1232, 62)
const HELP_TEXT := "直拉時拉力線穿過擱淺點不會轉；先繞礁石改變拉的方向，船頭才會轉。鏈越長、繞越多圈拉力越小。"
const LINKS := 40
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
var _ship: Node3D
var _links: Array[MeshInstance3D] = []
var _selection: MeshInstance3D
var _torque_arrow: Node3D
var _layout_variant := -1
var _layout_nodes: Array[Node] = []
var _anchor_marks: Array[Node3D] = []
var _target_line: MeshInstance3D

static func button_rect(command: String) -> Rect2:
	return Rect2(28 + COMMANDS.find(command) * 176, 590, 168, 56)

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

func _material(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.85
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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

func _cylinder(node_name: String, radius: float, height: float, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.032
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
	_viewport.name = "RescueViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "RescueBay"
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
	_sun.name = "RescueSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40
	_world.add_child(_sun)
	StageProps.dress_lighting(_environment, _sun)
	_camera = Camera3D.new()
	_camera.name = "RescueCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Both mirrored layouts reach ±10 m north/south, so the whole bay stays in frame.
	_camera.size = 24.0
	var focus := Vector3(-1.0, 0.0, 0.0)
	_camera.position = focus + Vector3(0, sin(deg_to_rad(72.0)), cos(deg_to_rad(72.0))) * 40.0
	_world.add_child(_camera)
	_camera.look_at(focus)
	_camera.current = true
	for item in [["water", "#357488"], ["sand", "#e2cd98"], ["hull", "#b5533c"], ["deck", "#e8d6a8"], ["cabin", "#2f566a"], ["rock", "#7d8a86"],
			["chain", "#c9c4b4"], ["anchor", "#f2d27a"], ["select", "#ffd36a"], ["arrow", "#9fe0c8"], ["channel", "#e9f4f2"]]:
		_materials[item[0]] = _material(Color(item[1]))
	# The bay is seen from far up, so the water pattern runs at a coarser grain.
	_materials.water = StageProps.water(Color("#357488"))
	_materials.water.set_shader_parameter("texels_per_metre", 4.0)
	_materials.water.set_shader_parameter("wave_scale", 0.9)
	_materials.water.set_shader_parameter("foam_color", Color("#357488").lerp(Color("#dcefe8"), 0.45))
	_materials.deck = StageProps.wood(Color("#c9a878"), 0.3)
	_materials.cabin = StageProps.painted(Color("#e8dcc0"))
	_materials.chain = StageProps.solid(Color("#9ba3a6"))
	_materials.chain.metallic = 0.6
	_materials.chain.roughness = 0.4
	_materials.sculpt = StageProps.sculpt_material()
	_box("Water", Vector3(140, 0.1, 60), Vector3(0, -0.1, 0), _world, _materials.water)
	StageProps.add(_world, "Sandbar", _sandbar_mesh(), _materials.sculpt, Vector3(0, -0.1, 0))
	_ship = Node3D.new()
	_ship.name = "Freighter"
	_world.add_child(_ship)
	StageProps.add(_ship, "Hull", StageProps.boat_mesh(Model.SHIP_LENGTH + 0.6, 1.25, Color("#b5533c"), Color("#e8d6a8"), 0.45, false), _materials.sculpt, Vector3(Model.SHIP_LENGTH * 0.5, -0.02, 0))
	_box("Deck", Vector3(Model.SHIP_LENGTH - 0.2, 0.06, 0.92), Vector3(Model.SHIP_LENGTH * 0.5, 0.44, 0), _ship, _materials.deck)
	_box("Bridge", Vector3(0.8, 0.6, 0.8), Vector3(0.6, 0.8, 0), _ship, _materials.cabin)
	StageProps.add(_ship, "BridgeTrim", _bridge_trim_mesh(), _materials.sculpt, Vector3(0.6, 0.8, 0))
	for slot in 3:
		StageProps.add(_ship, "DeckCargo", StageProps.crate_mesh(Vector3(0.5, 0.4, 0.7), Color("#8f6f4c") if slot % 2 == 0 else Color("#b98a57"), Color("#5fb7a4") if slot == 1 else Color.TRANSPARENT, 0.47), _materials.sculpt, Vector3(1.6 + slot * 0.62, 0, 0))
	_box("BowCleat", Vector3(0.25, 0.25, 0.25), Vector3(Model.SHIP_LENGTH, 0.6, 0), _ship, _materials.anchor)
	var link_mesh := _link_mesh()
	for i in LINKS:
		var link := StageProps.add(_world, "Link%d" % i, link_mesh, _materials.chain)
		link.visible = false
		_links.append(link)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.05
	_selection = MeshInstance3D.new()
	_selection.name = "SelectionRing"
	_selection.mesh = ring
	_selection.material_override = _materials.select
	_world.add_child(_selection)
	_torque_arrow = Node3D.new()
	_torque_arrow.name = "TorqueArrow"
	_world.add_child(_torque_arrow)
	_box("Shaft", Vector3(2.0, 0.05, 0.12), Vector3(1.0, 0, 0), _torque_arrow, _materials.arrow)
	_target_line = _box("ChannelHeading", Vector3(7.0, 0.03, 0.18), Vector3.ZERO, _world, _materials.channel)
	_label3d("擱淺點", Vector3(0, 1.0, 0.6), _world, 26)

func _build_layout() -> void:
	_layout_variant = int(_snapshot.variant)
	for node in _layout_nodes:
		node.get_parent().remove_child(node)
		node.queue_free()
	_layout_nodes.clear()
	_anchor_marks.clear()
	for target: Dictionary in _snapshot.targets:
		var at: Vector2 = target.position
		var node := Node3D.new()
		node.name = ("Reef%d" if target.kind == "post" else "AnchorSpot%d") % target.index
		node.position = Vector3(at.x, 0, at.y)
		_world.add_child(node)
		if target.kind == "post":
			StageProps.add(node, "Pillar", StageProps.rock_mesh(0.72, 1.1, Color("#7d8a86")), _materials.sculpt, Vector3(0, -0.1, 0))
		else:
			StageProps.add(node, "Marker", StageProps.buoy_mesh(0.32, 0.9, Color("#e9b44c")), _materials.sculpt, Vector3(0, -0.05, 0))
			_anchor_marks.append(node)
		_label3d(target.name, Vector3(0, 1.4, 0), node, 26)
		_layout_nodes.append(node)
	var heading := float(_snapshot.target_heading)
	_target_line.position = Vector3(cos(heading) * 4.5, 0.0, sin(heading) * 4.5)
	_target_line.rotation.y = -heading

## Sand island the freighter is stuck on: a wet foot, a dry crown and a few stones.
func _sandbar_mesh() -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3(0, 0.06, 0), 2.5, 2.3, 0.12, Color("#a98f66"), 14)
	sculpt.tube(Vector3(0, 0.15, 0), 2.2, 1.7, 0.1, Color("#e2cd98"), 14)
	for stone in 5:
		var around := TAU * stone / 5.0 + 0.9
		sculpt.ball(Vector3(cos(around) * 1.9, 0.14, sin(around) * 1.9), 0.18 + 0.05 * (stone % 2), Color("#8a8f86"), Color("#6f756d"), 6, 3, 0.6)
	return sculpt.mesh()

## Window band, roof and funnel on the bridge box.
func _bridge_trim_mesh() -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.box(Vector3(0, 0.14, 0), Vector3(0.84, 0.12, 0.84), Color("#2f566a"))
	sculpt.box(Vector3(0, 0.33, 0), Vector3(0.92, 0.06, 0.92), Color("#b5533c"))
	sculpt.tube(Vector3(-0.15, 0.55, 0), 0.12, 0.1, 0.4, Color("#2f566a"), 8)
	sculpt.tube(Vector3(-0.15, 0.7, 0), 0.125, 0.125, 0.08, Color("#e9b44c"), 8)
	return sculpt.mesh()

## One chain link a metre long, scaled to each span: an open oval of bar.
func _link_mesh() -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(0, 0, side * 0.09), Vector3(0.8, 0.07, 0.05), Color.WHITE)
		sculpt.box(Vector3(side * 0.42, 0, 0), Vector3(0.1, 0.07, 0.16), Color.WHITE)
	return sculpt.mesh()

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.variant) != _layout_variant:
		_build_layout()
	_ship.rotation.y = -float(_snapshot.theta)
	var path: Array = _snapshot.path
	var used := 0
	for index in range(1, path.size()):
		var from: Vector2 = path[index - 1]
		var to: Vector2 = path[index]
		var count := clampi(ceili(from.distance_to(to) / 0.7), 1, LINKS - used)
		for k in count:
			if used >= LINKS:
				break
			var a := from.lerp(to, float(k) / count)
			var b := from.lerp(to, float(k + 1) / count)
			var link := _links[used]
			link.visible = true
			link.position = Vector3((a.x + b.x) * 0.5, 0.35, (a.y + b.y) * 0.5)
			link.scale = Vector3(maxf(0.05, a.distance_to(b) * 0.9), 1, 1)
			# Every other link stands on edge, like a real chain.
			link.rotation = Vector3(PI * 0.5 * (used % 2), -(b - a).angle(), 0)
			used += 1
	for index in range(used, LINKS):
		_links[index].visible = false
	var selected: Dictionary = _snapshot.targets[int(_snapshot.selected)]
	var at: Vector2 = selected.position
	_selection.position = Vector3(at.x, 0.05, at.y)
	_selection.visible = not _snapshot.ended
	var torque := float(_snapshot.torque)
	_torque_arrow.position = Vector3(Vector2(_snapshot.cleat).x, 0.9, Vector2(_snapshot.cleat).y)
	_torque_arrow.rotation.y = -(float(_snapshot.theta) + (PI / 2.0 if torque > 0.0 else -PI / 2.0))
	_torque_arrow.scale = Vector3(clampf(absf(torque) / 4.0, 0.1, 1.2), 1, 1)
	_torque_arrow.visible = int(_snapshot.anchor) >= 0
	var night := _time_phase == "night"
	_environment.background_color = Color("#1b2c3a") if night else Color("#b8ccc9")
	StageProps.set_motion(_materials.water, _reduced_motion)
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.75 if night else 1.15
	_sun.rotation_degrees = Vector3(-55, {"dawn": -70.0, "noon": -30.0, "dusk": 40.0, "night": 70.0}.get(_time_phase, -30.0), 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var selected: Dictionary = _snapshot.targets[int(_snapshot.selected)]
	var wraps: Array[String] = []
	for index in _snapshot.wraps:
		wraps.append("礁石%d" % (int(index) + 1))
	return "選取：%s   |   鏈路：船頭→%s%s   |   鏈長 %.1f · 拉力 %.1f   |   船員%s舵" % [selected.name, "→".join(wraps) + ("→" if not wraps.is_empty() else ""), (str(_snapshot.targets[_snapshot.posts.size() + int(_snapshot.anchor)].name) if int(_snapshot.anchor) >= 0 else "（未下錨）"), _snapshot.chain_length, _snapshot.strength, ["左", "中", "右"][int(_snapshot.helper) + 1]]

func torque_text() -> String:
	if _snapshot.is_empty():
		return ""
	var reason: String = _snapshot.reason if not str(_snapshot.reason).is_empty() else "下錨後按住空白收鏈，看轉矩是否推向航道"
	return "轉矩 %+.1f（擱淺摩擦 %.1f）　還需轉 %d° 對準%s邊航道　｜　%s" % [_snapshot.torque, Model.GROUND_FRICTION, roundi(absf(rad_to_deg(_snapshot.remaining_turn))), _snapshot.channel, reason]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

## The torque reading and the how-to stay one hover away; the meter shows torque.
func _get_tooltip(at_position: Vector2) -> String:
	if _snapshot.is_empty() or not STATUS_PLATE.has_point(at_position):
		return ""
	return torque_text() + "\n" + HELP_TEXT

func _draw() -> void:
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_TEAL, true)
	if not _snapshot.is_empty():
		_text(Vector2(46, 166), status_text(), 1190, 17)
		_text(Vector2(46, 193), str(_snapshot.get("feedback", "")), 1190, 18, Paper.GOLD)
		_draw_meter()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var unavailable: bool = command == "undo" and not _snapshot.get("assisted", false)
		Props.control_key(self, button_rect(command), _pointer_owners.values().has(command), BUTTON_ICONS[i], BUTTON_LABELS[i], Paper.font(), roundi(15 * Paper.text_scale()), not unavailable)

## Torque against ground friction, and chain strain toward breaking.
func _draw_meter() -> void:
	Props.wood_panel(self, METER, Props.SIGN_TEAL, true)
	_text(METER.position + Vector2(10, 22), "轉矩／鏈繃", 160, 16, Paper.GOLD)
	var top := METER.position.y + 40
	var bottom := METER.end.y - 40
	var torque_bar := Rect2(METER.position.x + 24, top, 40, bottom - top)
	Props.gauge(self, torque_bar, absf(float(_snapshot.torque)) / 6.0, Color("#9fe0c8"))
	var friction_y := bottom - Model.GROUND_FRICTION / 6.0 * torque_bar.size.y
	draw_line(Vector2(torque_bar.position.x - 5, friction_y), Vector2(torque_bar.end.x + 5, friction_y), Color("#ff8a6a"), 3)
	_text(Vector2(torque_bar.position.x - 4, bottom + 24), "轉矩", 60, 14)
	var strain_bar := Rect2(METER.position.x + 104, top, 40, bottom - top)
	Props.gauge(self, strain_bar, float(_snapshot.strain), Color("#ff8a6a"))
	_text(Vector2(strain_bar.position.x - 4, bottom + 24), "鏈繃", 60, 14)
