extends Control
class_name BubblePhotoView

## Close portrait view for SG-25. Session owns inputs and uses the model as truth.
const BubblePhotoModelScript = preload("res://game/minigames/bubble_photo_model.gd")
const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const CAMERA_BODY := Rect2(190.0, 122.0, 900.0, 499.0)
const CAMERA_INSET := Rect2(199.0, 131.0, 882.0, 489.0)
const CAMERA_PLAQUE := Rect2(295.0, 130.0, 520.0, 30.0)
const SHUTTER_COLUMN := Rect2(986.0, 158.0, 88.0, 142.0)
const PREVIEW_LABEL := Rect2(734.0, 195.0, 236.0, 20.0)
const PLAQUE_TITLE_RECT := Rect2(295.0, 136.0, 520.0, 22.0)
const PLAQUE_LIGHT_RECT := Rect2(922.0, 136.0, 120.0, 22.0)
const SHUTTER_PRIMARY_RECT := Rect2(986.0, 207.0, 88.0, 20.0)
const SHUTTER_KEY_RECT := Rect2(986.0, 225.0, 88.0, 20.0)
const COVERAGE_TEXT_RECT := Rect2(986.0, 266.0, 88.0, 20.0)
const FOCUS_TEXT_RECT := Rect2(320.0, 195.0, 250.0, 21.0)
const FOCUS_BACKPLATE_RECT := Rect2(318.0, 193.0, 254.0, 25.0)
const PREVIEW_BACKPLATE_RECT := Rect2(732.0, 193.0, 240.0, 25.0)
const EXPOSURE_TEXT_RECT := Rect2(520.0, 584.0, 240.0, 24.0)
const PHOTO_RAIL := Rect2(205.0, 630.0, 870.0, 86.0)
const PHOTO_CARD_SIZE := Vector2(205.0, 76.0)
const PHOTO_CARD_START := Vector2(315.0, 636.0)
const PHOTO_CARD_STEP := 218.0
const BODY_SCREWS: Array[Vector2] = [Vector2(211,142), Vector2(1068,142), Vector2(211,608), Vector2(1068,608)]
const FAR_SHORE_LEFT: Array[Vector2] = [Vector2(334, 351), Vector2(334, 334), Vector2(374, 321), Vector2(412, 327), Vector2(444, 313), Vector2(478, 324), Vector2(498, 341), Vector2(498, 351)]
const FAR_SHORE_RIGHT: Array[Vector2] = [Vector2(802, 351), Vector2(802, 337), Vector2(833, 320), Vector2(862, 326), Vector2(892, 307), Vector2(919, 318), Vector2(946, 335), Vector2(946, 351)]
const MID_PIER_LEFT: Array[Vector2] = [Vector2(350, 374), Vector2(362, 365), Vector2(488, 365), Vector2(501, 374), Vector2(482, 382), Vector2(369, 382)]
const MID_PIER_RIGHT: Array[Vector2] = [Vector2(782, 372), Vector2(794, 364), Vector2(923, 364), Vector2(938, 374), Vector2(917, 382), Vector2(800, 382)]
const MID_SKIFF_LEFT: Array[Vector2] = [Vector2(344, 417), Vector2(390, 417), Vector2(381, 425), Vector2(352, 425)]
const MID_SKIFF_RIGHT: Array[Vector2] = [Vector2(900, 408), Vector2(944, 408), Vector2(935, 416), Vector2(908, 416)]
const MID_POST_XS: Array[float] = [370.0, 476.0, 805.0, 916.0]
const NEAR_TIDELINE: Array[Vector2] = [Vector2(334, 578), Vector2(392, 570), Vector2(462, 576), Vector2(520, 572), Vector2(596, 579), Vector2(680, 572), Vector2(758, 577), Vector2(826, 570), Vector2(892, 576), Vector2(946, 571), Vector2(946, 617), Vector2(334, 617)]
const PARALLAX_X_GAIN: Array[float] = [7.0, 16.0, 28.0]
const PARALLAX_Y_GAIN: Array[float] = [0.5, 1.0, 1.5]
const DEFAULT_APPEARANCE := {"skin":"warm", "species":"human", "hair":"windswept", "hair_color":"ink", "face":"curious"}
const DEFAULT_EQUIPPED := {"outfit":"outfit-tide", "hat":"hat-none"}
const SHELL_DARK := Color("#10262d")
const SHELL_INK := Color("#f3e1b5")
const READOUT_INK := Color("#fff4dc")
const READOUT_PANEL := Color("#142b31", 0.94)
const PHOTO_READOUT_PANEL := Color("#142b31")
const PRINT_PAPER := Color("#e9d8b2")
const PRINT_INK := Color("#2c3d40")

var _renderer: RefCounted
var _appearance: Dictionary = {}
var _equipped: Dictionary = {}
var _avatar_frames: Array[Texture2D] = []
var _avatar_regions: Array[Rect2i] = []
var _union_alpha_bounds := Rect2i(0, 0, 280, 360)
var _avatar_fps := 2.5
var _model_snapshot: Dictionary = {}
var _phase := "aim"
var _reduced_motion := false
var _time_phase := "noon"
var _initialized := false
var _harbor_geometry_cached := false
var _far_shore_left_points := PackedVector2Array()
var _far_shore_right_points := PackedVector2Array()
var _mid_pier_left_points := PackedVector2Array()
var _mid_pier_right_points := PackedVector2Array()
var _mid_skiff_left_points := PackedVector2Array()
var _mid_skiff_right_points := PackedVector2Array()
var _near_tideline_points := PackedVector2Array()
var _feedback_cache: Dictionary = {
	"coverage_text":"裁切", "coverage_shape":"open_frame", "center_text":"偏移",
	"center_shape":"offset_crosshair", "timing_text":"等待姿勢",
	"timing_shape":"aperture_closed", "timing_quality":0.0
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	initialize()

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_cache_harbor_geometry()
	_renderer = AvatarRendererScript.new()
	set_appearance(DEFAULT_APPEARANCE, DEFAULT_EQUIPPED)

func set_appearance(appearance: Dictionary, equipped: Dictionary) -> void:
	if not _initialized:
		_renderer = AvatarRendererScript.new()
		_initialized = true
	if appearance == _appearance and equipped == _equipped and not _avatar_frames.is_empty():
		return
	_appearance = appearance.duplicate(true)
	_equipped = equipped.duplicate(true)
	_build_avatar_cache()
	queue_redraw()

## `snapshot` is a stable model snapshot; keep its reference and treat it read-only.
func present_state(snapshot: Dictionary, phase: String, reduced: bool, timephase: String) -> void:
	initialize()
	_model_snapshot = snapshot
	_phase = phase if phase in ["aim", "exposure", "finished"] else str(snapshot.get("phase", "aim"))
	_reduced_motion = reduced
	_time_phase = _normalize_time_phase(timephase)
	_refresh_feedback()
	queue_redraw()

func playfield_rect() -> Rect2:
	return BubblePhotoModelScript.PLAY_RECT

func camera_frame_rect() -> Rect2:
	var value: Variant = _model_snapshot.get("frame_rect", Rect2())
	return value if value is Rect2 else Rect2()

func subject_draw_rect() -> Rect2:
	var target: Variant = _model_snapshot.get("target_box", Rect2())
	return _fit_rect(_union_alpha_bounds.size, target) if target is Rect2 else Rect2()

func avatar_alpha_bounds() -> Rect2i:
	return _union_alpha_bounds

func measured_subject_size() -> Vector2:
	return Vector2(_union_alpha_bounds.size)

func cached_avatar_frame_count() -> int:
	return _avatar_frames.size()

func pose_frame_for(snapshot: Dictionary) -> int:
	if _avatar_frames.is_empty():
		return 0
	var elapsed := float(snapshot.get("round_elapsed", 0.0))
	if str(snapshot.get("phase", "aim")) == "exposure":
		var round_index := int(snapshot.get("round", 0))
		var photos: Array = snapshot.get("photos", [])
		for index in range(photos.size() - 1, -1, -1):
			var shot: Dictionary = photos[index]
			if int(shot.get("round", -1)) == round_index and bool(shot.get("captured", false)):
				elapsed = float(shot.get("shutter_time", elapsed))
				break
	return posmod(int(floor(elapsed * _avatar_fps)), _avatar_frames.size())

func photo_card_rect(index: int) -> Rect2:
	if index < 0 or index >= 3:
		return Rect2()
	return Rect2(PHOTO_CARD_START + Vector2(PHOTO_CARD_STEP * index, 0.0), PHOTO_CARD_SIZE)

func photo_rail_rect() -> Rect2:
	return PHOTO_RAIL

func camera_body_rect() -> Rect2:
	return CAMERA_BODY

## The camera pan is taken only from the model's frame center. Distant paper-cut
## land moves least and the close shoreline moves most, with bounded offsets.
func harbor_layer_offset(layer: String) -> Vector2:
	var layer_index := -1
	match layer:
		"far": layer_index = 0
		"mid": layer_index = 1
		"near": layer_index = 2
		_: return Vector2.ZERO
	var center_value: Variant = _model_snapshot.get("frame_center", BubblePhotoModelScript.PLAY_RECT.get_center())
	var center: Vector2 = center_value if center_value is Vector2 else BubblePhotoModelScript.PLAY_RECT.get_center()
	var pan := center - BubblePhotoModelScript.PLAY_RECT.get_center()
	var pan_x := clampf(pan.x / 190.0, -1.0, 1.0)
	var pan_y := clampf(pan.y / 35.0, -1.0, 1.0)
	return Vector2(-pan_x * PARALLAX_X_GAIN[layer_index], -pan_y * PARALLAX_Y_GAIN[layer_index])

func harbor_layer_bounds(layer: String) -> Rect2:
	var bounds := Rect2()
	match layer:
		"far":
			bounds = _point_bounds(_far_shore_left_points).merge(_point_bounds(_far_shore_right_points))
			bounds = bounds.merge(Rect2(334, 338, 612, 19))
			bounds = bounds.merge(Rect2(384, 294, 8, 35))
			bounds = bounds.merge(Rect2(892.5, 276, 10, 39))
		"mid":
			bounds = _point_bounds(_mid_pier_left_points).merge(_point_bounds(_mid_pier_right_points))
			bounds = bounds.merge(_point_bounds(_mid_skiff_left_points)).merge(_point_bounds(_mid_skiff_right_points))
			bounds = bounds.merge(Rect2(350, 347, 588, 10))
			for post_x in MID_POST_XS:
				bounds = bounds.merge(Rect2(post_x, 374, 6, 25))
			bounds = bounds.merge(Rect2(366, 402, 2, 16)).merge(Rect2(920, 393, 2, 16))
		"near":
			bounds = _point_bounds(_near_tideline_points)
		_: return Rect2()
	return Rect2(bounds.position + harbor_layer_offset(layer), bounds.size).grow(1.0)

func _point_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var min_y := points[0].y
	var max_x := points[0].x
	var max_y := points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func camera_inset_rect() -> Rect2:
	return CAMERA_INSET

func camera_plaque_rect() -> Rect2:
	return CAMERA_PLAQUE

func shutter_column_rect() -> Rect2:
	return SHUTTER_COLUMN

func preview_label_rect() -> Rect2:
	return PREVIEW_LABEL

func readout_badge_rect(index: int) -> Rect2:
	if index < 0 or index >= 3:
		return Rect2()
	return Rect2(Vector2(320.0 + float(index) * 205.0, 160.0), Vector2(195.0, 31.0))

func control_label_width() -> float:
	return 88.0

func plaque_title_rect() -> Rect2:
	return PLAQUE_TITLE_RECT

func plaque_light_rect() -> Rect2:
	return PLAQUE_LIGHT_RECT

func shutter_primary_rect() -> Rect2:
	return SHUTTER_PRIMARY_RECT

func shutter_key_rect() -> Rect2:
	return SHUTTER_KEY_RECT

func coverage_text_rect() -> Rect2:
	return COVERAGE_TEXT_RECT

func focus_text_rect() -> Rect2:
	return FOCUS_TEXT_RECT

func focus_backplate_rect() -> Rect2:
	return FOCUS_BACKPLATE_RECT

func preview_backplate_rect() -> Rect2:
	return PREVIEW_BACKPLATE_RECT

func photo_readout_panel_color() -> Color:
	return PHOTO_READOUT_PANEL

func photo_readout_text_color() -> Color:
	return READOUT_INK

func exposure_text_rect() -> Rect2:
	return EXPOSURE_TEXT_RECT

func photo_text_rect(index: int) -> Rect2:
	var card := photo_card_rect(index)
	return Rect2(card.position + Vector2(63.0, 8.0), Vector2(card.size.x - 70.0, 62.0)) if card.size.x > 0.0 else Rect2()

func photo_label_text(index: int) -> Array[String]:
	if index < 0 or index >= 3:
		return []
	var photos: Array = _model_snapshot.get("photos", [])
	var lines: Array[String] = ["第 %d 張" % (index + 1), _photo_status_from(photos, index) if index < photos.size() else "尚未拍攝"]
	if index < photos.size() and photos[index] is Dictionary:
		var shot: Dictionary = photos[index]
		lines.append("%d 分  ·  %s" % [int(shot.get("score", 0)), photo_light_label(index)])
	else:
		lines.append(_light_label(_time_phase))
	return lines

func readout_label_text(index: int) -> String:
	var values: Array[String] = [
		"全身  " + str(_feedback_cache.coverage_text),
		"構圖  " + str(_feedback_cache.center_text),
		"姿勢  " + str(_feedback_cache.timing_text),
	]
	return values[index] if index >= 0 and index < values.size() else ""

func focus_label_text() -> String:
	return "合焦可拍" if bool(_model_snapshot.get("focus_available", false)) else "等待清晰姿勢"

func preview_label_text() -> String:
	return "預估分數  %03d" % int(_model_snapshot.get("score_preview", 0))

func plaque_title_text() -> String:
	return "港灣紀念相機  /  PORTRAIT 03"

func shutter_label_texts() -> Array[String]:
	return ["快門", "Space", "%d%% 入框" % roundi(float(_model_snapshot.get("coverage", 0.0)) * 100.0)]

func photo_body_rect(index: int) -> Rect2:
	var photos: Array = _model_snapshot.get("photos", [])
	if index < 0 or index >= photos.size():
		return Rect2()
	var shot: Dictionary = photos[index]
	if not bool(shot.get("captured", false)):
		return Rect2()
	var card := photo_card_rect(index)
	var print_rect := Rect2(card.position + Vector2(8.0, 7.0), Vector2(48.0, 62.0))
	var target: Variant = shot.get("target_box", Rect2())
	return _fit_rect(_union_alpha_bounds.size, Rect2(print_rect.position, print_rect.size)) if target is Rect2 else Rect2()

func photo_status_text(index: int) -> String:
	var shot := _photo_at(index)
	if shot.is_empty():
		return "等待拍攝" if index >= _photo_count() else "未取得照片"
	if not bool(shot.get("captured", false)):
		return "錯過快門"
	if bool(shot.get("perfect", false)):
		return "完整・置中・合焦"
	if not bool(shot.get("qualified", false)):
		return "構圖未達標"
	return "合照合格"

func photo_light_label(index: int) -> String:
	var shot := _photo_at(index)
	return _light_label(str(shot.get("time_of_day", _time_phase))) if not shot.is_empty() else _light_label(_time_phase)

func light_label() -> String:
	return _light_label(_time_phase)

func semantic_feedback() -> Dictionary:
	return _feedback_cache

func _refresh_feedback() -> void:
	var coverage := float(_model_snapshot.get("coverage", 0.0))
	var centering := float(_model_snapshot.get("centering", 0.0))
	var timing := float(_model_snapshot.get("timing_quality", 0.0))
	_feedback_cache["coverage_text"] = "完整" if coverage >= 0.999 else ("入框" if coverage >= 0.80 else "裁切")
	_feedback_cache["coverage_shape"] = "closed_frame" if coverage >= 0.999 else ("partial_frame" if coverage >= 0.80 else "cropped_frame")
	_feedback_cache["center_text"] = "置中" if centering >= 0.92 else "偏移"
	_feedback_cache["center_shape"] = "balanced_crosshair" if centering >= 0.92 else "offset_crosshair"
	_feedback_cache["timing_text"] = "合焦" if bool(_model_snapshot.get("focus_available", false)) else "等待姿勢"
	_feedback_cache["timing_shape"] = "aperture_open" if bool(_model_snapshot.get("focus_available", false)) else "aperture_closed"
	_feedback_cache["timing_quality"] = timing

func shows_reduced_motion() -> bool:
	return _reduced_motion

func exposure_flash_enabled() -> bool:
	return _phase == "exposure" and not _reduced_motion

func light_tint(time_of_day: String) -> Color:
	match _normalize_time_phase(time_of_day):
		"dawn": return Color(1.0, 0.94, 0.84)
		"dusk": return Color(1.0, 0.86, 0.78)
		"night": return Color(0.84, 0.92, 1.0)
		_: return Color.WHITE

func _draw() -> void:
	if not _initialized:
		return
	_draw_camera_shell()
	_draw_harbor_view()
	_draw_character()
	_draw_camera_frame()
	_draw_camera_controls()
	_draw_readouts()
	_draw_photo_rail()

func _draw_camera_shell() -> void:
	draw_rect(CAMERA_BODY, SHELL_DARK, true)
	# A stepped molded shell and inset glass lip make this a camera apparatus,
	# while keeping all hardware outside the scored image window.
	draw_rect(Rect2(CAMERA_BODY.position + Vector2(3, 3), CAMERA_BODY.size - Vector2(6, 6)), Color("#183a3e"), false, 2.0)
	draw_rect(CAMERA_BODY, Color("#4e8990"), false, 4.0)
	draw_rect(CAMERA_INSET, Color("#24464a"), false, 2.0)
	draw_line(Vector2(CAMERA_BODY.position.x + 18, 187), Vector2(CAMERA_BODY.position.x + 18, 574), Color("#6f9991", 0.25), 1.0)
	draw_line(Vector2(CAMERA_BODY.end.x - 18, 187), Vector2(CAMERA_BODY.end.x - 18, 574), Color("#6f9991", 0.25), 1.0)
	# Restrained molded ribs and brass screws make the camera body read as one object.
	for rib in 2:
		var y := 137.0 + float(rib) * 7.0
		draw_line(Vector2(224.0, y), Vector2(278.0, y), Color("#698987", 0.54), 2.0)
	for point in BODY_SCREWS:
		draw_circle(point, 4.0, Color("#c89454"))
		draw_circle(point, 1.5, Color("#f1d39a"))
	draw_string(ThemeDB.fallback_font, PLAQUE_TITLE_RECT.position + Vector2(0.0, 18.0), plaque_title_text(), HORIZONTAL_ALIGNMENT_LEFT, PLAQUE_TITLE_RECT.size.x, 15, SHELL_INK)
	draw_string(ThemeDB.fallback_font, PLAQUE_LIGHT_RECT.position + Vector2(0.0, 17.0), light_label(), HORIZONTAL_ALIGNMENT_RIGHT, PLAQUE_LIGHT_RECT.size.x, 14, READOUT_INK)
	draw_rect(PHOTO_RAIL, Color("#18353a"), true)
	draw_line(PHOTO_RAIL.position, Vector2(PHOTO_RAIL.end.x, PHOTO_RAIL.position.y), Color("#c89454"), 2.0)

func _draw_harbor_view() -> void:
	var sky := Color("#d7cba9")
	var water := Color("#628d91")
	var shore := Color("#b99a70")
	match _time_phase:
		"dawn": sky = Color("#d8b69a"); water = Color("#567f85"); shore = Color("#b38f71")
		"dusk": sky = Color("#bd8f83"); water = Color("#476e79"); shore = Color("#997b6a")
		"night": sky = Color("#435965"); water = Color("#263f50"); shore = Color("#706f68")
		_: pass
	var window := BubblePhotoModelScript.PLAY_RECT
	draw_rect(Rect2(window.position - Vector2(4.0, 4.0), window.size + Vector2(8.0, 5.0)), Color("#0a1a20"), true)
	draw_rect(Rect2(window.position - Vector2(3.0, 3.0), window.size + Vector2(6.0, 4.0)), Color("#ad8752"), false, 1.0)
	draw_rect(window, sky, true)
	draw_rect(Rect2(window.position.x, 356.0, window.size.x, window.end.y - 356.0), water, true)
	# Three cut-paper planes create a small optical postcard. Each is translated
	# only by the model's actual frame pan; no ambient or independent camera drift.
	var far_offset := harbor_layer_offset("far")
	draw_set_transform(far_offset, 0.0, Vector2.ONE)
	draw_rect(Rect2(334.0, 338.0, 612.0, 19.0), shore.darkened(0.03), true)
	draw_colored_polygon(_far_shore_left_points, Color("#8eaa9c"))
	draw_colored_polygon(_far_shore_right_points, Color("#91ad9e"))
	# Tiny beacon silhouettes on the far headlands reinforce the harbor scale.
	draw_rect(Rect2(384, 298, 8, 31), Color("#7b8172"), true)
	draw_rect(Rect2(379, 294, 18, 7), Color("#e6c890"), true)
	draw_rect(Rect2(893, 285, 9, 30), Color("#6f8178"), true)
	draw_circle(Vector2(897.5, 281), 5.0, Color("#d3b873"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var mid_offset := harbor_layer_offset("mid")
	draw_set_transform(mid_offset, 0.0, Vector2.ONE)
	draw_rect(Rect2(350, 347, 588, 10), shore, true)
	draw_colored_polygon(_mid_pier_left_points, Color("#5f665c"))
	draw_colored_polygon(_mid_pier_right_points, Color("#5f665c"))
	for post_x in MID_POST_XS:
		draw_rect(Rect2(post_x, 374, 6, 25), Color("#756049"), true)
	# Two small moored skiffs stay near the side margins, away from the full-body
	# scoring box; their paper hulls sit behind the avatar and focus frame.
	draw_colored_polygon(_mid_skiff_left_points, Color("#b8795d"))
	draw_colored_polygon(_mid_skiff_right_points, Color("#b8795d"))
	draw_line(Vector2(367, 402), Vector2(367, 417), Color("#f0ddb2"), 1.0)
	draw_line(Vector2(921, 393), Vector2(921, 408), Color("#f0ddb2"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(window.position.x, 356.0, window.size.x, 5.0), shore, true)
	var near_offset := harbor_layer_offset("near")
	draw_set_transform(near_offset, 0.0, Vector2.ONE)
	draw_colored_polygon(_near_tideline_points, Color("#a98b69"))
	# A few restrained tide cuts and edge reeds give the close plane material
	# without entering the avatar's target-box band (which ends above y=540).
	for line in 3:
		var line_y := 578.0 + float(line) * 11.0
		draw_line(Vector2(384, line_y), Vector2(470 + line * 31, line_y + 2), Color("#d0b88f", 0.52), 1.0)
		draw_line(Vector2(794 - line * 25, line_y + 3), Vector2(884, line_y), Color("#d0b88f", 0.46), 1.0)
	for side in 2:
		var x := 350.0 if side == 0 else 930.0
		var y := 595.0
		draw_line(Vector2(x, y), Vector2(x + (4.0 if side == 0 else -4.0), y - 21.0), Color("#526e60"), 3.0)
		draw_line(Vector2(x + (2.0 if side == 0 else -2.0), y - 11.0), Vector2(x + (14.0 if side == 0 else -14.0), y - 15.0), Color("#6f8870"), 2.0)
		draw_line(Vector2(x + (3.0 if side == 0 else -3.0), y - 6.0), Vector2(x + (12.0 if side == 0 else -12.0), y - 2.0), Color("#6f8870"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _time_phase == "night":
		draw_circle(Vector2(834, 235), 23.0, Color("#efd39c"))
		draw_circle(Vector2(844, 226), 21.0, sky)
		for lamp_index in 2:
			var lamp := Vector2(355.0, 355.0) if lamp_index == 0 else Vector2(900.0, 357.0)
			draw_line(lamp + Vector2(0, -35), lamp + Vector2(0, 0), Color("#4e4940"), 4.0)
			draw_circle(lamp + Vector2(0, -38), 7.0, Color("#f2cc84"))
	else:
		var sun_color := Color("#fff0be") if _time_phase == "noon" else Color("#f4c48d")
		draw_circle(Vector2(847, 231 if _time_phase == "dawn" else 280), 24.0, sun_color)
	# The image area is visibly a camera negative with a safe inset, not a second game backdrop.
	draw_rect(window, Color("#10262d", 0.22 if _time_phase == "night" else 0.045), true)
	draw_rect(window, Color("#e0c88e"), false, 2.0)

func _draw_readouts() -> void:
	var status := semantic_feedback()
	_draw_badge(readout_badge_rect(0), "全身  " + str(status.coverage_text), str(status.coverage_shape))
	_draw_badge(readout_badge_rect(1), "構圖  " + str(status.center_text), str(status.center_shape))
	_draw_badge(readout_badge_rect(2), "姿勢  " + str(status.timing_text), str(status.timing_shape))
	draw_rect(FOCUS_BACKPLATE_RECT, PHOTO_READOUT_PANEL, true)
	draw_rect(PREVIEW_BACKPLATE_RECT, PHOTO_READOUT_PANEL, true)
	draw_string(ThemeDB.fallback_font, FOCUS_TEXT_RECT.position + Vector2(0.0, 16.0), focus_label_text(), HORIZONTAL_ALIGNMENT_LEFT, FOCUS_TEXT_RECT.size.x, 14, READOUT_INK)
	draw_string(ThemeDB.fallback_font, PREVIEW_LABEL.position + Vector2(0.0, 16.0), preview_label_text(), HORIZONTAL_ALIGNMENT_RIGHT, PREVIEW_LABEL.size.x, 14, READOUT_INK)

func _draw_badge(rect: Rect2, label: String, shape: String) -> void:
	draw_rect(rect, READOUT_PANEL, true)
	draw_rect(rect, Color("#d6bd81", 0.74), false, 1.0)
	_draw_status_shape(shape, rect.position + Vector2(17, 15))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(31, 21), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36, 15, READOUT_INK)

func _draw_status_shape(shape: String, center: Vector2) -> void:
	match shape:
		"closed_frame":
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color("#9fd4bb"), false, 2.0)
		"partial_frame":
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color("#efbd83"), false, 1.0)
			draw_line(center + Vector2(-2, -8), center + Vector2(-2, 8), Color("#efbd83"), 2.0)
		"cropped_frame":
			for c_index in 4:
				var c := Vector2(-6.0 if c_index % 2 == 0 else 6.0, -6.0 if c_index < 2 else 6.0)
				draw_line(center + c, center + c + Vector2(-signf(c.x)*4, 0), Color("#efbd83"), 2.0)
		"balanced_crosshair":
			draw_arc(center, 7.0, 0.0, TAU, 16, Color("#9fd4bb"), 1.5)
			draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color("#9fd4bb"), 1.0)
		"offset_crosshair":
			draw_arc(center + Vector2(3, -2), 7.0, 0.0, TAU, 16, Color("#efbd83"), 1.5)
			draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color("#efbd83"), 1.0)
		"aperture_open":
			draw_circle(center, 7.0, Color("#9fd4bb"))
			draw_circle(center, 3.0, Color("#19363c"))
		_:
			draw_circle(center, 7.0, Color("#efbd83"), false, 2.0)
			draw_line(center + Vector2(-5, 5), center + Vector2(5, -5), Color("#efbd83"), 2.0)

func _draw_character() -> void:
	if _avatar_frames.is_empty():
		return
	var target: Variant = _model_snapshot.get("target_box", Rect2())
	if not target is Rect2:
		return
	var frame := pose_frame_for(_model_snapshot)
	var texture: Texture2D = _avatar_frames[frame]
	draw_texture_rect_region(texture, _fit_rect(_union_alpha_bounds.size, target), Rect2(_union_alpha_bounds), light_tint(_time_phase), false, true)

func _draw_camera_frame() -> void:
	var rect := camera_frame_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	draw_rect(rect, Color("#e9dfbd", 0.78 if _reduced_motion else 0.50), false, 2.0)
	# Thirds guides are subtle; the full subject box remains the scored boundary.
	for i in 2:
		var division := float(i + 1)
		var x: float = rect.position.x + rect.size.x * division / 3.0
		var y: float = rect.position.y + rect.size.y * division / 3.0
		draw_line(Vector2(x, rect.position.y + 3), Vector2(x, rect.end.y - 3), Color("#edf0d7", 0.20), 1.0)
		draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y), Color("#edf0d7", 0.20), 1.0)
	var corner_color := Color("#f4d996") if bool(_model_snapshot.get("focus_available", false)) else Color("#d4dfd6")
	for corner_index in 4:
		var corner := Vector2(rect.position.x if corner_index % 2 == 0 else rect.end.x, rect.position.y if corner_index < 2 else rect.end.y)
		var sx := 1.0 if corner.x == rect.position.x else -1.0
		var sy := 1.0 if corner.y == rect.position.y else -1.0
		draw_line(corner, corner + Vector2(18.0 * sx, 0.0), corner_color, 4.0)
		draw_line(corner, corner + Vector2(0.0, 18.0 * sy), corner_color, 4.0)

func _draw_camera_controls() -> void:
	var focus := bool(_model_snapshot.get("focus_available", false))
	var button_color := Color("#d9ad67") if focus else Color("#906f4f")
	draw_rect(SHUTTER_COLUMN, Color("#19383c"), true)
	draw_rect(SHUTTER_COLUMN, Color("#5b817c"), false, 1.0)
	var button_depth := 2.0 if _phase == "exposure" else 0.0
	var button_center := Vector2(1020.0, 184.0 + button_depth)
	draw_circle(button_center + Vector2(0.0, 3.0), 23.0, Color("#08171b"))
	draw_circle(button_center, 22.0, Color("#b48c57"))
	draw_circle(button_center, 18.0, Color("#0d2026"))
	draw_circle(button_center + Vector2(0.0, button_depth * 0.35), 15.0, button_color)
	draw_circle(button_center + Vector2(-5.0, -5.0), 4.5, Color("#fff0c5", 0.82))
	if exposure_flash_enabled():
		draw_arc(button_center, 28.0, 0.0, TAU, 28, Color("#f5dda4"), 2.0)
		for ray in 4:
			var angle := TAU * float(ray) / 4.0 + PI / 4.0
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(button_center + direction * 31.0, button_center + direction * 36.0, Color("#f5dda4"), 2.0)
	draw_string(ThemeDB.fallback_font, SHUTTER_PRIMARY_RECT.position + Vector2(0.0, 15.0), "快門", HORIZONTAL_ALIGNMENT_CENTER, SHUTTER_PRIMARY_RECT.size.x, 13, READOUT_INK)
	draw_string(ThemeDB.fallback_font, SHUTTER_KEY_RECT.position + Vector2(0.0, 15.0), "Space", HORIZONTAL_ALIGNMENT_CENTER, SHUTTER_KEY_RECT.size.x, 13, Color("#e5d7b7"))
	draw_rect(Rect2(994, 256, 52, 7), Color("#0d2026"), true)
	draw_rect(Rect2(996, 258, 48.0 * clampf(float(_model_snapshot.get("coverage", 0.0)), 0.0, 1.0), 3), Color("#9fd4bb") if float(_model_snapshot.get("coverage", 0.0)) >= 0.8 else Color("#e6ad75"), true)
	draw_string(ThemeDB.fallback_font, COVERAGE_TEXT_RECT.position + Vector2(0.0, 14.0), "%d%% 入框" % roundi(float(_model_snapshot.get("coverage", 0.0)) * 100.0), HORIZONTAL_ALIGNMENT_CENTER, COVERAGE_TEXT_RECT.size.x, 12, READOUT_INK)
	if _phase == "exposure":
		draw_rect(BubblePhotoModelScript.PLAY_RECT, Color("#fff4db", 0.78), false, 3.0)
		draw_string(ThemeDB.fallback_font, EXPOSURE_TEXT_RECT.position + Vector2(0.0, 18.0), "曝光中  ·  相片正在顯影", HORIZONTAL_ALIGNMENT_CENTER, EXPOSURE_TEXT_RECT.size.x, 15, READOUT_INK)

func _draw_photo_rail() -> void:
	var photos: Array = _model_snapshot.get("photos", [])
	for index in 3:
		var card := photo_card_rect(index)
		var has_photo := index < photos.size()
		draw_rect(card, PRINT_PAPER, true)
		draw_rect(card, Color("#c39257"), false, 2.0)
		var image_rect := Rect2(card.position + Vector2(8, 7), Vector2(48, 62))
		draw_rect(image_rect, Color("#637a79"), true)
		if has_photo:
			var shot: Dictionary = photos[index]
			if bool(shot.get("captured", false)) and not _avatar_frames.is_empty():
				var texture: Texture2D = _avatar_frames[_pose_frame_at(float(shot.get("shutter_time", 0.0)))]
				draw_texture_rect_region(texture, _fit_rect(_union_alpha_bounds.size, image_rect), Rect2(_union_alpha_bounds), light_tint(str(shot.get("time_of_day", "noon"))), false, true)
			else:
				draw_line(image_rect.position, image_rect.end, Color("#dba780"), 2.0)
				draw_line(Vector2(image_rect.end.x, image_rect.position.y), Vector2(image_rect.position.x, image_rect.end.y), Color("#dba780"), 2.0)
		var text_rect := photo_text_rect(index)
		var labels := photo_label_text(index)
		draw_string(ThemeDB.fallback_font, text_rect.position + Vector2(0.0, 14.0), labels[0], HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, 13, PRINT_INK)
		draw_string(ThemeDB.fallback_font, text_rect.position + Vector2(0.0, 33.0), labels[1], HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, 13, Color("#263a3d"))
		draw_string(ThemeDB.fallback_font, text_rect.position + Vector2(0.0, 52.0), labels[2], HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x, 12, Color("#17272b"))

func _build_avatar_cache() -> void:
	_avatar_frames.clear()
	_avatar_regions.clear()
	var count := int(_renderer.authored_frame_count("idle", "front"))
	if count <= 0:
		count = 3 # AvatarRenderer's built-in idle fallback exposes three poses.
	count = clampi(count, 1, 8)
	_avatar_fps = float(_renderer.authored_action_fps("idle", "front"))
	if _avatar_fps <= 0.0:
		_avatar_fps = 2.5
	var union := Rect2i()
	var has_bounds := false
	for frame in count:
		var texture: Texture2D = _renderer.texture(_appearance, _equipped, "front", frame, "idle")
		_avatar_frames.append(texture)
		var region := _measure_alpha_bounds(texture)
		_avatar_regions.append(region)
		if region.size.x > 0 and region.size.y > 0:
			union = region if not has_bounds else union.merge(region)
			has_bounds = true
	_union_alpha_bounds = union if has_bounds else Rect2i(0, 0, 280, 360)

func _cache_harbor_geometry() -> void:
	if _harbor_geometry_cached:
		return
	_harbor_geometry_cached = true
	_far_shore_left_points = PackedVector2Array(FAR_SHORE_LEFT)
	_far_shore_right_points = PackedVector2Array(FAR_SHORE_RIGHT)
	_mid_pier_left_points = PackedVector2Array(MID_PIER_LEFT)
	_mid_pier_right_points = PackedVector2Array(MID_PIER_RIGHT)
	_mid_skiff_left_points = PackedVector2Array(MID_SKIFF_LEFT)
	_mid_skiff_right_points = PackedVector2Array(MID_SKIFF_RIGHT)
	_near_tideline_points = PackedVector2Array(NEAR_TIDELINE)

func _measure_alpha_bounds(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2i()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1) if max_x >= min_x and max_y >= min_y else Rect2i()

func _fit_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or target.size.x <= 0.0 or target.size.y <= 0.0:
		return Rect2()
	var scale := minf(target.size.x / source_size.x, target.size.y / source_size.y)
	var fitted_size := source_size * scale
	return Rect2(target.position + (target.size - fitted_size) * 0.5, fitted_size)

func _photo_at(index: int) -> Dictionary:
	var photos: Array = _model_snapshot.get("photos", [])
	return photos[index] if index >= 0 and index < photos.size() else {}

func _photo_status_from(photos: Array, index: int) -> String:
	var shot: Dictionary = photos[index]
	if not bool(shot.get("captured", false)):
		return "錯過快門"
	if bool(shot.get("perfect", false)):
		return "完整・置中・合焦"
	if not bool(shot.get("qualified", false)):
		return "構圖未達標"
	return "合照合格"

func _photo_count() -> int:
	var photos: Array = _model_snapshot.get("photos", [])
	return photos.size()

func _pose_frame_at(time: float) -> int:
	return posmod(int(floor(time * _avatar_fps)), maxi(1, _avatar_frames.size()))

func _normalize_time_phase(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["dawn", "sunrise"]: return "dawn"
	if normalized in ["dusk", "sunset", "twilight"]: return "dusk"
	if normalized in ["night", "evening"]: return "night"
	return "noon"

func _light_label(value: String) -> String:
	match value:
		"dawn": return "晨光"
		"dusk", "sunset": return "暮色"
		"night": return "夜燈"
		_: return "日光"
