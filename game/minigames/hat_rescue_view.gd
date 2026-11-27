extends Control
class_name HatRescueView

signal axis_requested(value: float)
signal target_x_requested(value: float)
signal catch_requested(pressed: bool)

const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const HatRescueModelScript = preload("res://game/minigames/hat_rescue_model.gd")
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const PLAY_BOUNDS := Rect2(48.0, 136.0, 1184.0, 548.0)
const HUD_SAFE_RECT := Rect2(34.0, 18.0, 1212.0, 112.0)
const PLAYER_RAIL := Rect2(126.0, 530.0, 1028.0, 22.0)
const CATCH_LINE_Y := 518.0
const PLAYER_GROUND_Y := 638.0
const PLAYER_DRAW_SIZE := Vector2(126.0, 162.0)
const WALK_CYCLE_DISTANCE := PLAYER_DRAW_SIZE.x * 0.9
const STILL_SPEED := 1.0
const CATCH_LINE_MARKS: Array[float] = [182.0, 326.0, 470.0, 614.0, 758.0, 902.0, 1046.0]
const CHARACTER_RENDER_BOUNDS := Rect2(113.0, 452.0, 1054.0, 190.0)
const HAT_RENDER_BOUNDS := Rect2(96.0, 136.0, 1088.0, 432.0)
const STAGE_BOUNDS := Rect2(0.0, 136.0, 1280.0, 584.0)
const HAT_FILLS: Array[Color] = [Color("#d7ad67"), Color("#527b91"), Color("#e08268"), Color("#827460"), Color("#b87752"), Color("#527f78")]
const HAT_TRIMS: Array[Color] = [Color("#f0d99f"), Color("#f0e6d2"), Color("#f4d8a3"), Color("#b8a486"), Color("#e3bb78"), Color("#f0dfbf")]
const FAR_WAVE_X: Array[float] = [54.0, 440.0, 704.0, 1210.0]
const FERRY_DECK_Y := 236.0
const FERRY_RAIL_Y := 226.0
## Bow mast sits right of the HUD feedback band (x 370–910) so the wind cue is never covered.
const MAST_X := 1004.0
const RACK_RECT := Rect2(1124.0, 420.0, 136.0, 128.0)
const WIND_STREAK_Y: Array[float] = [326.0, 352.0, 381.0, 410.0, 446.0]
const PASSENGER_COATS: Array[Color] = [Color("#9c5b4a"), Color("#3e6476"), Color("#8a6d9a"), Color("#5f7a52"), Color("#a7774a"), Color("#4b5f86")]
const PLANK_SEAMS: Array[float] = [78.0, 250.0, 446.0, 628.0, 820.0, 1015.0, 1202.0]
const ROPE_POSTS: Array[float] = [94.0]
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
	# Textured polygons (headlands, the ferry hull) tile their material swatch.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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
		_visual_catch_active = not _catch_frames.is_empty() and absf(float(snapshot.get("player_velocity",0.0))) <= STILL_SPEED
	# These whole-body cels are planted reaches. Locomotion takes precedence;
	# cosmetic interruption never changes the model's catch eligibility window.
	if absf(float(snapshot.get("player_velocity",0.0))) > STILL_SPEED:
		_visual_catch_active = false
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

## Hats start small on the distant ferry deck and reach full size before the hand line.
func hat_draw_scale(y: float, spawn_y: float) -> float:
	return lerpf(0.42, 1.0, clampf((y - spawn_y) / 150.0, 0.0, 1.0))

func authored_catch_frame_count() -> int:
	return _catch_frames.size()

func authored_catch_frame_rate() -> float:
	return _catch_fps

func visible_walk_frame_index() -> int:
	if visible_catch_frame_index() >= 0:
		return -1
	var velocity := float(_snapshot.get("player_velocity", 0.0))
	var frames: Array[Texture2D] = _right_walk if velocity > 0.0 else _left_walk
	if absf(velocity) <= STILL_SPEED or frames.is_empty():
		return -1
	return int(floor(_walk_distance / WALK_CYCLE_DISTANCE * float(frames.size()))) % frames.size()

func visible_catch_frame_index() -> int:
	if _catch_frames.is_empty() or not _visual_catch_active or _catch_fps <= 0.0:
		return -1
	return mini(floori(_visual_catch_elapsed * _catch_fps), _catch_frames.size() - 1)

func bottom_control_hint() -> String:
	if float(_snapshot.get("catch_window", 0.0)) > 0.0:
		return "現在伸手！"
	if float(_snapshot.get("lead_in_left", 0.0)) > 0.0:
		return "準備：亮圈旅客的帽子先飛"
	if _airborne_hat_indices().size() > 1:
		return "兩頂一起來：先接 1 號"
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
	# Sky in posterised bands, paler toward the horizon, instead of one flat fill.
	Props.bands(self, Rect2(0.0, 0.0, DESIGN_SIZE.x, 302.0), sky.darkened(0.08), sky.lightened(0.16), 9)
	draw_rect(Rect2(0.0, 302.0, DESIGN_SIZE.x, DESIGN_SIZE.y - 302.0), sky)
	_draw_far_shore(sea, ink, kelp, paper, brass)
	_draw_gull()
	_draw_ferry(ink, paper, brass, coral, kelp)
	_draw_wind_streaks(paper, brass, coral)
	_draw_boardwalk(ink, wood, brass, paper, coral, kelp)
	_draw_forecast_flag(ink, brass, coral, paper)
	_draw_catch_rail(ink, brass, coral, paper)
	_draw_rescue_rack(ink, wood, brass)
	_draw_hat_paths(ink, brass)
	_draw_avatar(ink, coral)
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
	# Distant headland and lighthouse give scale; the ferry deck in front is where hats come from.
	var hill := kelp.darkened(0.18)
	for ridge in [
		PackedVector2Array([Vector2(0.0, 302.0), Vector2(0.0, 262.0), Vector2(70.0, 246.0), Vector2(150.0, 258.0), Vector2(210.0, 280.0), Vector2(210.0, 302.0)]),
		PackedVector2Array([Vector2(1030.0, 302.0), Vector2(1080.0, 270.0), Vector2(1170.0, 256.0), Vector2(1280.0, 262.0), Vector2(1280.0, 302.0)]),
	]:
		# Rock grain and a lit crest so the headlands read as land, not cut paper.
		Props.fill_polygon(self, ridge, Props.rock_grain(), hill)
		draw_polyline(ridge.slice(1, ridge.size() - 1), Props.lighten(hill, 0.22), 2.0)
	var tower_base := 1232.0
	draw_colored_polygon(PackedVector2Array([Vector2(tower_base - 15.0, 262.0), Vector2(tower_base - 9.0, 176.0), Vector2(tower_base + 9.0, 176.0), Vector2(tower_base + 15.0, 262.0)]), paper.darkened(0.04))
	for band in 3:
		var by := 188.0 + float(band) * 24.0
		draw_line(Vector2(tower_base - 11.0 - float(band) * 1.2, by), Vector2(tower_base + 11.0 + float(band) * 1.2, by), coral_color(), 6.0)
	draw_rect(Rect2(tower_base - 12.0, 160.0, 24.0, 16.0), ink)
	var lamp := brass.lightened(0.3) if _time_phase == "night" or _time_phase == "dusk" else brass
	draw_rect(Rect2(tower_base - 8.0, 163.0, 16.0, 10.0), lamp)
	if _time_phase == "night":
		draw_colored_polygon(PackedVector2Array([Vector2(tower_base - 8.0, 166.0), Vector2(tower_base - 120.0, 150.0), Vector2(tower_base - 120.0, 184.0)]), Color(lamp, 0.16))
	# Water darkens toward the boardwalk; the near rows carry the deeper tone.
	Props.bands(self, Rect2(0.0, 302.0, 1280.0, 258.0), sea.lightened(0.12), sea.darkened(0.16), 8)
	draw_line(Vector2(0.0, 314.0), Vector2(1280.0, 314.0), paper.lightened(0.12), 2.0)
	# Pixel ripple crests: a lit lip over a shaded trough, smaller and denser
	# toward the horizon, drifting slowly with the swell.
	var swell := 0.0 if _reduced_motion else float(_snapshot.get("elapsed", 0.0)) * 9.0
	for row in 7:
		var y := 330.0 + float(row * row) * 4.0 + float(row) * 8.0
		var width := 8.0 + float(row) * 4.0
		var step := 70.0 + float(row) * 26.0
		var x := fposmod(float(row) * 37.0 + swell * (0.5 + float(row) * 0.15), step) - step
		while x < DESIGN_SIZE.x:
			var at := Vector2(x, y).snapped(Vector2(2.0, 2.0))
			draw_rect(Rect2(at, Vector2(width, 2.0)), Color(paper, 0.32))
			draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(width, 2.0)), Color(Props.SHADOW, 0.12))
			x += step
	# Horizon flecks are sparse so the hat silhouettes stay primary.
	for wave_x in FAR_WAVE_X:
		draw_line(Vector2(wave_x, 486.0), Vector2(wave_x + 47.0, 486.0), paper.darkened(0.05), 2.0)
		draw_line(Vector2(wave_x + 12.0, 506.0), Vector2(wave_x + 70.0, 506.0), kelp, 1.0)

## The excursion ferry's upper deck: each passenger loses the hat that later flies at the player.
func _draw_ferry(ink: Color, paper: Color, brass: Color, coral: Color, kelp: Color) -> void:
	var hull := PackedVector2Array([Vector2(214.0, FERRY_DECK_Y), Vector2(1010.0, FERRY_DECK_Y), Vector2(1056.0, 252.0), Vector2(1012.0, 304.0), Vector2(236.0, 304.0)])
	# Riveted steel hull: brushed plate, a lit sheer line and a deepened outline.
	var steel := ink.lightened(0.06)
	draw_colored_polygon(PackedVector2Array([hull[0] + Vector2(10.0, 12.0), hull[1] + Vector2(10.0, 12.0), hull[2] + Vector2(6.0, 12.0), hull[3] + Vector2(4.0, 8.0), hull[4] + Vector2(6.0, 8.0)]), Color(Props.SHADOW, 0.22))
	Props.fill_polygon(self, hull, Props.material_tile("metal", steel))
	draw_colored_polygon(PackedVector2Array([Vector2(234.0, 292.0), Vector2(1022.0, 292.0), hull[3], hull[4]]), Color(Props.deepen(steel, 0.3), 0.7))
	draw_line(hull[0] + Vector2(2.0, 2.0), hull[1] + Vector2(0.0, 2.0), Props.lighten(steel, 0.35), 2.0)
	var hull_outline := hull.duplicate()
	hull_outline.append(hull[0])
	draw_polyline(hull_outline, Props.deepen(steel), 2.0)
	draw_line(Vector2(222.0, 262.0), Vector2(1036.0, 262.0), coral, 5.0)
	draw_line(Vector2(222.0, 260.0), Vector2(1036.0, 260.0), Props.lighten(coral, 0.3), 1.0)
	draw_line(Vector2(230.0, 290.0), Vector2(1022.0, 290.0), paper.darkened(0.2), 2.0)
	for porthole in 9:
		var port := Vector2(300.0 + float(porthole) * 82.0, 276.0)
		draw_circle(port, 6.0, brass.darkened(0.25))
		draw_circle(port, 4.0, brass.darkened(0.1) if _time_phase in ["dusk", "night"] else paper.darkened(0.12))
		draw_rect(Rect2(port - Vector2(2.0, 2.0), Vector2(2.0, 2.0)), Color(1, 1, 1, 0.6))
	# Painted timber cabin and a banded funnel sit behind the passengers.
	var cabin := Rect2(258.0, 176.0, 700.0, 60.0)
	Props.wood_panel(self, cabin, paper.darkened(0.1), true)
	draw_rect(Rect2(cabin.position.x, cabin.end.y - 8.0, cabin.size.x, 8.0), Color(Props.SHADOW, 0.16))
	draw_rect(Rect2(258.0, 172.0, 700.0, 6.0), kelp.darkened(0.25))
	draw_rect(Rect2(258.0, 172.0, 700.0, 2.0), kelp.lightened(0.05))
	for window in 8:
		var window_rect := Rect2(286.0 + float(window) * 84.0, 188.0, 40.0, 22.0)
		draw_rect(window_rect.grow(2.0), Props.deepen(paper.darkened(0.1), 0.35))
		var lit := _time_phase == "night" or _time_phase == "dusk"
		Props.surface(self, window_rect, "glass", brass.lightened(0.15) if lit else ink.lightened(0.22))
	var funnel := Rect2(880.0, 140.0, 34.0, 34.0)
	Props.shaded_box(self, funnel, coral, 4.0)
	draw_rect(Rect2(880.0, 140.0, 34.0, 7.0), ink)
	var hats_value: Variant = _snapshot.get("hats", [])
	var hats: Array = hats_value if hats_value is Array else []
	var next_index := int(_snapshot.get("next_hat_index", -1))
	for index in HatRescueModelScript.HAT_COUNT:
		var x := HatRescueModelScript.SPAWN_X[index]
		var head := Vector2(x, HatRescueModelScript.SPAWN_Y[index] + 24.0)
		var hat_gone := false
		if index < hats.size() and hats[index] is Dictionary:
			hat_gone = bool(hats[index].get("active", false)) or bool(hats[index].get("resolved", false))
		# Passengers bob on the swell, each on its own beat, in whole texels.
		if decorative_motion_enabled():
			head.y += 3.0 * roundf(sin(float(_snapshot.get("elapsed", 0.0)) * 2.2 + float(index) * 1.7) * 0.6)
		_draw_passenger(index, head)
		if hat_gone:
			# The passenger reaches up after the gust took the hat.
			var side := -1.0 if index % 2 == 0 else 1.0
			draw_line(Vector2(x + side * 9.0, head.y + 12.0), Vector2(x + side * 18.0, head.y - 14.0), PASSENGER_COATS[index].darkened(0.1), 4.0)
		else:
			_draw_hat(index, Vector2(x, head.y - 8.0), 0.0, brass, ink, 0.34)
			if index == next_index:
				draw_arc(head + Vector2(0.0, -6.0), 22.0, 0.0, TAU, 28, brass, 2.0)
	draw_line(Vector2(240.0, FERRY_RAIL_Y), Vector2(990.0, FERRY_RAIL_Y), ink, 3.0)
	for post in 16:
		var post_x := 248.0 + float(post) * 49.0
		draw_line(Vector2(post_x, FERRY_RAIL_Y), Vector2(post_x, FERRY_DECK_Y), ink, 2.0)

const PASSENGER_TEXEL := 3.0

## A passenger bust leaning on the rail: hair, a lit face, coat with lapels.
## Texel (4, 3) is the head centre; the coat is cropped at the deck line.
func _draw_passenger(index: int, head: Vector2) -> void:
	var coat: Color = PASSENGER_COATS[index]
	var skin := Color("#e6b996") if index % 2 == 0 else Color("#b98564")
	var hair: Color = [Color("#3a2a22"), Color("#6b4a2e"), Color("#2c2c34")][index % 3]
	var sprite := Pixels.bake("hat-rescue-passenger-%d" % index, Vector2i(9, 20), func(x: int, y: int) -> Color:
		var face := Vector2(x - 4.0, y - 3.0) / 3.2
		if y <= 6 and face.length() <= 1.0:
			if y <= 1 or (y == 2 and (x <= 2 or x >= 6)): return hair
			if y == 4 and (x == 3 or x == 5): return Color("#2b2320")
			return Pixels.rounded(skin, face)
		if y == 7 and x >= 3 and x <= 5: return skin.darkened(0.2)
		if y >= 8:
			if y == 8 and (x == 0 or x == 8): return Pixels.CLEAR
			if x == 4: return coat.darkened(0.25)
			if (x == 3 or x == 5) and y < 11: return coat.lightened(0.18)
			return Pixels.grainy(coat, x, y, 0.08)
		return Pixels.CLEAR)
	var top := head - Vector2(4.0, 3.0) * PASSENGER_TEXEL
	var rows := clampf((FERRY_DECK_Y - top.y) / PASSENGER_TEXEL + 1.0, 1.0, float(sprite.get_height()))
	var source := Rect2(0.0, 0.0, float(sprite.get_width()), rows)
	draw_texture_rect_region(sprite, Rect2(top - Vector2.ONE * PASSENGER_TEXEL, source.size * PASSENGER_TEXEL), source)

## Wind lines on the water use the same signed gust the model applies to every hat.
func _draw_wind_streaks(paper: Color, brass: Color, coral: Color) -> void:
	var force := float(_snapshot.get("wind_strength", 0.0))
	var forecast := bool(_snapshot.get("forecast_visible", false))
	var direction := int(signf(force)) if absf(force) > 1.0 else (int(_snapshot.get("forecast_direction", 0)) if forecast else 0)
	if direction == 0:
		return
	var color := coral if direction < 0 else brass.lightened(0.15)
	var strength := clampf(absf(force) / WIND_STRENGTH_DISPLAY, 0.0, 1.0)
	var length := 34.0 + strength * 70.0 if not forecast else 26.0
	var drift := 0.0 if _reduced_motion else fposmod(float(_snapshot.get("elapsed", 0.0)) * 140.0 * float(direction), 240.0)
	for row in WIND_STREAK_Y.size():
		var y := WIND_STREAK_Y[row]
		for column in 6:
			var x := fposmod(float(column) * 240.0 + float(row) * 77.0 + drift, 1280.0)
			var start := Vector2(x, y)
			var finish := start + Vector2(length * float(direction), 0.0)
			if forecast:
				draw_dashed_line(start, finish, Color(paper, 0.75), 2.0, 6.0)
			else:
				draw_line(start, finish, Color(color, 0.55 + strength * 0.4), 2.0 + strength * 1.5)
				draw_line(finish, finish + Vector2(-8.0 * float(direction), -5.0), color, 2.0)

func coral_color() -> Color:
	return Color("#da816b")

func _draw_boardwalk(ink: Color, wood: Color, brass: Color, paper: Color, coral: Color, kelp: Color) -> void:
	# Grained deck boards from the shared kit; the nearest rows fall into shade.
	Props.wood_panel(self, Rect2(0.0, 548.0, 1280.0, 172.0), wood)
	Props.bands(self, Rect2(0.0, 640.0, 1280.0, 80.0), Color(Props.SHADOW, 0.0), Color(Props.SHADOW, 0.22), 4)
	# Edge beam with a lit top, a brass kick strip and the ambient shade under its lip.
	draw_rect(Rect2(0.0, 548.0, 1280.0, 14.0), ink.darkened(0.05))
	draw_rect(Rect2(0.0, 548.0, 1280.0, 2.0), Props.lighten(ink, 0.25))
	draw_rect(Rect2(0.0, 562.0, 1280.0, 5.0), brass.darkened(0.18))
	draw_rect(Rect2(0.0, 562.0, 1280.0, 1.0), Props.lighten(brass, 0.2))
	draw_rect(Rect2(0.0, 567.0, 1280.0, 8.0), Color(Props.SHADOW, 0.24))
	for plank in range(8):
		var y := 565.0 + float(plank) * 19.0
		for nail_x in [52.0, 1227.0]:
			Props.rivet(self, Vector2(nail_x, y + 8.0), brass)
	for seam_x in PLANK_SEAMS:
		draw_line(Vector2(seam_x, 567.0), Vector2(seam_x, 718.0), Props.deepen(wood, 0.4), 2.0)
		draw_line(Vector2(seam_x + 2.0, 567.0), Vector2(seam_x + 2.0, 718.0), Color(Props.lighten(wood, 0.3), 0.5), 1.0)
	# Board ends, old nail scars and small weed tufts give the deck hand-built scale.
	for knot_x in [304.0, 704.0, 1038.0]:
		draw_arc(Vector2(knot_x, 610.0 + fposmod(knot_x, 38.0)), 8.0, 0.2, TAU - 0.2, 18, brass.darkened(0.2), 1.2)
	for weed_x in [386.0, 888.0]:
		draw_line(Vector2(weed_x, 568.0), Vector2(weed_x - 4.0, 550.0), kelp, 2.0)
		draw_line(Vector2(weed_x, 568.0), Vector2(weed_x + 5.0, 552.0), kelp, 2.0)
	# Rope stanchions and cleats are fixed stagecraft, not a frame or tile grid.
	for post_x in ROPE_POSTS:
		Props.contact_shadow(self, Vector2(post_x + 4.0, 548.0), 34.0, 0.5)
		Props.shaded_box(self, Rect2(post_x - 7.0, 449.0, 14.0, 99.0), wood.darkened(0.3), 4.0)
		draw_rect(Rect2(post_x - 3.0, 456.0, 4.0, 86.0), Color(Props.lighten(wood, 0.2), 0.45))
		Props.token(self, Vector2(post_x, 450.0), 10.0, brass)
		for wrap in range(3):
			Props.rope(self, Vector2(post_x - 7.0, 466.0 + float(wrap) * 6.0), Vector2(post_x + 7.0, 469.0 + float(wrap) * 6.0), 4.0, paper.darkened(0.12))

func _draw_forecast_flag(ink: Color, brass: Color, coral: Color, paper: Color) -> void:
	var forecast := bool(_snapshot.get("forecast_visible", false))
	var active_force := absf(float(_snapshot.get("wind_strength", 0.0)))
	var gust_active := active_force > 1.0
	var direction := int(_snapshot.get("forecast_direction", 0)) if forecast else (int(_snapshot.get("wind_direction", 0)) if gust_active else 0)
	var flag_color := coral if direction < 0 else brass
	var top := 140.0
	draw_line(Vector2(MAST_X, top), Vector2(MAST_X, FERRY_DECK_Y), ink, 4.0)
	draw_line(Vector2(MAST_X - 1.0, top), Vector2(MAST_X - 1.0, FERRY_DECK_Y), Props.lighten(ink, 0.3), 1.0)
	Props.token(self, Vector2(MAST_X, top - 2.0), 4.0, brass)
	if direction == 0:
		# Calm: the pennant hangs down along the mast.
		draw_line(Vector2(MAST_X + 2.0, top + 4.0), Vector2(MAST_X + 6.0, top + 26.0), paper, 4.0)
	else:
		var width := 22.0 + clampf((active_force if gust_active else 100.0) / WIND_STRENGTH_DISPLAY, 0.0, 1.0) * 32.0
		var tip := Vector2(MAST_X + width * direction, top + 10.0)
		var flag := PackedVector2Array([Vector2(MAST_X, top + 2.0), tip, Vector2(MAST_X, top + 20.0)])
		if forecast:
			draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), flag_color, 2.5)
		else:
			draw_colored_polygon(flag, flag_color)
			# Cloth shades toward its trailing edge and keeps a deepened hem.
			draw_colored_polygon(PackedVector2Array([flag[0].lerp(flag[2], 0.5), flag[1], flag[2]]), Props.deepen(flag_color, 0.18))
			draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2]]), Props.deepen(flag_color), 2.0)
	var pair := int(_snapshot.get("gust_hat_count", 0)) >= 2 and (forecast or gust_active)
	var label := ""
	if forecast:
		label = ("雙帽陣風　%.1f 秒" if pair else "陣風　%.1f 秒") % float(_snapshot.get("forecast_seconds", 0.0))
	elif gust_active:
		label = "雙帽陣風！" if pair else "陣風吹帽"
	if not label.is_empty():
		var plaque := Rect2(MAST_X + 20.0, top + 36.0, 132.0, 24.0)
		Props.block_shadow(self, plaque, Vector2(3.0, 4.0), 0.35)
		Props.wood_panel(self, plaque, ink.lightened(0.08), true)
		_draw_label(plaque.position + Vector2(8.0, 17.0), label, paper, HORIZONTAL_ALIGNMENT_LEFT, int(plaque.size.x) - 12, 14)

const WIND_STRENGTH_DISPLAY := 156.0

func _draw_catch_rail(ink: Color, brass: Color, coral: Color, paper: Color) -> void:
	var rail_y := PLAYER_RAIL.position.y + PLAYER_RAIL.size.y * 0.5
	# A brushed steel handrail on two stanchions, with its shade on the deck behind.
	draw_rect(Rect2(PLAYER_RAIL.position.x + 6.0, 548.0, PLAYER_RAIL.size.x - 6.0, 4.0), Color(Props.SHADOW, 0.28))
	for post_x in [PLAYER_RAIL.position.x, PLAYER_RAIL.end.x - 13.0]:
		Props.contact_shadow(self, Vector2(post_x + 10.0, rail_y + 36.0), 30.0, 0.5)
		Props.shaded_box(self, Rect2(post_x, rail_y + 2.0, 13.0, 34.0), ink.lightened(0.12), 4.0)
	Props.metal_plate(self, Rect2(PLAYER_RAIL.position.x, rail_y - 6.0, PLAYER_RAIL.size.x, 12.0), ink.lightened(0.2), false)
	draw_line(Vector2(PLAYER_RAIL.position.x + 2.0, rail_y - 5.0), Vector2(PLAYER_RAIL.end.x - 2.0, rail_y - 5.0), brass, 2.0)
	# A taut hemp line and enamel knots mark the model's exact hand contact height.
	Props.rope(self, Vector2(PLAYER_RAIL.position.x + 14.0, CATCH_LINE_Y), Vector2(PLAYER_RAIL.end.x - 14.0, CATCH_LINE_Y), 4.0, paper.darkened(0.06))
	for x in CATCH_LINE_MARKS:
		Props.token(self, Vector2(x, CATCH_LINE_Y), 5.0, coral)
	var airborne := _airborne_hat_indices()
	for index in airborne:
		var hat: Dictionary = _snapshot["hats"][index]
		var landing_x := float(hat.get("landing_x", hat.get("x", 0.0)))
		var trajectory_x := float(hat.get("x", landing_x))
		var hat_y := float(hat.get("y", CATCH_LINE_Y))
		var projected := Vector2(landing_x, CATCH_LINE_Y - 20.0)
		var middle := Vector2(float(hat.get("midpoint_x", trajectory_x)), float(hat.get("midpoint_y", hat_y)))
		var rank := int(hat.get("airborne_rank", 1))
		var first := rank <= 1
		var path_color := brass if first else Color(brass, 0.55)
		var trail_shade := Color(Props.SHADOW, 0.3 if first else 0.16)
		draw_line(Vector2(trajectory_x, hat_y + 2.0), middle + Vector2(0.0, 2.0), trail_shade, 2.0)
		draw_line(middle + Vector2(0.0, 2.0), projected + Vector2(0.0, 2.0), trail_shade, 2.0)
		draw_line(Vector2(trajectory_x, hat_y), middle, path_color, 2.0)
		draw_line(middle, projected, path_color, 2.0)
		# Landing ring as a lit enamel hoop: deepened rim, coloured band, top-left gleam.
		var ring := coral if first else paper
		Props.contact_shadow(self, Vector2(landing_x, CATCH_LINE_Y + 2.0), 30.0, 0.45 if first else 0.25)
		draw_arc(projected + Vector2(1.0, 2.0), 12.0, 0.0, TAU, 28, Color(Props.SHADOW, 0.35), 3.0)
		draw_arc(projected, 12.0, 0.0, TAU, 28, Props.deepen(ring, 0.3), 4.5)
		draw_arc(projected, 12.0, 0.0, TAU, 28, ring, 2.5)
		draw_arc(projected, 12.0, PI * 1.05, PI * 1.55, 8, Props.lighten(ring, 0.5), 2.0)
		if bool(_snapshot.get("assisted", false)):
			draw_arc(projected, 19.0, 0.0, TAU, 28, paper, 1.5)
		if airborne.size() > 1:
			# Two brims at once: number the landing rings in arrival order.
			Props.token(self, projected + Vector2(0.0, -24.0), 10.0, ink.lightened(0.1))
			_draw_label(projected + Vector2(-4.0, -19.0), str(rank), paper, HORIZONTAL_ALIGNMENT_LEFT, 20, 13)

func _draw_hat_paths(ink: Color, brass: Color) -> void:
	var hats_value: Variant = _snapshot.get("hats", [])
	if not hats_value is Array:
		return
	var hats: Array = hats_value
	for index in hats.size():
		if not hats[index] is Dictionary:
			continue
		var hat: Dictionary = hats[index]
		if bool(hat.get("resolved", false)):
			_draw_missed_hat(index, hat, brass, ink)
			continue
		if not bool(hat.get("active", false)):
			continue
		var y := float(hat.get("y", 0.0))
		var spawn_y := HatRescueModelScript.SPAWN_Y[index] if index < HatRescueModelScript.HAT_COUNT else y
		_draw_hat(index, Vector2(float(hat.get("x", 0.0)), y), visible_hat_angle(hat), brass, ink, hat_draw_scale(y, spawn_y))

const MISS_FLOP_SECONDS := 1.4
const DECK_LANDING_Y := 604.0

## The fail gag: a dropped hat smacks onto the deck, bounces, then spins on its
## brim like a coin before it settles upside down and fades.
func _draw_missed_hat(index: int, hat: Dictionary, brass: Color, ink: Color) -> void:
	var ledger_value: Variant = _snapshot.get("ledger", [])
	var ledger: Array = ledger_value if ledger_value is Array else []
	if _ledger_status(ledger, index) != "miss":
		return
	var age := float(_snapshot.get("elapsed", 0.0)) - float(ledger[index].get("contact_time", -10.0))
	if age < 0.0 or age > MISS_FLOP_SECONDS:
		return
	var x := float(hat.get("x", 0.0))
	if _reduced_motion:
		_draw_hat(index, Vector2(x, DECK_LANDING_Y), PI, brass, ink, 0.8)
		return
	var drop := clampf(age / 0.22, 0.0, 1.0)
	var hop := maxf(0.0, sin((age - 0.22) / 0.3 * PI)) * 26.0 if age > 0.22 and age < 0.52 else 0.0
	var y := lerpf(CATCH_LINE_Y + 44.0, DECK_LANDING_Y, drop * drop) - hop
	var wobble := sin(age * 22.0) * 0.5 * maxf(0.0, 1.0 - age / MISS_FLOP_SECONDS)
	Props.oval_shadow(self, Vector2(x + 4.0, DECK_LANDING_Y + 18.0), Vector2(34.0, 6.0), 0.35)
	var squash := 1.0 - 0.3 * maxf(0.0, 1.0 - absf(age - 0.22) / 0.08)
	draw_set_transform(Vector2(x, y), PI * clampf((age - 0.5) / 0.4, 0.0, 1.0) + wobble, Vector2(1.0 / squash, squash) * 0.8)
	Props.stamp(self, _hat_sprite(index), Vector2(-12.0, -9.0) * HAT_TEXEL, HAT_TEXEL, Color(1, 1, 1, clampf((MISS_FLOP_SECONDS - age) / 0.3, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Props.dust_puffs(self, Vector2(x, DECK_LANDING_Y + 16.0), age - 0.22, 52.0)

## One gull glides across the sky on a slow loop while the round runs.
func _draw_gull() -> void:
	if not decorative_motion_enabled():
		return
	var t := fposmod(float(_snapshot.get("elapsed", 0.0)) / 14.0, 1.0)
	var at := Vector2(lerpf(-60.0, 1340.0, t), 150.0 + sin(t * TAU * 2.0) * 14.0).round()
	var flap := int(float(_snapshot.get("elapsed", 0.0)) * 5.0) % 2
	var gull := Pixels.bake("hat-rescue-gull-%d" % flap, Vector2i(13, 5), func(x: int, y: int) -> Color:
		var wing := absf(x - 6.0)
		var wing_y := (1.0 + wing * 0.35) if flap == 0 else (3.0 - wing * 0.3)
		if x >= 5 and x <= 7 and y >= 2 and y <= 3: return Color("#f4efe2")
		if x == 8 and y == 2: return Props.BRASS
		if absf(y - wing_y) < 0.9 and wing > 0.5: return Color("#dcd6c8") if wing < 4.0 else Color("#5a6b74")
		return Pixels.CLEAR)
	Props.stamp(self, gull, at, 3.0)

func _draw_hat(index: int, center: Vector2, rotation: float, brass: Color, ink: Color, scale: float = 1.0) -> void:
	# Baked pixel hat: texel (12, 9) is the brim centre the model tracks.
	draw_set_transform(center, rotation, Vector2.ONE * scale)
	Props.stamp(self, _hat_sprite(index), Vector2(-12.0, -9.0) * HAT_TEXEL, HAT_TEXEL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

const HAT_TEXEL := 4.0

## Six lost hats, 24 x 13 texels each: straw boater, sailor cap, flower sun hat,
## bowler, knitted bucket and a newsboy cap. Each keeps a brass button at the
## crown front so a spinning hat still shows which way its brim faces.
func _hat_sprite(index: int) -> Texture2D:
	var fill: Color = HAT_FILLS[index]
	var trim: Color = HAT_TRIMS[index]
	return Pixels.bake("hat-rescue-%d" % index, Vector2i(24, 13), func(x: int, y: int) -> Color:
		var fx := float(x) + 0.5
		var fy := float(y) + 0.5
		var brim := pow((fx - 12.0) / 11.8, 2.0) + pow((fy - 10.0) / 2.6, 2.0) <= 1.0
		if x == 12 and y == 4 and index != 1:
			return Props.BRASS
		match index:
			0:
				if y >= 3 and y <= 8 and x >= 6 and x <= 17:
					if y == 7: return trim.darkened(0.25)
					return Pixels.grainy(fill if (x + y) % 3 else fill.darkened(0.14), x, y, 0.1)
				if brim: return Pixels.grainy(fill.darkened(0.06) if (x + y) % 3 else fill.darkened(0.2), x, y, 0.1)
			1:
				var dome := Vector2(fx - 12.0, fy - 9.0) / 7.5
				if y <= 9 and dome.length() <= 1.0:
					if x == 12 and y == 2: return trim
					if y == 8: return trim
					return Pixels.rounded(fill, dome)
				if y >= 9 and y <= 11 and x >= 3 and x <= 20: return trim if y == 9 else fill.darkened(0.2)
			2:
				var dome := Vector2(fx - 12.0, fy - 8.5) / 6.5
				if y <= 9 and dome.length() <= 1.0:
					if y == 7 and x % 3 == 0: return trim if x % 2 == 0 else Color("#f6eadb")
					if y == 8: return trim.darkened(0.2)
					return Pixels.rounded(fill, dome)
				if brim: return Pixels.grainy(fill.darkened(0.1), x, y, 0.1)
			3:
				var top := Vector2(fx - 12.0, fy - 5.0) / Vector2(6.5, 3.4)
				if (y >= 4 and y <= 9 and x >= 6 and x <= 17) or (y < 4 and top.length() <= 1.0):
					if y == 8: return trim
					return Pixels.rounded(fill, Vector2((fx - 12.0) / 6.0, (fy - 6.0) / 5.0))
				if brim: return fill.darkened(0.16)
			4:
				var dome := Vector2(fx - 12.0, fy - 9.0) / 7.2
				if y <= 9 and dome.length() <= 1.0:
					if (x + y) % 2 == 0 and y < 8: return fill.darkened(0.1)
					return Pixels.rounded(fill, dome)
				if y >= 9 and y <= 11 and x >= 4 and x <= 19: return trim.darkened(0.08) if (x % 2 == 0) else trim.darkened(0.2)
				if y == 1 and x >= 11 and x <= 12: return trim
			5:
				var dome := Vector2(fx - 10.0, fy - 8.0) / 7.2
				if y <= 9 and dome.length() <= 1.0:
					if y == 8: return trim
					if x == 10 and y < 8: return fill.darkened(0.18)
					return Pixels.rounded(fill, dome)
				var visor := pow((fx - 17.0) / 6.0, 2.0) + pow((fy - 10.0) / 1.8, 2.0) <= 1.0
				if visor: return fill.darkened(0.22)
		return Pixels.CLEAR)

func _draw_avatar(ink: Color, coral: Color) -> void:
	var player_x := float(_snapshot.get("player_x", 640.0))
	var velocity := float(_snapshot.get("player_velocity", 0.0))
	var texture := _idle_texture
	var catch_frame := visible_catch_frame_index()
	var walk_frame := visible_walk_frame_index()
	if catch_frame >= 0:
		texture = _catch_frames[catch_frame]
	elif walk_frame >= 0:
		var frames: Array[Texture2D] = _right_walk if velocity > 0.0 else _left_walk
		if not frames.is_empty():
			texture = frames[walk_frame]
	Props.oval_shadow(self, Vector2(player_x + 4.0, PLAYER_GROUND_Y - 6.0), Vector2(42.0, 9.0), 0.4)
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
	var rack := RACK_RECT
	var paper := Color("#f4eedc")
	var ledger_value: Variant = _snapshot.get("ledger", [])
	var ledger: Array = ledger_value if ledger_value is Array else []
	var finished_well := bool(_snapshot.get("finished", false)) and bool(_snapshot.get("success", false))
	if finished_well:
		draw_rect(rack.grow(6.0), Color(brass, 0.35))
	# Posts, two hook rails and a painted sign.
	Props.contact_shadow(self, Vector2(rack.position.x + rack.size.x * 0.5 + 6.0, rack.end.y), rack.size.x + 12.0, 0.45)
	Props.shaded_box(self, Rect2(rack.position.x + 6.0, rack.position.y + 18.0, 8.0, rack.size.y - 18.0), wood.darkened(0.2), 4.0)
	Props.shaded_box(self, Rect2(rack.end.x - 14.0, rack.position.y + 18.0, 8.0, rack.size.y - 18.0), wood.darkened(0.2), 4.0)
	Props.block_shadow(self, Rect2(rack.position.x, rack.position.y, rack.size.x, 22.0), Vector2(3.0, 4.0), 0.35)
	Props.wood_panel(self, Rect2(rack.position.x, rack.position.y, rack.size.x, 22.0), ink.lightened(0.08), true)
	_draw_label(rack.position + Vector2(10.0, 16.0), "失物帽架", paper, HORIZONTAL_ALIGNMENT_LEFT, 80, 13)
	# Streak lamps light one per consecutive centre catch.
	var combo := int(_snapshot.get("combo", 0))
	for lamp in 6:
		var lamp_center := Vector2(rack.position.x + 92.0 + float(lamp % 3) * 13.0, rack.position.y + 7.0 + float(lamp / 3) * 9.0)
		draw_circle(lamp_center, 3.5, brass.lightened(0.25) if lamp < combo else ink.lightened(0.3))
	for row in 2:
		var rail_y := rack.position.y + 46.0 + float(row) * 46.0
		draw_line(Vector2(rack.position.x + 8.0, rail_y + 2.0), Vector2(rack.end.x - 8.0, rail_y + 2.0), Props.deepen(brass), 3.0)
		draw_line(Vector2(rack.position.x + 8.0, rail_y), Vector2(rack.end.x - 8.0, rail_y), brass, 3.0)
		draw_line(Vector2(rack.position.x + 8.0, rail_y - 1.0), Vector2(rack.end.x - 8.0, rail_y - 1.0), Props.lighten(brass, 0.4), 1.0)
		for column in 3:
			var index := row * 3 + column
			var hook := Vector2(rack.position.x + 30.0 + float(column) * 38.0, rail_y)
			draw_arc(hook + Vector2(0.0, 5.0), 5.0, 0.0, PI, 10, brass.darkened(0.2), 2.0)
			var status := _ledger_status(ledger, index)
			if status == "center" or status == "edge":
				_draw_hat(index, hook + Vector2(0.0, 14.0), 0.0, brass, ink, 0.42)
				if status == "center":
					draw_circle(hook + Vector2(14.0, 2.0), 3.0, brass.lightened(0.35))
			elif status == "miss":
				# A small wave mark: this one fell into the sea.
				draw_arc(hook + Vector2(-5.0, 18.0), 5.0, PI, TAU, 8, Color("#5faab4"), 2.0)
				draw_arc(hook + Vector2(5.0, 18.0), 5.0, PI, TAU, 8, Color("#5faab4"), 2.0)

func _draw_score_note(ink: Color, paper: Color, brass: Color, coral: Color) -> void:
	var prompt := bottom_control_hint()
	var plate := Rect2(414.0, 653.0, 452.0, 42.0)
	# A stained deck sign screwed down at the boardwalk edge, with a brass tab.
	Props.block_shadow(self, plate, Vector2(4.0, 5.0), 0.4)
	Props.wood_panel(self, plate, ink.lightened(0.06), true)
	Props.metal_plate(self, Rect2(plate.position.x, plate.position.y, 8.0, plate.size.y), brass, false)
	_draw_label(Vector2(plate.position.x + 20.0, plate.position.y + 27.0), prompt, paper, HORIZONTAL_ALIGNMENT_LEFT, 416, 15)

## Airborne, unresolved hats in chart order; malformed entries are skipped.
func _airborne_hat_indices() -> Array[int]:
	var result: Array[int] = []
	var hats_value: Variant = _snapshot.get("hats", [])
	if not hats_value is Array:
		return result
	var hats: Array = hats_value
	for index in hats.size():
		if hats[index] is Dictionary and bool(hats[index].get("active", false)) and not bool(hats[index].get("resolved", false)):
			result.append(index)
	return result

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
	draw_string(FontProfiles.current_font(), position, text, alignment, width, size, color)

func _normalize_phase(value: String) -> String:
	return value if value == "dawn" or value == "noon" or value == "dusk" or value == "night" else "noon"
