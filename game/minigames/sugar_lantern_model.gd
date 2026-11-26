extends RefCounted

const BODY_POINTS := 450
const TAIL_POINTS := 150
const HOLD_SECONDS := 2.18
const RISE_SECONDS := 0.88
const ROUND_SECONDS := 105.0
const ASSISTED_SECONDS := 145.0
const SUGAR_MAX := 44
const TAIL_ANCHOR := 7
const TAIL_HINGE := 8
const TAIL_TIP := 9
const CURE_READY := 0.86
const POUR_HEAT := 0.34

const _PEG_COUNT := 11
const _ROW := _PEG_COUNT + 2
const _BODY_MASK := 0xff
const _MAX_LENGTH := 0.55
const _TICK := 1.0 / 60.0
const _REWARM_TIME := 0.95
const _OVERLOAD_TIME := 0.075
const _TAIL_SWAY := 0.27
const _MASS := [0.0, 0.14, 0.10, 0.16, 0.23, 0.21, 0.20, 0.24, 0.04, 0.07, 0.08]
const _LAYOUTS := [
	{"name": "長耳狐", "void_center": Vector2(0.50, 0.605), "void_radii": Vector2(0.098, 0.101),
		"pegs": [Vector2(0.46, 0.13), Vector2(0.26, 0.14), Vector2(0.16, 0.32), Vector2(0.11, 0.48),
			Vector2(0.34, 0.51), Vector2(0.28, 0.78), Vector2(0.51, 0.77), Vector2(0.68, 0.57),
			Vector2(0.78, 0.50), Vector2(0.91, 0.62), Vector2(0.49, 0.39)]},
	{"name": "林間鹿", "void_center": Vector2(0.485, 0.585), "void_radii": Vector2(0.097, 0.092),
		"pegs": [Vector2(0.48, 0.13), Vector2(0.67, 0.16), Vector2(0.71, 0.31), Vector2(0.84, 0.40),
			Vector2(0.64, 0.51), Vector2(0.66, 0.81), Vector2(0.43, 0.75), Vector2(0.27, 0.56),
			Vector2(0.19, 0.48), Vector2(0.08, 0.63), Vector2(0.47, 0.38)]},
]

class Strand:
	var a: int
	var b: int
	var length: float
	var thickness: float
	var cure := 0.0
	var adhesion: float
	var stress := 0.0
	var cracked := false
	var weight_load := 0.0
	var swing_load := 0.0
	var stress_factor := 0.0

var _layout := 0
var _assisted := false
var _pegs := PackedVector2Array()
var _void_center := Vector2.ZERO
var _void_radii := Vector2.ONE
var _edges: Array[Strand] = []
var _draw_edges: Array[Dictionary] = []
var _edges_changed := true
var _edge_indices := PackedInt32Array()
var _linked := 0
var _present := 0
var _wet := 0
var _cooling := 0
var _joined := false
var _tail_ready := false
var _matrix := PackedFloat64Array()
var _weight := PackedFloat64Array()

var _sugar := SUGAR_MAX
var _heat := 1.0
var _rewarm_left := 0.0
var _elapsed := 0.0
var _reserve_time := 0.0
var _lift_held := false
var _lifting := false
var _lift_time := 0.0
var _lift_height := 0.0
var _failed_edge := -1
var _overload_edge := -1
var _overload_seconds := 0.0
var _tail_angle := 0.0
var _tail_velocity := 0.0
var _tail_rest := 0.0
var _tail_stiffness := 0.0
var _tail_low := 0.0
var _tail_high := 0.0
var _tail_peak_speed := 0.0
var _tail_proven := false
var _tail_safe := true
var _engaged := false
var _ordinary := false
var _mistakes := 0
var _ended := false
var _success := false
var _score := 0
var _feedback := "先用糖線接起支架上的獸身。"


func _init() -> void:
	_edge_indices.resize(_PEG_COUNT * _PEG_COUNT)
	_matrix.resize(_PEG_COUNT * _ROW)
	_weight.resize(_PEG_COUNT)
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, _LAYOUTS.size())
	var drawing: Dictionary = _LAYOUTS[_layout]
	_pegs = PackedVector2Array(drawing.pegs)
	_void_center = drawing.void_center
	_void_radii = drawing.void_radii
	_edges.clear()
	_edges_changed = true
	_tail_rest = Vector2.DOWN.angle_to(_pegs[TAIL_TIP] - _pegs[TAIL_ANCHOR])
	_edge_indices.fill(-1)
	_linked = 1
	_present = 0
	_wet = 0
	_cooling = 0
	_joined = false
	_tail_ready = false
	_sugar = SUGAR_MAX
	_heat = 1.0
	_rewarm_left = 0.0
	_elapsed = 0.0
	_reserve_time = 0.0
	_lift_held = false
	_failed_edge = -1
	_tail_proven = false
	_engaged = false
	_ordinary = false
	_mistakes = 0
	_ended = false
	_success = false
	_score = 0
	_reset_lift()
	_feedback = "從頂端吊扣接起獸身；雙線可分擔重量。"


func place_strand(a: int, b: int, doubled: bool = false) -> bool:
	if _ended or _lifting:
		return false
	if a < 0 or a >= _PEG_COUNT or b < 0 or b >= _PEG_COUNT or a == b:
		return _refuse("選兩個不同的接點。")
	if _rewarm_left > 0.0 or _heat < POUR_HEAT:
		return _refuse("糖漿太涼，回熱後才能牽線。")
	var key := _key(a, b)
	var index := _edge_indices[key]
	var edge: Strand = _edges[index] if index >= 0 else null
	var length := _pegs[a].distance_to(_pegs[b])
	if edge == null or edge.cracked:
		if not _can_draw(a, b, length):
			return false
	if edge != null and not edge.cracked and edge.thickness >= 2.0:
		return _refuse("這段已是雙線，可試著從別處分重。")
	if edge != null and edge.cracked and _heat < 0.64:
		return _refuse("裂口需要較熱的糖漿，先回熱。")
	var reinforcement := edge != null and not edge.cracked
	var thickness := 2.0 if doubled or reinforcement else 1.0
	var cost := maxi(1, ceili(length * 11.5)) * (2 if doubled and not reinforcement else 1)
	if _sugar < cost:
		return _refuse("糖量不足，回熱可補糖。" if _assisted else "剩糖不夠牽這一段。")
	_sugar -= cost
	if edge == null:
		edge = Strand.new()
		edge.a = mini(a, b)
		edge.b = maxi(a, b)
		edge.length = length
		index = _edges.size()
		_edge_indices[key] = index
		_edges.append(edge)
	var was_cracked := edge.cracked
	edge.cracked = false
	edge.cure = 0.0
	edge.stress = 0.0
	edge.thickness = thickness
	edge.adhesion = lerpf(0.77, 1.0, smoothstep(POUR_HEAT, 0.92, _heat))
	_edges_changed = true
	if _failed_edge == index:
		_failed_edge = -1
	_engaged = true
	_scan_structure()
	if was_cracked:
		_feedback = "裂口已補接，等糖線凝住。"
	elif reinforcement:
		_feedback = "已保留原接點並加成雙線。"
	elif _tail_ready and (a >= TAIL_HINGE and a <= TAIL_TIP or b >= TAIL_HINGE and b <= TAIL_TIP):
		_feedback = "尾巴接好了；提起時看它能否擺動。"
	elif _joined:
		_feedback = "獸身接齊了；等糖面凝出紋路。"
	else:
		_feedback = "糖線已接上；還要連到吊扣。"
	return true


func _can_draw(a: int, b: int, length: float) -> bool:
	if length > _MAX_LENGTH:
		return _refuse("這段太長，到中間的支架點分兩段。")
	var tail_a := a in [TAIL_HINGE, TAIL_TIP]
	var tail_b := b in [TAIL_HINGE, TAIL_TIP]
	if (tail_a or tail_b) and _key(a, b) not in [_key(TAIL_ANCHOR, TAIL_HINGE), _key(TAIL_HINGE, TAIL_TIP)]:
		return _refuse("活動尾巴由尾根、轉點接到尾尖。")
	var from := _pegs[a]
	var to := _pegs[b]
	var void_a := (from - _void_center) / _void_radii
	var void_b := (to - _void_center) / _void_radii
	if Geometry2D.get_closest_point_to_segment(Vector2.ZERO, void_a, void_b).length_squared() < 1.0:
		return _refuse("腹部要留空，從空洞旁繞線。")
	for peg in _PEG_COUNT:
		if peg != a and peg != b and Geometry2D.get_closest_point_to_segment(_pegs[peg], from, to).distance_squared_to(_pegs[peg]) < 0.00052:
			return _refuse("經過支架點時要分段接合。")
	for line in _edges:
		if line.cracked or line.a in [a, b] or line.b in [a, b]:
			continue
		if Geometry2D.segment_intersects_segment(from, to, _pegs[line.a], _pegs[line.b]) != null:
			return _refuse("糖線相交會黏在一起，請從支架點繞開。")
	return true


func rewarm() -> bool:
	if _ended or _lifting or _rewarm_left > 0.0:
		return false
	_rewarm_left = _REWARM_TIME
	_feedback = "糖漿回熱中；已牽好的線繼續凝固。"
	return true


func set_lift(held: bool) -> void:
	if _ended or _lift_held == held:
		return
	_lift_held = held
	if not held:
		if _lifting:
			_reset_lift()
			_feedback = "已放回銅板；再按住可重新提起。"
		return
	if _rewarm_left > 0.0:
		_feedback = "糖漿回熱中，等一下再提。"
	elif not _joined:
		_feedback = "還有獸形接點沒連到吊扣。"
	elif _wet > 0:
		_feedback = "接點還沒凝固，等紋路出現再提。"
	else:
		_reset_lift()
		_solve_loads()
		_lifting = true
		_ordinary = true
		_feedback = "穩穩按住，留意糖線受力。"


func clear_input() -> void:
	set_lift(false)


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_reserve_time += minf(delta, 0.25)
	while _reserve_time + 0.000001 >= _TICK and not _ended:
		_reserve_time = maxf(0.0, _reserve_time - _TICK)
		_tick()


func _tick() -> void:
	_elapsed += _TICK
	if _rewarm_left > 0.0:
		_heat = lerpf(_heat, 1.0, minf(1.0, _TICK / _rewarm_left))
		_rewarm_left = maxf(0.0, _rewarm_left - _TICK)
		if _rewarm_left <= 0.00001:
			_rewarm_left = 0.0
			_heat = 1.0
			if _assisted:
				_sugar = SUGAR_MAX
			_feedback = "糖漿已回熱並續滿。" if _assisted else "糖漿已回熱，可以牽線或補裂口。"
	else:
		_heat = maxf(0.13, _heat - _TICK * (0.011 if _assisted else 0.017))
	var was_wet := _wet > 0
	if _cooling > 0 and not _lifting:
		_edges_changed = true
		for edge in _edges:
			if edge.cracked or edge.cure >= 1.0:
				continue
			var previous := edge.cure
			edge.cure = minf(1.0, previous + _TICK * (0.67 if edge.thickness == 1.0 else 0.54))
			if previous < CURE_READY and edge.cure >= CURE_READY:
				_wet -= 1
			_cooling -= int(edge.cure >= 1.0)
	if was_wet and _wet == 0 and _joined and _rewarm_left <= 0.0:
			_feedback = "糖線凝固了；按住提起測重量。"
	if _lifting:
		_lift_tick()
	if not _ended and _elapsed >= _duration() - 0.00001:
		_reset_lift()
		_lift_held = false
		_ended = true
		_feedback = "這回合結束。可換走線再試。"


func _scan_structure() -> void:
	_present = 0
	_wet = 0
	_cooling = 0
	for edge in _edges:
		if not edge.cracked:
			_present |= (1 << edge.a) | (1 << edge.b)
			_wet += int(edge.cure < CURE_READY)
			_cooling += int(edge.cure < 1.0)
	_linked = 1
	for pass_index in _PEG_COUNT - 1:
		var seen := _linked
		for edge in _edges:
			if not edge.cracked:
				var ends := (1 << edge.a) | (1 << edge.b)
				if (_linked & ends) != 0:
					_linked |= ends
		if _linked == seen:
			break
	_joined = (_linked & _BODY_MASK) == _BODY_MASK and (_linked & _present) == _present
	_tail_ready = _live_edge(TAIL_ANCHOR, TAIL_HINGE) and _live_edge(TAIL_HINGE, TAIL_TIP)


## A grounded spring network distributes the peg/strand load over every joined route.
## Solve once for weight and a unit tip force. Only the tip force varies during the lift.
func _solve_loads() -> void:
	_matrix.fill(0.0)
	_weight.fill(0.0)
	_matrix[0] = 1.0
	for peg in range(1, _PEG_COUNT):
		if (_linked & (1 << peg)) == 0:
			_matrix[peg * _ROW + peg] = 1.0
		else:
			_weight[peg] = _MASS[peg]
	for edge in _edges:
		if edge.cracked:
			continue
		var spring := _spring(edge)
		var mass := edge.length * edge.thickness * 0.17
		_weight[edge.a] += mass
		_weight[edge.b] += mass
		_matrix[edge.b * _ROW + edge.b] += spring
		if edge.a != 0:
			_matrix[edge.a * _ROW + edge.a] += spring
			_matrix[edge.a * _ROW + edge.b] -= spring
			_matrix[edge.b * _ROW + edge.a] -= spring
	for peg in range(1, _PEG_COUNT):
		_matrix[peg * _ROW + _PEG_COUNT] = _weight[peg]
	if _tail_ready:
		_matrix[TAIL_TIP * _ROW + _PEG_COUNT + 1] = 1.0
		var hinge := _edges[_edge_indices[_key(TAIL_ANCHOR, TAIL_HINGE)]]
		_tail_stiffness = 2.65 + (hinge.thickness - 1.0) * 8.5
	for pivot in range(1, _PEG_COUNT):
		var row := pivot * _ROW
		var resistance := _matrix[row + pivot]
		for i in range(pivot + 1, _PEG_COUNT):
			var lower := i * _ROW
			var scale := _matrix[lower + pivot] / resistance
			if absf(scale) <= 0.000001:
				continue
			for col in range(pivot + 1, _ROW):
				_matrix[lower + col] -= scale * _matrix[row + col]
	for pivot in range(_PEG_COUNT - 1, 0, -1):
		var row := pivot * _ROW
		for rhs in range(_PEG_COUNT, _ROW):
			var value := _matrix[row + rhs]
			for col in range(pivot + 1, _PEG_COUNT):
				value -= _matrix[row + col] * _matrix[col * _ROW + rhs]
			_matrix[row + rhs] = value / _matrix[row + pivot]
	for edge in _edges:
		if not edge.cracked:
			var from := edge.a * _ROW + _PEG_COUNT
			var to := edge.b * _ROW + _PEG_COUNT
			edge.weight_load = (_matrix[to] - _matrix[from]) * _spring(edge)
			edge.swing_load = (_matrix[to + 1] - _matrix[from + 1]) * _spring(edge)
			var leverage := 1.0 + absf(_pegs[edge.b].x - _pegs[edge.a].x) * 0.32 + edge.length * 0.12
			var capacity := 0.95 * pow(edge.thickness, 1.55) * edge.adhesion * lerpf(0.86, 1.0, edge.cure)
			edge.stress_factor = leverage / (capacity * (1.15 if _assisted else 1.0))


func _spring(edge: Strand) -> float:
	return pow(edge.thickness, 1.35) * edge.adhesion / edge.length


func _lift_tick() -> void:
	_lift_time += _TICK
	var rise := clampf(_lift_time / RISE_SECONDS, 0.0, 1.0)
	_lift_height = smoothstep(0.0, 1.0, rise)
	var pull := lerpf(0.08, 1.0, _lift_height) + sin(rise * PI) * 0.13
	var tip_force := _swing_tail() if _tail_ready else 0.0
	var worst := -1
	var stress := 1.0
	for index in _edges.size():
		var edge := _edges[index]
		if edge.cracked:
			continue
		var next_stress := absf(edge.weight_load * pull + edge.swing_load * tip_force) * edge.stress_factor
		_edges_changed = _edges_changed or not is_equal_approx(next_stress, edge.stress)
		edge.stress = next_stress
		if edge.stress > stress:
			worst = index
			stress = edge.stress
		if _tail_ready and (edge.b == TAIL_HINGE or edge.b == TAIL_TIP) and edge.stress >= 0.93:
			_tail_safe = false
	if worst >= 0 and worst == _overload_edge:
		_overload_seconds += _TICK
	else:
		_overload_edge = worst
		_overload_seconds = _TICK if worst >= 0 else 0.0
	if _overload_seconds >= _OVERLOAD_TIME:
		_crack(worst)
	elif _lift_time >= HOLD_SECONDS - 0.00001 and worst < 0:
		_finish_lift()


func _swing_tail() -> float:
	var gravity := 8.2 * _lift_height
	var acceleration := -gravity * sin(_tail_rest + _tail_angle) - _tail_stiffness * _tail_angle - 1.55 * _tail_velocity
	_tail_velocity = clampf(_tail_velocity + acceleration * _TICK, -3.2, 3.2)
	_tail_angle += _tail_velocity * _TICK
	if absf(_tail_angle) > 0.82:
		_tail_angle = clampf(_tail_angle, -0.82, 0.82)
		_tail_velocity *= -0.18
	_tail_low = minf(_tail_low, _tail_angle)
	_tail_high = maxf(_tail_high, _tail_angle)
	_tail_peak_speed = maxf(_tail_peak_speed, absf(_tail_velocity))
	return (_tail_velocity * _tail_velocity * 0.035 + absf(acceleration) * 0.014) * _lift_height


func _crack(index: int) -> void:
	_mistakes += 1
	var edge := _edges[index]
	edge.cracked = true
	_failed_edge = index
	_reset_lift()
	_scan_structure()
	_feedback = "這段受力過大裂開了。可補接、加雙線或改走線。"


func _finish_lift() -> void:
	_tail_proven = _tail_ready and _tail_safe and _tail_high - _tail_low >= _TAIL_SWAY and _tail_peak_speed >= 0.36
	_lifting = false
	_lift_held = false
	_success = true
	_ended = true
	_score = BODY_POINTS + (TAIL_POINTS if _tail_proven else 0)
	_feedback = "燈獸提穩了，尾巴也能擺動。" if _tail_proven else "整隻燈獸提穩了。"


func _reset_lift() -> void:
	_edges_changed = true
	_lifting = false
	_lift_time = 0.0
	_lift_height = 0.0
	_overload_edge = -1
	_overload_seconds = 0.0
	_tail_angle = 0.0
	_tail_velocity = 0.0
	_tail_low = 0.0
	_tail_high = 0.0
	_tail_peak_speed = 0.0
	_tail_safe = true
	for edge in _edges:
		if not edge.cracked:
			edge.stress = 0.0


func _key(a: int, b: int) -> int:
	return mini(a, b) * _PEG_COUNT + maxi(a, b)


func _live_edge(a: int, b: int) -> bool:
	var index := _edge_indices[_key(a, b)]
	return index >= 0 and not _edges[index].cracked


func _duration() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _refuse(message: String) -> bool:
	_feedback = message
	return false


func snapshot() -> Dictionary:
	if _edges_changed:
		var edges: Array[Dictionary] = []
		for edge in _edges:
			var visual := {"a": edge.a, "b": edge.b, "length": edge.length, "thickness": edge.thickness,
				"cure": edge.cure, "stress": edge.stress, "cracked": edge.cracked}
			visual.make_read_only()
			edges.append(visual)
		edges.make_read_only()
		_draw_edges = edges
		_edges_changed = false
	return {"layout": _layout, "name": _LAYOUTS[_layout].name, "pegs": _pegs.duplicate(), "void_center": _void_center,
		"void_radii": _void_radii, "edges": _draw_edges, "assisted": _assisted, "sugar": _sugar, "sugar_max": SUGAR_MAX,
		"heat": _heat, "rewarm_remaining": _rewarm_left, "elapsed": _elapsed, "remaining": maxf(0.0, _duration() - _elapsed),
		"joined": _joined, "wet": _wet, "linked_mask": _linked, "lift_held": _lift_held, "lifting": _lifting,
		"lift_progress": clampf(_lift_time / HOLD_SECONDS, 0.0, 1.0), "lift_height": _lift_height,
		"lift_hold": maxf(0.0, _lift_time - RISE_SECONDS), "failed_edge": _failed_edge,
		"tail_anchor": TAIL_ANCHOR, "tail_angle": _tail_angle, "tail_swing": _tail_high - _tail_low,
		"tail_ready": _tail_ready, "tail_proven": _tail_proven, "engaged": _engaged, "ended": _ended,
		"success": _success, "devil": _tail_proven, "ordinary_eligible": _ordinary or (_ended and _engaged), "score": _score, "mistakes": _mistakes, "feedback": _feedback}
