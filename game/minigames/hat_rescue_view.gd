extends Control
class_name HatRescueView

signal axis_requested(value: float)
signal target_x_requested(value: float)
signal catch_requested(pressed: bool)

const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const HatRescueModelScript = preload("res://game/minigames/hat_rescue_model.gd")
const FONT: FontFile = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const PLAY_BOUNDS := Rect2(48.0, 136.0, 1184.0, 548.0)
const HUD_SAFE_RECT := Rect2(34.0, 18.0, 1212.0, 112.0)
const PLAYER_RAIL := Rect2(126.0, 530.0, 1028.0, 22.0)
const CATCH_LINE_Y := 518.0
const PLAYER_GROUND_Y := 638.0
const PLAYER_DRAW_SIZE := Vector2(126.0, 162.0)
const WALK_CYCLE_DISTANCE := PLAYER_DRAW_SIZE.x * 0.9
const CATCH_LINE_MARKS: Array[float] = [182.0, 326.0, 470.0, 614.0, 758.0, 902.0, 1046.0]
const CHARACTER_RENDER_BOUNDS := Rect2(113.0, 452.0, 1054.0, 190.0)
const HAT_RENDER_BOUNDS := Rect2(96.0, 136.0, 1088.0, 432.0)
const STAGE_BOUNDS := Rect2(0.0, 136.0, 1280.0, 584.0)
const HAT_FILLS: Array[Color] = [Color("#d7ad67"), Color("#527b91"), Color("#e08268"), Color("#827460"), Color("#b87752"), Color("#527f78")]
const HAT_TRIMS: Array[Color] = [Color("#f0d99f"), Color("#f0e6d2"), Color("#f4d8a3"), Color("#b8a486"), Color("#e3bb78"), Color("#f0dfbf")]
const FAR_WAVE_X: Array[float] = [54.0, 440.0, 704.0, 1210.0]
const PLANK_SEAMS: Array[float] = [78.0, 250.0, 446.0, 628.0, 820.0, 1015.0, 1202.0]
const ROPE_POSTS: Array[float] = [94.0, 1186.0]
const PALETTE_DAWN: Array[Color] = [Color("#d8a98a"), Color("#5d9ca7"), Color("#253d4b"), Color("#d7a754"), Color("#e0846d"), Color("#927052"), Color("#eedfc3"), Color("#63868a")]
const PALETTE_NOON: Array[Color] = [Color("#b9d3cf"), Color("#5faab4"), Color("#1e4050"), Color("#e4bd69"), Color("#dd8069"), Color("#745640"), Color("#f1e7ce"), Color("#77958d")]
const PALETTE_DUSK: Array[Color] = [Color("#c98f82"), Color("#4e8797"), Color("#293948"), Color("#d4a556"), Color("#d97662"), Color("#674d43"), Color("#e9d8bb"), Color("#66828a")]
const PALETTE_NIGHT: Array[Color] = [Color("#405669"), Color("#356875"), Color("#1c303f"), Color("#d6bd76"), Color("#c97869"), Color("#443d43"), Color("#d8d8c8"), Color("#526f77")]

var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _left_down := false
var _right_down := false
var _renderer: RefCounted
var _idle_texture: Texture2D
var _catch_frames: Array[Texture2D] = []
var _catch_fps := 0.0
var _visual_catch_elapsed := 0.0
var _visual_catch_active := false
var _last_model_elapsed := -1.0
var _last_catch_pose := 0.0
var _last_player_x := NAN
var _walk_distance := 0.0
var _left_walk: Array[Texture2D] = []
var _right_walk: Array[Texture2D] = []
var _appearance: Dictionary = {"skin": "warm", "species": "human", "gender": "neutral", "hair": "windswept", "hair_color": "ink", "face": "curious"}
var _equipped: Dictionary = {"outfit": "outfit-tide", "hat": "hat-none"}

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
	_refresh_avatar_textures()

func configure_avatar(appearance: Dictionary, equipped: Dictionary) -> void:
	_appearance = appearance.duplicate(true)
	_equipped = equipped.duplicate(true)
	_refresh_avatar_textures()
	queue_redraw()

func update_frame(snapshot: Dictionary, time_phase: String = "noon", reduced_motion: bool = false) -> void:
	var previous_pose := _last_catch_pose
	var model_elapsed := float(snapshot.get("elapsed", _last_model_elapsed))
	var clock_rewound := is_finite(model_elapsed) and _last_model_elapsed >= 0.0 and model_elapsed < _last_model_elapsed
	if clock_rewound:
		# A Session retry rewinds the model clock and clears catch_pose; discard its old one-shot.
		_visual_catch_elapsed = 0.0
		_visual_catch_active = false
		_walk_distance = 0.0
		_last_player_x = NAN
		previous_pose = 0.0
	var player_x := float(snapshot.get("player_x", NAN))
	if is_finite(player_x):
		if is_finite(_last_player_x) and not clock_rewound and is_finite(model_elapsed) and model_elapsed > _last_model_elapsed:
			# One authored 8-frame cycle spans roughly one drawn body width; accumulate only actual model travel.
			_walk_distance += minf(absf(player_x - _last_player_x), WALK_CYCLE_DISTANCE)
		_last_player_x = player_x
	if is_finite(model_elapsed) and _last_model_elapsed >= 0.0 and model_elapsed >= _last_model_elapsed:
		if _visual_catch_active:
			_visual_catch_elapsed += minf(model_elapsed - _last_model_elapsed, 0.1)
	if float(snapshot.get("catch_pose", 0.0)) > 0.0 and previous_pose <= 0.0:
		_visual_catch_elapsed = 0.0
		_visual_catch_active = not _catch_frames.is_empty()
	if _visual_catch_active and _catch_fps > 0.0 and _visual_catch_elapsed >= float(_catch_frames.size()) / _catch_fps:
		_visual_catch_active = false
	_last_model_elapsed = model_elapsed if is_finite(model_elapsed) else _last_model_elapsed
	_snapshot = snapshot
	_last_catch_pose = float(snapshot.get("catch_pose", 0.0))
	_time_phase = _normalize_phase(time_phase)
	_reduced_motion = reduced_motion
	queue_redraw()

func clear_held_directions() -> void:
	_left_down = false
	_right_down = false

func stage_bounds() -> Rect2:
	return STAGE_BOUNDS

func play_bounds() -> Rect2:
	return PLAY_BOUNDS

func hud_safe_rect() -> Rect2:
	return HUD_SAFE_RECT

func catch_line_y() -> float:
	return CATCH_LINE_Y

func geometry_bounds() -> Rect2:
	# The scene paint reaches both canvas edges on the boardwalk and the full reserved vertical stage.
	return STAGE_BOUNDS

func time_palette_phase() -> String:
	return _time_phase

func sky_color() -> Color:
	if _time_phase == "dawn":
		return PALETTE_DAWN[0]
	if _time_phase == "dusk":
		return PALETTE_DUSK[0]
	if _time_phase == "night":
		return PALETTE_NIGHT[0]
	return PALETTE_NOON[0]

func decorative_motion_enabled() -> bool:
	return not _reduced_motion

func trajectory_motion_enabled() -> bool:
	return true

func wind_glyph() -> String:
	var direction := int(_snapshot.get("forecast_direction", 0)) if bool(_snapshot.get("forecast_visible", false)) else int(_snapshot.get("wind_direction", 0))
	return "←" if direction < 0 else "→" if direction > 0 else "↔"

func visible_hat_angle(hat: Dictionary) -> float:
	return 0.0 if _reduced_motion else float(hat.get("rotation", 0.0))

func authored_catch_frame_count() -> int:
	return _catch_frames.size()

func authored_catch_frame_rate() -> float:
	return _catch_fps

func visible_walk_frame_index() -> int:
	if visible_catch_frame_index() >= 0:
		return -1
	var velocity := float(_snapshot.get("player_velocity", 0.0))
	var frames: Array[Texture2D] = _right_walk if velocity > 0.0 else _left_walk
	if absf(velocity) <= 36.0 or frames.is_empty():
		return -1
	return int(floor(_walk_distance / WALK_CYCLE_DISTANCE * float(frames.size()))) % frames.size()

func visible_catch_frame_index() -> int:
	if _catch_frames.is_empty() or not _visual_catch_active or _catch_fps <= 0.0:
		return -1
	return mini(floori(_visual_catch_elapsed * _catch_fps), _catch_frames.size() - 1)

func bottom_control_hint() -> String:
	if float(_snapshot.get("catch_window", 0.0)) > 0.0:
		return "現在伸手！"
	if _active_hat_index() >= 0:
		return "跟著帽影移動"
	return "← → 走位　Space 接帽　｜　拖曳／點擊"

func visible_rack_hat_count(snapshot: Dictionary = {}) -> int:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	var ledger_value: Variant = state.get("ledger", [])
	if not ledger_value is Array:
		return 0
	var ledger: Array = ledger_value
	var visible := 0
	for entry in ledger:
		if not entry is Dictionary:
			continue
		var status := str(entry.get("status", ""))
		if status == "center" or status == "edge":
			visible += 1
	return visible

func uses_authored_avatar() -> bool:
	return _idle_texture != null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		if key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_left_down = key.pressed
			axis_requested.emit(float(int(_right_down) - int(_left_down)))
			accept_event()
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_right_down = key.pressed
			axis_requested.emit(float(int(_right_down) - int(_left_down)))
			accept_event()
		elif key.keycode == KEY_SPACE and key.pressed:
			catch_requested.emit(true)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if PLAYER_RAIL.grow(0.0).has_point(event.position) or Rect2(112.0, 170.0, 1056.0, 354.0).has_point(event.position):
			grab_focus()
			target_x_requested.emit(event.position.x)
			catch_requested.emit(true)
			accept_event()
	elif event is InputEventMouseMotion:
		var mouse_play_lane := Rect2(112.0, PLAYER_RAIL.position.y - 116.0, 1056.0, 138.0)
		if mouse_play_lane.has_point(event.position):
			target_x_requested.emit(event.position.x)
			accept_event()

func _refresh_avatar_textures() -> void:
	if _renderer == null:
		_renderer = AvatarRendererScript.new()
	_idle_texture = _renderer.texture(_appearance, _equipped, "front", 0, "idle")
	_catch_frames.clear()
	_catch_fps = 0.0
	if _renderer.has_authored_action("catch", "front"):
		var authored_count: int = _renderer.authored_frame_count("catch", "front")
		_catch_fps = _renderer.authored_action_fps("catch", "front")
		for frame in authored_count:
			var pose: Texture2D = _renderer.texture(_appearance, _equipped, "front", frame, "catch")
			if pose != null:
				_catch_frames.append(pose)
	_left_walk.clear()
	_right_walk.clear()
	for direction in ["left", "right"]:
		var frame_count: int = _renderer.walk_frame_count(direction)
		if frame_count <= 0:
			push_warning("HatRescueView: AvatarRenderer has no authored walk frames for direction '%s'; idle pose will be used." % direction)
			continue
		var destination: Array[Texture2D] = _left_walk if direction == "left" else _right_walk
		for frame in frame_count:
			var texture: Texture2D = _renderer.texture(_appearance, _equipped, direction, frame, "walk")
			if texture != null:
				destination.append(texture)

func _draw() -> void:
	var palette := _palette()
	var sky: Color = palette[0]
	var sea: Color = palette[1]
	var ink: Color = palette[2]
	var brass: Color = palette[3]
	var coral: Color = palette[4]
	var wood: Color = palette[5]
	var paper: Color = palette[6]
	var kelp: Color = palette[7]
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), sky)
	_draw_far_shore(sea, ink, kelp, paper, brass)
	_draw_boardwalk(ink, wood, brass, paper, coral, kelp)
	_draw_forecast_flag(ink, brass, coral, paper)
	_draw_catch_rail(ink, brass, coral, paper)
	_draw_hat_paths(ink, brass)
	_draw_avatar(ink, coral)
	_draw_rescue_rack(ink, wood, brass)
	_draw_score_note(ink, paper, brass, coral)

func _palette() -> Array[Color]:
	if _time_phase == "dawn":
		return PALETTE_DAWN
	if _time_phase == "dusk":
		return PALETTE_DUSK
	if _time_phase == "night":
		return PALETTE_NIGHT
	return PALETTE_NOON

func _draw_far_shore(sea: Color, ink: Color, kelp: Color, paper: Color, brass: Color) -> void:
	draw_rect(Rect2(0.0, 302.0, 1280.0, 258.0), sea)
	draw_line(Vector2(0.0, 314.0), Vector2(1280.0, 314.0), paper.lightened(0.12), 2.0)
	# Tide-house: stepped plaster, deep eaves, shingle seams and inset lit windows.
	draw_rect(Rect2(878.0, 330.0, 292.0, 118.0), ink.darkened(0.1))
	draw_rect(Rect2(890.0, 326.0, 272.0, 116.0), kelp.darkened(0.12))
	draw_rect(Rect2(890.0, 326.0, 272.0, 8.0), paper.darkened(0.12))
	draw_line(Vector2(858.0, 324.0), Vector2(1014.0, 239.0), ink, 17.0)
	draw_line(Vector2(1014.0, 239.0), Vector2(1187.0, 322.0), ink, 17.0)
	draw_line(Vector2(865.0, 319.0), Vector2(1014.0, 247.0), coral_color(), 3.0)
	draw_line(Vector2(1014.0, 247.0), Vector2(1178.0, 317.0), coral_color(), 3.0)
	for shingle in range(5):
		var sy := 263.0 + float(shingle) * 11.0
		draw_line(Vector2(925.0 - float(shingle) * 17.0, sy), Vector2(1007.0, sy + 1.0), brass.darkened(0.32), 1.3)
		draw_line(Vector2(1021.0, sy + 1.0), Vector2(1101.0 + float(shingle) * 15.0, sy + 1.0), brass.darkened(0.32), 1.3)
	for window_x in [920.0, 1084.0]:
		draw_rect(Rect2(window_x - 5.0, 347.0, 63.0, 62.0), ink)
		draw_rect(Rect2(window_x, 351.0, 53.0, 53.0), paper.darkened(0.04))
		draw_rect(Rect2(window_x + 7.0, 357.0, 17.0, 39.0), brass.darkened(0.06))
		draw_rect(Rect2(window_x + 28.0, 357.0, 18.0, 39.0), brass.lightened(0.08))
		draw_line(Vector2(window_x + 26.0, 352.0), Vector2(window_x + 26.0, 403.0), ink, 3.0)
		draw_line(Vector2(window_x - 10.0, 344.0), Vector2(window_x + 58.0, 344.0), coral_color(), 4.0)
		draw_line(Vector2(window_x - 8.0, 410.0), Vector2(window_x + 56.0, 410.0), ink, 4.0)
	# A few etched gull strokes and tide marks add scale without competing with hats.
	for gull_x in [455.0, 494.0, 112.0]:
		draw_line(Vector2(gull_x, 205.0), Vector2(gull_x + 8.0, 211.0), ink.darkened(0.08), 2.0)
		draw_line(Vector2(gull_x + 8.0, 211.0), Vector2(gull_x + 17.0, 204.0), ink.darkened(0.08), 2.0)
	# Clothesline carries shape-coded spare caps; it stays behind the active trajectory.
	draw_line(Vector2(93.0, 270.0), Vector2(380.0, 292.0), ink.darkened(0.12), 3.0)
	draw_line(Vector2(90.0, 258.0), Vector2(91.0, 343.0), ink, 5.0)
	draw_line(Vector2(380.0, 278.0), Vector2(381.0, 348.0), ink, 5.0)
	draw_line(Vector2(159.0, 276.0), Vector2(212.0, 282.0), coral_color(), 7.0)
	draw_line(Vector2(212.0, 282.0), Vector2(211.0, 309.0), coral_color(), 7.0)
	draw_line(Vector2(211.0, 309.0), Vector2(159.0, 297.0), coral_color(), 7.0)
	draw_line(Vector2(254.0, 284.0), Vector2(302.0, 288.0), brass, 7.0)
	draw_line(Vector2(302.0, 288.0), Vector2(307.0, 311.0), brass, 7.0)
	draw_line(Vector2(307.0, 311.0), Vector2(254.0, 302.0), brass, 7.0)
	# Horizon flecks are sparse so the hat silhouettes stay primary.
	for wave_x in FAR_WAVE_X:
		draw_line(Vector2(wave_x, 378.0), Vector2(wave_x + 47.0, 378.0), paper.darkened(0.05), 2.0)
		draw_line(Vector2(wave_x + 12.0, 399.0), Vector2(wave_x + 70.0, 399.0), kelp, 1.0)

func coral_color() -> Color:
	return Color("#da816b")

func _draw_boardwalk(ink: Color, wood: Color, brass: Color, paper: Color, coral: Color, kelp: Color) -> void:
	draw_rect(Rect2(0.0, 548.0, 1280.0, 172.0), wood)
	draw_rect(Rect2(0.0, 548.0, 1280.0, 14.0), ink.darkened(0.05))
	draw_rect(Rect2(0.0, 562.0, 1280.0, 5.0), brass.darkened(0.18))
	for plank in range(8):
		var y := 565.0 + float(plank) * 19.0
		draw_line(Vector2(0.0, y), Vector2(1280.0, y), ink.darkened(0.18), 2.0)
		draw_line(Vector2(42.0 + float(plank % 2) * 28.0, y + 3.0), Vector2(720.0, y + 3.0), brass.darkened(0.48), 1.0)
		for nail_x in [52.0, 1227.0]:
			draw_circle(Vector2(nail_x, y + 8.0), 2.2, brass.darkened(0.08))
	for seam_x in PLANK_SEAMS:
		draw_line(Vector2(seam_x, 554.0), Vector2(seam_x, 718.0), ink.darkened(0.18), 2.0)
	# Board ends, old nail scars and small weed tufts give the deck hand-built scale.
	for knot_x in [304.0, 704.0, 1038.0]:
		draw_arc(Vector2(knot_x, 610.0 + fposmod(knot_x, 38.0)), 8.0, 0.2, TAU - 0.2, 18, brass.darkened(0.2), 1.2)
	for weed_x in [386.0, 888.0]:
		draw_line(Vector2(weed_x, 568.0), Vector2(weed_x - 4.0, 550.0), kelp, 2.0)
		draw_line(Vector2(weed_x, 568.0), Vector2(weed_x + 5.0, 552.0), kelp, 2.0)
	# Rope stanchions and cleats are fixed stagecraft, not a frame or tile grid.
	for post_x in ROPE_POSTS:
		draw_rect(Rect2(post_x - 7.0, 449.0, 14.0, 99.0), ink)
		draw_rect(Rect2(post_x - 4.0, 456.0, 8.0, 86.0), brass.darkened(0.18))
		draw_circle(Vector2(post_x, 450.0), 10.0, brass)
		for wrap in range(3):
			draw_line(Vector2(post_x - 5.0, 466.0 + float(wrap) * 6.0), Vector2(post_x + 5.0, 469.0 + float(wrap) * 6.0), paper.darkened(0.12), 1.5)
	# The awning is a stretched canvas with scalloped hems and visible rope stays.
	draw_line(Vector2(74.0, 253.0), Vector2(399.0, 273.0), ink, 5.0)
	draw_line(Vector2(78.0, 258.0), Vector2(397.0, 278.0), coral, 2.0)
	for awning_panel in range(6):
		var ax := 84.0 + float(awning_panel) * 52.0
		var ay := 258.0 + float(awning_panel) * 3.2
		var panel_color: Color = paper if awning_panel % 2 == 0 else brass
		draw_line(Vector2(ax, ay), Vector2(ax + 43.0, ay + 3.0), panel_color, 7.0)
		draw_line(Vector2(ax + 42.0, ay + 3.0), Vector2(ax + 44.0, ay + 12.0), panel_color.darkened(0.08), 6.0)
		draw_circle(Vector2(ax + 22.0, ay + 17.0), 2.0, ink)
	draw_line(Vector2(77.0, 258.0), Vector2(90.0, 366.0), ink.darkened(0.1), 2.0)
	draw_line(Vector2(400.0, 278.0), Vector2(386.0, 365.0), ink.darkened(0.1), 2.0)

func _draw_forecast_flag(ink: Color, brass: Color, coral: Color, paper: Color) -> void:
	var forecast := bool(_snapshot.get("forecast_visible", false))
	var active_force := absf(float(_snapshot.get("wind_strength", 0.0)))
	var gust_active := active_force > 1.0
	var direction := int(_snapshot.get("forecast_direction", 0)) if forecast else (int(_snapshot.get("wind_direction", 0)) if gust_active else 0)
	var flag_color := coral if direction < 0 else brass
	var flag_x := 640.0
	var flag_y := 284.0
	draw_line(Vector2(flag_x, 233.0), Vector2(flag_x, flag_y), ink, 4.0)
	if direction == 0:
		draw_line(Vector2(flag_x, 244.0), Vector2(flag_x + 18.0, 244.0), paper, 4.0)
	else:
		var width := 22.0 + clampf((active_force if gust_active else 100.0) / WIND_STRENGTH_DISPLAY, 0.0, 1.0) * 32.0
		var tip := Vector2(flag_x + width * direction, 253.0)
		draw_line(Vector2(flag_x, 235.0), tip, flag_color, 5.0)
		draw_line(tip, Vector2(flag_x, 270.0), flag_color, 4.0)
		draw_line(Vector2(flag_x, 270.0), Vector2(flag_x, 235.0), flag_color, 3.0)
	var arrow_dir := direction
	if arrow_dir != 0:
		var arrow_len := 23.0 + clampf(active_force / WIND_STRENGTH_DISPLAY, 0.0, 1.0) * 40.0
		var arrow_start := Vector2(640.0 - arrow_dir * arrow_len * 0.5, 334.0)
		var arrow_end := Vector2(640.0 + arrow_dir * arrow_len * 0.5, 334.0)
		draw_line(arrow_start, arrow_end, flag_color, 4.0)
		draw_line(arrow_end, arrow_end + Vector2(-arrow_dir * 9.0, -7.0), flag_color, 3.0)
		draw_line(arrow_end, arrow_end + Vector2(-arrow_dir * 9.0, 7.0), flag_color, 3.0)
	var label := "預告　%.1f 秒" % float(_snapshot.get("forecast_seconds", 0.0)) if forecast else ("陣風正在推帽" if gust_active else "海風暫歇")
	_draw_label(Vector2(640.0, 218.0), label, ink, HORIZONTAL_ALIGNMENT_CENTER, 260, 15)
	_draw_label(Vector2(640.0, 356.0), "帽影落點" if forecast or gust_active else "沿接帽線移動", paper, HORIZONTAL_ALIGNMENT_CENTER, 220, 12)

const WIND_STRENGTH_DISPLAY := 156.0

func _draw_catch_rail(ink: Color, brass: Color, coral: Color, paper: Color) -> void:
	var rail_y := PLAYER_RAIL.position.y + PLAYER_RAIL.size.y * 0.5
	draw_line(Vector2(PLAYER_RAIL.position.x, rail_y), Vector2(PLAYER_RAIL.end.x, rail_y), ink, 8.0)
	draw_line(Vector2(PLAYER_RAIL.position.x, rail_y - 5.0), Vector2(PLAYER_RAIL.end.x, rail_y - 5.0), brass, 2.0)
	# The solid crossbar and segmented safe strip mark the model's exact hand contact height.
	draw_line(Vector2(PLAYER_RAIL.position.x + 14.0, CATCH_LINE_Y), Vector2(PLAYER_RAIL.end.x - 14.0, CATCH_LINE_Y), paper.darkened(0.06), 2.0)
	for x in CATCH_LINE_MARKS:
		draw_circle(Vector2(x, CATCH_LINE_Y), 4.0, coral)
	draw_rect(Rect2(PLAYER_RAIL.position.x, rail_y + 2.0, 13.0, 34.0), ink)
	draw_rect(Rect2(PLAYER_RAIL.end.x - 13.0, rail_y + 2.0, 13.0, 34.0), ink)
	var active_hat_index := _active_hat_index()
	if active_hat_index >= 0:
		var active_hat: Dictionary = _snapshot["hats"][active_hat_index]
		var landing_x := float(active_hat.get("landing_x", active_hat.get("x", 0.0)))
		var trajectory_x := float(active_hat.get("x", landing_x))
		var hat_y := float(active_hat.get("y", CATCH_LINE_Y))
		var projected := Vector2(landing_x, CATCH_LINE_Y - 20.0)
		var middle := Vector2(float(active_hat.get("midpoint_x", trajectory_x)), float(active_hat.get("midpoint_y", hat_y)))
		draw_line(Vector2(trajectory_x, hat_y), middle, brass, 2.0)
		draw_line(middle, projected, brass, 2.0)
		draw_arc(projected, 12.0, 0.0, TAU, 28, coral, 2.5)
		if bool(_snapshot.get("assisted", false)):
			draw_arc(projected, 19.0, 0.0, TAU, 28, paper, 1.5)
	var next_x := float(_snapshot.get("next_spawn_x", -1.0))
	if next_x > 0.0:
		draw_line(Vector2(next_x, 393.0), Vector2(next_x, 414.0), brass.darkened(0.12), 2.0)
		draw_arc(Vector2(next_x, 394.0), 11.0, PI, TAU, 20, brass, 2.0)
		_draw_label(Vector2(next_x, 432.0), "下一頂", ink, HORIZONTAL_ALIGNMENT_CENTER, 66, 11)
	_draw_label(Vector2(140.0, 517.0), "接帽線", paper, HORIZONTAL_ALIGNMENT_LEFT, 92, 13)

func _draw_hat_paths(ink: Color, brass: Color) -> void:
	var hats_value: Variant = _snapshot.get("hats", [])
	if not hats_value is Array:
		return
	var hats: Array = hats_value
	for index in hats.size():
		if not hats[index] is Dictionary:
			continue
		var hat: Dictionary = hats[index]
		if not bool(hat.get("active", false)) or bool(hat.get("resolved", false)):
			continue
		_draw_hat(index, Vector2(float(hat.get("x", 0.0)), float(hat.get("y", 0.0))), visible_hat_angle(hat), brass, ink)

func _draw_hat(index: int, center: Vector2, rotation: float, brass: Color, ink: Color, scale: float = 1.0) -> void:
	var fill: Color = HAT_FILLS[index]
	var trim: Color = HAT_TRIMS[index]
	draw_set_transform(center, rotation, Vector2.ONE * scale)
	if index == 0:
		draw_set_transform(center, rotation, Vector2(scale, 0.23 * scale))
		draw_circle(Vector2.ZERO, 44.0, fill.darkened(0.14))
		draw_set_transform(center, rotation, Vector2.ONE)
		draw_rect(Rect2(-26.0, -21.0, 52.0, 29.0), fill)
		draw_line(Vector2(-28, 2), Vector2(29, 2), trim, 2.0)
		draw_line(Vector2(-21, -13), Vector2(-16, 11), trim.darkened(0.18), 1.5)
		draw_line(Vector2(8, -20), Vector2(12, 12), trim.darkened(0.18), 1.5)
	elif index == 1:
		draw_circle(Vector2.ZERO, 31.0, fill)
		draw_rect(Rect2(-33.0, 1.0, 66.0, 10.0), fill)
		draw_line(Vector2(-32, 9), Vector2(34, 9), trim, 4.0)
		draw_line(Vector2(-8, -15), Vector2(0, 4), trim, 2.0)
		draw_line(Vector2(8, -15), Vector2(0, 4), trim, 2.0)
	elif index == 2:
		draw_set_transform(center, rotation, Vector2(scale, 0.23 * scale))
		draw_circle(Vector2.ZERO, 44.0, fill.darkened(0.08))
		draw_set_transform(center, rotation, Vector2.ONE)
		draw_circle(Vector2.ZERO, 25.0, fill)
		draw_line(Vector2(-36, 0), Vector2(37, 0), trim, 3.0)
		for petal in range(5):
			var petal_x := -22.0 + float(petal) * 11.0
			draw_circle(Vector2(petal_x, -24.0), 4.0, trim)
	elif index == 3:
		draw_set_transform(center, rotation, Vector2(scale, 0.25 * scale))
		draw_circle(Vector2.ZERO, 43.0, fill.darkened(0.1))
		draw_set_transform(center, rotation, Vector2.ONE)
		draw_rect(Rect2(-28.0, -24.0, 56.0, 36.0), fill)
		draw_line(Vector2(-24, -1), Vector2(24, -1), trim, 3.0)
		draw_arc(Vector2(0, -20), 13.0, PI, TAU, 18, trim, 1.5)
	elif index == 4:
		draw_circle(Vector2(0.0, -4.0), 29.0, fill)
		draw_rect(Rect2(-31.0, 1.0, 62.0, 10.0), fill.darkened(0.08))
		draw_line(Vector2(-36, 8), Vector2(36, 8), trim, 3.0)
		draw_circle(Vector2(-8, -10), 3.0, trim)
	elif index == 5:
		draw_circle(Vector2(-3.0, -3.0), 29.0, fill)
		draw_set_transform(center, rotation, Vector2(scale, 0.34 * scale))
		draw_circle(Vector2(32.0, 17.0), 25.0, fill.darkened(0.12))
		draw_set_transform(center, rotation, Vector2.ONE)
		draw_line(Vector2(-24, 9), Vector2(30, 9), trim, 2.5)
	# Shared small brass button clarifies which way the brim is facing in rotation.
	draw_circle(Vector2(0.0, -11.0), 2.7, brass)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_avatar(ink: Color, coral: Color) -> void:
	var player_x := float(_snapshot.get("player_x", 640.0))
	var velocity := float(_snapshot.get("player_velocity", 0.0))
	var texture := _idle_texture
	var catch_frame := visible_catch_frame_index()
	if catch_frame >= 0:
		texture = _catch_frames[catch_frame]
	elif absf(velocity) > 36.0:
		var frames: Array[Texture2D] = _right_walk if velocity > 0.0 else _left_walk
		if not frames.is_empty():
			texture = frames[visible_walk_frame_index()]
	if texture != null:
		draw_texture_rect(texture, Rect2(player_x - PLAYER_DRAW_SIZE.x * 0.5, PLAYER_GROUND_Y - PLAYER_DRAW_SIZE.y, PLAYER_DRAW_SIZE.x, PLAYER_DRAW_SIZE.y), false)
	else:
		# Authored full-figure fallback with cloth seams and articulated arms, never a circle stand-in.
		draw_line(Vector2(player_x - 11.0, 541.0), Vector2(player_x - 30.0, 505.0), Color("#e4b18d"), 8.0)
		draw_line(Vector2(player_x + 11.0, 541.0), Vector2(player_x + 30.0, 505.0), Color("#e4b18d"), 8.0)
		draw_rect(Rect2(player_x - 20.0, 506.0, 40.0, 73.0), Color("#4f8fa1"))
		draw_line(Vector2(player_x - 11.0, 577.0), Vector2(player_x - 15.0, 626.0), ink, 8.0)
		draw_line(Vector2(player_x + 11.0, 577.0), Vector2(player_x + 15.0, 626.0), ink, 8.0)
		draw_circle(Vector2(player_x, 488.0), 20.0, Color("#e8b991"))
		draw_rect(Rect2(player_x - 27.0, 475.0, 54.0, 8.0), coral)
	# Hand contact cue is a stable rail mark plus a short raised-arm accent while reaching.
	if float(_snapshot.get("catch_pose", 0.0)) > 0.0:
		draw_arc(Vector2(player_x, CATCH_LINE_Y - 14.0), 38.0, PI + 0.18, TAU - 0.18, 18, coral, 3.0)

func _draw_rescue_rack(ink: Color, wood: Color, brass: Color) -> void:
	var rack := Rect2(1050.0, 434.0, 120.0, 95.0)
	draw_rect(Rect2(rack.position.x, rack.position.y + 55.0, rack.size.x, 12.0), ink)
	draw_rect(Rect2(rack.position.x + 7.0, rack.position.y + 65.0, 8.0, 37.0), wood.darkened(0.12))
	draw_rect(Rect2(rack.end.x - 15.0, rack.position.y + 65.0, 8.0, 37.0), wood.darkened(0.12))
	draw_line(rack.position + Vector2(8.0, 54.0), rack.position + Vector2(112.0, 54.0), brass, 3.0)
	var ledger_value: Variant = _snapshot.get("ledger", [])
	var ledger: Array = ledger_value if ledger_value is Array else []
	for index in 6:
		var x := rack.position.x + 15.0 + float(index) * 17.0
		var status := _ledger_status(ledger, index)
		var color := brass if status == "center" or status == "edge" else ink.lightened(0.24)
		draw_arc(Vector2(x, rack.position.y + 47.0), 8.0, PI, TAU, 12, color, 2.0)
		if status == "center" or status == "edge":
			_draw_hat(index, Vector2(x, rack.position.y + 43.0), 0.0, brass, ink, 0.18)
		else:
			draw_line(Vector2(x - 3.0, rack.position.y + 43.0), Vector2(x + 3.0, rack.position.y + 43.0), ink.lightened(0.22), 1.5)
	for screw_x in [rack.position.x + 8.0, rack.end.x - 8.0]:
		draw_circle(Vector2(screw_x, rack.position.y + 61.0), 3.0, brass)
		draw_line(Vector2(screw_x - 1.5, rack.position.y + 61.0), Vector2(screw_x + 1.5, rack.position.y + 61.0), ink, 1.0)
	_draw_label(Vector2(1110.0, 420.0), "救回帽架", ink, HORIZONTAL_ALIGNMENT_CENTER, 124, 12)

func _draw_score_note(ink: Color, paper: Color, brass: Color, coral: Color) -> void:
	var note := Rect2(83.0, 151.0, 156.0, 92.0)
	var ivory := Color("#f4eedc")
	draw_rect(note, Color("#102b3a"))
	draw_rect(note, brass, false, 2.0)
	draw_rect(Rect2(note.position.x, note.position.y, 5.0, note.size.y), brass)
	_draw_label(Vector2(note.position.x + 18.0, note.position.y + 22.0), "救回 %d / 6" % int(_snapshot.get("caught", 0)), ivory, HORIZONTAL_ALIGNMENT_LEFT, 126, 15)
	_draw_label(Vector2(note.position.x + 18.0, note.position.y + 46.0), "漏接 %d" % int(_snapshot.get("misses", 0)), coral, HORIZONTAL_ALIGNMENT_LEFT, 126, 13)
	_draw_label(Vector2(note.position.x + 18.0, note.position.y + 72.0), "連續中心 %d" % int(_snapshot.get("combo", 0)), ivory, HORIZONTAL_ALIGNMENT_LEFT, 126, 12)
	var prompt := bottom_control_hint()
	var plate := Rect2(414.0, 653.0, 452.0, 42.0)
	draw_rect(plate, ink.darkened(0.02))
	draw_rect(Rect2(plate.position.x, plate.position.y, 6.0, plate.size.y), brass)
	_draw_label(Vector2(plate.position.x + 20.0, plate.position.y + 27.0), prompt, paper, HORIZONTAL_ALIGNMENT_LEFT, 416, 15)

func _active_hat_index() -> int:
	var hats_value: Variant = _snapshot.get("hats", [])
	if not hats_value is Array:
		return -1
	var hats: Array = hats_value
	for index in hats.size():
		if not hats[index] is Dictionary:
			continue
		var hat: Dictionary = hats[index]
		if bool(hat.get("active", false)) and not bool(hat.get("resolved", false)):
			return index
	return -1

func _ledger_status(ledger: Array, index: int) -> String:
	if index < 0 or index >= ledger.size() or not ledger[index] is Dictionary:
		return ""
	return str(ledger[index].get("status", ""))


func _draw_label(position: Vector2, text: String, color: Color, alignment: HorizontalAlignment, width: int, size: int) -> void:
	draw_string(FONT, position, text, alignment, width, size, color)

func _normalize_phase(value: String) -> String:
	return value if value == "dawn" or value == "noon" or value == "dusk" or value == "night" else "noon"
