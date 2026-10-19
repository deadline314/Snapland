extends Control
class_name BenchSwapView

signal seat_requested(index: int)

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const SAFE_PLAYFIELD := Rect2(70.0, 130.0, 1140.0, 510.0)
const FOOTER_LEFT := 70.0
const FOOTER_WIDTH := 1140.0
const FOOTER_STATUS_BASELINE := 613.0
const FOOTER_HELP_BASELINE := 638.0
const TABLE_BOUNDS := Rect2(138.0, 235.0, 1004.0, 354.0)
const AVATAR_SIZE := Vector2(72.0, 92.0)
const AVATAR_RENDER_BOUNDS := Rect2(Vector2.ZERO, AVATAR_SIZE)
const AvatarRendererScript := preload("res://game/world/avatar_renderer.gd")
const GUEST_NAMES := ["小燈", "海星", "貝殼", "小帆", "螃蟹", "水母"]
const GUEST_MARKS := ["☼", "✦", "◌", "≈", "♧", "✿"]
const CLOTHES := ["outfit-tide", "outfit-coral", "outfit-gold", "outfit-navy", "outfit-coral", "outfit-tide"]
const SKINS := ["warm", "deep", "bronze", "cool", "olive", "warm"]
const HAIR_STYLES := ["bob", "curly", "windswept", "bob", "curly", "windswept"]
const HAIR_COLORS := ["chestnut", "ink", "silver", "chestnut", "ink", "silver"]
const BADGE_COLORS := [Color("#df7865"), Color("#46a6aa"), Color("#d6a63e"), Color("#7585ba"), Color("#62a36f"), Color("#ba79a0")]

var _snapshot: Dictionary = {}
var _time_phase := "noon"
var _reduced_motion := false
var _seat_rects: Array[Rect2] = []
var _textures: Array[Texture2D] = []
var _appearance_key := ""
var _renderer: RefCounted
var _keyboard_seat := 0

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	_renderer = AvatarRendererScript.new()
	_resize_seats()
	set_process(false)

func configure_avatar(appearance: Dictionary, equipped: Dictionary) -> void:
	var key := JSON.stringify([appearance, equipped])
	if key == _appearance_key and not _textures.is_empty():
		return
	_appearance_key = key
	_textures.clear()
	for index in GUEST_NAMES.size():
		var look := appearance.duplicate(true)
		look["skin"] = SKINS[index]
		look["species"] = ["human", "elf", "human", "imp", "human", "elf"][index]
		look["hair"] = HAIR_STYLES[index]
		look["hair_color"] = HAIR_COLORS[index]
		var clothes := equipped.duplicate(true)
		clothes["outfit"] = CLOTHES[index]
		clothes["hat"] = "hat-none"
		_textures.append(_renderer.texture(look, clothes, "front", 0, "idle"))
	queue_redraw()

func update_frame(snapshot: Dictionary, time_phase: String = "noon", reduced_motion: bool = false) -> void:
	_snapshot = snapshot
	_time_phase = time_phase
	_reduced_motion = reduced_motion
	queue_redraw()

func screen_to_design(screen_position: Vector2) -> Vector2:
	var scale_value := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var offset := (size - DESIGN_SIZE * scale_value) * 0.5
	return (screen_position - offset) / maxf(scale_value, 0.0001)

func playfield_rect() -> Rect2:
	return SAFE_PLAYFIELD

func geometry_bounds() -> Rect2:
	return TABLE_BOUNDS

func seat_geometry_bounds(index: int) -> Rect2:
	return _seat_rects[index] if index >= 0 and index < _seat_rects.size() else Rect2()

## The tabletop is drawn in a transform centered on (640, 402). Avatar helpers
## expose that same local coordinate space so diagnostics and drawing agree.
func seat_avatar_baseline_local(index: int, lift: float = 0.0) -> Vector2:
	if index < 0 or index >= _seat_rects.size(): return Vector2.ZERO
	return _seat_rects[index].get_center() - Vector2(640.0, 402.0) + Vector2(0.0, 34.0 - lift)

func seat_avatar_baseline_design(index: int, lift: float = 0.0) -> Vector2:
	return seat_avatar_baseline_local(index, lift) + Vector2(640.0, 402.0)

## Returns the six authored figures as full-body rectangles in design space.
## During an exchange four guests stay seated and exactly two follow the model.
func guest_visual_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seats: Array = _snapshot.get("seats", [])
	var from_seat := int(_snapshot.get("swap_from", -1))
	var to_seat := int(_snapshot.get("swap_to", -1))
	var moving := from_seat >= 0 and to_seat >= 0 and from_seat < _seat_rects.size() and to_seat < _seat_rects.size()
	for index in _seat_rects.size():
		if moving and index in [from_seat, to_seat]: continue
		var guest := int(seats[index]) if index < seats.size() else index
		var lift := 13.0 if index == int(_snapshot.get("selected_seat", -1)) else 0.0
		var baseline := seat_avatar_baseline_local(index, lift)
		result.append(_avatar_layout_entry(guest, index, baseline, false))
	if moving:
		for entry in moving_avatar_geometry():
			result.append(entry)
	return result

## Coordinates are local to the active tabletop transform. The arc starts and
## ends on the same feet baselines used by idle figures, with no frame-0 jump.
func moving_avatar_geometry() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var from_seat := int(_snapshot.get("swap_from", -1))
	var to_seat := int(_snapshot.get("swap_to", -1))
	if from_seat < 0 or to_seat < 0 or from_seat >= _seat_rects.size() or to_seat >= _seat_rects.size(): return result
	var progress := clampf(float(_snapshot.get("swap_progress", 1.0)), 0.0, 1.0)
	if _reduced_motion: progress = 1.0
	var from_baseline := seat_avatar_baseline_local(from_seat)
	var to_baseline := seat_avatar_baseline_local(to_seat)
	var arc_offset := Vector2(0.0, -sin(progress * PI) * 66.0)
	var from_guest := int(_snapshot.get("moving_guest_from", -1))
	var to_guest := int(_snapshot.get("moving_guest_to", -1))
	result.append(_avatar_layout_entry(from_guest, to_seat, from_baseline.lerp(to_baseline, progress) + arc_offset, true))
	result.append(_avatar_layout_entry(to_guest, from_seat, to_baseline.lerp(from_baseline, progress) + arc_offset, true))
	return result

func _avatar_layout_entry(guest: int, seat: int, baseline: Vector2, moving: bool) -> Dictionary:
	var design_baseline := baseline + Vector2(640.0, 402.0)
	return {"guest":guest,"seat":seat,"baseline":baseline,"bounds":Rect2(design_baseline - Vector2(AVATAR_SIZE.x * 0.5, AVATAR_SIZE.y), AVATAR_SIZE),"moving":moving}

func uses_authored_avatar() -> bool:
	return _textures.size() == GUEST_NAMES.size() and _textures.all(func(texture: Texture2D) -> bool: return texture != null)

func avatar_texture_for_guest(index: int) -> Texture2D:
	return _textures[index] if index >= 0 and index < _textures.size() else null

func seat_highlight_kind(index: int) -> String:
	if index == int(_snapshot.get("selected_seat", -1)): return "selected"
	if index == int(_snapshot.get("swap_from", -1)) or index == int(_snapshot.get("swap_to", -1)): return "moving"
	var hint: Array = _snapshot.get("hint_pair", [])
	return "hint" if hint.has(index) else "idle"

func text_layout_bounds() -> Array[Rect2]:
	return [Rect2(70, 132, 420, 31), Rect2(730, 132, 480, 31), Rect2(172, 174, 936, 68), Rect2(FOOTER_LEFT, 592, FOOTER_WIDTH, 27), Rect2(FOOTER_LEFT, 619, FOOTER_WIDTH, 20)]

func footer_text_contracts() -> Array[Dictionary]:
	var status := "%s　交換 %d / %d　最少 %d" % [str(_snapshot.get("last_event", "")), int(_snapshot.get("moves", 0)), int(_snapshot.get("move_budget", 0)), int(_snapshot.get("optimal_moves", 0))]
	var help := "提示圈出一組有用的交換席位；仍需親自選取" if bool(_snapshot.get("assisted", false)) and not _snapshot.get("hint_pair", []).is_empty() else "在交換額度內排好三桌；每桌達最少步數可拿全章標記"
	return [{"text":status,"origin":Vector2(FOOTER_LEFT, FOOTER_STATUS_BASELINE),"width":FOOTER_WIDTH,"font_size":18}, {"text":help,"origin":Vector2(FOOTER_LEFT, FOOTER_HELP_BASELINE),"width":FOOTER_WIDTH,"font_size":14}]

func rule_text_widths() -> Array[float]:
	var result: Array[float] = []
	for label in str(_snapshot.get("rule_text", "")).split("　", false):
		result.append(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	return result

func input(event: InputEvent) -> void:
	_handle_input(event)

func _gui_input(event: InputEvent) -> void:
	_handle_input(event)

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point := screen_to_design(event.position)
		for index in _seat_rects.size():
			if _seat_rects[index].grow(14.0).has_point(point):
				seat_requested.emit(index)
				accept_event()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]: _keyboard_seat = posmod(_keyboard_seat - 1, GUEST_NAMES.size())
		elif event.keycode in [KEY_RIGHT, KEY_D]: _keyboard_seat = posmod(_keyboard_seat + 1, GUEST_NAMES.size())
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: seat_requested.emit(_keyboard_seat)
		else: return
		queue_redraw()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_seats()
		queue_redraw()

func _resize_seats() -> void:
	_seat_rects.clear()
	for index in GUEST_NAMES.size():
		var x := 247.0 + float(index) * 157.0
		var y := 379.0 + (10.0 if index % 2 == 1 else 0.0)
		_seat_rects.append(Rect2(x - 43.0, y - 105.0, 86.0, 184.0))

func _draw() -> void:
	var scale_value := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var offset := (size - DESIGN_SIZE * scale_value) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_value)
	var palette := _palette()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), palette.paper)
	_draw_header(palette)
	_draw_diorama(palette)
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_value)
	_draw_rules(palette)
	_draw_footer(palette)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_diorama(palette: Dictionary) -> void:
	draw_set_transform(Vector2(640, 402), 0.0, Vector2.ONE)
	_draw_table_legs(palette)
	_draw_window(Vector2(0, -114), palette)
	_draw_ellipse(Vector2(0, 88), Vector2(480, 126), palette.shadow)
	_draw_ellipse(Vector2(0, 66), Vector2(478, 126), palette.wood_edge)
	_draw_ellipse(Vector2(0, 52), Vector2(466, 112), palette.wood)
	for line in 7:
		var y := -17.0 + line * 22.0
		draw_line(Vector2(-360, y), Vector2(360, y - 5), palette.grain, 2.0, true)
	_draw_bench_back(palette)
	var seat_values: Array = _snapshot.get("seats", [])
	var selected := int(_snapshot.get("selected_seat", -1))
	var hint: Array = _snapshot.get("hint_pair", [])
	var from_seat := int(_snapshot.get("swap_from", -1))
	var to_seat := int(_snapshot.get("swap_to", -1))
	var swap_progress := float(_snapshot.get("swap_progress", 1.0))
	if _reduced_motion: swap_progress = 1.0
	for index in _seat_rects.size():
		var seat := _seat_rects[index]
		var center := seat.get_center()
		var guest := int(seat_values[index]) if index < seat_values.size() else index
		var lift := 0.0
		if index == selected: lift = 13.0
		if index == from_seat or index == to_seat: lift = sin(swap_progress * PI) * 30.0
		if not hint.is_empty() and (index == int(hint[0]) or index == int(hint[1])):
			draw_arc(center + Vector2(0, 66), 43.0, 0.0, TAU, 48, palette.hint, 4.0, true)
		_draw_seat(index, center + Vector2(0, -lift), guest, seat_highlight_kind(index), palette)
	for entry in moving_avatar_geometry():
		_draw_avatar(int(entry.guest), entry.baseline, palette)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_bench_back(palette: Dictionary) -> void:
	draw_line(Vector2(-413, 11), Vector2(413, 11), palette.wood_edge, 28.0, true)
	draw_line(Vector2(-405, 1), Vector2(405, 1), palette.brass, 5.0, true)
	for x in [-386, -230, -77, 77, 230, 386]:
		draw_line(Vector2(x, -17), Vector2(x, 19), palette.wood_edge, 11.0, true)
		draw_circle(Vector2(x, -3), 4, palette.brass)

func _draw_table_legs(palette: Dictionary) -> void:
	for x in [-300.0, 300.0]:
		var leg := PackedVector2Array([Vector2(x - 18, 62), Vector2(x + 18, 62), Vector2(x + 30, 161), Vector2(x - 27, 161)])
		draw_colored_polygon(leg, palette.wood_edge)
		draw_line(Vector2(x - 6, 78), Vector2(x - 2, 147), palette.grain, 3.0, true)

func _draw_window(center: Vector2, palette: Dictionary) -> void:
	var frame := Rect2(center - Vector2(61, 37), Vector2(122, 74))
	draw_rect(frame.grow(6), palette.wood_edge, true)
	draw_rect(frame, palette.window, true)
	draw_rect(Rect2(frame.position + Vector2(5, 5), frame.size - Vector2(10, 10)), palette.window_light, true)
	draw_rect(Rect2(center.x - 56, frame.end.y - 26, 112, 20), palette.sea, true)
	draw_line(Vector2(center.x, frame.position.y + 5), Vector2(center.x, frame.end.y - 5), palette.brass, 3)
	draw_line(Vector2(frame.position.x + 5, center.y), Vector2(frame.end.x - 5, center.y), palette.brass, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(frame.position.x - 17, frame.position.y - 9), Vector2(frame.position.x + 12, frame.position.y - 9), Vector2(frame.position.x + 4, frame.end.y + 2), Vector2(frame.position.x - 8, frame.end.y + 2)]), palette.curtain)
	draw_colored_polygon(PackedVector2Array([Vector2(frame.end.x - 12, frame.position.y - 9), Vector2(frame.end.x + 17, frame.position.y - 9), Vector2(frame.end.x + 8, frame.end.y + 2), Vector2(frame.end.x - 4, frame.end.y + 2)]), palette.curtain)


func _draw_seat(index: int, center: Vector2, guest: int, highlight: String, palette: Dictionary) -> void:
	var x := center.x - 640.0
	var y := center.y - 402.0
	var cushion := Rect2(x - 48.0, y + 48.0, 96.0, 28.0)
	draw_line(Vector2(x - 47, y + 76), Vector2(x - 38, y + 101), palette.wood_edge, 8.0, true)
	draw_line(Vector2(x + 47, y + 76), Vector2(x + 38, y + 101), palette.wood_edge, 8.0, true)
	draw_rect(cushion.grow(3), palette.wood_edge, true)
	draw_rect(cushion, palette.cloth[guest % palette.cloth.size()], true)
	draw_line(Vector2(x - 38, y + 55), Vector2(x + 38, y + 55), palette.stitch, 2.0, true)
	# Each figure is a miniature standing token on a visible, grained wooden plinth.
	var base := Rect2(x - 30, y + 32, 60, 10)
	draw_rect(base.grow(3), palette.wood_edge, true)
	draw_rect(base, palette.base_wood, true)
	draw_line(Vector2(x - 24, y + 35), Vector2(x + 24, y + 35), palette.grain, 2.0, true)
	draw_circle(Vector2(x, y + 37), 4.0, BADGE_COLORS[guest])
	var ring: Color = palette.selected if highlight == "selected" else (palette.moving if highlight == "moving" else (palette.hint if highlight == "hint" else palette.brass))
	draw_arc(Vector2(x, y + 54), 59.0, 0.0, TAU, 48, ring, 5.0 if highlight != "idle" else 2.0, true)
	if index != int(_snapshot.get("swap_from", -1)) and index != int(_snapshot.get("swap_to", -1)):
		_draw_avatar(guest, seat_avatar_baseline_local(index, maxf(0.0, -float(center.y - _seat_rects[index].get_center().y))), palette)
	draw_string(ThemeDB.fallback_font, Vector2(x - 46, y + 104), "%s %s" % [GUEST_MARKS[guest], GUEST_NAMES[guest]], HORIZONTAL_ALIGNMENT_CENTER, 92, 15, palette.ink)
	_draw_seat_number(Vector2(x, y + 125), index + 1, palette)
	if _keyboard_seat == index and has_focus():
		draw_arc(Vector2(x, y + 54), 66.0, 0.0, TAU, 48, palette.focus, 3.0, true)

func _draw_avatar(guest: int, baseline_center: Vector2, palette: Dictionary) -> void:
	if guest < 0 or guest >= _textures.size() or _textures[guest] == null:
		return
	var rect := Rect2(baseline_center.x - AVATAR_SIZE.x * 0.5, baseline_center.y - AVATAR_SIZE.y, AVATAR_SIZE.x, AVATAR_SIZE.y)
	draw_texture_rect(_textures[guest], rect, false, Color.WHITE)

func _draw_seat_number(center: Vector2, number: int, palette: Dictionary) -> void:
	draw_circle(center, 13.0, palette.brass)
	draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), str(number), HORIZONTAL_ALIGNMENT_CENTER, 10, 13, palette.ink)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 64:
		var angle := TAU * float(index) / 64.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_header(palette: Dictionary) -> void:
	var current := int(_snapshot.get("level", 0))
	draw_string(ThemeDB.fallback_font, Vector2(70, 158), "長椅換位 · %s" % str(_snapshot.get("level_name", ["窗邊重逢", "海風與留白", "長椅邀約"][mini(current, 2)])), HORIZONTAL_ALIGNMENT_LEFT, 420, 24, palette.ink)
	draw_string(ThemeDB.fallback_font, Vector2(730, 158), "選兩席交換　方向鍵移動 · Enter 選取", HORIZONTAL_ALIGNMENT_RIGHT, 480, 16, palette.muted)
	var dots := int(_snapshot.get("level", 0))
	for i in 3:
		draw_circle(Vector2(588.0 + i * 46.0, 157), 7.0, palette.coral if i <= dots else palette.inactive)

func _draw_rules(palette: Dictionary) -> void:
	var rect := Rect2(172, 174, 936, 68)
	draw_rect(rect, Color("#102b3a"))
	draw_rect(rect, Color("#dfb95f"), false, 2.0)
	var labels := str(_snapshot.get("rule_text", "先看看提示標記")).split("　", false)
	for index in labels.size():
		var column := index % 2
		var row := int(index / 2)
		var x := rect.position.x + 22.0 + column * 468.0
		var y := rect.position.y + 24.0 + row * 25.0
		draw_string(ThemeDB.fallback_font, Vector2(x, y), str(labels[index]), HORIZONTAL_ALIGNMENT_LEFT, 444, 16, Color("#f4eedc"))

func _draw_footer(palette: Dictionary) -> void:
	var contracts := footer_text_contracts()
	var status: Dictionary = contracts[0]
	var help: Dictionary = contracts[1]
	draw_string(ThemeDB.fallback_font, status.origin, status.text, HORIZONTAL_ALIGNMENT_CENTER, status.width, status.font_size, palette.ink)
	draw_string(ThemeDB.fallback_font, help.origin, help.text, HORIZONTAL_ALIGNMENT_CENTER, help.width, help.font_size, palette.hint if bool(_snapshot.get("assisted", false)) and not _snapshot.get("hint_pair", []).is_empty() else palette.muted)

func _palette() -> Dictionary:
	var phase_colors := {"night": [Color("#243644"), Color("#678094"), Color("#334e60"), Color("#779eaa")], "dusk": [Color("#f0e2d6"), Color("#bd7d60"), Color("#704a3b"), Color("#c79775")], "dawn": [Color("#f6edda"), Color("#bf9560"), Color("#78533d"), Color("#8bb8b1")], "noon": [Color("#f5efe2"), Color("#b98555"), Color("#744d39"), Color("#92c3bd")]}
	var phase: Array = phase_colors.get(_time_phase, phase_colors.noon)
	var night := _time_phase == "night"
	return {
		"paper": phase[0], "ink": Color("#f1eadc") if night else Color("#273945"), "muted": Color("#aec0c2") if night else Color("#61777c"),
		"wood": phase[1], "wood_edge": phase[2], "base_wood": Color("#d8ad70") if not night else Color("#8ba5a3"), "grain": Color("#d1a36e") if not night else Color("#92aaab"), "brass": Color("#e2b95f"), "shadow": Color("#12263466") if night else Color("#58645555"),
		"cloth":[Color("#d98370"),Color("#68aab0"),Color("#e4ba66"),Color("#8394bf")], "stitch": Color("#f6e7cc"), "window": phase[2], "window_light": phase[3], "sea": Color("#537e89") if night else Color("#76aaa8"), "curtain": Color("#bf7964") if not night else Color("#5a7487"),
		"selected": Color("#df6e61"), "moving": Color("#46a6aa"), "coral": Color("#df6e61"), "focus": Color("#31999a"), "hint": Color("#2d8990"), "note": Color("#e6d9bd") if not night else Color("#394e5b"), "inactive": Color("#c4b8a1")
	}
