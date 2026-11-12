extends RefCounted
class_name RowingCargoModel

## Planar coordinates map to world X/Z; heading zero points along +X.
const ROUND_SECONDS := 240.0
const MAX_FRAME_DELTA := 0.25
const MAX_SUBSTEP := 0.02
const BOUNDS := Rect2(-11.0, -7.0, 22.0, 14.0)
const START := Vector2(-8.0, -3.0)
const BOAT_RADIUS := 0.32
const CRATE_RADIUS := 0.32
const BREAKWATER_X := 0.45
const SHELTER_Y := 3.8
const LONG_ROUTE_Y := 5.3
const TIDE_PERIOD := 18.0
const GAP_MIN := 0.45
const GAP_MAX := 1.55
const WAVE_PERIOD := 6.0
const CREST_CENTER := 1.5
const CREST_HALF_WIDTH := 0.5
const WAVE_FORCE := 0.30
const WAVE_TORQUE := 0.15
const WAVE_LATERAL_RATIO := 0.6
const WAVE_SPATIAL_PHASE := 0.2
const SHELTER_FACTOR := 0.12
const ASSIST_WAVE_FACTOR := 0.5
const PADDLE_IMPULSE := 0.72
const PADDLE_COOLDOWN := 0.32
const SLIP_IMPULSE := 0.42
const SLIP_COOLDOWN := 0.7
const CREST_SLIP_BOOST := 1.35
const MAX_SPEED := 3.6
const MAX_ANGULAR_SPEED := 1.5
const FORWARD_DRAG := 0.72
const LATERAL_DRAG := 1.65
const RUDDER_TORQUE := 2.8
const ANGULAR_DRAG := 3.6
const RUDDER_IDLE_GAIN := 0.4
const RUDDER_SPEED_GAIN := 0.3
const RUDDER_GAIN_SPEED_CAP := 2.0
const PICKUP_RADIUS := 1.05
const PICKUP_SPEED := 1.0
const DOCK_RADIUS := 1.15
const DOCK_SPEED := 0.90
const DOCK_ANGLE := 0.35
const ASSIST_ATTRACTION := 0.16
const ASSIST_ATTRACTION_RADIUS := 1.7
const ASSIST_ATTRACTION_SPEED := 1.3
const ASSIST_DOCK_RADIUS_FACTOR := 1.15
const ASSIST_DOCK_SPEED_FACTOR := 1.2
const ASSIST_DOCK_ANGLE_FACTOR := 1.4
const CRATE_IMPACT_SPEED := 1.15
const CRATE_IMPACT_COOLDOWN := 0.6
const CRATE_REBOUND := 0.2
const WALL_RESTITUTION := 0.2
const WALL_IMPACT_MIN_SPEED := 0.05
const CREST_DOCK_WINDOW := 1.1
const CREST_DOCK_TRAVEL := 0.08
const CREST_SLIP_DOCK_RADIUS := DOCK_RADIUS + 0.75
const DELIVERED_CRATE_SPACING := 0.45
const DELIVERED_CRATE_OFFSET := -0.6
const DOCKS := [
	{"id": 1, "position": Vector2(8.0, -3.0), "heading": 0.0, "size": Vector2(2.5, 1.1)},
	{"id": 2, "position": Vector2(8.0, 3.0), "heading": 0.0, "size": Vector2(2.5, 1.1)},
]
const CARGO_STARTS := [Vector2(-8.0, -3.0), Vector2(-8.0, 0.0), Vector2(-8.0, 3.0)]
const DESTINATIONS := [1, 2, 1]

var _assisted := false
var _elapsed := 0.0
var _position := START
var _heading := 0.0
var _velocity := Vector2.ZERO
var _angular_velocity := 0.0
var _rudder := 0.0
var _paddle_at := -100.0
var _slip_at := -100.0
var _slip_origin := Vector2.ZERO
var _slip_axis := Vector2.ZERO
var _slip_dock := 0
var _crest_dock := false
var _cargo: Array[Dictionary] = []
var _carrying := ""
var _ledger: Array[Dictionary] = []
var _wall_collisions := 0
var _crate_impacts := 0
var _impact_at := -100.0
var _ended := false
var _success := false
var _feedback := "靠近貨箱後按空白拿取"

func _init() -> void:
	reset()

func reset(assisted: bool = false) -> void:
	_assisted = assisted
	_elapsed = 0.0
	_position = START
	_heading = 0.0
	_velocity = Vector2.ZERO
	_angular_velocity = 0.0
	_rudder = 0.0
	_paddle_at = -100.0
	_slip_at = -100.0
	_slip_dock = 0
	_slip_origin = Vector2.ZERO
	_slip_axis = Vector2.ZERO
	_crest_dock = false
	_cargo.clear()
	for i in 3:
		_cargo.append({"id": "crate-%d" % (i + 1), "position": CARGO_STARTS[i], "destination": DESTINATIONS[i], "status": "waiting"})
	_carrying = ""
	_ledger.clear()
	_wall_collisions = 0
	_crate_impacts = 0
	_impact_at = -100.0
	_ended = false
	_success = false
	_feedback = "靠近貨箱後按空白拿取"

func set_rudder(value: float) -> void:
	if not _ended and is_finite(value):
		_rudder = clampf(value, -1.0, 1.0)

func paddle(direction: float = 1.0) -> void:
	if _ended or not is_finite(direction) or is_zero_approx(direction):
		return
	if _elapsed - _paddle_at < PADDLE_COOLDOWN:
		_feedback = "槳尚未回位"
		return
	_paddle_at = _elapsed
	_velocity = (_velocity + Vector2.from_angle(_heading) * PADDLE_IMPULSE * clampf(direction, -1.0, 1.0)).limit_length(MAX_SPEED)
	_feedback = "前划" if direction > 0.0 else "反向槳減速"

func sideslip(direction: float) -> void:
	if _ended or not is_finite(direction) or is_zero_approx(direction):
		return
	if _elapsed - _slip_at < SLIP_COOLDOWN:
		_feedback = "側滑尚未回位"
		return
	_slip_at = _elapsed
	_slip_origin = _position
	_slip_axis = Vector2.from_angle(_heading + PI / 2.0) * signf(direction)
	_slip_dock = 0
	if _is_crest():
		for dock in DOCKS:
			if _position.distance_to(dock.position) <= CREST_SLIP_DOCK_RADIUS:
				_slip_dock = dock.id
	_velocity = (_velocity + _slip_axis * SLIP_IMPULSE * clampf(absf(direction), 0.0, 1.0) * (CREST_SLIP_BOOST if _is_crest() else 1.0)).limit_length(MAX_SPEED)
	_feedback = "浪峰側滑" if _is_crest() else "側滑"

func clear_input() -> void:
	_rudder = 0.0

func interact() -> void:
	if _ended:
		return
	if _carrying.is_empty():
		for crate in _cargo:
			if crate.status == "waiting" and _position.distance_to(crate.position) <= PICKUP_RADIUS:
				if _velocity.length() > PICKUP_SPEED:
					_feedback = "拿箱速度太快，先反向划槳"
					return
				_carrying = crate.id
				crate.status = "carried"
				crate.position = _position
				_feedback = "已拿 %s，送往碼頭 %d" % [crate.id, crate.destination]
				return
		_feedback = "靠近尚未拿取的貨箱"
		return
	for crate in _cargo:
		if crate.id != _carrying:
			continue
		var dock: Dictionary = DOCKS[crate.destination - 1]
		if _position.distance_to(dock.position) > _dock_radius():
			_feedback = "請靠近碼頭 %d" % crate.destination
			return
		if _velocity.length() > _dock_speed():
			_feedback = "靠岸速度太快，先反向划槳"
			return
		if _dock_angle_error(dock) > _dock_angle():
			_feedback = "靠岸角度太斜，船身須平行碼頭"
			return
		var crest_delivery: bool = _slip_dock == dock.id and _elapsed - _slip_at <= CREST_DOCK_WINDOW and (_position - _slip_origin).dot(_slip_axis) >= CREST_DOCK_TRAVEL
		_crest_dock = _crest_dock or crest_delivery
		crate.status = "delivered"
		crate.position = dock.position + Vector2((_ledger.size() - 1) * DELIVERED_CRATE_SPACING, DELIVERED_CRATE_OFFSET)
		_ledger.append({"cargo_id": crate.id, "dock_id": dock.id, "elapsed": _elapsed, "speed": _velocity.length(), "angle": _dock_angle_error(dock), "crest_sideslip": crest_delivery})
		_carrying = ""
		_feedback = "已送達 %d / 3 箱" % _ledger.size()
		if _ledger.size() == 3:
			_ended = true
			_success = true
			_rudder = 0.0
		return

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, minf(MAX_SUBSTEP, ROUND_SECONDS - _elapsed))
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	var forward := Vector2.from_angle(_heading)
	var lateral := Vector2(-forward.y, forward.x)
	var wave: Dictionary = _water()
	_velocity += (wave.force - forward * _velocity.dot(forward) * FORWARD_DRAG - lateral * _velocity.dot(lateral) * LATERAL_DRAG) * dt
	if _assisted and not _carrying.is_empty():
		for crate in _cargo:
			if crate.id == _carrying:
				var offset: Vector2 = DOCKS[crate.destination - 1].position - _position
				if offset.length() < ASSIST_ATTRACTION_RADIUS and _velocity.length() < ASSIST_ATTRACTION_SPEED:
					_velocity += offset * ASSIST_ATTRACTION * dt
	var rudder_gain := RUDDER_IDLE_GAIN + minf(absf(_velocity.dot(forward)), RUDDER_GAIN_SPEED_CAP) * RUDDER_SPEED_GAIN
	_angular_velocity = clampf(_angular_velocity + (_rudder * RUDDER_TORQUE * rudder_gain + wave.torque - ANGULAR_DRAG * _angular_velocity) * dt, -MAX_ANGULAR_SPEED, MAX_ANGULAR_SPEED)
	_heading = wrapf(_heading + _angular_velocity * dt, -PI, PI)
	_velocity = _velocity.limit_length(MAX_SPEED)
	_position += _velocity * dt
	_resolve_walls()
	for crate in _cargo:
		if crate.status == "carried":
			crate.position = _position
		elif crate.status == "waiting":
			var offset: Vector2 = _position - crate.position
			if offset.length() < BOAT_RADIUS + CRATE_RADIUS and _velocity.length() > CRATE_IMPACT_SPEED and _elapsed - _impact_at > CRATE_IMPACT_COOLDOWN:
				_crate_impacts += 1
				_impact_at = _elapsed
				_velocity *= -CRATE_REBOUND
				_feedback = "撞箱：減速後再拿取"
	if _elapsed >= ROUND_SECONDS:
		_ended = true
		_rudder = 0.0
		_feedback = "時間到，已送達 %d / 3 箱" % _ledger.size()

func _resolve_walls() -> void:
	var old := _position
	_position = _position.clamp(BOUNDS.position + Vector2.ONE * BOAT_RADIUS, BOUNDS.end - Vector2.ONE * BOAT_RADIUS)
	if old != _position:
		_wall_collision((old - _position).normalized())
	var gap := _gap_half_width()
	for wall in [Rect2(-BREAKWATER_X, BOUNDS.position.y, BREAKWATER_X * 2.0, -gap - BOUNDS.position.y), Rect2(-BREAKWATER_X, gap, BREAKWATER_X * 2.0, SHELTER_Y - gap)]:
		var expanded: Rect2 = wall.grow(BOAT_RADIUS)
		if not expanded.has_point(_position):
			continue
		# A closing tide ejects to the nearest free side, never strands the hull inside land.
		var exits := [Vector2(expanded.position.x, _position.y), Vector2(expanded.end.x, _position.y), Vector2(_position.x, expanded.position.y), Vector2(_position.x, expanded.end.y)]
		var nearest: Vector2 = exits[0]
		for candidate in exits:
			if not BOUNDS.grow(-BOAT_RADIUS).has_point(candidate):
				continue
			if _position.distance_squared_to(candidate) < _position.distance_squared_to(nearest):
				nearest = candidate
		var normal := (_position - nearest).normalized()
		_position = nearest - normal * 0.001
		_wall_collision(normal)

func _wall_collision(normal: Vector2) -> void:
	if _velocity.dot(normal) > WALL_IMPACT_MIN_SPEED:
		_wall_collisions += 1
		_velocity -= normal * _velocity.dot(normal) * (1.0 + WALL_RESTITUTION)
		_feedback = "碰到防波堤或岸邊，可轉舵再出發"

func _gap_half_width() -> float:
	return lerpf(GAP_MIN, GAP_MAX, 0.5 + 0.5 * sin(TAU * _elapsed / TIDE_PERIOD))

func _is_crest() -> bool:
	return absf(wrapf(_elapsed - CREST_CENTER, -WAVE_PERIOD / 2.0, WAVE_PERIOD / 2.0)) <= CREST_HALF_WIDTH

func _water() -> Dictionary:
	var phase := TAU * _elapsed / WAVE_PERIOD
	var shelter := _position.y >= SHELTER_Y
	var strength := WAVE_FORCE * (SHELTER_FACTOR if shelter else 1.0) * (ASSIST_WAVE_FACTOR if _assisted else 1.0)
	return {"force": Vector2(sin(phase), cos(phase) * WAVE_LATERAL_RATIO) * strength, "torque": sin(phase + _position.x * WAVE_SPATIAL_PHASE) * WAVE_TORQUE * strength / WAVE_FORCE, "sheltered": shelter, "strength": strength, "phase": phase, "crest": _is_crest(), "next_crest_seconds": fposmod(CREST_CENTER - CREST_HALF_WIDTH - _elapsed, WAVE_PERIOD)}

func _dock_radius() -> float:
	return DOCK_RADIUS * (ASSIST_DOCK_RADIUS_FACTOR if _assisted else 1.0)

func _dock_speed() -> float:
	return DOCK_SPEED * (ASSIST_DOCK_SPEED_FACTOR if _assisted else 1.0)

func _dock_angle() -> float:
	return DOCK_ANGLE * (ASSIST_DOCK_ANGLE_FACTOR if _assisted else 1.0)

func _dock_angle_error(dock: Dictionary) -> float:
	return minf(absf(angle_difference(_heading, dock.heading)), absf(angle_difference(_heading, dock.heading + PI)))

func snapshot() -> Dictionary:
	var water := _water()
	var gap := _gap_half_width()
	var forward := Vector2.from_angle(_heading)
	var nearest: Dictionary = DOCKS[0]
	if _position.distance_squared_to(DOCKS[1].position) < _position.distance_squared_to(nearest.position):
		nearest = DOCKS[1]
	return {
		"assisted": _assisted, "elapsed": _elapsed, "remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success,
		"devil": _success and _crest_dock and _crate_impacts == 0, "devil_success": _success and _crest_dock and _crate_impacts == 0,
		"ordinary_eligible": _ended, "score": _ledger.size() * 100, "mistakes": _crate_impacts, "crate_impacts": _crate_impacts, "wall_collisions": _wall_collisions,
		"position": _position, "heading": _heading, "velocity": _velocity, "speed": _velocity.length(), "angular_velocity": _angular_velocity,
		"forward_speed": _velocity.dot(forward), "lateral_speed": _velocity.dot(Vector2(-forward.y, forward.x)), "rudder": _rudder,
		"cargo": _cargo.duplicate(true), "carrying": _carrying, "docks": DOCKS.duplicate(true), "delivery_ledger": _ledger.duplicate(true),
		"bounds": BOUNDS, "boat_radius": BOAT_RADIUS, "shelter": Rect2(BOUNDS.position.x, SHELTER_Y, BOUNDS.size.x, BOUNDS.end.y - SHELTER_Y),
		"breakwaters": [Rect2(-BREAKWATER_X, BOUNDS.position.y, BREAKWATER_X * 2.0, -gap - BOUNDS.position.y), Rect2(-BREAKWATER_X, gap, BREAKWATER_X * 2.0, SHELTER_Y - gap)],
		"tide": 0.5 + 0.5 * sin(TAU * _elapsed / TIDE_PERIOD), "gap": {"center": Vector2.ZERO, "half_width": gap, "navigable_half_width": maxf(0.0, gap - BOAT_RADIUS)}, "water": water,
		"crest": water.crest, "crest_forecast": water.next_crest_seconds, "crest_dock": _crest_dock, "sheltered": water.sheltered,
		"paddle_ready": _elapsed - _paddle_at >= PADDLE_COOLDOWN, "paddle_ready_in": maxf(0.0, PADDLE_COOLDOWN - (_elapsed - _paddle_at)),
		"sideslip_ready": _elapsed - _slip_at >= SLIP_COOLDOWN, "sideslip_ready_in": maxf(0.0, SLIP_COOLDOWN - (_elapsed - _slip_at)),
		"dock_radius": _dock_radius(), "dock_speed_limit": _dock_speed(), "dock_angle_limit": _dock_angle(), "dock_angle_error": _dock_angle_error(nearest), "nearest_dock": nearest.id,
		"feedback": _feedback, "last_event": _feedback,
	}
