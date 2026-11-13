extends Control
class_name GullGlideView

## 2.5D side view of the cliff course. The camera trails the gull; wind lines at
## the wingtips grow with headwind and a red post marks where a spread glide lands.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/gull_glide_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const METER := Rect2(1150, 222, 94, 336)
const TUCK_BUTTON := Rect2(28, 590, 420, 56)
const COMMANDS := ["tuck"]
const VIEW_HEIGHT := 16.0
const COURSE_END := 64.0
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
var _bird: Node3D
var _wings: Array[Node3D] = []
var _companion: Node3D
var _wind_lines: Array[MeshInstance3D] = []
var _reach: MeshInstance3D
var _feather_nodes: Array[Node3D] = []
var _layout_variant := -1
var _layout_nodes: Array[Node] = []

## The tuck button and the whole flight stage are hold targets.
static func button_rect(command: String) -> Rect2:
	return TUCK_BUTTON if command == "tuck" else Rect2()

static func command_at(point: Vector2) -> String:
	if TUCK_BUTTON.has_point(point) or (STAGE.has_point(point) and not METER.has_point(point)):
		return "tuck"
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
		_pointer_owners.erase(source)
		command_requested.emit("tuck", false, source)
		queue_redraw()
		return true
	if not point.is_finite() or command_at(point).is_empty():
		return false
	if not _pointer_owners.has(source):
		_pointer_owners[source] = "tuck"
		command_requested.emit("tuck", true, source)
		queue_redraw()
	return true

func clear_pointer_input(emit_releases: bool = true) -> void:
	if emit_releases:
		for source in _pointer_owners:
			command_requested.emit("tuck", false, source)
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

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 28) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.022
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Paper.PAPER
	label.outline_modulate = Paper.DEEP
	label.outline_size = 8
	label.position = at
	parent.add_child(label)
	return label

## A gull: body, head, tail and two wings that fold back when tucked.
func _make_gull(node_name: String, body: Material, wing: Material) -> Node3D:
	var gull := Node3D.new()
	gull.name = node_name
	_world.add_child(gull)
	_box("Body", Vector3(0.9, 0.3, 0.3), Vector3.ZERO, gull, body)
	_box("Head", Vector3(0.3, 0.26, 0.26), Vector3(0.5, 0.1, 0), gull, body)
	_box("Beak", Vector3(0.22, 0.08, 0.08), Vector3(0.72, 0.06, 0), gull, _materials.beak)
	_box("Tail", Vector3(0.3, 0.06, 0.3), Vector3(-0.55, 0.02, 0), gull, wing)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Wing%s" % ("L" if side < 0.0 else "R")
		pivot.position = Vector3(0.05, 0.08, side * 0.12)
		gull.add_child(pivot)
		_box("Blade", Vector3(0.42, 0.05, 1.3), Vector3(0, 0, side * 0.65), pivot, wing)
		pivot.set_meta("side", side)
	return gull

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
	_viewport.name = "CliffViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "CliffCourse"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#d4e0de")
	_environment.ambient_light_energy = 0.6
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "CliffSun"
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "SideCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = VIEW_HEIGHT
	_camera.rotation_degrees = Vector3(-12, 0, 0)
	_world.add_child(_camera)
	_camera.current = true
	for item in [["sea", "#3d7d8f"], ["foam", "#d8ece6"], ["rock", "#6f7a76"], ["cliff", "#8a7a62"], ["grass", "#7fa36a"], ["nest", "#b48a52"],
			["gull", "#f4f1e8"], ["wing", "#9aa7ab"], ["beak", "#f0b443"], ["feather", "#fff6d8"], ["reach", "#e2674f"], ["wind", "#e9f4f2"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_materials["thermal"] = _material(Color("#ffd98a"), 0.18)
	_materials["ghost"] = _material(Color("#f4f1e8"), 0.45)
	_materials["ghost_wing"] = _material(Color("#9aa7ab"), 0.45)
	_box("Sea", Vector3(COURSE_END + 60.0, 8.0, 12.0), Vector3(COURSE_END * 0.5, -4.0, -2.0), _world, _materials.sea)
	_box("StartRock", Vector3(3.0, 7.0, 3.0), Vector3(-2.5, 3.5, -1.0), _world, _materials.cliff)
	_bird = _make_gull("Gull", _materials.gull, _materials.wing)
	_companion = _make_gull("Companion", _materials.ghost, _materials.ghost_wing)
	_bird.scale = Vector3.ONE * 1.6
	_companion.scale = Vector3.ONE * 1.2
	for side in [-1.0, 1.0]:
		var line := _box("WindLine", Vector3(1, 0.04, 0.04), Vector3.ZERO, _world, _materials.wind)
		line.set_meta("side", side)
		_wind_lines.append(line)
	_reach = _box("GlideReach", Vector3(0.18, 1.6, 0.18), Vector3.ZERO, _world, _materials.reach)

func _build_layout() -> void:
	_layout_variant = int(_snapshot.variant)
	for node in _layout_nodes:
		node.get_parent().remove_child(node)
		node.queue_free()
	_layout_nodes.clear()
	_feather_nodes.clear()
	var index := 0
	for column: Vector2 in _snapshot.thermals:
		var thermal := _box("Thermal%d" % index, Vector3(column.y - column.x, Model.CEILING, 1.6), Vector3((column.x + column.y) * 0.5, Model.CEILING * 0.5, -0.6), _world, _materials.thermal)
		_label3d("上升氣流", Vector3(0, -Model.CEILING * 0.5 + 0.9, 0.9), thermal, 24)
		_layout_nodes.append(thermal)
		index += 1
	index = 0
	for feather: Dictionary in _snapshot.feathers:
		var at: Vector2 = feather.position
		var node := Node3D.new()
		node.name = "Feather%d" % index
		node.position = Vector3(at.x, at.y, 0)
		_world.add_child(node)
		var quill := _box("Quill", Vector3(1.1, 0.2, 0.3), Vector3.ZERO, node, _materials.feather)
		quill.rotation_degrees = Vector3(0, 0, 35)
		_feather_nodes.append(node)
		_layout_nodes.append(node)
		index += 1
	var gap: Dictionary = _snapshot.gap
	var center: float = gap.x + gap.width * 0.5
	var lower := _box("GapLower", Vector3(gap.width, gap.low + 1.0, 2.0), Vector3(center, (gap.low - 1.0) * 0.5, 0), _world, _materials.rock)
	var upper := _box("GapUpper", Vector3(gap.width, gap.top - gap.high, 2.0), Vector3(center, (gap.top + gap.high) * 0.5, 0), _world, _materials.rock)
	var gap_label := _label3d("岩縫", Vector3(center, gap.top + 0.7, 0.9), _world, 26)
	_layout_nodes.append_array([lower, upper, gap_label])
	var nest: Vector2 = _snapshot.nest
	var cliff_top: float = nest.y - Model.NEST_BELOW
	var cliff := _box("NestCliff", Vector3(8.0, cliff_top + 1.0, 4.0), Vector3(nest.x + 4.0, (cliff_top - 1.0) * 0.5, -1.0), _world, _materials.cliff)
	_box("CliffTurf", Vector3(8.0, 0.2, 4.0), Vector3(0, (cliff_top + 1.0) * 0.5, 0), cliff, _materials.grass)
	var bowl := _box("Nest", Vector3(1.4, 0.4, 1.4), Vector3(nest.x + 0.9, cliff_top + 0.2, 0), _world, _materials.nest)
	_label3d("巢", Vector3(0, 0.9, 0.9), bowl, 28)
	_layout_nodes.append_array([cliff, bowl])

func _set_wings(gull: Node3D, tucked: bool, flap: float) -> void:
	for pivot in gull.get_children():
		if not pivot.has_meta("side"):
			continue
		var side: float = pivot.get_meta("side")
		# Spread wings hold a shallow V; tucked wings sweep back along the body.
		pivot.rotation = Vector3(side * (0.25 + flap), side * (1.2 if tucked else 0.0), 0)
		pivot.scale = Vector3(1, 1, 0.55 if tucked else 1.0)

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	if int(_snapshot.variant) != _layout_variant:
		_build_layout()
	var at: Vector2 = _snapshot.position
	var velocity: Vector2 = _snapshot.velocity
	var tucked: bool = _snapshot.tucked
	_bird.position = Vector3(at.x, at.y, 0)
	_bird.rotation = Vector3(0, 0, clampf(velocity.angle(), -0.9, 0.7))
	var flap := 0.0 if _reduced_motion or tucked else sin(float(_snapshot.elapsed) * 9.0) * 0.08
	_set_wings(_bird, tucked, flap)
	var mate: Vector2 = _snapshot.companion
	_companion.position = Vector3(mate.x, mate.y, -1.6)
	_set_wings(_companion, _snapshot.companion_tucked, 0.0)
	var wind := float(_snapshot.wind)
	for line in _wind_lines:
		var length := maxf(0.1, wind * 0.9)
		line.position = Vector3(at.x - 0.2 - length * 0.5, at.y + 0.12, float(line.get_meta("side")) * 0.9)
		line.scale = Vector3(length, 1, 1)
	var reach := float(_snapshot.reach)
	_reach.position = Vector3(reach, 0.8, 0)
	for index in _feather_nodes.size():
		_feather_nodes[index].visible = not _snapshot.feathers[index].taken
	# Tilted 12° down, so lift the camera to keep 0–14 m centred.
	_camera.position = Vector3(clampf(at.x + 6.0, 14.0, COURSE_END - 12.0), 7.0 + tan(deg_to_rad(12.0)) * 24.0, 24.0)
	var night := _time_phase == "night"
	_environment.background_color = Color("#1d2d3c") if night else Color("#bcd6dc")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.75 if night else 1.15
	_sun.rotation_degrees = Vector3(-50, {"dawn": -60.0, "noon": -20.0, "dusk": 30.0, "night": 60.0}.get(_time_phase, -20.0), 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var at: Vector2 = _snapshot.position
	return "%s　羽毛 %d／3　繞回 %d 圈　|　高度 %.1f m　逆風 %.1f　地速 %.1f　|　展翼可滑到 %d m（巢在 %d m）　|　夥伴回巢 %d 次" % [
		"收翼俯衝" if _snapshot.tucked else "展翼滑翔", _snapshot.feather_count, _snapshot.laps, at.y, _snapshot.wind, _snapshot.ground_speed,
		roundi(float(_snapshot.reach)), roundi(Vector2(_snapshot.nest).x), _snapshot.companion_homes]

func guide_text() -> String:
	if _snapshot.is_empty():
		return ""
	var at: Vector2 = _snapshot.position
	var gap: Dictionary = _snapshot.gap
	if bool(_snapshot.threaded):
		return "已收翼穿過岩縫：在巢前放開展翼，收著翼衝巢會撞"
	if at.x > gap.x - 6.0 and at.x < gap.x:
		return "岩縫只容收翼通過（高 %.1f–%.1f m）；不想冒險就從岩柱上方 %.1f m 以上飛過" % [gap.low, gap.high, gap.top]
	for feather: Dictionary in _snapshot.feathers:
		var spot: Vector2 = feather.position
		if not feather.taken and spot.x > at.x:
			return "下一根羽毛在 %d m、高 %.1f m：%s" % [roundi(spot.x), spot.y, "收翼俯衝下去，放開會拉回一點" if spot.y < at.y - 1.0 else "借上升氣流拉高，或俯衝後放開換高度"]
	return "羽毛已齊，對準巢的高度展翼滑進去" if int(_snapshot.feather_count) >= 3 else "這圈的羽毛已過，飛到巢會繞回起點"

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200, 17)
		_text(Vector2(40, 191), guide_text(), 1200, 17, Paper.GOLD if _snapshot.tucked else Paper.PAPER)
		_draw_meter()
	var held := not _pointer_owners.is_empty() or bool(_snapshot.get("tucked", false))
	draw_rect(TUCK_BUTTON, Paper.FRAME if held else Paper.DEEP_TEAL)
	draw_rect(TUCK_BUTTON, Paper.GOLD if held else Paper.TEAL, false, 2)
	_text(TUCK_BUTTON.position + Vector2(14, 35), "按住收翼（空白／S／↓，或按住畫面）", TUCK_BUTTON.size.x - 20, 17)
	_text(Vector2(470, 625), "放開＝展翼：慢沉、借氣流拉高；收翼越久衝越快，放開時把速度換回高度。", 780, 16)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "高處風大滑得慢、看得遠；貼海面風小但容易落水。紅柱是現在展翼能滑到的落點。", 1210, 17)

## Usable height: the gull's altitude against the next feather and the nest.
func _draw_meter() -> void:
	draw_rect(METER, Color(Paper.DEEP, 0.86))
	draw_rect(METER, Paper.TEAL, false, 2)
	_text(METER.position + Vector2(10, 22), "高度", 80, 16, Paper.GOLD)
	var top := METER.position.y + 40
	var bottom := METER.end.y - 18
	var bar := Rect2(METER.position.x + 30, top, 34, bottom - top)
	draw_rect(bar, Color("#22404a"))
	var to_y := func(height: float) -> float: return bottom - clampf(height / Model.CEILING, 0.0, 1.0) * bar.size.y
	# Wind shading: stronger toward the top.
	for band in 7:
		var from_h := band * Model.CEILING / 7.0
		var y0: float = to_y.call(from_h + Model.CEILING / 7.0)
		draw_rect(Rect2(bar.position.x, y0, bar.size.x, bar.size.y / 7.0), Color(Paper.PAPER, 0.05 + 0.04 * band))
	var at: Vector2 = _snapshot.position
	var nest: Vector2 = _snapshot.nest
	draw_line(Vector2(bar.position.x - 6, to_y.call(nest.y)), Vector2(bar.end.x + 6, to_y.call(nest.y)), Color("#b48a52"), 3)
	for feather: Dictionary in _snapshot.feathers:
		if not feather.taken:
			var spot: Vector2 = feather.position
			draw_circle(Vector2(bar.end.x + 10, to_y.call(spot.y)), 4, Color("#fff6d8"))
	draw_rect(Rect2(bar.position.x - 4, float(to_y.call(at.y)) - 3, bar.size.x + 8, 6), Paper.GOLD)
