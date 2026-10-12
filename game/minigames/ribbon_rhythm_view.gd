extends Control
class_name RibbonRhythmView

signal action_pressed(action: String)
signal action_released(action: String)

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const FONT: Font = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const CharacterAnimationLibrary = preload("res://game/world/character_animation_library.gd")
const STAGE_BOUNDS := Rect2(78.0, 142.0, 1124.0, 486.0)
const TOP_HUD_SAFE := Rect2(24.0, 12.0, 1232.0, 116.0)
const BOTTOM_HUD_SAFE := Rect2(24.0, 640.0, 1232.0, 68.0)
const MAIN_AVATAR_RECT := Rect2(503.0, 273.0, 230.0, 296.0)
const PARTNER_AVATAR_RECT := Rect2(812.0, 368.0, 128.0, 184.0)
const JUMP_AVATAR_RECT := Rect2(503.0, 246.0, 230.0, 296.0)
const CURRENT_CUE_RECT := Rect2(133.0, 229.0, 170.0, 76.0)
const UPCOMING_CUE_RECTS := [Rect2(977.0, 229.0, 170.0, 76.0), Rect2(1018.0, 319.0, 132.0, 63.0)]
const BEAT_MARKER_COUNT := 8
const STRONG_BEATS := [0, 3, 5, 7]
const CONTROL_RECTS := {
	"left": Rect2(342.0, 647.0, 176.0, 50.0),
	"jump": Rect2(552.0, 647.0, 176.0, 50.0),
	"right": Rect2(762.0, 647.0, 176.0, 50.0),
}
const PALETTES := {
	"dawn": {"sky": Color("#342d49"), "wall": Color("#725467"), "curtain": Color("#913e5a"), "velvet": Color("#b55365"), "gold": Color("#edc27b"), "wood": Color("#7f563f"), "wood_light": Color("#bc8959"), "beam": Color("#f3c57e"), "accent": Color("#77c5bd"), "coral": Color("#e88977"), "text": Color("#f7ebd1")},
	"noon": {"sky": Color("#26364b"), "wall": Color("#435c70"), "curtain": Color("#7b334f"), "velvet": Color("#a84c60"), "gold": Color("#edbd70"), "wood": Color("#694732"), "wood_light": Color("#a8784d"), "beam": Color("#f6d891"), "accent": Color("#70c7bd"), "coral": Color("#e27b69"), "text": Color("#f6edda")},
	"dusk": {"sky": Color("#27263f"), "wall": Color("#59475d"), "curtain": Color("#73324f"), "velvet": Color("#a74b64"), "gold": Color("#d8a96b"), "wood": Color("#513c38"), "wood_light": Color("#896449"), "beam": Color("#e8ad8b"), "accent": Color("#69aaa9"), "coral": Color("#d97d75"), "text": Color("#eee3d1")},
	"night": {"sky": Color("#161e33"), "wall": Color("#29394e"), "curtain": Color("#542640"), "velvet": Color("#7f354e"), "gold": Color("#d9b77c"), "wood": Color("#382d35"), "wood_light": Color("#695041"), "beam": Color("#8eaec5"), "accent": Color("#65b9b4"), "coral": Color("#d77a77"), "text": Color("#e8e3d6")},
}
const POSE_NAMES: Array[String] = ["idle_front", "walk_left", "walk_right", "jump_front", "wave_front", "celebrate_front"]

var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _renderer: RefCounted
var _appearance: Dictionary = {}
var _equipped: Dictionary = {}
var _texture_cache: Dictionary = {}
var _companion_library
var _companion_idle_frames: Array[Texture2D] = []
var _companion_dance_frames: Array[Texture2D] = []
var _companion_static_texture: Texture2D
var _companion_idle_fps := 3.0
var _companion_dance_fps := 6.0
var _companion_dance_active := false
var _companion_dance_complete := false
var _companion_dance_elapsed := 0.0
var _last_snapshot_elapsed := 0.0
var _last_snapshot_index := 0
var _last_snapshot_ended := false
var _assets_ready := false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _process(delta: float) -> void:
	if not _companion_dance_active or _reduced_motion or not is_finite(delta) or delta <= 0.0:
		return
	_companion_dance_elapsed += minf(delta, 0.1)
	if _companion_dance_elapsed >= float(_companion_dance_frames.size()) / maxf(0.01, _companion_dance_fps):
		_companion_dance_active = false
		_companion_dance_complete = true
	queue_redraw()

func configure_avatar(appearance: Dictionary, equipped: Dictionary) -> void:
	_appearance = appearance.duplicate(true)
	_equipped = equipped.duplicate(true)
	_texture_cache.clear()
	_renderer = AvatarRenderer.new()
	_prepare_companion()
	_assets_ready = _validate_authored_avatar_actions()
	queue_redraw()

func update_frame(snapshot: Dictionary, time_of_day: String = "noon", reduced_motion: bool = false) -> void:
	var elapsed := float(snapshot.get("elapsed", 0.0))
	var index := int(snapshot.get("gesture_index", 0))
	var ended := bool(snapshot.get("ended", false))
	if elapsed + 0.00001 < _last_snapshot_elapsed or index < _last_snapshot_index or (not ended and _last_snapshot_ended):
		_reset_companion_performance()
	var successful_finish := ended and bool(snapshot.get("success", false)) and index >= BEAT_MARKER_COUNT
	if successful_finish and not _last_snapshot_ended and not _companion_dance_complete:
		_companion_dance_active = not _companion_dance_frames.is_empty()
		_companion_dance_elapsed = 0.0
	_snapshot = snapshot
	_last_snapshot_elapsed = elapsed
	_last_snapshot_index = index
	_last_snapshot_ended = ended
	_time_phase = time_of_day if PALETTES.has(time_of_day) else "noon"
	_reduced_motion = reduced_motion
	queue_redraw()

func screen_to_design(point: Vector2) -> Vector2:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if scale_factor <= 0.0:
		return point
	var offset := (size - DESIGN_SIZE * scale_factor) * 0.5
	return (point - offset) / scale_factor

func design_to_screen(point: Vector2) -> Vector2:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if scale_factor <= 0.0:
		return point
	return (size - DESIGN_SIZE * scale_factor) * 0.5 + point * scale_factor

func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, DESIGN_SIZE)

func playfield_rect() -> Rect2:
	return STAGE_BOUNDS

func avatar_bounds_for_pose(pose: String, partner: bool = false) -> Rect2:
	if not POSE_NAMES.has(pose):
		return Rect2()
	if partner:
		return PARTNER_AVATAR_RECT
	return JUMP_AVATAR_RECT if pose == "jump_front" else MAIN_AVATAR_RECT

func available_pose_names() -> Array[String]:
	return POSE_NAMES.duplicate()

func companion_bounds() -> Rect2:
	return PARTNER_AVATAR_RECT

func companion_identity() -> String:
	return "imp"

func companion_display_name() -> String:
	return "小角"

func companion_assets_ready() -> bool:
	return _companion_static_texture != null and not _companion_idle_frames.is_empty()

func companion_idle_frame_count() -> int:
	return _companion_idle_frames.size()

func companion_dance_frame_count() -> int:
	return _companion_dance_frames.size()

func companion_cached_texture_count() -> int:
	return int(_companion_library.cached_texture_count()) if _companion_library != null else 0

func companion_frame_index() -> int:
	return _companion_frame_index(float(_snapshot.get("elapsed", 0.0)))

func companion_is_dancing() -> bool:
	return _companion_dance_active

func beat_marker_rect(index: int) -> Rect2:
	if index < 0 or index >= BEAT_MARKER_COUNT:
		return Rect2()
	var center_y := 600.0 + (3.0 if index % 2 == 1 else 0.0)
	return Rect2(Vector2(184.0 + float(index) * 130.0 - 12.0, center_y - 11.0), Vector2(24.0, 32.0))

func beat_marker_state(index: int, snapshot: Dictionary = {}) -> String:
	if index < 0 or index >= BEAT_MARKER_COUNT:
		return "invalid"
	var state := snapshot if not snapshot.is_empty() else _snapshot
	var current := int(state.get("gesture_index", 0))
	var trail: Variant = state.get("ribbon_trail", [])
	if index < current:
		if trail is Array:
			for entry in trail:
				if entry is Dictionary and int(entry.get("index", -1)) == index:
					return "complete"
		return "missed"
	if index == current and current < BEAT_MARKER_COUNT and not bool(state.get("ended", false)):
		return "current"
	return "future"

func avatar_assets_ready() -> bool:
	return _assets_ready

func visual_motion_enabled() -> bool:
	return not _reduced_motion

func palette_phase() -> String:
	return _time_phase

func visual_cue_state(snapshot: Dictionary = {}) -> Dictionary:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return {
		"motion_enabled": not _reduced_motion,
		"gesture_index": int(state.get("gesture_index", 0)),
		"current_gesture": state.get("current_gesture", {}),
		"upcoming": state.get("upcoming", []),
		"elapsed": float(state.get("elapsed", 0.0)),
		"held_action": str(state.get("hold_action", "")),
	}

func control_center(action: String) -> Vector2:
	if not CONTROL_RECTS.has(action):
		return Vector2.ZERO
	return (CONTROL_RECTS[action] as Rect2).get_center()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var action := _action_for_key(event.keycode)
		if action.is_empty() or event.echo:
			return
		if event.pressed:
			action_pressed.emit(action)
		else:
			action_released.emit(action)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var action := _action_at(screen_to_design(event.position))
		if action.is_empty():
			return
		if event.pressed:
			action_pressed.emit(action)
		else:
			action_released.emit(action)
		accept_event()

func _action_for_key(keycode: Key) -> String:
	match keycode:
		KEY_LEFT, KEY_A: return "left"
		KEY_RIGHT, KEY_D: return "right"
		KEY_SPACE, KEY_UP, KEY_W: return "jump"
	return ""

func _action_at(point: Vector2) -> String:
	for action in ["left", "jump", "right"]:
		if (CONTROL_RECTS[action] as Rect2).has_point(point):
			return action
	return ""

func _validate_authored_avatar_actions() -> bool:
	if _renderer == null:
		return false
	return _renderer.walk_frame_count("left") > 0 and _renderer.walk_frame_count("right") > 0 \
		and _renderer.has_authored_action("jump", "front") and _renderer.has_authored_action("wave", "front") \
		and _renderer.texture(_appearance, _equipped, "front", 0, "celebrate") != null

func _prepare_companion() -> void:
	_companion_library = CharacterAnimationLibrary.new()
	_companion_idle_frames.clear()
	_companion_dance_frames.clear()
	_companion_static_texture = null
	_companion_dance_active = false
	_companion_dance_complete = false
	_companion_dance_elapsed = 0.0
	_last_snapshot_elapsed = float(_snapshot.get("elapsed", 0.0))
	_last_snapshot_index = int(_snapshot.get("gesture_index", 0))
	_last_snapshot_ended = bool(_snapshot.get("ended", false))
	var idle: Dictionary = _companion_library.get_sequence("imp", "idle", "front")
	var dance: Dictionary = _companion_library.get_sequence("imp", "dance", "front")
	_companion_idle_fps = maxf(0.01, float(idle.get("fps", 3.0)))
	_companion_dance_fps = maxf(0.01, float(dance.get("fps", 6.0)))
	_append_sequence_textures(idle, _companion_idle_frames)
	_append_sequence_textures(dance, _companion_dance_frames)
	if not _companion_idle_frames.is_empty():
		_companion_static_texture = _companion_idle_frames[0]
	elif not _companion_dance_frames.is_empty():
		_companion_static_texture = _companion_dance_frames[0]
		_companion_idle_frames.append(_companion_static_texture)
		push_warning("RibbonRhythmView: imp idle frames are unavailable; using its authored dance first frame as a static identity fallback.")
	else:
		push_warning("RibbonRhythmView: authored imp companion textures are unavailable; keeping the partner slot empty rather than duplicating the traveller.")
	if _companion_dance_frames.is_empty():
		push_warning("RibbonRhythmView: authored imp dance is unavailable; 小角 will remain in a static authored imp pose on success.")

func _append_sequence_textures(sequence: Dictionary, destination: Array[Texture2D]) -> void:
	var frames: Variant = sequence.get("frames", [])
	if not frames is Array:
		return
	for frame_value in frames:
		if not frame_value is Dictionary:
			continue
		var texture := frame_value.get("texture") as Texture2D
		if texture != null:
			destination.append(texture)

func _reset_companion_performance() -> void:
	_companion_dance_active = false
	_companion_dance_complete = false
	_companion_dance_elapsed = 0.0

func _companion_frame_index(elapsed: float) -> int:
	if _companion_dance_active and not _companion_dance_frames.is_empty():
		if _reduced_motion:
			return _companion_dance_frames.size() - 1
		return mini(floori(maxf(0.0, _companion_dance_elapsed) * _companion_dance_fps), _companion_dance_frames.size() - 1)
	if _companion_idle_frames.is_empty() or _reduced_motion:
		return 0
	return posmod(floori(maxf(0.0, elapsed) * _companion_idle_fps), _companion_idle_frames.size())

func _pose_data(pose: String, elapsed: float) -> Dictionary:
	if pose == "walk_left" or pose == "walk_right":
		var direction := "left" if pose == "walk_left" else "right"
		var frame_count := maxi(1, _renderer.walk_frame_count(direction)) if _renderer != null else 1
		var frame := 0 if _reduced_motion else posmod(floori(maxf(0.0, elapsed) * 7.0), frame_count)
		return {"action": "walk", "direction": direction, "frame": frame}
	if pose == "jump_front":
		var jump_index := int(_snapshot.get("gesture_index", 0))
		var cue_time := float(_snapshot.get("cue_times", [])[jump_index]) if jump_index < _snapshot.get("cue_times", []).size() else elapsed
		var jump_age := maxf(0.0, elapsed - cue_time)
		var frame := 0 if _reduced_motion else clampi(floori(jump_age * 12.0), 0, maxi(0, _renderer.authored_frame_count("jump", "front") - 1)) if _renderer != null else 0
		return {"action": "jump", "direction": "front", "frame": frame}
	if pose == "wave_front":
		var count := maxi(1, _renderer.authored_frame_count("wave", "front")) if _renderer != null else 1
		var frame := 0 if _reduced_motion else posmod(floori(elapsed * 4.0), count)
		return {"action": "wave", "direction": "front", "frame": frame}
	if pose == "celebrate_front":
		var count := maxi(1, _renderer.authored_frame_count("celebrate", "front")) if _renderer != null else 1
		var frame := 0 if _reduced_motion else posmod(floori(elapsed * 3.0), count)
		return {"action": "celebrate", "direction": "front", "frame": frame}
	return {"action": "idle", "direction": "front", "frame": 0}

func _avatar_texture(pose: String, elapsed: float, _partner: bool = false) -> Texture2D:
	if _renderer == null:
		return null
	var pose_data := _pose_data(pose, elapsed)
	var action := str(pose_data.action)
	var direction := str(pose_data.direction)
	var frame := int(pose_data.frame)
	var cache_key := "%s|%s|%d|%s" % [action, direction, frame, JSON.stringify(_equipped)]
	if not _texture_cache.has(cache_key):
		_texture_cache[cache_key] = _renderer.texture(_appearance, _equipped, direction, frame, action)
	return _texture_cache[cache_key]

func _draw() -> void:
	var palette: Dictionary = PALETTES[_time_phase]
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), palette.sky)
	_draw_stage(palette)
	_draw_timeline(palette)
	_draw_ribbon_trails(palette)
	_draw_performers(palette)
	_draw_controls(palette)

func _draw_stage(palette: Dictionary) -> void:
	var ink: Color = palette.sky.darkened(0.38)
	var gold: Color = palette.gold
	draw_rect(STAGE_BOUNDS, ink)
	draw_rect(Rect2(86, 150, 1108, 468), palette.wall)
	# Four fixed lamps shape four readable lighting moods; the rays do not move.
	for lamp in [Vector2(275, 192), Vector2(520, 182), Vector2(760, 182), Vector2(1005, 192)]:
		var beam := PackedVector2Array([lamp + Vector2(-17, 3), lamp + Vector2(17, 3), Vector2(lamp.x + 184, 493), Vector2(lamp.x - 184, 493)])
		draw_colored_polygon(beam, Color(palette.beam, 0.075))
		draw_circle(lamp, 19.0, ink.darkened(0.15))
		draw_circle(lamp, 8.0, gold)
		draw_circle(lamp, 4.0, Color.WHITE.lightened(0.08))
	_draw_proscenium(palette)
	_draw_velvet_curtains(palette)
	_draw_plank_stage(palette)
	_draw_floor_lights(palette)

func _draw_proscenium(palette: Dictionary) -> void:
	var ink: Color = palette.sky.darkened(0.40)
	var gold: Color = palette.gold
	# Deep layered wood trim frames a frontal cabaret opening.
	draw_rect(Rect2(92, 145, 1096, 24), ink)
	draw_rect(Rect2(92, 169, 28, 416), ink)
	draw_rect(Rect2(1160, 169, 28, 416), ink)
	draw_rect(Rect2(99, 150, 1082, 5), gold.darkened(0.10))
	draw_rect(Rect2(98, 575, 1084, 18), palette.wood)
	draw_rect(Rect2(102, 579, 1076, 3), gold.darkened(0.10))
	for x in range(137, 1150, 76):
		draw_circle(Vector2(x, 158), 3.0, gold)
	draw_arc(Vector2(640, 247), 488, PI, TAU, 72, gold.darkened(0.30), 3.0, true)

func _draw_velvet_curtains(palette: Dictionary) -> void:
	var curtain: Color = palette.curtain
	var lit: Color = palette.velvet
	var gold: Color = palette.gold
	var left := PackedVector2Array([Vector2(116, 169), Vector2(318, 181), Vector2(286, 248), Vector2(264, 416), Vector2(249, 569), Vector2(116, 584)])
	var right := PackedVector2Array([Vector2(1164, 169), Vector2(962, 181), Vector2(994, 248), Vector2(1016, 416), Vector2(1031, 569), Vector2(1164, 584)])
	draw_colored_polygon(left, curtain)
	draw_colored_polygon(right, curtain)
	for index in range(6):
		var lx := 132.0 + float(index) * 28.0
		var rx := 1148.0 - float(index) * 28.0
		draw_line(Vector2(lx, 174), Vector2(133.0 + float(index) * 22.0, 569), lit.darkened(float(index) * 0.035), 6.0)
		draw_line(Vector2(rx, 174), Vector2(1147.0 - float(index) * 22.0, 569), lit.darkened(float(index) * 0.035), 6.0)
	# A scalloped pelmet signals a compact cabaret, not the shared harbor awning.
	draw_rect(Rect2(240, 168, 800, 20), curtain.darkened(0.08))
	for index in range(10):
		var x := 250.0 + float(index) * 86.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 184), Vector2(x + 86, 184), Vector2(x + 72, 207), Vector2(x + 43, 218), Vector2(x + 14, 207)]), lit)
		draw_circle(Vector2(x + 43, 192), 3.0, gold)

func _draw_plank_stage(palette: Dictionary) -> void:
	var back_edge := PackedVector2Array([Vector2(265, 470), Vector2(1015, 470), Vector2(1160, 605), Vector2(120, 605)])
	draw_colored_polygon(back_edge, palette.wood)
	draw_colored_polygon(PackedVector2Array([Vector2(120, 598), Vector2(1160, 598), Vector2(1187, 616), Vector2(92, 616)]), palette.wood.darkened(0.20))
	for index in range(1, 11):
		var t := float(index) / 11.0
		var y := lerpf(472.0, 599.0, t * t)
		var left_x := lerpf(265.0, 120.0, t)
		var right_x := lerpf(1015.0, 1160.0, t)
		draw_line(Vector2(left_x, y), Vector2(right_x, y), palette.wood_light.darkened(0.23), 2.0)
	for seam in range(7):
		var t := float(seam) / 7.0
		var x := lerpf(305.0, 974.0, t)
		draw_line(Vector2(x, 473), Vector2(lerpf(155, 1120, t), 596), palette.wood_light.darkened(0.32), 2.0)
	# Brass foot marks anchor left, center, right footwork to the boards.
	for x in [421.0, 640.0, 859.0]:
		draw_arc(Vector2(x, 565), 38.0, PI * 0.12, PI * 0.88, 26, Color(palette.gold, 0.42), 2.0, true)
		draw_circle(Vector2(x, 565), 3.5, palette.gold)

func _draw_floor_lights(palette: Dictionary) -> void:
	# The eight existing footlights are the performance timeline, safely below
	# the shared HUD and below the performers' feet.
	for index in range(BEAT_MARKER_COUNT):
		var center := Vector2(184.0 + float(index) * 130.0, 600.0 + (3.0 if index % 2 == 0 else 0.0))
		var state := beat_marker_state(index)
		var color: Color = palette.text.darkened(0.38)
		match state:
			"complete": color = palette.accent if index % 2 == 0 else palette.coral
			"current": color = palette.gold
			"missed": color = palette.coral.darkened(0.30)
		draw_circle(center, 9.0 if index in STRONG_BEATS else 7.0, palette.sky.darkened(0.15))
		draw_circle(center, 5.5 if index in STRONG_BEATS else 4.0, color)
		if state == "current":
			draw_arc(center, 10.5, 0.0, TAU, 24, palette.gold, 1.5, true)
		_draw_label(Vector2(center.x - 7.0, 620.0), str(index + 1), palette.text.darkened(0.08), HORIZONTAL_ALIGNMENT_CENTER, 14, 9)
	# Two raised side steps give the stage its 2.5D edge and contact shadow.
	draw_line(Vector2(92, 627), Vector2(1188, 627), palette.sky.darkened(0.50), 4.0)
	draw_line(Vector2(112, 632), Vector2(1168, 632), palette.gold.darkened(0.40), 2.0)

func _draw_timeline(palette: Dictionary) -> void:
	var upcoming: Array = _snapshot.get("upcoming", [])
	var current: Dictionary = _snapshot.get("current_gesture", {})
	_draw_cue_card(CURRENT_CUE_RECT, current, true, palette)
	_draw_cue_card(UPCOMING_CUE_RECTS[0], upcoming[0] if upcoming.size() > 0 else {}, false, palette)
	_draw_cue_card(UPCOMING_CUE_RECTS[1], upcoming[1] if upcoming.size() > 1 else {}, false, palette)
	# Thin timeline lines point into the stage while leaving faces unobstructed.
	draw_line(Vector2(303, 267), Vector2(415, 350), Color(palette.gold, 0.66), 2.0)
	draw_line(Vector2(977, 267), Vector2(878, 353), Color(palette.accent, 0.62), 2.0)
	draw_line(Vector2(1018, 349), Vector2(926, 415), Color(palette.coral, 0.58), 2.0)
	var active_hold := str(_snapshot.get("hold_action", ""))
	if not active_hold.is_empty():
		var required := maxf(0.01, float(_snapshot.get("hold_required", 0.0)))
		var ratio := clampf(float(_snapshot.get("hold_elapsed", 0.0)) / required, 0.0, 1.0)
		draw_rect(Rect2(458, 210, 364, 7), Color(palette.gold, 0.22))
		draw_rect(Rect2(458, 210, 364 * ratio, 7), palette.gold)
		_draw_label(Vector2(458, 201), "按住揮過整段弧線", palette.text, HORIZONTAL_ALIGNMENT_CENTER, 364, 13)

func _draw_cue_card(rect: Rect2, cue: Dictionary, is_current: bool, palette: Dictionary) -> void:
	if cue.is_empty():
		return
	var paper: Color = palette.sky.darkened(0.10) if is_current else Color(palette.sky, 0.75)
	var key_color: Color = palette.gold if bool(cue.get("strong", false)) else palette.accent
	draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color.BLACK, true)
	draw_rect(rect, paper, true)
	draw_rect(rect, key_color if is_current else Color(key_color, 0.62), false, 2.0, true)
	var icon_center := rect.position + Vector2(34, rect.size.y * 0.52)
	_draw_action_glyph(icon_center, str(cue.get("action", "")), key_color, bool(cue.get("strong", false)))
	var title := str(cue.get("label", "下一拍"))
	_draw_label(rect.position + Vector2(63, 30), title, palette.text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 69, 14)
	var held := float(cue.get("hold", 0.0))
	var subline := "按住 %.2f 秒" % held if held > 0.0 else ("重拍" if bool(cue.get("strong", false)) else "落在拍心")
	_draw_label(rect.position + Vector2(63, rect.size.y - 15), subline, palette.gold if held > 0.0 or bool(cue.get("strong", false)) else palette.text.darkened(0.05), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 69, 11)

func _draw_action_glyph(center: Vector2, action: String, color: Color, strong: bool) -> void:
	draw_circle(center, 23.0 if strong else 19.0, Color(color, 0.12))
	draw_circle(center, 14.0 if strong else 12.0, color)
	match action:
		"left":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 0), center + Vector2(4, -8), center + Vector2(4, 8)]), Color("#28384a"))
		"right":
			draw_colored_polygon(PackedVector2Array([center + Vector2(8, 0), center + Vector2(-4, -8), center + Vector2(-4, 8)]), Color("#28384a"))
		"jump":
			draw_line(center + Vector2(-8, 4), center + Vector2(0, -6), Color("#28384a"), 3.0)
			draw_line(center + Vector2(0, -6), center + Vector2(8, 4), Color("#28384a"), 3.0)

func _draw_ribbon_trails(palette: Dictionary) -> void:
	var trails: Array = _snapshot.get("ribbon_trail", [])
	var total := mini(trails.size(), 8)
	for index in range(total):
		var item: Dictionary = trails[index]
		var ribbon := str(item.get("ribbon", ""))
		var color: Color = palette.coral if index % 2 == 0 else palette.accent
		var alpha := lerpf(0.22, 0.72, float(index + 1) / float(total + 1))
		var path := _ribbon_path(ribbon)
		var points := PackedVector2Array()
		for point: Vector2 in path:
			points.append(point)
		if points.size() >= 2:
			draw_polyline(points, Color(color, alpha), 5.0 if index == total - 1 else 3.0, true)
			for point_index in range(1, points.size(), 5):
				draw_circle(points[point_index], 2.2, Color(palette.gold, alpha * 0.78))
	var current: Dictionary = _snapshot.get("current_gesture", {})
	if not _reduced_motion and float(_snapshot.get("hold_elapsed", 0.0)) > 0.0:
		var hold_path := _ribbon_path(str(current.get("ribbon", "")))
		var fraction := clampf(float(_snapshot.get("hold_elapsed", 0.0)) / maxf(0.01, float(_snapshot.get("hold_required", 0.0))), 0.0, 1.0)
		var visible := maxi(2, roundi(float(hold_path.size()) * fraction))
		var points := PackedVector2Array()
		for point_index in mini(visible, hold_path.size()):
			points.append(hold_path[point_index])
		if points.size() > 1:
			draw_polyline(points, Color(palette.gold, 0.95), 6.0, true)

func _ribbon_path(kind: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in range(19):
		var t := float(index) / 18.0
		var point := Vector2.ZERO
		match kind:
			"low_left": point = Vector2(470.0 - 102.0 * t, 432.0 - 78.0 * sin(PI * t))
			"low_right": point = Vector2(760.0 + 108.0 * t, 432.0 - 78.0 * sin(PI * t))
			"high_left_sweep": point = Vector2(520.0 - 212.0 * t, 354.0 - 118.0 * sin(PI * t))
			"high_right_sweep": point = Vector2(700.0 + 214.0 * t, 354.0 - 116.0 * sin(PI * t))
			"jump_loop":
				var angle := lerpf(-PI * 0.08, PI * 1.72, t)
				point = Vector2(617.0 + 107.0 * cos(angle), 360.0 + 91.0 * sin(angle))
			_: point = Vector2(473.0 + 290.0 * t, 435.0 - 62.0 * sin(PI * t))
		points.append(point)
	return points

func _draw_performers(palette: Dictionary) -> void:
	var pose := "idle_front"
	var current: Dictionary = _snapshot.get("current_gesture", {})
	if bool(_snapshot.get("ended", false)) and bool(_snapshot.get("success", false)):
		pose = "celebrate_front"
	elif not current.is_empty():
		pose = str(current.get("pose", "idle_front"))
	var elapsed := float(_snapshot.get("elapsed", 0.0))
	_draw_companion(palette, elapsed)
	var main_rect := JUMP_AVATAR_RECT if pose == "jump_front" and not _reduced_motion else MAIN_AVATAR_RECT
	_draw_ground_shadow(main_rect, palette, pose == "jump_front" and not _reduced_motion)
	_draw_avatar(pose, elapsed, false, main_rect, Color.WHITE, false)
	if bool(_snapshot.get("ended", false)):
		_draw_label(Vector2(436, 250), "掌聲留在天鵝絨後台", palette.gold, HORIZONTAL_ALIGNMENT_CENTER, 410, 15)

func _draw_companion(palette: Dictionary, elapsed: float) -> void:
	var texture := _companion_texture(elapsed)
	if texture == null:
		return
	_draw_ground_shadow(PARTNER_AVATAR_RECT, palette)
	draw_texture_rect(texture, PARTNER_AVATAR_RECT, false)
	_draw_label(Vector2(PARTNER_AVATAR_RECT.position.x, PARTNER_AVATAR_RECT.position.y - 5.0), "小角", palette.gold, HORIZONTAL_ALIGNMENT_CENTER, int(PARTNER_AVATAR_RECT.size.x), 12)

func _companion_texture(elapsed: float) -> Texture2D:
	if _companion_dance_active and not _companion_dance_frames.is_empty():
		return _companion_dance_frames[_companion_frame_index(elapsed)]
	if _companion_idle_frames.is_empty():
		return _companion_static_texture
	return _companion_idle_frames[_companion_frame_index(elapsed)]

func _draw_ground_shadow(rect: Rect2, palette: Dictionary, airborne: bool = false) -> void:
	var point := Vector2(rect.get_center().x, 575.0)
	if airborne:
		point.x += 4.0
	var draw_y_scale := 0.30 if airborne else 0.38
	draw_set_transform(point, 0.0, Vector2(1.55, draw_y_scale))
	draw_circle(Vector2.ZERO, 43.0, Color(palette.sky.darkened(0.43), 0.64))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_avatar(pose: String, elapsed: float, partner: bool, rect: Rect2, modulate: Color, mirrored: bool) -> void:
	var texture := _avatar_texture(pose, elapsed, partner)
	if texture == null:
		return
	if mirrored:
		var scale_factor := Vector2(-rect.size.x / float(texture.get_width()), rect.size.y / float(texture.get_height()))
		draw_set_transform(Vector2(rect.end.x, rect.position.y), 0.0, scale_factor)
		draw_texture(texture, Vector2.ZERO, modulate)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(texture, rect, false, modulate)
func _draw_controls(palette: Dictionary) -> void:
	for action in ["left", "jump", "right"]:
		var rect: Rect2 = CONTROL_RECTS[action]
		var active: bool = str(_snapshot.get("hold_action", "")) == action
		var fill: Color = palette.gold if active else Color(palette.sky, 0.82)
		draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color.BLACK, true)
		draw_rect(rect, fill, true)
		draw_rect(rect, palette.gold.darkened(0.16) if active else palette.accent.darkened(0.12), false, 2.0, true)
		var label := "←  A / ←" if action == "left" else ("跳起  SPACE" if action == "jump" else "D / →  →")
		_draw_label(rect.position + Vector2(0, 32), label, palette.text if not active else palette.sky, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), 15)

func _draw_label(position: Vector2, text: String, color: Color, alignment: HorizontalAlignment, width: int, size_value: int) -> void:
	draw_string(FONT, position, text, alignment, width, size_value, color)
