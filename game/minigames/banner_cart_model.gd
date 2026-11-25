extends RefCounted

const DIRECT := 0
const BYPASS := 1
const BANNER_COUNT := 3
const DELIVERY_POINTS := 150
const CHALLENGE_POINTS := 100
const TICK := 1.0 / 60.0
const ROUND_SECONDS := 115.0
const ASSISTED_SECONDS := 142.0

const MAX_LIFT := 0.55
const MAX_ROLL := 0.58
const CANVAS_HALF_DEPTH := 0.07
const PIVOT_BASE := 1.04
const START_LIFT := 0.34
const LIFT_RATE := 0.74
const ROLL_RATE := 1.17
const CARRIAGE_HALF_WIDTH := 0.44
const CARRIAGE_HALF_DEPTH := 0.55
const CARRIAGE_BOTTOM := 0.10
const CARRIAGE_TOP := 0.58
const ROUTE_LOCK_Z := 3.0
const BRANCH_Z := 5.2
const REJOIN_START_Z := 12.90
const REJOIN_END_Z := 15.70
const FINISH_Z := 17.4
const PEDESTRIAN_RADIUS := 0.27
const PEDESTRIAN_HALF_DEPTH := 0.24
const PEDESTRIAN_HEIGHT := 1.62
const PEDESTRIAN_MIN_X := -3.25
const PEDESTRIAN_MAX_X := 3.52
const MOVEMENT_EPSILON := 0.00001
const CONTACT_GAP := 0.00005
const USEFUL_ROLL := 0.23
const USEFUL_PENETRATION := 0.005

const _BANNERS := [
	{"id": 0, "name": "燕尾布幌", "width": 1.24, "height": 0.95},
	{"id": 1, "name": "方窗布幌", "width": 1.41, "height": 1.10},
	{"id": 2, "name": "滿月布幌", "width": 1.54, "height": 1.25},
]
const _ROUTE_NAMES := ["近巷", "外側寬路"]
const _TRACK_X := [Vector2(-1.54, 1.82), Vector2(-1.38, 2.02)]
const _LANE_HALF_WIDTH := [Vector2(1.10, 1.25), Vector2(1.05, 1.33)]
const _NECK_HALF_WIDTH := [0.90, 0.86]
const _NECK := [Vector2(5.26, 5.45), Vector2(5.28, 5.44)]
const _FIRST_ROOF := [Vector2(6.10, 6.78), Vector2(6.25, 6.95)]
const _SECOND_ROOF := [Vector2(9.02, 9.66), Vector2(9.18, 9.93)]
const _ABOVE_BYPASS := [Vector3(6.30, 8.42, 1.74), Vector3(6.70, 8.62, 1.71)]
const _PEDESTRIAN_Z := [11.68, 11.91]
const _PEDESTRIAN_PERIOD := [8.60, 7.70]
const _PEDESTRIAN_OFFSET := [0.15, 1.05]
const _WALL_MESSAGE := "窄口碰到招幌，先回正再推。"
const _PERSON_MESSAGE := "行人正在過巷，等走開再推。"


class Gate:
	var id: int
	var route: int
	var kind: String
	var side: int
	var minimum: Vector3
	var maximum: Vector3
	var cross_section: Rect2

	func _init(gate_id: int, route_id: int, obstacle: String, side_sign: int, low: Vector3, high: Vector3) -> void:
		id = gate_id
		route = route_id
		kind = obstacle
		side = side_sign
		minimum = low
		maximum = high
		var position := Vector2(low.x, low.y)
		cross_section = Rect2(position, Vector2(high.x, high.y) - position)


var _gates: Array[Gate] = []
var _gate_data: Array[Dictionary] = []
var _lanes: Array[Dictionary] = []
var _assisted := false
var _layout := 0
var _route := BYPASS
var _z := 0.0
var _speed := 0.0
var _lift := START_LIFT
var _roll := 0.0
var _banner_index := 0
var _delivered := 0
var _drive_axis := 0.0
var _lift_axis := 0.0
var _roll_axis := 0.0
var _braking := false
var _ticks := 0
var _accumulator := 0.0
var _pedestrian_x := 0.0
var _pedestrian_velocity := 0.0
var _block_kind := ""
var _block_id := -1
var _mistakes := 0
var _roof_passes := 0
var _useful_roof_mask := 0
var _challenge_proven := false
var _engaged := false
var _ended := false
var _feedback := ""
var _notes: Array[int] = []


func _init() -> void:
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, _TRACK_X.size())
	_build_layout()
	_route = BYPASS
	_z = 0.0
	_lift = START_LIFT
	_roll = 0.0
	_banner_index = 0
	_delivered = 0
	clear_input()
	_ticks = 0
	_accumulator = 0.0
	_update_pedestrian()
	_block_kind = ""
	_block_id = -1
	_mistakes = 0
	_roof_passes = 0
	_useful_roof_mask = 0
	_challenge_proven = false
	_engaged = false
	_ended = false
	_feedback = "先選路。近巷取決於姿態，外側寬路先降架。"
	_notes.clear()


func set_drive_axis(value: float) -> void:
	if not _ended and is_finite(value):
		_drive_axis = clampf(value, 0.0, 1.0)


func set_lift_axis(value: float) -> void:
	if not _ended and is_finite(value):
		_lift_axis = clampf(value, -1.0, 1.0)


## Positive roll raises the right edge of the canvas in the world X/Y plane.
func set_roll_axis(value: float) -> void:
	if not _ended and is_finite(value):
		_roll_axis = clampf(value, -1.0, 1.0)


func set_brake(value: bool) -> void:
	if _ended or value == _braking:
		return
	_braking = value
	if value:
		_feedback = "煞車中，停穩後可調整招幌。"


func choose_route(route: int) -> bool:
	if _ended or route not in [DIRECT, BYPASS]:
		return false
	if _z >= ROUTE_LOCK_Z:
		_feedback = "已進巷，下一幅才可換路。"
		return false
	if route != _route:
		_route = route
		_feedback = "選擇近巷。先回正過窄口，再看左右低檐。" if route == DIRECT else "選擇外側寬路。降架通過整排低棚。"
	return true


func clear_input() -> void:
	_drive_axis = 0.0
	_lift_axis = 0.0
	_roll_axis = 0.0
	_braking = false
	_speed = 0.0


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK and not _ended:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_ticks += 1
		_step_cart()
		if not _ended and _elapsed() >= _time_limit():
			_finish("時間到，已完整送達 %d / %d 幅。" % [_delivered, BANNER_COUNT])


func _step_cart() -> void:
	var previous_pedestrian_x := _pedestrian_x
	_update_pedestrian()
	var cart_x := _lane_x(_route, _z)
	var pose_block: Gate = _change_pose(cart_x)
	_update_speed()
	var next_z := minf(FINISH_Z, _z + _speed * TICK)
	if next_z - _z <= MOVEMENT_EPSILON:
		_report_block(pose_block)
		return
	var next_x := _lane_x(_route, next_z)
	var drive_block := _first_gate_hit(next_x, _z, next_z, _lift, _roll, true)
	if drive_block != null:
		_z = _gate_stop_depth(drive_block, next_x, next_z)
		_speed = 0.0
		_report_block(drive_block)
		return
	if _pedestrian_hit(next_x, _z, next_z, previous_pedestrian_x):
		_speed = 0.0
		_report_block(null, true)
		return
	_report_block(pose_block)
	_record_roof_passage(next_x, _z, next_z)
	_z = next_z
	_engaged = _engaged or _z >= 0.25
	if _z >= FINISH_Z:
		_deliver_banner()


func _change_pose(cart_x: float) -> Gate:
	var lift := clampf(_lift + _lift_axis * LIFT_RATE * TICK, 0.0, MAX_LIFT)
	var roll := clampf(_roll + _roll_axis * ROLL_RATE * TICK, -MAX_ROLL, MAX_ROLL)
	if lift == _lift and roll == _roll:
		return null
	var collision := _first_gate_hit(cart_x, _z, _z, lift, roll, false)
	if collision != null:
		return collision
	_lift = lift
	_roll = roll
	return null


func _update_speed() -> void:
	var max_speed := 2.80 if _route == DIRECT or _z < BRANCH_Z or _z > REJOIN_END_Z else 2.15
	if _assisted:
		max_speed *= 0.84
	var target := max_speed * _drive_axis
	var acceleration := 3.55
	if _braking:
		target = 0.0
		acceleration = 11.40 if _assisted else 9.20
	elif _speed > target:
		acceleration = 5.4 if _drive_axis == 0.0 else 3.8
	_speed = move_toward(_speed, target, acceleration * TICK)


func _build_layout() -> void:
	_gates.clear()
	var direct_x: float = _TRACK_X[_layout].x
	var bypass_x: float = _TRACK_X[_layout].y
	var neck: Vector2 = _NECK[_layout]
	var neck_width: float = _NECK_HALF_WIDTH[_layout]
	_gates.append(Gate.new(0, DIRECT, "wall", -1,
		Vector3(direct_x - 1.55, 0.02, neck.x), Vector3(direct_x - neck_width, 2.35, neck.y)))
	_gates.append(Gate.new(1, DIRECT, "wall", 1,
		Vector3(direct_x + neck_width, 0.02, neck.x), Vector3(direct_x + 1.55, 2.35, neck.y)))
	if _layout == 0:
		_add_roof(2, _FIRST_ROOF[_layout], 1, 0.44, 1.60, direct_x)
		_add_roof(3, _SECOND_ROOF[_layout], -1, 0.46, 1.58, direct_x)
	else:
		_add_roof(2, _FIRST_ROOF[_layout], -1, 0.40, 1.57, direct_x)
		_add_roof(3, _SECOND_ROOF[_layout], 1, 0.46, 1.63, direct_x)
	var bypass: Vector3 = _ABOVE_BYPASS[_layout]
	var bypass_width: float = _LANE_HALF_WIDTH[_layout].y
	_gates.append(Gate.new(4, BYPASS, "roof", 0,
		Vector3(bypass_x - bypass_width, bypass.z, bypass.x), Vector3(bypass_x + bypass_width, 2.15, bypass.y)))
	var gate_data: Array[Dictionary] = []
	for gate in _gates:
		var record := {"id": gate.id, "route": gate.route, "kind": gate.kind, "side": gate.side,
			"min": gate.minimum, "max": gate.maximum}
		record.make_read_only()
		gate_data.append(record)
	gate_data.make_read_only()
	_gate_data = gate_data

	var lanes: Array[Dictionary] = []
	var depths := [0.0, ROUTE_LOCK_Z, 3.45, 3.95, 4.45, BRANCH_Z, REJOIN_START_Z, 13.6, 14.3, 15.0, REJOIN_END_Z, FINISH_Z]
	for route in [DIRECT, BYPASS]:
		var points := PackedVector3Array()
		for depth: float in depths:
			points.append(Vector3(_lane_x(route, depth), 0.0, depth))
		var record := {"id": route, "name": _ROUTE_NAMES[route], "points": points, "half_width": _LANE_HALF_WIDTH[_layout][route]}
		record.make_read_only()
		lanes.append(record)
	lanes.make_read_only()
	_lanes = lanes


func _add_roof(id: int, span: Vector2, side: int, inset: float, underside: float, cart_x: float) -> void:
	var inner := cart_x + float(side) * inset
	var outer := cart_x + float(side) * 1.34
	_gates.append(Gate.new(id, DIRECT, "roof", side,
		Vector3(minf(inner, outer), underside, span.x), Vector3(maxf(inner, outer), 2.58, span.y)))


func _lane_x(route: int, depth: float) -> float:
	var offset: float = _TRACK_X[_layout][route]
	return offset * smoothstep(ROUTE_LOCK_Z, BRANCH_Z, depth) * (1.0 - smoothstep(REJOIN_START_Z, REJOIN_END_Z, depth))


func _half_canvas() -> Vector2:
	return Vector2(_BANNERS[_banner_index].width, _BANNERS[_banner_index].height) * 0.5


## The XY rectangle passes through a gate only while the two finite Z footprints overlap.
func _first_gate_hit(cart_x: float, from_z: float, to_z: float, lift: float, roll: float, include_carriage: bool) -> Gate:
	for gate in _gates:
		if gate.route != _route:
			continue
		if include_carriage and _overlaps_depth(from_z, to_z, CARRIAGE_HALF_DEPTH, gate.minimum.z, gate.maximum.z):
			if _carriage_gap(cart_x, gate.cross_section) <= 0.0:
				return gate
		if _overlaps_depth(from_z, to_z, CANVAS_HALF_DEPTH, gate.minimum.z, gate.maximum.z):
			if _canvas_gap(cart_x, lift, roll, gate.cross_section) <= 0.0:
				return gate
	return null


func _overlaps_depth(from_z: float, to_z: float, half_depth: float, min_z: float, max_z: float) -> bool:
	return to_z + half_depth >= min_z and from_z - half_depth <= max_z


func _gate_stop_depth(gate: Gate, cart_x: float, next_z: float) -> float:
	var stop_z := next_z
	if _overlaps_depth(_z, next_z, CARRIAGE_HALF_DEPTH, gate.minimum.z, gate.maximum.z) and _carriage_gap(cart_x, gate.cross_section) <= 0.0:
		stop_z = minf(stop_z, gate.minimum.z - CARRIAGE_HALF_DEPTH - CONTACT_GAP)
	if _overlaps_depth(_z, next_z, CANVAS_HALF_DEPTH, gate.minimum.z, gate.maximum.z) and _canvas_gap(cart_x, _lift, _roll, gate.cross_section) <= 0.0:
		stop_z = minf(stop_z, gate.minimum.z - CANVAS_HALF_DEPTH - CONTACT_GAP)
	return maxf(_z, stop_z)


func _carriage_gap(cart_x: float, rect: Rect2) -> float:
	var center := Vector2(cart_x, (CARRIAGE_TOP + CARRIAGE_BOTTOM) * 0.5)
	var delta := rect.get_center() - center
	var half := rect.size * 0.5
	return maxf(absf(delta.x) - half.x - CARRIAGE_HALF_WIDTH,
		absf(delta.y) - half.y - (CARRIAGE_TOP - CARRIAGE_BOTTOM) * 0.5)


func _canvas_gap(cart_x: float, lift: float, roll: float, rect: Rect2) -> float:
	var canvas_half := _half_canvas()
	var delta := rect.get_center() - Vector2(cart_x, PIVOT_BASE + lift)
	var other_half := rect.size * 0.5
	var width_axis := Vector2.from_angle(roll)
	var height_axis := Vector2(-width_axis.y, width_axis.x)
	var c := absf(width_axis.x)
	var s := absf(width_axis.y)
	# SAT uses both world axes and both axes of the rotated, rigid rectangle.
	var gap_x := absf(delta.x) - other_half.x - canvas_half.x * c - canvas_half.y * s
	var gap_y := absf(delta.y) - other_half.y - canvas_half.x * s - canvas_half.y * c
	var gap_width := absf(delta.dot(width_axis)) - canvas_half.x - other_half.x * c - other_half.y * s
	var gap_height := absf(delta.dot(height_axis)) - canvas_half.y - other_half.x * s - other_half.y * c
	return maxf(maxf(gap_x, gap_y), maxf(gap_width, gap_height))


func _update_pedestrian() -> void:
	var period: float = _PEDESTRIAN_PERIOD[_layout]
	var phase := fposmod(_elapsed() + _PEDESTRIAN_OFFSET[_layout], period) / period
	var fraction := 1.0 - absf(phase * 2.0 - 1.0)
	_pedestrian_x = lerpf(PEDESTRIAN_MIN_X, PEDESTRIAN_MAX_X, fraction)
	_pedestrian_velocity = (PEDESTRIAN_MAX_X - PEDESTRIAN_MIN_X) * 2.0 / period
	if phase >= 0.5:
		_pedestrian_velocity = -_pedestrian_velocity


func _pedestrian_hit(cart_x: float, from_z: float, to_z: float, previous_x: float) -> bool:
	var cross_z: float = _PEDESTRIAN_Z[_layout]
	var min_z := cross_z - PEDESTRIAN_HALF_DEPTH
	var max_z := cross_z + PEDESTRIAN_HALF_DEPTH
	if _overlaps_depth(from_z, to_z, CARRIAGE_HALF_DEPTH, min_z, max_z):
		var body := _pedestrian_section(from_z, to_z, CARRIAGE_HALF_DEPTH, min_z, max_z, previous_x)
		if _carriage_gap(cart_x, body) <= 0.0:
			return true
	if _overlaps_depth(from_z, to_z, CANVAS_HALF_DEPTH, min_z, max_z):
		var body := _pedestrian_section(from_z, to_z, CANVAS_HALF_DEPTH, min_z, max_z, previous_x)
		return _canvas_gap(cart_x, _lift, _roll, body) <= 0.0
	return false


func _pedestrian_section(from_z: float, to_z: float, half_depth: float, min_z: float, max_z: float, previous_x: float) -> Rect2:
	# Use only the part of the tick where the feet and this cart part share the crosswalk.
	var advance := to_z - from_z
	var enter := clampf((min_z - half_depth - from_z) / advance, 0.0, 1.0)
	var exit := clampf((max_z + half_depth - from_z) / advance, 0.0, 1.0)
	var x_enter := lerpf(previous_x, _pedestrian_x, enter)
	var x_exit := lerpf(previous_x, _pedestrian_x, exit)
	return Rect2(minf(x_enter, x_exit) - PEDESTRIAN_RADIUS, 0.0,
		absf(x_enter - x_exit) + PEDESTRIAN_RADIUS * 2.0, PEDESTRIAN_HEIGHT)


func _record_roof_passage(cart_x: float, from_z: float, to_z: float) -> void:
	if _route != DIRECT or _challenge_proven:
		return
	for gate in _gates:
		if gate.kind != "roof" or gate.side == 0:
			continue
		if not _overlaps_depth(from_z, to_z, CANVAS_HALF_DEPTH, gate.minimum.z, gate.maximum.z):
			continue
		var bit := 1 << gate.id
		if _roll * float(gate.side) < -USEFUL_ROLL and _canvas_gap(cart_x, _lift, 0.0, gate.cross_section) < -USEFUL_PENETRATION:
			_useful_roof_mask |= bit
		if to_z - CANVAS_HALF_DEPTH <= gate.maximum.z or (_useful_roof_mask & bit) == 0:
			continue
		_useful_roof_mask &= ~bit
		if gate.id == 2:
			_roof_passes = 1
			_feedback = "通過第一道側檐。停穩後換另一側傾。"
			_note(8)
		elif _roof_passes == 1:
			_roof_passes = 2
			_challenge_proven = true
			_feedback = "同一幅招幌已交錯避過兩道低檐。"
			_note(12)


func _report_block(gate: Gate, person: bool = false) -> void:
	var kind := "person" if person else ""
	var id := -1
	if gate != null:
		kind = gate.kind
		id = gate.id
	if kind == _block_kind and id == _block_id:
		return
	_block_kind = kind
	_block_id = id
	if kind.is_empty():
		return
	_mistakes += 1
	_note(-4)
	if person:
		_feedback = _PERSON_MESSAGE
	elif gate.kind == "wall":
		_feedback = _WALL_MESSAGE
	elif gate.side == 0:
		_feedback = "檐口太低，先降低架子再推。"
	else:
		_feedback = "右檐卡住，把招幌右側壓低。" if gate.side > 0 else "左檐卡住，把招幌左側壓低。"


func _deliver_banner() -> void:
	_delivered += 1
	_note(10)
	if _delivered >= BANNER_COUNT:
		_finish("三幅招幌都完整送達。")
		return
	_banner_index += 1
	_route = BYPASS
	_z = 0.0
	_speed = 0.0
	_lift = START_LIFT
	_roll = 0.0
	_roof_passes = 0
	_useful_roof_mask = 0
	_feedback = "已送達 %d / %d 幅。下一幅可重新選路。" % [_delivered, BANNER_COUNT]


func _finish(message: String) -> void:
	_ended = true
	clear_input()
	_accumulator = 0.0
	_feedback = message


func _note(pitch: int) -> void:
	if _notes.size() < 8:
		_notes.append(pitch)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func _elapsed() -> float:
	return float(_ticks) * TICK


func _time_limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _canvas_corners(pivot: Vector3) -> PackedVector3Array:
	var half := _half_canvas()
	var plane := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	var corners := PackedVector3Array()
	for point in plane:
		var rotated := point.rotated(_roll)
		corners.append(pivot + Vector3(rotated.x, rotated.y, 0.0))
	return corners


func _clearance() -> Dictionary:
	var nearest := -1
	var distance := INF
	var margin := INF
	var neutral := INF
	for gate in _gates:
		if gate.route != _route or _z - CANVAS_HALF_DEPTH > gate.maximum.z:
			continue
		var ahead := maxf(0.0, gate.minimum.z - _z - CANVAS_HALF_DEPTH)
		if ahead > distance:
			continue
		# Gate throats are on the straight portion. Preview is measured at the gate, not before the fork.
		var evaluation_x := _lane_x(_route, maxf(_z, gate.minimum.z))
		var clearance := minf(_carriage_gap(evaluation_x, gate.cross_section), _canvas_gap(evaluation_x, _lift, _roll, gate.cross_section))
		if ahead == distance and clearance >= margin:
			continue
		nearest = gate.id
		distance = ahead
		margin = clearance
		neutral = minf(_carriage_gap(evaluation_x, gate.cross_section), _canvas_gap(evaluation_x, _lift, 0.0, gate.cross_section))
	return {"gate_id": nearest, "distance": distance, "margin": margin, "neutral_margin": neutral}


func snapshot() -> Dictionary:
	var cart := Vector3(_lane_x(_route, _z), 0.0, _z)
	var pivot := cart + Vector3(0.0, PIVOT_BASE + _lift, 0.0)
	var elapsed := minf(_elapsed(), _time_limit())
	var success := _delivered == BANNER_COUNT
	var devil := success and _challenge_proven
	return {
		"assisted": _assisted, "layout": _layout, "cart": cart, "pivot": pivot,
		"speed": _speed, "lift": _lift, "roll": _roll, "braking": _braking,
		"route": _route, "route_locked": _z >= ROUTE_LOCK_Z, "route_lock_z": ROUTE_LOCK_Z, "finish_z": FINISH_Z,
		"banner_index": _banner_index, "delivered": _delivered, "banners": _BANNERS,
		"canvas": _canvas_corners(pivot), "canvas_half_depth": CANVAS_HALF_DEPTH,
		"carriage_min": cart + Vector3(-CARRIAGE_HALF_WIDTH, CARRIAGE_BOTTOM, -CARRIAGE_HALF_DEPTH),
		"carriage_max": cart + Vector3(CARRIAGE_HALF_WIDTH, CARRIAGE_TOP, CARRIAGE_HALF_DEPTH),
		"gates": _gate_data, "lanes": _lanes,
		"pedestrian": {"position": Vector3(_pedestrian_x, 0.0, _PEDESTRIAN_Z[_layout]),
			"velocity": Vector3(_pedestrian_velocity, 0.0, 0.0), "radius": PEDESTRIAN_RADIUS,
			"half_depth": PEDESTRIAN_HALF_DEPTH, "height": PEDESTRIAN_HEIGHT,
			"min_x": PEDESTRIAN_MIN_X, "max_x": PEDESTRIAN_MAX_X},
		"clearance": _clearance(), "blocked": not _block_kind.is_empty(),
		"block_kind": _block_kind, "block_id": _block_id, "mistakes": _mistakes,
		"roof_passes": _roof_passes, "challenge_proven": _challenge_proven, "engaged": _engaged,
		"elapsed": elapsed, "remaining": _time_limit() - elapsed, "ended": _ended,
		"success": success, "devil": devil, "ordinary_eligible": _ended and _engaged,
		"score": _delivered * DELIVERY_POINTS + int(devil) * CHALLENGE_POINTS, "feedback": _feedback,
	}
