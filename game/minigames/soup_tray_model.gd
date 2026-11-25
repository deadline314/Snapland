extends RefCounted
## Tray, bowl and free surface share the same fixed-step state used for scoring.

const SAFE := 0
const CHANNEL := 1
const CARRY := "carry"
const GAP := "gap"
const FLIGHT := "flight"
const HANDOFF := "handoff"
const DAMAGED := "damaged"
const ENDED := "ended"
const TICK := 1.0 / 60.0
const BOWL_COUNT := 3
const DELIVERY_POINTS := 150
const CHALLENGE_POINTS := 100
const ROUND_SECONDS := 100.0
const ASSISTED_SECONDS := 138.0
const MIN_FILL := 0.74
const PROOF_FILL := 0.80
const MAX_LEAN := 0.34
const WALK_SPEED := 2.18
const CAREFUL_SPEED := 0.94
const WALK_ACCEL := 1.78
const COAST_DECEL := 2.10
const BRAKE_DECEL := 3.6
const HANDOFF_RANGE := 0.39
const HANDOFF_SPEED := 0.13

const _GRAVITY := 9.81
const _LEAN_RATE := 2.7
const _MAX_SLOPE := 0.77
const _SLOSH_FORCE := 0.72
const _MAX_ACCEL := 15.0
const _RETURN_CREST := 0.033
const _RETURN_RATE := 0.16
const _START_BOWL_HEIGHT := 0.21
const _CATCH_HEIGHT := 0.065
const _CATCH_HALF_WIDTH := 0.22
const _EPS := 0.000001
const _CIRCLE := PI / 3.0

const _BOWLS := [
	{"id": 0, "name": "青花闊碗", "radius": 0.248, "base_radius": 0.138, "depth": 0.151,
		"initial_depth": 0.091, "frequency": 9.5, "damping": 0.25},
	{"id": 1, "name": "荷葉淺碗", "radius": 0.219, "base_radius": 0.131, "depth": 0.126,
		"initial_depth": 0.079, "frequency": 10.5, "damping": 0.28},
	{"id": 2, "name": "陶盅深碗", "radius": 0.212, "base_radius": 0.113, "depth": 0.173,
		"initial_depth": 0.106, "frequency": 8.8, "damping": 0.29},
]
const _SAFE_ROUTES := [
	[Vector2(0, 0), Vector2(0, 1.45), Vector2(-0.80, 2.25), Vector2(-1.70, 3.05), Vector2(-2.05, 4.0),
		Vector2(-2.05, 5.50), Vector2(-1.65, 6.15), Vector2(-0.85, 7.05), Vector2(0, 7.75)],
	[Vector2(0, 0), Vector2(0, 1.38), Vector2(1.00, 2.00), Vector2(1.95, 2.55), Vector2(2.35, 3.40),
		Vector2(2.35, 5.70), Vector2(1.90, 6.33), Vector2(0.85, 7.08), Vector2(0, 8.05)],
]
const _CHANNEL_ROUTES := [
	[Vector2(0, 0), Vector2(0, 1.45), Vector2(-0.58, 2.30), Vector2(0, 3.22), Vector2(0, 7.75)],
	[Vector2(0, 0), Vector2(0, 1.38), Vector2(0.60, 2.50), Vector2(0, 3.56), Vector2(0, 8.05)],
]
const _NEAR_Z := [4.20, 4.56]
const _FAR_Z := [4.88, 5.29]
const _CATCH_END_Z := [5.39, 5.82]

var _paths: Array[PackedVector2Array] = []
var _visible_paths: Array[PackedVector2Array] = []
var _visible_gap: Dictionary
var _visible_bowl: Dictionary
var _distances: Array[PackedFloat32Array] = []
var _gap_near_progress := 0.0
var _gap_far_progress := 0.0
var _path_total := 0.0
var _segment := 0
var _layout := 0
var _assisted := false
var _route := SAFE
var _stage := CARRY
var _walk := false
var _brake := false
var _lean_input := Vector2.ZERO
var _lean := Vector2.ZERO
var _player := Vector2.ZERO
var _velocity := Vector2.ZERO
var _acceleration := Vector2.ZERO
var _heading := Vector2.DOWN
var _speed := 0.0
var _progress := 0.0
var _slope := Vector2.ZERO
var _slope_rate := Vector2.ZERO
var _depth := 0.0
var _volume := 0.0
var _initial_volume := 0.0
var _spilled := 0.0
var _bowl_position := Vector2.ZERO
var _bowl_height := _START_BOWL_HEIGHT
var _flight_velocity := Vector2.ZERO
var _flight_vertical_speed := 0.0
var _flight_time := 0.0
var _flight_duration := 0.0
var _launch_return := false
var _crossed := false
var _landed_position := Vector2.ZERO
var _landed_fill := 0.0
var _crossing_proven := false
var _challenge_proven := false
var _recipient_clock := 0.0
var _settled_clock := 0.0
var _delivered := 0
var _engaged := false
var _ended := false
var _ticks := 0
var _accumulator := 0.0
var _mistakes := 0
var _retries := 0
var _feedback := ""
var _delivery_fills := PackedFloat32Array()
var _notes: Array[int] = []


func _init() -> void:
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, _SAFE_ROUTES.size())
	_delivered = 0
	_ended = false
	_engaged = false
	_challenge_proven = false
	_ticks = 0
	_accumulator = 0.0
	_mistakes = 0
	_retries = 0
	_delivery_fills.clear()
	_notes.clear()
	_build_routes()
	_prepare_bowl()


func select_route(route: int) -> bool:
	if not _route_selectable() or route not in [SAFE, CHANNEL]:
		return false
	_route = route
	_path_total = _distances[_route][-1]
	_feedback = "近路有缺口。到了槽邊，搖平等回流再滑送。" if route == CHANNEL else "沿外側轉角慢走，放平再交碗。"
	return true


func set_walk(pressed: bool) -> void:
	_walk = pressed


func set_brake(pressed: bool) -> void:
	_brake = pressed


func set_lean(direction: Vector2) -> void:
	if not direction.is_finite():
		return
	var peak := maxf(absf(direction.x), absf(direction.y))
	_lean_input = (direction / peak).normalized() if peak > 1.0 else direction.limit_length()


func clear_input() -> void:
	_walk = false
	_brake = false
	_lean_input = Vector2.ZERO


func action() -> bool:
	match _stage:
		GAP:
			if _gap_actionable():
				_launch()
				return true
			_mistakes += 1
			_feedback = "先停在槽邊，讓托盤向前傾。"
		HANDOFF:
			if _handoff_ready():
				_deliver()
				return true
			_mistakes += 1
			_feedback = "等接碗人伸手。" if _settled_clock >= 0.16 else "煞停放平，等湯面安定。"
	return false


func retry_bowl() -> bool:
	if not _assisted or _stage != DAMAGED or _ended:
		return false
	_retries += 1
	_prepare_bowl()
	_feedback = "換回這一碗。先前交好的湯都保留。"
	return true


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK and not _ended:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_ticks += 1
		match _stage:
			CARRY, GAP, HANDOFF:
				_step_carry()
			FLIGHT:
				_step_flight()
		if _ticks * TICK >= _limit() and not _ended:
			_end("收攤時間到了。")


func _prepare_bowl() -> void:
	clear_input()
	_stage = CARRY
	_route = SAFE
	_path_total = _distances[SAFE][-1]
	_segment = 0
	_progress = 0.0
	_speed = 0.0
	_player = _paths[SAFE][0]
	_velocity = Vector2.ZERO
	_acceleration = Vector2.ZERO
	_heading = Vector2.DOWN
	_lean = Vector2.ZERO
	_slope = Vector2.ZERO
	_slope_rate = Vector2.ZERO
	var shape := _shape()
	_visible_bowl = {"id": shape.id, "name": shape.name, "radius": shape.radius, "base_radius": shape.base_radius, "depth": shape.depth}
	_visible_bowl.make_read_only()
	_depth = shape.initial_depth
	_volume = _volume_at_depth(_depth, shape)
	_initial_volume = _volume
	_spilled = 0.0
	_bowl_position = _player
	_bowl_height = _START_BOWL_HEIGHT
	_flight_velocity = Vector2.ZERO
	_flight_vertical_speed = 0.0
	_flight_time = 0.0
	_flight_duration = 0.0
	_launch_return = false
	_crossed = false
	_landed_position = Vector2.ZERO
	_landed_fill = 0.0
	_crossing_proven = false
	_recipient_clock = 0.0
	_settled_clock = 0.0
	_feedback = "先選路。端穩湯碗，停好再交給接盤人。"


func _route_selectable() -> bool:
	return _stage == CARRY and _progress <= _EPS and _speed <= _EPS and not _ended


func _step_carry() -> void:
	var previous_velocity := _velocity
	var previous_position := _player
	_lean = _lean.move_toward(_lean_input * MAX_LEAN, _LEAN_RATE * TICK)
	var target_speed := (CAREFUL_SPEED if _brake else WALK_SPEED) if _walk else 0.0
	var rate := BRAKE_DECEL if _brake else (WALK_ACCEL if _walk else COAST_DECEL)
	_speed = move_toward(_speed, target_speed, rate * TICK)

	var limit := _gap_near_progress if _route == CHANNEL and not _crossed else _path_total
	_progress = minf(limit, _progress + _speed * TICK)
	_locate_on_route()
	_velocity = (_player - previous_position) / TICK
	if _progress >= limit:
		_speed = 0.0
	_acceleration = ((_velocity - previous_velocity) / TICK).limit_length(_MAX_ACCEL)
	_bowl_position = _player
	_engaged = _engaged or _progress > 0.12
	_step_liquid(_lean - _acceleration * (_SLOSH_FORCE / _GRAVITY))
	if _fill() < MIN_FILL:
		_damage("灑太多湯，這一碗不能交了。")
		return
	if _route == CHANNEL and not _crossed and _gap_near_progress - _progress <= 0.065:
		_stage = GAP
	elif _path_total - _progress <= HANDOFF_RANGE:
		_stage = HANDOFF
		_recipient_clock += TICK
		if _handoff_still():
			_settled_clock += TICK
		else:
			_settled_clock = 0.0


func _step_liquid(forcing: Vector2) -> void:
	var shape := _shape()
	var frequency: float = shape.frequency
	var damping: float = shape.damping + (0.18 if _assisted else 0.0)
	var spring := (forcing - _slope) * (frequency * frequency) - _slope_rate * (2.0 * damping * frequency)
	_slope_rate = (_slope_rate + spring * TICK).limit_length(11.0)
	_slope = (_slope + _slope_rate * TICK).limit_length(_MAX_SLOPE)
	_spill_if_crest_overflows(shape)


func _spill_if_crest_overflows(shape: Dictionary) -> void:
	var excess := float(shape.radius) * _slope.length() - (float(shape.depth) - _depth)
	if excess <= 0.0 or _volume <= _EPS:
		return
	var opening: float = lerpf(shape.base_radius, shape.radius, _depth / float(shape.depth))
	var escaping := minf(_volume, PI * opening * opening * excess * 1.56 * TICK)
	_volume -= escaping
	_spilled += escaping
	var lower := 0.0
	var upper := _depth
	for _bound in 14:
		var middle := (lower + upper) * 0.5
		if _volume_at_depth(middle, shape) < _volume:
			lower = middle
		else:
			upper = middle
	_depth = (lower + upper) * 0.5


func _volume_at_depth(depth: float, shape: Dictionary) -> float:
	var base: float = shape.base_radius
	var opening: float = lerpf(base, shape.radius, depth / float(shape.depth))
	return _CIRCLE * depth * (base * base + base * opening + opening * opening)


func _gap_actionable() -> bool:
	return _stage == GAP and _gap_near_progress - _progress <= 0.018 and not _walk and _velocity.length() <= 0.16 and _lean.y >= 0.062


func _return_phase() -> bool:
	# The back rim still carries the crest, and the returning wave is already moving toward level.
	return _slope.y <= -_RETURN_CREST and _slope_rate.y >= _RETURN_RATE


func _launch_velocity() -> Vector2:
	return Vector2(_lean.x * 3.50, 1.31 + 5.72 * maxf(0.0, _lean.y))


func _launch_vertical() -> float:
	return 0.94 + 0.45 * maxf(0.0, _lean.y)


func _landing_time(vertical: float) -> float:
	var drop := _START_BOWL_HEIGHT - _CATCH_HEIGHT
	return (vertical + sqrt(vertical * vertical + 2.0 * _GRAVITY * drop)) / _GRAVITY


func _projected_landing() -> Vector2:
	if _stage != GAP:
		return _bowl_position
	return _player + _launch_velocity() * _landing_time(_launch_vertical())


func _inside_catcher(at: Vector2) -> bool:
	return at.y >= _FAR_Z[_layout] and at.y <= _CATCH_END_Z[_layout] and absf(at.x) <= _CATCH_HALF_WIDTH


func _launch() -> void:
	_stage = FLIGHT
	_launch_return = _return_phase()
	_flight_velocity = _launch_velocity()
	_flight_vertical_speed = _launch_vertical()
	_flight_duration = _landing_time(_flight_vertical_speed)
	_flight_time = 0.0
	_velocity = Vector2.ZERO
	_acceleration = Vector2.ZERO
	_speed = 0.0
	_engaged = true
	_feedback = "湯碗已離開托盤，正在跨槽。"
	_notes.append(68)


func _step_flight() -> void:
	var previous_time := _flight_time
	_flight_time = minf(_flight_time + TICK, _flight_duration)
	_bowl_position += _flight_velocity * (_flight_time - previous_time)
	_bowl_height = _START_BOWL_HEIGHT + _flight_vertical_speed * _flight_time - 0.5 * _GRAVITY * _flight_time * _flight_time
	_step_liquid(Vector2.ZERO)
	if _flight_time < _flight_duration:
		return
	if not _inside_catcher(_bowl_position):
		_damage("碗沒落在接盤上。")
		return
	if _fill() < MIN_FILL:
		_damage("碗過去了，但湯量不夠。")
		return
	_crossed = true
	_landed_position = _bowl_position
	_landed_fill = _fill()
	_crossing_proven = _launch_return and _landed_fill >= PROOF_FILL
	_slope_rate += _flight_velocity * 0.27
	_lean = Vector2.ZERO
	_progress = _channel_progress_at_z(_landed_position.y)
	_locate_on_route()
	_stage = CARRY
	_bowl_position = _player
	_bowl_height = _START_BOWL_HEIGHT
	clear_input()
	_feedback = "回流過槽成功。停穩交碗。" if _crossing_proven else "碗已過槽，把湯交到接盤處。"
	_notes.append(76)


func _handoff_still() -> bool:
	return not _walk and _velocity.length() <= HANDOFF_SPEED and _lean.length() <= 0.070 		and _slope.length() <= 0.079 and _slope_rate.length() <= 0.23


func _recipient_phase() -> float:
	return fmod(_recipient_clock, 1.46) / 1.46


func _recipient_ready() -> bool:
	var phase := _recipient_phase()
	return _stage == HANDOFF and phase >= 0.19 and phase <= 0.81


func _handoff_ready() -> bool:
	return _recipient_ready() and _handoff_still() and _settled_clock >= 0.16 and _fill() >= MIN_FILL


func _deliver() -> void:
	_challenge_proven = _challenge_proven or _crossing_proven
	_delivery_fills.append(_fill())
	_delivered += 1
	_notes.append(84)
	if _delivered == BOWL_COUNT:
		_end("三碗湯都平安交到了。")
	else:
		_prepare_bowl()
		_feedback = "這碗交好了。換下一個碗形。"


func _damage(message: String) -> void:
	_mistakes += 1
	clear_input()
	if _assisted:
		_stage = DAMAGED
		_feedback = message + "　可重試這一碗。"
	else:
		_end(message)


func _end(message: String) -> void:
	_ended = true
	_stage = ENDED
	clear_input()
	_feedback = message


func _shape() -> Dictionary:
	return _BOWLS[mini(_delivered, BOWL_COUNT - 1)]


func _fill() -> float:
	return clampf(_volume / _initial_volume, 0.0, 1.0)


func _limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _build_routes() -> void:
	_paths.assign([_round_corners(_SAFE_ROUTES[_layout]), _round_corners(_CHANNEL_ROUTES[_layout])])
	_distances.clear()
	for path in _paths:
		var distance := PackedFloat32Array([0.0])
		for index in range(1, path.size()):
			distance.append(distance[-1] + path[index - 1].distance_to(path[index]))
		_distances.append(distance)
	_gap_near_progress = _channel_progress_at_z(_NEAR_Z[_layout])
	_gap_far_progress = _channel_progress_at_z(_FAR_Z[_layout])
	_visible_paths = _paths.duplicate()
	_visible_paths.make_read_only()
	_visible_gap = {"near": Vector2(0, _NEAR_Z[_layout]), "far": Vector2(0, _FAR_Z[_layout]),
		"landing_end": Vector2(0, _CATCH_END_Z[_layout]), "half_width": _CATCH_HALF_WIDTH,
		"near_progress": _gap_near_progress, "far_progress": _gap_far_progress}
	_visible_gap.make_read_only()


func _round_corners(points: Array) -> PackedVector2Array:
	var path := PackedVector2Array([points[0]])
	for index in range(1, points.size() - 1):
		var corner: Vector2 = points[index]
		var enter := corner.move_toward(points[index - 1], 0.28)
		var exit := corner.move_toward(points[index + 1], 0.28)
		for sample in 5:
			var blend := float(sample) / 4.0
			path.append(enter.lerp(corner, blend).lerp(corner.lerp(exit, blend), blend))
	path.append(points[-1])
	return path


func _channel_progress_at_z(depth: float) -> float:
	var path := _paths[CHANNEL]
	for index in range(1, path.size()):
		if path[index].y >= depth:
			var fraction := inverse_lerp(path[index - 1].y, path[index].y, depth)
			return lerpf(_distances[CHANNEL][index - 1], _distances[CHANNEL][index], fraction)
	return _distances[CHANNEL][-1]


func _locate_on_route() -> void:
	var path := _paths[_route]
	var marks := _distances[_route]
	while _segment < path.size() - 2 and _progress > marks[_segment + 1]:
		_segment += 1
	var fraction := clampf(inverse_lerp(marks[_segment], marks[_segment + 1], _progress), 0.0, 1.0)
	_player = path[_segment].lerp(path[_segment + 1], fraction)
	_heading = path[_segment].direction_to(path[_segment + 1])


func consume_notes() -> Array[int]:
	var output := _notes
	_notes = []
	return output


func snapshot() -> Dictionary:
	var finished := _delivered == BOWL_COUNT and _ended
	var devil := finished and _challenge_proven
	var prediction := _projected_landing()
	var launch_ready := _gap_actionable() and _inside_catcher(prediction)
	var shape := _shape()
	var elapsed := minf(_ticks * TICK, _limit())
	return {
		"stage": _stage, "layout": _layout, "assisted": _assisted, "route": _route,
		"route_selectable": _route_selectable(), "player": _player, "velocity": _velocity,
		"acceleration": _acceleration, "heading": _heading, "speed": _speed, "path_position": _progress,
		"path_length": _path_total, "paths": _visible_paths, "gap": _visible_gap, "bowl": _visible_bowl,
		"recipient": _paths[_route][-1], "recipient_phase": _recipient_phase(), "recipient_ready": _recipient_ready(),
		"lean": _lean, "liquid_slope": _slope, "liquid_rate": _slope_rate, "liquid_depth": _depth,
		"freeboard": float(shape.depth) - _depth, "liquid_volume": _volume, "initial_volume": _initial_volume,
		"spilled_volume": _spilled, "fill": _fill(), "bowl_position": _bowl_position, "bowl_height": _bowl_height,
		"airborne": _stage == FLIGHT, "flight_progress": clampf(_flight_time / maxf(_flight_duration, _EPS), 0.0, 1.0),
		"projected_landing": prediction, "can_launch": _gap_actionable(), "launch_ready": launch_ready,
		"return_ready": launch_ready and _return_phase(), "launch_return": _launch_return,
		"handoff_ready": _handoff_ready(), "retry_ready": _assisted and _stage == DAMAGED,
		"crossed": _crossed, "landed_position": _landed_position, "landed_fill": _landed_fill,
		"crossing_proven": _crossing_proven, "challenge_proven": _challenge_proven,
		"delivered": _delivered, "delivery_fills": _delivery_fills.duplicate(), "score": _delivered * DELIVERY_POINTS + int(devil) * CHALLENGE_POINTS,
		"engaged": _engaged, "participated": _engaged, "ordinary_eligible": _ended and _engaged, "ended": _ended, "success": finished,
		"devil": devil, "remaining": _limit() - elapsed, "elapsed": elapsed, "mistakes": _mistakes,
		"retries": _retries, "feedback": _feedback,
	}
