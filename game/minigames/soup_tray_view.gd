extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/soup_tray_model.gd")
const GLAZES := "res://assets/minigames/soup-tray-glazes.webp"
const ALLEY := "res://assets/minigames/soup-tray-alley.webp"
const RECEIVER := "res://assets/characters/identities-v3.png"
const RECEIVER_REGION := Rect2(675, 642, 207, 369)
const BOARD := Rect2(35, 187, 847, 328)
const READOUT := Rect2(900, 187, 345, 328)
const BOWL_CENTER := Vector2(1072, 346)
const FRAME := Color("#8b7565")
const INK := Color("#fff0dc")
const PANEL := Color("#252824")
const GOLD := Color("#ffd18d")
const MINT := Color("#abe0c4")
const MUTED := Color("#b7bcb4")
const CORAL := Color("#ffa28e")
const WATER := Color("#152931")
const GLAZE_COLORS := [Color("#d9d4ba"), Color("#adc09d"), Color("#bd7054")]
const PHASE_TINT := {
	"dawn": Color("#d8c2b7"), "noon": Color("#e0dbd0"),
	"dusk": Color("#dbbaad"), "night": Color("#bbbccc"),
}
const CIRCLE_SAMPLES := 48
## Lacquered stall wood for boards; boardwalk planks and dark channel water.
const LACQUER := Color("#3a2a26")
const BOARDWALK := Color("#8a6a4a")
const ROUTE_WIDTH := 0.42

enum {
	WALK, BRAKE, ROUTE, ACTION, LEAN_FORWARD, LEAN_LEFT, LEAN_BACK, LEAN_RIGHT,
	SAFE, CHANNEL, RETRY,
}
const LABELS := [
	"按住走 · W", "煞停 · 空白", "近路 · D", "滑送／交碗 · E",
	"往前傾 · ↑", "往左傾 · ←", "往後傾 · ↓", "往右傾 · →",
]
const KEY_ICONS := ["walk", "stop", "swap", "confirm", "up", "left", "down", "right"]
## Lacquered stall wood for the key caps.
const KEY_TONE := Color("#5e3a30")
const NAMES := [
	"SoupWalk", "SoupBrake", "SoupRoute", "SoupAction", "SoupLeanForward",
	"SoupLeanLeft", "SoupLeanBack", "SoupLeanRight",
]
const HINTS := [
	"按住行走。與煞車同按可慢走。",
	"放開行走再煞停。交碗前等湯面安定。",
	"每碗出發前可以換路。",
	"槽邊按住等回流。接盤人伸手才可交碗。",
	"朝槽口傾斜托盤。",
	"托盤向左傾，抵銷向右的浪。",
	"先往後帶起浪，再前傾等浪回來。",
	"托盤向右傾，抵銷向左的浪。",
]

var _state: Dictionary = {}
var _scenery: Control
var _glazes: Texture2D
var _alley: Texture2D
var _receiver: Texture2D
var _rays := PackedVector2Array()
var _phase := "night"
var _reduced := false
var _terrain_paint: Array = []
var _last_controls: Array = []
var _last_paint: Array = []
var _font_style := ""
var _locale := ""


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.get("ended", true):
		return false
	if state.stage == Model.DAMAGED:
		return state.retry_ready and action in [ROUTE, RETRY]
	match action:
		ROUTE, SAFE, CHANNEL:
			return state.route_selectable
		WALK:
			return state.stage in [Model.CARRY, Model.GAP, Model.HANDOFF]
		BRAKE, LEAN_FORWARD, LEAN_LEFT, LEAN_BACK, LEAN_RIGHT:
			return state.stage != Model.FLIGHT
		ACTION:
			return state.stage == Model.GAP or state.stage == Model.HANDOFF
	return false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	build_controls(LABELS, Color("#303b37"), Color("#635248"), FRAME, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	use_key_caps(KEY_ICONS, KEY_TONE)
	_glazes = load(GLAZES) as Texture2D
	_alley = load(ALLEY) as Texture2D
	_receiver = load(RECEIVER) as Texture2D
	for index in CIRCLE_SAMPLES:
		_rays.append(Vector2.from_angle(TAU * float(index) / CIRCLE_SAMPLES))
	_scenery = Control.new()
	_scenery.name = "SoupCourtyard"
	_scenery.show_behind_parent = true
	_scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scenery.draw.connect(_draw_terrain)
	add_child(_scenery)
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot == ROUTE and _state.get("retry_ready", false):
		return "重試這一碗。先前交好的湯會保留。"
	if slot < 0 and READOUT.has_point(point) and not _state.is_empty():
		return "已保住回流交接" if _state.challenge_proven else ("已過槽，穩住這一碗" if _state.crossing_proven else "回流過槽需保有八成湯")
	return HINTS[slot] if slot >= 0 and slot < HINTS.size() else ""


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	_state = state
	_reduced = reduced_motion
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
	var terrain := [_state.layout, _state.route, _phase]
	if terrain != _terrain_paint:
		_terrain_paint = terrain
		_scenery.queue_redraw()
	var mask: int = _state.get("control_mask", 0)
	var controls := [mask, _state.stage, _state.ended, _state.route_selectable, _state.route, _state.retry_ready]
	if controls != _last_controls:
		_last_controls = controls
		_refresh_controls(mask)
	var paint := [
		_state.stage, _state.layout, _state.route, _state.delivered, _state.retry_ready,
		_state.player.snapped(Vector2(0.008, 0.008)), _state.bowl_position.snapped(Vector2(0.008, 0.008)),
		snappedf(_state.bowl_height, 0.004), _state.lean.snapped(Vector2(0.005, 0.005)),
		_state.liquid_slope.snapped(Vector2(0.005, 0.005)), snappedf(_state.liquid_depth, 0.0005),
		snappedf(_state.fill, 0.01), _state.launch_ready, _state.return_ready, _state.handoff_ready,
		_state.recipient_ready, _state.crossing_proven, _state.challenge_proven, _reduced,
		_state.projected_landing.snapped(Vector2(0.008, 0.008)) if _state.stage == Model.GAP else Vector2.ZERO,
		_state.feedback, _state.get("slide_held", false),
	]
	if paint != _last_paint or typography_changed:
		_last_paint = paint
		queue_redraw()


func _refresh_controls(mask: int) -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		button.disabled = not action_available(index, _state)
		button.set_pressed_no_signal(bool(mask & (1 << index)) and not button.disabled)
	_buttons[ROUTE].text = "重試這碗 · R" if _state.retry_ready else ("改走外路 · A" if _state.route == Model.CHANNEL else "改走槽邊 · D")
	_buttons[ACTION].text = "交碗 · E" if _state.stage == Model.HANDOFF else "滑送 · E"
	_buttons[BRAKE].text = "煞車／慢走 · 空白"


func _project(point: Vector2, height: float = 0.0) -> Vector2:
	# Depth foreshortens the assembled lane while keeping the same plan as the simulation.
	return Vector2(458 + point.x * (118.0 - 6.5 * point.y), 476 - 29.0 * point.y - height * 79.0)


func _draw_terrain() -> void:
	var canvas := _scenery
	Props.wood_panel(canvas, BOARD.grow(8.0), LACQUER)
	canvas.draw_rect(BOARD, Color("#242c2d"))
	if _alley != null:
		var original := _alley.get_size()
		var crop := Vector2(minf(original.x, original.y * BOARD.size.aspect()), minf(original.y, original.x / BOARD.size.aspect()))
		canvas.draw_texture_rect_region(_alley, BOARD, Rect2((original - crop) * Vector2(0.5, 0.41), crop), PHASE_TINT[_phase])
	canvas.draw_rect(BOARD, Color(0.025, 0.044, 0.047, 0.31))
	var gap: Dictionary = _state.gap
	var near: Vector2 = gap.near
	var far: Vector2 = gap.far
	_patch(canvas, -0.76, 0.76, near.y - 0.05, far.y + 0.05, Color("#192419"))
	_patch(canvas, -0.68, 0.68, near.y, far.y, WATER, Props.material_tile("metal", Color("#2c5560")))
	for index in range(3):
		var depth := lerpf(near.y, far.y, (index + 1.0) / 4.0)
		canvas.draw_line(_project(Vector2(-0.54, depth)), _project(Vector2(0.53, depth)), Color("#43616b"), 1.3, true)
	var paths: Array = _state.paths
	var selected: int = _state.route
	for route in [Model.CHANNEL if selected == Model.SAFE else Model.SAFE, selected]:
		var channel: bool = route == Model.CHANNEL
		_draw_route(canvas, paths[route], near.y if channel else -1.0, far.y if channel else -1.0, route == selected)
	_patch(canvas, -gap.half_width, gap.half_width, far.y, gap.landing_end.y, Color.WHITE, Props.material_tile("wood", Color("#a3603f")))
	_crossbar(canvas, near, ROUTE_WIDTH, Color("#f2c88a"), 3.0)
	_crossbar(canvas, far, ROUTE_WIDTH, Color("#db995e"), 4.0)
	_crossbar(canvas, gap.landing_end, gap.half_width, Color("#f2c88a"), 2.0)
	var landing: Vector2 = _state.recipient
	_patch(canvas, landing.x - 0.57, landing.x + 0.57, landing.y - 0.10, landing.y + 0.57, Color.WHITE, Props.material_tile("wood", Color("#6a5242")))
	_crossbar(canvas, landing + Vector2(0.0, 0.53), 0.57, Color("#b98856"), 5.0)
	_crossbar(canvas, Vector2.ZERO, 0.52, Color("#cda97c"), 4.0)


func _patch(canvas: CanvasItem, left: float, right: float, near: float, far: float, tone: Color, tile: Texture2D = null) -> void:
	var corners := PackedVector2Array([
		_project(Vector2(left, near)), _project(Vector2(right, near)),
		_project(Vector2(right, far)), _project(Vector2(left, far)),
	])
	if tile == null:
		canvas.draw_colored_polygon(corners, tone)
	else:
		Props.fill_polygon(canvas, corners, tile, tone)


func _crossbar(canvas: CanvasItem, point: Vector2, half_width: float, tone: Color, width: float) -> void:
	canvas.draw_line(_project(point - Vector2(half_width, 0)), _project(point + Vector2(half_width, 0)), tone, width, true)


func _draw_route(canvas: CanvasItem, path: PackedVector2Array, near: float, far: float, chosen: bool) -> void:
	var section := PackedVector2Array([path[0]])
	for index in range(1, path.size()):
		var a := path[index - 1]
		var b := path[index]
		if a.y < near and b.y >= far:
			section.append(a.lerp(b, inverse_lerp(a.y, b.y, near)))
			_draw_paving(canvas, section, chosen)
			section = PackedVector2Array([a.lerp(b, inverse_lerp(a.y, b.y, far))])
		section.append(b)
	_draw_paving(canvas, section, chosen)


func _draw_paving(canvas: CanvasItem, path: PackedVector2Array, chosen: bool) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index in path.size():
		var point := path[index]
		var incoming := path[maxi(index - 1, 0)].direction_to(point)
		var outgoing := point.direction_to(path[mini(index + 1, path.size() - 1)])
		var across := (incoming + outgoing).normalized().orthogonal()
		var edge := across * ROUTE_WIDTH
		left.append(_project(point + edge))
		right.append(_project(point - edge))
	_draw_deck(canvas, left, right, Vector2(3, 7), Color(0.07, 0.05, 0.05, 0.7))
	_draw_deck(canvas, left, right, Vector2(0, 5), Props.deepen(BOARDWALK, 0.5))
	_draw_deck(canvas, left, right, Vector2.ZERO, Color.WHITE if chosen else Color(0.52, 0.56, 0.6), Props.material_tile("wood", BOARDWALK))
	var rail := Color("#c0a077") if chosen else Color("#76867b")
	canvas.draw_polyline(left, rail, 1.6, true)
	canvas.draw_polyline(right, rail, 1.6, true)
	var advance := 0.54
	for index in range(1, path.size()):
		var segment := path[index - 1].distance_to(path[index])
		while advance < segment:
			var fraction := advance / segment
			var a := left[index - 1].lerp(left[index], fraction)
			var b := right[index - 1].lerp(right[index], fraction)
			canvas.draw_line(a.lerp(b, 0.05), b.lerp(a, 0.05), Color(0.09, 0.065, 0.05, 0.42), 1.1, true)
			advance += 0.54
		advance -= segment


func _draw_deck(canvas: CanvasItem, left: PackedVector2Array, right: PackedVector2Array, offset: Vector2, tone: Color, tile: Texture2D = null) -> void:
	for index in range(1, left.size()):
		var a := left[index - 1] + offset
		var b := right[index - 1] + offset
		var c := right[index] + offset
		var d := left[index] + offset
		for triangle in [[a, b, c], [a, c, d]]:
			var origin: Vector2 = triangle[0]
			if absf((Vector2(triangle[1]) - origin).cross(Vector2(triangle[2]) - origin)) > 0.01:
				if tile == null:
					canvas.draw_colored_polygon(PackedVector2Array(triangle), tone)
				else:
					Props.fill_polygon(canvas, PackedVector2Array(triangle), tile, tone)


func _draw() -> void:
	if _state.is_empty() or _font == null or _rays.is_empty():
		return
	_text(Vector2(35, 173), _guide(), GOLD, 22, BOARD.size.x)
	_draw_course()
	_draw_readout()


func _guide() -> String:
	match _state.stage:
		Model.DAMAGED, Model.ENDED:
			return _state.feedback
		Model.GAP:
			if _state.return_ready:
				return "回流到了 · 現在滑送"
			if _state.launch_ready:
				return "落點進接板 · 按住 E 可等後浪再滑送"
			return "槽邊放開行走 · 往前傾到落點進接板"
		Model.FLIGHT:
			return "碗正在越過水槽"
		Model.HANDOFF:
			if _state.handoff_ready:
				return "接盤人伸手了 · 現在交碗"
			return "停穩放平，等接盤人伸手"
	if _state.route_selectable:
		return "出發前選路 · 外路繞彎，近路跨過水槽"
	return "過彎減速，端穩再走"


func _draw_course() -> void:
	var recipient := _project(_state.recipient)
	var hand_color := MINT if _state.recipient_ready else Color("#ac8875")
	if _receiver:
		draw_texture_rect_region(_receiver, Rect2(recipient + Vector2(-15, -57), Vector2(30, 54)), RECEIVER_REGION, Color("#f5d4ae"))
	else:
		draw_circle(recipient - Vector2(0, 35), 8.0, Color("#e3a878"), true, -1.0, true)
	for side in [-1, 1]:
		var hand := recipient + Vector2(side * (16.0 if _state.recipient_ready else 12.0), -8.0)
		draw_line(recipient + Vector2(side * 8.0, -19.0), hand, hand_color, 4.5, true)
		draw_circle(hand, 3.4, hand_color, true, -1.0, true)
	draw_arc(recipient, 13.0, 0, TAU, 22, hand_color, 2.0, true)
	if _state.stage == Model.GAP:
		_draw_forecast()
	var position := _project(_state.player)
	draw_set_transform(position, 0.0, Vector2(1.0, 0.39))
	draw_circle(Vector2.ZERO, 20.0, Color(0.0, 0.0, 0.0, 0.52), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if not _state.airborne:
		Props.shaded_box(self, Rect2(position + Vector2(-17, -9), Vector2(34, 10)), Color("#b58b59"), 4.0)
	var bowl := _project(_state.bowl_position, _state.bowl_height)
	var type: int = _state.bowl.id
	draw_line(bowl + Vector2(-11, 1), bowl + Vector2(11, 1), GLAZE_COLORS[type].darkened(0.35), 10.0, true)
	draw_line(bowl + Vector2(-12, -4), bowl + Vector2(12, -4), GLAZE_COLORS[type], 4.0, true)
	draw_line(bowl + Vector2(-7, -4), bowl + Vector2(7, -4), Color("#bb804d"), 2.0, true)


func _draw_forecast() -> void:
	var prediction: Vector2 = _state.projected_landing
	var displayed := Vector2(clampf(prediction.x, -1.4, 1.4), clampf(prediction.y, 3.4, 6.6))
	var end := _project(displayed)
	var start := _project(_state.player, 0.21)
	var tint := MINT if _state.return_ready else (GOLD if _state.launch_ready else CORAL)
	if not _reduced:
		draw_dashed_line(start, end, Color(tint, 0.73), 1.8, 7.0, true, true)
	var mark := PackedVector2Array([end + Vector2.UP * 5, end + Vector2.RIGHT * 8,
		end + Vector2.DOWN * 5, end + Vector2.LEFT * 8, end + Vector2.UP * 5])
	draw_polyline(mark, tint, 2.0, true)


func _draw_readout() -> void:
	Props.lacquer_board(self, READOUT, LACQUER)
	Props.wood_panel(self, Rect2(914, 232, 316, 4), Props.deepen(LACQUER, 0.2))
	_text(Vector2(918, 222), _state.bowl.name, INK, 24, 196.0)
	_text(Vector2(1124, 222), "第 %d 碗" % mini(Model.BOWL_COUNT, int(_state.delivered) + 1), MUTED, 17, 104.0)
	_draw_bowl()
	var fill := roundi(_state.fill * 100.0)
	var amount := "剩湯 %d%%" % fill
	_text(Vector2(918, 442), amount, INK, 19, 138.0)
	var bar := Rect2(1061, 431, 166, 10)
	draw_rect(bar.grow(2.0), Props.deepen(LACQUER, 0.4))
	draw_rect(bar, Color("#1d1416"))
	draw_rect(Rect2(bar.position.x, bar.end.y, bar.size.x, 2), Props.lighten(LACQUER, 0.25))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _state.fill, bar.size.y)), MINT if fill >= 80 else GOLD)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _state.fill, 2)), Props.lighten(MINT if fill >= 80 else GOLD, 0.4))
	for threshold in [Model.MIN_FILL, Model.PROOF_FILL]:
		var tick := bar.position + Vector2(bar.size.x * threshold, -4)
		draw_line(tick, tick + Vector2(0, 18), INK, 1.0, true)
	_text(Vector2(918, 478), _readout(), MINT if _state.return_ready or _state.handoff_ready else GOLD, 17, 311.0)


func _readout() -> String:
	if _state.return_ready:
		return "後側浪正回來 · 可滑送"
	if _state.launch_ready:
		return "命中接板 · 等湯浪回來"
	if _state.handoff_ready:
		return "接盤人已伸手 · 可交碗"
	if _state.stage == Model.GAP:
		if _state.get("slide_held", false):
			return "滑送已預備 · 等落點與回流"
		return "調整前傾，讓落點進接板"
	if _state.stage == Model.HANDOFF:
		return "交接中 · 停穩放平"
	return "放平托盤，避免湯越過碗沿"


func _bowl_point(point: Vector2, height: float) -> Vector2:
	return BOWL_CENTER + Vector2(point.x * 378.0, point.y * 188.0 - height * 232.0)


func _ellipse(radius: float, height: float, lean: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for ray in _rays:
		var point := ray * radius
		points.append(_bowl_point(point, height + lean.dot(point)))
	return points


func _draw_bowl() -> void:
	var shape: Dictionary = _state.bowl
	var lean: Vector2 = _state.lean
	var radius: float = shape.radius
	var base: float = shape.base_radius
	var depth: float = shape.depth
	var lip := _ellipse(radius, depth, lean)
	var foot := _ellipse(base, 0.0, lean)
	var silhouette := lip.duplicate()
	silhouette.append_array(foot)
	# The projected rims can overlap when tilted. Their convex envelope is the
	# visible outer wall of the tapered bowl and always triangulates as one surface.
	var face := Geometry2D.convex_hull(silhouette)
	face.remove_at(face.size() - 1)
	var uv := PackedVector2Array()
	var atlas_mid := (float(shape.id) + 0.5) / 3.0
	var top := _bowl_point(Vector2.ZERO, depth).y - radius * 188.0
	var bottom := _bowl_point(Vector2.ZERO, 0.0).y + base * 188.0
	for point in face:
		var x := clampf((point.x - BOWL_CENTER.x) / (radius * 378.0), -1.0, 1.0)
		var y := clampf(inverse_lerp(top, bottom, point.y), 0.0, 1.0)
		uv.append(Vector2(atlas_mid + x * 0.161, lerpf(0.07, 0.89, y)))
	var tone: Color = GLAZE_COLORS[shape.id]
	draw_set_transform(_bowl_point(Vector2.ZERO, -0.025), 0.0, Vector2(1.0, 0.29))
	draw_circle(Vector2.ZERO, base * 435.0, Color(0.0, 0.0, 0.0, 0.42), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if _glazes:
		draw_polygon(face, PackedColorArray([Color("#d6c1b0")]), uv, _glazes)
	else:
		draw_colored_polygon(face, tone)
	draw_colored_polygon(lip, tone.darkened(0.58))
	_draw_liquid(shape, lean)
	lip.append(lip[0])
	draw_polyline(lip, tone.lightened(0.28), 3.4, true)
	draw_line(lip[27], lip[33], Color(tone.lightened(0.54), 0.67), 1.7, true)


func _draw_liquid(shape: Dictionary, lean: Vector2) -> void:
	var slope: Vector2 = _state.liquid_slope
	var center_depth: float = _state.liquid_depth
	var base: float = shape.base_radius
	var lip_depth: float = shape.depth
	var widening := (float(shape.radius) - base) / lip_depth
	var points := PackedVector2Array()
	for ray in _rays:
		var reach := clampf((base + widening * center_depth) / maxf(0.2, 1.0 - widening * slope.dot(ray)), base, shape.radius)
		var point := ray * reach
		var height := clampf(center_depth + slope.dot(point), 0.0, lip_depth)
		points.append(_bowl_point(point, height + lean.dot(point)))
	var crest := _rays[0]
	if slope.length_squared() > 0.00001:
		crest = slope.normalized()
	var tone := Color("#db9a58") if not _state.return_ready else Color("#ebac63")
	draw_colored_polygon(points, tone)
	var center := _bowl_point(Vector2.ZERO, center_depth)
	var warm: Color = tone.lightened(0.22)
	for index in [3, 9, 14, 24, 34]:
		var start := center.lerp(points[index], 0.36)
		var end := center.lerp(points[(index + 2) % points.size()], 0.50)
		draw_line(start, end, Color(warm, 0.65), 2.0, true)
	var peak := posmod(roundi(crest.angle() / TAU * CIRCLE_SAMPLES), CIRCLE_SAMPLES)
	var color := MINT if _state.return_ready else Color("#ffe0a7")
	for offset in range(-3, 3):
		draw_line(points[posmod(peak + offset, CIRCLE_SAMPLES)], points[posmod(peak + offset + 1, CIRCLE_SAMPLES)], color, 2.4, true)


func _text(point: Vector2, value: String, color: Color, pixels: float, width: float) -> void:
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(pixels * _scale), color)
