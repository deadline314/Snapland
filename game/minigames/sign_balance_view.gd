extends Control
class_name SignBalanceView

signal balance_requested(value: float)

const FONT: FontFile = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const HUD_SAFE_RECT := Rect2(34.0, 18.0, 1212.0, 112.0)
const SCENE_BOUNDS := Rect2(0.0, 0.0, 1280.0, 720.0)
const PLAYFIELD_BOUNDS := Rect2(0.0, 130.0, 1280.0, 372.0)
const STAGE_CARD_BOUNDS := Rect2(202.0, 152.0, 180.0, 68.0)
const FORECAST_CARD_BOUNDS := Rect2(874.0, 148.0, 330.0, 72.0)
const CONTROLS_PANEL := Rect2(324.0, 502.0, 632.0, 204.0)
const BOARD_CENTER := Vector2(640.0, 326.0)
const BOARD_SIZE := Vector2(560.0, 184.0)
const AXLE_CENTER := BOARD_CENTER
const ANGLE_GAUGE := Rect2(412.0, 546.0, 456.0, 28.0)
const WEIGHT_RAIL := Rect2(430.0, 621.0, 420.0, 28.0)
const STATUS_LINE_BOUNDS := Rect2(356.0, 658.0, 564.0, 18.0)
const INPUT_HELP_BOUNDS := Rect2(356.0, 682.0, 564.0, 18.0)
const SAFE_DWELL_SECONDS := 0.52
const CAMERA_ORTHO_SIZE := 12.4
const COUNTERWEIGHT_TRAVEL := 2.45
const PALETTE_DAWN: Array[Color] = [Color("#c9d4d8"), Color("#8caeb7"), Color("#263f50"), Color("#f1c88f"), Color("#b96f59"), Color("#344e5a"), Color("#f1e2c8")]
const PALETTE_NOON: Array[Color] = [Color("#dce7dc"), Color("#9fc2bb"), Color("#183b49"), Color("#f5dfa1"), Color("#bd7449"), Color("#31575e"), Color("#f1f0dc")]
const PALETTE_DUSK: Array[Color] = [Color("#cfb7a1"), Color("#819aa3"), Color("#243a4b"), Color("#ebc277"), Color("#c3754e"), Color("#493f4c"), Color("#f0dec0")]
const PALETTE_NIGHT: Array[Color] = [Color("#354855"), Color("#5f8990"), Color("#172d3a"), Color("#e0c275"), Color("#d07d63"), Color("#233f4b"), Color("#dce3d4")]

var _snapshot: Dictionary = {}
var _time_of_day := "noon"
var _reduced_motion := false
var _dragging := false
var _stage_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _environment: Environment
var _sun: DirectionalLight3D
var _assembly: Node3D
var _sign_face: MeshInstance3D
var _counterweight: Node3D
var _counterweight_chain: Node3D
var _wind_pennant: Node3D
var _dock_platform: MeshInstance3D
var _water: MeshInstance3D
var _materials: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	_create_spatial_stage()
	_apply_snapshot_to_scene()

func _create_spatial_stage() -> void:
	_stage_container = SubViewportContainer.new()
	_stage_container.name = "SpatialStage"
	_stage_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_container.focus_mode = Control.FOCUS_NONE
	# Stay at the session's canvas Z: a negative relative Z also puts the
	# texture behind Session._draw()'s opaque background. Draw behind only
	# this view's paper overlays; the later HUD sibling stays above both.
	_stage_container.z_index = 0
	_stage_container.z_as_relative = true
	_stage_container.show_behind_parent = true
	_stage_container.stretch = true
	add_child(_stage_container)

	_viewport = SubViewport.new()
	_viewport.name = "HarborViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	_stage_container.add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "SignApparatus"
	_viewport.add_child(_world_root)
	_create_lighting()
	_create_harbor_platform()
	_create_sign_mechanism()
	_create_wind_instrument()

func _create_lighting() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = PALETTE_NOON[0]
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#e6e3cf")
	_environment.ambient_light_energy = 0.72
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.name = "HarborEnvironment"
	world_environment.environment = _environment
	_world_root.add_child(world_environment)

	_camera = Camera3D.new()
	_camera.name = "StageCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.near = 0.1
	_camera.far = 90.0
	_camera.position = Vector3(3.0, 6.1, 19.0)
	_camera.current = true
	_world_root.add_child(_camera)
	_camera.look_at(Vector3(0.0, 2.25, 0.0), Vector3.UP)

	_sun = DirectionalLight3D.new()
	_sun.name = "HarborSun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 24.0
	_sun.shadow_bias = 0.035
	_sun.rotation_degrees = Vector3(-47.0, -31.0, 0.0)
	_world_root.add_child(_sun)

func _create_harbor_platform() -> void:
	_materials["water"] = _material(PALETTE_NOON[1], 0.34, 0.08)
	_materials["dock"] = _material(Color("#765b43"), 0.88, 0.0)
	_materials["plank_light"] = _material(Color("#917153"), 0.82, 0.0)
	_materials["plank_dark"] = _material(Color("#624a39"), 0.9, 0.0)
	_materials["brass"] = _material(Color("#d3a65f"), 0.28, 0.72)
	_materials["iron"] = _material(Color("#3f5155"), 0.38, 0.62)
	_materials["wood"] = _material(Color("#6f513c"), 0.72, 0.0)
	_materials["face"] = _material(Color("#ead8b5"), 0.88, 0.0)
	_materials["face_edge"] = _material(Color("#503e34"), 0.64, 0.08)
	_materials["weight"] = _material(Color("#b2794e"), 0.31, 0.64)
	_materials["flag"] = _material(Color("#c66f54"), 0.88, 0.0)
	_materials["rope"] = _material(Color("#c2a77a"), 0.96, 0.0)

	_water = _mesh_instance("HarborWater", PlaneMesh.new(), _world_root, _materials["water"])
	(_water.mesh as PlaneMesh).size = Vector2(58.0, 48.0)
	_water.position = Vector3(0.0, -0.44, -15.0)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_dock_platform = _box("DockPlatform", Vector3(17.0, 0.34, 8.0), Vector3(0.0, -0.02, 0.55), _world_root, _materials["dock"])
	# Broad, individually modeled deck boards give the machine a real working surface.
	for index in range(13):
		var x := -7.2 + float(index) * 1.2
		var plank_material: StandardMaterial3D = _materials["plank_light"] if index % 3 == 0 else _materials["dock"]
		_box("DeckBoard%02d" % index, Vector3(1.12, 0.08, 7.45), Vector3(x, 0.19, 0.65), _world_root, plank_material)
	_box("DockFrontFascia", Vector3(16.8, 0.40, 0.20), Vector3(0.0, -0.02, 4.56), _world_root, _materials["plank_dark"])
	_box("DockRearBeam", Vector3(16.8, 0.34, 0.28), Vector3(0.0, -0.04, -3.43), _world_root, _materials["wood"])
	for x in [-7.5, -4.5, 4.5, 7.5]:
		_cylinder("DockBolt", 0.07, 0.035, Vector3(x, 0.245, 3.95), _world_root, _materials["brass"], Vector3(PI * 0.5, 0.0, 0.0))
	# Mooring bollards are two structural anchors, not background props.
	for x in [-7.0, 7.0]:
		_cylinder("MooringBollard", 0.18, 0.62, Vector3(x, 0.48, 2.85), _world_root, _materials["iron"])
		_cylinder("BollardCap", 0.23, 0.10, Vector3(x, 0.82, 2.85), _world_root, _materials["brass"])

func _create_sign_mechanism() -> void:
	# The support frame stays fixed; only this axle-mounted assembly follows sign angle.
	var pivot_height := 2.82
	_box("SupportPostLeft", Vector3(0.34, pivot_height, 0.36), Vector3(-0.58, pivot_height * 0.5 + 0.20, -0.60), _world_root, _materials["wood"])
	_box("SupportPostRight", Vector3(0.34, pivot_height, 0.36), Vector3(0.58, pivot_height * 0.5 + 0.20, -0.60), _world_root, _materials["wood"])
	_beam("SupportBraceLeft", Vector3(-2.15, 0.34, -0.64), Vector3(-0.56, 2.70, -0.64), 0.22, _world_root, _materials["brass"])
	_beam("SupportBraceRight", Vector3(2.15, 0.34, -0.64), Vector3(0.56, 2.70, -0.64), 0.22, _world_root, _materials["brass"])
	_box("SupportFoot", Vector3(5.4, 0.18, 0.8), Vector3(0.0, 0.36, -0.50), _world_root, _materials["iron"])
	_cylinder("Axle", 0.17, 1.65, Vector3(0.0, pivot_height, 0.02), _world_root, _materials["brass"], Vector3(PI * 0.5, 0.0, 0.0))
	for z in [-0.89, 0.93]:
		_cylinder("AxleCap", 0.30, 0.16, Vector3(0.0, pivot_height, z), _world_root, _materials["iron"], Vector3(PI * 0.5, 0.0, 0.0))
		_cylinder("AxleHub", 0.19, 0.18, Vector3(0.0, pivot_height, z + (0.10 if z > 0.0 else -0.10)), _world_root, _materials["brass"], Vector3(PI * 0.5, 0.0, 0.0))

	_assembly = Node3D.new()
	_assembly.name = "SignAssembly"
	_assembly.position = Vector3(0.0, pivot_height, 0.42)
	_world_root.add_child(_assembly)

	_sign_face = _box("SignFace", Vector3(7.55, 2.12, 0.34), Vector3(0.0, 0.72, 0.0), _assembly, _materials["face_edge"])
	_box("SignInlay", Vector3(7.23, 1.82, 0.055), Vector3(0.0, 0.72, 0.205), _assembly, _materials["face"])
	_box("SignTopRail", Vector3(7.62, 0.12, 0.43), Vector3(0.0, 1.81, 0.0), _assembly, _materials["brass"])
	_box("SignBottomRail", Vector3(7.62, 0.12, 0.43), Vector3(0.0, -0.37, 0.0), _assembly, _materials["brass"])
	for side in [-1.0, 1.0]:
		_box("SignSideRail", Vector3(0.13, 2.18, 0.42), Vector3(side * 3.78, 0.72, 0.0), _assembly, _materials["brass"])
	for x in [-3.53, 3.53]:
		for y in [-0.10, 1.54]:
			_cylinder("SignFaceRivet", 0.055, 0.035, Vector3(x, y, 0.25), _assembly, _materials["iron"], Vector3(PI * 0.5, 0.0, 0.0))
	var title := Label3D.new()
	title.name = "SignTitle"
	title.text = "潮汐花園"
	title.font = FONT
	title.font_size = 96
	title.pixel_size = 0.006
	title.modulate = Color("#263b41")
	title.outline_size = 6
	title.outline_modulate = Color("#ead8b5")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector3(0.0, 0.81, 0.246)
	_assembly.add_child(title)

	_box("CounterweightRail", Vector3(5.45, 0.19, 0.40), Vector3(0.0, -0.53, -0.08), _assembly, _materials["iron"])
	_box("RailTopInlay", Vector3(5.22, 0.05, 0.46), Vector3(0.0, -0.405, -0.08), _assembly, _materials["brass"])
	for x in [-2.62, 2.62]:
		_cylinder("RailEndStop", 0.16, 0.16, Vector3(x, -0.53, -0.08), _assembly, _materials["brass"], Vector3(PI * 0.5, 0.0, 0.0))

	_counterweight = Node3D.new()
	_counterweight.name = "Counterweight"
	_assembly.add_child(_counterweight)
	_box("WeightForging", Vector3(0.78, 0.68, 0.82), Vector3(0.0, -1.20, -0.08), _counterweight, _materials["weight"])
	_box("WeightFace", Vector3(0.57, 0.42, 0.055), Vector3(0.0, -1.20, 0.36), _counterweight, _materials["brass"])
	_box("WeightHandle", Vector3(0.16, 0.12, 0.12), Vector3(0.0, -0.80, -0.08), _counterweight, _materials["iron"])
	_counterweight_chain = Node3D.new()
	_counterweight_chain.name = "WeightChain"
	_assembly.add_child(_counterweight_chain)
	for index in range(4):
		var link := _box("ChainLink%02d" % index, Vector3(0.085, 0.14, 0.075), Vector3(0.0, -0.53 - float(index) * 0.105, -0.08), _counterweight_chain, _materials["rope"])
		link.rotation.z = 0.38 if index % 2 == 0 else -0.38

func _create_wind_instrument() -> void:
	var mast_x := -5.30
	_beam("PennantMast", Vector3(mast_x, 0.35, -0.35), Vector3(mast_x, 2.92, -0.35), 0.09, _world_root, _materials["iron"])
	_wind_pennant = Node3D.new()
	_wind_pennant.name = "WindPennant"
	_wind_pennant.position = Vector3(mast_x + 0.04, 2.57, -0.35)
	_world_root.add_child(_wind_pennant)
	_box("PennantCloth", Vector3(1.18, 0.52, 0.045), Vector3(0.55, 0.0, 0.0), _wind_pennant, _materials["flag"])
	_box("PennantHem", Vector3(1.12, 0.065, 0.06), Vector3(0.56, -0.23, 0.0), _wind_pennant, _materials["brass"])
	_cylinder("PennantMastCollar", 0.12, 0.10, Vector3(mast_x, 2.76, -0.35), _world_root, _materials["brass"])

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	return result

func _mesh_instance(node_name: String, mesh: Mesh, parent: Node3D, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

func _box(node_name: String, dimensions: Vector3, at: Vector3, parent: Node3D, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := _mesh_instance(node_name, mesh, parent, material)
	instance.position = at
	return instance

func _cylinder(node_name: String, radius: float, height: float, at: Vector3, parent: Node3D, material: StandardMaterial3D, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var instance := _mesh_instance(node_name, mesh, parent, material)
	instance.position = at
	instance.rotation = rotation
	return instance

func _beam(node_name: String, start: Vector3, finish: Vector3, thickness: float, parent: Node3D, material: StandardMaterial3D) -> MeshInstance3D:
	var delta := finish - start
	var instance := _box(node_name, Vector3(thickness, delta.length(), thickness), (start + finish) * 0.5, parent, material)
	instance.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return instance

func update_frame(snapshot: Dictionary, time_of_day: String = "noon", reduced_motion: bool = false) -> void:
	_snapshot = snapshot
	_time_of_day = time_of_day if time_of_day in ["dawn", "noon", "dusk", "night"] else "noon"
	_reduced_motion = reduced_motion
	_apply_snapshot_to_scene()
	queue_redraw()

func _apply_snapshot_to_scene() -> void:
	if not is_instance_valid(_assembly):
		return
	_assembly.rotation.z = visual_angle(_snapshot)
	var target_balance := weight_rail_x(_snapshot)
	_counterweight.position.x = target_balance
	_counterweight_chain.position.x = target_balance
	var torque := float(_snapshot.get("forecast_torque", 0.0)) if bool(_snapshot.get("forecast_visible", false)) else float(_snapshot.get("wind_torque", 0.0))
	var direction := -1.0 if int(_snapshot.get("wind_direction", 1)) < 0 else 1.0
	_wind_pennant.rotation.z = direction * lerpf(0.07, 0.24, clampf(absf(torque) / 0.28, 0.0, 1.0))
	if _time_of_day == "dawn":
		_environment.background_color = PALETTE_DAWN[0]
		_environment.ambient_light_color = Color("#d9c8aa")
		_sun.light_color = Color("#ffd9aa")
		_sun.rotation_degrees = Vector3(-33.0, -66.0, 0.0)
	elif _time_of_day == "dusk":
		_environment.background_color = PALETTE_DUSK[0]
		_environment.ambient_light_color = Color("#d6b69b")
		_sun.light_color = Color("#f5b47b")
		_sun.rotation_degrees = Vector3(-22.0, 112.0, 0.0)
	elif _time_of_day == "night":
		_environment.background_color = PALETTE_NIGHT[0]
		_environment.ambient_light_color = Color("#8097a7")
		_sun.light_color = Color("#9cb7d0")
		_sun.light_energy = 0.42
		_sun.rotation_degrees = Vector3(-58.0, -132.0, 0.0)
	else:
		_environment.background_color = PALETTE_NOON[0]
		_environment.ambient_light_color = Color("#e6e3cf")
		_sun.light_color = Color("#fff1d5")
		_sun.light_energy = 0.86
		_sun.rotation_degrees = Vector3(-47.0, -31.0, 0.0)
	if _time_of_day != "night":
		_sun.light_energy = 1.0
	(_materials["water"] as StandardMaterial3D).albedo_color = PALETTE_NOON[1] if _time_of_day == "noon" else (PALETTE_DAWN[1] if _time_of_day == "dawn" else (PALETTE_DUSK[1] if _time_of_day == "dusk" else PALETTE_NIGHT[1]))

func visual_angle(snapshot: Dictionary = {}) -> float:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return clampf(float(state.get("angle", 0.0)) * 0.43, -0.58, 0.58)

func shadow_offset(snapshot: Dictionary = {}) -> Vector2:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return Vector2(float(state.get("angle", 0.0)) * 72.0, 0.0)

func safe_angle_bounds(snapshot: Dictionary = {}) -> Vector2:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	var target := float(state.get("target_angle", 0.0))
	var limit := float(state.get("safe_limit", 0.13))
	return Vector2(target - limit, target + limit)

func weight_rail_x(snapshot: Dictionary = {}) -> float:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return clampf(float(state.get("balance", 0.0)), -1.0, 1.0) * COUNTERWEIGHT_TRAVEL

func weight_chain_attached_to_mass() -> bool:
	return is_instance_valid(_counterweight) and is_instance_valid(_counterweight_chain) and is_equal_approx(_counterweight.position.x, _counterweight_chain.position.x)

func projected_axle_position() -> Vector2:
	if not is_instance_valid(_camera): return Vector2.ZERO
	return _camera.unproject_position(Vector3(0.0, 2.82, 0.42))

func projected_sign_bounds(snapshot: Dictionary = {}) -> Rect2:
	if not is_instance_valid(_camera) or not is_instance_valid(_sign_face): return Rect2()
	if not snapshot.is_empty(): _assembly.rotation.z = visual_angle(snapshot)
	_assembly.force_update_transform()
	var aabb := _sign_face.get_aabb()
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for x in [aabb.position.x, aabb.end.x]:
		for y in [aabb.position.y, aabb.end.y]:
			for z in [aabb.position.z, aabb.end.z]:
				var screen_point := _camera.unproject_position(_sign_face.global_transform * Vector3(x, y, z))
				min_point = min_point.min(screen_point)
				max_point = max_point.max(screen_point)
	min_point -= Vector2(4.0, 4.0)
	max_point += Vector2(4.0, 4.0)
	return Rect2(min_point, max_point - min_point)

func spatial_node_count() -> int:
	if not is_instance_valid(_world_root): return 0
	var count := 0
	var pending: Array[Node] = [_world_root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		count += 1
		for child in current.get_children(): pending.append(child)
	return count

func decorative_node_count() -> int:
	return spatial_node_count()

func palette_phase() -> String:
	return _time_of_day

func sky_color() -> Color:
	if _time_of_day == "dawn": return PALETTE_DAWN[0]
	if _time_of_day == "dusk": return PALETTE_DUSK[0]
	if _time_of_day == "night": return PALETTE_NIGHT[0]
	return PALETTE_NOON[0]

func physical_motion_enabled() -> bool:
	return true

func decorative_motion_enabled() -> bool:
	return not _reduced_motion

func scene_bounds() -> Rect2:
	return SCENE_BOUNDS

func playfield_bounds() -> Rect2:
	return PLAYFIELD_BOUNDS

func pivot_position() -> Vector2:
	return projected_axle_position()

func hud_safe_rect() -> Rect2:
	return HUD_SAFE_RECT

func target_zone_bounds() -> Rect2:
	return ANGLE_GAUGE

func controls_panel_bounds() -> Rect2:
	return CONTROLS_PANEL

func stage_card_bounds() -> Rect2:
	return STAGE_CARD_BOUNDS

func wind_arrow_visible(snapshot: Dictionary = {}) -> bool:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	var torque := float(state.get("forecast_torque", 0.0)) if bool(state.get("forecast_visible", false)) else float(state.get("wind_torque", 0.0))
	return absf(torque) >= 0.035

func wind_display_label(snapshot: Dictionary = {}) -> String:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	if bool(state.get("forecast_visible", false)): return "預告風"
	return "當前風" if wind_arrow_visible(state) else "靜風"

func wind_glyph(snapshot: Dictionary = {}) -> String:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return "←" if int(state.get("wind_direction", 1)) < 0 else "→"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and WEIGHT_RAIL.has_point(event.position):
			_dragging = true
			grab_focus()
			balance_requested.emit(_balance_from_x(event.position.x))
			accept_event()
		elif not event.pressed and _dragging:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		balance_requested.emit(_balance_from_x(event.position.x))
		accept_event()

func _balance_from_x(x: float) -> float:
	return clampf(inverse_lerp(WEIGHT_RAIL.position.x + 17.0, WEIGHT_RAIL.end.x - 17.0, x) * 2.0 - 1.0, -1.0, 1.0)

func _draw() -> void:
	var palette := PALETTE_NOON
	if _time_of_day == "dawn": palette = PALETTE_DAWN
	elif _time_of_day == "dusk": palette = PALETTE_DUSK
	elif _time_of_day == "night": palette = PALETTE_NIGHT
	var ink: Color = palette[2]
	var brass: Color = palette[3]
	var terracotta: Color = palette[4]
	var paper: Color = palette[6]
	_draw_controls_panel(paper, brass, ink)
	_draw_balance_gauges(ink, brass, terracotta, paper)
	_draw_forecast(ink, brass, terracotta, paper)
	_draw_round_marks(ink, brass, paper)

func _draw_forecast(ink: Color, brass: Color, terracotta: Color, paper: Color) -> void:
	var visible := bool(_snapshot.get("forecast_visible", false)) and not bool(_snapshot.get("ended", false))
	var marker_x := 1004.0
	draw_round_rect(FORECAST_CARD_BOUNDS, 9.0, paper.darkened(0.04))
	draw_rect(Rect2(FORECAST_CARD_BOUNDS.position, Vector2(5.0, FORECAST_CARD_BOUNDS.size.y)), brass)
	var label := str(_snapshot.get("wind_kind", "港風"))
	_label(Vector2(892.0, 171.0), label, ink, HORIZONTAL_ALIGNMENT_LEFT, 96, 15)
	var torque := float(_snapshot.get("forecast_torque", 0.0)) if visible else float(_snapshot.get("wind_torque", 0.0))
	var arrow_visible := absf(torque) >= 0.035
	var arrow_dir := -1 if torque < 0.0 else 1
	var arrow_color := terracotta if torque < 0.0 else brass
	_label(Vector2(892.0, 199.0), "預告風" if visible else ("當前風" if arrow_visible else "靜風"), ink.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, 86, 12)
	if arrow_visible:
		var arrow_length := lerpf(24.0, 48.0, clampf(absf(torque) / 0.28, 0.0, 1.0))
		var arrow_from := Vector2(marker_x + (arrow_length if arrow_dir < 0 else 0.0), 185.0)
		var arrow_to := Vector2(marker_x + (0.0 if arrow_dir < 0 else arrow_length), 185.0)
		draw_line(arrow_from, arrow_to, arrow_color, 5.0)
		draw_line(arrow_to, arrow_to + Vector2(-9.0 * arrow_dir, -7.0), arrow_color, 3.0)
		draw_line(arrow_to, arrow_to + Vector2(-9.0 * arrow_dir, 7.0), arrow_color, 3.0)
	var flag_x := 1102.0
	draw_line(Vector2(flag_x, 162.0), Vector2(flag_x, 207.0), ink, 2.0)
	if not arrow_visible:
		draw_line(Vector2(flag_x, 173.0), Vector2(flag_x + 16.0, 173.0), ink.darkened(0.1), 3.0)
	elif str(_snapshot.get("wind_kind", "")) == "穿堂陣風":
		draw_line(Vector2(flag_x, 164.0), Vector2(flag_x + 44.0 * arrow_dir, 174.0), arrow_color, 5.0)
		draw_line(Vector2(flag_x + 44.0 * arrow_dir, 174.0), Vector2(flag_x, 186.0), arrow_color, 5.0)
		draw_line(Vector2(flag_x, 186.0), Vector2(flag_x, 164.0), arrow_color, 3.0)
	else:
		draw_line(Vector2(flag_x, 164.0), Vector2(flag_x + 38.0 * arrow_dir, 179.0), arrow_color, 6.0)
		draw_line(Vector2(flag_x + 38.0 * arrow_dir, 179.0), Vector2(flag_x + 64.0 * arrow_dir, 166.0), arrow_color, 4.0)
	var seconds := float(_snapshot.get("forecast_seconds", 0.0))
	_label(Vector2(1140.0, 196.0), "%.1f 秒" % seconds if visible else ("×%.2f" % absf(torque) if arrow_visible else "平靜"), ink, HORIZONTAL_ALIGNMENT_LEFT, 60, 12)

func _draw_balance_gauges(ink: Color, brass: Color, terracotta: Color, paper: Color) -> void:
	var target := float(_snapshot.get("target_angle", 0.0))
	var angle_value := float(_snapshot.get("angle", 0.0))
	var safe_limit := float(_snapshot.get("safe_limit", 0.13))
	var precise_limit := float(_snapshot.get("precise_limit", 0.055))
	var scale_left := ANGLE_GAUGE.position.x
	var scale_width := ANGLE_GAUGE.size.x
	var units_per_radian := scale_width / 1.64
	_label(Vector2(352.0, 532.0), "支點角度", ink, HORIZONTAL_ALIGNMENT_LEFT, 120, 14)
	_label(Vector2(822.0, 532.0), "安全帶 ±%.2f" % safe_limit, ink, HORIZONTAL_ALIGNMENT_RIGHT, 130, 13)
	draw_rect(Rect2(ANGLE_GAUGE.position, ANGLE_GAUGE.size), paper.darkened(0.05))
	var center_x := scale_left + scale_width * 0.5 + target * units_per_radian
	var precise_w := precise_limit * units_per_radian
	var safe_w := safe_limit * units_per_radian
	draw_rect(Rect2(center_x - safe_w, ANGLE_GAUGE.position.y + 4.0, safe_w * 2.0, 20.0), Color("#78a89e"))
	draw_rect(Rect2(center_x - precise_w, ANGLE_GAUGE.position.y + 4.0, precise_w * 2.0, 20.0), brass.lightened(0.12))
	draw_line(Vector2(center_x, ANGLE_GAUGE.position.y - 4.0), Vector2(center_x, ANGLE_GAUGE.end.y + 4.0), ink, 2.0)
	var pointer_x := scale_left + scale_width * 0.5 + angle_value * units_per_radian
	var pointer_color := terracotta if absf(angle_value - target) > safe_limit else ink
	draw_circle(Vector2(pointer_x, ANGLE_GAUGE.get_center().y), 9.0, pointer_color)
	_label(Vector2(356.0, 590.0), "撞線 %d / 3" % int(_snapshot.get("impacts", 0)), ink, HORIZONTAL_ALIGNMENT_LEFT, 150, 15)
	_label(Vector2(565.0, 590.0), "穩住 %d / 7" % int(_snapshot.get("safe_stages", 0)), ink, HORIZONTAL_ALIGNMENT_CENTER, 150, 15)
	_label(Vector2(774.0, 590.0), "精準 %d / 7" % int(_snapshot.get("precise_stages", 0)), ink, HORIZONTAL_ALIGNMENT_RIGHT, 150, 15)
	var rail_y := WEIGHT_RAIL.position.y + WEIGHT_RAIL.size.y * 0.5
	_label(Vector2(356.0, 617.0), "移動配重", ink, HORIZONTAL_ALIGNMENT_LEFT, 130, 14)
	_label(Vector2(794.0, 617.0), "左 ←　→ 右", ink.darkened(0.10), HORIZONTAL_ALIGNMENT_RIGHT, 150, 13)
	draw_rect(Rect2(WEIGHT_RAIL.position.x, rail_y - 4.0, WEIGHT_RAIL.size.x, 8.0), ink.darkened(0.14))
	for notch in range(9):
		var x := WEIGHT_RAIL.position.x + float(notch) * WEIGHT_RAIL.size.x / 8.0
		draw_line(Vector2(x, rail_y - 11.0), Vector2(x, rail_y - 6.0), brass, 2.0)
	var weight_x := lerpf(WEIGHT_RAIL.position.x + 17.0, WEIGHT_RAIL.end.x - 17.0, (float(_snapshot.get("balance", 0.0)) + 1.0) * 0.5)
	draw_circle(Vector2(weight_x, rail_y), 16.0, brass.darkened(0.10))
	draw_circle(Vector2(weight_x, rail_y), 10.0, Color("#f3dd9f"))
	_label(Vector2(356.0, 672.0), str(_snapshot.get("last_event", "先看風旗預告，再微調配重")), ink, HORIZONTAL_ALIGNMENT_CENTER, 564, 13)
	_label(Vector2(356.0, 696.0), "按住方向鍵移動配重　·　拖曳滑軌微調", ink.darkened(0.08), HORIZONTAL_ALIGNMENT_CENTER, 564, 13)

func _draw_controls_panel(paper: Color, brass: Color, ink: Color) -> void:
	draw_round_rect(CONTROLS_PANEL, 13.0, paper)
	draw_rect(CONTROLS_PANEL, Color(ink, 0.72), false, 2.0)
	draw_rect(Rect2(CONTROLS_PANEL.position, Vector2(7.0, CONTROLS_PANEL.size.y)), brass)

func _draw_round_marks(ink: Color, brass: Color, paper: Color) -> void:
	var score_value := int(_snapshot.get("score", 0))
	var score_card := Rect2(58.0, 152.0, 128.0, 68.0)
	draw_round_rect(score_card, 8.0, paper.darkened(0.03))
	_label(Vector2(72.0, 177.0), "平衡章", ink, HORIZONTAL_ALIGNMENT_LEFT, 98, 13)
	_label(Vector2(72.0, 204.0), "%03d" % score_value, brass.darkened(0.32), HORIZONTAL_ALIGNMENT_LEFT, 92, 22)
	draw_round_rect(STAGE_CARD_BOUNDS, 9.0, paper.darkened(0.03))
	draw_rect(STAGE_CARD_BOUNDS, Color(ink, 0.72), false, 2.0)
	draw_rect(Rect2(STAGE_CARD_BOUNDS.position, Vector2(5.0, STAGE_CARD_BOUNDS.size.y)), brass)
	var stage := int(_snapshot.get("stage", 0))
	var stable_ratio := clampf(float(_snapshot.get("stable_seconds", 0.0)) / SAFE_DWELL_SECONDS, 0.0, 1.0)
	_label(Vector2(208.0, 171.0), "風段 %d · %s" % [mini(stage + 1, 7), str(_snapshot.get("wind_kind", "海風"))], ink, HORIZONTAL_ALIGNMENT_CENTER, 166, 14)
	draw_rect(Rect2(218.0, 181.0, 148.0, 5.0), paper.darkened(0.1))
	draw_rect(Rect2(218.0, 181.0, 148.0 * stable_ratio, 5.0), brass)
	var forecast_visible := bool(_snapshot.get("forecast_visible", false))
	var forecast_seconds := float(_snapshot.get("forecast_seconds", 0.0))
	var message := str(_snapshot.get("last_event", ""))
	if forecast_visible:
		message = "%.1f 秒後受風 · 先移配重" % forecast_seconds
	elif message.is_empty():
		message = "穩住中央亮帶，抵住來風"
	_label(Vector2(207.0, 207.0), message, ink, HORIZONTAL_ALIGNMENT_CENTER, 170, 11)

func draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2.0), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)

func _label(position: Vector2, text: String, color: Color, alignment: HorizontalAlignment, width: int, size: int) -> void:
	draw_string(FONT, position, text, alignment, width, size, color)
