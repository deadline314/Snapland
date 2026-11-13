extends RefCounted
class_name RopeTugModel

## Planar tow physics (world X/Z). The tug is driven directly; the pontoon only
## moves through rope tension, water drag and wall contacts.
const ROUND_SECONDS := 180.0
const MAX_FRAME_DELTA := 0.25
const MAX_SUBSTEP := 1.0 / 120.0
const BOUNDS := Rect2(-12.0, -7.0, 24.0, 14.0)
const TUG_RADIUS := 0.45
const TUG_MASS := 1.6
const THRUST := 2.6
const REVERSE_THRUST := 1.4
const TUG_DRAG := 0.9
const TUG_LATERAL_DRAG := 3.0
const TURN_RATE := 1.9
const MAX_TUG_SPEED := 3.0
const PONTOON_RADIUS := 0.72
const PONTOON_DRAG := 0.55
const PONTOON_ANGULAR_DRAG := 1.6
const PONTOON_INERTIA := 0.45
const ROPE_MIN := 1.4
const ROPE_MAX := 5.0
const ASSIST_ROPE_MAX := 6.0
const REEL_SPEED := 1.5
const ROPE_STIFFNESS := 9.0
const ASSIST_ROPE_STIFFNESS := 4.5
const ROPE_DAMPING := 1.2
const BREAK_TENSION := 3.8
const ASSIST_BREAK_TENSION := 6.5
const BREAK_HOLD := 0.1
const HOOK_RANGE := 1.35
const HOOK_SPEED := 1.2
const DOCK_X := 9.8
const DOCK_SPEED := 0.9
const SNAG_TENSION := 2.0
const ASSIST_SNAG_SLACK_SECONDS := 1.2
const WALL_RESTITUTION := 0.2
const GATE_HALF_THICKNESS := 0.3
## Three narrow bays; the third also has a narrow side bay off the natural line.
const GATES := [
	{"id": 1, "x": -4.0, "gaps": [{"center": 2.5, "half": 1.45, "side": false}]},
	{"id": 2, "x": 1.0, "gaps": [{"center": -2.5, "half": 1.45, "side": false}]},
	{"id": 3, "x": 6.0, "gaps": [{"center": 2.2, "half": 1.45, "side": false}, {"center": -4.6, "half": 0.98, "side": true}]},
]
const TUG_START := Vector2(-7.3, 0.0)
const PONTOON_START := Vector2(-8.9, 0.0)
## Retries alternate the pontoon weight and where its cleats sit.
const VARIANTS := [
	{"name": "重載浮台", "mass": 1.8, "cleat": Vector2(0.78, 0.0)},
	{"name": "輕載偏繫點", "mass": 1.0, "cleat": Vector2(0.7, 0.32)},
]

var _assisted := false
var _variant := 0
var _mass := 1.8
var _cleat_offset := Vector2.ZERO
var _elapsed := 0.0
var _tug := TUG_START
var _tug_heading := 0.0
var _tug_velocity := Vector2.ZERO
var _thrust := 0.0
var _turn := 0.0
var _reel := 0.0
var _pontoon := PONTOON_START
var _pontoon_heading := 0.0
var _pontoon_velocity := Vector2.ZERO
var _pontoon_spin := 0.0
var _hooked := false
var _cleat := 1
var _rope_length := 2.0
var _tension := 0.0
var _over_tension := 0.0
var _breaks := 0
var _snags := 0
var _snagged := false
var _snag_time := 0.0
var _gates_passed: Array[Dictionary] = []
var _side_pass := false
var _ended := false
var _success := false
var _feedback := ""
var _walls: Array[Rect2] = []

func _init() -> void:
	_walls = _build_walls()
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, VARIANTS.size())
	_mass = float(VARIANTS[_variant].mass)
	_cleat_offset = VARIANTS[_variant].cleat
	_elapsed = 0.0
	_tug = TUG_START
	_tug_heading = 0.0
	_tug_velocity = Vector2.ZERO
	_thrust = 0.0
	_turn = 0.0
	_reel = 0.0
	_pontoon = PONTOON_START
	_pontoon_heading = 0.0
	_pontoon_velocity = Vector2.ZERO
	_pontoon_spin = 0.0
	_hooked = false
	_cleat = 1
	_rope_length = 2.0
	_tension = 0.0
	_over_tension = 0.0
	_breaks = 0
	_snags = 0
	_snagged = false
	_snag_time = 0.0
	_gates_passed.clear()
	_side_pass = false
	_ended = false
	_success = false
	_feedback = "靠近浮台按空白掛鉤"

func set_thrust(value: float) -> void:
	if not _ended and is_finite(value):
		_thrust = clampf(value, -1.0, 1.0)

func set_turn(value: float) -> void:
	if not _ended and is_finite(value):
		_turn = clampf(value, -1.0, 1.0)

func set_reel(value: float) -> void:
	if not _ended and is_finite(value):
		_reel = clampf(value, -1.0, 1.0)

func clear_input() -> void:
	_thrust = 0.0
	_turn = 0.0
	_reel = 0.0

func _rope_max() -> float:
	return ASSIST_ROPE_MAX if _assisted else ROPE_MAX

func _cleat_world(index: int) -> Vector2:
	var local := Vector2(_cleat_offset.x * index, _cleat_offset.y)
	return _pontoon + local.rotated(_pontoon_heading)

## Space: hook the nearer cleat, unhook, or deliver inside the dock.
func interact() -> void:
	if _ended:
		return
	if _hooked:
		if _all_gates() and _pontoon.x >= DOCK_X:
			if _pontoon_velocity.length() > DOCK_SPEED:
				_feedback = "浮台太快，先減速再解繩靠港"
				return
			_hooked = false
			_ended = true
			_success = true
			clear_input()
			_feedback = "浮台平安送進碼頭"
			return
		_hooked = false
		_tension = 0.0
		_feedback = "已解開拖繩"
		return
	# Either end can take the rope; the nearer cleat is used, one action at a time.
	var best := 1 if _tug.distance_squared_to(_cleat_world(1)) <= _tug.distance_squared_to(_cleat_world(-1)) else -1
	var distance := _tug.distance_to(_cleat_world(best))
	if distance > HOOK_RANGE:
		_feedback = "離浮台繫點太遠，靠近一點再掛鉤"
		return
	if _tug_velocity.length() > HOOK_SPEED:
		_feedback = "船速太快，減速後再掛鉤"
		return
	_hooked = true
	_cleat = best
	_rope_length = clampf(distance + 0.2, ROPE_MIN, _rope_max())
	_over_tension = 0.0
	_feedback = "掛上%s繫點，繩長 %.1f" % ["前" if best == 1 else "後", _rope_length]

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
	# The deckhand holds whatever length the player last set.
	if _hooked and _reel != 0.0:
		_rope_length = clampf(_rope_length + _reel * REEL_SPEED * dt, ROPE_MIN, _rope_max())
	var forward := Vector2.from_angle(_tug_heading)
	var lateral := Vector2(-forward.y, forward.x)
	var speed := _tug_velocity.dot(forward)
	_tug_heading = wrapf(_tug_heading + _turn * TURN_RATE * clampf(absf(speed) / 1.2 + 0.35, 0.35, 1.0) * dt, -PI, PI)
	var engine := forward * (THRUST if _thrust > 0.0 else REVERSE_THRUST) * _thrust
	var tug_force := engine - forward * speed * TUG_DRAG - lateral * _tug_velocity.dot(lateral) * TUG_LATERAL_DRAG
	var pontoon_force := -_pontoon_velocity * PONTOON_DRAG
	var torque := -_pontoon_spin * PONTOON_ANGULAR_DRAG
	_tension = 0.0
	if _hooked:
		var cleat := _cleat_world(_cleat)
		var span := _tug - cleat
		var distance := span.length()
		if distance > _rope_length and distance > 0.0001:
			var direction := span / distance
			var cleat_velocity := _pontoon_velocity + Vector2(-(cleat - _pontoon).y, (cleat - _pontoon).x) * _pontoon_spin
			var stretch_rate := (_tug_velocity - cleat_velocity).dot(direction)
			var stiffness := ASSIST_ROPE_STIFFNESS if _assisted else ROPE_STIFFNESS
			_tension = maxf(0.0, stiffness * (distance - _rope_length) + ROPE_DAMPING * stretch_rate)
			pontoon_force += direction * _tension
			tug_force -= direction * _tension
			var arm := cleat - _pontoon
			torque += arm.x * direction.y * _tension - arm.y * direction.x * _tension
	_tug_velocity = (_tug_velocity + tug_force / TUG_MASS * dt).limit_length(MAX_TUG_SPEED)
	_pontoon_velocity += pontoon_force / _mass * dt
	_pontoon_spin += torque / (_mass * PONTOON_INERTIA) * dt
	var previous_pontoon := _pontoon
	var tug_state := _resolve(_tug + _tug_velocity * dt, TUG_RADIUS, _tug_velocity)
	_tug = tug_state[0]
	_tug_velocity = tug_state[1]
	var moved := _pontoon + _pontoon_velocity * dt
	var pontoon_contact := _contact(moved, PONTOON_RADIUS)
	var pontoon_state := _resolve(moved, PONTOON_RADIUS, _pontoon_velocity)
	_pontoon = pontoon_state[0]
	_pontoon_velocity = pontoon_state[1]
	_pontoon_heading = wrapf(_pontoon_heading + _pontoon_spin * dt, -PI, PI)
	_check_gates(previous_pontoon, _pontoon)
	_update_snag(pontoon_contact, dt)
	if _hooked:
		var limit := ASSIST_BREAK_TENSION if _assisted else BREAK_TENSION
		_over_tension = _over_tension + dt if _tension > limit else 0.0
		if _over_tension >= BREAK_HOLD:
			_hooked = false
			_breaks += 1
			_tension = 0.0
			_over_tension = 0.0
			_feedback = "拖繩繃斷！靠近浮台重新掛鉤"
	if _elapsed >= ROUND_SECONDS:
		_ended = true
		clear_input()
		_feedback = "時間到：通過 %d / 3 道狹灣" % _gates_passed.size()

func _update_snag(contact: bool, dt: float) -> void:
	var snagged := contact and _tension > SNAG_TENSION
	if snagged and not _snagged:
		_snags += 1
		_feedback = "浮台卡在灣角：放長繩或換角度"
	_snagged = snagged
	_snag_time = _snag_time + dt if snagged else 0.0
	# Assistance frees a stuck pontoon by slackening the rope in place.
	if _assisted and _hooked and _snag_time >= ASSIST_SNAG_SLACK_SECONDS:
		_rope_length = clampf(_tug.distance_to(_cleat_world(_cleat)) + 0.6, ROPE_MIN, _rope_max())
		_snag_time = 0.0
		_feedback = "船員原地鬆繩，浮台脫困"

func _check_gates(from: Vector2, to: Vector2) -> void:
	var next := _gates_passed.size()
	if next >= GATES.size():
		return
	var gate: Dictionary = GATES[next]
	if from.x < gate.x and to.x >= gate.x:
		var y := lerpf(from.y, to.y, (gate.x - from.x) / maxf(0.0001, to.x - from.x))
		for gap: Dictionary in gate.gaps:
			if absf(y - gap.center) <= gap.half:
				_gates_passed.append({"gate": gate.id, "side": gap.side, "elapsed": _elapsed})
				_side_pass = _side_pass or gap.side
				_feedback = "浮台通過第 %d 道%s" % [gate.id, "側灣" if gap.side else "狹灣"]
				if _all_gates():
					_feedback += "，拖進碼頭後按空白解繩"
				return

func _all_gates() -> bool:
	return _gates_passed.size() == GATES.size()

func walls() -> Array[Rect2]:
	return _walls.duplicate()

func _build_walls() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for gate: Dictionary in GATES:
		var gaps: Array = gate.gaps.duplicate()
		gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.center < b.center)
		var y := BOUNDS.position.y
		for gap: Dictionary in gaps:
			rects.append(Rect2(gate.x - GATE_HALF_THICKNESS, y, GATE_HALF_THICKNESS * 2.0, gap.center - gap.half - y))
			y = gap.center + gap.half
		rects.append(Rect2(gate.x - GATE_HALF_THICKNESS, y, GATE_HALF_THICKNESS * 2.0, BOUNDS.end.y - y))
	return rects

func _contact(point: Vector2, radius: float) -> bool:
	if not BOUNDS.grow(-radius).has_point(point):
		return true
	for rect in _walls:
		if rect.grow(radius).has_point(point):
			return true
	return false

## Pushes a circle out of bounds and wall rectangles, damping the impact speed.
## Returns [position, velocity].
func _resolve(point: Vector2, radius: float, velocity: Vector2) -> Array:
	var position := point
	var inner := BOUNDS.grow(-radius)
	var clamped := position.clamp(inner.position, inner.end)
	if clamped != position:
		var normal := (clamped - position).normalized()
		position = clamped
		if velocity.dot(normal) < 0.0:
			velocity -= normal * velocity.dot(normal) * (1.0 + WALL_RESTITUTION)
	for rect in _walls:
		var nearest := position.clamp(rect.position, rect.end)
		var offset := position - nearest
		var distance := offset.length()
		if distance >= radius:
			continue
		var normal := offset / distance if distance > 0.0001 else Vector2(signf(position.x - rect.get_center().x), 0.0)
		position = nearest + normal * radius
		if velocity.dot(normal) < 0.0:
			velocity -= normal * velocity.dot(normal) * (1.0 + WALL_RESTITUTION)
	return [position, velocity]

func snapshot() -> Dictionary:
	var gates: Array = []
	for gate: Dictionary in GATES:
		gates.append(gate.duplicate(true))
	var devil := _success and _side_pass and _breaks == 0
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": VARIANTS[_variant].name, "pontoon_mass": _mass,
		"elapsed": _elapsed, "remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success,
		"devil": devil, "devil_success": devil, "ordinary_eligible": _ended,
		"score": _gates_passed.size() * 100 + (100 if _success else 0), "mistakes": _breaks, "breaks": _breaks, "snags": _snags,
		"tug": _tug, "tug_heading": _tug_heading, "tug_velocity": _tug_velocity, "tug_speed": _tug_velocity.length(),
		"thrust": _thrust, "turn": _turn, "reel": _reel,
		"pontoon": _pontoon, "pontoon_heading": _pontoon_heading, "pontoon_velocity": _pontoon_velocity, "pontoon_speed": _pontoon_velocity.length(),
		"cleats": [_cleat_world(1), _cleat_world(-1)], "hooked": _hooked, "cleat": _cleat, "cleat_position": _cleat_world(_cleat),
		"rope_length": _rope_length, "rope_span": _tug.distance_to(_cleat_world(_cleat)), "rope_max": _rope_max(), "tension": _tension,
		"break_tension": ASSIST_BREAK_TENSION if _assisted else BREAK_TENSION, "snagged": _snagged,
		"gates": gates, "walls": _walls.duplicate(), "gates_passed": _gates_passed.duplicate(true), "side_pass": _side_pass,
		"dock_x": DOCK_X, "bounds": BOUNDS, "feedback": _feedback, "last_event": _feedback,
	}
