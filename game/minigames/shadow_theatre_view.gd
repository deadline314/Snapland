extends Control
class_name ShadowTheatreView

## Dedicated 3D tabletop theatre. Session owns controls and the model owns all results.
signal axis_requested(horizontal: float, depth: float)
signal lamp_target_requested(target: Vector2)
signal shutter_requested

const ModelScript = preload("res://game/minigames/shadow_theatre_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const HUD_SAFE_RECT := Rect2(0.0, 0.0, 1280.0, 130.0)
const PLAYFIELD_RECT := Rect2(64.0, 136.0, 1152.0, 548.0)
const STAGE_BOUNDS := Rect2(146.0, 160.0, 988.0, 510.0)
const CAMERA_VERTICAL_SIZE := 5.60
const CAMERA_YAW_DEGREES := 50.0
const WALL_HALF_WIDTH := 3.18
const WALL_HALF_HEIGHT := 1.27
const PUPPET_HALF_DEPTH := 0.045
const TARGET_OUTER_WIDTH := 0.030
const TARGET_INNER_WIDTH := 0.010
const PHASES: Array[String] = ["dawn", "noon", "dusk", "night"]
const PHASE_AMBIENT: Dictionary = {
	"dawn": Color("#d4a27f"), "noon": Color("#b9c8b5"),
	"dusk": Color("#a17c78"), "night": Color("#8e9c96")
}
const PHASE_AMBIENT_ENERGY: Dictionary = {"dawn": 0.34, "noon": 0.38, "dusk": 0.32, "night": 0.36}
const PHASE_LAMP: Dictionary = {
	"dawn": Color("#ffd5a3"), "noon": Color("#fff0c9"),
	"dusk": Color("#ffd18a"), "night": Color("#ffe0a6")
}

var _container: SubViewportContainer
var _shutter_button: Button
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _lamp_rig: Node3D
var _spot: SpotLight3D
var _bulb: MeshInstance3D
var _target_markers: Array[MeshInstance3D] = []
var _puppet: MeshInstance3D
var _wall_material: StandardMaterial3D
var _environment: Environment
var _wood_grain: Texture2D
var _paper_fiber: Texture2D
var _snapshot: Dictionary = {}
var _geometry_model: RefCounted
var _round := 0
var _phase := "noon"
var _reduced_motion := false
var _left_down := false
var _right_down := false
var _up_down := false
var _down_down := false
var _resume_focus_pending := false
var _fine_down := false
var geometry_build_count := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_theatre()
	grab_focus()
	set_process(true)

## Stable SubViewport output for Session or a parent composition.
func texture() -> ViewportTexture:
	return _viewport.get_texture() if _viewport != null else null

## Convert this Control's local mouse position to the canonical 1280x720 design frame.
func screen_to_design(screen_position: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(screen_position.x * DESIGN_SIZE.x / size.x, screen_position.y * DESIGN_SIZE.y / size.y)

func present_state(snapshot: Dictionary, time_phase: String = "noon", reduced_motion: bool = false) -> void:
	# Session still presents paused snapshots while disabling continuous controls.
	if not is_processing():
		_resume_focus_pending = true
		_fine_down = false
	_snapshot = snapshot
	_phase = time_phase if time_phase in PHASES else "noon"
	_reduced_motion = reduced_motion
	if _environment != null:
		_environment.ambient_light_color = PHASE_AMBIENT[_phase]
		_environment.ambient_light_energy = float(PHASE_AMBIENT_ENERGY[_phase])
	if _spot != null:
		_spot.light_color = PHASE_LAMP[_phase]
	var next_round := clampi(int(snapshot.get("round", 0)), 0, 2)
	if next_round != _round:
		_round = next_round
		for index in _target_markers.size():
			_target_markers[index].visible = index == _round
	var lamp_value: Variant = snapshot.get("lamp_position", Vector2(0.0, -2.5))
	var lamp_pos: Vector2 = lamp_value if lamp_value is Vector2 and is_finite(lamp_value.x) and is_finite(lamp_value.y) else Vector2(0.0, -2.5)
	_update_lamp(lamp_pos)
	if _puppet != null:
		_puppet.visible = not bool(snapshot.get("finished", false)) or bool(snapshot.get("success", false))
	if _viewport != null and _reduced_motion:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func playfield_rect() -> Rect2:
	return PLAYFIELD_RECT

func hud_safe_rect() -> Rect2:
	return HUD_SAFE_RECT

func geometry_bounds() -> Rect2:
	return STAGE_BOUNDS

func projected_geometry_bounds() -> Rect2:
	if _camera == null or not _camera.is_inside_tree():
		return Rect2()
	var world_points: Array[Vector3] = [
		Vector3(-3.55, -1.62, 2.3), Vector3(-3.55, 1.62, 2.3),
		Vector3(3.55, -1.62, 2.3), Vector3(3.55, 1.62, 2.3),
		Vector3(-1.8, -1.45, -3.1), Vector3(1.8, 1.1, -1.2)
	]
	for x in [ModelScript.LAMP_X_MIN, ModelScript.LAMP_X_MAX]:
		for z in [ModelScript.LAMP_Z_MIN, ModelScript.LAMP_Z_MAX]:
			var lamp_source := Vector2(x, z)
			world_points.append(Vector3(x, -1.35, z))
			world_points.append(Vector3(x, 0.40, z))
			for vertex in _geometry_model.projection_for(lamp_source, _geometry_model.puppet_vertices()):
				world_points.append(Vector3(vertex.x, vertex.y, ModelScript.WALL_Z))
	for round_index in 3:
		for vertex in _geometry_model.projection_for(_geometry_model.round_solution(round_index), _geometry_model.puppet_vertices()):
			world_points.append(Vector3(vertex.x, vertex.y, ModelScript.WALL_Z))
	var first := _camera.unproject_position(world_points[0])
	var left := first.x
	var right := first.x
	var top := first.y
	var bottom := first.y
	for world_point in world_points:
		var point := _camera.unproject_position(world_point)
		left = minf(left, point.x)
		right = maxf(right, point.x)
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func cast_shadow_screen_bounds() -> Rect2:
	if _camera == null:
		return Rect2()
	var vertices: Variant = _snapshot.get("cast_vertices", PackedVector2Array())
	return _projected_vertex_bounds(vertices)

func target_marker_bounds() -> Rect2:
	if _camera == null:
		return Rect2()
	var vertices: Variant = _snapshot.get("target_vertices", PackedVector2Array())
	return _projected_vertex_bounds(vertices)

func camera() -> Camera3D:
	return _camera

func sub_viewport() -> SubViewport:
	return _viewport

func ambient_environment() -> Environment:
	return _environment

func lamp_light() -> SpotLight3D:
	return _spot

func visible_emitter() -> MeshInstance3D:
	return _bulb

func shutter_button() -> Button:
	return _shutter_button

func puppet_mesh() -> MeshInstance3D:
	return _puppet

func target_marker(round_index: int = -1) -> MeshInstance3D:
	var index := _round if round_index < 0 else clampi(round_index, 0, _target_markers.size() - 1)
	return _target_markers[index] if index >= 0 and index < _target_markers.size() else null

func _process(_delta: float) -> void:
	if _resume_focus_pending:
		_resume_focus_pending = false
		grab_focus()
	var horizontal := float(int(_right_down) - int(_left_down))
	var depth := float(int(_up_down) - int(_down_down))
	if horizontal != 0.0 or depth != 0.0:
		var axis := Vector2(horizontal, depth).limit_length(1.0)
		axis_requested.emit(axis.x * (0.25 if _fine_down else 1.0), axis.y * (0.25 if _fine_down else 1.0))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		match key.keycode:
			KEY_SHIFT: _fine_down = key.pressed
			KEY_LEFT, KEY_A: _left_down = key.pressed
			KEY_RIGHT, KEY_D: _right_down = key.pressed
			KEY_UP, KEY_W: _up_down = key.pressed
			KEY_DOWN, KEY_S: _down_down = key.pressed
			KEY_SPACE:
				if key.pressed:
					shutter_requested.emit()
					accept_event()
					return
			_: return
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			lamp_target_requested.emit(_lamp_target_from_design(screen_to_design(event.position)))
		elif event.is_released():
			accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		lamp_target_requested.emit(_lamp_target_from_design(screen_to_design(event.position)))
		accept_event()

func _lamp_target_from_design(point: Vector2) -> Vector2:
	var x := lerpf(ModelScript.LAMP_X_MIN, ModelScript.LAMP_X_MAX, clampf((point.x - 160.0) / 960.0, 0.0, 1.0))
	var z := lerpf(ModelScript.LAMP_Z_MAX, ModelScript.LAMP_Z_MIN, clampf((point.y - 176.0) / 440.0, 0.0, 1.0))
	return Vector2(x, z)

func _projected_vertex_bounds(vertices: Variant) -> Rect2:
	if not vertices is PackedVector2Array or vertices.is_empty() or _camera == null:
		return Rect2()
	var first: Vector2 = _camera.unproject_position(Vector3(vertices[0].x, vertices[0].y, ModelScript.WALL_Z))
	var left := first.x
	var right := first.x
	var top := first.y
	var bottom := first.y
	for vertex in vertices:
		var screen := _camera.unproject_position(Vector3(vertex.x, vertex.y, ModelScript.WALL_Z))
		left = minf(left, screen.x)
		right = maxf(right, screen.x)
		top = minf(top, screen.y)
		bottom = maxf(bottom, screen.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _build_theatre() -> void:
	_geometry_model = ModelScript.new()
	_container = SubViewportContainer.new()
	_container.name = "ShadowTheatreViewportContainer"
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.name = "ShadowTheatreViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	_viewport.positional_shadow_atlas_size = 2048
	_viewport.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	for quadrant in range(1, 4):
		_viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_viewport)
	_build_shutter_button()
	_stage = Node3D.new()
	_stage.name = "PaperTheatre"
	_viewport.add_child(_stage)
	_wood_grain = _make_grain_texture(0.87, 0.14, 9024)
	_paper_fiber = _make_grain_texture(0.955, 0.065, 9025)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("#203c45")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = PHASE_AMBIENT["noon"]
	_environment.ambient_light_energy = PHASE_AMBIENT_ENERGY["noon"]
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "HarborNightAndDayFill"
	world.environment = _environment
	_stage.add_child(world)
	_camera = Camera3D.new()
	_camera.name = "TheatreCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_VERTICAL_SIZE
	_camera.position = Vector3(-tan(deg_to_rad(CAMERA_YAW_DEGREES)) * (ModelScript.WALL_Z + 7.4), 0.0, -7.4)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.0, ModelScript.WALL_Z), Vector3.UP)
	_stage.add_child(_camera)
	_camera.current = true
	_build_wall_and_frame()
	_build_puppet()
	_build_lamp()
	_build_rail()
	_set_only_puppet_shadow_caster(_stage)
	for round_index in 3:
		var marker := _build_marker(_geometry_model.projection_for(_geometry_model.round_solution(round_index), _geometry_model.puppet_vertices()), round_index)
		marker.visible = round_index == 0
		_target_markers.append(marker)
		_stage.add_child(marker)
		geometry_build_count += 1

func _build_shutter_button() -> void:
	_shutter_button = Button.new()
	_shutter_button.name = "ShadowShutterButton"
	_shutter_button.text = "定影　Space"
	_shutter_button.tooltip_text = "按下快門，依目前真實投影判定"
	_shutter_button.focus_mode = Control.FOCUS_ALL
	_shutter_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_shutter_button.anchor_left = 1.0
	_shutter_button.anchor_top = 1.0
	_shutter_button.anchor_right = 1.0
	_shutter_button.anchor_bottom = 1.0
	_shutter_button.offset_left = -220.0
	_shutter_button.offset_top = -86.0
	_shutter_button.offset_right = -48.0
	_shutter_button.offset_bottom = -38.0
	_shutter_button.add_theme_font_size_override("font_size", 21)
	_shutter_button.add_theme_color_override("font_color", Color("#fff2d1"))
	_shutter_button.add_theme_color_override("font_hover_color", Color("#fff9e8"))
	_shutter_button.add_theme_color_override("font_pressed_color", Color("#f5d89a"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#102b35")
	normal.border_color = Color("#c3944f")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	normal.shadow_color = Color(0.02, 0.04, 0.05, 0.0)
	normal.shadow_size = 0
	normal.shadow_offset = Vector2.ZERO
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#19443f")
	hover.border_color = Color("#62c3b0")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#263d46")
	pressed.border_color = Color("#62c3b0")
	_shutter_button.add_theme_stylebox_override("normal", normal)
	_shutter_button.add_theme_stylebox_override("hover", hover)
	_shutter_button.add_theme_stylebox_override("pressed", pressed)
	_shutter_button.add_theme_stylebox_override("focus", hover)
	# Measure the owning Control in the main viewport; its SubViewport can report
	# an identity/empty transform during headless setup before any physical scale exists.
	var physical_scale := Paper.physical_scale(self)
	if physical_scale < 0.1:
		physical_scale = 1.0
	var current_height := _shutter_button.offset_bottom - _shutter_button.offset_top
	var minimum_height := 44.0 / physical_scale
	if current_height < minimum_height:
		_shutter_button.offset_top = _shutter_button.offset_bottom - minimum_height
	_shutter_button.pressed.connect(func() -> void: shutter_requested.emit())
	add_child(_shutter_button)

func _build_wall_and_frame() -> void:
	_wall_material = _material(Color("#ead3a5"), 0.9)
	_wall_material.albedo_texture = _paper_fiber
	_wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_wall_material.disable_receive_shadows = false
	# Restrained world fill keeps the real cast warm and readable without full black.
	_wall_material.disable_ambient_light = false
	_add_box("PrintedPaperWall", Vector3(WALL_HALF_WIDTH * 2.0, WALL_HALF_HEIGHT * 2.0, 0.14), Vector3(0.0, 0.0, ModelScript.WALL_Z + 0.07), _wall_material)
	var wood := _material(Color("#916541"), 0.74)
	var trim := _material(Color("#d0a45e"), 0.56, true)
	wood.albedo_texture = _wood_grain
	wood.uv1_scale = Vector3(2.2, 1.5, 1.0)
	_add_box("TopTimberRail", Vector3(6.9, 0.17, 0.28), Vector3(0.0, WALL_HALF_HEIGHT + 0.09, 2.3), wood)
	_add_box("BottomTimberRail", Vector3(6.9, 0.19, 0.32), Vector3(0.0, -WALL_HALF_HEIGHT - 0.09, 2.3), wood)
	_add_box("LeftTimberPost", Vector3(0.17, 2.7, 0.28), Vector3(-WALL_HALF_WIDTH - 0.09, 0.0, 2.3), wood)
	_add_box("RightTimberPost", Vector3(0.17, 2.7, 0.28), Vector3(WALL_HALF_WIDTH + 0.09, 0.0, 2.3), wood)
	for index in 5:
		var nail := _add_sphere("FrameBrassPeg%d" % index, 0.052, Vector3(-2.55 + index * 1.275, 1.22, 2.1), trim)
		nail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inset := _material(Color("#d9b36c"), 0.38, true)
	for side in [-1.0, 1.0]:
		var inner_post := _add_box("InnerGiltBead%s" % str(side), Vector3(0.028, 2.43, 0.022), Vector3(side * 3.04, 0.0, 2.13), inset)
		inner_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top_bead := _add_box("UpperGiltBead", Vector3(6.05, 0.025, 0.022), Vector3(0.0, 1.16, 2.13), inset)
	top_bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bottom_bead := _add_box("LowerGiltBead", Vector3(6.05, 0.025, 0.022), Vector3(0.0, -1.16, 2.13), inset)
	bottom_bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_curtains()
	_build_nameplate()
	geometry_build_count += 12

func _build_curtains() -> void:
	var teal := _material(Color("#28646b"), 0.82)
	var lining := _material(Color("#83aaa0"), 0.76)
	teal.albedo_texture = _paper_fiber
	var left := PackedVector2Array([
		Vector2(-3.17, 1.12), Vector2(-2.82, 1.04), Vector2(-2.86, 0.75),
		Vector2(-2.99, 0.47), Vector2(-2.85, 0.13), Vector2(-2.99, -0.19),
		Vector2(-2.86, -0.57), Vector2(-3.02, -1.16), Vector2(-3.17, -1.16)
	])
	var right := PackedVector2Array()
	for point in left:
		right.append(Vector2(-point.x, point.y))
	_add_flat_prop("LeftSeaGlassWing", left, 2.10, teal)
	_add_flat_prop("RightSeaGlassWing", right, 2.10, teal)
	for side in [-1.0, 1.0]:
		for fold_index in 3:
			var x: float = side * (2.91 + float(fold_index) * 0.085)
			var fold := PackedVector2Array([
				Vector2(x, 0.96), Vector2(x + side * 0.025, 0.88),
				Vector2(x - side * 0.018, 0.42), Vector2(x + side * 0.022, -0.05),
				Vector2(x - side * 0.012, -0.58), Vector2(x + side * 0.018, -1.04)
			])
			_add_flat_prop("CurtainFold%d%s" % [fold_index, str(side)], fold, 2.088, lining, 0.006)
	var cord := _material(Color("#d1ab6b"), 0.46, true)
	for side in [-1.0, 1.0]:
		var tieback := _add_sphere("CurtainGiltTieback%s" % str(side), 0.065, Vector3(side * 2.91, 0.26, 2.02), cord)
		tieback.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_build_count += 10

func _build_nameplate() -> void:
	var enamel := _material(Color("#28545c"), 0.46, true)
	var brass := _material(Color("#c19556"), 0.38, true)
	_add_box("EnamelTheatreNameplate", Vector3(1.96, 0.15, 0.035), Vector3(0.0, -1.39, 2.09), enamel)
	for side in [-1.0, 1.0]:
		var stud := _add_sphere("NameplateCornerStud%s" % str(side), 0.025, Vector3(side * 0.90, -1.39, 2.055), brass)
		stud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var title := Label3D.new()
	title.name = "TheatreLettering"
	title.text = "TIDE THEATRE  /  SHADOW STUDY"
	title.font_size = 26
	title.pixel_size = 0.0032
	title.modulate = Color("#f0d8a8")
	title.outline_size = 4
	title.outline_modulate = Color("#29454d")
	title.position = Vector3(0.0, -1.395, 2.045)
	# Label3D's front is local +Z; align it with the fixed oblique orthographic camera.
	title.basis = _camera.global_basis
	title.no_depth_test = true
	_stage.add_child(title)
	geometry_build_count += 4

func _build_puppet() -> void:
	var paper := _material(Color("#f3e2bd"), 0.84)
	paper.albedo_texture = _paper_fiber
	_puppet = MeshInstance3D.new()
	_puppet.name = "FixedHandCutMascotProp"
	_puppet.mesh = _extruded_polygon(_geometry_model.puppet_vertices(), PUPPET_HALF_DEPTH)
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	_puppet.material_override = paper
	_puppet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	# The light is on negative Z: the paper's front silhouette face must sit on model Z=0.
	_puppet.position.z = PUPPET_HALF_DEPTH
	_puppet.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_stage.add_child(_puppet)
	_build_mascot_ink()
	geometry_build_count += 1

func _build_mascot_ink() -> void:
	var cap := _material(Color("#38767a"), 0.83)
	var face := _material(Color("#e1a06b"), 0.84)
	var cream := _material(Color("#f4dfbb"), 0.86)
	var vest := _material(Color("#36777a"), 0.72)
	var boot := _material(Color("#285259"), 0.76)
	var coral := _material(Color("#d86f58"), 0.72)
	var ink := _material(Color("#263e4b"), 0.62)
	var gold := _material(Color("#e1b969"), 0.5, true)
	_add_ink_patch("SailorCap", PackedVector2Array([
		Vector2(-0.22, 0.31), Vector2(-0.18, 0.43), Vector2(-0.09, 0.47),
		Vector2(0.0, 0.41), Vector2(0.10, 0.47), Vector2(0.18, 0.42),
		Vector2(0.23, 0.31), Vector2(0.16, 0.29), Vector2(-0.15, 0.29)
	]), cap, -0.051)
	_add_ink_patch("OtterWarmFace", _ellipse_points(Vector2(0.0, 0.19), Vector2(0.235, 0.19), 18), face, -0.052)
	_add_ink_patch("CreamMuzzle", _ellipse_points(Vector2(0.0, 0.105), Vector2(0.135, 0.072), 16), cream, -0.054)
	_add_ink_patch("TidecoatBib", PackedVector2Array([
		Vector2(-0.17, -0.06), Vector2(-0.12, -0.14), Vector2(-0.13, -0.31),
		Vector2(-0.07, -0.37), Vector2(0.0, -0.30), Vector2(0.07, -0.37),
		Vector2(0.14, -0.31), Vector2(0.12, -0.13), Vector2(0.18, -0.06),
		Vector2(0.0, -0.015)
	]), vest, -0.052)
	_add_ink_patch("LeftDeckBoot", PackedVector2Array([
		Vector2(-0.23, -0.47), Vector2(-0.075, -0.48), Vector2(-0.045, -0.43),
		Vector2(-0.105, -0.385), Vector2(-0.24, -0.395)
	]), boot, -0.053)
	_add_ink_patch("RightDeckBoot", PackedVector2Array([
		Vector2(0.23, -0.47), Vector2(0.075, -0.48), Vector2(0.045, -0.43),
		Vector2(0.105, -0.385), Vector2(0.24, -0.395)
	]), boot, -0.053)
	_add_ink_patch("LeftBootSeam", PackedVector2Array([
		Vector2(-0.205, -0.417), Vector2(-0.095, -0.414), Vector2(-0.092, -0.401), Vector2(-0.208, -0.404)
	]), cream, -0.055)
	_add_ink_patch("RightBootSeam", PackedVector2Array([
		Vector2(0.205, -0.417), Vector2(0.095, -0.414), Vector2(0.092, -0.401), Vector2(0.208, -0.404)
	]), cream, -0.055)
	_add_ink_patch("CoralNeckerchief", PackedVector2Array([
		Vector2(-0.18, 0.015), Vector2(0.0, -0.075), Vector2(0.19, 0.015),
		Vector2(0.09, -0.10), Vector2(0.12, -0.18), Vector2(0.0, -0.13),
		Vector2(-0.12, -0.18), Vector2(-0.09, -0.10)
	]), coral, -0.055)
	for side in [-1.0, 1.0]:
		var eye := _add_sphere("InkEye%s" % str(side), 0.029, Vector3(side * 0.087, 0.221, -0.057), ink, _puppet)
		eye.scale = Vector3(1.0, 1.08, 0.46)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cheek := _add_sphere("PapercutBlush%s" % str(side), 0.045, Vector3(side * 0.155, 0.13, -0.056), coral, _puppet)
		cheek.scale = Vector3(1.0, 0.72, 0.38)
		cheek.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nose := _add_ink_patch("AnchorNose", PackedVector2Array([
		Vector2(-0.045, 0.139), Vector2(0.045, 0.139), Vector2(0.0, 0.095)
	]), ink, -0.058)
	var badge := _add_ink_patch("BrassTideBadge", _ellipse_points(Vector2(0.0, -0.22), Vector2(0.052, 0.052), 10), gold, -0.056)
	for decorative in [nose, badge]:
		decorative.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_build_count += 11

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

func _add_ink_patch(label: String, points: PackedVector2Array, material: Material, depth: float) -> MeshInstance3D:
	var patch := MeshInstance3D.new()
	patch.name = label
	patch.mesh = _extruded_polygon(points, 0.001)
	patch.position.z = depth
	patch.material_override = material
	var standard := material as StandardMaterial3D
	if standard != null:
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_puppet.add_child(patch)
	return patch

func _add_flat_prop(label: String, points: PackedVector2Array, depth: float, material: Material, half_depth: float = 0.008) -> MeshInstance3D:
	var prop := MeshInstance3D.new()
	prop.name = label
	prop.mesh = _extruded_polygon(points, half_depth)
	prop.position.z = depth
	prop.material_override = material
	var standard := material as StandardMaterial3D
	if standard != null:
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
	prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_stage.add_child(prop)
	return prop

func _build_lamp() -> void:
	_lamp_rig = Node3D.new()
	_lamp_rig.name = "MovingBrassLamp"
	_stage.add_child(_lamp_rig)
	var brass := _material(Color("#bc8c4f"), 0.35, true)
	var dark_brass := _material(Color("#624c36"), 0.48, true)
	var pole := _add_cylinder("BrassStandColumn", 0.035, 1.10, Vector3(0.0, -0.63, 0.0), brass, _lamp_rig)
	pole.rotation_degrees.z = -18.0
	_add_cylinder("BrassWeightedFoot", 0.24, 0.09, Vector3(0.0, -1.22, 0.0), dark_brass, _lamp_rig)
	var shade := MeshInstance3D.new()
	shade.name = "ReflectorBell"
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.075
	shade_mesh.bottom_radius = 0.235
	shade_mesh.height = 0.16
	shade_mesh.radial_segments = 20
	shade.mesh = shade_mesh
	# Its closed decorative caps sit ahead of the source, not in the gameplay caster set.
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.material_override = brass
	shade.position = Vector3(0.0, ModelScript.LAMP_Y, 0.115)
	shade.rotation_degrees.x = 90.0
	_lamp_rig.add_child(shade)
	var rim := MeshInstance3D.new()
	rim.name = "ReflectorRolledBrassLip"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.205
	rim_mesh.outer_radius = 0.235
	rim_mesh.rings = 20
	rim_mesh.ring_segments = 12
	rim.mesh = rim_mesh
	rim.material_override = brass
	rim.position = Vector3(0.0, ModelScript.LAMP_Y, -0.005)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp_rig.add_child(rim)
	var bulb_material := _material(Color("#fff0ca"), 0.22)
	bulb_material.emission_enabled = true
	bulb_material.emission = Color("#ffc96b")
	bulb_material.emission_energy_multiplier = 1.6
	_bulb = _add_sphere("WarmGlassBulbAtPointSource", 0.103, Vector3(0.0, ModelScript.LAMP_Y, 0.0), bulb_material, _lamp_rig)
	_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spot = SpotLight3D.new()
	_spot.name = "SinglePointSourceShadowLight"
	_spot.light_color = PHASE_LAMP["noon"]
	_spot.light_energy = 1.6
	_spot.spot_range = 8.0
	_spot.spot_angle = 46.0
	_spot.spot_angle_attenuation = 0.25
	_spot.shadow_enabled = true
	_spot.light_size = 0.025
	_spot.shadow_bias = 0.012
	_spot.shadow_normal_bias = 0.12
	_spot.shadow_blur = 0.15
	_spot.position = Vector3(0.0, ModelScript.LAMP_Y, 0.0)
	_lamp_rig.add_child(_spot)
	_update_lamp(Vector2(-0.90, -2.24))
	geometry_build_count += 7

func _build_rail() -> void:
	var wood := _material(Color("#684e39"), 0.74)
	var teal := _material(Color("#3f817e"), 0.72)
	_add_box("MiniatureStageDeck", Vector3(7.2, 0.16, 5.8), Vector3(0.0, -1.47, -0.05), wood)
	_add_box("StageFrontSeaGlassInlay", Vector3(4.7, 0.045, 0.06), Vector3(0.0, -1.36, -2.68), teal)
	for side in [-1.0, 1.0]:
		_add_cylinder("DeckBrassPost%s" % str(side), 0.055, 0.22, Vector3(side * 3.35, -1.32, -1.9), _material(Color("#c39354"), 0.36, true))
	geometry_build_count += 4

func _build_marker(vertices: PackedVector2Array, index: int) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "FixedTargetPrintRound%d" % (index + 1)
	marker.mesh = _outline_ribbon(vertices, TARGET_OUTER_WIDTH, ModelScript.WALL_Z - 0.004)
	var ink := _material(Color("#28495a"), 0.7)
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.no_depth_test = true
	marker.material_override = ink
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var accent := MeshInstance3D.new()
	accent.name = "InnerRegistrationInk"
	accent.mesh = _outline_ribbon(vertices, TARGET_INNER_WIDTH, ModelScript.WALL_Z - 0.008)
	var accent_material := _material(Color("#bd735d") if index != 2 else Color("#d3a85f"), 0.7)
	accent_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	accent_material.no_depth_test = true
	accent.material_override = accent_material
	accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(accent)
	return marker

func _outline_ribbon(vertices: PackedVector2Array, width: float, depth: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in vertices.size():
		var first := vertices[index]
		var second := vertices[(index + 1) % vertices.size()]
		var direction := (second - first).normalized()
		var normal := Vector2(-direction.y, direction.x) * width * 0.5
		var a := Vector3(first.x + normal.x, first.y + normal.y, depth)
		var b := Vector3(first.x - normal.x, first.y - normal.y, depth)
		var c := Vector3(second.x - normal.x, second.y - normal.y, depth)
		var d := Vector3(second.x + normal.x, second.y + normal.y, depth)
		_add_triangle(surface, a, b, c)
		_add_triangle(surface, a, c, d)
	surface.commit(mesh)
	return mesh

func _extruded_polygon(vertices: PackedVector2Array, half_depth: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(vertices)
	for tri in range(0, triangles.size(), 3):
		var a := vertices[triangles[tri]]
		var b := vertices[triangles[tri + 1]]
		var c := vertices[triangles[tri + 2]]
		_add_triangle(surface, Vector3(a.x, a.y, -half_depth), Vector3(b.x, b.y, -half_depth), Vector3(c.x, c.y, -half_depth))
		_add_triangle(surface, Vector3(c.x, c.y, half_depth), Vector3(b.x, b.y, half_depth), Vector3(a.x, a.y, half_depth))
	for index in vertices.size():
		var first := vertices[index]
		var second := vertices[(index + 1) % vertices.size()]
		var front_a := Vector3(first.x, first.y, -half_depth)
		var front_b := Vector3(second.x, second.y, -half_depth)
		var back_a := Vector3(first.x, first.y, half_depth)
		var back_b := Vector3(second.x, second.y, half_depth)
		_add_triangle(surface, front_a, back_a, front_b)
		_add_triangle(surface, front_b, back_a, back_b)
	surface.generate_normals()
	surface.commit(mesh)
	return mesh

func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

func _update_lamp(position: Vector2) -> void:
	if _lamp_rig == null:
		return
	_lamp_rig.position = Vector3(position.x, 0.0, position.y)
	if _spot != null:
		_spot.basis = Basis.looking_at(Vector3(-position.x, -ModelScript.LAMP_Y, ModelScript.WALL_Z - position.y), Vector3.UP)

func _material(color: Color, roughness: float, metallic: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.55 if metallic else 0.0
	return material

func _make_grain_texture(midpoint: float, amplitude: float, seed_value: int) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for y in 64:
		var band := sin(float(y) * 0.42 + sin(float(y) * 0.11) * 0.9) * amplitude * 0.45
		for x in 64:
			var hairline := sin(float(x) * 0.33 + float(y) * 0.07) * amplitude * 0.16
			var value := clampf(midpoint + band + hairline + random.randf_range(-amplitude * 0.22, amplitude * 0.22), 0.78, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)

func _add_box(label: String, dimensions: Vector3, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent != null else _stage).add_child(instance)
	return instance

func _add_cylinder(label: String, radius: float, height: float, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.14
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent != null else _stage).add_child(instance)
	return instance

func _add_sphere(label: String, radius: float, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent != null else _stage).add_child(instance)
	return instance

func puppet_screen_bounds() -> Rect2:
	return _mesh_screen_bounds(_puppet)

func lamp_body_screen_bounds() -> Rect2:
	var result := Rect2()
	var first := true
	for child in _lamp_rig.get_children():
		if not child is MeshInstance3D: continue
		var bounds := _mesh_screen_bounds(child as MeshInstance3D)
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func _mesh_screen_bounds(mesh: MeshInstance3D) -> Rect2:
	if not is_instance_valid(mesh) or not is_instance_valid(_camera): return Rect2()
	var box := mesh.get_aabb()
	var points: Array[Vector2] = []
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				points.append(_camera.unproject_position(mesh.global_transform * Vector3(x, y, z)))
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points: result = result.expand(point)
	return result

func _set_only_puppet_shadow_caster(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if node == _puppet else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): _set_only_puppet_shadow_caster(child)
