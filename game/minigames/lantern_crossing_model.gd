extends RefCounted

const LEFT := 0
const RIGHT := 1
const MIN_HEIGHT := 0
const MAX_HEIGHT := 8
const LAMP_COUNT := 4
const LAMP_POINTS := 150
const SWING_POINTS := 100
const LOSS_POINTS := 20
const TICK := 1.0 / 120.0
const ROUND_SECONDS := 124.0
const ASSISTED_SECONDS := 148.0

const LEFT_X := 0.08
const RIGHT_X := 0.92
const LOAD_LEFT := 0.115
const LOAD_RIGHT := 0.885
const RAIL_SPAN := RIGHT_X - LEFT_X
const START_HEIGHT := 2
const ROPE_BASE_Y := 0.445
const HEIGHT_STEP := 0.038
const HOIST_SPEED := 0.70
const BODY_LENGTH := 0.136
const CLIP_LENGTH := 0.087
const LANTERN_RADIUS := 0.026
const MAX_SPEED := 0.46
const GRADE_ACCELERATION := 3.65
const TROLLEY_DRAG := 0.34
const BRAKE_DECELERATION := 1.45
const PENDULUM_GRAVITY := 0.92
const NORMAL_DAMPING := 1.48
const ASSIST_DAMPING := 2.40
const NORMAL_SWING := 0.89
const ASSIST_SWING := 0.75

const LAYOUTS := [
	{
		"hooks": [Vector2(0.35, 0.380), Vector2(0.65, 0.342), Vector2(0.77, 0.304), Vector2(0.26, 0.418)],
		"sign": Rect2(0.430, 0.4705, 0.052, 0.125),
	},
	{
		"hooks": [Vector2(0.42, 0.342), Vector2(0.76, 0.418), Vector2(0.69, 0.380), Vector2(0.22, 0.304)],
		"sign": Rect2(0.550, 0.465, 0.052, 0.130),
	},
]

var _layout := 0
var _assisted := false
var _job := 0
var _hung := 0
var _selected := LEFT
var _helper := -1
var _height_left := START_HEIGHT
var _height_right := START_HEIGHT
var _left_y := 0.0
var _right_y := 0.0
var _cart_x := LOAD_LEFT
var _velocity := 0.0
var _angle := 0.0
var _angular_velocity := 0.0
var _clip_velocity := Vector2.ZERO
var _loaded := false
var _braking := true
var _stalled := false
var _swing_proven := false
var _upright_would_hit := false
var _committed_swing := false
var _participated := false
var _mistakes := 0
var _ticks := 0
var _accumulator := 0.0
var _ended := false
var _feedback := ""
var _notes: Array[int] = []
var _hooks := PackedVector2Array()


func _init() -> void:
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, LAYOUTS.size())
	_hooks = PackedVector2Array(LAYOUTS[_layout].hooks)
	_job = 0
	_hung = 0
	_committed_swing = false
	_participated = false
	_mistakes = 0
	_ticks = 0
	_accumulator = 0.0
	_ended = false
	_notes.clear()
	_restore_cart()
	_feedback = "先在吊台接燈，再升高出發端。"


func select_endpoint(endpoint: int) -> bool:
	if _ended or _stalled or endpoint not in [LEFT, RIGHT]:
		return false
	_selected = endpoint
	if _helper == endpoint:
		_helper = -1
		_feedback = "已接回這端絞盤。"
	return true


func adjust_endpoint(direction: int) -> bool:
	if _ended or _stalled or direction not in [-1, 1]:
		return false
	var height := _height_left if _selected == LEFT else _height_right
	var adjusted := clampi(height + direction, MIN_HEIGHT, MAX_HEIGHT)
	if adjusted == height:
		return false
	if _selected == LEFT:
		_height_left = adjusted
	else:
		_height_right = adjusted
	return true


func toggle_brake() -> bool:
	if _ended or _stalled or not _loaded:
		return false
	_braking = not _braking
	_feedback = "煞車已扣住，仍可調高兩端。" if _braking else "滑車沿斜坡移動。"
	_note(8)
	return true


func interact() -> bool:
	if _ended or _stalled:
		return false
	if not _loaded:
		_loaded = true
		_feedback = "已接燈。調好坡度，鬆煞車再滑送。"
		_note(9)
		return true
	if not _can_hook():
		_feedback = "先煞停，再讓燈扣對準掛鉤。"
		return false

	_hung += 1
	_committed_swing = _committed_swing or _swing_proven
	_note(14)
	if _hung == LAMP_COUNT:
		_loaded = false
		_ended = true
		_feedback = "四盞燈都已掛好。"
	else:
		_job += 1
		_restore_cart()
		_feedback = "掛好了。下一盞已送到對側吊台。"
	return true


func recover() -> bool:
	if _ended or not (_loaded or _stalled):
		return false
	if not _stalled and absf(_cart_x - _source_x()) >= 0.02:
		_mistakes += 1
	_restore_cart()
	_feedback = "已重送這一盞，先前掛好的燈保留。"
	return true


func toggle_helper() -> bool:
	if _ended or _stalled or not _assisted:
		return false
	if _helper >= 0:
		_helper = -1
		_feedback = "兩端都由你操作。"
	else:
		# The opposite hoist holds its requested detent. Only an explicit
		# player selection can take that hoist back or change the grade.
		_helper = 1 - _selected
		_feedback = "幫手固定對側現在的高度。"
	return true


func clear_input() -> void:
	# Commands are individual presses. The driver owns held-input state.
	pass


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_ticks += 1
		if not _stalled:
			_advance()
		if float(_ticks) * TICK >= _seconds_limit():
			_ended = true
			_feedback = "收攤時間到，已掛好 %d / %d 盞。" % [_hung, LAMP_COUNT]
			_accumulator = 0.0
			return


func _restore_cart() -> void:
	_selected = LEFT if _job % 2 == 0 else RIGHT
	_helper = -1
	_height_left = START_HEIGHT
	_height_right = START_HEIGHT
	_left_y = _height_to_y(START_HEIGHT)
	_right_y = _left_y
	_cart_x = _source_x()
	_velocity = 0.0
	_angle = 0.0
	_angular_velocity = 0.0
	_clip_velocity = Vector2.ZERO
	_loaded = false
	_braking = true
	_stalled = false
	_swing_proven = false
	_upright_would_hit = false


func _advance() -> void:
	var old_x := _cart_x
	var old_left := _left_y
	var old_right := _right_y
	var old_angle := _angle
	var old_cart := _trolley()
	_left_y = move_toward(_left_y, _height_to_y(_height_left), HOIST_SPEED * TICK)
	_right_y = move_toward(_right_y, _height_to_y(_height_right), HOIST_SPEED * TICK)
	if not _loaded:
		return

	var old_velocity := _velocity
	if _braking:
		_velocity = move_toward(_velocity, 0.0, BRAKE_DECELERATION * TICK)
	else:
		var acceleration := GRADE_ACCELERATION * (_right_y - _left_y) - TROLLEY_DRAG * _velocity
		_velocity = clampf(_velocity + acceleration * TICK, -MAX_SPEED, MAX_SPEED)
	var next_x := _cart_x + _velocity * TICK
	_cart_x = clampf(next_x, LEFT_X, RIGHT_X)
	if next_x != _cart_x:
		_velocity = 0.0
	_advance_swing((_velocity - old_velocity) / TICK)
	var old_clip := old_cart + Vector2(sin(old_angle), cos(old_angle)) * CLIP_LENGTH
	_clip_velocity = (_lantern_at(CLIP_LENGTH) - old_clip) / TICK

	var sign := _current_sign()
	if sign.has_area():
		var new_cart := _trolley()
		var old_body := old_cart + Vector2(sin(old_angle), cos(old_angle)) * BODY_LENGTH
		var body := _lantern_at(BODY_LENGTH)
		if _sweep_hits_sign(old_body, body, sign):
			_cart_x = old_x
			_left_y = old_left
			_right_y = old_right
			_angle = old_angle
			_stall()
			return
		_track_crossing(old_cart, new_cart, body, sign)

	if absf(_cart_x - _source_x()) >= 0.17:
		_participated = true


func _advance_swing(trolley_acceleration: float) -> void:
	var damping := ASSIST_DAMPING if _assisted else NORMAL_DAMPING
	var bound := ASSIST_SWING if _assisted else NORMAL_SWING
	var torque := -(PENDULUM_GRAVITY * sin(_angle) + trolley_acceleration * cos(_angle)) / BODY_LENGTH
	_angular_velocity += (torque - damping * _angular_velocity) * TICK
	var next_angle := _angle + _angular_velocity * TICK
	_angle = clampf(next_angle, -bound, bound)
	if _angle != next_angle:
		_angular_velocity = 0.0


func _stall() -> void:
	_stalled = true
	_braking = true
	_velocity = 0.0
	_angular_velocity = 0.0
	_clip_velocity = Vector2.ZERO
	_swing_proven = false
	_upright_would_hit = false
	_mistakes += 1
	_feedback = "燈身碰到招牌。重送這盞再試。"
	_note(3)


func _track_crossing(old_cart: Vector2, cart: Vector2, body: Vector2, sign: Rect2) -> void:
	if _swing_proven:
		return
	var direction := 1.0 if _job % 2 == 0 else -1.0
	var approach := sign.position.x if direction > 0.0 else sign.end.x
	var exit := sign.end.x if direction > 0.0 else sign.position.x
	if maxf(direction * (cart.x - approach), direction * (body.x - approach)) < -LANTERN_RADIUS:
		_upright_would_hit = false
		return
	# Compare the same trolley path with a freely hanging lantern. Changing
	# heights while stationary never earns the swing clearance by itself.
	if direction * (cart.x - old_cart.x) > 0.0000001:
		var drop := Vector2(0, BODY_LENGTH)
		_upright_would_hit = _upright_would_hit or _sweep_hits_sign(old_cart + drop, cart + drop, sign)
	if _upright_would_hit and minf(direction * (cart.x - exit), direction * (body.x - exit)) > LANTERN_RADIUS:
		_swing_proven = true
		_feedback = "燈擺繞過了招牌。把這盞掛好才算完成。"
		_note(12)


func _sweep_hits_sign(from: Vector2, to: Vector2, sign: Rect2) -> bool:
	if not _segment_hits_rect(from, to, sign.grow(LANTERN_RADIUS)):
		return false
	# The swept circle sees a rounded rectangle: two strips and four
	# round corners. A square expansion would reject clean corner arcs.
	var lower := sign.position
	var upper := sign.end
	var radius := LANTERN_RADIUS
	var horizontal := Rect2(lower - Vector2(radius, 0.0), sign.size + Vector2(2.0 * radius, 0.0))
	var vertical := Rect2(lower - Vector2(0.0, radius), sign.size + Vector2(0.0, 2.0 * radius))
	if _segment_hits_rect(from, to, horizontal) or _segment_hits_rect(from, to, vertical):
		return true
	var delta := to - from
	var length_squared := delta.length_squared()
	for corner: Vector2 in [lower, Vector2(lower.x, upper.y), Vector2(upper.x, lower.y), upper]:
		var along := clampf((corner - from).dot(delta) / length_squared, 0.0, 1.0) if length_squared > 0.0 else 0.0
		if (from + delta * along).distance_squared_to(corner) <= radius * radius:
			return true
	return false


func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		var delta: float = to[axis] - from[axis]
		if is_zero_approx(delta):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return false
			continue
		var near: float = (rect.position[axis] - from[axis]) / delta
		var far: float = (rect.end[axis] - from[axis]) / delta
		enter = maxf(enter, minf(near, far))
		leave = minf(leave, maxf(near, far))
		if enter > leave:
			return false
	return true


func _height_to_y(height: int) -> float:
	return ROPE_BASE_Y - HEIGHT_STEP * float(height)


func _source_x() -> float:
	return LOAD_LEFT if _job % 2 == 0 else LOAD_RIGHT


func _trolley() -> Vector2:
	return Vector2(_cart_x, lerpf(_left_y, _right_y, (_cart_x - LEFT_X) / RAIL_SPAN))


func _lantern_at(length: float) -> Vector2:
	return _trolley() + Vector2(sin(_angle), cos(_angle)) * length


func _current_sign() -> Rect2:
	return LAYOUTS[_layout].sign if _job >= 2 else Rect2()


func _can_hook() -> bool:
	if _ended or _stalled or not _loaded:
		return false
	var window := 0.037 if _assisted else 0.026
	return _lantern_at(CLIP_LENGTH).distance_squared_to(_hooks[_job]) <= window * window and _clip_velocity.length_squared() <= 0.15 * 0.15


func _seconds_limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _note(note: int) -> void:
	if _notes.size() < 8:
		_notes.append(note)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func snapshot() -> Dictionary:
	var success := _hung == LAMP_COUNT
	var devil := success and _committed_swing
	var score := maxi(0, _hung * LAMP_POINTS + int(devil) * SWING_POINTS - _mistakes * LOSS_POINTS)
	var elapsed := minf(float(_ticks) * TICK, _seconds_limit())
	return {
		"layout": _layout, "assisted": _assisted, "selected_endpoint": _selected,
		"height_left": _height_left, "height_right": _height_right, "helper_endpoint": _helper,
		"rope_left": Vector2(LEFT_X, _left_y), "rope_right": Vector2(RIGHT_X, _right_y),
		"trolley": _trolley(), "velocity": _velocity, "swing": _angle,
		"lantern": _lantern_at(BODY_LENGTH), "lantern_hook": _lantern_at(CLIP_LENGTH),
		"lantern_radius": LANTERN_RADIUS, "sign": _current_sign(), "hooks": _hooks.duplicate(),
		"source": Vector2(_source_x(), _height_to_y(START_HEIGHT) + CLIP_LENGTH), "target": _hooks[_job],
		"job": _job, "hung": _hung, "loaded": _loaded, "braking": _braking, "stalled": _stalled,
		"can_load": not _loaded and not _stalled and not _ended, "can_hook": _can_hook(),
		"swing_proven": _swing_proven, "mistakes": _mistakes,
		"elapsed": elapsed, "remaining": _seconds_limit() - elapsed, "success": success,
		"ended": _ended, "devil": devil, "score": score,
		"ordinary_eligible": _ended and (_participated or success), "feedback": _feedback,
	}
