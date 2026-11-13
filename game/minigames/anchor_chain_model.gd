extends RefCounted
class_name AnchorChainModel

## A grounded freighter pivots about its stern on a sandbar (the origin, world X/Z).
## The chain runs bow → wrapped reef posts → anchor; reeling pulls the bow toward
## the first point after it, so torque comes only from where that segment points.
const ROUND_SECONDS := 150.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const SHIP_LENGTH := 4.0
const PULL := 6.0
const WRAP_FRICTION := 0.85
const LENGTH_LOSS := 0.02
const FREE_LENGTH := 10.0
const GROUND_FRICTION := 2.0
const TURN_GAIN := 0.05
const STRAIN_LIMIT := 2.0
const SWING_LIMIT := deg_to_rad(100.0)
const ALIGN_TOLERANCE := deg_to_rad(5.0)
const HELPER_TORQUE := 0.6
const MAX_WRAPS := 3
const CHAIN_MAX := 24.0
const FREE_POINTS := 300
const BREAK_PENALTY := 50
## Retries mirror the stranding: another bow direction, channel and reef layout.
const LAYOUTS := [
	{"name": "北向擱淺", "heading": -90.0, "target": 0.0, "channel": "東",
		"posts": [Vector2(5, -6), Vector2(6, 1), Vector2(-3, -7)], "anchors": [Vector2(0, -10), Vector2(-7, -7), Vector2(-8, 1), Vector2(3, -10)]},
	{"name": "南向擱淺", "heading": 90.0, "target": 180.0, "channel": "西",
		"posts": [Vector2(-5, 6), Vector2(-6, -1), Vector2(3, 7)], "anchors": [Vector2(0, 10), Vector2(7, 7), Vector2(8, -1), Vector2(-3, 10)]},
]

var _assisted := false
var _variant := 0
var _layout: Dictionary = {}
var _elapsed := 0.0
var _theta := 0.0
var _start := 0.0
var _selected := 0
var _wraps: Array[int] = []
var _history: Array[Array] = []
var _anchor := -1
var _reeling := false
var _helper := 0
var _strain := 0.0
var _breaks := 0
var _reason := ""
var _torque := 0.0
var _freed_wraps: Array[int] = []
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
	_start = deg_to_rad(float(_layout.heading))
	_theta = _start
	_selected = 0
	_wraps.clear()
	_history.clear()
	_anchor = -1
	_reeling = false
	_helper = 0
	_strain = 0.0
	_breaks = 0
	_reason = ""
	_torque = 0.0
	_freed_wraps.clear()
	_ended = false
	_success = false
	_feedback = "選礁石繞鏈或選錨點下錨；把船頭轉向%s邊航道" % _layout.channel

## Selection cycles through every post, then every anchor spot.
func targets() -> Array:
	var rows: Array = []
	for index in _layout.posts.size():
		rows.append({"kind": "post", "index": index, "position": _layout.posts[index], "name": "礁石%d" % (index + 1)})
	for index in _layout.anchors.size():
		rows.append({"kind": "anchor", "index": index, "position": _layout.anchors[index], "name": "錨點%s" % ["甲", "乙", "丙", "丁"][index]})
	return rows

func select_next(step: int) -> void:
	if _ended or step == 0:
		return
	_selected = posmod(_selected + signi(step), targets().size())

func cleat() -> Vector2:
	return Vector2.from_angle(_theta) * SHIP_LENGTH

func _path_points() -> Array:
	var points: Array = [cleat()]
	for index in _wraps:
		points.append(_layout.posts[index])
	if _anchor >= 0:
		points.append(_layout.anchors[_anchor])
	return points

func chain_length() -> float:
	var points := _path_points()
	var total := 0.0
	for index in range(1, points.size()):
		total += Vector2(points[index - 1]).distance_to(points[index])
	return total

## F: wrap the selected reef or drop the anchor at the selected spot.
func place() -> void:
	if _ended:
		return
	if _reeling:
		_feedback = "收鏈中，放開後再調整"
		return
	var target: Dictionary = targets()[_selected]
	if _anchor >= 0:
		_feedback = "錨已下，先按 X 收錨才能改繞法"
		return
	if target.kind == "post":
		if _wraps.size() >= MAX_WRAPS:
			_feedback = "最多繞 %d 次礁石" % MAX_WRAPS
			return
		_history.append(_wraps.duplicate())
		_wraps.append(target.index)
		var turns := _wraps.count(target.index)
		_feedback = "鏈條繞過%s%s" % [target.name, "第二圈" if turns >= 2 else ""]
		return
	_anchor = target.index
	if chain_length() > CHAIN_MAX:
		_anchor = -1
		_feedback = "鏈條不夠長，換近一點的錨點或少繞一顆"
		return
	_feedback = "在%s下錨；按住空白收鏈" % target.name

## Z: assistance steps back one wrap; X lifts the anchor and the whole chain.
func undo() -> void:
	if _ended or _reeling:
		return
	if not _assisted:
		_feedback = "回溯繞礁只在輔助模式提供"
		return
	if _anchor >= 0:
		_anchor = -1
		_feedback = "回溯：收起錨"
		return
	if _history.is_empty():
		_feedback = "沒有可回溯的步驟"
		return
	_wraps = _history.pop_back()
	_feedback = "回溯一步繞礁"

func recall() -> void:
	if _ended or _reeling:
		return
	_wraps.clear()
	_history.clear()
	_anchor = -1
	_strain = 0.0
	_feedback = "收回錨鏈，重新規劃"

## R: the deckhand holds a low-speed rudder to one side (or centred).
func cycle_helper() -> void:
	if _ended:
		return
	_helper = (_helper + 2) % 3 - 1
	_feedback = "船員保持%s舵" % ["左", "中", "右"][_helper + 1]

func set_reeling(value: bool) -> void:
	if _ended:
		return
	if value and _anchor < 0:
		_feedback = "還沒下錨"
		return
	_reeling = value
	if not value:
		_strain = 0.0

func clear_input() -> void:
	_reeling = false
	_strain = 0.0

func strength() -> float:
	var value := PULL * pow(WRAP_FRICTION, _wraps.size())
	return value * maxf(0.4, 1.0 - LENGTH_LOSS * maxf(0.0, chain_length() - FREE_LENGTH))

## Signed torque the chain applies about the grounded stern, plus the helper rudder.
func torque() -> float:
	if _anchor < 0:
		return 0.0
	var points := _path_points()
	var bow: Vector2 = points[0]
	var direction: Vector2 = (Vector2(points[1]) - bow).normalized()
	return bow.cross(direction) * strength() / SHIP_LENGTH + _helper * HELPER_TORQUE

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
	_torque = torque()
	if _reeling and _anchor >= 0:
		var needed := signf(angle_difference(_theta, deg_to_rad(float(_layout.target))))
		if absf(_torque) <= GROUND_FRICTION:
			_strain += dt
			_reason = "拉力線幾乎穿過擱淺點，轉矩不足" if absf(_torque) < 0.3 else "轉矩被擱淺摩擦抵住"
			if _strain > STRAIN_LIMIT and not _assisted:
				_breaks += 1
				_wraps.clear()
				_history.clear()
				_anchor = -1
				_reeling = false
				_strain = 0.0
				_feedback = "鏈條繃斷！%s" % _reason
		else:
			_strain = 0.0
			_reason = "船身轉向航道" if signf(_torque) == needed else "轉矩方向反了，船頭越轉越偏"
			_theta = clampf(_theta + (_torque - signf(_torque) * GROUND_FRICTION) * TURN_GAIN * dt, _start - SWING_LIMIT, _start + SWING_LIMIT)
			_feedback = _reason
			if absf(angle_difference(_theta, deg_to_rad(float(_layout.target)))) <= ALIGN_TOLERANCE:
				_freed_wraps = _wraps.duplicate()
				_ended = true
				_success = true
				_reeling = false
				_feedback = "船頭對準航道，貨船脫困"
	if not _ended and _elapsed >= ROUND_SECONDS:
		_ended = true
		_reeling = false
		_feedback = "時間到：貨船還擱淺著"

## The devil's twist: one reef wrapped twice in a row turns the chain there twice.
static func double_wrap(wraps: Array[int]) -> bool:
	for index in range(1, wraps.size()):
		if wraps[index] == wraps[index - 1]:
			return true
	return false

func snapshot() -> Dictionary:
	var devil := _success and double_wrap(_freed_wraps) and _breaks == 0
	var target_heading := deg_to_rad(float(_layout.target))
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": _layout.name, "channel": _layout.channel, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil, "devil_success": devil,
		"ordinary_eligible": _ended, "score": maxi(0, (FREE_POINTS if _success else 0) - _breaks * BREAK_PENALTY + (100 if devil else 0)),
		"mistakes": _breaks, "breaks": _breaks, "theta": _theta, "target_heading": target_heading, "remaining_turn": angle_difference(_theta, target_heading),
		"cleat": cleat(), "posts": _layout.posts.duplicate(), "anchors": _layout.anchors.duplicate(), "targets": targets(), "selected": _selected,
		"wraps": _wraps.duplicate(), "anchor": _anchor, "path": _path_points(), "chain_length": chain_length(), "strength": strength(),
		"torque": _torque if _reeling else torque(), "reeling": _reeling, "strain": minf(_strain, STRAIN_LIMIT) / STRAIN_LIMIT, "helper": _helper, "reason": _reason,
		"double_wrap": double_wrap(_wraps), "undo_available": _assisted and (_anchor >= 0 or not _history.is_empty()),
		"feedback": _feedback, "last_event": _feedback,
	}
