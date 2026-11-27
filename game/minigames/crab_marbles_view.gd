extends Control
class_name CrabMarblesView

## 3D close-up sand tray. Trail, bounces, gates and the marble come from the model;
## previews shown here are the model's own visible-line helpers.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/crab_marbles_model.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const StageProps = preload("res://game/minigames/stage_props.gd")
const Scenery = preload("res://game/world/scenery_kit.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1086, 222, 158, 336)
const COMMANDS := ["aim_left", "aim_right", "charge"]
const BUTTON_LABELS := ["A / ← 向左瞄", "D / → 向右瞄", "按住空白 蓄力，放開彈出"]
const BUTTON_ICONS := ["turn_left", "turn_right", "power"]
const STATUS_PLATE := Rect2(24, 140, 1232, 62)
const HELP_TEXT := "力道越大滾越遠；濕沙堤和礁石會反彈，沙坡會把彈珠往箭頭方向推。"
const TRAIL_DOTS := 160
const BOUNCE_MARKS := 8
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
var _layout_variant := -1
var _layout_nodes: Array[Node] = []
var _doors: Array[Node3D] = []
var _gate_labels: Array[Label3D] = []
var _marble: MeshInstance3D
var _aim: Node3D
var _aim_shaft: MeshInstance3D
var _helper_line: Node3D
var _first_segment: MeshInstance3D
var _trail: MultiMeshInstance3D
var _bounces: Array[MeshInstance3D] = []

static func button_rect(command: String) -> Rect2:
	var widths := {"aim_left": Rect2(28, 590, 300, 56), "aim_right": Rect2(340, 590, 300, 56), "charge": Rect2(652, 590, 600, 56)}
	return widths.get(command, Rect2())

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

static func to_world(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, height, point.y)

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
		clear_pointer_input(false)
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
	material.roughness = 0.95
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.009
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
	_viewport.name = "SandViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "SandTray"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#e3d8c4")
	_environment.ambient_light_energy = 0.5
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "SandSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 30
	_world.add_child(_sun)
	StageProps.dress_lighting(_environment, _sun)
	_camera = Camera3D.new()
	_camera.name = "SandCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 5.9
	var focus := Vector3(1.3, 0.0, 0.1)
	_camera.position = focus + Vector3(0, sin(deg_to_rad(52.0)), cos(deg_to_rad(52.0))) * 26.0
	_world.add_child(_camera)
	_camera.look_at(focus)
	_camera.current = true
	for item in [["sand", "#e6cf9c"], ["wet", "#a98f66"], ["rock", "#7d8a86"], ["door", "#d86f55"], ["hole", "#3a2a1e"], ["crab", "#e2553f"],
			["marble", "#7fd6ea"], ["aim", "#fff2b0"], ["trail", "#8a6e4a"], ["bounce", "#ffd36a"], ["helper", "#9fe0c8"], ["first", "#ffffff"], ["slope", "#d6b97f"], ["launcher", "#5d7d8c"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_materials.slope_tint = _material(Color("#c9a76d"), 0.55)
	_materials.sand = StageProps.painted(Color("#e6cf9c"))
	_materials.wet = StageProps.stone(Color("#a98f66"), 1.0)
	_materials.beach = StageProps.painted(Color("#cdb47f"))
	_materials.sea = StageProps.water(Color("#3d8ea3"))
	_materials.door = StageProps.wood(Color("#c46a50"), 0.1, true)
	_materials.marble.roughness = 0.12
	_materials.marble.metallic = 0.25
	_materials.sculpt = StageProps.sculpt_material()
	var tray: Rect2 = _snapshot.tray
	# The tray sits on a wider beach with the tide line beyond it, so it is a
	# place on the shore rather than a box floating on a flat backdrop.
	_box("Beach", Vector3(tray.size.x + 24, 0.2, tray.size.y + 8), Vector3(tray.get_center().x, -0.32, tray.get_center().y + 2.0), _world, _materials.beach)
	_box("Sea", Vector3(tray.size.x + 24, 0.1, 12), Vector3(tray.get_center().x, -0.3, tray.position.y - 8.2), _world, _materials.sea)
	for at: Vector3 in [Vector3(tray.position.x - 1.3, -0.22, tray.position.y + 0.6), Vector3(tray.end.x + 1.1, -0.22, tray.end.y - 0.4), Vector3(tray.end.x + 1.6, -0.22, tray.position.y + 1.2), Vector3(tray.position.x - 1.8, -0.22, tray.end.y - 0.2)]:
		StageProps.add(_world, "BeachRock", StageProps.rock_mesh(0.3, 0.26, Color("#8a9088")), _materials.sculpt, at)
	StageProps.add(_world, "Shells", _shells_mesh(tray), _materials.sculpt)
	_box("SandBed", Vector3(tray.size.x, 0.2, tray.size.y), Vector3(tray.get_center().x, -0.1, tray.get_center().y), _world, _materials.sand)
	for side in [[Vector3(tray.size.x + 0.5, 0.36, 0.25), Vector3(0, 0.08, tray.position.y - 0.12)], [Vector3(tray.size.x + 0.5, 0.36, 0.25), Vector3(0, 0.08, tray.end.y + 0.12)],
			[Vector3(0.25, 0.36, tray.size.y), Vector3(tray.position.x - 0.12, 0.08, 0)], [Vector3(0.25, 0.36, tray.size.y), Vector3(tray.end.x + 0.12, 0.08, 0)]]:
		_box("WetBank", side[0], side[1], _world, _materials.wet)
	var launcher := to_world(_snapshot.launcher)
	StageProps.add(_world, "Launcher", _launcher_mesh(), _materials.sculpt, launcher + Vector3(0, -0.04, 0.15))
	_aim = Node3D.new()
	_aim.name = "AimArrow"
	_aim.position = launcher + Vector3(0, 0.12, 0)
	_world.add_child(_aim)
	_aim_shaft = _box("AimShaft", Vector3(0.06, 0.03, 1.0), Vector3(0, 0, -0.5), _aim, _materials.aim)
	var ball := SphereMesh.new()
	ball.radius = Model.BALL_RADIUS
	ball.height = Model.BALL_RADIUS * 2.0
	_marble = _mesh("Marble", ball, Vector3.ZERO, _world, _materials.marble)
	_helper_line = Node3D.new()
	_helper_line.name = "HelperHint"
	_helper_line.position = launcher + Vector3(0, 0.04, 0)
	_world.add_child(_helper_line)
	for i in 6:
		_box("HintDash", Vector3(0.05, 0.02, 0.22), Vector3(0, 0, -0.35 - i * 0.45), _helper_line, _materials.helper)
	_first_segment = _box("FirstSegment", Vector3(0.04, 0.02, 1.0), Vector3.ZERO, _world, _materials.first)
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.03
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot
	multimesh.instance_count = TRAIL_DOTS
	multimesh.visible_instance_count = 0
	_trail = MultiMeshInstance3D.new()
	_trail.name = "SandTrail"
	_trail.multimesh = multimesh
	_trail.material_override = _materials.trail
	_world.add_child(_trail)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.18
	for i in BOUNCE_MARKS:
		var mark := _mesh("Bounce%d" % i, ring, Vector3.ZERO, _world, _materials.bounce)
		mark.visible = false
		_bounces.append(mark)

## Gates, rocks and slopes move between layouts, so they are rebuilt once per variant.
func _build_layout() -> void:
	_layout_variant = int(_snapshot.variant)
	for node in _layout_nodes:
		node.get_parent().remove_child(node)
		node.queue_free()
	_layout_nodes.clear()
	_doors.clear()
	_gate_labels.clear()
	for index in _snapshot.slopes.size():
		var slope: Dictionary = _snapshot.slopes[index]
		var rect: Rect2 = slope.rect
		var patch := _box("Slope%d" % index, Vector3(rect.size.x, 0.04, rect.size.y), to_world(rect.get_center(), 0.02), _world, _materials.slope_tint)
		var pull: Vector2 = slope.pull
		var arrow := _box("SlopeArrow", Vector3(0.08, 0.02, 0.8), Vector3(0, 0.03, 0), patch, _materials.slope)
		arrow.rotation.y = -atan2(pull.y, pull.x) + PI / 2.0
		# Slope captions sit at the patch corner so they never cover a gate label.
		_label3d("沙坡↓" if pull.y > 0.0 else ("沙坡→" if pull.x > 0.0 else "沙坡←"), Vector3(rect.size.x * 0.32, 0.25, rect.size.y * 0.32), patch, 24)
		_layout_nodes.append(patch)
	for index in _snapshot.rocks.size():
		var rock: Dictionary = _snapshot.rocks[index]
		_layout_nodes.append(StageProps.add(_world, "Rock%d" % index, StageProps.rock_mesh(float(rock.radius) * 0.92, float(rock.radius) * 0.9, Color("#7d8a86")), _materials.sculpt, to_world(rock.center, -0.02)))
	for gate: Dictionary in _snapshot.gates:
		var node := Node3D.new()
		node.name = "CrabGate%d" % (gate.index + 1)
		node.position = to_world(gate.position)
		_world.add_child(node)
		var hole := CylinderMesh.new()
		hole.top_radius = Model.GATE_RADIUS
		hole.bottom_radius = Model.GATE_RADIUS
		hole.height = 0.02
		_mesh("Hole", hole, Vector3(0, 0.01, 0), node, _materials.hole)
		var door := Node3D.new()
		door.name = "Door"
		node.add_child(door)
		_box("Panel", Vector3(0.62, 0.4, 0.06), Vector3(0, 0.2, 0), door, _materials.door)
		StageProps.add(node, "Burrow", _burrow_mesh(), _materials.sculpt)
		StageProps.add(node, "Crab", _crab_mesh(), _materials.sculpt, Vector3(0.38, 0.0, 0.12)).rotation.y = -0.5
		_gate_labels.append(_label3d("", Vector3(0, 0.75, 0), node, 28))
		_doors.append(door)
		_layout_nodes.append(node)

## Red shore crab facing the camera: a domed shell, raised claws, stalk eyes
## and four legs a side.
func _crab_mesh() -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	var shell := Color("#e2553f")
	sculpt.ball(Vector3(0, 0.08, 0), 0.13, shell, shell.darkened(0.2), 8, 4, 0.55)
	for side: float in [-1.0, 1.0]:
		sculpt.ball(Vector3(side * 0.16, 0.11, 0.1), 0.06, shell.lightened(0.08), shell.darkened(0.15), 6, 3, 0.8)
		sculpt.box(Vector3(side * 0.11, 0.08, 0.06), Vector3(0.08, 0.025, 0.03), shell.darkened(0.1), Basis(Vector3.UP, side * 0.6))
		sculpt.box(Vector3(side * 0.04, 0.16, 0.07), Vector3(0.015, 0.06, 0.015), shell.darkened(0.25))
		sculpt.ball(Vector3(side * 0.04, 0.2, 0.07), 0.022, Color("#1f2a30"), Color.TRANSPARENT, 5, 2)
		for leg in 4:
			sculpt.box(Vector3(side * 0.16, 0.03, -0.06 + leg * 0.045), Vector3(0.12, 0.018, 0.018), shell.darkened(0.3), Basis(Vector3.FORWARD, side * 0.5))
	return sculpt.mesh()

## A ring of dug sand around each crab hole.
func _burrow_mesh() -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.tube(Vector3(0, 0.025, 0), Model.GATE_RADIUS + 0.12, Model.GATE_RADIUS + 0.02, 0.05, Color("#c9ad78"), 12)
	for lump in 5:
		var around := TAU * lump / 5.0 + 0.7
		sculpt.ball(Vector3(cos(around), 0, sin(around)) * (Model.GATE_RADIUS + 0.1) + Vector3(0, 0.03, 0), 0.06, Color("#d6bb84"), Color("#b39866"), 5, 2, 0.6)
	return sculpt.mesh()

## Driftwood chute with a brass plunger spring behind the marble.
func _launcher_mesh() -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	sculpt.box(Vector3(0, 0.08, 0), Vector3(0.6, 0.12, 0.5), Color("#8a6844"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.24, 0.18, 0), Vector3(0.1, 0.1, 0.52), Color("#a57a4e"))
	sculpt.tube(Vector3(0, 0.18, 0.2), 0.07, 0.07, 0.04, Color("#c9a45a"), 8, Basis(Vector3.RIGHT, PI * 0.5))
	for coil in 3:
		sculpt.tube(Vector3(0, 0.18, 0.1 + coil * 0.04), 0.05, 0.05, 0.015, Color("#a9802f"), 8, Basis(Vector3.RIGHT, PI * 0.5))
	return sculpt.mesh()

## Scattered shells and pebbles on the beach around the tray.
func _shells_mesh(tray: Rect2) -> ArrayMesh:
	var sculpt := Scenery.Sculpt.new()
	for index in 14:
		var side := index % 2
		var x := tray.position.x - 0.6 - fposmod(index * 0.73, 2.2) if side == 0 else tray.end.x + 0.6 + fposmod(index * 0.61, 2.2)
		var z := tray.position.y + fposmod(index * 1.37, tray.size.y)
		var tone: Color = [Color("#f1e6d2"), Color("#e8b8a0"), Color("#9a9a92")][index % 3]
		sculpt.ball(Vector3(x, -0.2, z), 0.06 + 0.02 * (index % 3), tone, tone.darkened(0.15), 5, 2, 0.5)
	return sculpt.mesh()

func _segment(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	node.position = (from + to) * 0.5
	node.scale = Vector3(1, 1, maxf(0.01, from.distance_to(to)))
	node.rotation = Vector3(0, atan2(to.x - from.x, to.z - from.z), 0)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.variant) != _layout_variant:
		_build_layout()
	var aim := float(_snapshot.aim)
	_aim.rotation.y = -aim
	_aim_shaft.scale.z = 0.6 + float(_snapshot.power) * 1.4 if _snapshot.charging else 1.0
	_aim_shaft.position.z = -_aim_shaft.scale.z * 0.5
	_aim.visible = not _snapshot.ball_active and not _snapshot.ended
	_helper_line.rotation.y = -float(_snapshot.helper_aim)
	_helper_line.visible = _aim.visible
	var segment: PackedVector2Array = _snapshot.first_segment
	_first_segment.visible = segment.size() == 2 and _aim.visible
	if _first_segment.visible:
		_segment(_first_segment, to_world(segment[0], 0.05), to_world(segment[1], 0.05))
	_marble.position = to_world(_snapshot.ball, Model.BALL_RADIUS)
	_marble.visible = _snapshot.ball_active or (not _snapshot.ended and _snapshot.balls_left > 0)
	for gate: Dictionary in _snapshot.gates:
		var door: Node3D = _doors[gate.index]
		door.rotation.x = -PI / 2.0 if gate.open else 0.0
		_gate_labels[gate.index].text = "第%d門 %s" % [gate.index + 1, "開" if gate.open else "關"]
		_gate_labels[gate.index].modulate = Paper.GOLD if gate.open else Paper.PAPER
	var trail: PackedVector2Array = _snapshot.trail
	var count := mini(trail.size(), TRAIL_DOTS)
	_trail.multimesh.visible_instance_count = count
	for i in count:
		_trail.multimesh.set_instance_transform(i, Transform3D(Basis(), to_world(trail[i], 0.012)))
	var points: Array = _snapshot.bounce_points
	for i in _bounces.size():
		_bounces[i].visible = i < points.size()
		if _bounces[i].visible:
			_bounces[i].position = to_world(points[i], 0.03)
	var night := _time_phase == "night"
	_environment.background_color = Color("#1b2c3a") if night else Color("#bfcfc6")
	StageProps.set_motion(_materials.sea, _reduced_motion)
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.75 if night else 1.15
	_sun.rotation_degrees = Vector3(-50, {"dawn": -70.0, "noon": -30.0, "dusk": 40.0, "night": 70.0}.get(_time_phase, -30.0), 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var power := "蓄力 %d%%" % roundi(float(_snapshot.power) * 100) if _snapshot.charging else "放開空白即彈出"
	return "瞄準 %+d°   |   %s   |   彈珠剩 %d / %d   |   蟹門 %d / 3   |   %s" % [roundi(rad_to_deg(_snapshot.aim)), power, _snapshot.balls_left, _snapshot.balls_total, _snapshot.opened, _snapshot.layout_name]

func shot_text() -> String:
	if _snapshot.is_empty():
		return ""
	var shots: Array = _snapshot.shots
	if shots.is_empty():
		return "沙面會留下彈珠軌跡；金圈是反彈點。綠色虛線是夥伴只看直線的寬角建議。"
	var last: Dictionary = shots[-1]
	var gates: Array[String] = []
	for gate in last.gates:
		gates.append("第%d門" % (int(gate) + 1))
	return "上一顆：反彈 %d 次，撞開 %s   |   出手 %d 次" % [last.bounces, "、".join(gates) if not gates.is_empty() else "無", shots.size()]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

## The last shot and the how-to stay one hover away.
func _get_tooltip(at_position: Vector2) -> String:
	if _snapshot.is_empty() or not STATUS_PLATE.has_point(at_position):
		return ""
	return shot_text() + "\n" + HELP_TEXT

func _draw() -> void:
	Props.wood_panel(self, STATUS_PLATE, Props.SIGN_TEAL, true)
	if not _snapshot.is_empty():
		_text(Vector2(46, 166), status_text(), 1190, 17)
		_text(Vector2(46, 193), str(_snapshot.get("feedback", "")), 1190, 18, Paper.GOLD)
		_draw_meter()
	for i in COMMANDS.size():
		Props.control_key(self, button_rect(COMMANDS[i]), _pointer_owners.values().has(COMMANDS[i]), BUTTON_ICONS[i], BUTTON_LABELS[i], Paper.font(), roundi(16 * Paper.text_scale()), true)

## Power bar with the charge level and remaining marbles as plain counts.
func _draw_meter() -> void:
	Props.wood_panel(self, METER, Props.SIGN_TEAL, true)
	_text(METER.position + Vector2(10, 22), "力道", 140, 16, Paper.GOLD)
	var bar := Rect2(METER.position.x + 20, METER.position.y + 40, 40, METER.size.y - 90)
	Props.gauge(self, bar, float(_snapshot.power) if _snapshot.charging else 0.0, Color("#ffe27a"))
	_text(Vector2(bar.position.x - 4, bar.end.y + 24), "%d%%" % roundi(float(_snapshot.power) * 100) if _snapshot.charging else "—", 60, 15)
	for i in int(_snapshot.balls_total):
		var center := Vector2(METER.position.x + 108, METER.position.y + 56 + i * 34)
		Props.token(self, center, 11, Color("#7fd6ea") if i < int(_snapshot.balls_left) else Color("#3b5560"))
	_text(Vector2(METER.position.x + 84, METER.end.y - 14), "彈珠", 60, 15)
