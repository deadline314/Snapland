extends Control

signal input_requested(event: InputEvent, design_point: Vector2)

const Model = preload("res://game/minigames/bean_seesaw_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const STAGE := Rect2(24, 231, 1232, 328)
enum { HOPPER_LEFT = 5, HOPPER_RIGHT, HELPER, FINISH }
const BUTTONS := ["最左", "左", "中央", "右", "最右", "左料斗 · Q", "右料斗 · E", "AI 扶板 · R", "結算 · F"]
const TOOLTIPS := [
	"大幅抬高右端", "稍微抬高右端", "讓兩端回到接近平衡", "稍微抬高左端", "大幅抬高左端",
	"放出左料斗的下一顆豆", "放出右料斗的下一顆豆", "減少板端晃動，放豆仍由你控制", "雙盤同步後可提早結算",
]
const MINT := Color("#83e1c3")
const PINK := Color("#f991ad")
const GOLD := Color("#ffd18c")
const RAISIN := Color("#28283c")
const CREAM := Color("#fff0da")

var _state: Dictionary = {}
var _buttons: Array[Button] = []
var _labels: Array[Label] = []
var _board: Node3D
var _pedal: MeshInstance3D
var _side_slot: MeshInstance3D
var _hoppers: Array[Node3D] = []
var _hopper_labels: Array[Label3D] = []
var _pans: Array[Label3D] = []
var _pan_bases: Array[MeshInstance3D] = []
var _beans: Array[MeshInstance3D] = []
var _bean_materials: Array[StandardMaterial3D] = []
var _pan_empty: StandardMaterial3D
var _slot_empty: StandardMaterial3D
var _slot_full: StandardMaterial3D
var _text_scale := 0.0

static func button_rect(index: int) -> Rect2:
	if index < 0 or index >= BUTTONS.size():
		return Rect2()
	if index < HOPPER_LEFT:
		return Rect2(24 + index * 98, 592, 90, 72)
	return Rect2(522 + (index - HOPPER_LEFT) * 184, 592, 172, 72)

static func button_at(point: Vector2) -> int:
	for index in BUTTONS.size():
		if button_rect(index).has_point(point):
			return index
	return -1

func _get_tooltip(at_position: Vector2) -> String:
	var index := button_at(at_position)
	return TOOLTIPS[index] if index >= 0 else ""

func _gui_input(event: InputEvent) -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if button_at(event.position) >= 0:
			input_requested.emit(event, event.position)
			accept_event()

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_make_stage()
	_make_widgets()
	_apply()

func present(state: Dictionary) -> void:
	_state = state
	if is_node_ready():
		_apply()

func _make_widgets() -> void:
	_add_label(Rect2(32, 164, 1216, 29), 22, CREAM)
	_add_label(Rect2(32, 198, 1216, 26), 19, MINT)
	_add_label(Rect2(32, 560, 1216, 28), 17, GOLD)
	var normal := Paper.button_box(Color("#37324a"), Color("#8c7c99"))
	var selected := Paper.button_box(Color("#54384d"), GOLD)
	for index in BUTTONS.size():
		var button := Button.new()
		button.text = BUTTONS[index]
		button.tooltip_text = TOOLTIPS[index]
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.toggle_mode = true
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_pressed_color", GOLD)
		add_child(button)
		button.position = button_rect(index).position
		button.size = button_rect(index).size
		_buttons.append(button)

func _add_label(rect: Rect2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.set_meta("font_size", font_size)
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	_labels.append(label)

func _apply() -> void:
	if _state.is_empty():
		return
	var current_scale := Paper.text_scale()
	if _text_scale != current_scale:
		_text_scale = current_scale
		for label in _labels:
			label.add_theme_font_override("font", Paper.font())
			label.add_theme_font_size_override("font_size", roundi(int(label.get_meta("font_size")) * _text_scale))
		for button in _buttons:
			button.add_theme_font_override("font", Paper.font())
			button.add_theme_font_size_override("font_size", roundi(19.0 * _text_scale))
	var sync_text: String = "已同步 · %.2f 秒" % _state.pair_gap if _state.paired else "雙盤須於 %.2f 秒內各接一顆" % _state.sync_window
	_labels[0].text = "%s    ｜    側槽%s" % [sync_text, "已收" if _state.side_catch else "待回彈"]
	_labels[1].text = _state.feedback_text
	var rise: float = _state.angular_speed * Model.HALF_LENGTH * cos(_state.angle)
	_labels[2].text = "A / D 或方向鍵移踏板，Home / End 到兩端    ｜    右端 %s %.1f    ｜    %s" % [
		"上升 ↑" if rise > 0.10 else ("下降 ↓" if rise < -0.10 else "平穩"), absf(rise),
		"雙料斗高低不同" if _state.layout == 1 else "左料斗先出重豆",
	]
	_board.rotation.z = _state.angle
	_pedal.position.x = _state.pedal * 0.59
	_side_slot.material_override = _slot_full if _state.side_catch else _slot_empty
	for index in _buttons.size():
		_buttons[index].set_pressed_no_signal(index == _state.pedal + Model.MAX_PEDAL or (index == HELPER and _state.helper))
	for index in 2:
		var hopper: Vector2 = _state.hoppers[index]
		_hoppers[index].position = Vector3(hopper.x, hopper.y + 0.18, 0)
		var bean: Dictionary = _state.beans[index]
		_beans[index].visible = bean.phase != Model.Flight.EMPTY
		var mass: int = bean.mass if _beans[index].visible else _state.next_masses[index]
		_hopper_labels[index].text = ("左" if index == 0 else "右") + (" · 輕 1" if mass == 1 else " · 重 2")
		_hopper_labels[index].modulate = _bean_materials[mass - 1].albedo_color
		_pans[index].text = "%s秤盤  %d" % ["左" if index == 0 else "右", _state.pans[index]]
		_pan_bases[index].material_override = _bean_materials[0] if _state.pans[index] > 0 else _pan_empty
		if _beans[index].visible:
			_beans[index].position = Vector3(bean.position.x, bean.position.y, 0)
			_beans[index].scale = Vector3.ONE * Model.radius(bean.mass)
			_beans[index].material_override = _bean_materials[bean.mass - 1]

func _make_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "SeesawStage"
	container.position = STAGE.position
	container.size = STAGE.size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(STAGE.size)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.gui_disable_input = true
	viewport.world_3d = World3D.new()
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = RAISIN
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = CREAM
	environment.ambient_light_energy = 0.64
	var backdrop := WorldEnvironment.new()
	backdrop.environment = environment
	world.add_child(backdrop)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 0.90
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 4.92
	camera.position = Vector3(0, 4.75, 17)
	world.add_child(camera)
	camera.look_at(Vector3(0, 2.3, 0))
	camera.current = true

	var plum := _material(Color("#51425c"))
	var copper := _material(Color("#be7a67"))
	var cocoa := _material(Color("#774d59"))
	var mint := _material(MINT)
	var pink := _material(PINK)
	var ochre := _material(GOLD)
	_bean_materials.assign([mint, ochre])
	_pan_empty = _material(Color("#284a4f"))
	_slot_empty = plum
	_slot_full = pink
	_box(world, Vector3(13.8, 0.31, 2.5), Vector3(0, 0.14, 0), cocoa)
	_box(world, Vector3(13.65, 0.09, 2.4), Vector3(0, 0.33, 0), copper)
	_cylinder(world, 0.26, 0.68, Model.BOARD_HEIGHT - 0.36, Vector3(0, Model.BOARD_HEIGHT * 0.5 + 0.14, -0.06), plum)
	_cylinder(world, 0.28, 0.28, 0.28, Vector3(0, Model.BOARD_HEIGHT, 0.33), ochre).rotation_degrees.x = 90
	_board = Node3D.new()
	_board.position = Vector3(0, Model.BOARD_HEIGHT, 0)
	world.add_child(_board)
	_box(_board, Vector3(2 * Model.HALF_LENGTH, 0.18, 0.66), Vector3.ZERO, copper)
	_box(_board, Vector3(2 * Model.HALF_LENGTH, 0.12, 0.09), Vector3(0, 0.06, -0.31), ochre)
	_box(_board, Vector3(0.45, 0.06, 0.59), Vector3(2.11, 0.10, 0), pink)
	_pedal = _box(_board, Vector3(0.38, 0.23, 0.49), Vector3(0, -0.23, 0.02), mint)
	var margin := Model.ASSIST_MARGIN if bool(_state.get("assisted", false)) else 0.0
	for index in 2:
		var pan_x: float = Model.PAN_X * Model.DIRECTIONS[index]
		var stand_height := Model.PAN_HEIGHT - 0.28
		_cylinder(world, 0.13, 0.29, stand_height, Vector3(pan_x, 0.36 + stand_height * 0.5, 0), plum)
		_pan_bases.append(_pan(world, pan_x, Model.PAN_HALF_WIDTH + margin, mint, _pan_empty))
		_pans.append(_caption(world, Vector3(pan_x, 0.47, 0.84), MINT, 23))
		var hopper := Node3D.new()
		world.add_child(hopper)
		_hoppers.append(hopper)
		_cylinder(hopper, 0.43, 0.16, 0.49, Vector3.ZERO, cocoa)
		_cylinder(hopper, 0.46, 0.46, 0.09, Vector3(0, 0.27, 0), copper)
		_box(hopper, Vector3(0.23, 0.16, 0.35), Vector3(0, -0.24, 0), ochre)
		_hopper_labels.append(_caption(hopper, Vector3(0, 0.56, 0.03), CREAM, 30))
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 20
		sphere.rings = 10
		_beans.append(_piece(world, sphere, Vector3.ZERO, mint))
	_side_slot = _pan(world, Model.SIDE_X, Model.SIDE_HALF_WIDTH + margin, pink, _slot_empty)
	_caption(world, Vector3(Model.SIDE_X, 0.47, 0.84), PINK, 23).text = "側槽"

func _pan(world: Node3D, x: float, half_width: float, lip: Material, base: Material) -> MeshInstance3D:
	_box(world, Vector3(half_width * 2.0, 0.08, 0.13), Vector3(x, Model.PAN_HEIGHT, -0.41), lip)
	for direction in Model.DIRECTIONS:
		_box(world, Vector3(0.08, 0.13, 0.78), Vector3(x + direction * half_width, Model.PAN_HEIGHT - 0.02, 0), lip)
	return _box(world, Vector3(half_width * 2.0, 0.12, 0.84), Vector3(x, Model.PAN_HEIGHT - 0.09, 0), base)

func _caption(parent: Node3D, point: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.position = point
	label.font = Paper.font()
	label.font_size = font_size
	label.pixel_size = 0.011
	label.modulate = color
	label.outline_modulate = RAISIN
	label.outline_size = 10
	label.no_depth_test = true
	parent.add_child(label)
	return label

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.83
	return material

func _box(parent: Node3D, size: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _piece(parent, mesh, point, material)

func _cylinder(parent: Node3D, top: float, bottom: float, height: float, point: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	return _piece(parent, mesh, point, material)

func _piece(parent: Node3D, mesh: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = point
	parent.add_child(piece)
	return piece
