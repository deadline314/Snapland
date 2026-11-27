extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/pancake_fold_model.gd")
const SurfaceShader = preload("res://game/minigames/pancake_fold_surface.gdshader")
const COUNTER := "res://assets/minigames/pancake-fold-counter.webp"
const PAN := "res://assets/minigames/pancake-fold-pan.webp"
const BOARD := Rect2(35, 187, 846, 328)
const READOUT := Rect2(899, 187, 346, 328)
const CENTRE := Vector2(459, 352)
const CELL := 9.35
const FIELD_WIDTH := Model.PAN_SIZE * CELL
const FIELD := Rect2(CENTRE - Vector2.ONE * FIELD_WIDTH * 0.5, Vector2.ONE * FIELD_WIDTH)
const PAN_RECT := Rect2(CENTRE - Vector2.ONE * 159.0, Vector2.ONE * 318.0)
const INK := Color("#fff0dc")
const MUTED := Color("#bbc8c9")
const DEEP := Color("#1d2730")
const FRAME := Color("#72594e")
## Lacquered counter wood for the boards.
const LACQUER := Color("#3f2726")
const GOLD := Color("#fbd298")
const MINT := Color("#a8dec3")
const CORAL := Color("#f5a991")
const FLOUR := Color("#fff5d8")
const REASONS := {
	"empty": "先倒糊，再傾鍋鋪開", "thin": "補上折線和配料範圍的薄孔",
	"wet": "等麵糊凝固，再折合", "burned": "餅皮已焦化",
	"folding": "正在包合", "ended": "回合結束", "": "餅皮就緒，可以折合",
}

enum { NORTH, EAST, SOUTH, WEST, POUR, TOOL, SALVAGE, FOLD }
const LABELS := ["向北傾 · W", "向東傾 · D", "向南傾 · S", "向西傾 · A", "倒一勺 · 空白", "改用移勺 · Q", "舀鍋邊 · R", "折合 · E"]
const KEY_ICONS := ["up", "right", "down", "left", "ladle", "swap", "grab", "confirm"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
const NAMES := ["PancakeNorth", "PancakeEast", "PancakeSouth", "PancakeWest", "PancakePour", "PancakeTool", "PancakeSalvage", "PancakeFold"]
const DIRECTIONS := ["北", "東", "南", "西"]
const DEFAULT_HINTS := [
	"按住往北傾鍋", "按住往東傾鍋", "按住往南傾鍋", "按住往西傾鍋",
	"在勺點倒一份新糊", "切換傾鍋與移動勺點", "把勺點移到有餘糊的鍋邊再舀",
	"餅皮凝固後沿虛線包住配料",
]

var _state: Dictionary = {}
var _backdrop: Texture2D
var _pan: Texture2D
var _sheet: TextureRect
var _field_image: Image
var _field_tex: ImageTexture
var _fold_mask: ImageTexture
var _fold_mask_ready := false
var _fold_buffer_valid := false
var _heat_material: ShaderMaterial
var _markers: Node2D
var _pixels := PackedByteArray()
var _filling_edges := PackedVector2Array()
var _ear_edges := PackedVector2Array()
var _thin_lines := PackedVector2Array()
var _rim_points := PackedVector2Array()
var _last_layout := -1
var _last_revision := -1
var _last_amount := -1.0
var _last_axis := Vector2.INF
var _last_tilt := Vector2.INF
var _last_reduced := false
var _last_paint: Array = []
var _feedback_lines: Array[String] = []
var _feedback_value := ""
var _reduced_motion := false
var _phase := "night"


static func action_available(action: int, state: Dictionary) -> bool:
	return (
		action >= NORTH and action <= FOLD and not state.is_empty()
		and not state.get("ended", false) and state.get("fold_reason", "") != "folding"
	)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#3d393f"), Color("#705543"), FRAME, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	use_key_caps(KEY_ICONS, KEY_TONE)
	_backdrop = load(COUNTER) as Texture2D if ResourceLoader.exists(COUNTER) else null
	_pan = load(PAN) as Texture2D if ResourceLoader.exists(PAN) else null
	_pixels.resize(Model.PAN_SIZE * Model.PAN_SIZE * 4)
	_field_image = Image.create_from_data(Model.PAN_SIZE, Model.PAN_SIZE, false, Image.FORMAT_RGBA8, _pixels)
	_field_tex = ImageTexture.create_from_image(_field_image)
	_heat_material = ShaderMaterial.new()
	_heat_material.shader = SurfaceShader
	_heat_material.set_shader_parameter("pan_radius", Model.PAN_RADIUS * 2.0 / Model.PAN_SIZE)
	_fold_mask = ImageTexture.create_from_image(Image.create_empty(Model.PAN_SIZE, Model.PAN_SIZE, false, Image.FORMAT_R8))
	_heat_material.set_shader_parameter("fold_source", _fold_mask)
	_sheet = TextureRect.new()
	_sheet.name = "LiveBatterField"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.position = FIELD.position
	_sheet.size = FIELD.size
	_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet.texture = _field_tex
	_sheet.material = _heat_material
	add_child(_sheet)
	_markers = Node2D.new()
	_markers.name = "PanReadings"
	_markers.draw.connect(_draw_markers)
	add_child(_markers)
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot < 0:
		return ""
	if slot <= WEST and _state.get("tool", Model.TILT) == Model.LADLE:
		return "按住往%s移動勺點" % DIRECTIONS[slot]
	if slot == SALVAGE and _state.get("cup", 0.0) > 0.0:
		return "把舀起的餘糊放在目前勺點"
	return DEFAULT_HINTS[slot]


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	_state = state
	_reduced_motion = reduced_motion
	_phase = phase
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _state.is_empty():
		return
	var old_scale := _scale
	var old_font := _font
	refresh_font()
	var changed_layout: bool = _last_layout != _state.layout
	if changed_layout:
		_last_layout = _state.layout
		_filling_edges = _outline(_state.filling_mask)
		_ear_edges = _outline(_state.ear_mask)
		_last_revision = -1
	var folding: bool = _state.fold_reason == "folding"
	if not folding:
		_fold_buffer_valid = false
	elif not _state.folded:
		_fold_buffer_valid = true
	elif _reduced_motion:
		_fold_buffer_valid = false
	var animating: bool = folding and not _reduced_motion and _fold_buffer_valid
	# Keep the exact open field during the visible half-turn. A last-tick pour
	# or deposit belongs to that open field, even if the fold started at once.
	if _last_revision != _state.revision and (not animating or not _state.folded):
		_upload_field()
	if animating and not _fold_mask_ready:
		_upload_fold_source()
	elif not animating:
		_fold_mask_ready = false
	var amount: float = _state.fold_progress if animating and _fold_mask_ready else 0.0
	_update_material(amount)
	var hold := int(_state.get("direction_mask", 0))
	var paint := [
		_phase, _last_layout, _last_revision, _state.assisted, _state.cursor.snappedf(0.04),
		_state.tilt.snappedf(0.02), _state.tool, _state.can_fold, _state.can_salvage, _state.fold_reason,
		floori(_state.stock), floori(_state.cup * 10.0), floori(_state.rim_available * 10.0),
		_state.ear_proven, _state.ear_attached, _state.ended, _state.feedback, hold,
	]
	if paint == _last_paint and old_scale == _scale and old_font == _font:
		return
	_last_paint = paint
	if _feedback_value != _state.feedback or old_scale != _scale or old_font != _font:
		_feedback_value = _state.feedback
		_feedback_lines = _fit_feedback(_feedback_value)
	_update_buttons(hold)
	queue_redraw()
	_markers.queue_redraw()


func _upload_fold_source() -> void:
	var mask: PackedByteArray = _state.get("fold_source_mask", PackedByteArray())
	if mask.size() != Model.PAN_SIZE * Model.PAN_SIZE:
		return
	var pixels := mask.duplicate()
	for index in pixels.size():
		pixels[index] = 255 if mask[index] != 0 else 0
	_fold_mask.update(Image.create_from_data(Model.PAN_SIZE, Model.PAN_SIZE, false, Image.FORMAT_R8, pixels))
	_fold_mask_ready = true


func _update_material(amount: float) -> void:
	var tilt: Vector2 = _state.tilt.snappedf(0.01)
	var fold_axis: Vector2 = _state.fold_axis
	if tilt != _last_tilt:
		_heat_material.set_shader_parameter("tilt", tilt)
		_last_tilt = tilt
	if fold_axis != _last_axis:
		_heat_material.set_shader_parameter("fold_axis", fold_axis)
		_last_axis = fold_axis
	if amount != _last_amount:
		_heat_material.set_shader_parameter("fold_amount", amount)
		_last_amount = amount
	if _reduced_motion != _last_reduced:
		_heat_material.set_shader_parameter("reduced_motion", _reduced_motion)
		_last_reduced = _reduced_motion


func _upload_field() -> void:
	var mass: PackedFloat32Array = _state.mass
	var cooking: PackedFloat32Array = _state.cook
	var heat: PackedFloat32Array = _state.heat
	var recovered: PackedFloat32Array = _state.recovered
	var rim: PackedFloat32Array = _state.rim
	var thin: PackedByteArray = _state.thin_mask
	_thin_lines.clear()
	_rim_points.clear()
	for index in mass.size():
		var offset := index * 4
		_pixels[offset] = _channel(mass[index] / 1.80)
		_pixels[offset + 1] = _channel(cooking[index] / 3.50)
		_pixels[offset + 2] = _channel(recovered[index] / maxf(mass[index], 0.01))
		_pixels[offset + 3] = _channel((heat[index] - 0.38) / 1.12)
		if _state.assisted and thin[index] != 0:
			var center := _cell_center(index)
			_thin_lines.append(center + Vector2(-2.3, 2.0))
			_thin_lines.append(center + Vector2(2.3, -2.0))
		if rim[index] > 0.11:
			_rim_points.append(_cell_center(index))
	_field_image.set_data(Model.PAN_SIZE, Model.PAN_SIZE, false, Image.FORMAT_RGBA8, _pixels)
	_field_tex.update(_field_image)
	_last_revision = _state.revision


func _channel(normalized: float) -> int:
	return roundi(clampf(normalized, 0.0, 1.0) * 255.0)


func _update_buttons(held: int) -> void:
	var moving_ladle: bool = _state.tool == Model.LADLE
	for index in _buttons.size():
		var disabled := not action_available(index, _state)
		if _buttons[index].disabled != disabled:
			_buttons[index].disabled = disabled
		var active: bool = not disabled and index <= WEST and (held & (1 << index)) != 0
		if not disabled:
			active = active or (index == FOLD and _state.can_fold) or (index == SALVAGE and _state.can_salvage)
		if _buttons[index].button_pressed != active:
			_buttons[index].set_pressed_no_signal(active)
		if index <= WEST:
			_set_button(index, "移勺向%s · %s" % [DIRECTIONS[index], "WDSA"[index]] if moving_ladle else LABELS[index])
	_set_button(TOOL, "改用傾鍋 · Q" if moving_ladle else LABELS[TOOL])
	_set_button(SALVAGE, "放餘糊 · R" if _state.cup > 0.0 else LABELS[SALVAGE])


func _set_button(index: int, value: String) -> void:
	if _buttons[index].text != value:
		_buttons[index].text = value


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	Props.wood_panel(self, BOARD.grow(8.0), LACQUER)
	draw_rect(BOARD, DEEP)
	if _backdrop != null:
		var original := _backdrop.get_size()
		var crop_h := original.x * BOARD.size.y / BOARD.size.x
		draw_texture_rect_region(_backdrop, BOARD, Rect2(0, (original.y - crop_h) * 0.43, original.x, crop_h))
		draw_rect(BOARD, Color(0.06, 0.06, 0.08, 0.15 if _phase == "noon" else 0.27))
	draw_set_transform(CENTRE + Vector2(0, 8), 0.0, Vector2(1.08, 0.76))
	draw_circle(Vector2.ZERO, 121.0, Color(0.04, 0.04, 0.058, 0.72), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if _pan != null:
		draw_texture_rect(_pan, PAN_RECT, false)
	else:
		draw_circle(CENTRE, 124.0, Color("#29323a"), true, -1.0, true)
		draw_circle(CENTRE, 124.0, FRAME, false, 6.0, true)
	_text(Vector2(35, 171), REASONS.get(_state.fold_reason, ""), GOLD, 22, BOARD.size.x)
	_draw_readout()


func _draw_readout() -> void:
	Props.lacquer_board(self, READOUT, LACQUER)
	_text(Vector2(917, 226), "熱鍋與麵糊", INK, 22, 305)
	_text(Vector2(917, 257), "新糊 %d 勺" % floori(_state.stock / Model.POUR_MASS), MUTED, 17, 305)
	_text(Vector2(1068, 257), "勺中餘糊" if _state.cup > 0.0 else "空勺", GOLD if _state.cup > 0.0 else MUTED, 17, 154)
	Props.wood_panel(self, Rect2(915, 270, 313, 4), Props.deepen(LACQUER, 0.2))
	_meter(Vector2(917, 299), "填料覆蓋", float(_state.filled), MINT)
	_meter(Vector2(917, 335), "折線完整", float(_state.seam), GOLD)
	_meter(Vector2(917, 371), "餅皮凝固", float(_state.cooked), CORAL)
	Props.wood_panel(self, Rect2(915, 383, 313, 4), Props.deepen(LACQUER, 0.2))
	var status := "餘糊已接成折耳" if _state.ear_proven else "可舀鍋邊餘糊" if _state.rim_available > 0.1 else "餘糊會沿傾向流往鍋邊"
	_text(Vector2(917, 414), status, MINT if _state.ear_proven else MUTED, 17, 310)
	for index in _feedback_lines.size():
		_text(Vector2(917, 442 + float(index) * 22), _feedback_lines[index], INK, 16, 310)
	if _state.assisted:
		_text(Vector2(917, 496), "斜紋標出薄區", MINT, 16, 310)


func _fit_feedback(value: String) -> Array[String]:
	var size := roundi(16.0 * _scale)
	var lines: Array[String] = []
	var line := ""
	for character in value:
		if not line.is_empty() and lines.is_empty() and _font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 306.0:
			lines.append(line)
			line = ""
		line += character
	if not line.is_empty():
		lines.append(line)
	return lines


func _meter(at: Vector2, label: String, ratio: float, color: Color) -> void:
	_text(at, label, MUTED, 17, 130.0)
	var track := Rect2(at + Vector2(130, -12), Vector2(123, 10))
	draw_rect(track.grow(2.0), Props.deepen(LACQUER, 0.4))
	draw_rect(track, Color("#1d1218"))
	draw_rect(Rect2(track.position.x, track.end.y, track.size.x, 2), Props.lighten(LACQUER, 0.25))
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(ratio, 0.0, 1.0), track.size.y)), color)
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(ratio, 0.0, 1.0), 2)), Props.lighten(color, 0.4))
	_text(at + Vector2(261, 0), "%d%%" % roundi(100.0 * ratio), INK, 15, 56.0)


func _draw_markers() -> void:
	if _state.is_empty() or _state.folded or _state.fold_reason == "folding":
		return
	_markers.draw_multiline(_filling_edges, Color(FLOUR, 0.75), 1.35, true)
	if _state.cup > 0.0 or _state.rim_available > 0.0:
		_markers.draw_multiline(_ear_edges, Color(MINT, 0.64), 1.5, true)
	var crease: Vector2 = _state.fold_axis.orthogonal()
	for segment in range(-8, 9, 2):
		var length := float(segment) * CELL
		_markers.draw_line(CENTRE + crease * length, CENTRE + crease * (length + CELL * 0.82),
			Color(FLOUR, 0.61), 1.5, true)
	if not _thin_lines.is_empty():
		_markers.draw_multiline(_thin_lines, Color("#e7bbc4"), 1.15, true)
	for point in _rim_points:
		_markers.draw_circle(point, 2.3, Color(GOLD, 0.82), true, -1.0, true)
	var cursor: Vector2 = CENTRE + _state.cursor * CELL
	_markers.draw_circle(cursor, 6.5, Color(DEEP, 0.92), false, 3.0, true)
	_markers.draw_circle(cursor, 5.4, GOLD, false, 1.5, true)
	var tilt: Vector2 = _state.tilt
	if tilt.length_squared() > 0.01:
		var heading := tilt.normalized()
		var edge := CENTRE + heading * (FIELD_WIDTH * 0.49)
		var tail := edge - heading * (10.0 + 12.0 * tilt.length())
		_markers.draw_line(tail, edge, GOLD, 2.6, true)
		for side: float in [-1.0, 1.0]:
			_markers.draw_line(edge, edge - heading * 6.0 + heading.orthogonal() * side * 4.1, GOLD, 1.8, true)


func _outline(mask: PackedByteArray) -> PackedVector2Array:
	var points := PackedVector2Array()
	var size := Model.PAN_SIZE
	var half := CELL * 0.5
	for index in mask.size():
		if not mask[index]:
			continue
		var x := index % size
		var y := floori(float(index) / size)
		var center := _cell_center(index)
		if x == 0 or mask[index - 1] == 0:
			points.append(center + Vector2(-half, -half))
			points.append(center + Vector2(-half, half))
		if x == size - 1 or mask[index + 1] == 0:
			points.append(center + Vector2(half, -half))
			points.append(center + Vector2(half, half))
		if y == 0 or mask[index - size] == 0:
			points.append(center + Vector2(-half, -half))
			points.append(center + Vector2(half, -half))
		if y == size - 1 or mask[index + size] == 0:
			points.append(center + Vector2(-half, half))
			points.append(center + Vector2(half, half))
	return points


func _cell_center(index: int) -> Vector2:
	return FIELD.position + (Vector2(index % Model.PAN_SIZE, floori(float(index) / Model.PAN_SIZE)) + Vector2.ONE * 0.5) * CELL


func _text(at: Vector2, value: String, color: Color, nominal: int, width: float) -> void:
	var size := roundi(nominal * _scale)
	var measured := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if measured > width:
		size = maxi(13, floori(size * width / measured))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)
