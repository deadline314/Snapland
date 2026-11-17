extends RefCounted
class_name CookieMoldModel

const ROUND_SECONDS := 150.0
const SUBSTEP := 1.0 / 120.0
const PIVOT := Vector2(0, 2.8)
const TRAY_Y := -0.8
const TRAY_HALF_WIDTH := 1.15
const SHAPE_NAMES := ["五角星", "心形", "魚", "葉", "五瓣花", "雙層齒輪"]

var _s: Dictionary
var _catch_wait := 0.0
var _candidate := false

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_s = {"elapsed": 0.0, "remaining": ROUND_SECONDS, "score": 0, "mistakes": 0,
		"ended": false, "success": false, "devil": false, "ordinary_eligible": false,
		"participated": false, "assisted": assisted, "variant": posmod(variant, 2),
		"feedback": "先鬆黏角，再翻模滑接", "caught": 0,
		"completed": [false, false, false, false, false, false], "shape_index": 0,
		"double_layer_inertial_caught": false, "tray_x": 0.0, "tray_target": 0.0,
		"tray_y": TRAY_Y, "tray_half_width": TRAY_HALF_WIDTH,
		"catch_tolerance": 0.22 if assisted else 0.0, "helper": false,
		"crack_limit": 1.45 if assisted else 1.0, "pivot": PIVOT}
	_load_cookie()

func _polygon(index: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	match index:
		0:
			for i in 10:
				points.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * (0.56 if i % 2 == 0 else 0.25))
		1:
			points.assign([Vector2(0, -0.48), Vector2(0.22, -0.28), Vector2(0.43, -0.04), Vector2(0.51, 0.17), Vector2(0.46, 0.35), Vector2(0.31, 0.45), Vector2(0.14, 0.42), Vector2(0, 0.24), Vector2(-0.14, 0.42), Vector2(-0.31, 0.45), Vector2(-0.46, 0.35), Vector2(-0.51, 0.17), Vector2(-0.43, -0.04), Vector2(-0.22, -0.28)])
		2:
			points.assign([Vector2(-0.53, 0.30), Vector2(-0.27, 0.14), Vector2(-0.1, 0.31), Vector2(0.2, 0.36), Vector2(0.46, 0.19), Vector2(0.59, 0), Vector2(0.46, -0.19), Vector2(0.2, -0.36), Vector2(-0.1, -0.31), Vector2(-0.27, -0.14), Vector2(-0.53, -0.30), Vector2(-0.43, 0)])
		3:
			points.assign([Vector2(-0.55, -0.27), Vector2(-0.42, -0.31), Vector2(-0.15, -0.34), Vector2(0.15, -0.25), Vector2(0.39, -0.08), Vector2(0.55, 0.27), Vector2(0.29, 0.38), Vector2(0.04, 0.4), Vector2(-0.22, 0.29), Vector2(-0.4, 0.09)])
		4:
			for i in 30:
				var angle := TAU * i / 30.0
				points.append(Vector2.from_angle(angle) * (0.43 + 0.12 * cos(5.0 * angle)))
		5:
			for i in 32:
				points.append(Vector2.from_angle(TAU * (i + 0.5) / 32.0) * (0.55 if i % 4 < 2 else 0.41))
	if _s.variant == 1:
		var base := points.duplicate()
		for i in points.size():
			if _concave(base, i):
				points[i] *= 0.78
	return points

func _concave(points: Array, index: int) -> bool:
	var area := 0.0
	for i in points.size():
		area += Vector2(points[i]).cross(points[(i + 1) % points.size()])
	var previous: Vector2 = points[posmod(index - 1, points.size())]
	var current: Vector2 = points[index]
	var next: Vector2 = points[(index + 1) % points.size()]
	return (current - previous).cross(next - current) * area < 0

func _load_cookie() -> void:
	var index: int = _s.shape_index
	_s.shape_name = SHAPE_NAMES[index]
	_s.polygon = _polygon(index)
	_s.double_layer = index == 5
	var layer := 0.16 if _s.variant == 0 else 0.21
	_s.thickness = 2.0 * layer + 0.035 if _s.double_layer else layer
	_s.edges = []
	for i in _s.polygon.size():
		var notch := 1.0 if _concave(_s.polygon, i) or _concave(_s.polygon, (i + 1) % _s.polygon.size()) else 0.0
		_s.edges.append({"point": (Vector2(_s.polygon[i]) + Vector2(_s.polygon[(i + 1) % _s.polygon.size()])) * 0.5,
			"adhesion": 0.70 + 0.20 * notch, "stress": 0.0, "notch": notch})
	_s.phase = "molded"
	_s.mold_angle = 0.0
	_s.mold_omega = 0.0
	_s.mold_target = 0.0
	_s.mold_held = false
	_s.outlet = PIVOT + Vector2(0, 0.45)
	_s.selected_edge = 0
	_s.charging = false
	_s.charge = 0.0
	_s.cookie_position = _s.outlet
	_s.cookie_velocity = Vector2.ZERO
	_s.cookie_angle = 0.0
	_s.cookie_omega = 0.0
	_s.release_omega = 0.0
	_s.release_inertial = 0.0
	_s.release_gravity = 0.0
	_catch_wait = 0.0
	_candidate = false

func set_mold_target(angle: float) -> void:
	if _s.ended or _s.phase != "molded" or not is_finite(angle):
		return
	_s.mold_target = wrapf(angle, -PI, PI)
	_s.mold_held = true
	if absf(angle_difference(_s.mold_angle, _s.mold_target)) > 0.0001:
		_s.participated = true

func release_mold() -> void:
	if not _s.ended:
		_s.mold_held = false

func select_edge(direction: int) -> void:
	if _s.ended or _s.phase != "molded" or _s.charging or direction == 0:
		return
	_s.selected_edge = posmod(int(_s.selected_edge) + signi(direction), _s.edges.size())

func select_edge_at(local_point: Vector2) -> void:
	if _s.ended or _s.phase != "molded" or _s.charging or not local_point.is_finite() or local_point.length() > 1.0:
		return
	var nearest := INF
	for i in _s.edges.size():
		var gap := local_point.distance_squared_to(_s.edges[i].point)
		if gap < nearest:
			nearest = gap
			_s.selected_edge = i

func begin_tap() -> void:
	if not _s.ended and _s.phase == "molded" and not _s.charging:
		_s.charging = true
		_s.charge = 0.0

func release_tap() -> void:
	if _s.ended or _s.phase != "molded" or not _s.charging:
		return
	var force := 0.15 + 0.85 * clampf(float(_s.charge) / 0.9, 0, 1)
	var ratio: float = _s.thickness / 0.16
	var point: Vector2 = _s.edges[_s.selected_edge].point
	for edge in _s.edges:
		var weight := maxf(0, 1.0 - Vector2(edge.point).distance_to(point) / 0.95)
		edge.adhesion = maxf(0, float(edge.adhesion) - 0.78 * force * weight / ratio)
		edge.stress = minf(_s.crack_limit, float(edge.stress) + 0.40 * force * force * weight * (1.0 + 0.6 * float(edge.notch)) * (1.0 + 0.65 * maxf(0, cos(_s.mold_angle))) / (ratio * ratio))
	_s.charging = false
	_s.charge = 0.0
	_s.participated = true
	_check_crack()

func set_tray_target(x: float) -> void:
	if _s.ended or not is_finite(x):
		return
	_s.tray_target = clampf(x, -3.2, 3.2)
	_s.helper = false
	if absf(float(_s.tray_target) - float(_s.tray_x)) > 0.0001:
		_s.participated = true

func toggle_helper() -> void:
	if not _s.ended:
		_s.helper = not _s.helper

func retry_cookie() -> void:
	if not _s.ended and _s.phase in ["cracked", "missed"]:
		_load_cookie()
		_s.feedback = "免費重做：先鬆黏角，再翻模滑接"

func clear_input() -> void:
	_s.mold_held = false
	_s.charging = false
	_s.charge = 0.0

func step(delta: float) -> void:
	if _s.ended or not is_finite(delta) or delta <= 0:
		return
	var bounded := minf(delta, 0.25)
	var count := mini(30, ceili(bounded / SUBSTEP))
	for i in count:
		if _s.ended:
			break
		_substep(bounded / count)

func _substep(h: float) -> void:
	h = minf(h, ROUND_SECONDS - float(_s.elapsed))
	_s.elapsed = minf(ROUND_SECONDS, float(_s.elapsed) + h)
	_s.remaining = maxf(0, ROUND_SECONDS - float(_s.elapsed))
	if _s.charging:
		_s.charge = minf(0.9, float(_s.charge) + h)
	var alpha := clampf(28.0 * angle_difference(_s.mold_angle, _s.mold_target) - 7.0 * float(_s.mold_omega), -22, 22) if _s.mold_held else -1.2 * float(_s.mold_omega)
	_s.mold_omega = clampf(float(_s.mold_omega) + alpha * h, -5, 5)
	_s.mold_angle = wrapf(float(_s.mold_angle) + float(_s.mold_omega) * h, -PI, PI)
	var normal := Vector2(sin(_s.mold_angle), cos(_s.mold_angle))
	var tangent := Vector2(normal.y, -normal.x)
	_s.outlet = PIVOT + 0.45 * normal
	var old_tray: float = _s.tray_x
	if _s.helper:
		_s.tray_target = _s.outlet.x
	_s.tray_x = move_toward(float(_s.tray_x), float(_s.tray_target), 4.0 * h)
	if _s.phase == "molded":
		_s.cookie_position = _s.outlet
		_s.cookie_angle = _s.mold_angle
		_s.cookie_omega = _s.mold_omega
		var gravity := maxf(0, -7.5 * normal.y)
		var inertia: float = _s.mold_omega * _s.mold_omega * 0.45
		var pull := gravity + inertia
		var ratio: float = _s.thickness / 0.16
		var loose := true
		for edge in _s.edges:
			var excess := maxf(0, pull - 12.0 * float(edge.adhesion) * (1.0 + 0.35 * float(edge.notch)) * ratio)
			edge.adhesion = maxf(0, float(edge.adhesion) - 0.20 * excess * h)
			edge.stress = minf(_s.crack_limit, float(edge.stress) + 0.012 * excess * (1.0 + float(edge.notch)) * h / (ratio * ratio))
			loose = loose and edge.adhesion <= 0.03
		_check_crack()
		if _s.phase == "molded" and loose and normal.y < -0.15:
			_s.phase = "flying"
			_s.cookie_velocity = 0.45 * float(_s.mold_omega) * tangent + normal * clampf(0.08 * pull, 0.25, 1.1)
			_s.release_omega = _s.mold_omega
			_s.release_inertial = inertia
			_s.release_gravity = gravity
			_candidate = _s.double_layer and absf(_s.release_omega) >= 2.0 and inertia >= 0.35 * gravity
			clear_input()
			_s.feedback = "滑動接盤，完整接住餅乾"
	if _s.phase == "flying":
		_fly(h, old_tray)
	elif _s.phase == "caught" and not _s.ended:
		_catch_wait += h
		if _catch_wait >= 0.45:
			_s.shape_index += 1
			_load_cookie()
	if _s.remaining <= 0 and not _s.ended:
		_finish(false)

func _check_crack() -> void:
	for edge in _s.edges:
		if edge.stress >= _s.crack_limit:
			_fail("cracked", "裂餅了，免費重做；換一角輕敲")
			return
		if edge.stress >= 0.65 * float(_s.crack_limit):
			_s.feedback = "裂紋加深了，換一角輕敲"

func _bounds(position: Vector2, angle: float) -> Rect2:
	var normal := Vector2(sin(angle), cos(angle))
	var tangent := Vector2(normal.y, -normal.x)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for vertex in _s.polygon:
		for side in [-0.5, 0.5]:
			var point: Vector2 = position + float(vertex.x) * tangent + side * float(_s.thickness) * normal
			low = low.min(point)
			high = high.max(point)
	return Rect2(low, high - low)

func _fly(h: float, old_tray: float) -> void:
	var old_position: Vector2 = _s.cookie_position
	var old_angle: float = _s.cookie_angle
	var old_bottom := _bounds(old_position, old_angle).position.y
	_s.cookie_velocity.y -= 7.5 * h
	_s.cookie_position += _s.cookie_velocity * h
	_s.cookie_angle += float(_s.cookie_omega) * h
	var bottom := _bounds(_s.cookie_position, _s.cookie_angle).position.y
	if old_bottom >= TRAY_Y and bottom < TRAY_Y and _s.cookie_velocity.y < 0:
		var fraction := (old_bottom - TRAY_Y) / (old_bottom - bottom)
		var bounds := _bounds(old_position.lerp(_s.cookie_position, fraction), lerpf(old_angle, _s.cookie_angle, fraction))
		var tray := lerpf(old_tray, _s.tray_x, fraction)
		var half: float = TRAY_HALF_WIDTH + _s.catch_tolerance
		var depth_fits := true
		for vertex in _s.polygon:
			depth_fits = depth_fits and absf(vertex.y) <= 0.85
		if bounds.position.x >= tray - half and bounds.end.x <= tray + half and depth_fits:
			_s.cookie_position = old_position.lerp(_s.cookie_position, fraction)
			_s.cookie_angle = lerpf(old_angle, _s.cookie_angle, fraction)
			_s.cookie_velocity = Vector2.ZERO
			_s.phase = "caught"
			_s.completed[_s.shape_index] = true
			_s.caught += 1
			if _candidate:
				_s.double_layer_inertial_caught = true
			_s.feedback = "完整接住 %d／6" % _s.caught
			_refresh_score()
			if _s.caught == 6:
				_finish(true)
			return
	if _s.cookie_position.y < -2.4 or absf(_s.cookie_position.x) > 6:
		_fail("missed", "餅乾掉了，免費重做")

func _fail(phase: String, feedback: String) -> void:
	if _s.phase in ["cracked", "missed"]:
		return
	_s.phase = phase
	_s.feedback = feedback
	_s.mistakes += 1
	_candidate = false
	clear_input()
	_refresh_score()

func _finish(success: bool) -> void:
	_s.ended = true
	_s.success = success
	_s.devil = success and _s.double_layer_inertial_caught
	_s.ordinary_eligible = _s.participated
	clear_input()
	_refresh_score()

func _refresh_score() -> void:
	_s.score = maxi(0, 100 * int(_s.caught) + (100 if _s.success else 0) + (100 if _s.devil else 0) - 20 * int(_s.mistakes))

func snapshot() -> Dictionary:
	return _s.duplicate(true)
