extends "res://game/ui/minigame_hold_controls.gd"

const Model = preload("res://game/minigames/banner_cart_model.gd")
const Stage = preload("res://game/minigames/banner_cart_stage.gd")
const BOARD := Rect2(35, 187, 848, 328)
const READOUT := Rect2(900, 187, 345, 328)
const PROFILE := Rect2(914, 259, 317, 145)
const PROFILE_ORIGIN := Vector2(1072.5, 398)
const PROFILE_SCALE := 51.0
const INK := Color("#fff1df")
const PALE := Color("#b9cbd2")
const DEEP := Color("#151e2c")
const PANEL := Color("#1d2a3a")
const EDGE := Color("#697985")
const GRID := Color("#3b4a5b")
const COPPER := Color("#c99578")
const GOLD := Color("#ffdc9d")
const MINT := Color("#a8e5cb")
const CORAL := Color("#ffb6a5")
const FABRICS := [Color("#ebad86"), Color("#9bd6bb"), Color("#d2b2ed")]

enum { DRIVE, BRAKE, RAISE, LOWER, ROLL_LEFT, ROLL_RIGHT, DIRECT, BYPASS }

const LABELS := [
	"推車前進 · W", "按住煞車 · 空白", "升架 · R", "降架 · F",
	"左側上抬 · Q", "右側上抬 · E", "選近巷 · A", "選外側寬路 · D",
]
const NAMES := [
	"BannerDrive", "BannerBrake", "BannerRaise", "BannerLower",
	"BannerRollLeft", "BannerRollRight", "BannerDirect", "BannerBypass",
]
const HINTS := [
	"按住向前推，鬆開會減速", "按住減速。停穩後可調整招幌",
	"升高整幅招幌", "降低整幅招幌，避開低檐",
	"抬高左側，同時壓低右側", "抬高右側，同時壓低左側",
	"先回正過窄口，再依低檐側傾", "路程較長，先降架通過低棚",
]

var _state: Dictionary = {}
var _stage: SubViewport
var _phase := "night"
var _reduced_motion := false
var _font_style := ""
var _locale := ""
var _last_paint: Array = []
var _last_controls: Array = []


static func action_available(action: int, state: Dictionary) -> bool:
	if state.is_empty() or state.get("ended", true):
		return false
	match action:
		DRIVE, BRAKE, RAISE, LOWER, ROLL_LEFT, ROLL_RIGHT:
			return true
		DIRECT, BYPASS:
			return not state.get("route_locked", true)
	return false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_controls(LABELS, Color("#2e3c4a"), Color("#625143"), EDGE, GOLD)
	for index in NAMES.size():
		_buttons[index].name = NAMES[index]
	_stage = Stage.new()
	add_child(_stage)
	_refresh()


func _get_tooltip(point: Vector2) -> String:
	var slot := hit_slot(point)
	if slot in [DIRECT, BYPASS] and _state.get("route_locked", false):
		return "下一幅招幌出發前可換路"
	return HINTS[slot] if slot >= 0 else ""


func present(state: Dictionary, reduced_motion: bool = false, phase: String = "night") -> void:
	_state = state
	_reduced_motion = reduced_motion
	_phase = phase
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _state.is_empty():
		return
	_stage.update_stage(_state, _phase, _reduced_motion)
	var typography_changed := _scale != Paper.text_scale() or _font_style != Paper.font_style() or _locale != TranslationServer.get_locale()
	if typography_changed:
		refresh_font()
		_font_style = Paper.font_style()
		_locale = TranslationServer.get_locale()
	_refresh_controls()
	var at_crosswalk := _crosswalk_near()
	var paint := [
		_state.layout, _state.banner_index, _state.route, _state.route_locked, _state.assisted,
		_state.block_kind, _state.block_id, _state.braking, _state.speed > 0.025, _state.challenge_proven,
		snappedf(_state.lift, 0.005), snappedf(_state.roll, 0.008), _state.clearance.gate_id,
		snappedf(_state.clearance.distance, 0.04), _state.clearance.margin > 0.0, at_crosswalk,
	]
	if _state.assisted:
		paint.append(snappedf(_state.clearance.margin, 0.005))
	if at_crosswalk:
		paint.append(snappedf(_state.pedestrian.position.x, 0.035))
		paint.append(_person_in_lane(_crosswalk_bounds()))
	if paint == _last_paint and not typography_changed:
		return
	_last_paint = paint
	queue_redraw()


func _refresh_controls() -> void:
	var mask: int = _state.get("control_mask", 0)
	var controls := [mask, _state.route, _state.route_locked, _state.ended]
	if controls == _last_controls:
		return
	_last_controls = controls
	var route: int = _state.route
	for index in _buttons.size():
		var button := _buttons[index]
		button.disabled = not action_available(index, _state)
		var selected := (index == DIRECT and route == Model.DIRECT) or (index == BYPASS and route == Model.BYPASS)
		button.set_pressed_no_signal(selected or bool(mask & (1 << index)))
	_buttons[DIRECT].text = "已選近巷 · A" if route == Model.DIRECT else LABELS[DIRECT]
	_buttons[BYPASS].text = "已選外側寬路 · D" if route == Model.BYPASS else LABELS[BYPASS]


func _draw() -> void:
	if _state.is_empty() or _font == null or not is_instance_valid(_stage):
		return
	var gate := _next_gate()
	var at_crosswalk := _crosswalk_near()
	_text(Vector2(35, 172), _guide(gate, at_crosswalk), CORAL if _state.blocked else GOLD, 22, BOARD.size.x)
	draw_rect(BOARD.grow(2), EDGE)
	draw_rect(BOARD, DEEP)
	draw_texture_rect(_stage.get_texture(), BOARD, false)
	_draw_readout(gate, at_crosswalk)


func _next_gate() -> Dictionary:
	var id: int = _state.clearance.gate_id
	if _state.block_id >= 0:
		id = _state.block_id
	return _state.gates[id] if id >= 0 and id < _state.gates.size() else {}


func _guide(gate: Dictionary, at_crosswalk: bool) -> String:
	if _state.block_kind == "person":
		return "行人正在過巷，先停等"
	if _state.blocked:
		return _gate_instruction(gate)
	if _state.braking:
		return "煞車減速中" if _state.speed > 0.025 else "已煞停，可調架高與側傾"
	if not _state.route_locked:
		return "近巷有窄口，外側寬路有低棚"
	if at_crosswalk:
		return "確認行人走開，再通過斑馬線"
	if not gate.is_empty() and _state.clearance.distance < 2.8:
		if _state.clearance.margin > 0.0:
			return "此角度可過檐，回正會碰到" if gate.kind == "roof" and gate.side != 0 and _state.clearance.neutral_margin < 0.0 else "可通過，保持目前姿態"
		return _gate_instruction(gate)
	if _state.challenge_proven:
		return "已交錯過檐，送達三幅就完成挑戰"
	return "推向攤尾，遇到障礙先煞停"


func _gate_instruction(gate: Dictionary) -> String:
	if gate.is_empty():
		return "停穩後再調整招幌"
	if gate.kind == "wall":
		return "窄口要先把招幌回正"
	match int(gate.side):
		-1:
			return "左側低檐 · 把招幌左側壓低"
		1:
			return "右側低檐 · 把招幌右側壓低"
	return "整排低棚 · 先降低架子"


func _gate_name(gate: Dictionary) -> String:
	if gate.kind == "wall":
		return "窄口"
	match int(gate.side):
		-1:
			return "左側低檐"
		1:
			return "右側低檐"
	return "整排低棚"


func _draw_readout(gate: Dictionary, at_crosswalk: bool) -> void:
	draw_rect(READOUT.grow(2), EDGE)
	draw_rect(READOUT, DEEP)
	var base := READOUT.position + Vector2(14, 0)
	var banner: Dictionary = _state.banners[_state.banner_index]
	_text(base + Vector2(0, 31), banner.name, INK, 24, 305)
	var route_name: String = _state.lanes[_state.route].name
	var route_status := "已入巷" if _state.route_locked else "可換路"
	_text(base + Vector2(0, 60), "%s  ·  %s" % [route_name, route_status], PALE, 18, 315)
	_draw_profile(gate)
	if at_crosswalk:
		var lane := _crosswalk_bounds()
		var crossing := _person_in_lane(lane)
		_draw_crosswalk(lane)
		_text(base + Vector2(0, 249), "斑馬線 · 行人在車道上" if crossing else "斑馬線 · 車道暫時空出",
			CORAL if crossing else MINT, 18, 315)
	elif not gate.is_empty():
		var clear: bool = _state.clearance.margin > 0.0
		var status := "可通過" if clear else "會碰到"
		if _state.blocked:
			status = "調整受阻" if clear else "擋住了"
		_text(base + Vector2(0, 249), "%s  ·  %s" % [_gate_name(gate), status],
			MINT if clear and not _state.blocked else CORAL, 20, 315)
		if _state.assisted:
			var margin: float = _state.clearance.margin
			var gap := maxi(1, roundi(absf(margin) * 100.0))
			var description := "餘隙" if margin > 0.0 else "重疊"
			var distance: float = _state.clearance.distance
			var detail := "%s %d cm" % [description, gap]
			if is_finite(distance):
				detail += " · 前方 %.1f m" % distance
			_text(base + Vector2(0, 278), detail, PALE, 17, 315)
	else:
		_text(base + Vector2(0, 249), "前方是攤尾", MINT, 20, 315)
	_text(base + Vector2(0, 307), _pose_line(), PALE, 17, 315)


func _pose_line() -> String:
	var roll: float = _state.roll
	var lift: float = _state.lift
	var side := "左側抬高" if roll < 0.0 else "右側抬高"
	var upright := absf(roll) < 0.035
	if _state.assisted:
		var height := "升架 %d cm" % roundi(lift * 100.0)
		var tilt := "回正" if upright else "%s %d°" % ["左抬" if roll < 0.0 else "右抬", roundi(rad_to_deg(absf(roll)))]
		return "%s  ·  %s" % [height, tilt]
	var height := "已降到底" if lift < 0.01 else "架子已抬高"
	return "%s  ·  %s" % [height, "已回正" if upright else side]


func _draw_profile(gate: Dictionary) -> void:
	draw_rect(PROFILE, PANEL)
	draw_rect(PROFILE, GRID, false, 1.0)
	for step in range(1, 5):
		var y := PROFILE_ORIGIN.y - float(step) * PROFILE_SCALE * 0.5
		draw_line(Vector2(PROFILE.position.x + 12, y), Vector2(PROFILE.end.x - 12, y), GRID, 1.0)
	draw_line(PROFILE_ORIGIN, Vector2(PROFILE_ORIGIN.x, PROFILE.position.y + 8.0), GRID, 1.0)
	if not gate.is_empty():
		var lane_x := _gate_lane_x(gate)
		if gate.kind == "wall":
			for wall: Dictionary in _state.gates:
				if wall.kind == "wall" and wall.route == gate.route:
					_draw_gate_profile(wall, lane_x)
		else:
			_draw_gate_profile(gate, lane_x)

	var cart_x: float = _state.cart.x
	var low: Vector3 = _state.carriage_min
	var high: Vector3 = _state.carriage_max
	var frame := Rect2(_profile_point(Vector3(low.x, high.y, 0), cart_x), Vector2(high.x - low.x, high.y - low.y) * PROFILE_SCALE)
	draw_rect(frame, Color("#465766"))
	draw_rect(frame, PALE, false, 1.3)
	var anchor := _profile_point(_state.pivot, cart_x)
	draw_line(Vector2(PROFILE_ORIGIN.x, frame.position.y), anchor, PALE, 2.0, true)
	var outline := PackedVector2Array()
	for corner: Vector3 in _state.canvas:
		outline.append(_profile_point(corner, cart_x))
	var cloth: Color = FABRICS[_state.banner_index]
	draw_colored_polygon(outline, Color(cloth, 0.30))
	outline.append(outline[0])
	draw_polyline(outline, cloth, 2.1, true)
	draw_circle(anchor, 3.1, INK, true, -1.0, true)


func _gate_lane_x(gate: Dictionary) -> float:
	var points: PackedVector3Array = _state.lanes[gate.route].points
	for index in range(1, points.size()):
		if gate.min.z <= points[index].z:
			var at := inverse_lerp(points[index - 1].z, points[index].z, gate.min.z)
			return lerpf(points[index - 1].x, points[index].x, at)
	return points[-1].x


func _draw_gate_profile(gate: Dictionary, lane_x: float) -> void:
	var low: Vector3 = gate.min
	var high: Vector3 = gate.max
	var size_px := Vector2(high.x - low.x, high.y - low.y) * PROFILE_SCALE
	var area := Rect2(_profile_point(Vector3(low.x, high.y, 0), lane_x), size_px)
	var tone := CORAL if int(_state.block_id) == int(gate.id) else COPPER
	draw_rect(area, Color(tone, 0.24))
	draw_rect(area, tone, false, 1.6)
	if gate.kind == "roof":
		for x in range(ceili(area.position.x + 6), floori(area.end.x - 2), 12):
			draw_line(Vector2(x - 3, area.end.y - 1), Vector2(x + 2, area.end.y - 8), tone, 1.3, true)


func _profile_point(point: Vector3, center_x: float) -> Vector2:
	return PROFILE_ORIGIN + Vector2(point.x - center_x, -point.y) * PROFILE_SCALE


func _crosswalk_near() -> bool:
	var distance: float = _state.pedestrian.position.z - _state.cart.z
	return _state.block_kind == "person" or (distance < 2.4 and distance > -0.88)


func _crosswalk_bounds() -> Vector2:
	var bounds := Vector2(_state.carriage_min.x, _state.carriage_max.x)
	var corners: PackedVector3Array = _state.canvas
	var height: float = _state.pedestrian.height
	for index in corners.size():
		var current := corners[index]
		var next := corners[(index + 1) % corners.size()]
		if current.y <= height:
			bounds.x = minf(bounds.x, current.x)
			bounds.y = maxf(bounds.y, current.x)
		if (current.y <= height) != (next.y <= height):
			var at := lerpf(current.x, next.x, inverse_lerp(current.y, next.y, height))
			bounds.x = minf(bounds.x, at)
			bounds.y = maxf(bounds.y, at)
	return bounds


func _person_in_lane(lane: Vector2) -> bool:
	var x: float = _state.pedestrian.position.x
	var radius: float = _state.pedestrian.radius
	return _state.block_kind == "person" or (x + radius >= lane.x and x - radius <= lane.y)


func _draw_crosswalk(lane: Vector2) -> void:
	var walker: Dictionary = _state.pedestrian
	var start := Vector2(940, 415)
	var finish := Vector2(1205, start.y)
	draw_line(start, finish, GRID, 4.0, true)
	var min_lane := start.lerp(finish, inverse_lerp(walker.min_x, walker.max_x, lane.x))
	var max_lane := start.lerp(finish, inverse_lerp(walker.min_x, walker.max_x, lane.y))
	draw_line(min_lane, max_lane, PALE, 4.0, true)
	for endpoint in [min_lane, max_lane]:
		draw_line(endpoint - Vector2(0, 5), endpoint + Vector2(0, 5), PALE, 1.5, true)
	var person := start.lerp(finish, inverse_lerp(walker.min_x, walker.max_x, walker.position.x))
	var diamond := PackedVector2Array([person + Vector2(0, -6), person + Vector2(6, 0),
		person + Vector2(0, 6), person + Vector2(-6, 0)])
	draw_colored_polygon(diamond, GOLD)


func _text(at: Vector2, value: String, color: Color, pixels: int, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(float(pixels) * _scale), color)
