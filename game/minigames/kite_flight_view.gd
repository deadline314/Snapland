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
const GEOMETRY_REVISION := 4
const CLOUD_X: Array[float] = [90.0, 455.0, 935.0]
const CLOUD_Y: Array[float] = [260.0, 218.0, 300.0]
const ROOF_ACCENTS: Array[float] = [158.0, 176.0, 319.0, 484.0, 653.0, 822.0, 1000.0, 1174.0]
const STREAMER_START_X: Array[float] = [154.0, 555.0, 947.0]
const STREAMER_LENGTH: Array[float] = [188.0, 214.0, 176.0]
const STREAMER_BASE_Y: Array[float] = [244.0, 299.0, 255.0]
const FontProfiles = preload("res://game/ui/font_profiles.gd")

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
var _far_ridge := PackedVector2Array()
var _near_ridge := PackedVector2Array()
var _cliff_facets: Array[PackedVector2Array] = []
var _cliff_arches: Array[PackedVector2Array] = []
var _cliff_strata: Array[PackedVector2Array] = []
var _sea_wave_paths: Array[PackedVector2Array] = []
var _wind_streamers: Array[PackedVector2Array] = []
var _clouds: Array[PackedVector2Array] = []
var _lighthouse_body := PackedVector2Array()
var _lighthouse_roof := PackedVector2Array()
var _lighthouse_lantern := PackedVector2Array()
var _distant_boat := PackedVector2Array()
var _distant_sail := PackedVector2Array()
var _beacon_pennant := PackedVector2Array()
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

func _parallax_offset(camera_x: float, rate: float, width: float = DESIGN_SIZE.x) -> float:
	return -fposmod(camera_x * rate, width)

func _wind_streamer_lift(index: int) -> float:
	if index < 0 or index >= _wind_streamers.size() or _wind_streamers[index].size() < 2:
		return 0.0
	var points := _wind_streamers[index]
	return points[points.size() - 1].y - points[0].y

func _ridge_fill(ridge: PackedVector2Array, bottom_y: float) -> PackedVector2Array:
	var filled := ridge.duplicate()
	filled.append(Vector2(ridge[ridge.size() - 1].x, bottom_y))
	filled.append(Vector2(ridge[0].x, bottom_y))
	return filled

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
		Vector2(1201, 462), Vector2(1221, 482), Vector2(1320, 482), Vector2(1320, 492), Vector2(-40, 492)
	])
	_far_ridge = PackedVector2Array([
		Vector2(-40, 454), Vector2(22, 447), Vector2(72, 426), Vector2(121, 421), Vector2(165, 433),
		Vector2(203, 455), Vector2(248, 468), Vector2(311, 468), Vector2(367, 459), Vector2(414, 445),
		Vector2(462, 448), Vector2(514, 466), Vector2(570, 474), Vector2(618, 459), Vector2(659, 431),
		Vector2(698, 424), Vector2(741, 438), Vector2(784, 462), Vector2(826, 472), Vector2(871, 467),
		Vector2(914, 449), Vector2(954, 438), Vector2(1001, 440), Vector2(1044, 455), Vector2(1086, 472),
		Vector2(1144, 475), Vector2(1197, 462), Vector2(1251, 447), Vector2(1320, 458)
	])
	_far_cliff = _ridge_fill(_far_ridge, 720.0)
	_near_ridge = PackedVector2Array([
		Vector2(-40, 562), Vector2(12, 554), Vector2(57, 527), Vector2(96, 506), Vector2(131, 510),
		Vector2(165, 490), Vector2(202, 494), Vector2(229, 514), Vector2(265, 520), Vector2(302, 537),
		Vector2(344, 551), Vector2(383, 547), Vector2(418, 529), Vector2(454, 510), Vector2(489, 513),
		Vector2(520, 535), Vector2(556, 549), Vector2(592, 542), Vector2(626, 521), Vector2(660, 501),
		Vector2(691, 496), Vector2(723, 507), Vector2(752, 529), Vector2(782, 544), Vector2(818, 551),
		Vector2(851, 538), Vector2(879, 517), Vector2(913, 505), Vector2(948, 506), Vector2(978, 522),
		Vector2(1007, 545), Vector2(1038, 554), Vector2(1070, 543), Vector2(1102, 521), Vector2(1138, 512),
		Vector2(1174, 519), Vector2(1207, 540), Vector2(1260, 558), Vector2(1320, 560)
	])
	_near_cliff = _ridge_fill(_near_ridge, 720.0)
	_cliff_facets.clear()
	_cliff_facets.append(PackedVector2Array([Vector2(62, 527), Vector2(165, 490), Vector2(271, 720), Vector2(26, 720)]))
	_cliff_facets.append(PackedVector2Array([Vector2(416, 529), Vector2(489, 513), Vector2(594, 720), Vector2(362, 720)]))
	_cliff_facets.append(PackedVector2Array([Vector2(660, 501), Vector2(723, 507), Vector2(835, 720), Vector2(612, 720)]))
	_cliff_facets.append(PackedVector2Array([Vector2(913, 505), Vector2(978, 522), Vector2(1088, 720), Vector2(852, 720)]))
	_cliff_facets.append(PackedVector2Array([Vector2(1102, 521), Vector2(1174, 519), Vector2(1320, 720), Vector2(1084, 720)]))
	_cliff_arches.clear()
	_cliff_arches.append(PackedVector2Array([Vector2(200, 647), Vector2(207, 586), Vector2(226, 551), Vector2(252, 534), Vector2(279, 541), Vector2(300, 568), Vector2(311, 647)]))
	_cliff_arches.append(PackedVector2Array([Vector2(758, 647), Vector2(762, 589), Vector2(779, 562), Vector2(802, 551), Vector2(826, 560), Vector2(842, 587), Vector2(847, 647)]))
	_cliff_arches.append(PackedVector2Array([Vector2(1064, 647), Vector2(1073, 597), Vector2(1090, 578), Vector2(1112, 574), Vector2(1132, 590), Vector2(1145, 617), Vector2(1151, 647)]))
	_cliff_strata.clear()
	_cliff_strata.append(PackedVector2Array([Vector2(-20, 620), Vector2(32, 612), Vector2(95, 620), Vector2(148, 612), Vector2(218, 619), Vector2(286, 603)]))
	_cliff_strata.append(PackedVector2Array([Vector2(268, 634), Vector2(331, 627), Vector2(396, 637), Vector2(455, 622), Vector2(518, 628)]))
	_cliff_strata.append(PackedVector2Array([Vector2(618, 619), Vector2(676, 610), Vector2(738, 619), Vector2(806, 607), Vector2(864, 616)]))
	_cliff_strata.append(PackedVector2Array([Vector2(847, 641), Vector2(909, 632), Vector2(974, 641), Vector2(1037, 625), Vector2(1104, 635), Vector2(1176, 620), Vector2(1310, 634)]))
	_sea_wave_paths.clear()
	_sea_wave_paths.append(PackedVector2Array([Vector2(0, 0), Vector2(20, -2), Vector2(42, 1), Vector2(71, -1), Vector2(96, 0)]))
	_sea_wave_paths.append(PackedVector2Array([Vector2(130, 0), Vector2(147, -1), Vector2(164, 1), Vector2(190, 0)]))
	_sea_wave_paths.append(PackedVector2Array([Vector2(238, 0), Vector2(252, -2), Vector2(272, 1), Vector2(298, 0), Vector2(322, -1)]))
	_wind_streamers.clear()
	for streamer_index in STREAMER_START_X.size():
		var streamer := PackedVector2Array()
		streamer.resize(8)
		_wind_streamers.append(streamer)
	_clouds.clear()
	_clouds.append(PackedVector2Array([Vector2(0, 18), Vector2(6, 8), Vector2(17, 5), Vector2(25, -4), Vector2(39, -6), Vector2(49, 1), Vector2(63, -1), Vector2(74, 6), Vector2(91, 5), Vector2(101, 13), Vector2(98, 19), Vector2(5, 21)]))
	_clouds.append(PackedVector2Array([Vector2(0, 15), Vector2(9, 9), Vector2(23, 9), Vector2(30, 1), Vector2(43, 0), Vector2(51, 8), Vector2(68, 7), Vector2(78, 13), Vector2(75, 18), Vector2(5, 20)]))
	_clouds.append(PackedVector2Array([Vector2(0, 14), Vector2(8, 4), Vector2(20, 3), Vector2(27, -3), Vector2(40, -2), Vector2(46, 5), Vector2(63, 4), Vector2(72, 11), Vector2(69, 17), Vector2(4, 19)]))
	_lighthouse_body = PackedVector2Array([Vector2(0, 0), Vector2(5, -44), Vector2(21, -44), Vector2(27, 0)])
	_lighthouse_roof = PackedVector2Array([Vector2(2, -44), Vector2(13, -57), Vector2(24, -44)])
	_lighthouse_lantern = PackedVector2Array([Vector2(5, -44), Vector2(5, -53), Vector2(21, -53), Vector2(21, -44)])
	_distant_boat = PackedVector2Array([Vector2(0, 0), Vector2(38, 0), Vector2(32, 7), Vector2(7, 7)])
	_distant_sail = PackedVector2Array([Vector2(14, -26), Vector2(14, -2), Vector2(2, -2)])
	_resize_points(_beacon_pennant, 3)
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
	_update_wind_geometry()
	_kite_bounds = _component_union_bounds()

func _update_wind_geometry() -> void:
	var lift := clampf(_actual_wind / 185.0, -1.0, 1.0)
	for ribbon_index in _wind_streamers.size():
		var path: PackedVector2Array = _wind_streamers[ribbon_index]
		var phase := _elapsed * 2.1 + float(ribbon_index) * 1.9
		for point_index in path.size():
			var t := float(point_index) / float(path.size() - 1)
			var x := STREAMER_START_X[ribbon_index] + t * STREAMER_LENGTH[ribbon_index]
			var bend := lift * (48.0 * t + 12.0 * sin(t * PI))
			var ripple := 0.0 if _reduced_motion else sin(phase + t * TAU * 1.45) * minf(absf(lift) * 3.2, 2.4)
			var y := STREAMER_BASE_Y[ribbon_index] - bend + ripple
			path.set(point_index, Vector2(x, y))
		_wind_streamers[ribbon_index] = path
	var flag_wave := 0.0 if _reduced_motion else sin(_elapsed * 2.3) * 2.0
	var flag_lift := -lift * 12.0 + flag_wave
	var flag_direction := 1.0 if absf(lift) < 0.015 else signf(lift)
	_beacon_pennant.set(0, Vector2(13.0, -68.0))
	_beacon_pennant.set(1, Vector2(13.0 + flag_direction * (9.0 + absf(lift) * 13.0), -65.0 + flag_lift))
	_beacon_pennant.set(2, Vector2(13.0, -59.0))

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
	# One quiet sea plane meets the sky at a clean horizon; the coast supplies the foreground texture.
	draw_rect(Rect2(0.0, 402.0, DESIGN_SIZE.x, DESIGN_SIZE.y - 402.0), _sea_color(), true)
	draw_line(Vector2(0.0, 402.0), Vector2(DESIGN_SIZE.x, 402.0), Color(PAPER, 0.48), 1.5, true)
	draw_line(Vector2(0.0, 406.0), Vector2(DESIGN_SIZE.x, 406.0), Color(INK, 0.12), 1.0, true)
	_draw_wind_streamers()
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

func _draw_wind_streamers() -> void:
	var strength := absf(clampf(_actual_wind / 185.0, -1.0, 1.0))
	if strength < 0.08:
		return
	for ribbon_index in _wind_streamers.size():
		var points: PackedVector2Array = _wind_streamers[ribbon_index]
		var band_alpha := 0.10 + strength * 0.18
		var core_alpha := 0.26 + strength * 0.42
		draw_polyline(points, Color(INK, band_alpha), 4.0 + strength * 2.0, true)
		draw_polyline(points, Color(TIDAL if _actual_wind >= 0.0 else CREAM, core_alpha), 1.4 + strength * 1.1, true)

func _draw_night_sparks() -> void:
	for i in 9:
		var sx := float((i * 137 + 91) % 1190 + 35)
		var sy := float((i * 47 + 173) % 205 + 155)
		draw_circle(Vector2(sx, sy), 1.3 if i % 3 == 0 else 0.8, Color("#e4ead5", 0.72))

func _draw_parallax_layers() -> void:
	var harbor_shift := _parallax_offset(_camera_x, 0.035)
	var far_shift := _parallax_offset(_camera_x, 0.09)
	var near_shift := _parallax_offset(_camera_x, 0.17)
	_draw_sea_ribbons()
	for repeat in 2:
		var copy_x := float(repeat) * DESIGN_SIZE.x
		draw_set_transform(Vector2(far_shift + copy_x, 0.0))
		draw_colored_polygon(_far_cliff, _far_cliff_color())
		draw_polyline(_far_ridge, _far_ridge_color(), 1.6, true)
		_draw_cliff_strata(0.0, 0.50)
		draw_set_transform(Vector2(harbor_shift + copy_x, 0.0))
		draw_colored_polygon(_far_harbor, _harbor_color())
		_draw_harbor_landmarks(harbor_shift + copy_x)
		draw_set_transform(Vector2(near_shift + copy_x, 0.0))
		draw_colored_polygon(_near_cliff, _near_cliff_color())
		draw_polyline(_near_ridge, _near_ridge_color(), 2.0, true)
		for facet_index in _cliff_facets.size():
			draw_colored_polygon(_cliff_facets[facet_index], _cliff_facet_color(facet_index))
		_draw_cliff_arches()
		_draw_cliff_strata(0.0, 0.78)
		_draw_ridge_foam()
		draw_set_transform(Vector2.ZERO)

func _draw_harbor_landmarks(shore_offset: float) -> void:
	# One beacon tower and a few broken roof clusters give the far shore scale.
	var lighthouse_x := 81.0 + shore_offset
	var lighthouse_y := 470.0
	draw_set_transform(Vector2(lighthouse_x, lighthouse_y))
	draw_colored_polygon(_lighthouse_body, Color("#d9c69e"))
	draw_colored_polygon(_lighthouse_roof, Color(CORAL, 0.94))
	draw_colored_polygon(_lighthouse_lantern, Color("#f0d49b"))
	draw_line(Vector2(5, -44), Vector2(21, -44), Color(INK, 0.66), 1.2)
	draw_rect(Rect2(9.0, -34.0, 3.0, 5.0), Color(DEEP, 0.72), true)
	draw_rect(Rect2(17.0, -28.0, 3.0, 5.0), Color(DEEP, 0.72), true)
	draw_line(Vector2(13.0, -57.0), Vector2(13.0, -68.0), Color(INK, 0.82), 1.2, true)
	draw_colored_polygon(_beacon_pennant, Color(CORAL, 0.92))
	draw_polyline(_beacon_pennant, Color(INK, 0.72), 0.9, true)
	draw_line(Vector2(4, -52), Vector2(-15, -61), Color(OCHRE, 0.48), 1.0)
	draw_line(Vector2(22, -52), Vector2(39, -60), Color(OCHRE, 0.48), 1.0)
	draw_set_transform(Vector2.ZERO)
	# Roof accents are separated into two small settlements instead of a repeated block grid.
	for roof_x in ROOF_ACCENTS:
		var roof_screen_x: float = roof_x + shore_offset
		var roof_y := 470.0 if roof_x < 300.0 else 482.0 if roof_x > 900.0 else 480.0
		draw_line(Vector2(roof_screen_x - 13.0, roof_y), Vector2(roof_screen_x, roof_y - 10.0), Color(PAPER, 0.34), 1.2, true)
		draw_line(Vector2(roof_screen_x, roof_y - 10.0), Vector2(roof_screen_x + 15.0, roof_y), Color(PAPER, 0.34), 1.2, true)
	for lamp_index in 3:
		var lx := 187.0 + float(lamp_index) * 347.0 + shore_offset
		draw_line(Vector2(lx, 483.0), Vector2(lx, 469.0), _harbor_lamp_stem(), 1.4, true)
		draw_circle(Vector2(lx, 467.0), 2.1, Color("#ffd48a") if _time_phase == "dusk" or _time_phase == "night" else Color("#f2d5a0", 0.58))
	# A single sailboat sits on the open water as a scale cue.
	var boat_x := 930.0 + shore_offset
	var boat_y := 493.0
	draw_set_transform(Vector2(boat_x, boat_y))
	draw_colored_polygon(_distant_boat, Color("#425e63", 0.66))
	draw_line(Vector2(15, -27), Vector2(15, -1), Color(PAPER, 0.74), 1.1, true)
	draw_colored_polygon(_distant_sail, Color("#ead6ae", 0.82))
	draw_set_transform(Vector2.ZERO)

func _draw_cliff_strata(_offset: float, opacity: float) -> void:
	var ink_color := Color("#f0cb8a", 0.54 * opacity) if _time_phase != "night" else Color("#b3c8c5", 0.42 * opacity)
	for line_index in 3:
		var path := _cliff_strata[line_index]
		draw_polyline(path, ink_color if line_index % 2 == 0 else Color(INK, 0.34 * opacity), 1.8 if line_index % 2 == 0 else 1.1, true)

func _draw_cliff_arches() -> void:
	var arch_ink := Color("#173a49", 0.88) if _time_phase != "night" else Color("#102c3c", 0.95)
	var arch_edge := Color("#c69c68", 0.62) if _time_phase != "night" else Color("#79999c", 0.54)
	for arch in _cliff_arches:
		draw_colored_polygon(arch, arch_ink)
		draw_polyline(arch, arch_edge, 1.6, true)

func _draw_ridge_foam() -> void:
	var edge_light := Color("#f3e2bd", 0.43) if _time_phase != "night" else Color("#a8c8c5", 0.34)
	draw_line(Vector2(82.0, 513.0), Vector2(119.0, 508.0), edge_light, 1.1, true)
	draw_line(Vector2(444.0, 516.0), Vector2(469.0, 513.0), edge_light, 1.0, true)
	draw_line(Vector2(669.0, 499.0), Vector2(704.0, 500.0), edge_light, 1.1, true)
	draw_line(Vector2(918.0, 504.0), Vector2(945.0, 505.0), edge_light, 1.0, true)

func _draw_sea_ribbons() -> void:
	var shift := -fposmod(_camera_x * 0.13, 280.0)
	var water_ink := Color("#d9e5c6", 0.34) if _time_phase != "night" else Color("#9ecac5", 0.28)
	for wave_index in 7:
		var sx := shift + float(wave_index) * 224.0 - 12.0
		var base_y := 414.0 + float((wave_index * 2) % 4) * 17.0
		draw_set_transform(Vector2(sx, base_y))
		draw_polyline(_sea_wave_paths[wave_index % _sea_wave_paths.size()], water_ink, 1.2 if wave_index % 2 == 0 else 0.9, true)
	draw_set_transform(Vector2.ZERO)

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
	var alpha := 0.98 if status == "next" else (0.86 if status == "center" else 0.76 if status == "edge" else 0.70 if status == "miss" else 0.42)
	if status == "miss":
		alpha = 0.78
	draw_set_transform(center, 0.0, Vector2(RING_HALF_DEPTH, RING_HALF_HEIGHT))
	var start_angle := -PI / 2.0 if front_half else PI / 2.0
	var end_angle := PI / 2.0 if front_half else 3.0 * PI / 2.0
	if front_half:
		if status == "next":
			draw_circle(Vector2.ZERO, 0.17, Color(SEA_GLASS, 0.12))
			draw_arc(Vector2.ZERO, 0.53, -0.18, 0.18, 18, Color(CREAM, 0.42), 0.035)
			draw_line(Vector2(-0.17, 0), Vector2(0.17, 0), Color(PAPER, 0.48), 0.018, true)
	var face_color := Color(color, alpha) if front_half else Color(color.darkened(0.34), alpha * 0.9)
	var cord_shadow := Color(INK, alpha * (0.92 if front_half else 0.78))
	draw_arc(Vector2.ZERO, 0.91, start_angle, end_angle, 40, cord_shadow, 0.19)
	draw_arc(Vector2.ZERO, 0.88, start_angle, end_angle, 40, face_color, 0.105)
	draw_arc(Vector2.ZERO, 0.82, start_angle, end_angle, 40, Color(CREAM, alpha * (0.72 if front_half else 0.34)), 0.035)
	draw_arc(Vector2.ZERO, 0.71, start_angle, end_angle, 40, Color(INK, alpha * 0.20), 0.025)
	if status == "edge" and front_half:
		for tick in 3:
			var tick_y := -0.14 + float(tick) * 0.14
			draw_line(Vector2(0.71, tick_y), Vector2(0.98, tick_y + 0.06), Color(OCHRE, 0.92), 0.035, true)
	elif status == "miss" and front_half:
		draw_line(Vector2(0.67, -0.16), Vector2(0.96, -0.02), Color(CORAL, 0.96), 0.045, true)
		draw_line(Vector2(0.66, 0.12), Vector2(0.91, 0.27), Color(CORAL, 0.96), 0.045, true)
	if front_half and status == "center":
		draw_arc(Vector2.ZERO, 0.94, -0.16, 0.16, 12, Color(TIDAL, 0.82), 0.055)
	if front_half:
		for rivet in 5:
			var rivet_angle := -1.0 + float(rivet) * 0.5
			var rivet_alpha := 0.86 if status == "next" else 0.48
			draw_circle(Vector2(cos(rivet_angle), sin(rivet_angle)) * 0.88, 0.032, Color(CREAM, rivet_alpha))
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
	var day_tint := Color(INK, 0.8)
	if _phase == "results" or _phase == "ended":
		label = "航程完成"
	if _event == "miss":
		label = "環口未通過　回到航線再試"
		day_tint = CORAL
	elif _event == "edge":
		label = "擦過環緣　收穩風箏"
		day_tint = OCHRE
	elif _event == "center":
		label = "穿越環心"
		day_tint = SEA_GLASS
	elif _event == "line_snap":
		label = "線張力過高　風箏已復位"
		day_tint = CORAL
	var backplate := _flight_caption_backplate_color(_time_phase)
	if backplate.a > 0.0:
		draw_rect(Rect2(82.0, 153.0, 332.0, 30.0), backplate, true)
	var tint := _flight_caption_color(_time_phase, _phase, _event, day_tint)
	draw_string(FontProfiles.current_font(), Vector2(91.0, 174.0), label, HORIZONTAL_ALIGNMENT_LEFT, 300.0, 15, tint)

func _flight_caption_backplate_color(time_phase: String) -> Color:
	if time_phase == "dusk" or time_phase == "night":
		return Color("#172d41", 0.96)
	return Color(INK, 0.0)

func _flight_caption_color(time_phase: String, flight_phase: String, event: String, day_tint: Color) -> Color:
	if time_phase != "dusk" and time_phase != "night":
		return day_tint
	# Apply the same readable event palette during active play and the Session's
	# singular "result" phase; daytime event colors above remain byte-identical.
	var is_caption_phase := flight_phase == "playing" or flight_phase == "paused" or flight_phase == "result" or flight_phase == "results" or flight_phase == "ended"
	if not is_caption_phase:
		return day_tint
	match event:
		"miss", "line_snap": return Color("#ffd6cf")
		"edge": return Color("#ffe1ad")
		"center": return Color("#d6f2e8")
		_: return Color("#fff7e5")

func _draw_bottom_instruments() -> void:
	draw_rect(Rect2(80.0, 637.0, 1120.0, 71.0), Color(_instrument_bg(), 0.94), true)
	draw_line(Vector2(80.0, 637.0), Vector2(1200.0, 637.0), Color(PAPER, 0.52), 1.0)
	draw_string(FontProfiles.current_font(), Vector2(98.0, 660.0), "現風", HORIZONTAL_ALIGNMENT_LEFT, 70.0, 14, _instrument_text())
	_draw_actual_wind(Vector2(177.0, 668.0), _actual_wind)
	draw_string(FontProfiles.current_font(), Vector2(358.0, 660.0), "1.25 秒後", HORIZONTAL_ALIGNMENT_LEFT, 115.0, 14, _instrument_text())
	_draw_forecast_wind(Vector2(468.0, 668.0), _forecast_wind)
	draw_string(FontProfiles.current_font(), Vector2(642.0, 660.0), "線張力", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, _instrument_text())
	_draw_tension_gauge()
	draw_string(FontProfiles.current_font(), Vector2(883.0, 660.0), "收線減壓" if _tension_warning else "衝刺看線", HORIZONTAL_ALIGNMENT_LEFT, 118.0, 14, _warning_text())
	draw_string(FontProfiles.current_font(), Vector2(1024.0, 660.0), "備線", HORIZONTAL_ALIGNMENT_LEFT, 56.0, 14, _instrument_text())
	for rescue_index in 2:
		var dot := Vector2(1092.0 + float(rescue_index) * 34.0, 657.0)
		var used := rescue_index < _rescues_used
		draw_circle(dot, 7.0, Color(CORAL if used else OCHRE, 0.84))
		draw_arc(dot, 8.5, 0.0, TAU, 20, Color(PAPER, 0.92), 1.5)
		if not used:
			draw_line(dot + Vector2(-3, 0), dot + Vector2(3, 0), Color(CREAM, 0.9), 1.3)
	draw_string(FontProfiles.current_font(), Vector2(96.0, 692.0), "↑↓迎風　短按衝刺　收線降張力　↑氣流升高", HORIZONTAL_ALIGNMENT_LEFT, 450.0, 12, Color(_instrument_text(), 0.82))
	draw_string(FontProfiles.current_font(), Vector2(700.0, 692.0), "五枚風環　中心最穩", HORIZONTAL_ALIGNMENT_LEFT, 280.0, 12, Color(_instrument_text(), 0.82))

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
		_: return Color("#c2d0bf")

func _tail_color(index: int) -> Color:
	match index % 3:
		0: return CORAL
		1: return Color("#e3bd72")
		_: return TIDAL

func _sky_color() -> Color:
	match _time_phase:
		"dawn": return Color("#e0b094")
		"dusk": return Color("#8f7894")
		"night": return Color("#294965")
		_: return Color("#86c8d0")

func _horizon_color() -> Color:
	match _time_phase:
		"dawn": return Color("#f4c69b")
		"dusk": return Color("#e3977b")
		"night": return Color("#536d84")
		_: return Color("#e4d5a6")

func _sea_color() -> Color:
	match _time_phase:
		"dawn": return Color("#6aa5a5")
		"dusk": return Color("#596f87")
		"night": return Color("#30536b")
		_: return Color("#58a0a5")

func _harbor_color() -> Color:
	match _time_phase:
		"dawn": return Color("#8a776b")
		"dusk": return Color("#6c6374")
		"night": return Color("#304d61")
		_: return Color("#827566")

func _far_cliff_color() -> Color:
	match _time_phase:
		"dawn": return Color("#70878c")
		"dusk": return Color("#5c667b")
		"night": return Color("#315165")
		_: return Color("#5c8585")

func _far_ridge_color() -> Color:
	return Color("#c6b48f", 0.54) if _time_phase != "night" else Color("#a6b5b9", 0.42)

func _near_cliff_color() -> Color:
	match _time_phase:
		"dawn": return Color("#3b6268")
		"dusk": return Color("#404b65")
		"night": return Color("#203d53")
		_: return Color("#315e68")

func _near_ridge_color() -> Color:
	return Color("#dfc18c", 0.64) if _time_phase != "night" else Color("#9bb6b9", 0.50)

func _cliff_facet_color(index: int) -> Color:
	if _time_phase == "night":
		return Color("#294b63") if index % 2 == 0 else Color("#365e70")
	if _time_phase == "dusk":
		return Color("#56546a") if index % 2 == 0 else Color("#70566c")
	return Color("#3b6c70") if index % 2 == 0 else Color("#507f78")

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
