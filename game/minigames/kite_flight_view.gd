extends Control
class_name KiteFlightView

## A 2.5D side profile: the kite crosses a readable ring plane above a layered cliff.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const FIELD_RECT := Rect2(80.0, 155.0, 1110.0, 470.0)
const HUD_RECT := Rect2(34.0, 18.0, 1212.0, 112.0)
const KITE_SCREEN_X := 360.0
const WORLD_X_SCALE := 0.32
const HEIGHT_TOP := 200.0
const HEIGHT_BOTTOM := 535.0
const HEIGHT_WORLD_MIN := 110.0
const HEIGHT_WORLD_MAX := 650.0
const RING_WORLD_X := [520.0, 1040.0, 1560.0, 2080.0, 2600.0]
const RING_WORLD_HEIGHT := [390.0, 285.0, 430.0, 315.0, 405.0]
const EMPTY_MARKERS: Array = []
const RING_HALF_HEIGHT := 45.0
const RING_HALF_DEPTH := 18.0
const CENTER_ZONE_HALF_HEIGHT := 15.0
const GEOMETRY_REVISION := 3
const CLOUD_X: Array[float] = [90.0, 455.0, 935.0]
const CLOUD_Y: Array[float] = [260.0, 218.0, 300.0]
const ROOF_ACCENTS: Array[float] = [158.0, 176.0, 319.0, 484.0, 653.0, 822.0, 1000.0, 1174.0]
const FONT: Font = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")

const INK := Color("#263f50")
const SEA_GLASS := Color("#4b8985")
const CORAL := Color("#c86d60")
const OCHRE := Color("#a97848")
const PAPER := Color("#ead9b7")
const CREAM := Color("#f7efd9")
const DEEP := Color("#1e3b4a")
const TIDAL := Color("#7db7ac")

var _snapshot: Dictionary = {}
var _phase := "playing"
var _time_phase := "noon"
var _reduced_motion := false
var _elapsed := 0.0
var _camera_x := 120.0
var _kite_height := 380.0
var _kite_velocity := 0.0
var _actual_wind := 0.0
var _forecast_wind := 0.0
var _forecast_seconds := 1.25
var _tension := 0.22
var _tension_warning := false
var _tension_risk := 0.0
var _rescues_used := 0
var _next_ring := 0
var _event_markers: Array = []
var _event := ""
var _geometry_revision := -1
var _far_harbor := PackedVector2Array()
var _far_cliff := PackedVector2Array()
var _near_cliff := PackedVector2Array()
var _cliff_facets: Array[PackedVector2Array] = []
var _cliff_strata: Array[PackedVector2Array] = []
var _sea_wave_paths: Array[PackedVector2Array] = []
var _clouds: Array[PackedVector2Array] = []
var _lighthouse_body := PackedVector2Array()
var _lighthouse_roof := PackedVector2Array()
var _lighthouse_lantern := PackedVector2Array()
var _distant_boat := PackedVector2Array()
var _distant_sail := PackedVector2Array()
var _kite_body := PackedVector2Array()
var _kite_panel_left := PackedVector2Array()
var _kite_panel_right := PackedVector2Array()
var _kite_panel_top := PackedVector2Array()
var _kite_shadow := PackedVector2Array()
var _tail_flags: Array[PackedVector2Array] = []
var _tether_points := PackedVector2Array()
var _bridle_line := PackedVector2Array()
var _spool_disc := PackedVector2Array()
var _spool_ring := PackedVector2Array()
var _kite_bounds := Rect2()
var _warning_triangle := PackedVector2Array()
var _kite_center := Vector2(KITE_SCREEN_X, 380.0)
var _kite_roll := 0.0
var _shadow_center := Vector2(420.0, 595.0)
var _light_center := Vector2(1060.0, 206.0)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_geometry()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_geometry_revision = -1
		_ensure_geometry()

func update_frame(snapshot: Dictionary, phase: String, reduced_motion: bool, time_phase: String = "noon") -> void:
	_ensure_geometry()
	_snapshot = snapshot
	_phase = phase
	_reduced_motion = reduced_motion
	_time_phase = _normalized_time_phase(time_phase)
	_elapsed = float(snapshot.get("elapsed", 0.0))
	_camera_x = float(snapshot.get("x", 120.0))
	_kite_height = clampf(float(snapshot.get("height", 380.0)), HEIGHT_WORLD_MIN, HEIGHT_WORLD_MAX)
	_kite_velocity = float(snapshot.get("vy", 0.0))
	_actual_wind = float(snapshot.get("actualwind", 0.0))
	_forecast_wind = float(snapshot.get("forecast", 0.0))
	_forecast_seconds = float(snapshot.get("forecast_seconds", 1.25))
	_tension = clampf(float(snapshot.get("tension", 0.22)), 0.0, 1.0)
	_tension_warning = bool(snapshot.get("tension_warning", false))
	_tension_risk = clampf(float(snapshot.get("tension_risk", 0.0)), 0.0, 1.0)
	_rescues_used = clampi(int(snapshot.get("rescues_used", 0)), 0, 2)
	_next_ring = clampi(int(snapshot.get("nextRing", 0)), 0, 5)
	_event_markers = snapshot.get("eventmarkers", EMPTY_MARKERS)
	_event = str(snapshot.get("event", ""))
	_light_center = _phase_light_position()
	_update_dynamic_geometry()
	queue_redraw()

func field_rect() -> Rect2:
	return FIELD_RECT

func world_to_screen_x(world_x: float) -> float:
	return KITE_SCREEN_X + (world_x - _camera_x) * WORLD_X_SCALE

func height_to_screen_y(world_height: float) -> float:
	var bounded := clampf(world_height, HEIGHT_WORLD_MIN, HEIGHT_WORLD_MAX)
	return lerpf(HEIGHT_TOP, HEIGHT_BOTTOM, inverse_lerp(HEIGHT_WORLD_MIN, HEIGHT_WORLD_MAX, bounded))

func ring_screen_center(index: int) -> Vector2:
	if index < 0 or index >= 5:
		return Vector2(-1.0, -1.0)
	return Vector2(world_to_screen_x(RING_WORLD_X[index]), height_to_screen_y(RING_WORLD_HEIGHT[index]))

func ring_visual_bounds(index: int) -> Rect2:
	var center := ring_screen_center(index)
	return Rect2(center - Vector2(RING_HALF_DEPTH, RING_HALF_HEIGHT), Vector2(RING_HALF_DEPTH * 2.0, RING_HALF_HEIGHT * 2.0))

func kite_screen_center() -> Vector2:
	return _kite_center

func kite_visual_bounds() -> Rect2:
	return _kite_bounds

func warning_triangle_bounds() -> Rect2:
	return Rect2(Vector2(866.0, 657.0) + Vector2(-9.0, -10.0), Vector2(18.0, 17.0)).grow(1.0)

func ring_status(index: int) -> String:
	if index == _next_ring and index < 5:
		return "next"
	for marker: Dictionary in _event_markers:
		if int(marker.get("ring", -1)) == index:
			return str(marker.get("kind", "resolved"))
	return "silhouette"

func legend_style(which: String) -> String:
	return "solid_vertical_arrow" if which == "actual" else "dashed_open_vertical_arrow"

func wind_arrow_tip(origin: Vector2, value: float) -> Vector2:
	var normalized := clampf(value / 185.0, -1.0, 1.0)
	var length := 6.0 + absf(normalized) * 16.0
	return origin + Vector2(0.0, -signf(normalized) * length)

func tail_wind_offset(value: float, distance: float) -> float:
	return -clampf(value / 185.0, -1.0, 1.0) * 12.0 * (distance / 34.0)

func geometry_revision() -> int:
	return _geometry_revision

func _ensure_geometry() -> void:
	if _geometry_revision == GEOMETRY_REVISION:
		return
	_far_harbor = PackedVector2Array([
		Vector2(-40, 486), Vector2(12, 486), Vector2(34, 478), Vector2(52, 475), Vector2(52, 455),
		Vector2(68, 443), Vector2(83, 455), Vector2(83, 475), Vector2(103, 480),
		Vector2(124, 474), Vector2(144, 462), Vector2(163, 470), Vector2(182, 454), Vector2(204, 466),
		Vector2(221, 480), Vector2(266, 480), Vector2(284, 469), Vector2(305, 472), Vector2(321, 454),
		Vector2(341, 463), Vector2(365, 481), Vector2(420, 481), Vector2(443, 467), Vector2(464, 474),
		Vector2(484, 458), Vector2(506, 463), Vector2(530, 482), Vector2(592, 482), Vector2(614, 470),
		Vector2(636, 472), Vector2(655, 451), Vector2(675, 461), Vector2(694, 482), Vector2(760, 482),
		Vector2(784, 466), Vector2(807, 474), Vector2(828, 456), Vector2(851, 466), Vector2(873, 483),
		Vector2(934, 483), Vector2(958, 470), Vector2(982, 476), Vector2(1004, 450), Vector2(1029, 464),
		Vector2(1048, 484), Vector2(1112, 484), Vector2(1135, 468), Vector2(1157, 475), Vector2(1178, 453),
		Vector2(1201, 462), Vector2(1221, 482), Vector2(1320, 482), Vector2(1320, 540), Vector2(-40, 540)
	])
	_far_cliff = PackedVector2Array([
		Vector2(-40, 550), Vector2(28, 542), Vector2(91, 530), Vector2(154, 533), Vector2(213, 539),
		Vector2(278, 524), Vector2(342, 518), Vector2(411, 531), Vector2(480, 535), Vector2(547, 519),
		Vector2(612, 512), Vector2(682, 525), Vector2(748, 533), Vector2(818, 519), Vector2(886, 513),
		Vector2(952, 527), Vector2(1018, 533), Vector2(1085, 518), Vector2(1152, 512), Vector2(1218, 526),
		Vector2(1320, 536), Vector2(1320, 720), Vector2(-40, 720)
	])
	_near_cliff = PackedVector2Array([
		Vector2(-40, 587), Vector2(24, 578), Vector2(84, 572), Vector2(143, 580), Vector2(197, 578),
		Vector2(248, 561), Vector2(300, 554), Vector2(353, 563), Vector2(408, 577), Vector2(463, 580),
		Vector2(518, 568), Vector2(571, 557), Vector2(626, 559), Vector2(681, 574), Vector2(734, 580),
		Vector2(789, 567), Vector2(843, 556), Vector2(898, 562), Vector2(954, 577), Vector2(1010, 581),
		Vector2(1066, 568), Vector2(1120, 557), Vector2(1176, 562), Vector2(1231, 578), Vector2(1320, 585),
		Vector2(1320, 720), Vector2(-40, 720)
	])
	_cliff_facets.clear()
	_cliff_facets.append(PackedVector2Array([Vector2(0, 592), Vector2(220, 576), Vector2(374, 720), Vector2(0, 720)]))
	_cliff_facets.append(PackedVector2Array([Vector2(412, 580), Vector2(684, 575), Vector2(832, 720), Vector2(300, 720)]))
	_cliff_facets.append(PackedVector2Array([Vector2(840, 576), Vector2(1110, 574), Vector2(1280, 602), Vector2(1280, 720), Vector2(970, 720)]))
	_cliff_strata.clear()
	_cliff_strata.append(PackedVector2Array([Vector2(-20, 625), Vector2(76, 618), Vector2(142, 624), Vector2(222, 612), Vector2(310, 619)]))
	_cliff_strata.append(PackedVector2Array([Vector2(352, 650), Vector2(430, 641), Vector2(506, 647), Vector2(584, 633), Vector2(666, 641)]))
	_cliff_strata.append(PackedVector2Array([Vector2(704, 614), Vector2(788, 620), Vector2(874, 609), Vector2(948, 617)]))
	_cliff_strata.append(PackedVector2Array([Vector2(981, 658), Vector2(1055, 647), Vector2(1130, 653), Vector2(1235, 638), Vector2(1310, 642)]))
	_sea_wave_paths.clear()
	_sea_wave_paths.append(PackedVector2Array([Vector2(0, 0), Vector2(20, -2), Vector2(42, 1), Vector2(71, -1), Vector2(96, 0)]))
	_sea_wave_paths.append(PackedVector2Array([Vector2(130, 0), Vector2(147, -1), Vector2(164, 1), Vector2(190, 0)]))
	_sea_wave_paths.append(PackedVector2Array([Vector2(238, 0), Vector2(252, -2), Vector2(272, 1), Vector2(298, 0), Vector2(322, -1)]))
	_clouds.clear()
	_clouds.append(PackedVector2Array([Vector2(0, 18), Vector2(6, 8), Vector2(17, 5), Vector2(25, -4), Vector2(39, -6), Vector2(49, 1), Vector2(63, -1), Vector2(74, 6), Vector2(91, 5), Vector2(101, 13), Vector2(98, 19), Vector2(5, 21)]))
	_clouds.append(PackedVector2Array([Vector2(0, 15), Vector2(9, 9), Vector2(23, 9), Vector2(30, 1), Vector2(43, 0), Vector2(51, 8), Vector2(68, 7), Vector2(78, 13), Vector2(75, 18), Vector2(5, 20)]))
	_clouds.append(PackedVector2Array([Vector2(0, 14), Vector2(8, 4), Vector2(20, 3), Vector2(27, -3), Vector2(40, -2), Vector2(46, 5), Vector2(63, 4), Vector2(72, 11), Vector2(69, 17), Vector2(4, 19)]))
	_lighthouse_body = PackedVector2Array([Vector2(0, 0), Vector2(5, -44), Vector2(21, -44), Vector2(27, 0)])
	_lighthouse_roof = PackedVector2Array([Vector2(2, -44), Vector2(13, -57), Vector2(24, -44)])
	_lighthouse_lantern = PackedVector2Array([Vector2(5, -44), Vector2(5, -53), Vector2(21, -53), Vector2(21, -44)])
	_distant_boat = PackedVector2Array([Vector2(0, 0), Vector2(38, 0), Vector2(32, 7), Vector2(7, 7)])
	_distant_sail = PackedVector2Array([Vector2(14, -26), Vector2(14, -2), Vector2(2, -2)])
	_resize_points(_kite_body, 4)
	_resize_points(_kite_panel_left, 3)
	_resize_points(_kite_panel_right, 3)
	_resize_points(_kite_panel_top, 3)
	_resize_points(_kite_shadow, 4)
	_tail_flags.clear()
	for _flag_index in 4:
		var points := PackedVector2Array()
		points.resize(3)
		_tail_flags.append(points)
	_tether_points.resize(6)
	_bridle_line.resize(2)
	_resize_points(_spool_disc, 12)
	_resize_points(_spool_ring, 12)
	_resize_points(_warning_triangle, 3)
	_warning_triangle.set(0, Vector2(0, -10))
	_warning_triangle.set(1, Vector2(9, 7))
	_warning_triangle.set(2, Vector2(-9, 7))
	_geometry_revision = GEOMETRY_REVISION
	_update_dynamic_geometry()

func _resize_points(points: PackedVector2Array, count: int) -> void:
	points.resize(count)

func _update_dynamic_geometry() -> void:
	_kite_center = Vector2(KITE_SCREEN_X, height_to_screen_y(_kite_height))
	_kite_roll = 0.0 if _reduced_motion else clampf(_kite_velocity * 0.0012, -0.28, 0.28)
	_shadow_center = Vector2(KITE_SCREEN_X + signf(KITE_SCREEN_X - _light_center.x) * (603.0 - _kite_center.y) * 0.25, 603.0)
	_set_kite_points()
	_set_tail_and_tether_points()
	_kite_bounds = _component_union_bounds()

func _set_kite_points() -> void:
	var top := Vector2(0.0, -34.0)
	var right := Vector2(40.0, 0.0)
	var bottom := Vector2(-2.0, 31.0)
	var left := Vector2(-38.0, -2.0)
	top = _kite_center + top.rotated(_kite_roll)
	right = _kite_center + right.rotated(_kite_roll)
	bottom = _kite_center + bottom.rotated(_kite_roll)
	left = _kite_center + left.rotated(_kite_roll)
	_kite_body.set(0, top)
	_kite_body.set(1, right)
	_kite_body.set(2, bottom)
	_kite_body.set(3, left)
	_kite_panel_left.set(0, top)
	_kite_panel_left.set(1, left)
	_kite_panel_left.set(2, bottom)
	_kite_panel_right.set(0, top)
	_kite_panel_right.set(1, right)
	_kite_panel_right.set(2, bottom)
	_kite_panel_top.set(0, top)
	_kite_panel_top.set(1, right)
	_kite_panel_top.set(2, left)
	var shadow_scale := clampf(1.2 - _kite_height / 800.0, 0.38, 0.95)
	var shadow_size := Vector2(25.0, 8.0) * shadow_scale
	_kite_shadow.set(0, _shadow_center + Vector2(-shadow_size.x, 0.0))
	_kite_shadow.set(1, _shadow_center + Vector2(0.0, -shadow_size.y))
	_kite_shadow.set(2, _shadow_center + Vector2(shadow_size.x, 0.0))
	_kite_shadow.set(3, _shadow_center + Vector2(0.0, shadow_size.y))

func _draw() -> void:
	if _geometry_revision != GEOMETRY_REVISION:
		_ensure_geometry()
	_draw_sky()
	_draw_parallax_layers()
	_draw_kite_shadow()
	_draw_ring_backs()
	_draw_tether_and_kite()
	_draw_ring_fronts()
	_draw_flight_caption()
	_draw_bottom_instruments()

func _draw_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), _sky_color(), true)
	# Two quiet print bands create atmospheric depth without a flat, desert-like horizon.
	draw_rect(Rect2(0.0, 332.0, DESIGN_SIZE.x, 104.0), _horizon_color(), true)
	draw_rect(Rect2(0.0, 436.0, DESIGN_SIZE.x, 165.0), _sea_color(), true)
	_draw_clouds()
	var light_color := Color("#ffe8b8") if _time_phase != "night" else Color("#dae7ef")
	draw_circle(_light_center + Vector2(3.0, 4.0), 18.0, Color(INK, 0.10))
	for ray_index in 8:
		var angle := TAU * float(ray_index) / 8.0
		var inner := _light_center + Vector2(cos(angle), sin(angle)) * 24.0
		var outer := _light_center + Vector2(cos(angle), sin(angle)) * 30.0
		draw_line(inner, outer, Color(light_color, 0.34), 1.1, true)
	draw_circle(_light_center, 16.0, Color(light_color, 0.20))
	draw_circle(_light_center, 9.0, light_color)
	if _time_phase == "night":
		_draw_night_sparks()

func _draw_clouds() -> void:
	var drift := -fposmod(_camera_x * 0.012, DESIGN_SIZE.x)
	var cloud_tint := Color("#f0e5c9", 0.40) if _time_phase != "night" else Color("#b5c7ca", 0.28)
	var cloud_shadow := Color("#567f82", 0.12) if _time_phase != "night" else Color("#172f48", 0.20)
	for cloud_index in _clouds.size():
		var base_x := CLOUD_X[cloud_index]
		var base_y := CLOUD_Y[cloud_index]
		for repeat in 2:
			var cloud_x := base_x + drift + float(repeat) * DESIGN_SIZE.x
			if cloud_x < -140.0 or cloud_x > DESIGN_SIZE.x + 90.0:
				continue
			draw_set_transform(Vector2(cloud_x, base_y + 4.0))
			draw_colored_polygon(_clouds[cloud_index], cloud_shadow)
			draw_set_transform(Vector2(cloud_x, base_y))
			draw_colored_polygon(_clouds[cloud_index], cloud_tint)
			draw_polyline(_clouds[cloud_index], Color(PAPER, 0.33), 1.0, true)
			draw_set_transform(Vector2.ZERO)

func _draw_night_sparks() -> void:
	for i in 9:
		var sx := float((i * 137 + 91) % 1190 + 35)
		var sy := float((i * 47 + 173) % 205 + 155)
		draw_circle(Vector2(sx, sy), 1.3 if i % 3 == 0 else 0.8, Color("#e4ead5", 0.72))

func _draw_parallax_layers() -> void:
	var harbor_shift := -fposmod(_camera_x * 0.035, DESIGN_SIZE.x)
	var far_shift := -fposmod(_camera_x * 0.09, DESIGN_SIZE.x)
	var near_shift := -fposmod(_camera_x * 0.17, DESIGN_SIZE.x)
	for repeat in 2:
		var copy_x := float(repeat) * DESIGN_SIZE.x
		draw_set_transform(Vector2(harbor_shift + copy_x, 0.0))
		draw_colored_polygon(_far_harbor, _harbor_color())
		_draw_harbor_landmarks()
	_draw_sea_ribbons()
	for repeat in 2:
		var copy_x := float(repeat) * DESIGN_SIZE.x
		draw_set_transform(Vector2(far_shift + copy_x, 0.0))
		draw_colored_polygon(_far_cliff, _far_cliff_color())
		_draw_cliff_strata(0.0, 0.50)
		draw_set_transform(Vector2(near_shift + copy_x, 0.0))
		draw_colored_polygon(_near_cliff, _near_cliff_color())
		for facet_index in _cliff_facets.size():
			draw_colored_polygon(_cliff_facets[facet_index], _cliff_facet_color(facet_index))
		_draw_cliff_strata(0.0, 0.78)
		_draw_ridge_foam()
		draw_set_transform(Vector2.ZERO)

func _draw_harbor_landmarks() -> void:
	# One beacon tower and a few broken roof clusters give the far shore scale.
	var lighthouse_x := 81.0
	var lighthouse_y := 470.0
	draw_set_transform(Vector2(lighthouse_x, lighthouse_y))
	draw_colored_polygon(_lighthouse_body, Color("#d9c69e"))
	draw_colored_polygon(_lighthouse_roof, Color(CORAL, 0.94))
	draw_colored_polygon(_lighthouse_lantern, Color("#f0d49b"))
	draw_line(Vector2(5, -44), Vector2(21, -44), Color(INK, 0.66), 1.2)
	draw_rect(Rect2(9.0, -34.0, 3.0, 5.0), Color(DEEP, 0.72), true)
	draw_rect(Rect2(17.0, -28.0, 3.0, 5.0), Color(DEEP, 0.72), true)
	draw_line(Vector2(4, -52), Vector2(-15, -61), Color(OCHRE, 0.48), 1.0)
	draw_line(Vector2(22, -52), Vector2(39, -60), Color(OCHRE, 0.48), 1.0)
	draw_set_transform(Vector2.ZERO)
	# Roof accents are separated into two small settlements instead of a repeated block grid.
	for roof_x in ROOF_ACCENTS:
		var roof_y := 470.0 if roof_x < 300.0 else 482.0 if roof_x > 900.0 else 480.0
		draw_line(Vector2(roof_x - 13.0, roof_y), Vector2(roof_x, roof_y - 10.0), Color(PAPER, 0.34), 1.2, true)
		draw_line(Vector2(roof_x, roof_y - 10.0), Vector2(roof_x + 15.0, roof_y), Color(PAPER, 0.34), 1.2, true)
	for lamp_index in 3:
		var lx := 187.0 + float(lamp_index) * 347.0
		draw_line(Vector2(lx, 483.0), Vector2(lx, 469.0), _harbor_lamp_stem(), 1.4, true)
		draw_circle(Vector2(lx, 467.0), 2.1, Color("#ffd48a") if _time_phase == "dusk" or _time_phase == "night" else Color("#f2d5a0", 0.58))
	# A single sailboat sits on the open water as a scale cue.
	var boat_x := 930.0
	var boat_y := 493.0
	draw_set_transform(Vector2(boat_x, boat_y))
	draw_colored_polygon(_distant_boat, Color("#425e63", 0.66))
	draw_line(Vector2(15, -27), Vector2(15, -1), Color(PAPER, 0.74), 1.1, true)
	draw_colored_polygon(_distant_sail, Color("#ead6ae", 0.82))
	draw_set_transform(Vector2.ZERO)

func _draw_cliff_strata(_offset: float, opacity: float) -> void:
	var ink_color := Color("#d6b57e", 0.36 * opacity) if _time_phase != "night" else Color("#96aeb0", 0.28 * opacity)
	for line_index in _cliff_strata.size():
		var path := _cliff_strata[line_index]
		draw_polyline(path, ink_color if line_index % 2 == 0 else Color(INK, 0.20 * opacity), 1.4, true)

func _draw_ridge_foam() -> void:
	var foam := Color("#d7ddc4", 0.38) if _time_phase != "night" else Color("#8eaeb0", 0.27)
	for foam_index in 7:
		var x := 46.0 + float(foam_index) * 184.0
		var y := 580.0 + sin(float(foam_index) * 1.1) * 10.0
		draw_line(Vector2(x, y), Vector2(x + 24.0, y - 3.0), foam, 1.2, true)
		draw_line(Vector2(x + 32.0, y + 2.0), Vector2(x + 45.0, y), Color(foam, foam.a * 0.65), 0.9, true)

func _draw_sea_ribbons() -> void:
	var shift := -fposmod(_camera_x * 0.19, 340.0)
	var water_ink := Color("#c3d9c2", 0.40) if _time_phase != "night" else Color("#8eb8b6", 0.34)
	for row in 4:
		var base_y := 451.0 + float(row) * 23.0
		for repeat in 5:
			var sx := shift + float(repeat) * 340.0 + float(row) * 71.0
			draw_set_transform(Vector2(sx, base_y))
			draw_polyline(_sea_wave_paths[row % _sea_wave_paths.size()], water_ink, 1.25 if row % 2 == 0 else 0.9, true)
			draw_set_transform(Vector2.ZERO)
		if row == 1 or row == 3:
			for foam_index in 7:
				var foam_x := shift + float(foam_index) * 191.0 + float(row) * 48.0
				draw_line(Vector2(foam_x, base_y + 5.0), Vector2(foam_x + 6.0, base_y + 4.0), Color(water_ink, 0.74), 1.0, true)

func _draw_kite_shadow() -> void:
	draw_colored_polygon(_kite_shadow, Color(_shadow_color(), 0.44))
	draw_line(_kite_center + Vector2(4.0, 15.0), _shadow_center, Color(_shadow_color(), 0.18), 1.1)

func _draw_ring_backs() -> void:
	for index in 5:
		_draw_ring(index, false)
		if ring_status(index) != "next":
			_draw_ring(index, true)

func _draw_ring_fronts() -> void:
	for index in 5:
		if ring_status(index) == "next":
			_draw_ring(index, true)

func _draw_ring(index: int, front_half: bool) -> void:
	var center := ring_screen_center(index)
	if center.x < FIELD_RECT.position.x - 40.0 or center.x > FIELD_RECT.end.x + 40.0:
		return
	var status := ring_status(index)
	var color := _ring_color(status)
	var alpha := 0.96 if status == "next" else (0.74 if status == "center" else 0.57 if status == "edge" else 0.46 if status == "miss" else 0.19)
	if status == "miss":
		alpha = 0.7
	draw_set_transform(center, 0.0, Vector2(RING_HALF_DEPTH, RING_HALF_HEIGHT))
	var start_angle := -PI / 2.0 if front_half else PI / 2.0
	var end_angle := PI / 2.0 if front_half else 3.0 * PI / 2.0
	if front_half:
		if status == "next":
			draw_circle(Vector2.ZERO, 0.17, Color(SEA_GLASS, 0.12))
			draw_arc(Vector2.ZERO, 0.53, -0.18, 0.18, 18, Color(CREAM, 0.42), 0.035)
			draw_line(Vector2(-0.17, 0), Vector2(0.17, 0), Color(PAPER, 0.48), 0.018, true)
	var face_color := Color(color, alpha) if front_half else Color(color.darkened(0.38), alpha * 0.76)
	draw_arc(Vector2.ZERO, 0.88, start_angle, end_angle, 32, Color(INK, alpha * 0.88), 0.105)
	draw_arc(Vector2.ZERO, 0.88, start_angle, end_angle, 32, face_color, 0.055)
	if status == "edge" and front_half:
		for tick in 3:
			var tick_y := -0.14 + float(tick) * 0.14
			draw_line(Vector2(0.71, tick_y), Vector2(0.98, tick_y + 0.06), Color(OCHRE, 0.92), 0.035, true)
	elif status == "miss" and front_half:
		draw_line(Vector2(0.67, -0.16), Vector2(0.96, -0.02), Color(CORAL, 0.96), 0.045, true)
		draw_line(Vector2(0.66, 0.12), Vector2(0.91, 0.27), Color(CORAL, 0.96), 0.045, true)
	if front_half and status == "center":
		draw_arc(Vector2.ZERO, 0.94, -0.16, 0.16, 12, Color(TIDAL, 0.82), 0.055)
	if front_half and status == "next":
		for rivet in 3:
			var rivet_angle := -0.65 + float(rivet) * 0.65
			draw_circle(Vector2(cos(rivet_angle), sin(rivet_angle)) * 0.88, 0.035, Color(PAPER, 0.65))
	draw_set_transform(Vector2.ZERO)


func _set_tail_and_tether_points() -> void:
	var anchor := Vector2(226.0, 614.0)
	var tail := _kite_center + Vector2(-20.0, 14.0)
	var slack := (1.0 - _tension) * 32.0
	var control := (tail + anchor) * 0.5 + Vector2(0.0, slack)
	for segment in _tether_points.size():
		_tether_points.set(segment, _quadratic(tail, control, anchor, float(segment) / float(_tether_points.size() - 1)))
	_bridle_line.set(0, _kite_center + Vector2(-7.0, 1.0))
	_bridle_line.set(1, _kite_center + Vector2(-19.0, 67.0))
	var spool_center: Vector2 = _tether_points[_tether_points.size() - 1]
	for point_index in _spool_disc.size():
		var angle := TAU * float(point_index) / float(_spool_disc.size())
		_spool_disc.set(point_index, spool_center + Vector2(cos(angle), sin(angle)) * 4.5)
		_spool_ring.set(point_index, spool_center + Vector2(cos(angle), sin(angle)) * 6.2)
	var wind_lift := clampf(_actual_wind / 185.0, -1.0, 1.0) * 12.0
	var flag_base := _kite_center + Vector2(-20.0, 13.0)
	for flag_index in _tail_flags.size():
		var distance := 31.0 + float(flag_index) * 11.0
		var wave := _tail_wave(flag_index)
		var flag_center := flag_base + Vector2(-distance, 12.0 + wave + tail_wind_offset(_actual_wind, distance))
		var points: PackedVector2Array = _tail_flags[flag_index]
		points.set(0, flag_center + Vector2(3.5, -4.0))
		points.set(1, flag_center + Vector2(15.0, 0.0))
		points.set(2, flag_center + Vector2(2.0, 4.0))
		_tail_flags[flag_index] = points

func _component_union_bounds() -> Rect2:
	var bounds := _polygon_bounds(_kite_body)
	bounds = bounds.merge(_polygon_bounds(_kite_panel_left))
	bounds = bounds.merge(_polygon_bounds(_kite_panel_right))
	bounds = bounds.merge(_polygon_bounds(_kite_panel_top))
	bounds = bounds.merge(_polygon_bounds(_kite_shadow))
	bounds = bounds.merge(_polygon_bounds(_tether_points))
	bounds = bounds.merge(_polygon_bounds(_bridle_line))
	bounds = bounds.merge(_polygon_bounds(_spool_disc))
	bounds = bounds.merge(_polygon_bounds(_spool_ring))
	for flag in _tail_flags:
		bounds = bounds.merge(_polygon_bounds(flag))
	return bounds.grow(1.5)

func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for index in range(1, points.size()):
		var point := points[index]
		minimum.x = minf(minimum.x, point.x); minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x); maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)

func _draw_vertical_arrow_head(tip: Vector2, flow_sign: float, color: Color) -> void:
	draw_line(tip, tip + Vector2(-5.0, flow_sign * 8.0), color, 2.2, true)
	draw_line(tip, tip + Vector2(5.0, flow_sign * 8.0), color, 2.2, true)

func _draw_tether_and_kite() -> void:
	for segment in range(1, _tether_points.size()):
		draw_line(_tether_points[segment - 1], _tether_points[segment], Color(INK, 0.72), 1.45, true)
	for flag_index in _tail_flags.size():
		draw_colored_polygon(_tail_flags[flag_index], _tail_color(flag_index))
	# The near ring's front half is drawn after the kite to establish real depth ordering.
	draw_colored_polygon(_kite_body, _kite_base_color())
	draw_colored_polygon(_kite_panel_left, _kite_left_color())
	draw_colored_polygon(_kite_panel_right, _kite_right_color())
	draw_colored_polygon(_kite_panel_top, _kite_top_color())
	draw_line(_kite_body[0], _kite_body[1], Color(INK, 0.82), 1.4, true)
	draw_line(_kite_body[1], _kite_body[2], Color(INK, 0.82), 1.4, true)
	draw_line(_kite_body[2], _kite_body[3], Color(INK, 0.82), 1.4, true)
	draw_line(_kite_body[3], _kite_body[0], Color(INK, 0.82), 1.4, true)
	var spar_color := Color(PAPER, 0.87)
	draw_line(_kite_body[0], _kite_body[2], spar_color, 1.4, true)
	draw_line(_kite_body[3], _kite_body[1], Color(INK, 0.82), 1.7, true)
	draw_line(_bridle_line[0], _bridle_line[1], Color(PAPER, 0.9), 1.8, true)
	draw_circle(_kite_body[0], 2.3, Color(OCHRE, 0.92))
	draw_circle(_kite_body[2], 2.0, Color(OCHRE, 0.82))
	draw_circle(_kite_center, 4.2, Color(INK, 0.86))
	draw_circle(_kite_center, 2.0, Color(CREAM, 0.96))
	var anchor := _tether_points[_tether_points.size() - 1]
	draw_colored_polygon(_spool_disc, Color(INK, 0.82))
	draw_polyline(_spool_ring, Color(PAPER, 0.76), 1.0, true)
	draw_arc(anchor, 5.8, 0.0, TAU, 18, Color(OCHRE, 0.82), 1.1)

func _draw_flight_caption() -> void:
	var label := "海崖風環航道"
	var tint := Color(INK, 0.8)
	if _phase == "results" or _phase == "ended":
		label = "航程完成"
	if _event == "miss":
		label = "環口未通過　回到航線再試"
		tint = CORAL
	elif _event == "edge":
		label = "擦過環緣　收穩風箏"
		tint = OCHRE
	elif _event == "center":
		label = "穿越環心"
		tint = SEA_GLASS
	elif _event == "line_snap":
		label = "線張力過高　風箏已復位"
		tint = CORAL
	draw_string(FONT, Vector2(91.0, 174.0), label, HORIZONTAL_ALIGNMENT_LEFT, 300.0, 15, tint)

func _draw_bottom_instruments() -> void:
	draw_rect(Rect2(80.0, 637.0, 1120.0, 71.0), Color(_instrument_bg(), 0.94), true)
	draw_line(Vector2(80.0, 637.0), Vector2(1200.0, 637.0), Color(PAPER, 0.52), 1.0)
	draw_string(FONT, Vector2(98.0, 660.0), "現風", HORIZONTAL_ALIGNMENT_LEFT, 70.0, 14, _instrument_text())
	_draw_actual_wind(Vector2(177.0, 668.0), _actual_wind)
	draw_string(FONT, Vector2(358.0, 660.0), "1.25 秒後", HORIZONTAL_ALIGNMENT_LEFT, 115.0, 14, _instrument_text())
	_draw_forecast_wind(Vector2(468.0, 668.0), _forecast_wind)
	draw_string(FONT, Vector2(642.0, 660.0), "線張力", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, _instrument_text())
	_draw_tension_gauge()
	draw_string(FONT, Vector2(883.0, 660.0), "收線減壓" if _tension_warning else "衝刺看線", HORIZONTAL_ALIGNMENT_LEFT, 118.0, 14, _warning_text())
	draw_string(FONT, Vector2(1024.0, 660.0), "備線", HORIZONTAL_ALIGNMENT_LEFT, 56.0, 14, _instrument_text())
	for rescue_index in 2:
		var dot := Vector2(1092.0 + float(rescue_index) * 34.0, 657.0)
		var used := rescue_index < _rescues_used
		draw_circle(dot, 7.0, Color(CORAL if used else OCHRE, 0.84))
		draw_arc(dot, 8.5, 0.0, TAU, 20, Color(PAPER, 0.92), 1.5)
		if not used:
			draw_line(dot + Vector2(-3, 0), dot + Vector2(3, 0), Color(CREAM, 0.9), 1.3)
	draw_string(FONT, Vector2(96.0, 692.0), "↑↓迎風　短按衝刺　收線降張力　↑氣流升高", HORIZONTAL_ALIGNMENT_LEFT, 450.0, 12, Color(_instrument_text(), 0.82))
	draw_string(FONT, Vector2(700.0, 692.0), "五枚風環　中心最穩", HORIZONTAL_ALIGNMENT_LEFT, 280.0, 12, Color(_instrument_text(), 0.82))

func _draw_actual_wind(origin: Vector2, value: float) -> void:
	var normalized := clampf(value / 185.0, -1.0, 1.0)
	if absf(normalized) < 0.015:
		draw_circle(origin, 3.0, Color(TIDAL, 0.98))
		return
	var direction := signf(normalized)
	var end := wind_arrow_tip(origin, value)
	draw_line(origin, end, Color(TIDAL, 0.98), 3.2, true)
	_draw_vertical_arrow_head(end, direction, Color(TIDAL, 0.98))
	draw_line(origin + Vector2(-4.0, 9.0), origin + Vector2(4.0, 9.0), Color(PAPER, 0.35), 1.0)

func _draw_forecast_wind(origin: Vector2, value: float) -> void:
	var normalized := clampf(value / 185.0, -1.0, 1.0)
	if absf(normalized) < 0.015:
		draw_arc(origin, 3.0, 0.0, TAU, 20, Color(CORAL, 0.96), 1.6)
		return
	var direction := signf(normalized)
	var end := wind_arrow_tip(origin, value)
	_draw_dashed_line(origin, end, Color(CORAL, 0.96), 2.3, 5.0, 4.0)
	_draw_vertical_arrow_head(end, direction, Color(CORAL, 0.96))
	draw_line(origin + Vector2(-4.0, 9.0), origin + Vector2(4.0, 9.0), Color(PAPER, 0.35), 1.0)

func _draw_tension_gauge() -> void:
	var gauge := Rect2(714.0, 648.0, 150.0, 17.0)
	draw_rect(gauge, Color(INK, 0.7), true)
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * _tension, gauge.size.y)), _tension_color(), true)
	var risk_x := gauge.position.x + gauge.size.x * 0.78
	draw_line(Vector2(risk_x, 645.0), Vector2(risk_x, 669.0), Color(CORAL, 0.98), 2.0, true)
	if _tension_warning:
		draw_set_transform(Vector2(866.0, 657.0))
		draw_colored_polygon(_warning_triangle, CORAL)
		draw_line(Vector2(0, -4), Vector2(0, 2), CREAM, 1.5, true)
		draw_circle(Vector2(0, 4), 0.8, CREAM)
		draw_set_transform(Vector2.ZERO)
		var risk_width := 150.0 * _tension_risk
		draw_rect(Rect2(714.0, 671.0, risk_width, 3.0), CORAL, true)

func _draw_filled_arrow_head(tip: Vector2, direction: float, color: Color) -> void:
	var side := 1.0 if direction >= 0.0 else -1.0
	draw_line(tip, tip + Vector2(-side * 8.0, -5.0), color, 2.2, true)
	draw_line(tip, tip + Vector2(-side * 8.0, 5.0), color, 2.2, true)

func _draw_open_arrow_head(tip: Vector2, direction: float, color: Color) -> void:
	var side := 1.0 if direction >= 0.0 else -1.0
	draw_line(tip, tip + Vector2(-side * 8.0, -5.0), color, 1.8, true)
	draw_line(tip, tip + Vector2(-side * 8.0, 5.0), color, 1.8, true)

func _draw_dashed_line(start: Vector2, finish: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var vector := finish - start
	var direction := vector.normalized()
	var total := vector.length()
	var offset := 0.0
	while offset < total:
		var last := minf(offset + dash, total)
		draw_line(start + direction * offset, start + direction * last, color, width, true)
		offset += dash + gap

func _quadratic(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return inverse * inverse * a + 2.0 * inverse * t * control + t * t * b

func _tail_wave(index: int) -> float:
	return 0.0 if _reduced_motion else sin(_elapsed * 5.2 + float(index) * 0.9) * 3.0

func _ring_color(status: String) -> Color:
	match status:
		"center": return SEA_GLASS
		"edge": return OCHRE
		"miss": return CORAL
		"next": return Color("#d29a4f")
		_: return Color("#637f80")

func _tail_color(index: int) -> Color:
	match index % 3:
		0: return CORAL
		1: return Color("#e3bd72")
		_: return TIDAL

func _sky_color() -> Color:
	match _time_phase:
		"dawn": return Color("#d7a88d")
		"dusk": return Color("#856f87")
		"night": return Color("#253e5a")
		_: return Color("#91c4c4")

func _horizon_color() -> Color:
	match _time_phase:
		"dawn": return Color("#f0c595")
		"dusk": return Color("#d78b75")
		"night": return Color("#526579")
		_: return Color("#d6d19f")

func _sea_color() -> Color:
	match _time_phase:
		"dawn": return Color("#679b98")
		"dusk": return Color("#526f79")
		"night": return Color("#29485b")
		_: return Color("#70aaa5")

func _harbor_color() -> Color:
	match _time_phase:
		"dawn": return Color("#6c7775")
		"dusk": return Color("#565665")
		"night": return Color("#273f50")
		_: return Color("#758b80")

func _far_cliff_color() -> Color:
	match _time_phase:
		"dawn": return Color("#5d7b79")
		"dusk": return Color("#4e6068")
		"night": return Color("#294b5a")
		_: return Color("#567b75")

func _near_cliff_color() -> Color:
	match _time_phase:
		"dawn": return Color("#385b5d")
		"dusk": return Color("#3b4d5a")
		"night": return Color("#1d394a")
		_: return Color("#335b5c")

func _cliff_facet_color(index: int) -> Color:
	if _time_phase == "night":
		return Color("#284658") if index % 2 == 0 else Color("#345667")
	if _time_phase == "dusk":
		return Color("#4e515b") if index % 2 == 0 else Color("#655365")
	return Color("#42696a") if index % 2 == 0 else Color("#4d7470")

func _harbor_lamp_stem() -> Color:
	return Color("#465961") if _time_phase == "night" else Color("#566e6d", 0.76)

func _sea_ribbon_color(index: int) -> Color:
	var base := Color("#83c9bd", 0.62) if _time_phase != "night" else Color("#83aeb1", 0.46)
	return Color(base, base.a * (0.8 if index == 0 else 0.46))

func _shadow_color() -> Color:
	return Color("#1f3d45") if _time_phase != "night" else Color("#182e42")

func _instrument_bg() -> Color:
	return Color("#243f4d") if _time_phase != "night" else Color("#182d41")

func _instrument_text() -> Color:
	return Color("#f3e5c8")

func _warning_text() -> Color:
	return Color("#f1b7a8") if _tension_warning else Color("#ead9b7", 0.88)

func _tension_color() -> Color:
	if _tension_warning:
		return CORAL
	return OCHRE if _tension >= 0.58 else SEA_GLASS

func _kite_base_color() -> Color:
	return Color("#293e4b")

func _kite_left_color() -> Color:
	return Color("#d4695b") if _time_phase != "night" else Color("#d47b6b")

func _kite_right_color() -> Color:
	return Color("#e2bc72")

func _kite_top_color() -> Color:
	return Color("#72b4a5")

func _phase_light_position() -> Vector2:
	match _time_phase:
		"dawn": return Vector2(190.0, 218.0)
		"dusk": return Vector2(905.0, 228.0)
		"night": return Vector2(1080.0, 193.0)
		_: return Vector2(1040.0, 176.0)

func _normalized_time_phase(value: String) -> String:
	match value:
		"dawn", "noon", "dusk", "night": return value
		_: return "noon"
