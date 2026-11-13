extends RefCounted
class_name SailChaseModel

## Planar sailing (world X/Z, +y is south). Wind angles are the direction the
## wind blows toward. Boat speed comes from a simple polar times trim efficiency.
const ROUND_SECONDS := 150.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const BOUNDS := Rect2(-14.0, -8.0, 28.0, 16.0)
const START := Vector2(-11.5, -5.0)
const START_HEADING := 0.0
const NO_GO := deg_to_rad(42.0)
const MAX_BOAT_SPEED := 3.1
const ACCELERATION := 0.9
const TURN_RATE := 1.5
const TRIM_RATE := deg_to_rad(55.0)
const AUTO_TRIM_RATE := deg_to_rad(25.0)
const OUTER_WIND := 1.15
const INNER_WIND := 0.8
const INNER_RECT := Rect2(-7.0, -3.4, 14.0, 6.8)
const LIGHTSHIP_SPEED := 2.0
const SPURT_SPEED := 3.6
const SPURT_SECONDS := 5.0
const CATCH_RADIUS := 1.0
const CATCHES := 3
const GYBE_WINDOW := 6.0
const FORECAST := 4.0
const ASSIST_FORECAST := 8.0
const WOOD_RADIUS := 0.55
const WOOD_SLOW := 0.3
const BOAT_RADIUS := 0.35
const CATCH_POINTS := 100
const ROUTE := [Vector2(-9.0, -5.0), Vector2(9.0, -5.0), Vector2(9.0, 5.0), Vector2(-9.0, 5.0)]
## Retries change when and where the wind turns and where driftwood floats.
const VARIANTS := [
	{"name": "北風轉東北", "winds": [[0.0, 90.0], [45.0, 135.0], [95.0, 60.0]], "wood": [Vector2(2.0, -5.6), Vector2(9.6, 0.5), Vector2(-3.0, 4.4)]},
	{"name": "北風轉西北", "winds": [[0.0, 90.0], [40.0, 50.0], [90.0, 120.0]], "wood": [Vector2(-2.0, -4.5), Vector2(8.4, 2.0), Vector2(1.5, 5.6)]},
]

var _assisted := false
var _variant := 0
var _elapsed := 0.0
var _position := START
var _heading := START_HEADING
var _speed := 0.0
var _rudder := 0.0
var _trim := deg_to_rad(45.0)
var _trim_input := 0.0
var _ship_distance := 3.0
var _spurt := 0.0
var _catches: Array[Dictionary] = []
var _gybes: Array[float] = []
var _bumps := 0
var _in_contact := false
var _gybe_catch := false
var _last_side := 0
var _ended := false
var _success := false
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, VARIANTS.size())
	_elapsed = 0.0
	_position = START
	_heading = START_HEADING
	_speed = 0.0
	_rudder = 0.0
	_trim = deg_to_rad(45.0)
	_trim_input = 0.0
	_ship_distance = 3.0
	_spurt = 0.0
	_catches.clear()
	_gybes.clear()
	_bumps = 0
	_in_contact = false
	_gybe_catch = false
	_last_side = _downwind_side()
	_ended = false
	_success = false
	_feedback = "轉舵追上燈船；Q／E 收放帆角讓帆吃滿風"

func set_rudder(value: float) -> void:
	if not _ended and is_finite(value):
		_rudder = clampf(value, -1.0, 1.0)

func set_trim_input(value: float) -> void:
	if not _ended and is_finite(value):
		_trim_input = clampf(value, -1.0, 1.0)

func clear_input() -> void:
	_rudder = 0.0
	_trim_input = 0.0

func wind_at(time: float) -> float:
	var angle := 90.0
	for row: Array in VARIANTS[_variant].winds:
		if time >= float(row[0]):
			angle = float(row[1])
	return deg_to_rad(angle)

func next_shift() -> Dictionary:
	for row: Array in VARIANTS[_variant].winds:
		if float(row[0]) > _elapsed:
			return {"at": float(row[0]), "in": float(row[0]) - _elapsed, "wind": deg_to_rad(float(row[1]))}
	return {}

## Angle between the bow and the direction the wind comes from (0 = head to wind).
func point_of_sail(heading: float, wind: float) -> float:
	return absf(angle_difference(heading, wind + PI))

func optimal_trim(alpha: float) -> float:
	return clampf(alpha * 0.5, deg_to_rad(10.0), deg_to_rad(90.0))

## Fraction of top speed for a point of sail: nothing inside the no-go zone.
func polar(alpha: float) -> float:
	if alpha < NO_GO:
		return 0.0
	var reach := clampf((alpha - NO_GO) / (deg_to_rad(95.0) - NO_GO), 0.0, 1.0)
	return lerpf(0.45, 1.0, reach) if alpha <= deg_to_rad(95.0) else lerpf(1.0, 0.78, (alpha - deg_to_rad(95.0)) / (PI - deg_to_rad(95.0)))

func trim_efficiency(alpha: float, trim: float) -> float:
	var error := absf(trim - optimal_trim(alpha))
	return clampf(cos(minf(error * 1.6, PI / 2.0)), 0.0, 1.0)

func region_factor(point: Vector2) -> float:
	return INNER_WIND if INNER_RECT.has_point(point) else OUTER_WIND

func target_speed(point: Vector2, heading: float, trim: float, wind: float) -> float:
	var alpha := point_of_sail(heading, wind)
	return MAX_BOAT_SPEED / OUTER_WIND * region_factor(point) * polar(alpha) * trim_efficiency(alpha, trim)

func lightship_position(distance: float) -> Vector2:
	var total := 0.0
	var lengths: Array[float] = []
	for index in ROUTE.size():
		var length: float = ROUTE[index].distance_to(ROUTE[(index + 1) % ROUTE.size()])
		lengths.append(length)
		total += length
	var d := fposmod(distance, total)
	for index in ROUTE.size():
		if d <= lengths[index]:
			return ROUTE[index].lerp(ROUTE[(index + 1) % ROUTE.size()], d / lengths[index])
		d -= lengths[index]
	return ROUTE[0]

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, SUBSTEP)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _downwind_side() -> int:
	return signi(roundi(signf(angle_difference(wind_at(_elapsed), _heading) + 0.0001)))

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	var wind := wind_at(_elapsed)
	_heading = wrapf(_heading + _rudder * TURN_RATE * clampf(_speed / 1.2 + 0.4, 0.4, 1.0) * dt, -PI, PI)
	var alpha := point_of_sail(_heading, wind)
	if _trim_input != 0.0:
		_trim = clampf(_trim + _trim_input * TRIM_RATE * dt, deg_to_rad(5.0), deg_to_rad(90.0))
	elif _assisted:
		# Assistance eases the sail back toward its best angle when untouched.
		_trim = move_toward(_trim, optimal_trim(alpha), AUTO_TRIM_RATE * dt)
	var goal := target_speed(_position, _heading, _trim, wind)
	_speed = move_toward(_speed, goal, ACCELERATION * dt)
	var next := _position + Vector2.from_angle(_heading) * _speed * dt
	var inner := BOUNDS.grow(-BOAT_RADIUS)
	if not inner.has_point(next):
		next = next.clamp(inner.position, inner.end)
		_speed *= 0.5
	_position = next
	_check_wood()
	_track_gybe(wind, alpha)
	_ship_distance += (SPURT_SPEED if _spurt > 0.0 else LIGHTSHIP_SPEED) * dt
	_spurt = maxf(0.0, _spurt - dt)
	if _spurt <= 0.0 and _position.distance_to(lightship_position(_ship_distance)) <= CATCH_RADIUS:
		_catch()
	if not _ended and _elapsed >= ROUND_SECONDS:
		_ended = true
		clear_input()
		_feedback = "時間到：追上燈船 %d / %d 次" % [_catches.size(), CATCHES]

func _check_wood() -> void:
	var touching := false
	for wood: Vector2 in VARIANTS[_variant].wood:
		if _position.distance_to(wood) <= WOOD_RADIUS + BOAT_RADIUS:
			touching = true
	if touching and not _in_contact:
		_bumps += 1
		_speed *= WOOD_SLOW
		_feedback = "撞到浮木，船速大減"
	_in_contact = touching

## A gybe is the stern crossing the wind while running before it.
func _track_gybe(wind: float, alpha: float) -> void:
	var side := _downwind_side()
	if side != _last_side and alpha > deg_to_rad(140.0):
		_gybes.append(_elapsed)
		_feedback = "順風換舷！"
	_last_side = side

func _catch() -> void:
	var after_gybe: bool = not _gybes.is_empty() and _elapsed - _gybes[-1] <= GYBE_WINDOW and (_catches.is_empty() or _gybes[-1] > _catches[-1].elapsed)
	_catches.append({"elapsed": _elapsed, "after_gybe": after_gybe})
	_gybe_catch = _gybe_catch or after_gybe
	_spurt = SPURT_SECONDS
	_feedback = "追上燈船 %d / %d！%s" % [_catches.size(), CATCHES, "換舷超越成功" if after_gybe else "燈船加速拉開了"]
	if _catches.size() >= CATCHES:
		_ended = true
		_success = true
		clear_input()
		_feedback = "三次追上燈船"

func snapshot() -> Dictionary:
	var wind := wind_at(_elapsed)
	var alpha := point_of_sail(_heading, wind)
	var shift := next_shift()
	var forecast := ASSIST_FORECAST if _assisted else FORECAST
	var flag_wind: float = shift.wind if not shift.is_empty() and shift["in"] <= forecast else wind
	var devil := _success and _gybe_catch
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": VARIANTS[_variant].name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil, "devil_success": devil,
		"ordinary_eligible": _ended, "score": _catches.size() * CATCH_POINTS, "mistakes": _bumps, "bumps": _bumps,
		"position": _position, "heading": _heading, "speed": _speed, "rudder": _rudder, "trim": _trim, "trim_input": _trim_input,
		"wind": wind, "point_of_sail": alpha, "in_irons": alpha < NO_GO, "efficiency": trim_efficiency(alpha, _trim),
		"optimal_trim": optimal_trim(alpha), "region": "inner" if INNER_RECT.has_point(_position) else "outer", "region_factor": region_factor(_position),
		"flag_wind": flag_wind, "shift": shift, "shift_visible": not shift.is_empty() and shift["in"] <= forecast,
		"helper_trim": optimal_trim(point_of_sail(_heading, flag_wind)) * 0.85,
		"lightship": lightship_position(_ship_distance), "lightship_heading": (lightship_position(_ship_distance + 0.1) - lightship_position(_ship_distance)).angle(),
		"lightship_distance": _ship_distance, "spurt": _spurt, "catches": _catches.size(), "catch_log": _catches.duplicate(true),
		"gybes": _gybes.size(), "gybe_catch": _gybe_catch, "wood": VARIANTS[_variant].wood.duplicate(), "route": ROUTE.duplicate(),
		"bounds": BOUNDS, "inner": INNER_RECT, "feedback": _feedback, "last_event": _feedback,
	}
