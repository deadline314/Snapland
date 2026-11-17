extends Control
class_name JellyTrampolineView

signal command_requested(command: String, pressed: bool, source: String)
signal pointer_requested(action: String, point: Vector2, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 288, 1232, 290)
const COMMANDS := ["bed_left", "bed_right", "tilt_left", "tilt_right", "charge", "helper", "reset_fruit"]
const BUTTON_KEYS := ["A / ←", "D / →", "Q", "E", "Space", "R", "X"]
const BUTTON_ACTIONS := ["左移床", "右移床", "左斜壓", "右斜壓", "蓄彈放開", "接球AI", "重置當顆"]
const KEYS := {KEY_A: "bed_left", KEY_LEFT: "bed_left", KEY_D: "bed_right", KEY_RIGHT: "bed_right", KEY_Q: "tilt_left", KEY_E: "tilt_right", KEY_SPACE: "charge", KEY_R: "helper", KEY_X: "reset_fruit"}
var _snapshot: Dictionary = {}
var _pointer_owner := ""
var _pointer_command := ""
var _world: Node3D
var _viewport: SubViewport
var _environment: Environment
var _materials: Dictionary = {}
var _bed: MeshInstance3D
var _left: MeshInstance3D
var _right: MeshInstance3D
var _support: MeshInstance3D
var _target: MeshInstance3D
var _safe: MeshInstance3D
var _fruit: MeshInstance3D
var _bell: MeshInstance3D
var _dots: Array[MeshInstance3D] = []
var _time_phase := "noon"

static func button_rect(command: String) -> Rect2:
	return Rect2(24 + COMMANDS.find(command) * 177, 594, 169, 74)
static func command_at(point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(point):
			return command
	return ""
static func pointer_source(event: InputEvent) -> String:
	if ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventMouseMotion) and event.device != InputEvent.DEVICE_ID_EMULATION:
		return "mouse"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d" % event.index
	return ""
static func hover_text(command: String) -> String:
	match command:
		"charge": return "按住蓄彈，放開才發射；移出按鈕放開會取消。"
		"tilt_left", "tilt_right": return "斜壓改變發射水平速度；空中不改向。"
		"reset_fruit": return "只重置當顆，時間不回復；已有蓄彈或飛行會計失誤。"
		"helper": return "AI只在實際接觸彈床時接穩，等你蓄彈放行。"
		"bed_left", "bed_right": return "移床一格；空中移床只影響實際回接。"
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
	if not point.is_finite() or not _pointer_owner.is_empty() or _snapshot.is_empty() or command_at(point).is_empty() or _snapshot.ended:
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
			command_requested.emit(KEYS[code], event.pressed, "keyboard:%d" % code)
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
func present(state: Dictionary, time_phase: String, _reduced_motion: bool) -> void:
	_snapshot = state.duplicate(true)
	_time_phase = time_phase
	if _world == null and is_inside_tree() and not state.is_empty():
		_create_stage()
	if _world != null:
		_apply_snapshot()
	queue_redraw()
static func world_point(x: float, y: float, z := 0.0) -> Vector3:
	return Vector3((x - 560) * 0.02, (620 - y) * 0.01, z)
func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.38
	return material
func _mesh(node_name: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	_world.add_child(node)
	return node
func _box(node_name: String, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(node_name, mesh, material, at)
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
	_world.name = "JellyStage"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#ffe9d0")
	_environment.ambient_light_energy = 0.8
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.shadow_enabled = true
	_world.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "JellyCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 6.6
	_world.add_child(camera)
	camera.position = Vector3(0, 12.4, 22)
	camera.look_at(Vector3(0, 3.1, 0), Vector3.UP)
	camera.current = true
	for item in [["frame", "#498a97"], ["jelly", "#64d3ad"], ["edge", "#b5ffe0"], ["target", "#ee9b66"], ["safe", "#fff1a1"], ["fruit", "#ff6f83"], ["bell", "#ffd85c"], ["arc", "#b2e8ff"]]:
		_materials[item[0]] = _material(item[1])
	_box("Floor", Vector3(22, 0.12, 2.4), Vector3(0, -0.1, 0), _materials.frame)
	for x in [32, 1088]:
		_box("Wall%d" % x, Vector3(0.12, 5.88, 1.0), world_point(x, 326), _materials.frame)
	_box("TopBeam", Vector3(21.12, 0.12, 0.9), world_point(560, 32), _materials.frame)
	_bed = _box("ElasticBed", Vector3(2.8, 0.44, 1.5), Vector3.ZERO, _materials.jelly)
	_left = _box("CompressionLeft", Vector3(1.32, 0.8, 1.3), Vector3.ZERO, _materials.jelly)
	_right = _box("CompressionRight", Vector3(1.32, 0.8, 1.3), Vector3.ZERO, _materials.jelly)
	_support = _box("BedSupport", Vector3.ONE, Vector3.ZERO, _materials.edge)
	_target = _box("HighPlatform", Vector3.ONE, Vector3.ZERO, _materials.target)
	_safe = _box("SafeLandingCenters", Vector3.ONE, Vector3.ZERO, _materials.safe)
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	_fruit = _mesh("Fruit", sphere, _materials.fruit, Vector3.ZERO)
	_fruit.scale.x = 2.0
	var bell_mesh := SphereMesh.new()
	bell_mesh.radius = 0.32
	bell_mesh.height = 0.64
	_bell = _mesh("SideBell", bell_mesh, _materials.bell, Vector3.ZERO)
	_bell.scale.x = 2.0
	_box("BellHanger", Vector3(0.1, 1.6, 0.12), world_point(930, 110, -0.2), _materials.bell)
	var dot := SphereMesh.new()
	dot.radius = 0.055
	dot.height = 0.11
	for i in 24:
		_dots.append(_mesh("Trajectory%02d" % i, dot, _materials.arc, Vector3.ZERO))
func _apply_snapshot() -> void:
	_environment.background_color = Color("#243b50") if _time_phase in ["night", "evening"] else Color("#34566a")
	var bed: Dictionary = _snapshot.bed
	var target: Dictionary = _snapshot.target
	var fruit: Dictionary = _snapshot.fruit
	var depression := 40.0 * float(_snapshot.depth)
	var width := float(bed.half_width) * 0.04
	_bed.position = world_point(bed.x, bed.y + depression + 22)
	_bed.scale.x = width / 2.8
	_bed.rotation.z = -deg_to_rad(float(_snapshot.tilt)) * 0.25
	for pair in [[_left, -1.0], [_right, 1.0]]:
		var side: MeshInstance3D = pair[0]
		var height := clampf(0.8 - depression * 0.01 + pair[1] * float(_snapshot.tilt) * 0.006, 0.15, 1.1)
		side.position = world_point(bed.x + pair[1] * float(bed.half_width) * 0.5, 602 - height * 50)
		side.scale = Vector3(width / 2.8, height / 0.8, 1)
	_support.position = world_point(bed.x, bed.y + depression, 0.76)
	_support.scale = Vector3((float(bed.half_width) - float(fruit.radius)) * 0.04, 0.045, 0.08)
	_target.position = world_point(target.x, (float(target.y) + 620.0) * 0.5)
	_target.scale = Vector3(float(target.half_width) * 0.04, (620.0 - float(target.y)) * 0.01, 1.2)
	_safe.position = world_point(target.x, target.y, 0.65)
	_safe.scale = Vector3((float(target.half_width) - float(fruit.radius)) * 0.04, 0.065, 0.1)
	_fruit.position = world_point(fruit.x, fruit.y, 0.24)
	_materials.fruit.albedo_color = Color("#ffe783") if fruit.bell_touched else Color("#ff6f83")
	_bell.position = world_point(_snapshot.bell.x, _snapshot.bell.y, 0.05)
	_bell.scale = Vector3(2, 1, 1) * (float(_snapshot.bell.radius) / 32.0)
	_materials.bell.albedo_color = Color("#fff9d0") if fruit.bell_touched else Color("#ffd85c")
	for i in 24:
		_dots[i].visible = i < _snapshot.trajectory.size()
		if _dots[i].visible:
			var point: Vector2 = _snapshot.trajectory[i]
			_dots[i].position = world_point(point.x, point.y, 0.3)

func text_size(font_size: int) -> int:
	var physical_scale := Paper.physical_scale(self) * get_global_transform_with_canvas().x.length()
	return ceili(maxf(font_size, 14.0 / maxf(physical_scale, 0.01)) * Paper.text_scale())
func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, text_size(font_size), color)
func status_text() -> String:
	if _snapshot.is_empty():
		return "按住蓄彈 · 放開才發射"
	if _snapshot.ended:
		return "三顆送達！" if _snapshot.success else "時間到 · 未完成"
	return "按住蓄彈 · 放開發射 · 三顆送上高台"
func feedback_text() -> String:
	return str(_snapshot.get("feedback", ""))
func text_rows() -> Array:
	if _snapshot.is_empty():
		return []
	return [
		[Vector2(38, 168), status_text(), 900, 18],
		[Vector2(1000, 168), "%d秒  %d分" % [ceili(_snapshot.remaining), _snapshot.score], 240, 18],
		[Vector2(38, 202), "送達 %d/3 · 失誤 %d" % [_snapshot.delivered, _snapshot.mistakes], 360, 17],
		[Vector2(430, 202), "重 %.2f · 斜壓 %d°" % [_snapshot.fruit.mass, _snapshot.tilt], 380, 17],
		[Vector2(850, 202), "蓄彈 %d%% · AI%s" % [roundi(_snapshot.depth * 100), "開" if _snapshot.helper else "關"], 390, 17],
		[Vector2(38, 239), "亮帶＝果心安全支撐", 405, 16],
		[Vector2(460, 239), "碰鈴送達 %d · 當顆%s" % [_snapshot.bell_deliveries, "已碰鈴" if _snapshot.fruit.bell_touched else "未碰鈴"], 790, 16],
		[Vector2(38, 274), "AI接穩等你放行", 405, 16],
		[Vector2(460, 274), "X重置不回時間 · 斜壓改變水平速度", 790, 16],
		[Vector2(28, 700), feedback_text(), 1220, 17]]
func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 140), Paper.DEEP_TEAL)
	for row in text_rows():
		_text(row[0], row[1], row[2], row[3], Paper.GOLD if row[0].y in [168.0, 700.0] else Paper.PAPER)
	for i in COMMANDS.size():
		var rect := button_rect(COMMANDS[i])
		var held: bool = _pointer_command == COMMANDS[i] and not _pointer_owner.is_empty()
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
		_text(rect.position + Vector2(8, 26), BUTTON_KEYS[i], 153, 15, Paper.GOLD)
		_text(rect.position + Vector2(8, 59), BUTTON_ACTIONS[i], 153, 16)
