extends RefCounted
class_name SugarBridgeModel

const ROUND_SECONDS := 150.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const BOUNDS := Rect2(-3, -3, 15, 8)
const VOLUME := 4.0
const CAPACITY_GAIN := 5.5
const MAX_LENGTH := 10.5
const GRAVITY := 4.8
const BALL_SPEED := 1.6
const FEED_GAP := 0.45
const STARTS := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, -2), Vector2(3, -2)]
const LAYOUTS := [
	{"name": "原味糖帶", "spacing": 4.0, "weight": 0.85, "elasticity": 1.0},
	{"name": "彈韌糖帶", "spacing": 4.4, "weight": 0.95, "elasticity": 1.12},
]

var _assisted := false
var _variant := 0
var _anchors: Array[Vector2] = []
var _endpoints: Array[Dictionary] = []
var _endpoint_velocities: Array[float] = []
var _bands: Array[Dictionary] = []
var _balls: Array[Dictionary] = []
var _bean: Dictionary = {}
var _helper: Array[bool] = []
var _selected := 0
var _grabbed := -1
var _elapsed := 0.0
var _falls := 0
var _breaks := 0
var _participated := false
var _ended := false
var _success := false
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, LAYOUTS.size())
	var spacing: float = LAYOUTS[_variant].spacing
	_anchors = [Vector2.ZERO, Vector2(spacing, 0), Vector2(spacing * 2, 0)]
	_endpoints.clear()
	_endpoint_velocities = [0.0, 0.0, 0.0, 0.0]
	_bands.clear()
	_balls.clear()
	_helper = [false, false, false, false]
	for id in 4:
		_endpoints.append({"id": id, "band": id / 2, "position": STARTS[id], "pin": -1})
	for id in 2:
		_bands.append({"id": id, "generation": 0, "broken": false, "hit": false})
	for id in 3:
		_balls.append({"id": id, "state": "unused", "position": Vector2(-0.3, 0.14), "velocity": Vector2.ZERO,
			"band": -1, "progress": 0.0, "traversed": [-1, -1]})
	_bean = {"active": false, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "band": -1, "generation": -1, "hit": false}
	_selected = 0
	_grabbed = -1
	_elapsed = 0.0
	_falls = 0
	_breaks = 0
	_participated = false
	_ended = false
	_success = false
	_feedback = "抓兩端拉糖搭橋；每次上料一球，長橋宜逐球"

func select_next(direction: int) -> void:
	if _ended or direction == 0:
		return
	clear_input()
	_selected = posmod(_selected + signi(direction), 4)

func grab_selected() -> void:
	if _ended or _bands[_selected / 2].broken:
		return
	_grabbed = _selected
	_endpoint_velocities[_selected] = 0.0
	_endpoints[_selected].pin = -1
	_helper[_selected] = false

func move_selected(position: Vector2) -> void:
	if _ended or _grabbed != _selected or not position.is_finite():
		return
	var bounded := position.clamp(BOUNDS.position, BOUNDS.end)
	if bounded != _endpoints[_selected].position:
		_participated = true
	_endpoints[_selected].position = bounded
	_endpoint_velocities[_selected] = 0.0

func _near_anchor(position: Vector2) -> int:
	var nearest := -1
	var distance := 0.75 if _assisted else 0.5
	for index in _anchors.size():
		var gap := position.distance_to(_anchors[index])
		if gap <= distance:
			nearest = index
			distance = gap
	return nearest

func _pin_selected(anchor: int) -> void:
	_endpoints[_selected].pin = anchor
	_endpoints[_selected].position = _anchors[anchor]
	_endpoint_velocities[_selected] = 0.0
	_grabbed = -1
	_helper[_selected] = false
	_participated = true
	_feedback = "糖帶固定在%s" % ["左岸", "中央承台", "右岸"][anchor]

func release_selected() -> void:
	if _ended or _grabbed != _selected:
		return
	var anchor := _near_anchor(_endpoints[_selected].position)
	if anchor >= 0:
		_pin_selected(anchor)
		return
	_grabbed = -1
	var other: Dictionary = _endpoints[_selected ^ 1]
	var position: Vector2 = _endpoints[_selected].position
	if other.pin >= 0 and position.distance_to(other.position) >= 0.25:
		var band: int = _selected / 2
		_bean = {"active": true, "position": position,
			"velocity": (Vector2(other.position) - position) * 4.0 * float(LAYOUTS[_variant].elasticity),
			"band": band, "generation": _bands[band].generation, "hit": false}
		_participated = true
		_feedback = "試料豆彈出；命中後用同條糖帶運送"

func toggle_pin() -> void:
	if _ended or _bands[_selected / 2].broken:
		return
	if _endpoints[_selected].pin >= 0:
		_endpoints[_selected].pin = -1
		_feedback = "鬆開端點，抓住後拖曳"
		return
	var anchor := _near_anchor(_endpoints[_selected].position)
	if anchor >= 0:
		_pin_selected(anchor)
	else:
		_feedback = "靠近支點再固定"

func _renew_band(id: int) -> void:
	# Clear all old references before a bounded generation counter can wrap.
	_bands[id].generation = (int(_bands[id].generation) + 1) % 1000000000
	_bands[id].hit = false
	for ball in _balls:
		ball.traversed[id] = -1
	if _bean.band == id:
		_bean.active = false
		_bean.hit = false

func recall_selected() -> void:
	if _ended:
		return
	var id: int = _selected / 2
	for ball in _balls:
		if ball.state == "rolling" and ball.band == id:
			_fall(ball)
	_renew_band(id)
	_bands[id].broken = false
	for endpoint in range(id * 2, id * 2 + 2):
		_endpoints[endpoint].position = STARTS[endpoint]
		_endpoints[endpoint].pin = -1
		_endpoint_velocities[endpoint] = 0.0
		_helper[endpoint] = false
	clear_input()
	_feedback = "免費回收糖帶；先彈後橋紀錄清除"

func cycle_helper() -> void:
	if _ended:
		return
	_helper[_selected] = not _helper[_selected]
	_endpoint_velocities[_selected] = 0.0
	if _grabbed == _selected:
		_grabbed = -1
	_feedback = "AI %s所選端點；固定、彈射與上料由你決定" % ("保持" if _helper[_selected] else "放開")

func clear_input() -> void:
	_grabbed = -1

func _connected(id: int) -> bool:
	var a: Dictionary = _endpoints[id * 2]
	var b: Dictionary = _endpoints[id * 2 + 1]
	return not _bands[id].broken and a.pin >= 0 and b.pin >= 0 and a.pin != b.pin

func _length(id: int) -> float:
	return Vector2(_endpoints[id * 2].position).distance_to(_endpoints[id * 2 + 1].position)

func _capacity(id: int) -> float:
	return CAPACITY_GAIN * pow(VOLUME / maxf(0.25, _length(id)), 2) * float(LAYOUTS[_variant].elasticity)

func _load(id: int) -> float:
	var total := 0.0
	for ball in _balls:
		if ball.state == "rolling" and ball.band == id:
			total += float(LAYOUTS[_variant].weight)
	return total

func _sag(id: int) -> float:
	return _length(id) * (0.025 + 0.1 * _load(id) / _capacity(id)) / float(LAYOUTS[_variant].elasticity)

func _ends(id: int) -> Array:
	var a: Vector2 = _endpoints[id * 2].position
	var b: Vector2 = _endpoints[id * 2 + 1].position
	return [a, b] if a.x <= b.x else [b, a]

func _curve(id: int, progress: float) -> Vector2:
	var ends := _ends(id)
	return Vector2(ends[0]).lerp(ends[1], progress) + Vector2(0, -4.0 * _sag(id) * progress * (1.0 - progress))

func _outgoing(anchor: int) -> int:
	for id in 2:
		if not _connected(id):
			continue
		var a: int = _endpoints[id * 2].pin
		var b: int = _endpoints[id * 2 + 1].pin
		if mini(a, b) == anchor:
			return id
	return -1

func load_ball() -> void:
	if _ended:
		return
	var candidate: Dictionary = {}
	for desired in ["unused", "fallen"]:
		for ball in _balls:
			if ball.state == desired:
				candidate = ball
				break
		if not candidate.is_empty():
			break
	if candidate.is_empty():
		_feedback = "三顆球都在運送或已送達；落球後可重送"
		return
	_participated = true
	var feed_x := -FEED_GAP
	for ball in _balls:
		if ball.state == "queued":
			feed_x = minf(feed_x, float(ball.position.x) - FEED_GAP)
	candidate.state = "queued"
	candidate.band = -1
	candidate.progress = 0.0
	candidate.position = Vector2(feed_x, 0.14)
	candidate.velocity = Vector2(BALL_SPEED, 0)
	candidate.traversed = [-1, -1]
	_feedback = "上料一球；留意糖帶承重"

func _fall(ball: Dictionary) -> void:
	ball.state = "falling"
	ball.band = -1
	ball.velocity = Vector2(0.35, 0)
	_falls += 1
	_feedback = "運料球落下，可免費重送"

func _break_band(id: int) -> void:
	_bands[id].broken = true
	_breaks += 1
	_renew_band(id)
	for endpoint in range(id * 2, id * 2 + 2):
		_endpoints[endpoint].pin = -1
		_helper[endpoint] = false
	if _grabbed / 2 == id and _grabbed >= 0:
		clear_input()
	for ball in _balls:
		if ball.state == "rolling" and ball.band == id:
			_fall(ball)
	_feedback = "糖帶拉斷或超載；回收後重搭"

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, SUBSTEP)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	for id in 4:
		if _endpoints[id].pin >= 0 or _grabbed == id or _helper[id]:
			continue
		var position: Vector2 = _endpoints[id].position
		position.y = maxf(BOUNDS.position.y, position.y + _endpoint_velocities[id] * dt - 0.5 * GRAVITY * dt * dt)
		_endpoint_velocities[id] = 0.0 if position.y <= BOUNDS.position.y else _endpoint_velocities[id] - GRAVITY * dt
		_endpoints[id].position = position
	for id in 2:
		if not _bands[id].broken and (_length(id) > MAX_LENGTH or _load(id) > _capacity(id)):
			_break_band(id)
	_step_bean(dt)
	for ball in _balls:
		if ball.state == "queued":
			ball.position.x = minf(0.0, float(ball.position.x) + BALL_SPEED * dt)
			if ball.position.x >= 0.0:
				ball.band = _outgoing(0)
				ball.state = "rolling"
				ball.velocity = Vector2.ZERO
				if ball.band < 0:
					_fall(ball)
		elif ball.state == "falling":
			ball.position += ball.velocity * dt + Vector2(0, -GRAVITY * dt * dt * 0.5)
			ball.velocity.y -= GRAVITY * dt
			if ball.position.y < BOUNDS.position.y - 0.5:
				ball.state = "fallen"
		elif ball.state == "rolling":
			_step_ball(ball, dt)
	if _delivered() == 3:
		_success = true
		_ended = true
		_feedback = "三顆運料球全部送達"
	elif _elapsed >= ROUND_SECONDS:
		_ended = true
		_feedback = "時間到：送達 %d / 3 球" % _delivered()
	if _ended:
		clear_input()

func _step_ball(ball: Dictionary, dt: float) -> void:
	var id: int = ball.band
	if id < 0 or not _connected(id):
		_fall(ball)
		return
	var length := maxf(0.25, _length(id))
	var slope := -4.0 * _sag(id) * (1.0 - 2.0 * float(ball.progress)) / length
	var speed := clampf(BALL_SPEED - slope * 0.45, 0.65, 2.4)
	ball.progress = minf(1.0, float(ball.progress) + dt * speed / (length * sqrt(1.0 + slope * slope)))
	ball.position = _curve(id, ball.progress) + Vector2(0, 0.14)
	if _bands[id].hit and ball.progress > 0.05:
		ball.traversed[id] = _bands[id].generation
	if ball.progress < 1.0:
		return
	var arrival := maxi(int(_endpoints[id * 2].pin), int(_endpoints[id * 2 + 1].pin))
	if arrival == 2:
		ball.state = "delivered"
		ball.band = -1
		_feedback = "運料球送達右岸"
	else:
		ball.band = _outgoing(arrival)
		ball.progress = 0.0
		if ball.band < 0:
			_fall(ball)

func _step_bean(dt: float) -> void:
	if not _bean.active:
		return
	var before: Vector2 = _bean.position
	var after: Vector2 = before + Vector2(_bean.velocity) * dt + Vector2(0, -GRAVITY * dt * dt * 0.5)
	_bean.position = after
	_bean.velocity.y -= GRAVITY * dt
	var closest := Geometry2D.get_closest_point_to_segment(_hopper(), before, after)
	if closest.distance_to(_hopper()) <= _hopper_radius():
		_bean.hit = true
		_bean.active = false
		var id: int = _bean.band
		if _bands[id].generation == _bean.generation and not _bands[id].broken:
			_bands[id].hit = true
			_feedback = "命中料斗！用同條糖帶實際運送才算先彈後橋"
	elif not BOUNDS.grow(2.0).has_point(after):
		_bean.active = false

func _hopper() -> Vector2:
	return Vector2(float(LAYOUTS[_variant].spacing) * 0.6, 1.8)

func _hopper_radius() -> float:
	return 0.65 if _assisted else 0.45

func _delivered() -> int:
	var count := 0
	for ball in _balls:
		if ball.state == "delivered":
			count += 1
	return count

func _devil() -> bool:
	if not _success:
		return false
	for id in 2:
		if not _bands[id].hit:
			continue
		for ball in _balls:
			if ball.state == "delivered" and ball.traversed[id] == _bands[id].generation:
				return true
	return false

func _preview() -> Array:
	var points: Array = []
	if _grabbed < 0 or _endpoints[_grabbed ^ 1].pin < 0:
		return points
	var position: Vector2 = _endpoints[_grabbed].position
	var velocity: Vector2 = (Vector2(_endpoints[_grabbed ^ 1].position) - position) * 4.0 * float(LAYOUTS[_variant].elasticity)
	for index in 31:
		var t := index * 0.05
		points.append(position + velocity * t + Vector2(0, -0.5 * GRAVITY * t * t))
	return points

func snapshot() -> Dictionary:
	var bands := _bands.duplicate(true)
	for id in 2:
		bands[id].length = _length(id)
		bands[id].thickness = VOLUME / maxf(0.25, _length(id))
		bands[id].capacity = _capacity(id)
		bands[id].load = _load(id)
		bands[id].sag = _sag(id)
		bands[id].connected = _connected(id)
		bands[id].points = []
		for index in 17:
			bands[id].points.append(_curve(id, index / 16.0))
	var endpoints := _endpoints.duplicate(true)
	for endpoint in endpoints:
		endpoint.held = _helper[endpoint.id] or _grabbed == endpoint.id
	var delivered := _delivered()
	var devil := _devil()
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": LAYOUTS[_variant].name,
		"elapsed": _elapsed, "remaining": maxf(0, ROUND_SECONDS - _elapsed), "ended": _ended,
		"success": _success, "devil": devil, "devil_success": devil, "ordinary_eligible": _ended and _participated,
		"score": maxi(0, delivered * 100 + (100 if _success else 0) + (100 if devil else 0) - (_falls + _breaks) * 20),
		"mistakes": _falls + _breaks, "falls": _falls, "breaks": _breaks, "delivered": delivered,
		"selected": _selected, "grabbed": _grabbed, "helper": _helper.duplicate(), "participated": _participated,
		"anchors": _anchors.duplicate(), "endpoints": endpoints, "bands": bands, "balls": _balls.duplicate(true),
		"bean": _bean.duplicate(true), "preview": _preview(), "hopper": _hopper(), "hopper_radius": _hopper_radius(),
		"weight": LAYOUTS[_variant].weight, "elasticity": LAYOUTS[_variant].elasticity, "bounds": BOUNDS,
		"feedback": _feedback, "last_event": _feedback,
	}
