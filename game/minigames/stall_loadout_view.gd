extends "res://game/ui/minigame_hold_controls.gd"

signal piece_tapped(index: int)
signal cell_tapped(cell: Vector2i)

const Model = preload("res://game/minigames/stall_loadout_model.gd")
const ART := "res://assets/minigames/stall-loadout-alcove.webp"
const ORIGIN := Vector2(445, 313)
const EAST_AXIS := Vector2(44, 11)
const SOUTH_AXIS := Vector2(-32, 20)
const HEIGHT := Vector2(0, -34)
const UNDO_RECT := Rect2(919, 463, 306, 53)
const READOUT := Rect2(900, 216, 344, 306)
const MISS := Vector2i(-1, -1)
const INK := Color("#1b2429")
const CARD := Color("#252c30")
const EDGE := Color("#746658")
const AMBER := Color("#f4bd7c")
const TEXT := Color("#fff0d8")
const MUTED := Color("#b9cbc3")
const MINT := Color("#9ee7bb")
const CORAL := Color("#ffa38d")
const MATERIALS := [Color("#507f91"), Color("#ab8258"), Color("#b77643"), Color("#71875b"), Color("#dbcbc0")]
const PHASE_WASH := {"dawn": Color(0.33, 0.31, 0.26, 0.08), "noon": Color(0.51, 0.37, 0.22, 0.08),
	"dusk": Color(0.65, 0.29, 0.14, 0.07), "night": Color(0.04, 0.09, 0.15, 0.06)}
const PLACEMENT_SECONDS := 0.17
## Lacquered stall wood, the cart's deck boards, and the finish of each piece
## (pot, rack, tray, crate, plates).
const LACQUER := Color("#3a2a26")
const DECK_WOOD := Color("#7a5640")
const FINISHES := ["metal", "wood", "wood", "wood", "paper"]
const EXTRACTION_SECONDS := 0.53
const DRAW_KEYS := [&"focus", &"layer", &"selected", &"angle", &"fit", &"ghost", &"secured", &"devil", &"feedback", &"straps", &"pot_path", &"ended"]
const CONTROL_KEYS := [&"secured", &"devil", &"selected", &"can_undo", &"ended", &"control_mask"]

enum { NORTH, EAST, SOUTH, WEST, PLACE, ROTATE, LEVEL, PHASE, UNDO, CYCLE }

const LABELS := ["往上移 · ↑", "往右移 · →", "往下移 · ↓", "往左移 · ←",
	"放置 · E", "轉向 · Q", "換層 · R", "綁帶 · F"]
const KEY_ICONS := ["up", "right", "down", "left", "grab", "turn_right", "layers", "strap"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
const NAMES := ["StallLoadoutNorth", "StallLoadoutEast", "StallLoadoutSouth", "StallLoadoutWest",
	"StallLoadoutPlace", "StallLoadoutRotate", "StallLoadoutLevel", "StallLoadoutPhase"]
const CARGO_HINTS := ["底層湯鍋；高難度需沿開口抽出。", "木架中央有空位，可套進器具。", "料盒有凸起，先確認上方格位。",
	"食材箱占底面數格。", "疊盤薄而寬，可填入承托面。"]
const FEEDBACK := {
	&"outside": "凸出車架，移位或轉向。", &"collision": "格位已占用，轉向或換層。",
	&"unsupported": "底下沒有承托。", &"incomplete": "先放齊五件器具。",
	&"strap_gap": "兩道綁帶都須接觸器具。", &"exit_blocked": "湯鍋抽不出，請解帶調整。",
	&"secured": "可先抽湯鍋，或直接交車。", &"unsecured": "已解帶，可調整器具。",
	&"extracted": "按 E 或 A 確認交車。", &"undo": "已還原上一次擺放。",
	&"finished": "器具裝車完成。", &"time": "時間到。",
}

var _state: Dictionary = {}
var _alcove: Texture2D
var _slots: Array[Button] = []
var _undo: Button
var _reduced_motion := false
var _phase := "night"
var _pieces: Array = []
var _voxels: Array[Vector3i] = []
var _occupied: Dictionary[Vector3i, int] = {}
var _moving := -1
var _settling := 1.0
var _extracting := 1.0
var _label_font: Font
var _label_scale := 1.0
var _label_style := ""
var _label_locale := ""
var _shown_control_mask := -1


static func piece_rect(index: int) -> Rect2:
	if index < 0 or index >= Model.PIECE_COUNT:
		return Rect2()
	return Rect2(35 + index * 244, 147, 234, 54)


static func hit_piece(point: Vector2) -> int:
	if not point.is_finite():
		return -1
	for index in Model.PIECE_COUNT:
		if piece_rect(index).has_point(point):
			return index
	return -1


static func hit_undo(point: Vector2) -> bool:
	return point.is_finite() and UNDO_RECT.has_point(point)


static func cell_center(cell: Vector2i, layer: int) -> Vector2:
	return _project(Vector3(float(cell.x) + 0.5, float(layer), float(cell.y) + 0.5))


static func hit_cell(point: Vector2, layer: int) -> Vector2i:
	if not point.is_finite() or layer < 0 or layer >= Model.DECK.y:
		return MISS
	var delta := point - ORIGIN - HEIGHT * layer
	var determinant := EAST_AXIS.cross(SOUTH_AXIS)
	var x := floori(delta.cross(SOUTH_AXIS) / determinant)
	var z := floori(EAST_AXIS.cross(delta) / determinant)
	return Vector2i(x, z) if x >= 0 and x < Model.DECK.x and z >= 0 and z < Model.DECK.z else MISS


static func _project(cell: Vector3) -> Vector2:
	return ORIGIN + EAST_AXIS * cell.x + HEIGHT * cell.y + SOUTH_AXIS * cell.z


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.get("ended", true) or action < NORTH or action > CYCLE:
		return false
	if state.get("secured", false):
		return action == PLACE or ((action == PHASE or action == UNDO) and not state.get("devil", false))
	if action == UNDO:
		return state.get("can_undo", false)
	return true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_alcove = load(ART) as Texture2D
	build_controls(LABELS, Color("#26343b"), Color("#614733"), EDGE, AMBER)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	use_key_caps(KEY_ICONS, KEY_TONE)
	for index in Model.PIECE_COUNT:
		var normal: Color = MATERIALS[index].darkened(0.68)
		var slot := _tool_button("StallLoadoutPiece%d" % index, piece_rect(index), normal, normal.lightened(0.15))
		slot.text = Model.NAMES[index]
		_slots.append(slot)
	_undo = _tool_button("StallLoadoutUndo", UNDO_RECT, Color("#3e3833"), Color("#604d38"))
	_undo.text = "撤回 · U"
	_refresh_fonts()
	_sync_controls()
	set_process(false)


func _tool_button(id: String, rect: Rect2, normal: Color, active: Color) -> Button:
	var button := Button.new()
	button.name = id
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.toggle_mode = true
	# The view paints a key cap under each one; the Button keeps its text.
	for style in ["normal", "hover", "focus", "disabled", "pressed", "hover_pressed"]:
		var box := StyleBoxEmpty.new()
		box.content_margin_bottom = 8.0 - (KEY_SINK if style.contains("pressed") else 0.0)
		box.content_margin_top = KEY_SINK if style.contains("pressed") else 0.0
		button.add_theme_stylebox_override(style, box)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button


func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	if super.handle_pointer(event, point):
		return true
	var source := pointer_source(event)
	if source.is_empty() or not event.pressed or event.is_canceled():
		return false
	if hit_undo(point) and action_available(UNDO, _state):
		command.emit(UNDO, true, source)
		command.emit(UNDO, false, source)
		return true
	if not action_available(CYCLE, _state):
		return false
	var piece := hit_piece(point)
	if piece >= 0:
		piece_tapped.emit(piece)
		return true
	var cell := hit_cell(point, int(_state.get("layer", 0)))
	if cell != MISS:
		cell_tapped.emit(cell)
		return true
	return false


func _get_tooltip(point: Vector2) -> String:
	var piece := hit_piece(point)
	if piece >= 0:
		return CARGO_HINTS[piece]
	var tied: bool = _state.get("secured", false)
	if hit_undo(point):
		return "解開綁帶，回到裝載。" if tied else "還原上一次擺放。"
	match hit_slot(point):
		NORTH: return "往車架後側移一格。"
		EAST: return "沿寬度往右移一格。"
		SOUTH: return "往車架前側移一格。"
		WEST: return "沿寬度往左移一格。"
		PLACE: return "確認裝載並交車。" if tied else "在框出的格位放下器具。"
		ROTATE: return "平面轉四分之一圈。"
		LEVEL: return "換到另一層，底下須有承托。"
		PHASE: return "沿車架開口抽出底層湯鍋。" if tied else "五件放齊，讓兩道帶子都碰到器具。"
	if hit_cell(point, int(_state.get("layer", 0))) != MISS and not tied:
		return "先選格，再點同格放下。"
	return ""


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	var previous := _state
	var new_pieces: Array = state.get("pieces", [])
	var new_phase := phase if PHASE_WASH.has(phase) else "night"
	var piece_change: bool = _pieces != new_pieces or state.get("layout") != previous.get("layout")
	var redraw: bool = piece_change or _reduced_motion != reduced_motion or _phase != new_phase
	var control_change: bool = piece_change or _shown_control_mask != int(state.get("control_mask", 0))
	for key in DRAW_KEYS:
		redraw = redraw or previous.get(key) != state.get(key)
	for key in CONTROL_KEYS:
		control_change = control_change or previous.get(key) != state.get(key)
	_state = state
	_reduced_motion = reduced_motion
	_phase = new_phase
	if piece_change:
		_rebuild_load(new_pieces, previous.get("layout") == state.get("layout"))
	if state.get("devil", false) and not previous.get("devil", false) and not reduced_motion:
		_extracting = 0.0
	elif not state.get("devil", false) or reduced_motion:
		_extracting = 1.0
	if reduced_motion:
		_settling = 1.0
	if not is_node_ready():
		return
	redraw = _refresh_fonts() or redraw
	if control_change:
		_sync_controls()
	if redraw:
		queue_redraw()
	var animating := _settling < 1.0 or _extracting < 1.0
	if is_processing() != animating:
		set_process(animating)


func _rebuild_load(pieces: Array, use_transition: bool) -> void:
	var old := _pieces
	_pieces = pieces
	_occupied.clear()
	_voxels.clear()
	for piece: Dictionary in pieces:
		var anchor: Vector3i = piece.anchor
		if anchor == Model.UNPLACED:
			continue
		var id: int = piece.id
		if not _reduced_motion and use_transition and id < old.size() and (old[id].anchor != anchor or old[id].angle != piece.angle):
			_moving = id
			_settling = 0.0
		for part: Vector3i in piece.cells:
			var cell := anchor + part
			_occupied[cell] = id
			_voxels.append(cell)
	_voxels.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var depth_a := a.x + a.z
		var depth_b := b.x + b.z
		if depth_a != depth_b:
			return depth_a < depth_b
		return a.y < b.y if a.y != b.y else a.x < b.x)


func _process(delta: float) -> void:
	_settling = minf(_settling + delta / PLACEMENT_SECONDS, 1.0)
	_extracting = minf(_extracting + delta / EXTRACTION_SECONDS, 1.0)
	queue_redraw()
	if _settling == 1.0 and _extracting == 1.0:
		set_process(false)


func _refresh_fonts() -> bool:
	var scale := Paper.text_scale()
	var style := Paper.font_style()
	var locale := TranslationServer.get_locale()
	if _label_font != null and _label_scale == scale and _label_style == style and _label_locale == locale:
		return false
	var font := Paper.font()
	_label_font = font
	_label_scale = scale
	_label_style = style
	_label_locale = locale
	refresh_font()
	for button in _slots:
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", roundi(20.0 * scale))
	_undo.add_theme_font_override("font", font)
	_undo.add_theme_font_size_override("font_size", roundi(19.0 * scale))
	return true


func _sync_controls() -> void:
	var tied: bool = _state.get("secured", false)
	var mask: int = _state.get("control_mask", 0)
	_shown_control_mask = mask
	for index in _buttons.size():
		_buttons[index].disabled = not action_available(index, _state)
		_buttons[index].set_pressed_no_signal((mask & (1 << index)) != 0)
	_buttons[PLACE].text = "交車 · E" if tied else LABELS[PLACE]
	_buttons[PHASE].text = "抽湯鍋 · F" if tied else LABELS[PHASE]
	var selected: int = _state.get("selected", 0)
	for id in _slots.size():
		var loaded: bool = id < _pieces.size() and _pieces[id].anchor != Model.UNPLACED
		_slots[id].text = "✓  " + Model.NAMES[id] if loaded else Model.NAMES[id]
		_slots[id].disabled = not action_available(CYCLE, _state)
		_slots[id].set_pressed_no_signal(id == selected and not tied)
	_undo.disabled = not action_available(UNDO, _state)
	_undo.text = "解帶 · U / View" if tied else "撤回 · U / View"
	_undo.set_pressed_no_signal((mask & (1 << UNDO)) != 0)
	queue_redraw()


func _draw() -> void:
	if _alcove != null:
		var art_size := _alcove.get_size()
		var visible_height := minf(art_size.y, art_size.x * 601.0 / 1280.0)
		draw_texture_rect_region(_alcove, Rect2(0, 119, 1280, 601),
			Rect2(0, (art_size.y - visible_height) * 0.5, art_size.x, visible_height))
	draw_rect(Rect2(0, 119, 1280, 601), PHASE_WASH[_phase])
	_draw_tool_caps()
	_draw_cart()
	if _state.is_empty():
		return
	_draw_opening()
	_draw_sweep()
	_draw_cargo()
	_draw_straps()
	if not _state.get("secured", false):
		_draw_positioning()
	_draw_readout()


func _draw_tool_caps() -> void:
	for index in _slots.size():
		var slot := _slots[index]
		var held := slot.button_pressed and not slot.disabled
		var tone: Color = MATERIALS[index].darkened(0.45)
		Props.key_cap(self, Rect2(slot.position, slot.size), held, true, tone if not slot.disabled else tone.lerp(Color("#1c1216"), 0.55))


func _draw_cart() -> void:
	var corners := _patch(0.0, 0.0, float(Model.DECK.x), float(Model.DECK.z), 0.0)
	var base := Vector2(0, 15)
	var shadow := PackedVector2Array([corners[0] + Vector2(-17, 27), corners[1] + Vector2(19, 23),
		corners[2] + Vector2(24, 32), corners[3] + Vector2(-17, 39)])
	draw_colored_polygon(shadow, Color(0.02, 0.06, 0.08, 0.55))
	var boards := Props.material_tile("wood", DECK_WOOD)
	for x in [1.1, 5.55]:
		var wheel := _project(Vector3(x, 0, Model.DECK.z)) + Vector2(0, 25)
		Props.contact_shadow(self, wheel + Vector2(4, 14), 40.0, 0.7)
		Props.token(self, wheel, 16.0, Color("#4a3628"))
		draw_arc(wheel, 11.0, 0.0, TAU, 20, Color("#2a1d16"), 2.0, true)
		for spoke in 4:
			var ray := Vector2.from_angle(PI * 0.25 * spoke * 2.0 + 0.4) * 11.0
			draw_line(wheel - ray, wheel + ray, Color("#6e5238"), 2.0, true)
		Props.token(self, wheel, 4.0, Props.BRASS)
	Props.fill_polygon(self, PackedVector2Array([corners[3], corners[2], corners[2] + base, corners[3] + base]), boards, Color(0.5, 0.42, 0.42))
	Props.fill_polygon(self, PackedVector2Array([corners[2], corners[1], corners[1] + base, corners[2] + base]), boards, Color(0.72, 0.6, 0.56))
	# Deck boards run along the cart's width, mapped on the deck's own axes.
	var cell := boards.get_size()
	var deck_uv := PackedVector2Array([Vector2.ZERO, Vector2(Model.DECK.x * 48.0 / cell.x, 0.0),
		Vector2(Model.DECK.x * 48.0 / cell.x, Model.DECK.z * 32.0 / cell.y), Vector2(0.0, Model.DECK.z * 32.0 / cell.y)])
	draw_colored_polygon(corners, Color(0.86, 0.8, 0.78), deck_uv, boards)
	for x in range(1, Model.DECK.x):
		draw_line(_project(Vector3(x, 0, 0)), _project(Vector3(x, 0, Model.DECK.z)), Color(0.14, 0.09, 0.08, 0.35), 1.0, true)
	for z in range(1, Model.DECK.z):
		draw_line(_project(Vector3(0, 0, z)), _project(Vector3(Model.DECK.x, 0, z)), Color(0.14, 0.09, 0.08, 0.35), 1.0, true)
	for band: int in Model.STRAP_ROWS:
		var z := float(band) + 0.5
		draw_dashed_line(_project(Vector3(0, 0, z)), _project(Vector3(Model.DECK.x, 0, z)),
			Color(0.94, 0.68, 0.38, 0.40), 2.0, 7.0, true, true)
	draw_line(corners[0], corners[1], EDGE, 2.0, true)
	draw_line(corners[0], corners[3], EDGE, 2.0, true)


func _draw_opening() -> void:
	var opening: Vector2i = _state.get("opening", Vector2i.ZERO)
	var south: bool = _state.get("exit_direction", Vector3i.ZERO).z > 0
	for axis in 2:
		var length: int = Model.DECK.x if axis == 0 else Model.DECK.z
		for index in length:
			var open := ((axis == 0) == south) and index >= opening.x and index < opening.y
			var a := Vector3(index, 0, Model.DECK.z) if axis == 0 else Vector3(Model.DECK.x, 0, index)
			var b := a + (Vector3.RIGHT if axis == 0 else Vector3.BACK)
			var first := _project(a)
			var last := _project(b)
			if open:
				draw_dashed_line(first, last, AMBER, 2.1, 5.0, true, true)
			else:
				draw_line(first + Vector2(0, -3), last + Vector2(0, -3), Color("#a0754c"), 5.0, true)
				draw_line(first + Vector2(0, -6), last + Vector2(0, -6), Color("#d8a368"), 1.2, true)
	var middle := (opening.x + opening.y) * 0.5
	var start := _project(Vector3(middle, 0, Model.DECK.z) if south else Vector3(Model.DECK.x, 0, middle))
	var forward := (SOUTH_AXIS if south else EAST_AXIS).normalized()
	var end := start + forward * 29.0
	var flank := forward.orthogonal() * 7.0
	draw_line(start, end, AMBER, 2.7, true)
	draw_colored_polygon(PackedVector2Array([end + forward * 6.0, end - forward * 5.0 + flank, end - forward * 5.0 - flank]), AMBER)


func _draw_sweep() -> void:
	var path: Array = _state.get("pot_path", [])
	if path.size() < 2 or _pieces.is_empty():
		return
	var start := _project(Vector3(path[0]) + Vector3(0.5, 0.0, 0.5))
	var finish := _project(Vector3(path[-1]) + Vector3(0.5, 0.0, 0.5))
	draw_dashed_line(start, finish, Color(1.0, 0.80, 0.40, 0.76), 4.0, 9.0, true, true)
	for position: Vector3i in path:
		for part: Vector3i in _pieces[Model.POT].cells:
			var at := position + part
			draw_colored_polygon(_patch(at.x, at.z, 1.0, 1.0, at.y), Color(0.95, 0.71, 0.39, 0.14))


func _draw_cargo() -> void:
	var visible_base := Vector2(0, -13.0 * (1.0 - smoothstep(0.0, 1.0, _settling)))
	for cell in _voxels:
		var id := _occupied[cell]
		_draw_voxel(Vector3(cell), id, visible_base if id == _moving else Vector2.ZERO, _occupied)
	var path: Array = _state.get("pot_path", [])
	if path.size() < 2 or _pieces.is_empty():
		return
	var travel := _extracting * (path.size() - 1)
	var step := mini(floori(travel), path.size() - 2)
	var pot := Vector3(path[step]).lerp(Vector3(path[step + 1]), travel - step)
	for part: Vector3i in _pieces[Model.POT].cells:
		_draw_voxel(pot + Vector3(part), Model.POT, Vector2.ZERO)


func _draw_voxel(cell: Vector3, id: int, offset: Vector2, neighbors: Dictionary = {}) -> void:
	var at := Vector3i(cell)
	var top := _project(cell + Vector3.UP) + offset
	var east := top + EAST_AXIS
	var south := top + SOUTH_AXIS
	var far := east + SOUTH_AXIS
	var down := -HEIGHT
	var color: Color = MATERIALS[id]
	# Each piece keeps its finish (metal, wood or glaze); faces are the same
	# swatch in light or shade, so no face is one flat colour.
	var finish := Props.material_tile(FINISHES[id], color.lightened(0.12))
	var side_z := not neighbors.has(at + Vector3i.BACK)
	var side_x := not neighbors.has(at + Vector3i.RIGHT)
	if side_z:
		Props.fill_polygon(self, PackedVector2Array([south, far, far + down, south + down]), finish, Color(0.5, 0.48, 0.5))
		draw_line(south + down, far + down, Props.deepen(color, 0.6), 1.6, true)
	if side_x:
		Props.fill_polygon(self, PackedVector2Array([far, east, east + down, far + down]), finish, Color(0.68, 0.66, 0.68))
		draw_line(far, far + down, Props.deepen(color, 0.5), 1.3, true)
	if not neighbors.has(at + Vector3i.UP):
		Props.fill_polygon(self, PackedVector2Array([top, east, far, south]), finish)
		if neighbors.get(at - Vector3i.BACK, -1) != id:
			draw_line(top, east, color.lightened(0.40), 1.35, true)
		if neighbors.get(at - Vector3i.RIGHT, -1) != id:
			draw_line(top, south, color.lightened(0.38), 1.35, true)
		if side_z:
			draw_line(south, far, color.darkened(0.23), 1.15, true)
		if side_x:
			draw_line(east, far, color.darkened(0.15), 1.15, true)
		_draw_material_mark(top, id, color)
	if side_z and id == 3:
		for shift: float in [0.24, 0.52, 0.78]:
			var p := south + EAST_AXIS * shift
			draw_line(p + down * 0.20, p + down * 0.80, color.darkened(0.61), 2.0, true)
	if side_x and id == 1:
		draw_line(east.lerp(far, 0.17) + down * 0.53, east.lerp(far, 0.83) + down * 0.53, color.darkened(0.53), 2.0, true)


func _draw_material_mark(top: Vector2, id: int, color: Color) -> void:
	match id:
		0, 4:
			var rim := PackedVector2Array()
			var center := top + (EAST_AXIS + SOUTH_AXIS) * 0.50
			for index in range(10 + 1):
				var d := TAU * float(index) / 10.0
				rim.append(center + (EAST_AXIS * cos(d) + SOUTH_AXIS * sin(d)) * (0.27 if id == 4 else 0.21))
			draw_polyline(rim, color.lightened(0.46), 1.35, true)
		1, 3:
			var streak := top + SOUTH_AXIS * 0.44
			draw_line(streak + EAST_AXIS * 0.18, streak + EAST_AXIS * 0.82, color.darkened(0.33), 1.5, true)
		2:
			var latch := top + EAST_AXIS * 0.58 + SOUTH_AXIS * 0.69
			draw_line(latch - EAST_AXIS * 0.10, latch + EAST_AXIS * 0.08, Color("#f5d3a2"), 2.2, true)


func _draw_straps() -> void:
	var profiles: Array = _state.get("straps", [])
	for index in profiles.size():
		var profile: PackedInt32Array = profiles[index]
		var row: float = float(Model.STRAP_ROWS[index]) + 0.5
		var band := PackedVector2Array([_project(Vector3(0, -0.20, row))])
		for x in profile.size():
			var contact := float(profile[x]) + 0.025
			band.append(_project(Vector3(x, contact, row)))
			band.append(_project(Vector3(x + 1, contact, row)))
		band.append(_project(Vector3(Model.DECK.x, -0.20, row)))
		draw_polyline(band, Color("#382d29"), 8.0, true)
		draw_polyline(band, Color("#cb8b54") if index == 0 else Color("#e0ab6b"), 4.5, true)
		draw_polyline(band, Color("#ffdaa0"), 1.2, true)


func _draw_positioning() -> void:
	var layer: int = _state.get("layer", 0)
	if layer > 0:
		for x in range(Model.DECK.x + 1):
			draw_dashed_line(_project(Vector3(x, layer, 0)), _project(Vector3(x, layer, Model.DECK.z)),
				Color(0.80, 0.94, 0.82, 0.27), 1.1, 6.0, true, true)
		for z in range(Model.DECK.z + 1):
			draw_dashed_line(_project(Vector3(0, layer, z)), _project(Vector3(Model.DECK.x, layer, z)),
				Color(0.80, 0.94, 0.82, 0.27), 1.1, 6.0, true, true)
	var cursor: Vector2i = _state.get("focus", Vector2i.ZERO)
	var focus := _patch(cursor.x, cursor.y, 1.0, 1.0, layer)
	draw_colored_polygon(focus, Color(0.98, 0.78, 0.37, 0.22))
	_border(focus, AMBER, 2.3)
	var valid: bool = _state.get("fit", &"") == &""
	for cell: Vector3i in _state.get("ghost", []):
		var top := _patch(cell.x, cell.z, 1.0, 1.0, cell.y + 1.0)
		var shade := (MINT if valid else CORAL)
		draw_colored_polygon(top, Color(shade, 0.23))
		_border(top, Color(shade, 0.87), 2.0)
		if not valid:
			draw_line(top[0].lerp(top[2], 0.26), top[0].lerp(top[2], 0.74), shade, 1.7, true)
			draw_line(top[1].lerp(top[3], 0.26), top[1].lerp(top[3], 0.74), shade, 1.7, true)


func _draw_readout() -> void:
	Props.lacquer_board(self, READOUT, LACQUER)
	var left := READOUT.position.x + 19.0
	var top := READOUT.position.y
	var count: int = _state.get("placed", 0)
	var tied: bool = _state.get("secured", false)
	_text(Vector2(left, top + 35), "車上  %d / %d" % [count, Model.PIECE_COUNT], TEXT, 24)
	for index in Model.PIECE_COUNT:
		var tile := Rect2(left + index * 59.0, top + 50, 49, 9)
		var loaded: bool = index < _pieces.size() and _pieces[index].anchor != Model.UNPLACED
		if loaded:
			Props.shaded_box(self, tile.grow_individual(0, 0, 0, 4), MATERIALS[index].lightened(0.15), 4.0)
		else:
			draw_rect(tile.grow(1.0), Props.deepen(LACQUER, 0.4))
			draw_rect(tile, Color("#24181a"))
	_text(Vector2(left, top + 101), "雙帶已固定" if tied else "尚未綁帶", MINT if tied else MUTED, 22)
	Props.wood_panel(self, Rect2(left - 4, top + 114, READOUT.size.x - 32.0, 4), Props.deepen(LACQUER, 0.2))
	var guidance_y := top + 157.0
	var reason: StringName = _state.get("feedback", &"ready")
	if not tied:
		var layer: int = _state.get("layer", 0)
		var angle: int = _state.get("angle", 0)
		var fit: StringName = _state.get("fit", &"")
		_text(Vector2(left, top + 149), "第 %d 層 / %d    %d°" % [layer + 1, Model.DECK.y, angle * 90], AMBER, 20)
		guidance_y = top + 192.0
		if not fit.is_empty() and fit != &"locked":
			reason = fit
	var guide: String = FEEDBACK.get(reason, "可在預覽位置放下。")
	var needs_attention := reason in [&"outside", &"collision", &"unsupported", &"exit_blocked", &"strap_gap"]
	_text(Vector2(left, guidance_y), guide, CORAL if needs_attention else TEXT, 16)
	var held_undo := _undo.button_pressed and not _undo.disabled
	Props.key_cap(self, UNDO_RECT, held_undo, true, KEY_TONE if not _undo.disabled else KEY_TONE.lerp(Color("#1c1216"), 0.55))


func _text(at: Vector2, label: String, color: Color, pixels: int) -> void:
	if _label_font != null:
		draw_string(_label_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, READOUT.size.x - 38,
			roundi(pixels * _label_scale), color)


func _patch(x: float, z: float, width: float, depth: float, level: float) -> PackedVector2Array:
	var origin := _project(Vector3(x, level, z))
	return PackedVector2Array([origin, origin + EAST_AXIS * width, origin + EAST_AXIS * width + SOUTH_AXIS * depth, origin + SOUTH_AXIS * depth])


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)


func _border(points: PackedVector2Array, color: Color, width: float) -> void:
	for index in points.size():
		draw_line(points[index], points[(index + 1) % points.size()], color, width, true)
