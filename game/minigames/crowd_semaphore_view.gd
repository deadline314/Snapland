extends Control
class_name CrowdSemaphoreView

## Raised harbor signal miniature. It renders a presented CrowdTrafficModel
## snapshot; all timing, arrivals, and outcomes remain owned by the model.
signal signal_requested(lane: int)

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const HUD_SAFE_RECT := Rect2(80.0, 160.0, 1120.0, 455.0)
const PLAYFIELD_RECT := Rect2(80.0, 160.0, 1120.0, 455.0)
const HORIZONTAL_SIGNAL := Vector2(520.0, 235.0)
const VERTICAL_SIGNAL := Vector2(760.0, 235.0)
const SIGNAL_HIT_RADIUS := 64.0
const LANES := 2
const GROUP_POOL_SIZE := 6
const PHASES := ["dawn", "noon", "dusk", "night"]
const PHASE_AMBIENT := {
	"dawn": Color("#ad9a84"), "noon": Color("#9eafa9"),
	"dusk": Color("#837b80"), "night": Color("#506b79")
}
const PHASE_SKY := {
	"dawn": Color("#edc19c"), "noon": Color("#a8c9c2"),
	"dusk": Color("#c47f75"), "night": Color("#263f57")
}
const PHASE_KEY_LIGHT := {"dawn": 1.1, "noon": 1.25, "dusk": 0.92, "night": 0.68}
const PERSON_COLORS: Array[Color] = [Color("#e8ae72"), Color("#b9d8cc"), Color("#e38e77"), Color("#92b4cf"), Color("#d7c18c"), Color("#b6a0c9")]
const LANE_WEST := -3.5
const LANE_EAST := 3.5
const LANE_SOUTH := 3.35
const LANE_NORTH := -3.35
const CARD_TOP := 160.0
const CARD_SIZE := Vector2(220.0, 84.0)
const CROSSING_CARD_X := 170.0
const FORECAST_CARD_X := 890.0
const CARD_BG := Color("#102b35")
const CARD_BORDER := Color("#c3944f")
const RISK_BORDER := Color("#ef6f7a")
const ADVICE_BORDER := Color("#7fe3c4")
const TEXT_LIGHT := Color("#fff0d2")
const TEXT_GOLD := Color("#f0c878")
const TEXT_RISK := Color("#ff9a8f")

var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _stage: Node3D
var _camera: Camera3D
var _environment: Environment
var _key_light: DirectionalLight3D
var _phase_lights: Array[OmniLight3D] = []
var _lane_gates: Array[Array] = [[], []]
var _signal_lamps: Array[MeshInstance3D] = []
var _guest_roots: Array[Node3D] = []
var _guest_people: Array[Array] = []
var _patience_bars: Array[MeshInstance3D] = []
var _cross_marks: Array[MeshInstance3D] = []
var _lane_status_labels: Array[Label] = []
var _queue_labels: Array[Label] = []
var _lane_title_labels: Array[Label] = []
var _queue_strips: Array[ColorRect] = []
var _card_styles: Array[StyleBoxFlat] = []
var _crossing_label: Label
var _forecast_labels: Array[Label] = []
var _assisted := false
var _clearance_pennants: Array[MeshInstance3D] = []
var _material_cache: Dictionary = {}
var _phase := "noon"
var _reduced_motion := false
var _walk_lane := -1
var _clearance_lane := -1
var _pool_size_at_build := 0
var _rescue_flag: MeshInstance3D
var _rescue_stretcher: MeshInstance3D
var geometry_build_count := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_scene()
	_build_signal_surface()
	set_process(false)

func texture() -> ViewportTexture:
	return _viewport.get_texture() if _viewport != null else null

func sub_viewport() -> SubViewport:
	return _viewport

func is_3d_stage_ready() -> bool:
	return _viewport != null and _camera != null and _stage != null and _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS

## Present scalar state and bounded queue references. The snapshot is consumed
## immediately; only primitive visual fields are retained, never model timers.
func present_traffic(snapshot: Dictionary, elapsed: float, reduced_motion: bool, time_phase: String) -> void:
	_reduced_motion = reduced_motion
	_assisted = bool(snapshot.get("assisted", false))
	_phase = time_phase if PHASES.has(time_phase) else "noon"
	var valid := _is_valid_snapshot(snapshot)
	_walk_lane = -1
	_clearance_lane = -1
	if valid:
		var phase_name := str(snapshot.get("phase", "red"))
		var lane := int(snapshot.get("signal_lane", -1))
		if lane < 0 or lane >= LANES:
			lane = int(snapshot.get("desired_lane", -1))
		if phase_name == "walk" and lane >= 0 and lane < LANES:
			_walk_lane = lane
		elif phase_name == "clearance" and lane >= 0 and lane < LANES:
			_clearance_lane = lane
		_apply_group_state(snapshot, elapsed)
	else:
		_hide_all_groups()
	_update_gates_and_lamps(snapshot if valid else {}, phase_name_for(valid, snapshot))
	_update_signal_surface(snapshot if valid else {})
	_update_lighting()

func phase_name_for(valid: bool, snapshot: Dictionary) -> String:
	return str(snapshot.get("phase", "red")) if valid else "red"

func signal_lane_at(point: Vector2) -> int:
	if point.distance_squared_to(HORIZONTAL_SIGNAL) <= SIGNAL_HIT_RADIUS * SIGNAL_HIT_RADIUS:
		return 0
	if point.distance_squared_to(VERTICAL_SIGNAL) <= SIGNAL_HIT_RADIUS * SIGNAL_HIT_RADIUS:
		return 1
	return -1

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mouse.pressed:
		var requested_lane := signal_lane_at(mouse.position)
		if requested_lane >= 0:
			signal_requested.emit(requested_lane)

func signal_control_centres() -> Array[Vector2]:
	return [HORIZONTAL_SIGNAL, VERTICAL_SIGNAL]

func playfield_rect() -> Rect2:
	return PLAYFIELD_RECT

func hud_safe_rect() -> Rect2:
	return HUD_SAFE_RECT

func guest_pool_size() -> int:
	return _guest_roots.size()

func visible_group_count() -> int:
	var count := 0
	for guest in _guest_roots:
		if guest.visible:
			count += 1
	return count

func group_position(group_id: int) -> Vector3:
	return _guest_roots[group_id].position if group_id >= 0 and group_id < _guest_roots.size() else Vector3.ZERO

func waiting_position(group_id: int, queue_index: int) -> Vector3:
	return _queue_position(group_id, queue_index)

func gate_open_for_lane(lane: int) -> bool:
	return lane == _walk_lane

func gate_clearance_for_lane(lane: int) -> bool:
	return lane == _clearance_lane

func signal_lens_is_lit(lane: int, lens_index: int) -> bool:
	if lane < 0 or lane >= LANES or lens_index < 0 or lens_index >= 3:
		return false
	var material := _signal_lamps[lane * 3 + lens_index].material_override as StandardMaterial3D
	return material != null and material.emission_enabled

func rescue_marker_visible() -> bool:
	return _rescue_flag != null and _rescue_flag.visible and _rescue_stretcher.visible

func phase_light_energy(phase_name: String) -> float:
	if phase_name not in PHASES:
		return 0.0
	return float(PHASE_KEY_LIGHT[phase_name])

## Bounding rectangle measured from transformed 3D stage mesh corners projected
## by the actual camera. Screen coordinates are translated into the playfield.
func projected_content_bounds() -> Rect2:
	if _camera == null or not _camera.is_inside_tree():
		return Rect2()
	var first := true
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for mesh in _stage_meshes():
		if not mesh.visible or mesh.mesh == null:
			continue
		var aabb := mesh.mesh.get_aabb()
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var world := mesh.global_transform * Vector3(x, y, z)
					if _camera.is_position_behind(world):
						continue
					var local_point := _camera.unproject_position(world)
					var point := _viewport_container.position + local_point
					if first:
						min_point = point
						max_point = point
						first = false
					else:
						min_point = min_point.min(point)
						max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point) if not first else Rect2()

func _build_scene() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "HarborStageFrame"
	_viewport_container.position = Vector2(80.0, 245.0)
	_viewport_container.size = Vector2(1120.0, 369.0)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "HarborStageViewport"
	_viewport.size = Vector2i(1120, 369)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)
	var world := World3D.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = PHASE_AMBIENT["noon"]
	_environment.ambient_light_energy = phase_light_energy("noon")
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = _environment
	_viewport.world_3d = world
	_stage = Node3D.new()
	_stage.name = "SemaphoreHarbor"
	_viewport.add_child(_stage)
	_camera = Camera3D.new()
	_camera.name = "HarborCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 4.8
	_camera.position = Vector3(0.0, 8.0, 16.0)
	_camera.rotation_degrees = Vector3(-27.0, 0.0, 0.0)
	_camera.current = true
	_stage.add_child(_camera)
	_build_lighting()
	_build_harbor()
	_build_gate_system()
	_build_group_pool()
	geometry_build_count = _descendant_count(_stage)
	_pool_size_at_build = _guest_roots.size()

func _build_lighting() -> void:
	_key_light = DirectionalLight3D.new()
	_key_light.name = "HarborKeyLight"
	_key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	_key_light.shadow_enabled = true
	_key_light.light_energy = phase_light_energy("noon")
	_stage.add_child(_key_light)
	for corner in [Vector3(-4.2, 0.45, -3.8), Vector3(4.2, 0.45, -3.8), Vector3(-4.2, 0.45, 3.8), Vector3(4.2, 0.45, 3.8)]:
		var lamp := OmniLight3D.new()
		lamp.position = corner
		lamp.omni_range = 3.2
		lamp.light_energy = 0.15
		lamp.light_color = Color("#f4be77")
		lamp.shadow_enabled = false
		_stage.add_child(lamp)
		_phase_lights.append(lamp)

func _build_harbor() -> void:
	_add_box("Tidewater", Vector3(0.0, -0.58, 0.0), Vector3(11.3, 0.12, 8.7), "#527e86", 0.07)
	_add_box("RaisedTimberTable", Vector3(0.0, -0.28, 0.0), Vector3(10.2, 0.38, 7.65), "#76533e", 0.12)
	_add_box("QuayTop", Vector3(0.0, -0.04, 0.0), Vector3(9.82, 0.14, 7.27), "#c2a77c", 0.05)
	# Eight repeated plank seams are restrained; the four corner quay pads make
	# a legible navigable harbor miniature instead of a floating blank rectangle.
	for index in 9:
		var x := -4.45 + float(index) * 1.11
		_add_box("PlankSeam%d" % index, Vector3(x, 0.041, 0.0), Vector3(0.018, 0.006, 6.98), "#70533f", 0.01)
	for x in [-3.55, 3.55]:
		for z in [-2.55, 2.55]:
			_add_box("QuayStone", Vector3(x, 0.13, z), Vector3(2.1, 0.20, 1.75), "#b7b6a2", 0.12)
			_add_box("QuayInset", Vector3(x, 0.245, z), Vector3(1.94, 0.055, 1.59), "#d4c5a4", 0.08)
	# Two marked roads intersect with distinct stone curb lips and raised zebra bars.
	_add_box("HorizontalAsphalt", Vector3(0.0, 0.045, 0.0), Vector3(9.2, 0.045, 1.72), "#596267", 0.04)
	_add_box("VerticalAsphalt", Vector3(0.0, 0.049, 0.0), Vector3(1.72, 0.045, 6.65), "#596267", 0.04)
	for offset in [-1.12, -0.78, -0.44, -0.10, 0.24, 0.58, 0.92, 1.26]:
		_add_box("ZebraNorthSouth", Vector3(0.0, 0.087, offset), Vector3(1.04, 0.04, 0.16), "#f0e5c9", 0.025)
		_add_box("ZebraEastWest", Vector3(offset, 0.087, 0.0), Vector3(0.16, 0.04, 1.04), "#f0e5c9", 0.025)
	for x in [-4.22, 4.22]:
		for z in [-3.0, 3.0]:
			_add_cylinder("BrassMooring", Vector3(x, 0.34, z), 0.16, 0.39, "#bd8853", 16)
			_add_torus("MooringRing", Vector3(x, 0.53, z), 0.16, 0.045, "#dfbd7f")
	for index in 6:
		var x := -3.5 + float(index) * 1.4
		_add_box("DockFaceBoard", Vector3(x, -0.18, 3.78), Vector3(1.2, 0.13, 0.07), "#4e392f", 0.025)
	# Tiny fixed route studs are static visual guidance, not model timing markers.
	for lane in LANES:
		for step_index in 5:
			var t := float(step_index + 1) / 6.0
			var point := _crossing_point(lane, t)
			var mark := _add_sphere("RouteStud", point + Vector3(0.0, 0.16, 0.0), 0.07, "#d8b767", 12, 6)
			_cross_marks.append(mark)

func _build_gate_system() -> void:
	# Gate arms are paired at both mouths; horizontal arms pivot about Z and the
	# perpendicular pair about X. Status reads from the model's phase/lane fields.
	for mouth in [-1, 1]:
		var h_root := Node3D.new()
		h_root.name = "HorizontalGatePivot"
		h_root.position = Vector3(float(mouth) * 1.72, 0.16, 0.0)
		_stage.add_child(h_root)
		_add_box("HorizontalGateArm", Vector3(float(mouth) * -0.55, 0.18, 0.0), Vector3(1.1, 0.12, 0.13), "#e8d6b5", 0.035, h_root)
		_add_box("GateCoralBand", Vector3(float(mouth) * -0.49, 0.18, 0.0), Vector3(0.22, 0.125, 0.137), "#cf7664", 0.02, h_root)
		_add_cylinder("GateHinge", Vector3.ZERO, 0.19, 0.34, "#a8784e", 14, h_root)
		_lane_gates[0].append(h_root)
		var v_root := Node3D.new()
		v_root.name = "VerticalGatePivot"
		v_root.position = Vector3(0.0, 0.16, float(mouth) * 1.55)
		_stage.add_child(v_root)
		_add_box("VerticalGateArm", Vector3(0.0, 0.18, float(mouth) * -0.52), Vector3(0.13, 0.12, 1.04), "#e8d6b5", 0.035, v_root)
		_add_box("GateTealBand", Vector3(0.0, 0.18, float(mouth) * -0.47), Vector3(0.137, 0.125, 0.22), "#5b9d91", 0.02, v_root)
		_add_cylinder("GateHinge", Vector3.ZERO, 0.19, 0.34, "#a8784e", 14, v_root)
		_lane_gates[1].append(v_root)
	# Raised semaphore housings are pair-coded by geometry and material.
	for lane in LANES:
		var center := Vector3(-1.38 if lane == 0 else 1.38, 0.78, -1.12 if lane == 0 else 1.12)
		_add_cylinder("SignalMast", center + Vector3(0.0, -0.26, 0.0), 0.075, 0.83, "#705644", 12)
		_add_box("SignalHousing", center, Vector3(0.5, 0.66, 0.28), "#3d4542", 0.10)
		for lamp_index in 3:
			var lamp := _add_sphere("SignalLens", center + Vector3(0.0, 0.20 - float(lamp_index) * 0.19, 0.17), 0.095, "#544943", 14, 8)
			lamp.material_override = (_material("#544943").duplicate() as StandardMaterial3D)
			_signal_lamps.append(lamp)
		_add_box("SignalNameplate", center + Vector3(0.0, -0.49, 0.02), Vector3(0.56, 0.07, 0.33), "#bd9867", 0.02)
		_add_cylinder("SignalCap", center + Vector3(0.0, 0.39, 0.0), 0.31, 0.08, "#c69c65", 16)
	# Mounted clearance pennant indicates flashing amber state with a static pose.
	for lane in LANES:
		var pennant := _add_box("ClearancePennant", Vector3(-1.38 if lane == 0 else 1.38, 1.33, -1.12 if lane == 0 else 1.12), Vector3(0.26, 0.28, 0.05), "#e3a65f", 0.02)
		pennant.visible = false
		_clearance_pennants.append(pennant)

func _build_group_pool() -> void:
	for group_id in GROUP_POOL_SIZE:
		var group_root := Node3D.new()
		group_root.name = "GuestGroup%d" % group_id
		_stage.add_child(group_root)
		_guest_roots.append(group_root)
		var bodies: Array[MeshInstance3D] = []
		var people_count: int = [2, 3, 2, 4, 2, 3][group_id]
		for person_index in people_count:
			var person := Node3D.new()
			person.name = "Traveler%d" % person_index
			person.position = Vector3((float(person_index) - float(people_count - 1) * 0.5) * 0.18, 0.0, (person_index % 2) * 0.13)
			group_root.add_child(person)
			var tunic := _add_capsule("WoolCoat", Vector3(0.0, 0.29, 0.0), 0.085, 0.29, PERSON_COLORS[group_id], 8, 4, person)
			_add_sphere("Head", Vector3(0.0, 0.51, 0.0), 0.073, "#dca884", 10, 6, person)
			_add_capsule("Boots", Vector3(0.0, 0.08, 0.0), 0.063, 0.11, "#4c4540", 8, 4, person)
			bodies.append(tunic)
		_guest_people.append(bodies)
		var patience := _add_box("PatienceMeter", Vector3(0.0, 0.76, 0.0), Vector3(0.72, 0.055, 0.07), "#78ae9b", 0.02, group_root)
		_patience_bars.append(patience)
		group_root.visible = false
	# Rescue group has a physical stretcher and a high-contrast signal flag.
	var rescue := _guest_roots[3]
	_rescue_stretcher = _add_box("RescueStretcher", Vector3(0.0, 0.17, 0.35), Vector3(0.52, 0.09, 0.22), "#dfb883", 0.04, rescue)
	_add_box("StretcherRail", Vector3(0.0, 0.24, 0.35), Vector3(0.60, 0.045, 0.27), "#fff0d0", 0.02, rescue)
	_rescue_flag = _add_box("RescuePennant", Vector3(0.28, 0.78, 0.25), Vector3(0.12, 0.32, 0.04), "#d16c5d", 0.015, rescue)
	_add_box("RescueFlagCross", Vector3(0.28, 0.80, 0.225), Vector3(0.07, 0.16, 0.012), "#f8e3c6", 0.005, rescue)
	_pool_size_at_build = _guest_roots.size()

func signal_card_rect(lane: int) -> Rect2:
	if lane < 0 or lane >= LANES:
		return Rect2()
	var panel := get_node_or_null("SignalControl%d" % lane) as Control
	return Rect2(panel.position, panel.size) if panel != null else Rect2()

func signal_card_status(lane: int) -> String:
	return _lane_status_labels[lane].text if lane >= 0 and lane < _lane_status_labels.size() else ""

func _build_signal_surface() -> void:
	for lane in LANES:
		var center := HORIZONTAL_SIGNAL if lane == 0 else VERTICAL_SIGNAL
		var layout := _make_card("SignalControl%d" % lane, Vector2(center.x - CARD_SIZE.x * 0.5, CARD_TOP))
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(header)
		var title := _card_label(header, "LaneTitle%d" % lane, 19, TEXT_LIGHT, 52.0)
		title.text = "橫向" if lane == 0 else "縱向"
		_lane_title_labels.append(title)
		var queue := _card_label(header, "QueueCount%d" % lane, 16, TEXT_GOLD, 138.0)
		queue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_queue_labels.append(queue)
		_lane_status_labels.append(_card_label(layout, "LaneLabel%d" % lane, 16, TEXT_LIGHT, 194.0))
		var strip := ColorRect.new()
		strip.name = "QueuePatience%d" % lane
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.custom_minimum_size = Vector2(194.0, 6.0)
		strip.color = Color("#79a891")
		layout.add_child(strip)
		_queue_strips.append(strip)
	var crossing := _make_card("CrossingStateCard", Vector2(CROSSING_CARD_X, CARD_TOP))
	_card_label(crossing, "CrossingTitle", 19, TEXT_LIGHT, 194.0).text = "路口"
	_crossing_label = _card_label(crossing, "CrossingState", 16, TEXT_GOLD, 194.0)
	var forecast := _make_card("ArrivalForecastCard", Vector2(FORECAST_CARD_X, CARD_TOP))
	_card_label(forecast, "ForecastTitle", 19, TEXT_LIGHT, 194.0).text = "到站預告"
	for row in 2:
		_forecast_labels.append(_card_label(forecast, "ForecastRow%d" % row, 15, TEXT_GOLD, 194.0))

## One planning card: dark panel with a brass border that turns coral for risk.
func _make_card(card_name: String, position: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = card_name
	panel.position = position
	panel.size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 5.0
	panel.add_theme_stylebox_override("panel", style)
	_card_styles.append(style)
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 1)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(layout)
	return layout

func _card_label(parent: Control, label_name: String, font_size: int, color: Color, width: float) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(width, 0.0)
	label.clip_text = true
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func lane_card_border(lane: int) -> Color:
	return _card_styles[lane].border_color if lane >= 0 and lane < LANES else Color.TRANSPARENT

func crossing_text() -> String:
	return _crossing_label.text if _crossing_label != null else ""

func forecast_texts() -> Array[String]:
	var texts: Array[String] = []
	for label in _forecast_labels:
		texts.append(label.text)
	return texts

func _apply_group_state(snapshot: Dictionary, elapsed: float) -> void:
	var queues: Array = snapshot.get("queues", [])
	for group_id in GROUP_POOL_SIZE:
		var found: Dictionary = {}
		var queue_index := -1
		var lane := -1
		for candidate_lane in LANES:
			if queues.size() <= candidate_lane or not queues[candidate_lane] is Array:
				continue
			for index in queues[candidate_lane].size():
				var entry: Variant = queues[candidate_lane][index]
				if entry is Dictionary and int(entry.get("id", -1)) == group_id:
					found = entry
					queue_index = index
					lane = candidate_lane
					break
			if not found.is_empty():
				break
		var active: Dictionary = snapshot.get("active", {})
		var is_active := not active.is_empty() and int(active.get("id", -1)) == group_id and str(snapshot.get("phase", "")) == "walk"
		if is_active:
			found = active
			lane = int(active.get("lane", -1))
			queue_index = -1
		var visible := not found.is_empty() and lane >= 0 and lane < LANES and not bool(snapshot.get("finished", false))
		_guest_roots[group_id].visible = visible
		if not visible:
			continue
		if is_active:
			var progress := clampf(float(snapshot.get("active_progress", 0.0)), 0.0, 1.0)
			if _reduced_motion:
				progress = roundf(progress * 5.0) / 5.0
			_guest_roots[group_id].position = _crossing_point(lane, progress)
			_guest_roots[group_id].rotation.y = 0.0 if lane == 0 else PI * 0.5
		else:
			var target := _queue_position(lane, queue_index)
			_guest_roots[group_id].position = target
			_guest_roots[group_id].rotation.y = 0.0 if lane == 0 else PI * 0.5
		var people := clampi(int(found.get("people", _guest_people[group_id].size())), 1, _guest_people[group_id].size())
		for index in _guest_people[group_id].size():
			_guest_people[group_id][index].visible = index < people
		var remaining := clampf(float(found.get("patience_remaining", 0.0)), 0.0, maxf(0.1, float(found.get("patience", 1.0))))
		_patience_bars[group_id].visible = not is_active
		_patience_bars[group_id].scale.x = maxf(0.03, remaining / maxf(0.1, float(found.get("patience", 1.0))))
		var bar_material := _patience_bars[group_id].material_override as StandardMaterial3D
		if bar_material != null:
			bar_material.albedo_color = Color("#cf7a64") if remaining < 1.5 else Color("#75aa92")
		if group_id == 3:
			_rescue_flag.visible = bool(found.get("rescue", false))
			_rescue_stretcher.visible = _rescue_flag.visible

func _hide_all_groups() -> void:
	for group in _guest_roots:
		group.visible = false
	_rescue_flag.visible = false
	_rescue_stretcher.visible = false

func _update_gates_and_lamps(snapshot: Dictionary, phase_name: String) -> void:
	var phase_value := phase_name
	var lane := int(snapshot.get("signal_lane", -1))
	if lane < 0 or lane >= LANES:
		lane = int(snapshot.get("desired_lane", -1))
	_walk_lane = lane if phase_value == "walk" and lane >= 0 and lane < LANES else -1
	_clearance_lane = lane if phase_value == "clearance" and lane >= 0 and lane < LANES else -1
	for gate_lane in LANES:
		var open := gate_lane == _walk_lane
		var clearance := gate_lane == _clearance_lane
		for gate in _lane_gates[gate_lane]:
			var sign := 1.0 if gate_lane == 0 else -1.0
			var target_angle := sign * deg_to_rad(78.0) if open else (sign * deg_to_rad(12.0) if clearance and not _reduced_motion else 0.0)
			gate.rotation.z = target_angle if gate_lane == 0 else 0.0
			gate.rotation.x = target_angle if gate_lane == 1 else 0.0
		for lamp_index in 3:
			var material := _signal_lamps[gate_lane * 3 + lamp_index].material_override as StandardMaterial3D
			var enabled := (phase_value == "walk" and open and lamp_index == 2) or (phase_value == "clearance" and clearance and lamp_index == 1) or (lamp_index == 0 and (phase_value in ["red", "all_red", "finished"] or (phase_value == "walk" and not open) or (phase_value == "clearance" and not clearance)))
			if material != null:
				material.albedo_color = _lamp_color(lamp_index, enabled)
				material.emission_enabled = enabled
				material.emission = material.albedo_color if enabled else Color.BLACK
		_clearance_pennants[gate_lane].visible = clearance

func _update_signal_surface(snapshot: Dictionary) -> void:
	var queues: Array = snapshot.get("queues", [])
	var risks: Array = snapshot.get("lane_risk", [])
	var phase_value := str(snapshot.get("phase", "red"))
	var recommended := int(snapshot.get("recommended_lane", -1))
	for lane in LANES:
		var queue: Array = queues[lane] if queues.size() > lane and queues[lane] is Array else []
		var risk: Dictionary = risks[lane] if risks.size() > lane and risks[lane] is Dictionary else {}
		var least_ratio := 1.0
		for entry_variant in queue:
			if entry_variant is Dictionary:
				least_ratio = minf(least_ratio, clampf(float(entry_variant.get("patience_remaining", 0.0)) / maxf(0.1, float(entry_variant.get("patience", 1.0))), 0.0, 1.0))
		var must_go := bool(risk.get("must_go_next", false))
		var advised := _assisted and lane == recommended and not queue.is_empty()
		_queue_labels[lane].text = "空" if queue.is_empty() else "%d 隊 %d 人%s" % [queue.size(), int(risk.get("people", 0)), "・救援" if bool(risk.get("rescue", false)) else ""]
		_queue_strips[lane].color = Color("#d17662") if not queue.is_empty() and (least_ratio < 0.28 or must_go) else Color("#78a890")
		var lamp := "黃燈" if phase_value == "clearance" else ("綠燈" if lane == _walk_lane else "紅燈")
		var detail := "暢通" if queue.is_empty() else "最急 %.1f 秒" % float(risk.get("patience_remaining", 0.0))
		if must_go: detail = "先放這側！剩 %.1f 秒" % float(risk.get("patience_remaining", 0.0))
		elif bool(risk.get("lost", false)): detail = "來不及了"
		elif advised: detail = "建議先放 %.1f 秒" % float(risk.get("patience_remaining", 0.0))
		_lane_status_labels[lane].text = "%s・%s" % [lamp, detail]
		_lane_status_labels[lane].add_theme_color_override("font_color", TEXT_RISK if must_go else TEXT_LIGHT)
		_lane_title_labels[lane].text = "橫向" if lane == 0 else "縱向"
		_card_styles[lane].border_color = RISK_BORDER if must_go else (ADVICE_BORDER if advised else CARD_BORDER)
	if _crossing_label != null:
		var free_in := float(snapshot.get("time_to_free", 0.0))
		match phase_value:
			"walk": _crossing_label.text = "%s通行中・%.1f 秒後可換" % ["橫向" if _walk_lane == 0 else "縱向", free_in]
			"clearance", "all_red": _crossing_label.text = "清場中・%.1f 秒後放行" % free_in
			"finished": _crossing_label.text = "六隊已處理完"
			_: _crossing_label.text = "空出・可立即放行"
	var upcoming: Array = snapshot.get("upcoming", [])
	for row in _forecast_labels.size():
		if row < upcoming.size() and upcoming[row] is Dictionary:
			var next: Dictionary = upcoming[row]
			_forecast_labels[row].text = "%.1f 秒後 %s %d 人%s" % [float(next.get("eta", 0.0)), "橫向" if int(next.get("lane", 0)) == 0 else "縱向", int(next.get("people", 0)), "・救援" if bool(next.get("rescue", false)) else ""]
		else:
			_forecast_labels[row].text = "—" if row > 0 or not upcoming.is_empty() else "已無新隊伍"

func _update_lighting() -> void:
	if _environment != null:
		_environment.ambient_light_color = PHASE_AMBIENT[_phase]
		_environment.ambient_light_energy = phase_light_energy(_phase)
	if _key_light != null:
		_key_light.light_color = PHASE_SKY[_phase]
		_key_light.light_energy = phase_light_energy(_phase)
	for index in _phase_lights.size():
		_phase_lights[index].light_energy = 0.54 if _phase == "night" else 0.13
		_phase_lights[index].light_color = Color("#ffd493") if _phase in ["dusk", "night"] else Color("#f5e0bb")
	if _stage != null and _reduced_motion:
		# Static lens/gate states continue to describe model phase; no extra flapping.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _is_valid_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot.has("phase") or not snapshot.has("queues") or not snapshot.has("active"):
		return false
	if str(snapshot.get("phase", "")) not in ["red", "walk", "clearance", "all_red", "finished"]:
		return false
	var queues: Variant = snapshot.get("queues")
	if not queues is Array or queues.size() != LANES:
		return false
	for queue_variant in queues:
		if not queue_variant is Array:
			return false
	var active: Variant = snapshot.get("active")
	if not active is Dictionary:
		return false
	return true

func _queue_position(lane: int, queue_index: int) -> Vector3:
	if lane == 0:
		return Vector3(LANE_WEST - float(maxi(0, queue_index)) * 0.43, 0.10, -0.48 + float(maxi(0, queue_index % 2)) * 0.92)
	return Vector3(-0.45 + float(maxi(0, queue_index % 2)) * 0.9, 0.10, LANE_SOUTH + float(maxi(0, queue_index)) * 0.43)

func _crossing_point(lane: int, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	if lane == 0:
		return Vector3(lerpf(LANE_WEST, LANE_EAST, t), 0.10, -0.48)
	return Vector3(-0.45, 0.10, lerpf(LANE_SOUTH, LANE_NORTH, t))

func _lamp_color(index: int, enabled: bool) -> Color:
	var base: Array[Color] = [Color("#d46f62"), Color("#e3a75f"), Color("#65aa8b")]
	return base[index] if enabled else base[index].darkened(0.68)

func _stage_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_meshes(_stage, result)
	return result

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		_collect_meshes(child, out)

func _descendant_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _descendant_count(child)
	return count

func _add_box(name: String, position: Vector3, size: Vector3, color: String, bevel: float = 0.0, parent: Node = null) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.material_override = _material(color, bevel)
	(parent if parent != null else _stage).add_child(mesh_node)
	return mesh_node

func _add_sphere(name: String, position: Vector3, radius: float, color: String, radial: int = 12, rings: int = 8, parent: Node = null) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.material_override = _material(color)
	(parent if parent != null else _stage).add_child(mesh_node)
	return mesh_node

func _add_cylinder(name: String, position: Vector3, radius: float, height: float, color: String, segments: int = 16, parent: Node = null) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.material_override = _material(color)
	(parent if parent != null else _stage).add_child(mesh_node)
	return mesh_node

func _add_torus(name: String, position: Vector3, radius: float, thickness: float, color: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.01, radius - thickness)
	mesh.outer_radius = radius
	mesh_node.mesh = mesh
	mesh_node.position = position
	mesh_node.rotation.x = PI * 0.5
	mesh_node.material_override = _material(color, 0.25)
	_stage.add_child(mesh_node)
	return mesh_node

func _add_capsule(name: String, position: Vector3, radius: float, height: float, color: Color, radial: int, rings: int, parent: Node) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = rings
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color.to_html(false))
	parent.add_child(node)
	return node

func _material(hex: String, roughness: float = 0.82) -> StandardMaterial3D:
	var cache_key := "%s|%.2f" % [hex, roughness]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = roughness
	material.metallic = 0.12 if hex in ["#bd8853", "#dfbd7f", "#a8784e", "#c69c65"] else 0.0
	_material_cache[cache_key] = material
	return material
