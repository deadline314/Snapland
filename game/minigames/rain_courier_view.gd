extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/rain_courier_model.gd")
const ART := "res://assets/minigames/rain-courier-alley.webp"
const BOARD := Rect2(35, 188, 872, 327)
const FIELD := Rect2(72, 215, 775, 282)
const READOUT := Rect2(925, 188, 319, 327)
const INK := Color("#fff0de")
const PANEL := Color("#182439")
const DEEP := Color("#101927")
const MUTED := Color("#8fa5b4")
const EDGE := Color("#567282")
const MINT := Color("#9ce4ce")
const CORAL := Color("#ffad98")
const GOLD := Color("#ffd385")
const RAIN := Color("#9cc6ee")
const RAIL_SPAN := 94.0
enum { SHORT, COVERED, WALK, UMBRELLA, ACTION, RETRY }
const LABELS := ["近路 · A", "雨棚繞路 · D", "按住前進 · W", "撐傘 · Space", "取餐 · E", "重取 · R"]
const NAMES := ["RainCourierShort", "RainCourierCovered", "RainCourierWalk", "RainCourierUmbrella", "RainCourierAction", "RainCourierRetry"]
const HINTS := [
	"路程較短，露天段較長", "棚下保溫，兩段缺口會淋雨", "按住沿選定路線前進",
	"切換雨傘。撐傘防雨，走得較慢", "先取餐，到站等指針進入亮帶再滑遞", "重取這份餐盒，扣 20 分",
]
const STAGE_HINTS := {
	Model.READY: ["先選路再取餐。", "走棚下可保持餐盒乾爽。"],
	Model.CARRY: ["遇雨縫先撐傘；進棚可收傘。", "太濕或太冷可重取這份。"],
	Model.HANDOFF: ["看亮帶，進帶後滑遞。", "小惡魔：撐傘護餐盒過積水。"],
	Model.SLIDING: ["滑遞中仍可切換傘。", ""],
}
var _state: Dictionary = {}
var _texture: Texture2D
var _reduced := false
var _paths: Array[Dictionary] = []
var _route_stamp := Vector2i(-1, -1)
var _last_font_style := ""
var _last_locale := ""

static func action_available(action: int, stage: String) -> bool:
	match action:
		SHORT, COVERED: return stage == Model.READY
		WALK: return stage == Model.CARRY
		UMBRELLA: return stage in [Model.READY, Model.CARRY, Model.HANDOFF, Model.SLIDING]
		ACTION: return stage == Model.READY or stage == Model.HANDOFF
		RETRY: return stage == Model.CARRY or stage == Model.HANDOFF
	return false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	build_controls(LABELS, Color("#223a4b"), Color("#345c66"), EDGE, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	if ResourceLoader.exists(ART):
		_texture = load(ART) as Texture2D
	_refresh()

func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == ACTION and _state.get("stage") == Model.HANDOFF:
		return "進入亮帶再滑遞。撐傘可護住積水段"
	return HINTS[slot] if slot >= 0 and slot < HINTS.size() else ""

func present(state: Dictionary, reduced_motion: bool = false) -> void:
	if is_same(_state, state) and _reduced == reduced_motion and _typography_current():
		return
	_state = state
	_reduced = reduced_motion
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if _state.is_empty():
		return
	if not _typography_current():
		refresh_font()
		_last_locale = TranslationServer.get_locale()
		_last_font_style = Paper.font_style()
	var stamp := Vector2i(_state.layout, _state.recipient_index)
	if stamp != _route_stamp:
		_route_stamp = stamp
		_paths.clear()
		for route in 2:
			_paths.append(_route_geometry(_state.route_paths[route], _state.open_segments[route]))
	for index in _buttons.size():
		var disabled := not action_available(index, _state.stage)
		if _buttons[index].disabled != disabled:
			_buttons[index].disabled = disabled
	_buttons[SHORT].set_pressed_no_signal(_state.route == Model.SHORT)
	_buttons[COVERED].set_pressed_no_signal(_state.route == Model.COVERED)
	_buttons[WALK].set_pressed_no_signal(_state.walking)
	_buttons[UMBRELLA].set_pressed_no_signal(_state.umbrella_manual)
	_buttons[ACTION].set_pressed_no_signal(_state.slide_ready)
	var action_text := "取餐 · E" if _state.stage == Model.READY else "滑遞 · E"
	if _buttons[ACTION].text != action_text:
		_buttons[ACTION].text = action_text
	queue_redraw()

func _typography_current() -> bool:
	return _scale == Paper.text_scale() and _last_locale == TranslationServer.get_locale() and _last_font_style == Paper.font_style()

func _route_geometry(path: PackedVector2Array, gaps: PackedVector2Array) -> Dictionary:
	var lengths := PackedFloat32Array([0.0])
	for index in range(1, path.size()):
		lengths.append(lengths[-1] + path[index - 1].distance_to(path[index]))
	var total := float(lengths[-1])
	var covered := PackedVector2Array()
	var exposed := PackedVector2Array()
	var projected := PackedVector2Array()
	for point: Vector2 in path:
		projected.append(_route_point(point))
	for index in range(1, path.size()):
		var start := float(lengths[index - 1]) / total
		var finish := float(lengths[index]) / total
		var from := projected[index - 1]
		var to := projected[index]
		var cursor := from
		for gap: Vector2 in gaps:
			var lower := maxf(start, gap.x)
			var upper := minf(finish, gap.y)
			if lower >= upper:
				continue
			var gap_start := from.lerp(to, inverse_lerp(start, finish, lower))
			var gap_end := from.lerp(to, inverse_lerp(start, finish, upper))
			if cursor.distance_squared_to(gap_start) > 0.01:
				covered.append(cursor)
				covered.append(gap_start)
			exposed.append(gap_start)
			exposed.append(gap_end)
			cursor = gap_end
		if cursor.distance_squared_to(to) > 0.01:
			covered.append(cursor)
			covered.append(to)
	return {"path": projected, "covered": covered, "exposed": exposed}

func _route_point(normalized: Vector2) -> Vector2:
	return FIELD.position + normalized * FIELD.size

func _draw() -> void:
	if _state.is_empty() or _font == null or _paths.size() != 2:
		return
	_text(Vector2(35, 168), str(_state.message), GOLD, 21, BOARD.size.x)
	_draw_alley()
	_draw_panel()
	_draw_action_hint()

func _draw_alley() -> void:
	draw_rect(BOARD.grow(2), EDGE)
	draw_rect(BOARD, PANEL)
	if is_instance_valid(_texture):
		var art_size := _texture.get_size()
		var height := art_size.x * BOARD.size.y / BOARD.size.x
		var crop := Rect2(0, maxf(0.0, (art_size.y - height) * 0.32), art_size.x, height)
		draw_texture_rect_region(_texture, BOARD, crop)
		draw_rect(BOARD, Color("#102138", 0.28))
	if not _reduced:
		_draw_rain()
	_draw_routes()
	_draw_place_markers()
	_draw_courier()
	if _state.stage == Model.HANDOFF or _state.stage == Model.SLIDING:
		_draw_slide()

func _draw_rain() -> void:
	var flow := float(_state.rain_direction)
	var duration: float = _state.elapsed
	for index in 23:
		var column := float(index * 83 % 863)
		var fraction := fposmod(float(index * 29 % 97) / 97.0 + duration * 0.8, 1.0)
		var y := BOARD.position.y + 16.0 + fraction * (BOARD.size.y - 38.0)
		var x := BOARD.position.x + 12.0 + fposmod(column + fraction * flow * 42.0, BOARD.size.x - 23.0)
		var start := Vector2(roundf(x), roundf(y))
		draw_line(start, start + Vector2(5 * flow, 13), Color(RAIN, 0.19), 2.0)

func _draw_routes() -> void:
	var selected: int = _state.route
	_draw_route(_paths[1 - selected], false)
	_draw_route(_paths[selected], true)
	var y := BOARD.end.y - 23.0
	var at := Vector2(BOARD.position.x + 14.0, y)
	draw_rect(Rect2(at - Vector2(0, 18), Vector2(230, 35)), Color(DEEP, 0.92))
	draw_line(at + Vector2(12, 0), at + Vector2(36, 0), MINT, 4.0)
	_text(at + Vector2(43, 6), "棚下", INK, 15)
	draw_dashed_line(at + Vector2(110, 0), at + Vector2(136, 0), CORAL, 4.0, 5.0)
	_text(at + Vector2(143, 6), "露天", INK, 15)

func _draw_route(geometry: Dictionary, selected: bool) -> void:
	var path: PackedVector2Array = geometry.path
	draw_polyline(path, Color(DEEP, 0.92 if selected else 0.63), 12.0 if selected else 8.0, true)
	var sheltered: PackedVector2Array = geometry.covered
	var exposed: PackedVector2Array = geometry.exposed
	if not sheltered.is_empty():
		draw_multiline(sheltered, Color(MINT, 0.96 if selected else 0.59), 5.0 if selected else 3.0, true)
	for index in range(0, exposed.size(), 2):
		draw_dashed_line(exposed[index], exposed[index + 1], Color(CORAL, 1.0 if selected else 0.62),
			5.0 if selected else 3.0, 10.0)

func _draw_place_markers() -> void:
	var path: PackedVector2Array = _paths[_state.route].path
	var start := path[0]
	_draw_bay(start, "取餐口", MINT)
	_draw_bay(path[-1] + Vector2(RAIL_SPAN, 0), str(_state.recipient), GOLD)

func _draw_bay(at: Vector2, label: String, tint: Color) -> void:
	draw_rect(Rect2(at - Vector2(8, 8), Vector2(16, 16)), DEEP)
	draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), tint)
	var plaque := Rect2(at.x - 49, at.y + 13, 98, 33)
	draw_rect(plaque, Color(DEEP, 0.95))
	draw_rect(plaque, EDGE, false, 1.5)
	draw_string(_font, plaque.position + Vector2(0, 22), label, HORIZONTAL_ALIGNMENT_CENTER, plaque.size.x, roundi(16.0 * _scale), tint)

func _draw_courier() -> void:
	var stage: String = _state.stage
	if stage in [Model.COMPLETE, Model.EXPIRED]:
		return
	var at := _route_point(_state.position).round()
	# Cadence follows actual path distance so a stopped courier has no walk motion.
	var gait := 0.0
	if _state.walking and not _reduced:
		gait = sin(float(_state.distance) * 138.0) * 3.0
	var top := at + Vector2(0, floorf(absf(gait) * -0.65))
	draw_circle(at + Vector2(0, 2), 16.0, Color(DEEP, 0.62))
	draw_rect(Rect2(top + Vector2(-13, -29), Vector2(26, 27)), DEEP)
	draw_rect(Rect2(top + Vector2(-10, -26), Vector2(20, 22)), Color("#d79c65"))
	draw_rect(Rect2(top + Vector2(2, -25), Vector2(8, 20)), Color("#b9716b"))
	draw_rect(Rect2(top + Vector2(-9, -43), Vector2(18, 15)), DEEP)
	draw_rect(Rect2(top + Vector2(-6, -38), Vector2(14, 9)), Color("#edc598"))
	draw_rect(Rect2(top + Vector2(-12, -42), Vector2(26, 5)), Color("#7ac1bc"))
	draw_rect(Rect2(top + Vector2(-11 + gait, -6), Vector2(10, 7)), Color("#627895"))
	draw_rect(Rect2(top + Vector2(2 - gait, -6), Vector2(10, 7)), Color("#9ba4ae"))
	if stage == Model.CARRY or stage == Model.HANDOFF:
		_draw_box(top + Vector2(17, -17))
	if _state.umbrella and stage != Model.SLIDING:
		_draw_umbrella(top + Vector2(0, -44))

func _draw_umbrella(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 27)), DEEP)
	draw_rect(Rect2(at + Vector2(-22, -13), Vector2(44, 15)), Color("#458b9f"))
	draw_rect(Rect2(at + Vector2(-17, -17), Vector2(34, 7)), MINT)
	draw_rect(Rect2(at + Vector2(-10, -21), Vector2(20, 5)), MINT)
	draw_rect(Rect2(at + Vector2(-23, 0), Vector2(46, 4)), Color("#186b83"))

func _draw_box(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(10, 9), Vector2(20, 18)), DEEP)
	draw_rect(Rect2(at - Vector2(8, 7), Vector2(16, 13)), GOLD)
	draw_rect(Rect2(at - Vector2(2, 7), Vector2(4, 13)), Color("#d78071"))

func _draw_slide() -> void:
	var path: PackedVector2Array = _paths[_state.route].path
	var near := path[-1] + Vector2(12, -15)
	var far := near + Vector2(RAIL_SPAN - 12.0, 0.0)
	draw_line(near, far, DEEP, 22.0)
	draw_line(near, far, EDGE, 3.0)
	var puddle: Vector2 = _state.puddle_span
	var wet_from := near.lerp(far, puddle.x)
	var wet_to := near.lerp(far, puddle.y)
	draw_line(wet_from, wet_to, RAIN, 8.0)
	if _state.stage == Model.SLIDING:
		var box := near.lerp(far, _state.slide_progress)
		if _state.puddle_protected:
			_draw_umbrella(box - Vector2(0, 17))
		elif not _reduced and _state.slide_progress >= puddle.x and _state.slide_progress <= puddle.y:
			draw_line(box, box + Vector2(-12, 10), RAIN, 2.0)
			draw_line(box, box + Vector2(7, 13), RAIN, 2.0)
		_draw_box(box)
	else:
		draw_rect(Rect2(far - Vector2(8, 12), Vector2(16, 24)), MINT if _state.slide_ready else EDGE)

func _draw_panel() -> void:
	draw_rect(READOUT, PANEL)
	draw_rect(READOUT, EDGE, false, 2.0)
	var x := READOUT.position.x + 18.0
	_text(Vector2(x, 225), "送往 %s" % _state.recipient, INK, 21, 282.0)
	_meter(Vector2(x, 257), "熱度", _state.temperature, _state.warm_limit, "至少", MINT if _state.temperature >= _state.warm_limit else CORAL)
	_meter(Vector2(x, 320), "濕度", _state.wetness, _state.wet_limit, "至多", RAIN if _state.wetness <= _state.wet_limit else CORAL)
	var stage: String = _state.stage
	if stage in [Model.HANDOFF, Model.SLIDING]:
		var available: bool = _state.slide_ready
		_text(Vector2(x, 402), "滑遞中" if stage == Model.SLIDING else ("可以滑遞" if available else "等候接餐"), MINT if available else INK, 18)
		_draw_timing(Vector2(x, 417), 282.0)
		_text(Vector2(x, 485), "有傘護住積水" if _state.umbrella_manual else "積水段可用傘護餐", GOLD, 17)
	else:
		var exposure := "棚下遮雨" if _state.sheltered else "露天淋雨"
		if _state.umbrella: exposure = "雨傘遮雨" if _state.umbrella_manual else "AI 撐傘"
		_text(Vector2(x, 412), exposure, MINT if _state.sheltered or _state.umbrella else CORAL, 19)
		_text(Vector2(x, 467), "雨從左側來" if _state.rain_direction > 0 else "雨從右側來", RAIN, 17)
		_text(Vector2(x, 493), "撐傘時移動較慢", MUTED, 17)

func _meter(at: Vector2, label: String, fraction: float, limit: float, threshold: String, tone: Color) -> void:
	_text(at, "%s %d%%" % [label, roundi(fraction * 100.0)], tone, 18, 128.0)
	_text(at + Vector2(155, 0), "%s %d%%" % [threshold, roundi(limit * 100.0)], MUTED, 16, 127.0)
	var fill := Rect2(at + Vector2(0, 9), Vector2(282, 12))
	draw_rect(fill, DEEP)
	draw_rect(Rect2(fill.position, Vector2(fraction * fill.size.x, fill.size.y)), tone)
	draw_rect(Rect2(fill.position + Vector2(limit * fill.size.x - 1.0, -3.0), Vector2(2, 18)), INK)

func _draw_timing(at: Vector2, span: float) -> void:
	var band: Vector2 = _state.handoff_window
	draw_rect(Rect2(at, Vector2(span, 23)), DEEP)
	draw_rect(Rect2(at + Vector2(band.x * span, 3.0), Vector2((band.y - band.x) * span, 17)), Color("#397b76"))
	var needle: Vector2 = at + Vector2(span * _state.handoff_phase, 0.0)
	draw_rect(Rect2(needle - Vector2(2.0, 3.0), Vector2(4, 29)), MINT if _state.slide_ready else GOLD)

func _draw_action_hint() -> void:
	var lines: Array = STAGE_HINTS.get(_state.stage, [])
	for index in lines.size():
		_text(Vector2(666, 646 + index * 30), lines[index], INK if index == 0 else MUTED, 18, 575.0)

func _text(at: Vector2, value: String, color: Color, pixel_size: int, width := -1.0) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(pixel_size * _scale), color)
