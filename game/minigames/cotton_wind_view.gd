extends Control
class_name CottonWindView

signal input_requested(event: InputEvent, design_point: Vector2)
signal clear_requested

const Paper = preload("res://game/ui/paper_ui.gd")
const Model = preload("res://game/minigames/cotton_wind_model.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const WORKSPACE := Rect2(24, 242, 880, 390)
const COMMAND_PANEL := Rect2(916, 242, 340, 390)
const COMMANDS := ["left", "right", "near", "far", "spin_left", "spin_right", "finish", "helper"]
const KEYS := {
	KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right",
	KEY_W: "near", KEY_UP: "near", KEY_S: "far", KEY_DOWN: "far",
	KEY_Q: "spin_left", KEY_E: "spin_right", KEY_SPACE: "spin_right", KEY_F: "finish", KEY_R: "helper",
}
const ACTIONS := ["左移", "右移", "靠近糖源", "遠離糖源", "逆向轉棒", "順向轉棒", "確認成品", "AI 幫手"]
const KEY_LABELS := ["A / ←", "D / →", "W / ↑", "S / ↓", "Q", "E / Space", "F", "R"]
const TOOLTIPS := ["按住左移", "按住右移", "近處易收粗絲", "遠處可收薄絲", "按住逆轉，點一下鎖定", "按住順轉，點一下鎖定", "三段均勻後確認", "切換只收自己糖絲的幫手"]
const BAND_NAMES := ["左段", "中段", "右段"]
const BAND_TINTS := [Color("#ffd0ac"), Color("#ffadd5"), Color("#d5bbff")]
const WOOD := Color("#b68055")
const HELPER_TINT := Color("#8ae0c4")
const BOARD := Color("#153146")
const EDGE := Color("#4e768c")
const CAMERA_FOCUS := Vector3(0, 94, 100)
const CAMERA_YAW := PI / 18.0
const CAMERA_RIGHT := Vector3(cos(CAMERA_YAW), 0, -sin(CAMERA_YAW))
const CAMERA_UP := Vector3(-0.8 * sin(CAMERA_YAW), 0.6, -0.8 * cos(CAMERA_YAW))
const CAMERA_BACK := Vector3(0.6 * sin(CAMERA_YAW), 0.8, 0.6 * cos(CAMERA_YAW))
const CAMERA_SIZE := 205.0
const PIXELS_PER_UNIT := WORKSPACE.size.y / CAMERA_SIZE
const STICK_HEIGHT := 90.0
const RING_SAMPLES := 24
const BAND_EDGES := [-90.0, -30.0, 30.0, 90.0]

var _state: Dictionary = {}
var _labels: Dictionary = {}
var _buttons: Dictionary = {}
var _band_labels: Array[Label] = []
var _band_markers: Array[Label] = []
var _font: Font
var _text_scale := 0.0
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _environment: Environment
var _player: Node3D
var _helper: Node3D
var _player_mesh := ArrayMesh.new()
var _helper_mesh := ArrayMesh.new()
var _catch_meshes: Array[ArrayMesh] = [ArrayMesh.new(), ArrayMesh.new()]
var _catch_zones: Array[MeshInstance3D] = []
var _strand_batch: MultiMesh
var _tail_line: MeshInstance3D
var _anchor: MeshInstance3D
var _free_end: MeshInstance3D
var _tail_material: StandardMaterial3D
var _revision := -1
var _time_phase := "noon"

static func key_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode else event.keycode

static func pointer_source(event: InputEvent) -> String:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventMouseMotion:
		return "mouse"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d" % event.index
	return ""

static func button_rect(command: String) -> Rect2:
	var index := COMMANDS.find(command)
	if index < 0:
		return Rect2()
	var cell := COMMAND_PANEL.size / Vector2(2, 4)
	var origin := COMMAND_PANEL.position + Vector2(index % 2, floori(index / 2.0)) * cell
	return Rect2(origin.round() + Vector2(4, 4), cell.ceil() - Vector2(8, 8))

static func command_at(design_point: Vector2) -> String:
	for command in COMMANDS:
		if button_rect(command).has_point(design_point):
			return command
	return ""

static func command_center(command: String) -> Vector2:
	return button_rect(command).get_center()

static func world_to_design(world_point: Vector3) -> Vector2:
	var relative := world_point - CAMERA_FOCUS
	return WORKSPACE.get_center() + Vector2(CAMERA_RIGHT.dot(relative), -CAMERA_UP.dot(relative)) * PIXELS_PER_UNIT

static func stick_to_design(stick_point: Vector2) -> Vector2:
	return world_to_design(Vector3(stick_point.x, STICK_HEIGHT, stick_point.y))

static func design_to_stick(design_point: Vector2) -> Vector2:
	var x_axis := Vector2(CAMERA_RIGHT.x, -CAMERA_UP.x) * PIXELS_PER_UNIT
	var z_axis := Vector2(CAMERA_RIGHT.z, -CAMERA_UP.z) * PIXELS_PER_UNIT
	var projection := Transform2D(x_axis, z_axis, world_to_design(Vector3(0, STICK_HEIGHT, 0)))
	return projection.affine_inverse() * design_point

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_exited.connect(clear_requested.emit)
	_create_stage()
	_create_interface()
	_apply_snapshot()
	grab_focus()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT] \
		or (what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree()):
		clear_requested.emit()

func _gui_input(event: InputEvent) -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if event is InputEventKey:
		if not KEYS.has(key_code(event)):
			return
	elif pointer_source(event).is_empty():
		return
	var point: Vector2 = Vector2.ZERO if event is InputEventKey else event.position
	input_requested.emit(event, point)
	accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	if WORKSPACE.has_point(at_position):
		return "拖曳移棒，點轉棒按鈕可邊轉邊移"
	var command := COMMANDS.find(command_at(at_position))
	return TOOLTIPS[command] if command >= 0 else ""

func present(state: Dictionary, time_phase: String, _reduced_motion: bool) -> void:
	_state = state
	_time_phase = time_phase
	if is_node_ready():
		_apply_snapshot()
	queue_redraw()

func _add_label(label_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.set_meta("base_font", font_size)
	add_child(label)
	label.position = rect.position
	label.size = rect.size
	_labels[label_name] = label
	return label

func _create_interface() -> void:
	var normal := Paper.button_box(Paper.FRAME, EDGE)
	var held := Paper.button_box(Color("#4b4541"), Paper.GOLD)
	for i in COMMANDS.size():
		var command: String = COMMANDS[i]
		var button := Button.new()
		button.name = command.capitalize().replace(" ", "")
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.text = ACTIONS[i] + "\n" + KEY_LABELS[i]
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("pressed", held)
		button.add_theme_color_override("font_color", Paper.PAPER)
		button.add_theme_color_override("font_pressed_color", Paper.GOLD)
		add_child(button)
		button.position = button_rect(command).position
		button.size = button_rect(command).size
		_buttons[command] = button
	_add_label("Mode", Rect2(40, 146, 770, 40), 28, Paper.PAPER)
	_add_label("Time", Rect2(900, 146, 336, 40), 23, Paper.GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_label("Wind", Rect2(40, 187, 550, 25), 18, Paper.TEAL)
	_add_label("Progress", Rect2(740, 187, 496, 25), 18, Paper.TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_label("Instruction", Rect2(40, 212, 1198, 27), 17, Paper.PAPER).text = "靠近糖源收得粗、遠處收得細。左右移棒餵足三段，轉棒把每段捲勻。"
	for i in 3:
		var band := _add_label("Band%d" % (i + 1), Rect2(37 + i * 288, 247, 278, 54), 16, BAND_TINTS[i])
		band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_band_labels.append(band)
		var marker := _add_label("RodBand%d" % (i + 1), Rect2(0, 0, 44, 24), 14, BAND_TINTS[i])
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_color_override("font_outline_color", Paper.DEEP)
		marker.add_theme_constant_override("outline_size", 5)
		marker.text = BAND_NAMES[i]
		_band_markers.append(marker)
	_add_label("Near", Rect2(38, 303, 108, 30), 16, Paper.GOLD).text = "近 · 糖源"
	_add_label("Far", Rect2(38, 546, 108, 30), 16, Paper.PAPER).text = "遠 · 薄絲"
	for endpoint in ["Anchor", "FreeEnd"]:
		var caption := _add_label(endpoint, Rect2(0, 0, 68, 27), 14, Paper.CORAL)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_outline_color", Paper.DEEP)
		caption.add_theme_constant_override("outline_size", 5)
	_labels.Anchor.text = "錨點"
	_labels.FreeEnd.text = "自由端"
	_add_label("QualityRule", Rect2(40, 574, 850, 24), 15, Paper.PAPER)
	_add_label("Tail", Rect2(40, 599, 850, 26), 17, Paper.GOLD)
	_add_label("Feedback", Rect2(40, 635, 1200, 31), 20, Paper.GOLD)
	_add_label("RejoinRule", Rect2(40, 668, 1200, 25), 16, Paper.PAPER).text = "將斷時轉棒，用另一外段碰自由端。均勻並實際接回可得小惡魔；AI 只收自己的糖絲。"
	_add_label("ParticipationRule", Rect2(40, 692, 1200, 25), 16, Paper.PAPER).text = "正式回合自然結束，收絲至少 1、移棒至少 6、轉棒至少 0.5 弧度可收藏普通拍貼。均勻後確認才通關。"

func _material(tint: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.85
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _mesh(node_name: String, mesh: Mesh, parent: Node3D, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _box(node_name: String, extent: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = extent
	_mesh(node_name, mesh, _world, material).position = at

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh

func _rod(node_name: String, cotton: ArrayMesh, grip_color: Color, cotton_material: Material) -> Node3D:
	var rod := Node3D.new()
	rod.name = node_name
	_world.add_child(rod)
	_mesh("DepositedCotton", cotton, rod, cotton_material)
	var grip := _cylinder(4.1, 15.0)
	var grip_material := _material(grip_color)
	var marker_material := _material(Paper.GOLD)
	for side in [-1, 1]:
		var handle := _mesh("Grip%d" % side, grip, rod, grip_material)
		handle.rotation.z = PI / 2.0
		handle.position.x = side * 97.0
		var mark := BoxMesh.new()
		mark.size = Vector3(10, 1.5, 2)
		_mesh("RotationMark%d" % side, mark, rod, marker_material).position = Vector3(side * 97.0, 4.1, 0)
	return rod

func _create_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "SpatialStage"
	container.position = WORKSPACE.position
	container.size = WORKSPACE.size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "CottonViewport"
	_viewport.size = Vector2i(WORKSPACE.size)
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "Workbench"
	_viewport.add_child(_world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#c8d2e7")
	_environment.ambient_light_energy = 0.48
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	_world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-64, -35, 0)
	light.light_energy = 0.75
	_world.add_child(light)
	_camera = Camera3D.new()
	_camera.name = "WorkbenchCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = CAMERA_SIZE
	_camera.transform = Transform3D(Basis(CAMERA_RIGHT, CAMERA_UP, CAMERA_BACK), CAMERA_FOCUS + CAMERA_BACK * 500.0)
	_world.add_child(_camera)
	_camera.current = true
	_box("Countertop", Vector3(490, 10, 254), Vector3(0, -4, 93), _material(Color("#345671")))
	var lane_material := _material(Color("#57778c"))
	for z in [45.0, 100.0, 155.0]:
		_box("DistanceLine", Vector3(406, 0.2, 1.2), Vector3(0, 1.15, z), lane_material)
	var spinner := _mesh("SugarSpinner", _cylinder(27.0, 34.0), _world, _material(Color("#a85c74")))
	spinner.position = Vector3(0, 20, 0)
	_mesh("SpinnerRim", _cylinder(29.0, 4.0), _world, _material(Color("#d492a8"))).position.y = 37
	_mesh("SugarSource", _cylinder(21.0, 1.0), _world, _material(Color("#ffd287"))).position.y = 39.2
	var cotton_material := _material(Color.WHITE)
	cotton_material.vertex_color_use_as_albedo = true
	cotton_material.vertex_color_is_srgb = true
	_player = _rod("PlayerStick", _player_mesh, WOOD, cotton_material)
	_helper = _rod("HelperStick", _helper_mesh, Color("#3c7c79"), cotton_material)
	var catch_material := _material(Color("#5af6ce"), true)
	for i in 2:
		_catch_zones.append(_mesh("Receiver%d" % (i * 2 + 1), _catch_meshes[i], _player, catch_material))
	_strand_batch = MultiMesh.new()
	_strand_batch.transform_format = MultiMesh.TRANSFORM_3D
	_strand_batch.use_colors = true
	_strand_batch.mesh = _cylinder(1.0, 1.0)
	_strand_batch.instance_count = Model.MAX_STRANDS
	_strand_batch.visible_instance_count = 0
	_strand_batch.custom_aabb = AABB(Vector3(-140, -24, -8), Vector3(280, 180, 260))
	var strands := MultiMeshInstance3D.new()
	strands.name = "AirborneStrands"
	strands.multimesh = _strand_batch
	var strand_material := _material(Color.WHITE, true)
	strand_material.vertex_color_use_as_albedo = true
	strands.material_override = strand_material
	_world.add_child(strands)
	_tail_material = _material(Paper.GOLD, true)
	_tail_line = _mesh("TailLine", _cylinder(1.0, 1.0), _world, _tail_material)
	var tip := SphereMesh.new()
	tip.radius = 2.8
	tip.height = 5.6
	tip.radial_segments = 12
	tip.rings = 6
	_anchor = _mesh("TailAnchor", tip, _world, _tail_material)
	_free_end = _mesh("TailFreeEnd", tip, _world, _tail_material)

func _sample_angle(sample: int) -> float:
	return (sample / 2 + (0.12 if sample % 2 == 0 else 0.88)) * TAU / 12.0

func _radial(sample: int) -> Vector3:
	var angle := _sample_angle(sample)
	return Vector3(0, cos(angle), sin(angle))

func _rebuild_cotton(mesh: ArrayMesh, bands: Array, helper: bool) -> void:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var faces := PackedInt32Array()
	for ring in 6:
		var band: int = ring / 2
		var x: float = BAND_EDGES[band + ring % 2]
		if ring > 0 and ring < 5:
			x += -0.7 if ring % 2 else 0.7
		for sample in RING_SAMPLES:
			var mass: float = bands[band][sample / 2]
			var radial := _radial(sample)
			points.append(Vector3(x, 0, 0) + radial * Model.radius(mass))
			var before := posmod(sample - 1, RING_SAMPLES)
			var after := (sample + 1) % RING_SAMPLES
			var tangent := _radial(after) * Model.radius(bands[band][after / 2]) - _radial(before) * Model.radius(bands[band][before / 2])
			normals.append(radial.lerp(tangent.cross(Vector3.RIGHT).normalized(), 0.65).normalized())
			var tint: Color = HELPER_TINT if helper else BAND_TINTS[band]
			colors.append(WOOD.lerp(tint.darkened(0.18 - 0.035 * mass), clampf(sqrt(mass) * 3.5, 0.0, 1.0)))
			if ring < 5:
				var near := ring * RING_SAMPLES + sample
				var next := ring * RING_SAMPLES + (sample + 1) % RING_SAMPLES
				faces.append_array([near, near + RING_SAMPLES, next, next, near + RING_SAMPLES, next + RING_SAMPLES])
	for side in 2:
		var base := points.size()
		var normal := Vector3.LEFT if side == 0 else Vector3.RIGHT
		var source := 0 if side == 0 else 5 * RING_SAMPLES
		for sample in RING_SAMPLES:
			points.append(points[source + sample])
			normals.append(normal)
			colors.append(colors[source + sample])
			var current := base + sample
			var next := base + (sample + 1) % RING_SAMPLES
			faces.append_array([base + RING_SAMPLES, current, next] if side == 0 else [base + RING_SAMPLES, next, current])
		points.append(Vector3(BAND_EDGES[side * 3], 0, 0))
		normals.append(normal)
		colors.append(WOOD)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = faces
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _rebuild_receiver(mesh: ArrayMesh, band: int, cells: Array, margin: float) -> void:
	var lines := PackedVector3Array()
	for sample in RING_SAMPLES:
		var next := (sample + 1) % RING_SAMPLES
		var radius := Model.radius(cells[sample / 2]) + margin
		var turn := _radial(sample) * radius
		var next_turn := _radial(next) * (Model.radius(cells[next / 2]) + margin)
		var start := Vector3(BAND_EDGES[band], 0, 0)
		var finish := Vector3(BAND_EDGES[band + 1], 0, 0)
		lines.append_array([start + turn, start + next_turn, finish + turn, finish + next_turn])
		if sample % 6 == 0:
			lines.append_array([start + turn, finish + turn])
			# Only the outside tip is capped. The middle-band boundary is axial.
			var end := -1 if band == 0 else 1
			var center := start if end == -1 else finish
			var previous := center + turn
			for segment in range(1, 5):
				var angle := segment * PI / 8.0
				var point := center + turn * cos(angle) + Vector3(end * radius * sin(angle), 0, 0)
				lines.append_array([previous, point])
				previous = point
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

func _segment(from: Vector3, to: Vector3, width: float) -> Transform3D:
	var difference := to - from
	var length := difference.length()
	var axis := difference / length if length > 0.0001 else Vector3.UP
	var normal := axis.cross(Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD).normalized()
	return Transform3D(Basis(normal * width, axis * maxf(length, 0.0001), normal.cross(axis) * width), (from + to) * 0.5)

func _apply_snapshot() -> void:
	if _state.is_empty():
		return
	_environment.background_color = Color("#1a314c") if _time_phase == "night" else BOARD
	_player.position = _state.stick
	_player.rotation.x = _state.angle
	_helper.visible = _state.helper
	_helper.position = _state.helper_stick
	_helper.rotation.x = _state.helper_angle
	if _revision != _state.revision:
		_revision = _state.revision
		_rebuild_cotton(_player_mesh, _state.bands, false)
		_rebuild_cotton(_helper_mesh, _state.helper_bands, true)
		for i in 2:
			var band := i * 2
			_rebuild_receiver(_catch_meshes[i], band, _state.bands[band], 8.0 if _state.assisted else 4.0)
	_strand_batch.visible_instance_count = _state.strands.size()
	for i in _state.strands.size():
		var strand: Dictionary = _state.strands[i]
		var strength := clampf(float(strand.collectible) / Model.STRAND_MASS, 0.0, 1.0)
		_strand_batch.set_instance_transform(i, _segment(strand.previous, strand.position, 0.55 + strength * 0.45))
		_strand_batch.set_instance_color(i, Color("#ffe8f3").lerp(Color("#ffd8a0"), strength))
	var tail: Dictionary = _state.tail
	_tail_line.visible = not tail.is_empty()
	_anchor.visible = _tail_line.visible
	_free_end.visible = _tail_line.visible
	for i in 2:
		_catch_zones[i].visible = not tail.is_empty() and tail.receiver_band == i * 2
	if not tail.is_empty():
		_tail_material.albedo_color = Color("#fc6c52") if tail.near_break else Paper.GOLD
		_tail_line.transform = _segment(tail.anchor, tail.free_end, 1.35 if tail.near_break else 0.95)
		_anchor.position = tail.anchor
		_free_end.position = tail.free_end
	_apply_interface()

func _apply_interface() -> void:
	var font := Paper.font()
	var text_scale := Paper.text_scale()
	if _font != font or _text_scale != text_scale:
		_font = font
		_text_scale = text_scale
		for label: Label in _labels.values():
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", roundi(float(label.get_meta("base_font")) * text_scale))
		for button: Button in _buttons.values():
			button.add_theme_font_override("font", font)
			button.add_theme_font_size_override("font_size", roundi(20 * text_scale))
	var helper := "關閉"
	if _state.helper:
		helper = "讓位" if _state.helper_yielding else "收絲 %.1f" % _state.material.helper
	_labels.Mode.text = "棉糖捲風 · %s 區熱風%s" % ["AB"[_state.variant], " · 輔助" if _state.assisted else ""]
	_labels.Time.text = _state.get("time_text", "%d 秒" % ceili(_state.remaining))
	var wind: float = _state.wind
	var direction := "靜" if absf(wind) < 0.05 else ("左" if wind < 0.0 else "右")
	_labels.Wind.text = "熱風 %s %.1f    AI %s" % [direction, absf(wind), helper]
	_labels.Progress.text = _state.get("progress_text", "接回 %d 次" % _state.rejoins)
	_labels.QualityRule.text = "均勻門檻 · 各段 12 以上 · 至少 %d 格 · CV ≤ %s · 厚薄比 ≤ %s" % (
		[7, "0.80", "1.50"] if _state.assisted else [8, "0.65", "1.35"])
	var spin_note := "｜點轉棒鈕可鎖定，再點停止" if not _state.ended else ""
	_labels.Feedback.text = "%s%s" % [_state.feedback, spin_note]
	for i in 3:
		var q: Dictionary = _state.quality[i]
		_band_labels[i].text = "%s %.1f%s\n%d/12 格 · CV %.2f" % [BAND_NAMES[i], q.mass, " ✓" if q.ready else "", q.coverage, q.cv]
		_band_markers[i].position = world_to_design(_state.stick + Vector3((i - 1) * 60.0, 24, 0)) - Vector2(22, 18)
	var tail: Dictionary = _state.tail
	_labels.Anchor.visible = not tail.is_empty() and tail.near_break
	_labels.FreeEnd.visible = _labels.Anchor.visible
	if tail.is_empty():
		_labels.Tail.text = "三段%s · 厚薄比 %.2f    ｜    等待外段遠處收出懸絲" % ["均勻" if _state.uniform else "調整中", _state.ratio]
	else:
		var action := "將自由端移入亮框的%s" % BAND_NAMES[tail.receiver_band] if tail.near_break else "移棒拉出張力，將斷時才可接回"
		_labels.Tail.text = "%s · 張力 %.0f    ｜    %s" % ["將斷" if tail.near_break else "懸絲", tail.tension, action]
		var low := WORKSPACE.position + Vector2(10, 70)
		var high := WORKSPACE.end - Vector2(80, 65)
		_labels.Anchor.position = (world_to_design(tail.anchor) + Vector2(-34, 6)).clamp(low, high)
		_labels.FreeEnd.position = (world_to_design(tail.free_end) + Vector2(-34, 6)).clamp(low, high)
	for command: String in COMMANDS:
		_buttons[command].set_pressed_no_signal(command in _state.get("held_commands", []) or (command == "helper" and _state.helper))

func _draw() -> void:
	draw_rect(Rect2(0, 140, 1280, 580), Paper.DEEP)
	draw_rect(WORKSPACE.grow(2), EDGE)
	draw_rect(COMMAND_PANEL, BOARD)
