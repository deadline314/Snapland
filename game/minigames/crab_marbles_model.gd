extends RefCounted
class_name CrabMarblesModel

## Sand tray in planar X/Y (y grows toward the player). One marble rolls at a
## time under sand friction and slope pull; walls and rocks reflect it.
const ROUND_SECONDS := 120.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 120.0
const TRAY := Rect2(-5.0, -3.0, 10.0, 6.0)
const LAUNCHER := Vector2(0.0, 2.55)
const BALL_RADIUS := 0.14
const AIM_LIMIT := deg_to_rad(70.0)
const AIM_SPEED := deg_to_rad(45.0)
const CHARGE_SECONDS := 1.2
const MIN_SPEED := 2.2
const MAX_SPEED := 7.4
const FRICTION := 1.5
const WALL_RESTITUTION := 0.78
const ROCK_RESTITUTION := 0.7
const GATE_RADIUS := 0.34
const OPEN_SPEED := 0.6
const GATE_SLOWDOWN := 0.8
const STOP_SPEED := 0.05
const MAX_SHOT_SECONDS := 9.0
const BALLS := 3
const ASSIST_BALLS := 5
const GATE_POINTS := 100
const SPARE_POINTS := 50
const TRAIL_LIMIT := 160
## Retries swap slope patches and which gate hides behind the rock.
const LAYOUTS := [
	{"name": "東坡", "gates": [Vector2(-3.3, -1.9), Vector2(0.4, -2.45), Vector2(3.4, -0.9)],
		"rocks": [{"center": Vector2(0.25, -0.7), "radius": 0.62}, {"center": Vector2(-2.6, 0.9), "radius": 0.45}],
		"slopes": [{"rect": Rect2(1.6, -2.4, 3.2, 2.6), "pull": Vector2(0.0, 0.9)}, {"rect": Rect2(-4.8, -2.9, 2.2, 1.4), "pull": Vector2(0.7, 0.0)}]},
	{"name": "西坡", "gates": [Vector2(-3.5, -0.8), Vector2(-0.3, -2.45), Vector2(3.2, -2.0)],
		"rocks": [{"center": Vector2(-0.2, -0.8), "radius": 0.62}, {"center": Vector2(2.1, 0.5), "radius": 0.45}],
		"slopes": [{"rect": Rect2(-4.8, -2.4, 3.2, 2.6), "pull": Vector2(0.0, 0.9)}, {"rect": Rect2(2.6, -2.9, 2.2, 1.4), "pull": Vector2(-0.7, 0.0)}]},
]

var _assisted := false
var _variant := 0
var _layout: Dictionary = {}
var _elapsed := 0.0
var _aim := 0.0
var _aim_input := 0.0
var _charging := false
var _power := 0.0
var _balls_left := BALLS
var _opened: Array[bool] = [false, false, false]
var _ball_active := false
var _ball := LAUNCHER
var _velocity := Vector2.ZERO
var _shot_time := 0.0
var _shot_bounces := 0
var _shot_gates: Array[int] = []
var _shots: Array[Dictionary] = []
var _trail: PackedVector2Array = PackedVector2Array()
var _bounce_points: Array[Vector2] = []
var _double_after_bounce := false
var _ended := false
var _success := false
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, LAYOUTS.size())
	_layout = LAYOUTS[_variant]
	_elapsed = 0.0
	_aim = 0.0
	_aim_input = 0.0
	_charging = false
	_power = 0.0
	_balls_left = ASSIST_BALLS if assisted else BALLS
	_opened = [false, false, false]
	_ball_active = false
	_ball = LAUNCHER
	_velocity = Vector2.ZERO
	_shot_time = 0.0
	_shot_bounces = 0
	_shot_gates.clear()
	_shots.clear()
	_trail = PackedVector2Array()
	_bounce_points.clear()
	_double_after_bounce = false
	_ended = false
	_success = false
	_feedback = "左右瞄準，按住空白蓄力、放開彈出"

func set_aim_input(value: float) -> void:
	if not _ended and is_finite(value):
		_aim_input = clampf(value, -1.0, 1.0)

func clear_input() -> void:
	_aim_input = 0.0
	if _charging:
		_charging = false
		_power = 0.0
		_feedback = "蓄力已取消"

## Charging only starts while the tray is clear; releasing fires the marble.
func set_charging(value: bool) -> void:
	if _ended:
		return
	if value:
		if _ball_active:
			_feedback = "等彈珠停下再蓄力"
			return
		if _balls_left <= 0:
			return
		_charging = true
		_power = 0.0
		return
	if not _charging:
		return
	_charging = false
	_fire(_power)

func _fire(power: float) -> void:
	_balls_left -= 1
	_ball_active = true
	_ball = LAUNCHER
	_velocity = direction() * lerpf(MIN_SPEED, MAX_SPEED, clampf(power, 0.0, 1.0))
	_shot_time = 0.0
	_shot_bounces = 0
	_shot_gates.clear()
	_trail = PackedVector2Array([LAUNCHER])
	_bounce_points.clear()
	_feedback = "放出彈珠（力道 %d%%）" % roundi(power * 100.0)

func direction() -> Vector2:
	return Vector2(sin(_aim), -cos(_aim))

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, SUBSTEP)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	if not _ball_active:
		_aim = clampf(_aim + _aim_input * AIM_SPEED * dt, -AIM_LIMIT, AIM_LIMIT)
	if _charging:
		_power = minf(1.0, _power + dt / CHARGE_SECONDS)
	if _ball_active:
		var event := integrate(_ball, _velocity, _opened, dt)
		_ball = event.position
		_velocity = event.velocity
		_shot_time += dt
		if event.bounced:
			_shot_bounces += 1
			_bounce_points.append(_ball)
			_feedback = "撞到%s反彈" % event.surface
		for gate: int in event.opened:
			_opened[gate] = true
			_shot_gates.append(gate)
			_feedback = "撞開第 %d 扇蟹門" % (gate + 1)
			if _shot_gates.size() >= 2 and _shot_bounces >= 1:
				_double_after_bounce = true
		if _trail.size() < TRAIL_LIMIT and (_trail.is_empty() or _trail[_trail.size() - 1].distance_to(_ball) > 0.12):
			_trail.append(_ball)
		if _velocity.length() < STOP_SPEED or _shot_time >= MAX_SHOT_SECONDS:
			_settle_shot()
	if not _ended and _elapsed >= ROUND_SECONDS:
		_finish("時間到：撞開 %d / 3 扇蟹門" % _opened_count())

func _settle_shot() -> void:
	_ball_active = false
	_velocity = Vector2.ZERO
	_shots.append({"gates": _shot_gates.duplicate(), "bounces": _shot_bounces, "stop": _ball})
	if _opened_count() == 3:
		_success = true
		_finish("三扇蟹門都開了")
	elif _balls_left <= 0:
		_finish("彈珠用完：撞開 %d / 3 扇蟹門" % _opened_count())
	elif _shot_gates.is_empty():
		_feedback = "彈珠停在沙上；看軌跡調整角度或力道"

func _finish(message: String) -> void:
	_ended = true
	_charging = false
	_aim_input = 0.0
	_feedback = message

## One fixed-step integration of a rolling marble. Pure: the caller owns state.
func integrate(position: Vector2, velocity: Vector2, opened: Array, dt: float) -> Dictionary:
	var pull := Vector2.ZERO
	for slope: Dictionary in _layout.slopes:
		if slope.rect.has_point(position):
			pull += slope.pull
	velocity += pull * dt
	var speed := velocity.length()
	if speed > 0.0:
		velocity = velocity.normalized() * maxf(0.0, speed - FRICTION * dt)
	var next := position + velocity * dt
	var bounced := false
	var surface := ""
	var inner := TRAY.grow(-BALL_RADIUS)
	if next.x < inner.position.x or next.x > inner.end.x:
		next.x = clampf(next.x, inner.position.x, inner.end.x)
		velocity.x = -velocity.x * WALL_RESTITUTION
		bounced = true
		surface = "濕沙堤"
	if next.y < inner.position.y or next.y > inner.end.y:
		next.y = clampf(next.y, inner.position.y, inner.end.y)
		velocity.y = -velocity.y * WALL_RESTITUTION
		bounced = true
		surface = "濕沙堤"
	for rock: Dictionary in _layout.rocks:
		var offset: Vector2 = next - rock.center
		var limit: float = rock.radius + BALL_RADIUS
		if offset.length() < limit:
			var normal := offset.normalized() if offset.length() > 0.0001 else Vector2.DOWN
			next = rock.center + normal * limit
			if velocity.dot(normal) < 0.0:
				velocity = (velocity - normal * velocity.dot(normal) * 2.0) * ROCK_RESTITUTION
			bounced = true
			surface = "礁石"
	var newly: Array[int] = []
	for index in 3:
		if opened[index]:
			continue
		var gate: Vector2 = _layout.gates[index]
		if Geometry2D.get_closest_point_to_segment(gate, position, next).distance_to(gate) <= GATE_RADIUS + BALL_RADIUS and velocity.length() >= OPEN_SPEED:
			newly.append(index)
			velocity *= GATE_SLOWDOWN
	return {"position": next, "velocity": velocity, "bounced": bounced, "surface": surface, "opened": newly}

## Pure preview of a full shot from the launcher (used by tests and solvers).
func simulate(aim: float, power: float, opened: Array = []) -> Dictionary:
	var gates_open: Array = opened.duplicate() if not opened.is_empty() else _opened.duplicate()
	var position := LAUNCHER
	var velocity := Vector2(sin(aim), -cos(aim)) * lerpf(MIN_SPEED, MAX_SPEED, clampf(power, 0.0, 1.0))
	var hit: Array[int] = []
	var bounces := 0
	var double_after_bounce := false
	var time := 0.0
	while time < MAX_SHOT_SECONDS and velocity.length() >= STOP_SPEED:
		var event := integrate(position, velocity, gates_open, SUBSTEP)
		position = event.position
		velocity = event.velocity
		time += SUBSTEP
		if event.bounced:
			bounces += 1
		for gate: int in event.opened:
			gates_open[gate] = true
			hit.append(gate)
			if hit.size() >= 2 and bounces >= 1:
				double_after_bounce = true
	return {"gates": hit, "bounces": bounces, "stop": position, "double_after_bounce": double_after_bounce}

## First straight segment from the launcher to the first wall or rock (assist preview).
func first_segment() -> PackedVector2Array:
	var start := LAUNCHER
	var dir := direction()
	var best := 30.0
	var inner := TRAY.grow(-BALL_RADIUS)
	for t in [(inner.position.x - start.x) / dir.x if dir.x < 0.0 else INF, (inner.end.x - start.x) / dir.x if dir.x > 0.0 else INF, (inner.position.y - start.y) / dir.y if dir.y < 0.0 else INF]:
		if t > 0.0:
			best = minf(best, t)
	for rock: Dictionary in _layout.rocks:
		var hit: Variant = Geometry2D.segment_intersects_circle(start, start + dir * best, rock.center, rock.radius + BALL_RADIUS)
		if hit is float and hit >= 0.0:
			best = minf(best, best * hit)
	return PackedVector2Array([start, start + dir * best])

## The helper reads only the visible straight line to the nearest closed gate.
func helper_aim() -> float:
	var best := INF
	var aim := 0.0
	for index in 3:
		if _opened[index]:
			continue
		var gate: Vector2 = _layout.gates[index]
		var offset := gate - LAUNCHER
		if offset.length() < best:
			best = offset.length()
			aim = clampf(atan2(offset.x, -offset.y), -AIM_LIMIT, AIM_LIMIT)
	return aim

func _opened_count() -> int:
	return _opened.count(true)

func snapshot() -> Dictionary:
	var opened := _opened_count()
	var devil := _success and _double_after_bounce
	var gates: Array = []
	for index in 3:
		gates.append({"index": index, "position": _layout.gates[index], "open": _opened[index]})
	return {
		"assisted": _assisted, "variant": _variant, "layout_name": _layout.name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil, "devil_success": devil,
		"ordinary_eligible": _ended, "score": opened * GATE_POINTS + (_balls_left * SPARE_POINTS if _success else 0),
		"mistakes": 0, "opened": opened, "balls_left": _balls_left, "balls_total": ASSIST_BALLS if _assisted else BALLS,
		"aim": _aim, "aim_input": _aim_input, "charging": _charging, "power": _power, "ball_active": _ball_active, "ball": _ball,
		"velocity": _velocity, "speed": _velocity.length(), "shot_bounces": _shot_bounces, "shot_gates": _shot_gates.duplicate(),
		"shots": _shots.duplicate(true), "trail": _trail, "bounce_points": _bounce_points.duplicate(), "double_after_bounce": _double_after_bounce,
		"gates": gates, "rocks": _layout.rocks.duplicate(true), "slopes": _layout.slopes.duplicate(true), "tray": TRAY, "launcher": LAUNCHER,
		"first_segment": first_segment() if _assisted else PackedVector2Array(), "helper_aim": helper_aim(),
		"feedback": _feedback, "last_event": _feedback,
	}
