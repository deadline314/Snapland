extends "res://game/ui/minigame_hold_controls.gd"

const COUNTER_ART := "res://assets/minigames/scent-trail-counter.webp"
const ART := "res://assets/minigames/scent-trail-alleys.webp"
const BOARD := Rect2(35, 187, 847, 328)
const FIELD := Rect2(99, 245, 718, 227)
const READOUT := Rect2(900, 187, 345, 328)
const DEFAULT_BOUNDS := Rect2(-4.15, -2.65, 8.3, 5.95)
const INK := Color("#fff3dd")
const MUTED := Color("#b9cbcc")
const DEEP := Color("#101b25")
const FRAME := Color("#596b70")
const GOLD := Color("#ffcf82")
const MINT := Color("#92dfc9")
const CORAL := Color("#ff9f8f")
const SCENT_TONES := [Color("#8ee3c4"), Color("#ffcd83"), Color("#eab8e5")]
const SCENTS := ["茶香", "炭香", "糖香"]
const HEADINGS := ["北", "東北", "東", "東南", "南", "西南", "西", "西北"]
const GUARDRAIL_LIGHT := Color("#ffd2a8")

enum { MOVE_NORTH, MOVE_EAST, MOVE_SOUTH, MOVE_WEST, TURN_LEFT, TURN_RIGHT, FILTER, ACTION }

const LABELS := ["往北 · W", "往東 · D", "往南 · S", "往西 · A", "左轉聞香器 · Q", "右轉聞香器 · E", "換濾網 · F", "採樣 · 空白"]
const NAMES := ["ScentNorth", "ScentEast", "ScentSouth", "ScentWest", "ScentTurnLeft", "ScentTurnRight", "ScentFilter", "ScentAction"]
const HINTS := [
	"按住沿巷往北", "按住沿巷往東", "按住沿巷往南", "按住沿巷往西",
	"聞香器左轉一格", "聞香器右轉一格", "依序切換全香、茶香、炭香、糖香", "朝著氣味才能採樣",
]

var _state: Dictionary = {}
var _backdrop: Texture2D
var _counter: Texture2D
var _reduced_motion := false
var _last_paint: Array = []
var _last_style := ""
var _last_locale := ""
var _bounds := DEFAULT_BOUNDS
var _link_source: Array = []
var _screen_links: Array[Dictionary] = []
var _stall_source: Array = []
var _stalls_back_to_front: Array = []


static func action_available(action: int, state: Dictionary) -> bool:
	return action >= MOVE_NORTH and action <= ACTION and not state.is_empty() and not state.get("ended", false)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#273b46"), Color("#535643"), FRAME, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	if ResourceLoader.exists(ART):
		_backdrop = load(ART) as Texture2D
	if ResourceLoader.exists(COUNTER_ART):
		_counter = load(COUNTER_ART) as Texture2D
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == ACTION:
		match String(_state.get("action", "sample")):
			"confirm":
				return "確認面前的攤位正在開火"
			"mark":
				return "標記兩股香最先匯合的路口"
			"helper":
				return "標出弱香的下一個上游路口"
	return HINTS[slot] if slot >= 0 else ""


func present(state: Dictionary, reduced_motion: bool = false) -> void:
	_state = state
	_reduced_motion = reduced_motion
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	var typography_changed := _scale != Paper.text_scale() or _last_style != Paper.font_style() or _last_locale != TranslationServer.get_locale()
	if typography_changed:
		refresh_font()
		_last_style = Paper.font_style()
		_last_locale = TranslationServer.get_locale()
	if _state.is_empty():
		if not _last_paint.is_empty():
			_last_paint = []
			_update_buttons()
			queue_redraw()
		return
	var bounds: Rect2 = _state.get("bounds", DEFAULT_BOUNDS)
	bounds = bounds if bounds.has_area() else DEFAULT_BOUNDS
	var geometry_changed := _bounds != bounds
	_bounds = bounds
	# The outer HUD owns the timer. Stage drawing follows the visible pose and cue only.
	var cue: Dictionary = _state.get("cue", {})
	var strengths: Vector3 = cue.get("strengths", Vector3.ZERO)
	var pose: Vector2 = _state.get("player", Vector2.ZERO)
	var paint := [_bounds, _project(pose).snappedf(0.75), _state.get("facing", Vector2.UP), _state.get("sampler_turn", 0),
		_state.get("sampler_dir", Vector2.UP), _state.get("filter", -1), _state.get("links", []), _state.get("stalls", []),
		cue.get("edge", -1), cue.get("position", Vector2.ZERO), cue.get("wind", Vector2.ZERO), cue.get("aligned", false),
		_meter_steps(strengths.x), _meter_steps(strengths.y), _meter_steps(strengths.z), cue.get("mask", 0),
		_state.get("found_mask", 0), _state.get("sampled_mask", 0), _state.get("found", 0), _state.get("mix_proven", false),
		_state.get("mixed_mask", 0), _state.get("helper_ready", false), _state.get("helper_visible", false),
		_state.get("helper_scent", -1), _state.get("helper_point", Vector2.ZERO), _state.get("assist_direction", Vector2.ZERO),
		_state.get("assist_half_angle", 0.0), _state.get("action", "sample"), _state.get("action_ready", false),
		_state.get("ended", false), _state.get("success", false), _state.get("devil", false), _move_mask(), _reduced_motion, _walk_pose()]
	if paint == _last_paint and not typography_changed:
		return
	_last_paint = paint
	_update_geometry(geometry_changed)
	_update_buttons()
	queue_redraw()


func _update_geometry(bounds_changed: bool) -> void:
	var links: Array = _state.get("links", [])
	if bounds_changed or not is_same(links, _link_source):
		_link_source = links
		_screen_links.clear()
		for link: Dictionary in links:
			var a := _project(link.a)
			var b := _project(link.b)
			var direction := (b - a).normalized()
			# Project both boundaries so the visible lane follows the walkable branch.
			var half_width: float = link.get("half_width", 0.44)
			var normal := Vector2(link.b - link.a).normalized().orthogonal() * half_width
			var across := _project(Vector2(link.a) + normal) - a
			_screen_links.append({
				"a": a, "b": b, "direction": direction, "at": a.lerp(b, 0.5),
				"width": absf(across.dot(direction.orthogonal())) * 2.0,
				"open": link.get("open", true), "sampled_mask": link.get("sampled_mask", 0),
				"downwind": _screen_direction(link.a, link.get("wind", Vector2.ZERO)),
			})
	var stalls: Array = _state.get("stalls", [])
	if not is_same(stalls, _stall_source):
		_stall_source = stalls
		_stalls_back_to_front = stalls.duplicate()
		_stalls_back_to_front.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y)


func _update_buttons() -> void:
	var move_mask := _move_mask()
	var filter: int = _state.get("filter", -1)
	for index in _buttons.size():
		var disabled := not action_available(index, _state)
		if _buttons[index].disabled != disabled:
			_buttons[index].disabled = disabled
	for index in range(MOVE_NORTH, MOVE_WEST + 1):
		_set_pressed(index, not _buttons[index].disabled and move_mask & (1 << index) != 0)
	_set_pressed(FILTER, not _buttons[FILTER].disabled and filter >= 0)
	_set_pressed(ACTION, not _buttons[ACTION].disabled and _state.get("action_ready", false))
	_set_button_text(FILTER, "濾網：%s · F" % _filter_name(filter))
	_set_button_text(ACTION, "%s · 空白" % _action_name())


func _move_mask() -> int:
	if _state.has("move_mask"):
		return int(_state.move_mask)
	var velocity: Vector2 = _state.get("velocity", Vector2.ZERO)
	var mask := 0
	if velocity.y < -0.02:
		mask |= 1 << MOVE_NORTH
	elif velocity.y > 0.02:
		mask |= 1 << MOVE_SOUTH
	if velocity.x > 0.02:
		mask |= 1 << MOVE_EAST
	elif velocity.x < -0.02:
		mask |= 1 << MOVE_WEST
	return mask


func _set_pressed(slot: int, pressed: bool) -> void:
	if _buttons[slot].button_pressed != pressed:
		_buttons[slot].set_pressed_no_signal(pressed)


func _set_button_text(slot: int, label: String) -> void:
	if _buttons[slot].text != label:
		_buttons[slot].text = label


func _action_name() -> String:
	match String(_state.get("action", "sample")):
		"confirm":
			return "核對攤位"
		"mark":
			return "標記上游"
		"helper":
			return "查看幫手"
	return "採樣"


func _filter_name(index: int) -> String:
	return SCENTS[index] if index >= 0 and index < SCENTS.size() else "全香"


func _meter_steps(strength: float) -> int:
	return clampi(ceili(strength * 3.0), 0, 3)


func _draw() -> void:
	if _state.is_empty() or _font == null:
		return
	_text(Vector2(35, 172), "轉動聞香器採樣，沿風箭逆向找攤", GOLD, 22, BOARD.size.x)
	_draw_backdrop()
	_draw_lanes()
	var cue: Dictionary = _state.get("cue", {})
	_draw_wind(cue)
	_draw_helper()
	var player: Vector2 = _state.get("player", Vector2.ZERO)
	var drew_player := false
	# Let closer awnings occlude the traveler naturally.
	for stall: Dictionary in _stalls_back_to_front:
		var position: Vector2 = stall.position
		if not drew_player and position.y > player.y:
			_draw_player(player)
			drew_player = true
		_draw_stall(stall, player)
	if not drew_player:
		_draw_player(player)
	_draw_readout(cue)


func _draw_backdrop() -> void:
	draw_rect(BOARD.grow(2.0), FRAME)
	draw_rect(BOARD, DEEP)
	if is_instance_valid(_backdrop):
		var source := _backdrop.get_size()
		var board_aspect := BOARD.size.aspect()
		var crop := source
		if source.aspect() > board_aspect:
			crop.x = source.y * board_aspect
		else:
			crop.y = source.x / board_aspect
		draw_texture_rect_region(_backdrop, BOARD, Rect2((source - crop) * Vector2(0.5, 0.23), crop))
		draw_rect(BOARD, Color(0.04, 0.07, 0.10, 0.3))
	_text(Vector2(52, 211), "風箭指向下游", INK, 16, 200)
	_arrow(Vector2(188, 205), Vector2.RIGHT, 23.0, MINT, 1.7)


func _project(position: Vector2) -> Vector2:
	var normalized := (position - _bounds.position) / _bounds.size
	return FIELD.position + normalized * FIELD.size + Vector2((normalized.y - 0.5) * 27.0, 0.0)


func _screen_direction(world_position: Vector2, direction: Vector2) -> Vector2:
	return (_project(world_position + direction) - _project(world_position)).normalized()


func _draw_lanes() -> void:
	# Keep the painted paving visible through the playable field. The closed
	# branch keeps its striped barrier and a distinct tint at any text scale.
	_stroke_lanes(Vector2.ZERO, 4.5, Color(0.08, 0.14, 0.17, 0.34), Color(0.14, 0.08, 0.11, 0.38))
	_stroke_lanes(Vector2.ZERO, 1.8, Color(0.36, 0.64, 0.62, 0.23), Color(0.50, 0.29, 0.33, 0.26))
	for link in _screen_links:
		var at: Vector2 = link.at
		var direction: Vector2 = link.direction
		var sampled_mask: int = link.sampled_mask
		if not link.open:
			_draw_barrier(at, direction, direction.orthogonal())
		elif sampled_mask != 0:
			var downwind: Vector2 = link.downwind
			_arrow(at, downwind, 23.0, Color(MINT, 0.63), 1.8)
			_draw_patterns(at - downwind * 23.0, sampled_mask, 0.72, 0.78)


func _stroke_lanes(offset: Vector2, extra_width: float, walk: Color, closed: Color) -> void:
	for link in _screen_links:
		draw_line(link.a + offset, link.b + offset, walk if link.open else closed, link.width + extra_width, true)


func _draw_barrier(at: Vector2, direction: Vector2, side: Vector2) -> void:
	draw_line(at - side * 12.0, at + side * 12.0, DEEP, 11.0, true)
	draw_line(at - side * 12.0, at + side * 12.0, CORAL, 6.0, true)
	for stripe in [-7.0, 0.0, 7.0]:
		var center := at + side * float(stripe)
		draw_line(center - direction * 2.3 - side * 1.7, center + direction * 2.3 + side * 1.7,
			GUARDRAIL_LIGHT, 1.5, true)
	draw_circle(at - side * 13.0, 3.1, GUARDRAIL_LIGHT, true, -1.0, true)
	draw_circle(at + side * 13.0, 3.1, GUARDRAIL_LIGHT, true, -1.0, true)


func _draw_wind(cue: Dictionary) -> void:
	var direction: Vector2 = cue.get("wind", Vector2.ZERO)
	if direction.is_zero_approx():
		return
	var position: Vector2 = cue.get("position", Vector2.ZERO)
	var at := _project(position)
	var downwind := _screen_direction(position, direction)
	var side := downwind.orthogonal()
	var mask: int = cue.get("mask", 0)
	var tint := MINT if mask != 0 else MUTED
	_arrow(at, downwind, 42.0, Color(tint, 0.92), 2.7)
	_arrow(at - downwind * 31.0 + side * 9.0, downwind, 16.0, Color(tint, 0.72), 1.5)
	_arrow(at + downwind * 30.0 - side * 9.0, downwind, 16.0, Color(tint, 0.72), 1.5)
	if mask != 0:
		_draw_patterns(at - Vector2(0, 29), mask, 1.03, 1.0)


func _draw_helper() -> void:
	if not _state.get("helper_visible", false):
		return
	var at := _project(_state.get("helper_point", Vector2.ZERO))
	var scent: int = _state.get("helper_scent", -1)
	for index in 4:
		var start := PI * 0.5 * index + 0.18
		draw_arc(at, 16.0, start, start + 1.0, 7, Color(MINT, 0.93), 2.0, true)
	if scent >= 0 and scent < SCENTS.size():
		_pattern(at, scent, 1.03, 0.94)


func _draw_stall(stall: Dictionary, player: Vector2) -> void:
	var position: Vector2 = stall.position
	var at := _project(position)
	var found: bool = stall.get("found", false)
	var near := position.distance_squared_to(player) < 0.70 * 0.70
	var tone := MINT if found else Color("#dcad7d")
	var is_cooking: bool = stall.get("cooking", false)
	var canopy := at + Vector2(0, -22)
	draw_set_transform(at + Vector2(0, 1.5), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 22.0, Color(0.035, 0.055, 0.082, 0.77), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if _counter != null:
		var size := _counter.get_size().normalized() * 60.0
		draw_texture_rect(_counter, Rect2(at - Vector2(size.x * 0.5, size.y), size), false)
	else:
		draw_rect(Rect2(at - Vector2(18, 21), Vector2(36, 21)), Color("#653e3c"))
		draw_line(at - Vector2(18, 15), at + Vector2(18, -15), tone, 2.0, true)
	if found:
		var scent: int = stall.get("scent", -1)
		if scent >= 0 and scent < SCENTS.size():
			_pattern(canopy + Vector2(0, -13), scent, 0.92, 1.0)
	elif near:
		if is_cooking:
			for x in [-8, 0, 8]:
				_steam(canopy + Vector2(x, -14))
		draw_line(at + Vector2(-22, 4), at + Vector2(22, 4), GOLD, 2.0, true)


func _steam(at: Vector2) -> void:
	draw_polyline(PackedVector2Array([at, at + Vector2(-2, -3), at + Vector2(0, -7), at + Vector2(-1, -11)]),
		Color(INK, 0.88), 1.4, true)


func _walk_pose() -> int:
	var velocity: Vector2 = _state.get("velocity", Vector2.ZERO)
	if _reduced_motion or velocity.length_squared() < 0.04:
		return 0
	return posmod(floori(float(_state.get("elapsed", 0.0)) * 30.0), 12)


func _draw_player(position: Vector2) -> void:
	var at := _project(position)
	var facing: Vector2 = _state.get("facing", Vector2.DOWN)
	var sampler: Vector2 = _state.get("sampler_dir", Vector2.UP)
	var screen_heading := _screen_direction(position, sampler)
	var sampler_origin := at + Vector2(0, -11)
	var assist: Vector2 = _state.get("assist_direction", Vector2.ZERO)
	var half_angle: float = _state.get("assist_half_angle", 0.0)
	if not assist.is_zero_approx() and half_angle > 0.0:
		var fan := PackedVector2Array([sampler_origin])
		for step in 7:
			var angle := lerpf(-half_angle, half_angle, step / 6.0)
			fan.append(sampler_origin + _screen_direction(position, assist.rotated(angle)) * 43.0)
		draw_colored_polygon(fan, Color(MINT, 0.14))
		fan.append(sampler_origin)
		draw_polyline(fan, Color(MINT, 0.42), 1.4, true)
	draw_set_transform(at + Vector2(0, 2), 0.0, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, 13.5, Color(0.035, 0.06, 0.077, 0.9), true, -1.0, true)
	if _state.get("action_ready", false):
		draw_circle(Vector2.ZERO, 15.0, GOLD, false, 2.2, true)
	draw_set_transform(Vector2.ZERO)
	# The traveler's clothing and instrument tip use separate silhouettes from the wind arrows.
	var turn := signf(facing.x)
	var pace := sin(TAU * _walk_pose() / 12.0)
	var step := _screen_direction(position, facing) * pace * 4.0
	draw_line(at + Vector2(-4, -7), at + Vector2(-5 + turn, 0) + step, DEEP, 4.0, true)
	draw_line(at + Vector2(4, -7), at + Vector2(5 + turn, 0) - step, DEEP, 4.0, true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-5, -17), at + Vector2(5, -17), at + Vector2(9, -3), at + Vector2(-9, -3),
	]), Color("#c47655"))
	draw_line(at + Vector2(-5, -10), at + Vector2(6, -8), GOLD, 2.0, true)
	draw_circle(at + Vector2(turn, -21), 5.8, Color("#f8cb9c"), true, -1.0, true)
	draw_arc(at + Vector2(turn, -21), 6.0, PI, TAU, 10, Color("#344a52"), 3.0, true)
	var tip := sampler_origin + screen_heading * 28.0
	draw_line(sampler_origin, tip, DEEP, 7.0, true)
	draw_line(sampler_origin, tip, GOLD, 3.5, true)
	if not _reduced_motion:
		draw_circle(tip, 10.0, Color(GOLD, 0.16), true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([
		tip + screen_heading * 5.0, tip + screen_heading.orthogonal() * 4.8,
		tip - screen_heading * 5.0, tip - screen_heading.orthogonal() * 4.8,
	]), INK)


func _draw_readout(cue: Dictionary) -> void:
	draw_rect(READOUT.grow(2.0), FRAME)
	draw_rect(READOUT, DEEP)
	draw_rect(Rect2(900, 187, 345, 4), GOLD)
	var heading: int = posmod(int(_state.get("sampler_turn", 0)), HEADINGS.size())
	var filter: int = _state.get("filter", -1)
	var found: int = _state.get("found", 0)
	_text(Vector2(919, 224), "聞香器 · 朝%s" % HEADINGS[heading], INK, 21, 307.0)
	_text(Vector2(919, 251), "濾網 %s     找到 %d／3" % [_filter_name(filter), found], MUTED, 17, 307.0)
	var strengths: Vector3 = cue.get("strengths", Vector3.ZERO)
	var sampled: int = _state.get("sampled_mask", 0)
	var found_mask: int = _state.get("found_mask", 0)
	for scent in SCENTS.size():
		var row := Vector2(919, 276 + float(scent) * 35.0)
		_draw_reading(row, scent, _meter_steps(strengths[scent]), sampled, found_mask)
	draw_line(Vector2(919, 386), Vector2(1227, 386), FRAME, 1.2, true)
	var prompt := "靠近有風的巷道"
	var detail := "風箭指向氣味飄散的方向"
	var accent := MUTED
	if _state.get("success", false):
		prompt = "找到三個香源"
		detail = "已標記共用上游" if _state.get("mix_proven", false) else "採樣結果已記錄"
		accent = MINT
	elif _state.get("ended", false):
		prompt = "時間到"
		detail = "已核對 %d／3 攤" % found
	elif _state.get("action_ready", false):
		prompt = "%s · 空白" % _action_name()
		detail = "沿風箭反方向找香源"
		accent = GOLD
	elif Vector2(cue.get("wind", Vector2.ZERO)).length_squared() > 0.0:
		prompt = "轉向有訊號的位置"
		detail = "快到攤前時核對氣味"
	if _state.get("helper_visible", false):
		detail = "虛線圈標出微弱氣味"
	elif _state.get("helper_ready", false):
		detail = "R／Y 查看微弱氣味"
	elif int(_state.get("mixed_mask", 0)) != 0 and not _state.get("mix_proven", false):
		detail = "去兩種氣味共用的上游"
	_text(Vector2(919, 423), prompt, accent, 19, 309.0)
	_text(Vector2(919, 451), detail, MUTED, 17, 309.0)
	if _state.get("mix_proven", false):
		_text(Vector2(919, 489), "共用上游已標記", MINT, 17, 309.0)
	elif int(_state.get("mixed_mask", 0)) != 0:
		_text(Vector2(919, 489), "分辨出兩種混合氣味", GOLD, 17, 309.0)


func _draw_reading(row: Vector2, scent: int, steps: int, sampled: int, found_mask: int) -> void:
	var bit := 1 << scent
	var tone: Color = SCENT_TONES[scent]
	_pattern(row + Vector2(12, 0), scent, 1.0, 1.0)
	_text(row + Vector2(34, 6), SCENTS[scent], INK, 18, 83.0)
	for segment in 3:
		var box := Rect2(row + Vector2(110 + segment * 24, -4), Vector2(18, 8))
		draw_rect(box, tone if segment < steps else Color("#324754"))
		if segment < steps:
			draw_line(box.position + Vector2(3, 2), box.position + Vector2(13, 2), Color(INK, 0.66), 1.0, true)
	if found_mask & bit != 0:
		_text(row + Vector2(196, 6), "已核對", MINT, 16, 111.0)
	elif sampled & bit != 0:
		_text(row + Vector2(196, 6), "已採樣", MUTED, 16, 111.0)


func _draw_patterns(at: Vector2, mask: int, scale: float, opacity: float) -> void:
	var count := int(mask & 1 != 0) + int(mask & 2 != 0) + int(mask & 4 != 0)
	var x := (1 - count) * 12.0 * scale
	for scent in SCENTS.size():
		if mask & (1 << scent) != 0:
			_pattern(at + Vector2(x, 0), scent, scale, opacity)
			x += 24.0 * scale


func _pattern(at: Vector2, scent: int, scale: float, opacity: float) -> void:
	var tint := Color(SCENT_TONES[scent], opacity)
	draw_circle(at, 10.0 * scale, Color(DEEP, 0.92), true, -1.0, true)
	if scent == 0:
		draw_circle(at, 7.5 * scale, tint, false, 1.8 * scale, true)
	else:
		var outline := PackedVector2Array([at + Vector2(0, -8) * scale])
		if scent == 1:
			outline.append(at + Vector2(8, 0) * scale)
			outline.append(at + Vector2(0, 8) * scale)
			outline.append(at + Vector2(-8, 0) * scale)
		else:
			outline.append(at + Vector2(8, 6.5) * scale)
			outline.append(at + Vector2(-8, 6.5) * scale)
		outline.append(outline[0])
		draw_polyline(outline, tint, 1.8 * scale, true)
	for stripe in scent + 1:
		var x := (float(stripe) - scent * 0.5) * 3.1 * scale
		draw_line(at + Vector2(x, -0.75 * scale), at + Vector2(x, 3.2 * scale), tint, 1.4 * scale, true)


func _arrow(at: Vector2, direction: Vector2, length: float, tone: Color, width: float) -> void:
	if direction.is_zero_approx():
		return
	var tail := at - direction * length * 0.5
	var tip := at + direction * length * 0.5
	var base := tip - direction * 6.0
	var side := direction.orthogonal() * 3.8
	draw_line(tail, tip, DEEP, width + 2.4, true)
	draw_line(tail, tip, tone, width, true)
	draw_polyline(PackedVector2Array([base + side, tip, base - side]), tone, width, true)


func _text(at: Vector2, value: String, color: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), color)
