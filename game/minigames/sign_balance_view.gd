extends Control
class_name SignBalanceView

signal balance_requested(value: float)

const FONT: FontFile = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const HUD_SAFE_RECT := Rect2(34.0, 18.0, 1212.0, 112.0)
const SCENE_BOUNDS := Rect2(56.0, 136.0, 1168.0, 570.0)
const STAGE_CARD_BOUNDS := Rect2(476.0, 145.0, 328.0, 72.0)
const CONTROLS_PANEL := Rect2(324.0, 502.0, 632.0, 204.0)
const BOARD_CENTER := Vector2(640.0, 326.0)
const BOARD_SIZE := Vector2(560.0, 184.0)
const AXLE_CENTER := BOARD_CENTER
const ANGLE_GAUGE := Rect2(412.0, 546.0, 456.0, 28.0)
const WEIGHT_RAIL := Rect2(430.0, 621.0, 420.0, 28.0)
const STATUS_LINE_BOUNDS := Rect2(356.0, 658.0, 564.0, 18.0)
const INPUT_HELP_BOUNDS := Rect2(356.0, 682.0, 564.0, 18.0)
const SAFE_DWELL_SECONDS := 0.52
const BOARD_CORNER_X: Array[float] = [-247.0, 247.0]
const BOARD_CORNER_Y: Array[float] = [-74.0, 74.0]
const BOARD_PIVOT_SIDES: Array[float] = [-1.0, 1.0]
const PALETTE_DAWN: Array[Color] = [Color("#c9d4d8"), Color("#8caeb7"), Color("#263f50"), Color("#f1c88f"), Color("#b96f59"), Color("#344e5a"), Color("#f1e2c8")]
const PALETTE_NOON: Array[Color] = [Color("#dce7dc"), Color("#9fc2bb"), Color("#183b49"), Color("#f5dfa1"), Color("#bd7449"), Color("#31575e"), Color("#f1f0dc")]
const PALETTE_DUSK: Array[Color] = [Color("#cfb7a1"), Color("#819aa3"), Color("#243a4b"), Color("#ebc277"), Color("#c3754e"), Color("#493f4c"), Color("#f0dec0")]
const PALETTE_NIGHT: Array[Color] = [Color("#354855"), Color("#5f8990"), Color("#172d3a"), Color("#e0c275"), Color("#d07d63"), Color("#233f4b"), Color("#dce3d4")]

var _snapshot: Dictionary = {}
var _time_of_day := "noon"
var _reduced_motion := false
var _dragging := false

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL

func update_frame(snapshot: Dictionary, time_of_day: String = "noon", reduced_motion: bool = false) -> void:
	_snapshot = snapshot
	_time_of_day = time_of_day if time_of_day == "dawn" or time_of_day == "noon" or time_of_day == "dusk" or time_of_day == "night" else "noon"
	_reduced_motion = reduced_motion
	queue_redraw()

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

func palette_phase() -> String:
	return _time_of_day

func sky_color() -> Color:
	if _time_of_day == "dawn":
		return PALETTE_DAWN[0]
	if _time_of_day == "dusk":
		return PALETTE_DUSK[0]
	if _time_of_day == "night":
		return PALETTE_NIGHT[0]
	return PALETTE_NOON[0]

func physical_motion_enabled() -> bool:
	return true

func decorative_motion_enabled() -> bool:
	return not _reduced_motion

func scene_bounds() -> Rect2:
	return SCENE_BOUNDS

func pivot_position() -> Vector2:
	return AXLE_CENTER

func hud_safe_rect() -> Rect2:
	return HUD_SAFE_RECT

func target_zone_bounds() -> Rect2:
	return ANGLE_GAUGE

func controls_panel_bounds() -> Rect2:
	return CONTROLS_PANEL

func stage_card_bounds() -> Rect2:
	return STAGE_CARD_BOUNDS

func projected_sign_bounds(snapshot: Dictionary = {}) -> Rect2:
	var rotation := visual_angle(snapshot)
	var cosine := cos(rotation)
	var sine := sin(rotation)
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	# Include the deeper backing board (offset downward), pivot end caps, and AA fringe.
	var local_points: Array[Vector2] = [
		Vector2(-280.0, -92.0), Vector2(280.0, -92.0),
		Vector2(-280.0, 106.0), Vector2(280.0, 106.0),
		Vector2(-294.0, -18.0), Vector2(-258.0, -18.0),
		Vector2(258.0, -18.0), Vector2(294.0, -18.0),
		Vector2(-294.0, 18.0), Vector2(-258.0, 18.0),
		Vector2(258.0, 18.0), Vector2(294.0, 18.0),
	]
	for point in local_points:
		var projected := BOARD_CENTER + Vector2(point.x * cosine - point.y * sine, point.x * sine + point.y * cosine)
		min_point = min_point.min(projected)
		max_point = max_point.max(projected)
	min_point -= Vector2(2.0, 2.0)
	max_point += Vector2(2.0, 2.0)
	return Rect2(min_point, max_point - min_point)

func wind_arrow_visible(snapshot: Dictionary = {}) -> bool:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	var torque := float(state.get("forecast_torque", 0.0)) if bool(state.get("forecast_visible", false)) else float(state.get("wind_torque", 0.0))
	return absf(torque) >= 0.035

func wind_display_label(snapshot: Dictionary = {}) -> String:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	if bool(state.get("forecast_visible", false)):
		return "預告風"
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
	if _time_of_day == "dawn":
		palette = PALETTE_DAWN
	if _time_of_day == "dusk":
		palette = PALETTE_DUSK
	elif _time_of_day == "night":
		palette = PALETTE_NIGHT
	var sky: Color = sky_color()
	var sea: Color = palette[1]
	var ink: Color = palette[2]
	var brass: Color = palette[3]
	var terracotta: Color = palette[4]
	var wood: Color = palette[5]
	var paper: Color = palette[6]
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), sky)
	_draw_harbor_horizon(sea, ink, wood, paper, terracotta)
	_draw_forecast(ink, brass, terracotta, paper)
	_draw_pier_support(ink, brass, wood, paper)
	_draw_sign(ink, brass, terracotta, paper)
	_draw_controls_panel(paper, brass, ink)
	_draw_balance_gauges(ink, brass, terracotta, paper)
	_draw_round_marks(ink, brass, paper)

func _draw_harbor_horizon(sea: Color, ink: Color, wood: Color, paper: Color, terracotta: Color) -> void:
	draw_rect(Rect2(0.0, 426.0, DESIGN_SIZE.x, 294.0), sea)
	# Two low shore silhouettes frame the fixed sign and establish a real harbor horizon.
	var left_shore := PackedVector2Array([Vector2(0, 412), Vector2(72, 391), Vector2(136, 398), Vector2(202, 376), Vector2(282, 404), Vector2(360, 408), Vector2(360, 432), Vector2(0, 432)])
	var right_shore := PackedVector2Array([Vector2(920, 408), Vector2(1004, 390), Vector2(1070, 399), Vector2(1142, 372), Vector2(1222, 396), Vector2(1280, 386), Vector2(1280, 432), Vector2(920, 432)])
	draw_colored_polygon(left_shore, sea.darkened(0.17))
	draw_colored_polygon(right_shore, sea.darkened(0.15))
	_draw_lighthouse(ink, paper, terracotta)
	_draw_harbor_boat(ink, paper, terracotta)
	draw_line(Vector2(0.0, 430.0), Vector2(1280.0, 430.0), paper.darkened(0.10), 2.0)
	# A quiet water surface gives the pier a clear depth cue without lines behind controls.
	for wave in [[Vector2(92, 452), Vector2(220, 452)], [Vector2(1008, 449), Vector2(1194, 449)], [Vector2(104, 480), Vector2(274, 480)], [Vector2(984, 479), Vector2(1190, 479)]]:
		draw_line(wave[0], wave[1], Color(paper, 0.40), 2.0)
	# Timber pier cap and its front fascia stop above the dedicated control panel.
	draw_rect(Rect2(0.0, 482.0, 1280.0, 10.0), wood.darkened(0.12))
	draw_rect(Rect2(0.0, 492.0, 1280.0, 9.0), wood.lightened(0.12))
	draw_line(Vector2(0.0, 482.0), Vector2(1280.0, 482.0), paper.darkened(0.16), 2.0)
	for seam_x in [92.0, 240.0, 1040.0, 1185.0]:
		draw_line(Vector2(seam_x, 484.0), Vector2(seam_x, 499.0), ink, 2.0)

func _draw_lighthouse(ink: Color, paper: Color, terracotta: Color) -> void:
	# Familiar tapered tower and beacon light stay to the left of the rotating board.
	draw_colored_polygon(PackedVector2Array([Vector2(84, 414), Vector2(102, 386), Vector2(162, 386), Vector2(183, 414)]), ink.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(111, 389), Vector2(119, 333), Vector2(148, 333), Vector2(158, 389)]), paper.darkened(0.12))
	draw_rect(Rect2(116, 346, 38, 13), terracotta)
	draw_rect(Rect2(119, 329, 29, 8), ink)
	draw_rect(Rect2(123, 314, 21, 15), terracotta.lightened(0.12))
	draw_rect(Rect2(119, 310, 29, 5), ink)
	draw_circle(Vector2(133, 321), 4.0, Color("#ffe6a8"))
	draw_rect(Rect2(104, 386, 62, 5), ink.darkened(0.12))

func _draw_harbor_boat(ink: Color, paper: Color, terracotta: Color) -> void:
	# Small moored sailboat, mast and folded sail make the right shore read as a quay.
	draw_colored_polygon(PackedVector2Array([Vector2(1040, 416), Vector2(1198, 416), Vector2(1176, 438), Vector2(1070, 438)]), ink.darkened(0.10))
	draw_line(Vector2(1124, 365), Vector2(1124, 416), ink, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(1119, 369), Vector2(1072, 407), Vector2(1119, 407)]), paper)
	draw_colored_polygon(PackedVector2Array([Vector2(1129, 377), Vector2(1165, 407), Vector2(1129, 407)]), terracotta.lightened(0.10))
	draw_line(Vector2(1060, 442), Vector2(1204, 442), paper.darkened(0.08), 2.0)

func _draw_forecast(ink: Color, brass: Color, terracotta: Color, paper: Color) -> void:
	var direction := int(_snapshot.get("wind_direction", 1))
	var forecast: float = float(_snapshot.get("forecast_torque", 0.0))
	var visible := bool(_snapshot.get("forecast_visible", false)) and not bool(_snapshot.get("ended", false))
	var marker_x := 984.0
	draw_round_rect(Rect2(858.0, 148.0, 330.0, 76.0), 11.0, paper.darkened(0.04))
	draw_rect(Rect2(858.0, 148.0, 5.0, 76.0), brass)
	var label := str(_snapshot.get("wind_kind", "港風"))
	_label(Vector2(878.0, 171.0), label, ink, HORIZONTAL_ALIGNMENT_LEFT, 126, 16)
	var torque := forecast if visible else float(_snapshot.get("wind_torque", 0.0))
	var arrow_visible := absf(torque) >= 0.035
	var arrow_dir := -1 if torque < 0.0 else 1
	var arrow_color := terracotta if torque < 0.0 else brass
	_label(Vector2(878.0, 198.0), "預告風" if visible else ("當前風" if arrow_visible else "靜風"), ink.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, 86, 12)
	if arrow_visible:
		var arrow_length := lerpf(24.0, 51.0, clampf(absf(torque) / 0.28, 0.0, 1.0))
		var arrow_from := Vector2(marker_x + (arrow_length if arrow_dir < 0 else 0.0), 185.0)
		var arrow_to := Vector2(marker_x + (0.0 if arrow_dir < 0 else arrow_length), 185.0)
		draw_line(arrow_from, arrow_to, arrow_color, 5.0)
		draw_line(arrow_to, arrow_to + Vector2(-9.0 * arrow_dir, -7.0), arrow_color, 3.0)
		draw_line(arrow_to, arrow_to + Vector2(-9.0 * arrow_dir, 7.0), arrow_color, 3.0)
	# Pennant silhouette varies by wind kind; arrow and label make direction independent of color.
	var flag_x := 1085.0
	var flag_color := arrow_color
	draw_line(Vector2(flag_x, 163.0), Vector2(flag_x, 210.0), ink, 2.0)
	if not arrow_visible:
		draw_line(Vector2(flag_x, 174.0), Vector2(flag_x + 16.0, 174.0), ink.darkened(0.1), 3.0)
	elif str(_snapshot.get("wind_kind", "")) == "穿堂陣風":
		draw_line(Vector2(flag_x, 165.0), Vector2(flag_x + 47.0 * arrow_dir, 175.0), flag_color, 5.0)
		draw_line(Vector2(flag_x + 47.0 * arrow_dir, 175.0), Vector2(flag_x, 188.0), flag_color, 5.0)
		draw_line(Vector2(flag_x, 188.0), Vector2(flag_x, 165.0), flag_color, 3.0)
	else:
		draw_line(Vector2(flag_x, 166.0), Vector2(flag_x + 42.0 * arrow_dir, 180.0), flag_color, 6.0)
		draw_line(Vector2(flag_x + 42.0 * arrow_dir, 180.0), Vector2(flag_x + 70.0 * arrow_dir, 168.0), flag_color, 4.0)
	var seconds := float(_snapshot.get("forecast_seconds", 0.0))
	var torque_strength := absf(torque)
	_label(Vector2(1131.0, 194.0), "%.1fs" % seconds if visible else ("×%.2f" % torque_strength if arrow_visible else "平靜"), ink, HORIZONTAL_ALIGNMENT_LEFT, 64, 13)

func _draw_pier_support(ink: Color, brass: Color, wood: Color, paper: Color) -> void:
	# Layered upright, twin braces and a brass seat show how the sign carries load to the pier.
	draw_rect(Rect2(600.0, 344.0, 80.0, 154.0), ink.darkened(0.05))
	draw_rect(Rect2(610.0, 349.0, 27.0, 145.0), wood.lightened(0.12))
	draw_rect(Rect2(644.0, 349.0, 24.0, 145.0), wood.darkened(0.05))
	draw_line(Vector2(603.0, 449.0), Vector2(559.0, 493.0), brass, 9.0)
	draw_line(Vector2(677.0, 449.0), Vector2(721.0, 493.0), brass, 9.0)
	draw_line(Vector2(603.0, 449.0), Vector2(559.0, 493.0), paper, 2.0)
	draw_line(Vector2(677.0, 449.0), Vector2(721.0, 493.0), paper, 2.0)
	draw_rect(Rect2(548.0, 492.0, 184.0, 10.0), ink)
	draw_rect(Rect2(562.0, 497.0, 156.0, 5.0), brass)
	for bolt in [Vector2(608, 461), Vector2(672, 461), Vector2(570, 489), Vector2(710, 489)]:
		draw_circle(bolt, 4.0, brass.lightened(0.14))

func _draw_sign(ink: Color, brass: Color, terracotta: Color, paper: Color) -> void:
	var state_angle := visual_angle()
	var center := BOARD_CENTER
	var half := BOARD_SIZE * 0.5
	var wood_color := Color("#684c3c")
	var face := Color("#ead8b5")
	var trim := Color("#b98552")
	var text_color := Color("#253a43")
	# Ground shadow responds to the physical sign angle, without moving the camera.
	var shadow := center + shadow_offset()
	draw_set_transform(shadow, 0.0, Vector2(1.0, 0.20))
	draw_circle(Vector2.ZERO, 235.0 + absf(float(_snapshot.get("angle", 0.0))) * 22.0, Color(ink.r, ink.g, ink.b, 0.21))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(center, state_angle, Vector2.ONE)
	draw_rect(Rect2(-half.x, -half.y + 14.0, BOARD_SIZE.x, BOARD_SIZE.y), wood_color)
	draw_rect(Rect2(-half.x, -half.y, BOARD_SIZE.x, BOARD_SIZE.y), trim)
	draw_rect(Rect2(-half.x + 9.0, -half.y + 9.0, BOARD_SIZE.x - 18.0, BOARD_SIZE.y - 18.0), face)
	draw_rect(Rect2(-half.x + 20.0, -half.y + 20.0, BOARD_SIZE.x - 40.0, BOARD_SIZE.y - 40.0), ink.darkened(0.04), false, 2.0)
	# A few routed grain channels and brass corner caps give the timber depth.
	for x in BOARD_CORNER_X:
		for y in BOARD_CORNER_Y:
			draw_circle(Vector2(x, y), 5.0, brass)
	for y in [-69.0, 69.0]:
		draw_line(Vector2(-235.0, y), Vector2(-215.0, y), Color(wood_color.r, wood_color.g, wood_color.b, 0.26), 2.0)
		draw_line(Vector2(215.0, y), Vector2(235.0, y), Color(wood_color.r, wood_color.g, wood_color.b, 0.26), 2.0)
	# End caps sit on the horizontal pivot line, visually joining the sign to the post.
	for side in BOARD_PIVOT_SIDES:
		draw_circle(Vector2(side * (half.x - 4.0), 0.0), 18.0, ink)
		draw_circle(Vector2(side * (half.x - 4.0), 0.0), 12.0, brass)
		draw_circle(Vector2(side * (half.x - 4.0), 0.0), 5.0, ink.darkened(0.12))
	# Central maker's badge remains legible inside the face at the full 1280px design size.
	draw_circle(Vector2(-202.0, -24.0), 27.0, Color("#c1754c"))
	draw_circle(Vector2(-202.0, -24.0), 21.0, Color("#edd29b"))
	draw_circle(Vector2(-202.0, -24.0), 6.0, Color("#c1754c"))
	draw_arc(Vector2(-202.0, -24.0), 15.0, PI * 0.12, PI * 0.88, 16, Color("#31575e"), 3.0)
	_label(Vector2(-4.0, -7.0), "潮汐花園", text_color, HORIZONTAL_ALIGNMENT_CENTER, 320, 24)
	_label(Vector2(-4.0, 17.0), "HARBOR GARDEN", text_color.darkened(0.12), HORIZONTAL_ALIGNMENT_CENTER, 220, 11)
	var stage_number := int(_snapshot.get("stage_number", 1))
	var target := float(_snapshot.get("target_angle", 0.0))
	var level_text := "水平記號" if absf(target) < 0.01 else ("微向左" if target < 0.0 else "微向右")
	_label(Vector2(-4.0, 62.0), str(stage_number) + " / 7   ·   " + level_text, text_color.darkened(0.12), HORIZONTAL_ALIGNMENT_CENTER, 280, 13)
	if bool(_snapshot.get("success", false)):
		_draw_success_rosette(Vector2(230.0, -52.0), brass, terracotta, paper)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_success_rosette(position: Vector2, brass: Color, terracotta: Color, paper: Color) -> void:
	draw_circle(position, 25.0, brass)
	draw_circle(position, 19.0, paper)
	draw_circle(position, 12.0, terracotta)
	draw_line(position + Vector2(-7.0, 1.0), position + Vector2(-2.0, 7.0), paper, 3.0)
	draw_line(position + Vector2(-2.0, 7.0), position + Vector2(9.0, -7.0), paper, 3.0)

func _draw_balance_gauges(ink: Color, brass: Color, terracotta: Color, paper: Color) -> void:
	var target := float(_snapshot.get("target_angle", 0.0))
	var angle_value := float(_snapshot.get("angle", 0.0))
	var safe_limit := float(_snapshot.get("safe_limit", 0.13))
	var precise_limit := float(_snapshot.get("precise_limit", 0.055))
	var scale_left := 412.0
	var scale_width := 456.0
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
	var event_text := str(_snapshot.get("last_event", "先看風旗預告，再微調配重"))
	_label(Vector2(356.0, 672.0), event_text, ink, HORIZONTAL_ALIGNMENT_CENTER, 564, 13)
	_label(Vector2(356.0, 696.0), "按住方向鍵移動配重　·　拖曳滑軌微調", ink.darkened(0.08), HORIZONTAL_ALIGNMENT_CENTER, 564, 13)

func _draw_controls_panel(paper: Color, brass: Color, ink: Color) -> void:
	draw_round_rect(CONTROLS_PANEL, 13.0, paper)
	draw_rect(CONTROLS_PANEL, Color(ink, 0.72), false, 2.0)
	draw_rect(Rect2(CONTROLS_PANEL.position, Vector2(7.0, CONTROLS_PANEL.size.y)), brass)

func _draw_round_marks(ink: Color, brass: Color, paper: Color) -> void:
	var score_value := int(_snapshot.get("score", 0))
	draw_round_rect(Rect2(82.0, 152.0, 128.0, 68.0), 8.0, paper.darkened(0.03))
	_label(Vector2(98.0, 177.0), "平衡章", ink, HORIZONTAL_ALIGNMENT_LEFT, 96, 13)
	_label(Vector2(98.0, 204.0), "%03d" % score_value, brass.darkened(0.32), HORIZONTAL_ALIGNMENT_LEFT, 92, 22)
	draw_round_rect(STAGE_CARD_BOUNDS, 9.0, paper.darkened(0.03))
	draw_rect(STAGE_CARD_BOUNDS, Color(ink, 0.72), false, 2.0)
	draw_rect(Rect2(STAGE_CARD_BOUNDS.position, Vector2(6.0, STAGE_CARD_BOUNDS.size.y)), brass)
	var stage := int(_snapshot.get("stage", 0))
	var stable_ratio := clampf(float(_snapshot.get("stable_seconds", 0.0)) / SAFE_DWELL_SECONDS, 0.0, 1.0)
	_label(Vector2(508.0, 165.0), "風段 " + str(mini(stage + 1, 7)) + "  ·  " + str(_snapshot.get("wind_kind", "海風")), ink, HORIZONTAL_ALIGNMENT_CENTER, 264, 14)
	draw_rect(Rect2(551.0, 177.0, 178.0, 5.0), paper.darkened(0.1))
	draw_rect(Rect2(551.0, 177.0, 178.0 * stable_ratio, 5.0), brass)
	var forecast_visible := bool(_snapshot.get("forecast_visible", false))
	var forecast_seconds := float(_snapshot.get("forecast_seconds", 0.0))
	var message := str(_snapshot.get("last_event", ""))
	if forecast_visible:
		message = "%.1f 秒後受風　預先移到風向反側" % forecast_seconds
	elif message.is_empty():
		message = "把牌角穩在中央亮帶，預先抵住來風"
	_label(Vector2(463.0, 205.0), message, ink, HORIZONTAL_ALIGNMENT_CENTER, 356, 12)

func draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	# Rounded plate assembled from built-in shapes; no textures or per-frame nodes.
	draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2.0), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)

func _label(position: Vector2, text: String, color: Color, alignment: HorizontalAlignment, width: int, size: int) -> void:
	draw_string(FONT, position, text, alignment, width, size, color)
