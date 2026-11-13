extends Control
class_name RopeTugView

## 3D towing bay. Tug, pontoon, rope and walls mirror the model snapshot; the
## view only interpolates nothing and never simulates.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/rope_tug_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1066, 222, 178, 336)
const COMMANDS := ["left", "right", "ahead", "astern", "reel_in", "reel_out", "hook"]
const BUTTON_LABELS := ["A / ← 左舵", "D / → 右舵", "W / ↑ 前進", "S / ↓ 倒車", "Q 收繩", "E 放繩", "空白 掛鉤／解繩"]
const ROPE_LINKS := 12
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
var _tug: Node3D
var _pontoon: Node3D
var _rope: Array[MeshInstance3D] = []
var _gate_labels: Array[Label3D] = []

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

## Tension as a fraction of the break limit; the rope reads red only alongside text.
static func strain(state: Dictionary) -> float:
	return clampf(float(state.get("tension", 0.0)) / maxf(0.001, float(state.get("break_tension", 1.0))), 0.0, 1.0)

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

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _box(node_name: String, dimensions: Vector3, at: Vector3, parent: Node3D, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 36) -> Label3D:
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
	var container := SubViewportContainer.new()
	container.name = "SpatialStage"
	container.position = STAGE.position
	container.size = STAGE.size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.show_behind_parent = true
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "TugViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "TowingBay"
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
	_sun.name = "TugSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "TugCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 10.4
	var focus := Vector3(1.6, 0.0, 0.0)
	_camera.position = focus + Vector3(0, sin(deg_to_rad(48.0)), cos(deg_to_rad(48.0))) * 34.0
	_world.add_child(_camera)
	_camera.look_at(focus)
	_camera.current = true
	for item in [["water", "#3a6f80"], ["wall", "#6f8580"], ["wall_top", "#9db1a8"], ["hull", "#d56f55"], ["deck", "#ead9af"],
			["cabin", "#2f566a"], ["pontoon", "#a07b52"], ["plank", "#6d5236"], ["cleat", "#f2d27a"], ["dock", "#8c6a46"], ["post", "#ead9af"]]:
		_materials[item[0]] = _material(Color(item[1]))
	var bounds: Rect2 = _snapshot.bounds
	_box("Water", Vector3(bounds.size.x + 8, 0.1, bounds.size.y + 6), Vector3(bounds.get_center().x, -0.12, bounds.get_center().y), _world, _materials.water)
	var walls: Array = _snapshot.walls
	for index in walls.size():
		var rect: Rect2 = walls[index]
		var wall := _box("Breakwater%d" % index, Vector3(rect.size.x, 0.55, rect.size.y), Vector3(rect.get_center().x, 0.2, rect.get_center().y), _world, _materials.wall)
		_box("WallTop", Vector3(rect.size.x + 0.04, 0.06, rect.size.y), Vector3(0, 0.3, 0), wall, _materials.wall_top)
	for gate: Dictionary in _snapshot.gates:
		for gap: Dictionary in gate.gaps:
			_gate_labels.append(_label3d(("側灣" if gap.side else "第%d灣" % gate.id), Vector3(gate.x, 1.0, gap.center), _world, 32))
	var dock := Node3D.new()
	dock.name = "Dock"
	_world.add_child(dock)
	_box("DockDeck", Vector3(1.4, 0.25, bounds.size.y - 1.0), Vector3(bounds.end.x - 0.9, 0.08, bounds.get_center().y), dock, _materials.dock)
	for z in range(-5, 6, 2):
		_box("DockPost", Vector3(0.14, 0.7, 0.14), Vector3(bounds.end.x - 1.5, 0.3, z), dock, _materials.post)
	_box("DockLine", Vector3(0.05, 0.03, bounds.size.y - 1.0), Vector3(float(_snapshot.dock_x), 0.0, bounds.get_center().y), dock, _materials.cleat)
	_label3d("碼頭（解繩靠港）", Vector3(bounds.end.x - 1.0, 1.2, bounds.position.y + 1.2), dock, 32)
	_tug = Node3D.new()
	_tug.name = "Tug"
	_world.add_child(_tug)
	_box("Hull", Vector3(1.0, 0.32, 0.62), Vector3(0, 0.08, 0), _tug, _materials.hull)
	_box("Deck", Vector3(0.9, 0.06, 0.5), Vector3(-0.04, 0.27, 0), _tug, _materials.deck)
	_box("Cabin", Vector3(0.36, 0.32, 0.4), Vector3(0.12, 0.45, 0), _tug, _materials.cabin)
	var bow := _box("Bow", Vector3(0.22, 0.24, 0.22), Vector3(0.55, 0.1, 0), _tug, _materials.hull)
	bow.rotation.y = PI / 4.0
	_box("Winch", Vector3(0.16, 0.16, 0.26), Vector3(-0.38, 0.38, 0), _tug, _materials.cleat)
	_pontoon = Node3D.new()
	_pontoon.name = "Pontoon"
	_world.add_child(_pontoon)
	_box("Raft", Vector3(1.7, 0.26, 1.15), Vector3(0, 0.05, 0), _pontoon, _materials.pontoon)
	for i in 5:
		_box("Plank", Vector3(0.04, 0.03, 1.1), Vector3(-0.68 + i * 0.34, 0.2, 0), _pontoon, _materials.plank)
	_box("Cargo", Vector3(0.6, 0.45, 0.5), Vector3(-0.2, 0.42, 0), _pontoon, _materials.cabin)
	for side in ["Bow", "Stern"]:
		_box("Cleat" + side, Vector3(0.14, 0.14, 0.14), Vector3.ZERO, _pontoon, _materials.cleat)
	for i in ROPE_LINKS:
		var link := _box("Rope%d" % i, Vector3.ONE, Vector3.ZERO, _world, _material(Color("#f0e2b8")))
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rope.append(link)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	var tug: Vector2 = _snapshot.tug
	_tug.position = Vector3(tug.x, 0.0, tug.y)
	_tug.rotation.y = -float(_snapshot.tug_heading)
	var pontoon: Vector2 = _snapshot.pontoon
	_pontoon.position = Vector3(pontoon.x, 0.0, pontoon.y)
	_pontoon.rotation.y = -float(_snapshot.pontoon_heading)
	for index in 2:
		var node: Node3D = _pontoon.get_node("Cleat%s" % ("Bow" if index == 0 else "Stern"))
		var world: Vector2 = _snapshot.cleats[index]
		var local := (world - pontoon).rotated(-float(_snapshot.pontoon_heading))
		node.position = Vector3(local.x, 0.3, local.y)
	# The rope sags with slack and straightens under tension.
	var hooked: bool = _snapshot.hooked
	var from := Vector3(tug.x, 0.38, tug.y) - Vector3(Vector2.from_angle(float(_snapshot.tug_heading)).x, 0, Vector2.from_angle(float(_snapshot.tug_heading)).y) * 0.38
	var cleat: Vector2 = _snapshot.cleat_position
	var to := Vector3(cleat.x, 0.3, cleat.y)
	var slack := clampf(float(_snapshot.rope_length) - float(_snapshot.rope_span), 0.0, 2.0)
	var level := strain(_snapshot)
	var color := Color("#f0e2b8").lerp(Color("#ff6a4d"), level)
	for i in _rope.size():
		var link := _rope[i]
		link.visible = hooked
		if not hooked:
			continue
		var a := from.lerp(to, float(i) / ROPE_LINKS)
		var b := from.lerp(to, float(i + 1) / ROPE_LINKS)
		a.y -= sin(PI * float(i) / ROPE_LINKS) * slack * 0.25
		b.y -= sin(PI * float(i + 1) / ROPE_LINKS) * slack * 0.25
		link.position = (a + b) * 0.5
		var length := maxf(0.01, a.distance_to(b))
		link.scale = Vector3(length, 0.05 + level * 0.03, 0.05 + level * 0.03)
		link.look_at(b if not b.is_equal_approx(link.position) else link.position + Vector3.RIGHT, Vector3.UP)
		link.rotate_object_local(Vector3.UP, PI / 2.0)
		(link.material_override as StandardMaterial3D).albedo_color = color
	var night := _time_phase == "night"
	_environment.background_color = Color("#1d3443") if night else Color("#b1c4c0")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.85 if night else 1.2
	_sun.rotation_degrees = Vector3(-42, {"dawn": -70.0, "noon": -35.0, "dusk": 40.0, "night": 70.0}.get(_time_phase, -35.0), 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var rope := "繩長 %.1f（船員穩住）" % _snapshot.rope_length if _snapshot.hooked else "未掛鉤"
	return "%s   |   張力 %.1f / 斷繩 %.1f   |   浮台速度 %.1f   |   %s" % [rope, _snapshot.tension, _snapshot.break_tension, _snapshot.pontoon_speed, "卡角中" if _snapshot.snagged else ("繩鬆" if _snapshot.hooked and _snapshot.tension <= 0.0 else "拖行中")]

func route_text() -> String:
	if _snapshot.is_empty():
		return ""
	var passed: Array[String] = []
	for row: Dictionary in _snapshot.gates_passed:
		passed.append("第%d灣%s" % [row.gate, "（側灣）" if row.side else ""])
	return "%s · 已通過：%s   |   斷繩 %d · 卡角 %d" % [_snapshot.variant_name, "、".join(passed) if not passed.is_empty() else "無", _snapshot.breaks, _snapshot.snags]

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), route_text(), 1200, 17)
		_draw_meter()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held := _pointer_owners.values().has(command)
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
		_text(rect.position + Vector2(10, 34), BUTTON_LABELS[i], rect.size.x - 16, 16)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "按住前進與舵；Q／E 按住收放繩。短繩跟得緊、長繩擺得開，張力到紅線會斷繩。", 1210, 17)

## Tension and rope length gauges; numbers accompany every bar.
func _draw_meter() -> void:
	draw_rect(METER, Color(Paper.DEEP, 0.86))
	draw_rect(METER, Paper.TEAL, false, 2)
	_text(METER.position + Vector2(10, 22), "張力／繩長", 160, 16, Paper.GOLD)
	var top := METER.position.y + 40
	var bottom := METER.end.y - 36
	var tension_bar := Rect2(METER.position.x + 24, top, 40, bottom - top)
	draw_rect(tension_bar, Color("#22404a"))
	var level := strain(_snapshot)
	draw_rect(Rect2(tension_bar.position.x, bottom - level * tension_bar.size.y, tension_bar.size.x, level * tension_bar.size.y), Color("#ff8a6a") if level > 0.75 else Color("#ffe27a"))
	draw_line(Vector2(tension_bar.position.x - 5, top), Vector2(tension_bar.end.x + 5, top), Color("#ff6a4d"), 3)
	_text(Vector2(tension_bar.position.x - 6, bottom + 22), "張力", 60, 14)
	var rope_bar := Rect2(METER.position.x + 104, top, 40, bottom - top)
	draw_rect(rope_bar, Color("#22404a"))
	var fraction := clampf((float(_snapshot.rope_length) - Model.ROPE_MIN) / maxf(0.01, float(_snapshot.rope_max) - Model.ROPE_MIN), 0.0, 1.0)
	draw_rect(Rect2(rope_bar.position.x, bottom - fraction * rope_bar.size.y, rope_bar.size.x, fraction * rope_bar.size.y), Color("#9fd7c8"))
	_text(Vector2(rope_bar.position.x - 2, bottom + 22), "繩長", 60, 14)
	_text(Vector2(tension_bar.end.x + 4, top + 14), "斷", 30, 13, Color("#ff9b7a"))
