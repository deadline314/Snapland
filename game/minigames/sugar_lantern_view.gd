extends "res://game/ui/minigame_hold_controls.gd"

signal peg_tapped(index: int)

const Model = preload("res://game/minigames/sugar_lantern_model.gd")
const ART := "res://assets/minigames/sugar-lantern-copper-bench.webp"
const BOARD := Rect2(35, 185, 847, 330)
const PEG_AREA := Rect2(148, 249, 620, 217)
const READOUT := Rect2(900, 185, 345, 330)
const WARM := Color("#ffd199")
const PALE := Color("#fff0db")
const INK := Color("#242023")
const PANEL := Color("#2c2827")
const LINE := Color("#80675a")
const MINT := Color("#b6e5c5")
const CORAL := Color("#ffab93")
## Lacquered bench wood for the boards; copper pins hold the sugar.
const LACQUER := Color("#3f2726")
const COPPER := Color("#b8734a")
const PHASE_TINT := {
	"dawn": Color("#dbc0b6"), "noon": Color("#e4ddd4"),
	"dusk": Color("#e8c9b9"), "night": Color("#d5c0c2"),
}
const TAIL_HINGE := Model.TAIL_HINGE
const TAIL_END := Model.TAIL_TIP
const GHOST := Color(0.97, 0.82, 0.61, 0.35)
const PEG_HIT_RADIUS := 28.0

enum { NORTH, EAST, SOUTH, WEST, JOIN, GAUGE, LIFT, REWARM }
const LABELS := [
	"往上選點 · ↑", "往右選點 · →", "往下選點 · ↓", "往左選點 · ←",
	"接線 · E", "單線 · Q", "按住提起 · 空白", "回熱修接 · F",
]
const KEY_ICONS := ["up", "right", "down", "left", "hook", "swap", "grab", "flame"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
const NAMES := [
	"SugarLanternNorth", "SugarLanternEast", "SugarLanternSouth", "SugarLanternWest",
	"SugarLanternJoin", "SugarLanternGauge", "SugarLanternLift", "SugarLanternRewarm",
]
const HINTS := [
	"選上方最近的支架點。", "選右方最近的支架點。",
	"選下方最近的支架點。", "選左方最近的支架點。",
	"先定起點，再選另一點接線。", "雙線耗糖較多，承重較高。",
	"等糖線凝固，按住提把至穩定。", "放下糖畫後可回熱修接。",
]

var _state: Dictionary = {}
var _art: Texture2D
var _motion_reduced := false
var _phase := "night"
var _last_paint: Array = []
var _last_controls: Array = []
var _font_style := ""
var _locale := ""


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.get("ended", true) or action < NORTH or action > REWARM:
		return false
	if action == LIFT:
		return state.get("rewarm_remaining", 0.0) <= 0.0
	return not state.get("lift_held", false) and not state.get("lifting", false) and state.get("rewarm_remaining", 0.0) <= 0.0


static func hit_peg(point: Vector2, state: Dictionary) -> int:
	if not point.is_finite() or state.is_empty():
		return -1
	var nearest := -1
	var closest := PEG_HIT_RADIUS * PEG_HIT_RADIUS
	var pegs: PackedVector2Array = state.pegs
	for index in pegs.size():
		var distance := _flat_point(pegs[index]).distance_squared_to(point)
		if distance < closest:
			closest = distance
			nearest = index
	return nearest


static func _flat_point(normalized: Vector2) -> Vector2:
	return PEG_AREA.position + normalized * PEG_AREA.size


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#383238"), Color("#674a42"), LINE, WARM)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	use_key_caps(KEY_ICONS, KEY_TONE)
	_art = load(ART) as Texture2D
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == REWARM and _state.get("assisted", false):
		return "放下糖畫，回熱修接並補糖。"
	if slot >= 0 and slot < HINTS.size():
		return HINTS[slot]
	match hit_peg(point, _state):
		-1: return "十字鍵選點　A 接線　X 換粗細　右肩鍵提起　Y 回熱" if BOARD.has_point(point) else ""
		0: return "提把。至少有一條牢靠的連線通往身體。"
		TAIL_HINGE: return "尾巴接點。接到身體再接尾端。"
		TAIL_END: return "尾端。提起後要能擺動。"
		10: return "補強支點。可選其他路線。"
	return "身體支架點。可和附近支點合接。"


func handle_pointer(event: InputEvent, point: Vector2) -> bool:
	if super.handle_pointer(event, point):
		return true
	if pointer_source(event).is_empty() or not event.pressed or event.is_canceled():
		return false
	var index := hit_peg(point, _state)
	if index < 0 or not action_available(JOIN, _state):
		return false
	peg_tapped.emit(index)
	return true


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	_state = state
	_motion_reduced = reduced_motion
	_phase = phase if PHASE_TINT.has(phase) else "night"
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _state.is_empty():
		return
	var typography_changed := _scale != Paper.text_scale() or _font_style != Paper.font_style() or _locale != TranslationServer.get_locale()
	if typography_changed:
		refresh_font()
		_font_style = Paper.font_style()
		_locale = TranslationServer.get_locale()
	var mask: int = _state.control_mask
	var controls := [_state.ended, _state.anchor, _state.doubled, _state.lifting, _state.lift_held, _state.rewarm_remaining > 0.0, mask]
	if controls != _last_controls:
		_last_controls = controls
		_refresh_controls(mask)
	var edges := PackedFloat32Array()
	for edge in _state.edges:
		edges.append(edge.a)
		edges.append(edge.b)
		edges.append(edge.thickness)
		edges.append(snappedf(edge.cure, 0.035))
		edges.append(snappedf(edge.stress, 0.035))
		edges.append(float(edge.cracked))
	var paint := [
		_state.layout, _state.focus, _state.anchor, _state.doubled, _state.wet, _state.joined,
		_state.lifting, _state.success, _state.ended, _state.failed_edge, _state.tail_ready, _state.tail_proven,
		snappedf(_state.sugar, 0.05), snappedf(_state.heat, 0.02), snappedf(_state.lift_height, 0.01),
		snappedf(_state.lift_hold, 0.02), snappedf(_state.tail_swing, 0.03),
		snappedf(_state.rewarm_remaining, 0.04), (0.0 if _motion_reduced else snappedf(_state.tail_angle, 0.018)), _state.feedback,
		_motion_reduced, _phase, edges,
	]
	if paint != _last_paint or typography_changed:
		_last_paint = paint
		queue_redraw()


func _refresh_controls(mask: int) -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		button.disabled = not action_available(index, _state)
		button.set_pressed_no_signal(bool(mask & (1 << index)) and not button.disabled)
	_buttons[JOIN].text = "選起點 · E" if _state.anchor < 0 else "接線／解除 · E"
	_buttons[GAUGE].text = "雙線 · Q" if _state.doubled else "單線 · Q"
	_buttons[LIFT].text = "保持提起 · 空白" if _state.lift_held else LABELS[LIFT]


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(35, 172), _guide(), WARM, 22, BOARD.size.x)
	_draw_bench()
	_draw_void()
	_draw_work()
	_draw_readout()


func _draw_bench() -> void:
	Props.wood_panel(self, BOARD.grow(8.0), LACQUER)
	draw_rect(BOARD, INK)
	if _art:
		var image_size := _art.get_size()
		var aspect := BOARD.size.aspect()
		var crop := Vector2(minf(image_size.x, image_size.y * aspect), minf(image_size.y, image_size.x / aspect))
		draw_texture_rect_region(_art, BOARD, Rect2((image_size - crop) * 0.5, crop), PHASE_TINT[_phase])
	draw_rect(BOARD, Color(0.06, 0.043, 0.048, 0.24))


func _draw_void() -> void:
	var center := _flat_point(_state.void_center)
	var radius: Vector2 = _state.void_radii * PEG_AREA.size
	for index in 12:
		var from := TAU * index / 12.0
		var to := from + TAU / 23.0
		draw_line(center + Vector2.from_angle(from) * radius, center + Vector2.from_angle(to) * radius, GHOST, 1.2, true)


func _draw_work() -> void:
	var points: PackedVector2Array = _state.pegs
	var placed := PackedVector2Array()
	for index in points.size():
		placed.append(_display_peg(index, points))
	var depth := Vector2(2.5, 3.0 + _lift_rise() * 0.20)
	for strand in _state.edges:
		var a: Vector2 = placed[strand.a]
		var b: Vector2 = placed[strand.b]
		draw_line(a + depth, b + depth, Color(0.12, 0.07, 0.055, 0.55), 5.4 * float(strand.thickness), true)
	for strand in _state.edges:
		_draw_strand(placed[strand.a], placed[strand.b], strand)
	var anchor: int = _state.anchor
	var focus: int = _state.focus
	if action_available(JOIN, _state) and anchor >= 0 and anchor != focus:
		draw_dashed_line(placed[anchor], placed[focus], Color(WARM, 0.73), 2.0, 6.0, true, true)
	for index in placed.size():
		_draw_peg(placed[index], index, index == focus, index == anchor)


func _display_peg(index: int, points: PackedVector2Array) -> Vector2:
	var point := points[index]
	# Rotate in model coordinates, then apply the board's projection.
	if not _motion_reduced and index in [TAIL_HINGE, TAIL_END] and _state.tail_anchor >= 0:
		var hinge: Vector2 = points[_state.tail_anchor]
		point = hinge + (point - hinge).rotated(_state.tail_angle)
	return _flat_point(point) + Vector2(0, -_lift_rise())


func _lift_rise() -> float:
	var rise := clampf(float(_state.lift_height), 0.0, 1.0)
	if _motion_reduced:
		return 28.0 if rise >= 0.95 else 0.0
	return 28.0 * rise


func _draw_strand(a: Vector2, b: Vector2, strand: Dictionary) -> void:
	var width := clampf(float(strand.thickness) * 4.3, 3.0, 10.0)
	var tone := Color("#c47949").lerp(Color("#ffd291"), clampf(float(strand.cure), 0.0, 1.0))
	if float(strand.stress) > 0.62:
		tone = tone.lerp(CORAL, smoothstep(0.62, 1.0, strand.stress))
	if strand.cracked:
		draw_line(a, a.lerp(b, 0.42), CORAL, width, true)
		draw_line(a.lerp(b, 0.58), b, CORAL, width, true)
		var mark := a.lerp(b, 0.5)
		draw_line(mark + Vector2(-4, -6), mark + Vector2(4, 6), PALE, 2.0, true)
		return
	draw_line(a, b, tone.darkened(0.29), width + 1.9, true)
	draw_line(a, b, tone, width, true)
	var gloss := a.direction_to(b).orthogonal() * width * 0.16
	var glint_start := a.lerp(b, 0.14) + gloss
	var glint_end := a.lerp(b, 0.80) + gloss
	if float(strand.cure) < Model.CURE_READY:
		draw_dashed_line(glint_start, glint_end, Color(PALE, 0.43), 1.2, 5.0, true, true)
	else:
		draw_line(glint_start, glint_end, Color(PALE, 0.56), maxf(1.0, width * 0.21), true)


func _draw_peg(point: Vector2, index: int, focused: bool, anchored: bool) -> void:
	var tint := MINT if index in [TAIL_HINGE, TAIL_END] else WARM
	# Copper pins set in the bench, each with its cast shadow.
	Props.contact_shadow(self, point + Vector2(3, 5), 18.0, 0.55)
	if index == 0:
		Props.shaded_box(self, Rect2(point - Vector2(8, 8), Vector2(16, 18)), COPPER, 4.0)
		draw_rect(Rect2(point - Vector2(7, 7), Vector2(14, 14)), tint, false, 2.0)
	elif index == 10:
		Props.token(self, point, 5.0, COPPER.darkened(0.2))
		draw_circle(point, 6.7, tint, false, 1.3, true)
	else:
		Props.token(self, point, 7.0, COPPER)
		draw_circle(point, 7.0, tint, false, 1.6, true)
	if anchored:
		draw_circle(point, 13.2, MINT, false, 2.0, true)
	if focused:
		var mark := PackedVector2Array([
			point + Vector2.UP * 16.0, point + Vector2.RIGHT * 16.0,
			point + Vector2.DOWN * 16.0, point + Vector2.LEFT * 16.0,
			point + Vector2.UP * 16.0,
		])
		draw_polyline(mark, PALE, 2.1, true)


func _draw_readout() -> void:
	Props.lacquer_board(self, READOUT, LACQUER)
	_text(Vector2(920, 223), _state.name, PALE, 25, 305)
	Props.wood_panel(self, Rect2(917, 232, 309, 4), Props.deepen(LACQUER, 0.2))
	_draw_meter(265.0, "剩糖 %d" % _state.sugar, _ratio(_state.sugar, _state.sugar_max), WARM)
	var heat := "糖漿可牽線" if _state.heat >= Model.POUR_HEAT else "糖漿偏涼 · 先回熱"
	if _state.rewarm_remaining > 0.0:
		heat = "糖漿回熱中"
	_draw_meter(326.0, heat, _state.heat, CORAL)
	var hold_ratio := _ratio(_state.lift_hold, Model.HOLD_SECONDS - Model.RISE_SECONDS)
	_draw_meter(387.0, "持續提燈", hold_ratio, MINT)
	var cooling := "未凝固的糖線 %d 條" % _state.wet if _state.wet > 0 else "糖線已凝固"
	if _state.edges.is_empty():
		cooling = "先選支點接線"
	elif _state.failed_edge >= 0:
		cooling = "裂線可回熱補接"
	_text(Vector2(920, 453), cooling, CORAL if _state.failed_edge >= 0 else PALE, 18, 306)
	var tail := "可用餘糖接尾巴"
	if _state.tail_proven:
		tail = "活動尾巴已通過"
	elif _state.tail_ready and (_state.lifting or _state.success):
		tail = "尾巴擺幅 %d°" % roundi(rad_to_deg(_state.tail_swing))
	elif _state.tail_ready:
		tail = "已接尾巴，提起後可擺動"
	_text(Vector2(920, 492), tail, MINT, 17, 306)


func _draw_meter(row: float, value: String, portion: float, tint: Color) -> void:
	_text(Vector2(920, row), value, tint, 18, 306.0)
	var channel := Rect2(920, row + 15.0, 304, 10.0)
	draw_rect(channel.grow(2.0), Props.deepen(LACQUER, 0.4))
	draw_rect(channel, Color("#1d1218"))
	draw_rect(Rect2(channel.position.x, channel.end.y, channel.size.x, 2), Props.lighten(LACQUER, 0.25))
	draw_rect(Rect2(channel.position, Vector2(channel.size.x * portion, channel.size.y)), tint)
	draw_rect(Rect2(channel.position, Vector2(channel.size.x * portion, 2)), Props.lighten(tint, 0.4))


func _guide() -> String:
	if _state.ended:
		return _state.feedback
	if _state.lifting:
		return "保持提起，讓重量穩定"
	if _state.anchor >= 0 and _state.anchor != _state.focus and _state.feedback.is_empty():
		return "再選一個支點，接上糖線"
	if _state.feedback.is_empty():
		return "選支點接線，凝固後再提起"
	return _state.feedback


func _ratio(value: float, maximum: float) -> float:
	return clampf(value / maxf(0.001, maximum), 0.0, 1.0)


func _text(point: Vector2, value: String, color: Color, pixels: float, width: float) -> void:
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(pixels * _scale), color)
