extends RefCounted

const ROUND_SECONDS := 75
const STEP := 1.0 / 120.0
const HALF_LENGTH := 3.25
const BOARD_HEIGHT := 1.9
const PAN_HEIGHT := 0.79
const PAN_X := 4.14
const SIDE_X := 5.58
const PAN_HALF_WIDTH := 0.38
const SIDE_HALF_WIDTH := 0.54
const ASSIST_MARGIN := 0.20
const SYNC_WINDOW := 0.43
const ASSISTED_SYNC_WINDOW := 0.64
const GRAVITY := 10.5
const MAX_PEDAL := 2
const DIRECTIONS := [-1.0, 1.0]
const LAYOUTS := [
	{"hoppers": [Vector2(-1.76, 3.65), Vector2(1.95, 3.77)], "masses": [[2, 1, 1], [1, 1, 2]], "pedal": 1},
	{"hoppers": [Vector2(-2.28, 3.90), Vector2(1.72, 3.42)], "masses": [[1, 2, 1], [2, 1, 1]], "pedal": -1},
]

enum Flight { EMPTY, DROP, BOARD, OUT }

class Bean:
	var phase := Flight.EMPTY
	var mass := 0
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var distance := 0.0
	var speed := 0.0
	var rebounded := false

var _beans: Array[Bean] = [Bean.new(), Bean.new()]
var _feed := PackedInt32Array([0, 0])
var _pans := PackedInt32Array([0, 0])
var _last_catch := Vector2(-10.0, -10.0)
var _layout := 0
var _pedal := 0
var _pedal_used := false
var _assisted := false
var _helper := false
var _angle := 0.0
var _angular_speed := 0.0
var _ticks := 0
var _remainder := 0.0
var _paired := false
var _side_catch := false
var _pair_gap := -1.0
var _mistakes := 0
var _ended := false
var _feedback := ""

func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, LAYOUTS.size())
	_pedal = LAYOUTS[_layout].pedal
	_pedal_used = false
	_helper = false
	_angle = -0.085 * _pedal
	_angular_speed = 0.0
	_ticks = 0
	_remainder = 0.0
	_paired = false
	_side_catch = false
	_pair_gap = -1.0
	_mistakes = 0
	_ended = false
	_last_catch = Vector2(-10.0, -10.0)
	_feedback = "移一格踏板，再開左右料斗。"
	for index in 2:
		_beans[index] = Bean.new()
		_feed[index] = 0
		_pans[index] = 0

func move_pedal(value: int) -> void:
	var next := clampi(value, -MAX_PEDAL, MAX_PEDAL)
	if _ended or next == _pedal:
		return
	_pedal = next
	_pedal_used = true

func nudge_pedal(direction: int) -> void:
	move_pedal(_pedal + direction)

func release(index: int) -> void:
	if _ended or index < 0 or index >= _beans.size():
		return
	var bean := _beans[index]
	if bean.phase != Flight.EMPTY:
		_feedback = "等這顆糖豆離開，再開同一邊料斗。"
		return
	bean.mass = _next_mass(index)
	_feed[index] += 1
	bean.position = LAYOUTS[_layout].hoppers[index]
	bean.velocity = Vector2.ZERO
	bean.distance = 0.0
	bean.speed = 0.0
	bean.rebounded = false
	bean.phase = Flight.DROP
	_feedback = "留意兩端高度和糖豆落盤的先後。"

func toggle_helper() -> void:
	if _ended:
		return
	_helper = not _helper
	_feedback = "AI 正扶穩兩端，放豆仍由你控制。" if _helper else "已關閉 AI 扶板。"

func finish() -> void:
	if _ended:
		return
	if _paired:
		_ended = true
	else:
		_feedback = "雙盤在同一時間窗落豆後，才可提早結算。"

func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_remainder += minf(delta, 0.25)
	while _remainder + 0.0000001 >= STEP and not _ended:
		_remainder = maxf(0.0, _remainder - STEP)
		_ticks += 1
		_move_board()
		for index in 2:
			_move_bean(index)
		_ended = (_paired and _side_catch) or _ticks >= ROUND_SECONDS / STEP

func _next_mass(index: int) -> int:
	var cycle: Array = LAYOUTS[_layout].masses[index]
	return cycle[_feed[index] % cycle.size()]

func _move_board() -> void:
	var target := -0.085 * _pedal
	for index in 2:
		var bean := _beans[index]
		if bean.phase == Flight.BOARD:
			target -= DIRECTIONS[index] * bean.mass * 0.088 * bean.distance / HALF_LENGTH
	var stiffness := 44.0 if _helper else 32.0
	var damping := 7.0 if _helper else 5.8
	_angular_speed += (32.0 * target - stiffness * _angle - damping * _angular_speed) * STEP
	var next := _angle + _angular_speed * STEP
	_angle = clampf(next, -0.34, 0.34)
	if _angle != next:
		_angular_speed = 0.0

func _board_point(distance: float) -> Vector2:
	return Vector2(0, BOARD_HEIGHT) + Vector2(distance, 0).rotated(_angle)

static func radius(mass: int) -> float:
	return 0.14 if mass == 1 else 0.20

func _move_bean(index: int) -> void:
	var bean := _beans[index]
	var side: float = DIRECTIONS[index]
	match bean.phase:
		Flight.DROP:
			bean.velocity.y -= GRAVITY * STEP
			bean.position += bean.velocity * STEP
			var distance := absf(bean.position.x / cos(_angle))
			var surface := _board_point(side * distance)
			if bean.position.y <= surface.y + radius(bean.mass) + 0.09:
				bean.phase = Flight.BOARD
				bean.distance = distance
				bean.speed = 1.85
				_angular_speed -= side * absf(bean.velocity.y) * bean.mass * distance * 0.019
				_place_on_board(bean, surface)
		Flight.BOARD:
			_roll_bean(index, side, bean)
		Flight.OUT:
			var before := bean.position
			bean.velocity.y -= GRAVITY * STEP
			bean.position += bean.velocity * STEP
			var plane := PAN_HEIGHT + radius(bean.mass)
			if bean.position.y <= plane and bean.velocity.y < 0.0:
				var landing_x := lerpf(before.x, bean.position.x, clampf(inverse_lerp(before.y, bean.position.y, plane), 0.0, 1.0))
				_land(index, bean, landing_x)

func _place_on_board(bean: Bean, point: Vector2) -> void:
	bean.position = point + Vector2(0, radius(bean.mass) + 0.09)

func _roll_bean(index: int, side: float, bean: Bean) -> void:
	var upward := side * bean.distance * cos(_angle) * _angular_speed
	if index == 1 and bean.mass == 1 and bean.distance >= 1.95 and upward >= 0.96:
		bean.rebounded = true
		bean.phase = Flight.OUT
		bean.velocity = Vector2(4.50, upward + 1.20)
		_feedback = "右板端甩起輕豆，觀察它會不會進側槽。"
		return
	# The guide pocket holds a light bean when its slope points back toward the pivot.
	if bean.mass == 1 and side * _angle > 0.092 and bean.distance <= 2.33:
		bean.speed = 0.0
	else:
		var rail_speed := clampf(2.10 - 6.0 * side * sin(_angle), 0.70, 3.70)
		bean.speed = move_toward(bean.speed, rail_speed, 7.0 * STEP)
		bean.distance = minf(HALF_LENGTH, bean.distance + bean.speed * STEP)
	_place_on_board(bean, _board_point(side * bean.distance))
	if bean.distance >= HALF_LENGTH:
		bean.phase = Flight.OUT
		bean.velocity = Vector2(side * cos(_angle) * bean.speed, upward + side * sin(_angle) * bean.speed)

func _land(index: int, bean: Bean, x: float) -> void:
	bean.phase = Flight.EMPTY
	var margin := ASSIST_MARGIN if _assisted else 0.0
	if bean.rebounded and absf(x - SIDE_X) <= SIDE_HALF_WIDTH + margin:
		_side_catch = true
		_feedback = "回彈輕豆進了側槽！"
	elif absf(x - DIRECTIONS[index] * PAN_X) <= PAN_HALF_WIDTH + margin:
		_pans[index] += bean.mass
		_last_catch[index] = _ticks * STEP
		var gap := absf(_last_catch.x - _last_catch.y)
		if _pedal_used and gap <= _sync_window():
			_paired = true
			_pair_gap = gap
			_feedback = "雙盤同步，間隔 %.2f 秒。" % gap
		else:
			_feedback = "糖豆落盤。看哪邊晚到，再調放豆順序。"
	else:
		_mistakes += 1
		_feedback = "糖豆落在盤外。回到中格可縮小板端落差。"

func _sync_window() -> float:
	return ASSISTED_SYNC_WINDOW if _assisted else SYNC_WINDOW

func snapshot() -> Dictionary:
	var beans: Array[Dictionary] = []
	for bean in _beans:
		beans.append({"position": bean.position, "phase": bean.phase, "mass": bean.mass, "rebounded": bean.rebounded})
	var pans_hit := int(_pans[0] > 0) + int(_pans[1] > 0)
	var points := 60 * pans_hit + 200 * int(_paired) + 100 * int(_side_catch) - 20 * _mistakes
	return {"beans": beans, "hoppers": LAYOUTS[_layout].hoppers.duplicate(), "layout": _layout,
		"next_masses": Vector2i(_next_mass(0), _next_mass(1)), "pans": Vector2i(_pans[0], _pans[1]),
		"pans_hit": pans_hit, "angle": _angle, "angular_speed": _angular_speed, "pedal": _pedal, "helper": _helper,
		"assisted": _assisted, "paired": _paired, "side_catch": _side_catch, "pair_gap": _pair_gap, "sync_window": _sync_window(),
		"elapsed": _ticks * STEP, "remaining": maxf(0.0, ROUND_SECONDS - _ticks * STEP),
		"score": maxi(0, points), "mistakes": _mistakes, "feedback": _feedback, "ended": _ended,
		"success": _ended and _paired, "devil": _ended and _paired and _side_catch,
		"ordinary_eligible": _ended and _pedal_used and _feed[0] > 0 and _feed[1] > 0}
