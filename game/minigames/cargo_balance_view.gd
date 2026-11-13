extends Control
class_name CargoBalanceView

## 3D cross-section hold: the ship rolls by the model heel; crates, cursor, straps
## and draft marks are placed from the snapshot only.
signal command_requested(command: String, pressed: bool, source: String)
const Paper = preload("res://game/ui/paper_ui.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Model = preload("res://game/minigames/cargo_balance_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const STAGE := Rect2(24, 208, 1232, 364)
const GAUGE := Rect2(1046, 222, 198, 336)
const COMMANDS := ["left", "right", "up", "down", "grab", "strap", "confirm"]
const BUTTON_LABELS := ["A / ← 左移", "D / → 右移", "W / ↑ 上層", "S / ↓ 下層", "空白 吊起／放下", "F 指定繫帶", "Enter 出航／離港"]
const CELL := 1.1
const PIER_OFFSET := -4.6
const PORT_COLORS := {"A": Color("#e07a5f"), "B": Color("#4f9d9a")}
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
var _pier: Node3D
var _cursor: MeshInstance3D
var _water: MeshInstance3D
var _crates: Dictionary = {}
var _crate_labels: Dictionary = {}
var _straps: Dictionary = {}
var _draft_marks: Array[Label3D] = []
var _cog: MeshInstance3D

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

## Local position of a grid cell: hold cells ride on the ship, pier cells stay ashore.
static func cell_local(cell: Vector2i) -> Vector3:
	if cell.x >= Model.PIER_COLUMNS:
		return Vector3(Model.HOLD_X[cell.x - Model.PIER_COLUMNS], 0.55 + cell.y * CELL, 0)
	return Vector3(PIER_OFFSET + (cell.x - Model.PIER_COLUMNS) * CELL, 0.95 + cell.y * CELL, 0)

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

func _label3d(text: String, at: Vector3, parent: Node3D, font_size: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FontProfiles.current_font()
	label.font_size = font_size
	label.pixel_size = 0.009
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
	_viewport.name = "HoldViewport"
	_viewport.size = Vector2i(STAGE.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "HoldSection"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#d4dcd6")
	_environment.ambient_light_energy = 0.6
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	_sun = DirectionalLight3D.new()
	_sun.name = "HoldSun"
	_world.add_child(_sun)
	_camera = Camera3D.new()
	_camera.name = "HoldCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 5.6
	_camera.position = Vector3(-1.2, 1.4, 20)
	_world.add_child(_camera)
	_camera.look_at(Vector3(-1.2, 1.2, 0))
	_camera.current = true
	for item in [["hull", "#b5533c"], ["hull_dark", "#6b3427"], ["deck", "#d9c39a"], ["slot", "#8a7356"], ["pier", "#8c6a46"], ["strap", "#f3d36b"],
			["cursor", "#ffd36a"], ["mark", "#ffffff"], ["mast", "#ead9af"]]:
		_materials[item[0]] = _material(Color(item[1]))
	_materials.water = _material(Color("#3d7f93"), 0.72)
	_water = _box("Water", Vector3(30, 2.0, 2.2), Vector3(0, -0.6, 0.4), _world, _materials.water)
	_pier = Node3D.new()
	_pier.name = "Pier"
	_world.add_child(_pier)
	_box("PierDeck", Vector3(3.8, 0.3, 1.4), Vector3(PIER_OFFSET - 2.2, 0.25, 0), _pier, _materials.pier)
	for x in [-7.8, -5.6]:
		_box("PierPost", Vector3(0.2, 1.4, 0.2), Vector3(x, -0.4, 0.5), _pier, _materials.pier)
	_label3d("碼頭", Vector3(PIER_OFFSET - 2.2, 3.4, 0.2), _pier, 34)
	_ship = Node3D.new()
	_ship.name = "Ship"
	_world.add_child(_ship)
	_box("Keel", Vector3(5.6, 0.4, 1.4), Vector3(0, -0.2, 0), _ship, _materials.hull)
	for side in [-1, 1]:
		var wall := _box("HullSide", Vector3(0.25, 2.6, 1.4), Vector3(side * 3.0, 0.9, 0), _ship, _materials.hull)
		wall.rotation.z = side * 0.18
		_draft_marks.append(_label3d("", Vector3(side * 3.45, 0.2, 0.75), _ship, 26))
	_box("HoldFloor", Vector3(5.2, 0.08, 1.2), Vector3(0, 0.02, 0), _ship, _materials.deck)
	for column in Model.HOLD_COLUMNS:
		_box("SlotLine", Vector3(0.04, 2.2, 0.05), Vector3(Model.HOLD_X[column] + CELL * 0.68, 1.1, -0.6), _ship, _materials.slot)
	_box("Mast", Vector3(0.12, 3.6, 0.12), Vector3(-2.9, 2.0, -0.5), _ship, _materials.mast)
	# Assistance projects the cargo centre of gravity onto the hold floor.
	_cog = _box("GravityProjection", Vector3(0.06, 2.4, 0.06), Vector3(0, 1.2, 0.62), _ship, _materials.strap)
	_cursor = _box("Cursor", Vector3(CELL * 1.25, CELL * 0.95, 0.06), Vector3.ZERO, _world, _materials.cursor)
	(_cursor.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(_cursor.material_override as StandardMaterial3D).albedo_color = Color("#ffd36a", 0.35)
	for crate: Dictionary in _snapshot.crates:
		var edge: float = 0.55 + float(crate.weight) * 0.12
		var node := _box("Crate%d" % crate.id, Vector3(edge * 1.15, edge, 0.9), Vector3.ZERO, _world, _material(PORT_COLORS[crate.port]))
		_crate_labels[crate.id] = _label3d("", Vector3(0, 0, 0.5), node, 28)
		_straps[crate.id] = _box("Strap", Vector3(edge * 1.2, 0.08, 0.95), Vector3(0, 0, 0), node, _materials.strap)
		_crates[crate.id] = node

func _apply_snapshot() -> void:
	if _snapshot.is_empty():
		return
	var heel := float(_snapshot.heel)
	var docked: bool = _snapshot.phase in ["loading", "port"]
	_ship.rotation.z = -deg_to_rad(heel)
	_ship.position.y = 0.0 if _reduced_motion or docked else sin(float(_snapshot.elapsed) * 1.3) * 0.04
	_pier.visible = docked
	var cursor: Vector2i = _snapshot.cursor
	_cursor.global_transform = _ship.global_transform * Transform3D(Basis(), cell_local(cursor)) if cursor.x >= Model.PIER_COLUMNS else Transform3D(Basis(), cell_local(cursor))
	_cursor.position.z = 0.55
	for crate: Dictionary in _snapshot.crates:
		var node: MeshInstance3D = _crates[crate.id]
		node.visible = not crate.delivered
		if crate.delivered:
			continue
		var cell: Vector2i = cursor if crate.held else crate.cell
		var local := cell_local(cell) + (Vector3(0, 0.45, 0.2) if crate.held else Vector3.ZERO)
		node.global_transform = (_ship.global_transform * Transform3D(Basis(), local)) if cell.x >= Model.PIER_COLUMNS else Transform3D(Basis(), local)
		var strap: MeshInstance3D = _straps[crate.id]
		strap.visible = crate.strapped or crate.strap_timer >= 0.0
		(strap.material_override as StandardMaterial3D).albedo_color = Color("#f3d36b") if crate.strapped else Color("#f3d36b", 0.4)
		_crate_labels[crate.id].text = "%d噸 %s%s" % [crate.weight, Model.PORT_NAMES[crate.port], " 綁" if crate.strapped else ""]
	_cog.visible = bool(_snapshot.assisted)
	_cog.position.x = float(_snapshot.moment) / maxf(1.0, _total_weight())
	# Draft marks read the waterline depth on each side, so the roll is legible without color.
	var low := absf(heel) * 0.04
	_draft_marks[0].text = "左吃水 %.2f" % (1.0 + (low if heel < 0.0 else -low))
	_draft_marks[1].text = "右吃水 %.2f" % (1.0 + (low if heel > 0.0 else -low))
	var night := _time_phase == "night"
	_environment.background_color = Color("#1b2c3a") if night else Color("#bcd0cf")
	_sun.light_color = {"dawn": Color("#f2caad"), "noon": Color("#f8efcf"), "dusk": Color("#e2b19c"), "night": Color("#a5c2d8")}.get(_time_phase, Color("#f8efcf"))
	_sun.light_energy = 0.75 if night else 1.1
	_sun.rotation_degrees = Vector3(-35, -25, 0)

func status_text() -> String:
	if _snapshot.is_empty():
		return ""
	var phase: String = {"loading": "裝貨中", "sailing": "航行第 %d 段" % (int(_snapshot.segment) + 1), "port": "停靠%s" % Model.PORT_NAMES.get(_snapshot.port, "")}.get(_snapshot.phase, "")
	return "%s   |   傾斜 %+.1f°（安全 ±%d°）   |   重心 %+.2f   |   繫帶 %d / %d   |   %s" % [phase, _snapshot.heel, int(Model.SAFE_HEEL), float(_snapshot.moment) / maxf(1.0, _total_weight()), _snapshot.straps, Model.MAX_STRAPS, _snapshot.variant_name]

func wave_text() -> String:
	if _snapshot.is_empty():
		return ""
	var wave: Dictionary = _snapshot.upcoming
	if _snapshot.phase != "sailing":
		var order: Array[String] = []
		for port in _snapshot.port_order:
			order.append(Model.PORT_NAMES[port])
		return "靠港順序：%s　｜　航行中只能在船艙內移箱，Enter 出航或卸完離港" % "→".join(order)
	if wave.is_empty() or not wave.visible:
		return "海面平靜；側浪預告會在來臨前出現"
	return "側浪從%s來，%.1f 秒後；照現在排法最大傾斜約 %+.1f°%s" % ["右" if wave.direction < 0 else "左", wave["in"], wave.predicted, "（超過安全）" if absf(wave.predicted) > Model.SAFE_HEEL else ""]

func _total_weight() -> float:
	var total := 0.0
	for crate: Dictionary in _snapshot.crates:
		if not crate.delivered and crate.cell.x >= Model.PIER_COLUMNS:
			total += crate.weight
	return total

func _text(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = Paper.PAPER) -> void:
	draw_string(Paper.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * Paper.text_scale()), color)

func _draw() -> void:
	draw_rect(Rect2(24, 140, 1232, 62), Paper.DEEP_TEAL)
	if not _snapshot.is_empty():
		_text(Vector2(40, 164), status_text(), 1200)
		_text(Vector2(40, 191), wave_text(), 1200, 17, Paper.GOLD if not _snapshot.upcoming.is_empty() and _snapshot.upcoming.visible else Paper.PAPER)
		_draw_gauge()
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var rect := button_rect(command)
		var held := _pointer_owners.values().has(command)
		draw_rect(rect, Paper.FRAME if held else Paper.DEEP_TEAL)
		draw_rect(rect, Paper.GOLD if held else Paper.TEAL, false, 2)
		_text(rect.position + Vector2(10, 34), BUTTON_LABELS[i], rect.size.x - 16, 16)
	_text(Vector2(30, 673), str(_snapshot.get("feedback", "")), 1210, 20, Paper.GOLD)
	_text(Vector2(30, 704), "重箱放低放中間船最穩；上層方便卸貨但更容易傾斜。沒繫帶的箱子在大傾斜時會滑動。", 1210, 17)

## Heel gauge with safe, slide and capsize bands plus the predicted wave peak.
func _draw_gauge() -> void:
	draw_rect(GAUGE, Color(Paper.DEEP, 0.86))
	draw_rect(GAUGE, Paper.TEAL, false, 2)
	_text(GAUGE.position + Vector2(10, 22), "傾斜儀", 170, 16, Paper.GOLD)
	var center := Vector2(GAUGE.get_center().x, GAUGE.position.y + 150)
	var radius := 80.0
	for band in [[Model.CAPSIZE_HEEL, Color("#a03a2c")], [Model.SLIDE_HEEL, Color("#c97b3d")], [Model.SAFE_HEEL, Color("#3f7f6c")]]:
		var limit := deg_to_rad(float(band[0]) * 2.0)
		draw_arc(center, radius, -PI / 2.0 - limit, -PI / 2.0 + limit, 24, band[1], 14)
	var needle := deg_to_rad(float(_snapshot.heel) * 2.0)
	draw_line(center, center + Vector2(sin(needle), -cos(needle)) * (radius + 8), Paper.PAPER, 4)
	var wave: Dictionary = _snapshot.upcoming
	if not wave.is_empty() and wave.visible:
		var predicted := deg_to_rad(clampf(float(wave.predicted), -30.0, 30.0) * 2.0)
		draw_line(center, center + Vector2(sin(predicted), -cos(predicted)) * (radius - 10), Color("#ffd36a"), 2)
	_text(Vector2(GAUGE.position.x + 14, center.y + 40), "%+.1f°" % float(_snapshot.heel), 170, 22)
	_text(Vector2(GAUGE.position.x + 14, center.y + 70), "綠：安全　橙：滑箱", 180, 13)
	_text(Vector2(GAUGE.position.x + 14, center.y + 92), "紅：進水　金線：浪後預估", 180, 13)
	if _snapshot.assisted:
		_text(Vector2(GAUGE.position.x + 14, center.y + 118), "重心偏移 %+.2f" % (float(_snapshot.moment) / maxf(1.0, _total_weight())), 180, 14, Paper.GOLD)
