extends Control
class_name MelodyMemoryView

signal note_requested(index: int)
signal replay_requested

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const INSTRUMENT_ATLAS_PATH := "res://assets/minigames/props/melody-instruments-v2.png"
const ATLAS_CELL_SIZE := 627
const ATLAS_ALPHA_BOUNDS: Array[Rect2] = [
	Rect2(121, 95, 439, 504),
	Rect2(152, 97, 315, 512),
	Rect2(99, 126, 519, 409),
	Rect2(130, 69, 382, 454),
]
const ATLAS_DRAW_SIZE := 196.0
const HUD_SAFE_RECT := Rect2(34.0, 18.0, 1212.0, 112.0)
const SCENE_BOUNDS := Rect2(38.0, 142.0, 1204.0, 510.0)
const TIMELINE_RECT := Rect2(190.0, 174.0, 900.0, 153.0)
const ROLL_CASE_BOUNDS := Rect2(174.0, 158.0, 932.0, 180.0)
const CRANK_LABEL_BOUNDS := Rect2(38.0, 281.0, 136.0, 43.0)
const TABLE_BOUNDS := Rect2(104.0, 350.0, 1072.0, 242.0)
const INSTRUMENT_CENTERS: Array[Vector2] = [Vector2(215, 466), Vector2(497, 466), Vector2(783, 466), Vector2(1065, 466)]
const INSTRUMENT_SIZES: Array[Vector2] = [Vector2(212, 202), Vector2(212, 202), Vector2(218, 218), Vector2(212, 202)]
const INSTRUMENT_NAMES: Array[String] = ["貝殼簧片", "玻璃潮鈴", "漂木音板", "小港鼓"]
const KEY_LABELS: Array[String] = ["1", "2", "3", "4"]
const SECONDARY_KEYS: Array[String] = ["A", "S", "D", "F"]
const PHASES: Array[String] = ["dawn", "noon", "dusk", "night"]
const REPLAY_RECT := Rect2(1080, 586, 150, 58)

var _snapshot: Dictionary = {}
var _time_of_day := "noon"
var _reduced_motion := false
var _instrument_textures: Array[Texture2D] = []
var _atlas_texture: Texture2D
var _atlas_warning_logged := false

func _ready() -> void:
	custom_minimum_size = DESIGN_SIZE
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cache_instrument_atlas()
	queue_redraw()

func _cache_instrument_atlas() -> void:
	_instrument_textures.clear()
	_atlas_texture = null
	if not ResourceLoader.exists(INSTRUMENT_ATLAS_PATH, "Texture2D"):
		_warn_atlas_fallback()
		return
	var loaded := ResourceLoader.load(INSTRUMENT_ATLAS_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if not (loaded is Texture2D):
		_warn_atlas_fallback()
		return
	var atlas := loaded as Texture2D
	if atlas.get_width() < ATLAS_CELL_SIZE * 2 or atlas.get_height() < ATLAS_CELL_SIZE * 2:
		_warn_atlas_fallback()
		return
	_atlas_texture = atlas
	for index in range(4):
		var region := Rect2((index % 2) * ATLAS_CELL_SIZE, (index >> 1) * ATLAS_CELL_SIZE, ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
		var quadrant := AtlasTexture.new()
		quadrant.atlas = atlas
		quadrant.region = region
		_instrument_textures.append(quadrant)

func _warn_atlas_fallback() -> void:
	if _atlas_warning_logged:
		return
	_atlas_warning_logged = true
	push_warning("MelodyMemoryView: could not load instrument atlas at " + INSTRUMENT_ATLAS_PATH + "; using procedural instrument drawings")

func update_frame(snapshot: Dictionary, time_of_day: String = "noon", reduced_motion: bool = false) -> void:
	_snapshot = snapshot
	_time_of_day = time_of_day if time_of_day in PHASES else "noon"
	_reduced_motion = reduced_motion
	queue_redraw()

func scene_bounds() -> Rect2:
	return SCENE_BOUNDS

func hud_safe_rect() -> Rect2:
	return HUD_SAFE_RECT

func timeline_bounds() -> Rect2:
	return TIMELINE_RECT

func roll_case_bounds() -> Rect2:
	return ROLL_CASE_BOUNDS

func crank_label_bounds() -> Rect2:
	return CRANK_LABEL_BOUNDS

func table_bounds() -> Rect2:
	return TABLE_BOUNDS

func instrument_bounds(index: int) -> Rect2:
	if index < 0 or index >= INSTRUMENT_CENTERS.size():
		return Rect2()
	var center := INSTRUMENT_CENTERS[index]
	var measured := instrument_visual_bounds(index)
	var target_size := INSTRUMENT_SIZES[index]
	var target := Rect2(center - target_size * 0.5, target_size)
	return target.merge(measured)

## Union of the actual shape, trim, mallet/striker, shadow, and optional cue halo.
## Geometry tests use this instead of assuming the click target equals the drawing.
func instrument_visual_bounds(index: int) -> Rect2:
	if index < 0 or index >= INSTRUMENT_CENTERS.size():
		return Rect2()
	var center := INSTRUMENT_CENTERS[index]
	if _instrument_textures.size() == 4:
		var texture_rect := _instrument_texture_rect(index)
		var source_bounds := ATLAS_ALPHA_BOUNDS[index]
		var scale := texture_rect.size.x / float(ATLAS_CELL_SIZE)
		var content := Rect2(texture_rect.position + source_bounds.position * scale, source_bounds.size * scale)
		var union := content.merge(_ellipse_bounds(center + Vector2(0, 69), Vector2(72, 11), 0.0))
		if cue_is_visible(index):
			union = union.merge(_ellipse_bounds(center, Vector2(82, 82), 0.0))
		return union
	var shape_rects: Array[Rect2] = []
	match index:
		0:
			shape_rects.append(_points_bounds(PackedVector2Array([center + Vector2(-72, 45), center + Vector2(-62, -27), center + Vector2(-37, -66), center + Vector2(0, -79), center + Vector2(37, -66), center + Vector2(62, -27), center + Vector2(72, 45)]), 4.0))
			shape_rects.append(Rect2(center + Vector2(-62, 5), Vector2(124, 62)))
			shape_rects.append(_ellipse_bounds(center + Vector2(0, 24), Vector2(9, 9), 1.0))
		1:
			shape_rects.append(_points_bounds(PackedVector2Array([center + Vector2(-49, -55), center + Vector2(49, -55), center + Vector2(44, 5), center + Vector2(67, 45), center + Vector2(58, 62), center + Vector2(-58, 62), center + Vector2(-67, 45), center + Vector2(-44, 5)]), 4.0))
			shape_rects.append(_ellipse_bounds(center + Vector2(0, -79), Vector2(9, 9), 2.0))
			shape_rects.append(Rect2(center + Vector2(-40, 33), Vector2(80, 40)))
		2:
			shape_rects.append(Rect2(center + Vector2(-81, -45), Vector2(162, 99)).grow(4.0))
			shape_rects.append(_line_bounds(center + Vector2(54, -64), center + Vector2(83, -91), 4.0))
			shape_rects.append(_ellipse_bounds(center + Vector2(85, -94), Vector2(12, 12), 2.0))
		3:
			shape_rects.append(Rect2(center + Vector2(-69, -37), Vector2(138, 87)))
			shape_rects.append(_ellipse_bounds(center + Vector2(0, -37), Vector2(69, 24), 4.0))
			shape_rects.append(_ellipse_bounds(center + Vector2(0, 49), Vector2(69, 19), 4.0))
			shape_rects.append(_line_bounds(center + Vector2(-36, -88), center + Vector2(29, -58), 4.0))
			shape_rects.append(_ellipse_bounds(center + Vector2(32, -57), Vector2(11, 11), 2.0))
	shape_rects.append(_ellipse_bounds(center + Vector2(0, 69), Vector2(72, 11), 0.0))
	if cue_is_visible(index):
		shape_rects.append(_ellipse_bounds(center, Vector2(82, 82), 0.0))
	var union := shape_rects[0]
	for shape_rect in shape_rects:
		union = union.merge(shape_rect)
	return union

func instrument_label_bounds(index: int) -> Rect2:
	if index < 0 or index >= INSTRUMENT_CENTERS.size():
		return Rect2()
	return Rect2(INSTRUMENT_CENTERS[index].x - 98.0, 548.0, 196.0, 40.0)

func instrument_texture_bounds(index: int) -> Rect2:
	if index < 0 or index >= INSTRUMENT_CENTERS.size() or _instrument_textures.size() != 4:
		return Rect2()
	var rect := _instrument_texture_rect(index)
	var scale := rect.size.x / float(ATLAS_CELL_SIZE)
	var content := ATLAS_ALPHA_BOUNDS[index]
	return Rect2(rect.position + content.position * scale, content.size * scale)

func has_instrument_atlas() -> bool:
	return _instrument_textures.size() == 4

func atlas_region_bounds(index: int) -> Rect2:
	if index < 0 or index >= _instrument_textures.size():
		return Rect2()
	return (_instrument_textures[index] as AtlasTexture).region

func atlas_resource_cached_correctly() -> bool:
	if not has_instrument_atlas() or _atlas_texture == null:
		return false
	for index in range(4):
		var quadrant := _instrument_textures[index] as AtlasTexture
		if quadrant.atlas != _atlas_texture or quadrant.atlas.resource_path != INSTRUMENT_ATLAS_PATH:
			return false
	return true

func _instrument_texture_rect(index: int) -> Rect2:
	var center := INSTRUMENT_CENTERS[index] + Vector2(0, -13)
	return Rect2(center - Vector2.ONE * (ATLAS_DRAW_SIZE * 0.5), Vector2.ONE * ATLAS_DRAW_SIZE)

func playable_bounds() -> Rect2:
	return Rect2(Vector2(96, 348), Vector2(1088, 236))

func instrument_kind(index: int) -> String:
	return ["shell_reed", "glass_bell", "wood_block", "harbor_drum"][index] if index >= 0 and index < 4 else ""

func cue_is_visible(index: int, snapshot: Dictionary = {}) -> bool:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return int(state.get("current_cue", -1)) == index

func rhythm_markers(snapshot: Dictionary = {}) -> Array:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	return state.get("heard_notes", [])

func visual_motion_enabled() -> bool:
	return not _reduced_motion

func palette_phase() -> String:
	return _time_of_day

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var point := _design_point(event.position)
	for index in range(4):
		if instrument_bounds(index).has_point(point):
			note_requested.emit(index)
			accept_event()
			return
	if REPLAY_RECT.has_point(point):
		replay_requested.emit()
		accept_event()

func _design_point(point: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return point
	return Vector2(point.x * DESIGN_SIZE.x / size.x, point.y * DESIGN_SIZE.y / size.y)

func _ellipse_bounds(center: Vector2, radius: Vector2, stroke: float) -> Rect2:
	var half_size := radius + Vector2.ONE * stroke
	return Rect2(center - half_size, half_size * 2.0)

func _line_bounds(start: Vector2, finish: Vector2, stroke_radius: float) -> Rect2:
	return Rect2(start, Vector2.ZERO).expand(finish).grow(stroke_radius)

func _points_bounds(points: PackedVector2Array, stroke_radius: float) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result.grow(stroke_radius)

func _draw() -> void:
	var colors := _palette()
	var paper: Color = colors.paper
	var ink: Color = colors.ink
	var sea: Color = colors.sea
	var teal: Color = colors.teal
	var coral: Color = colors.coral
	var brass: Color = colors.brass
	var wood: Color = colors.wood
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), colors.sky)
	_draw_seaside_backdrop(paper, ink, sea, wood, brass)
	_draw_music_roll(paper, ink, brass, teal, wood)
	_draw_phase_steps(ink, brass, teal)
	_draw_instruments(ink, paper, brass, teal, coral, wood)
	_draw_controls(ink, paper, coral)

func _palette() -> Dictionary:
	match _time_of_day:
		"dawn":
			return {"sky": Color("#d4d5c8"), "paper": Color("#eee0bd"), "ink": Color("#304452"), "sea": Color("#83aeb0"), "teal": Color("#4b8884"), "coral": Color("#cb7861"), "brass": Color("#be9150"), "wood": Color("#795a43")}
		"dusk":
			return {"sky": Color("#c6ad9b"), "paper": Color("#e7d3b4"), "ink": Color("#2e3e4a"), "sea": Color("#6f9295"), "teal": Color("#538080"), "coral": Color("#d17962"), "brass": Color("#bc8950"), "wood": Color("#725340")}
		"night":
			return {"sky": Color("#334955"), "paper": Color("#d6d7c1"), "ink": Color("#203540"), "sea": Color("#4e7d83"), "teal": Color("#65a9a1"), "coral": Color("#da8b70"), "brass": Color("#dbbc76"), "wood": Color("#55493e")}
		_:
			return {"sky": Color("#d7e1d7"), "paper": Color("#f0e3c4"), "ink": Color("#263f50"), "sea": Color("#80b4b1"), "teal": Color("#4b8985"), "coral": Color("#c86d60"), "brass": Color("#bd9252"), "wood": Color("#795a43")}

func _draw_seaside_backdrop(paper: Color, ink: Color, sea: Color, wood: Color, brass: Color) -> void:
	draw_rect(Rect2(0, 605, 1280, 115), sea)
	draw_line(Vector2(0, 608), Vector2(1280, 608), ink.darkened(0.1), 3.0)
	for wave in range(7):
		var y := 626.0 + float(wave) * 14.0
		for x in range(24 + wave % 2 * 48, 1260, 112):
			draw_arc(Vector2(x, y), 24.0, PI, TAU, 12, paper.darkened(0.12), 1.5, true)
	draw_rect(Rect2(0, 142, 1280, 4), ink.darkened(0.12))
	_draw_pier_silhouette(ink.darkened(0.22))
	_draw_harbor_table(paper, ink, wood, brass)

func _draw_harbor_table(paper: Color, ink: Color, wood: Color, brass: Color) -> void:
	var apron := TABLE_BOUNDS
	var top := Rect2(apron.position + Vector2(0, 8), Vector2(apron.size.x, 174))
	draw_rect(apron, wood.darkened(0.28))
	draw_rect(top, wood)
	draw_rect(top, ink.darkened(0.18), false, 3.0, true)
	draw_rect(top.grow(-9), wood.lightened(0.09), false, 1.5, true)
	# A few long grain lines make the stage read as a joined harbor workbench.
	for seam_y in [top.position.y + 42.0, top.position.y + 126.0]:
		draw_line(Vector2(top.position.x + 18, seam_y), Vector2(top.end.x - 18, seam_y), wood.darkened(0.2), 2.0)
	for x in [top.position.x + 20, top.end.x - 20]:
		for y in [top.position.y + 18, top.end.y - 18]:
			draw_circle(Vector2(x, y), 5.0, brass)
			draw_circle(Vector2(x, y), 2.0, ink.darkened(0.15))
	draw_rect(Rect2(apron.position.x, apron.end.y - 51, apron.size.x, 8), brass.darkened(0.12))


func _draw_pier_silhouette(ink: Color) -> void:
	draw_rect(Rect2(44, 344, 87, 18), ink)
	draw_rect(Rect2(53, 362, 8, 30), ink)
	draw_rect(Rect2(112, 362, 8, 30), ink)
	draw_rect(Rect2(1150, 353, 84, 17), ink)
	draw_rect(Rect2(1160, 370, 7, 26), ink)
	draw_rect(Rect2(1216, 370, 7, 26), ink)

func _draw_music_roll(paper: Color, ink: Color, brass: Color, teal: Color, wood: Color) -> void:
	var roll := Rect2(TIMELINE_RECT.position, TIMELINE_RECT.size)
	draw_rect(ROLL_CASE_BOUNDS, wood.darkened(0.12))
	draw_rect(ROLL_CASE_BOUNDS, ink, false, 2.0, true)
	draw_rect(ROLL_CASE_BOUNDS.grow(-7), brass.darkened(0.15), false, 1.5, true)
	draw_rect(roll, paper)
	draw_rect(roll, ink, false, 2.0, true)
	draw_rect(Rect2(roll.position.x, roll.position.y, 18, roll.size.y), brass)
	draw_rect(Rect2(roll.end.x - 18, roll.position.y, 18, roll.size.y), brass)
	# A visible crank and perforated paper roll frame this like a working seaside music box.
	draw_circle(Vector2(150, 250), 36, brass)
	draw_circle(Vector2(150, 250), 25, paper)
	draw_circle(Vector2(150, 250), 7, ink)
	draw_line(Vector2(150, 250), Vector2(173, 221), ink, 5.0)
	draw_circle(Vector2(178, 215), 9, teal)
	draw_rect(CRANK_LABEL_BOUNDS, paper)
	draw_rect(CRANK_LABEL_BOUNDS, ink, false, 1.5, true)
	draw_string(FontProfiles.current_font(), Vector2(45, 308), "手搖樂譜", HORIZONTAL_ALIGNMENT_LEFT, 122, 17, ink)
	var notes: Array = rhythm_markers()
	var count := notes.size()
	if count > 0:
		var pattern: Array = _snapshot.get("rhythm", [])
		var cursor_x := 224.0
		var baseline := 264.0
		for i in range(count):
			var cue := clampi(int(notes[i]), 0, 3)
			var x := cursor_x
			var y := baseline - cue * 16.0
			draw_line(Vector2(x, y), Vector2(x + 34, y), ink, 3.0)
			var note_colors: Array[Color] = [teal, Color("#c86d60"), brass, ink]
			draw_circle(Vector2(x + 18, y), 8, note_colors[cue])
			draw_circle(Vector2(x + 18, 287), 5, ink.darkened(0.12))
			if i + 1 < count:
				var beat_gap := float(pattern[i + 1]) if i + 1 < pattern.size() else 0.5
				cursor_x += 54.0 + beat_gap * 55.0
	_draw_roll_rail(roll, brass, ink)

func _draw_roll_rail(roll: Rect2, brass: Color, ink: Color) -> void:
	for x in range(int(roll.position.x + 32), int(roll.end.x - 25), 38):
		draw_circle(Vector2(x, roll.position.y + 9), 2.5, ink.darkened(0.14))
		draw_circle(Vector2(x, roll.end.y - 9), 2.5, ink.darkened(0.14))
	draw_circle(Vector2(roll.position.x + 9, roll.position.y + 10), 5, brass.lightened(0.18))
	draw_circle(Vector2(roll.end.x - 9, roll.end.y - 10), 5, brass.lightened(0.18))

func _draw_instruments(ink: Color, paper: Color, brass: Color, teal: Color, coral: Color, wood: Color) -> void:
	var fills: Array[Color] = [Color("#ead4ab"), Color("#c5e2d9"), Color("#b78454"), Color("#d9a07a")]
	for index in range(4):
		var center := INSTRUMENT_CENTERS[index]
		var active := cue_is_visible(index)
		var fill: Color = fills[index]
		if active:
			fill = fill.lightened(0.23)
			draw_circle(center, 82, (teal if index % 2 == 0 else coral).lightened(0.19))
		_draw_instrument_shadow(center, wood)
		if has_instrument_atlas():
			draw_texture_rect(_instrument_textures[index], _instrument_texture_rect(index), false, Color.WHITE)
		else:
			match index:
				0: _draw_shell_reed(center, fill, ink, brass, teal)
				1: _draw_glass_bell(center, fill, ink, brass, teal)
				2: _draw_wood_block(center, fill, ink, brass, wood)
				3: _draw_harbor_drum(center, fill, ink, brass, coral)
		var box: Rect2 = instrument_label_bounds(index)
		draw_rect(box, Color("#102b3a"))
		draw_rect(box, brass, false, 2.0)
		draw_string(FontProfiles.current_font(), Vector2(box.position.x + 8, box.position.y + 18), KEY_LABELS[index] + "  " + INSTRUMENT_NAMES[index], HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 16, 16, Color("#f4eedc"))
		draw_string(FontProfiles.current_font(), Vector2(box.position.x + 8, box.position.y + 35), "或鍵盤 " + SECONDARY_KEYS[index], HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 16, 12, Color("#c7dbd4"))

func _draw_instrument_shadow(center: Vector2, wood: Color) -> void:
	_draw_ellipse(center + Vector2(0, 69), Vector2(72, 11), wood.darkened(0.10))

func _draw_shell_reed(center: Vector2, fill: Color, ink: Color, brass: Color, teal: Color) -> void:
	var shell := PackedVector2Array([center + Vector2(-72, 45), center + Vector2(-62, -27), center + Vector2(-37, -66), center + Vector2(0, -79), center + Vector2(37, -66), center + Vector2(62, -27), center + Vector2(72, 45)])
	draw_colored_polygon(shell, fill)
	draw_polyline(PackedVector2Array([center + Vector2(-72, 45), center + Vector2(-62, -27), center + Vector2(-37, -66), center + Vector2(0, -79), center + Vector2(37, -66), center + Vector2(62, -27), center + Vector2(72, 45)]), ink, 4.0, true)
	for rib in range(-2, 3):
		draw_line(center + Vector2(rib * 17.0, -50), center + Vector2(rib * 22.0, 36), brass, 3.0)
	draw_arc(center + Vector2(0, 5), 62, 0.0, PI, 20, teal, 5.0, true)
	draw_circle(center + Vector2(0, 24), 9, brass)
	for rivet_x in [-53.0, 53.0]:
		draw_circle(center + Vector2(rivet_x, 38), 4.5, brass)

func _draw_glass_bell(center: Vector2, fill: Color, ink: Color, brass: Color, teal: Color) -> void:
	var bell := PackedVector2Array([center + Vector2(-49, -55), center + Vector2(49, -55), center + Vector2(44, 5), center + Vector2(67, 45), center + Vector2(58, 62), center + Vector2(-58, 62), center + Vector2(-67, 45), center + Vector2(-44, 5)])
	draw_colored_polygon(bell, fill)
	draw_polyline(PackedVector2Array([bell[0], bell[1], bell[2], bell[3], bell[4], bell[5], bell[6], bell[7], bell[0]]), ink, 4.0, true)
	draw_line(center + Vector2(-31, -44), center + Vector2(-26, 20), teal.lightened(0.2), 6.0)
	draw_line(center + Vector2(31, -44), center + Vector2(26, 20), brass, 4.0)
	draw_arc(center + Vector2(0, 33), 40, 0.0, PI, 18, ink, 3.0, true)
	draw_line(center + Vector2(0, -63), center + Vector2(0, -78), brass, 6.0)
	draw_circle(center + Vector2(0, -79), 9, brass)
	draw_circle(center + Vector2(-51, -43), 4, brass)
	draw_circle(center + Vector2(51, -43), 4, brass)

func _draw_wood_block(center: Vector2, fill: Color, ink: Color, brass: Color, wood: Color) -> void:
	var block := Rect2(center + Vector2(-81, -45), Vector2(162, 99))
	draw_rect(block, fill)
	draw_rect(block, ink, false, 7.0, true)
	draw_rect(block.grow(-12), wood.lightened(0.17))
	draw_rect(block.grow(-12), brass, false, 3.0, true)
	draw_line(center + Vector2(-50, -17), center + Vector2(50, -17), ink.darkened(0.15), 3.0)
	draw_line(center + Vector2(-50, 10), center + Vector2(50, 10), ink.darkened(0.15), 3.0)
	draw_line(center + Vector2(-53, 31), center + Vector2(-22, 24), wood.lightened(0.3), 2.0)
	draw_line(center + Vector2(18, -32), center + Vector2(53, -38), wood.lightened(0.3), 2.0)
	for fastener in [Vector2(-67, -31), Vector2(67, -31), Vector2(-67, 40), Vector2(67, 40)]:
		draw_circle(center + fastener, 4, brass)
	draw_line(center + Vector2(54, -64), center + Vector2(83, -91), ink, 8.0)
	draw_circle(center + Vector2(85, -94), 12, brass)

func _draw_harbor_drum(center: Vector2, fill: Color, ink: Color, brass: Color, coral: Color) -> void:
	draw_rect(Rect2(center + Vector2(-69, -37), Vector2(138, 87)), fill)
	_draw_ellipse(center + Vector2(0, -37), Vector2(69, 24), coral.lightened(0.15))
	_draw_ellipse(center + Vector2(0, -37), Vector2(69, 24), ink, false, 4.0)
	draw_line(center + Vector2(-69, -36), center + Vector2(-69, 47), ink, 4.0)
	draw_line(center + Vector2(69, -36), center + Vector2(69, 47), ink, 4.0)
	_draw_ellipse(center + Vector2(0, 49), Vector2(69, 19), fill)
	_draw_ellipse(center + Vector2(0, 49), Vector2(69, 19), ink, false, 4.0)
	for lace_x in [-50.0, -25.0, 0.0, 25.0, 50.0]:
		draw_line(center + Vector2(lace_x, -15), center + Vector2(lace_x, 30), brass, 3.0)
	draw_line(center + Vector2(-36, -88), center + Vector2(29, -58), ink, 8.0)
	draw_circle(center + Vector2(32, -57), 11, brass)

func _draw_controls(ink: Color, paper: Color, coral: Color) -> void:
	var ui_ink := Color("#102b3a")
	var ivory := Color("#f4eedc")
	var phase := str(_snapshot.get("phase", "listen"))
	var phrase_no := int(_snapshot.get("phrase_number", 1))
	var phrase_total := int(_snapshot.get("phrase_count", 3))
	var completed := int(_snapshot.get("completed_phrases", 0))
	draw_rect(Rect2(190, 592, 230, 39), ui_ink)
	draw_rect(Rect2(190, 592, 230, 39), Color("#dfb95f"), false, 2.0)
	draw_string(FontProfiles.current_font(), Vector2(199, 609), "樂句 %d / %d" % [phrase_no, phrase_total], HORIZONTAL_ALIGNMENT_LEFT, 112, 14, ivory)
	for dot in range(phrase_total):
		var color := Color("#71c7b5") if dot < completed else Color("#607986")
		draw_circle(Vector2(324 + dot * 28, 611), 7, color)
	# Session shows last_event as a brief HUD toast. Keep this persistent stage
	# strip useful after that toast fades without repeating the same sentence.
	var message := _stage_feedback_message()
	draw_rect(Rect2(168, 331, 924, 27), ui_ink)
	draw_rect(Rect2(168, 331, 924, 27), Color("#dfb95f"), false, 1.0)
	draw_string(FontProfiles.current_font(), Vector2(177, 350), message, HORIZONTAL_ALIGNMENT_CENTER, 900, 17, ivory)
	draw_rect(Rect2(198, 146, 228, 25), ui_ink)
	draw_rect(Rect2(198, 146, 228, 25), Color("#dfb95f"), false, 1.0)
	draw_string(FontProfiles.current_font(), Vector2(202, 165), _phase_label(), HORIZONTAL_ALIGNMENT_LEFT, 216, 18, ivory)
	if phase == "active" and bool(_snapshot.get("replay_available", false)):
		draw_rect(REPLAY_RECT, ui_ink)
		draw_rect(REPLAY_RECT, Color("#dfb95f"), false, 2.0)
		draw_arc(REPLAY_RECT.position + Vector2(28, 29), 13, 0.25, TAU * 0.9, 20, coral, 3.0, true)
		draw_string(FontProfiles.current_font(), Vector2(REPLAY_RECT.position.x + 48, REPLAY_RECT.position.y + 36), "重聽 %d/%d" % [int(_snapshot.get("replay_count", 0)), int(_snapshot.get("replay_limit", 2))], HORIZONTAL_ALIGNMENT_LEFT, 95, 17, ivory)
	else:
		draw_rect(REPLAY_RECT, Color("#203f4e"))
		draw_rect(REPLAY_RECT, Color("#70828a"), false, 2.0)
		draw_string(FontProfiles.current_font(), Vector2(REPLAY_RECT.position.x + 10, REPLAY_RECT.position.y + 36), "重聽（演奏時）", HORIZONTAL_ALIGNMENT_CENTER, 130, 14, Color("#a7b8b6"))
	draw_rect(Rect2(38, 592, 138, 39), ui_ink)
	draw_rect(Rect2(38, 592, 138, 39), Color("#dfb95f"), false, 1.0)
	draw_string(FontProfiles.current_font(), Vector2(46, 609), "音高", HORIZONTAL_ALIGNMENT_LEFT, 58, 13, ivory)
	draw_string(FontProfiles.current_font(), Vector2(46, 626), "＋ 節奏", HORIZONTAL_ALIGNMENT_LEFT, 100, 13, ivory)
	draw_rect(Rect2(682, 603, 362, 28), ui_ink)
	draw_rect(Rect2(682, 603, 362, 28), Color("#dfb95f"), false, 1.0)
	draw_string(FontProfiles.current_font(), Vector2(690, 622), "錯誤 %d   精準音 %d" % [int(_snapshot.get("error_count", 0)), int(_snapshot.get("precise_notes", 0))], HORIZONTAL_ALIGNMENT_RIGHT, 346, 14, ivory)
	if _reduced_motion:
		draw_rect(Rect2(974, 146, 220, 25), ui_ink)
		draw_rect(Rect2(974, 146, 220, 25), Color("#dfb95f"), false, 1.0)
		draw_string(FontProfiles.current_font(), Vector2(973, 163), "靜態音符標記", HORIZONTAL_ALIGNMENT_RIGHT, 220, 14, ivory)

func _stage_feedback_message() -> String:
	match str(_snapshot.get("phase", "listen")):
		"listen": return "先聽完樂句，記住四件樂器的順序"
		"ready": return "準備重現旋律，留意音高與節奏"
		"active": return "依照剛才聽到的順序演奏"
		"wrong_pause": return "再聽一次，留意旋律的高低與間隔"
		"complete": return "這段合奏完成"
		"encore": return "全體樂器一起合奏剛完成的樂句"
		"finale": return "三句完成：終曲合奏"
		_: return "跟著手搖樂譜聽拍點"

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	draw_ellipse(center, radius.x, radius.y, color, filled, width, true)

## 0 示範, 1 記住, 2 演奏, 3 合奏 — the step the stage is in now.
func phase_step(snapshot: Dictionary = {}) -> int:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	match str(state.get("phase", "listen")):
		"listen", "wrong_pause": return 0
		"ready": return 1
		"active": return 2
		"encore", "finale", "complete": return 3
	return 0

## Hidden note slots the player must recall: total and how many are already played.
func memory_slots(snapshot: Dictionary = {}) -> Vector2i:
	var state := snapshot if not snapshot.is_empty() else _snapshot
	var phase := str(state.get("phase", "listen"))
	if phase != "ready" and phase != "active":
		return Vector2i.ZERO
	return Vector2i(int(state.get("phrase_length", 0)), int(state.get("input_index", 0)) if phase == "active" else 0)

func _draw_phase_steps(ink: Color, brass: Color, teal: Color) -> void:
	var labels: Array[String] = ["示範", "記住", "演奏", "合奏"]
	var current := phase_step()
	for index in labels.size():
		var chip := Rect2(560.0 + float(index) * 96.0, 146.0, 88.0, 25.0)
		var active := index == current
		draw_rect(chip, teal if active else Color("#102b3a"))
		draw_rect(chip, brass if active else Color("#55707a"), false, 1.5)
		draw_string(FontProfiles.current_font(), chip.position + Vector2(0.0, 18.0), "%d %s" % [index + 1, labels[index]], HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 14, Color("#f4eedc") if active else Color("#a7b8b6"))
	var slots := memory_slots()
	for slot in slots.x:
		var center := Vector2(250.0 + float(slot) * 62.0, 245.0)
		draw_circle(center, 13.0, Color("#102b3a") if slot >= slots.y else teal)
		draw_arc(center, 13.0, 0.0, TAU, 24, brass, 2.0, true)
		if slot >= slots.y:
			draw_string(FontProfiles.current_font(), center + Vector2(-8.0, 6.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color("#f4eedc"))

func _phase_label() -> String:
	match str(_snapshot.get("phase", "listen")):
		"listen": return "聽・看樂句"
		"ready": return "準備演奏"
		"active": return "照節奏重現"
		"wrong_pause": return "再聽一次"
		"complete": return "合奏完成"
		"encore": return "合奏回放"
		"finale": return "終曲合奏"
		_: return "海風樂譜"
