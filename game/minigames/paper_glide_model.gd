extends RefCounted

enum { SETUP, FLIGHT, MISSED, FINISHED }
const LEFT := 1
const RIGHT := 2
const BOTH := LEFT | RIGHT
const ROUND_SECONDS := 75.0
const TICK := 1.0 / 120.0
const START := Vector3(0, 5.6, 0)
const POWERS := [7.6, 9.0, 10.4]
const SPANS := [0.72, 0.46]
const CRUISE := [8.0, 8.9]
const DRAG := [0.64, 0.34]
const SINK := [0.74, 0.98]
const MAX_LANE := 5.0
const WINDOW_POINTS := 80
const LANDING_POINTS := 240
const BELL_POINTS := 100
const MISS_PENALTY := 20
const COURSES := [
	{"name": "薄糖紙", "mass": 1.0, "wind": Vector3(0.55, -0.80, 0.40),
		"windows": [Vector3(-0.43, 4.70, 10), Vector3(1.24, 3.73, 21)], "opening": 1.49,
		"bell": Vector3(1.22, 3.02, 29), "basket": Vector3(0.35, 2.35, 33)},
	{"name": "厚糖紙", "mass": 1.14, "wind": Vector3(-0.72, 1.00, -0.50),
		"windows": [Vector3(0.46, 4.48, 10), Vector3(-0.31, 3.58, 21)], "opening": 1.43,
		"bell": Vector3(-1.14, 2.62, 29), "basket": Vector3(-0.35, 1.97, 33)},
]

class Flight:
	var position := START
	var speed := 0.0
	var lateral_speed := 0.0
	var bank := 0.0
	var time := 0.0
	var braked := false

	func _init(fold: int, power: int) -> void:
		speed = POWERS[power] + 1.15 * fold

	func advance(fold: int, mass: float, wind: float, steer: float) -> void:
		var cruise: float = CRUISE[fold]
		var effective_cruise: float = cruise * (0.68 if braked else 1.0)
		speed = move_toward(speed, effective_cruise, absf(effective_cruise - speed) * DRAG[fold] * TICK)
		bank = move_toward(bank, 0.51 * steer, 2.8 * TICK)
		lateral_speed += (8.0 * bank + wind - lateral_speed * 2.3) * TICK
		var sink: float = SINK[fold] * mass * (0.7 + 0.3 * cruise / speed) + 0.25 * absf(bank)
		position += Vector3(lateral_speed, -sink, speed) * TICK
		time += TICK

var _layout := 0
var _assisted := false
var _course: Dictionary
var _phase := SETUP
var _fold := 0
var _folded := 0
var _helper := false
var _power := 1
var _preview := PackedVector3Array()
var _flight: Flight
var _elapsed := 0.0
var _unprocessed := 0.0
var _passed := 0
var _best := 0
var _misses := 0
var _steer := 0.0
var _worked := false
var _success := false
var _devil := false
var _feedback := ""
var _notes: Array[int] = []

func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, COURSES.size())
	_course = COURSES[_layout]
	_fold = 0
	_power = 1
	_helper = false
	_elapsed = 0.0
	_unprocessed = 0.0
	_best = 0
	_misses = 0
	_worked = false
	_success = false
	_devil = false
	_prepare()

func _prepare() -> void:
	_phase = SETUP
	_folded = 0
	_passed = 0
	_steer = 0.0
	_unprocessed = 0.0
	_notes.clear()
	_flight = null
	_feedback = "選摺型與投力，摺好雙翼再投出。"
	_update_preview()

func select_fold(fold: int) -> void:
	if _phase != SETUP or fold == _fold or fold < 0 or fold >= SPANS.size():
		return
	_fold = fold
	_folded = 0
	_feedback = "折線已換，重新摺左右翼。"
	_update_preview()

func change_power(amount: int) -> void:
	if _phase != SETUP:
		return
	var power := clampi(_power + amount, 0, POWERS.size() - 1)
	if power != _power:
		_power = power
		_update_preview()

func fold_side(side: int) -> void:
	if _phase != SETUP:
		return
	_folded |= BOTH if _helper else (side & BOTH)
	if _folded == BOTH:
		_feedback = "雙翼已摺好。投出後用左右舵穿窗。"
	elif _folded != 0:
		_feedback = "再摺另一側機翼。"

func toggle_helper() -> void:
	if _phase != SETUP:
		return
	_helper = not _helper
	if _helper and _folded != 0:
		fold_side(_folded)
	elif _helper:
		_feedback = "摺任一翼，AI 會沿同一折線摺另一翼。"
	else:
		_feedback = "左右翼各摺一次。"

func launch_or_recover() -> void:
	match _phase:
		SETUP:
			if _folded != BOTH:
				_feedback = "先摺好左右翼。"
				return
			_flight = Flight.new(_fold, _power)
			_phase = FLIGHT
			_feedback = "調整側風，讓兩側翼尖穿過第一道風窗。"
		MISSED:
			_prepare()
		FLIGHT:
			if _assisted:
				_prepare()
				_feedback = "已收回紙機，可重摺或調整投力。"

func steer(value: float) -> void:
	_steer = clampf(value, -1.0, 1.0) if _phase == FLIGHT and is_finite(value) else 0.0

func phase() -> int:
	return _phase

func step(delta: float) -> void:
	if _phase == FINISHED or not is_finite(delta) or delta <= 0.0:
		return
	var active := minf(delta, minf(0.25, ROUND_SECONDS - _elapsed))
	_elapsed = minf(ROUND_SECONDS, _elapsed + active)
	_unprocessed += active
	while _unprocessed + 0.0000001 >= TICK and _phase == FLIGHT:
		_unprocessed -= TICK
		_fly()
	if _phase != FLIGHT:
		_unprocessed = 0.0
	if _phase != FINISHED and _elapsed >= ROUND_SECONDS:
		_phase = FINISHED
		_feedback = "時間到。"

func _fly() -> void:
	var previous := _flight.position
	var previous_bank := _flight.bank
	_flight.advance(_fold, _course.mass, _wind_at(previous.z), _steer)
	_worked = _worked or _flight.position.z >= 2.0
	if absf(_flight.position.x) > MAX_LANE or _flight.position.y < 0.3:
		_fail("紙機飛離試飛道。收回紙機再試。")
		return
	if _passed < _course.windows.size():
		var window_z: float = _course.windows[_passed].z
		if _flight.position.z >= window_z:
			var fraction := inverse_lerp(previous.z, _flight.position.z, window_z)
			var sample := previous.lerp(_flight.position, fraction)
			var bank := lerpf(previous_bank, _flight.bank, fraction)
			_cross_window(sample, bank, _flight.time - (1.0 - fraction) * TICK)
		return
	var bell: Vector3 = _course.bell
	if previous.z < bell.z and _flight.position.z >= bell.z:
		var fraction := inverse_lerp(previous.z, _flight.position.z, bell.z)
		var sample := previous.lerp(_flight.position, fraction)
		_cross_bell(sample, lerpf(previous_bank, _flight.bank, fraction))
	var basket: Vector3 = _course.basket
	if _flight.position.z >= basket.z:
		var sample := previous.lerp(_flight.position, inverse_lerp(previous.z, _flight.position.z, basket.z))
		_land(sample, basket)

func _cross_window(sample: Vector3, bank: float, time: float) -> void:
	var window := _window_at(_passed, time)
	if not _inside_window(sample, window):
		_fail("偏離第 %d 道風窗。看側風調整進窗位置。" % (_passed + 1))
	elif not _inside_window(sample + wing_offset(_fold, bank), window) or not _inside_window(sample - wing_offset(_fold, bank), window):
		_fail("翼尖碰到第 %d 道窗框。試試較窄的折線或對準窗中央。" % (_passed + 1))
	else:
		_passed += 1
		_best = maxi(_best, _passed)
		_notes.append(_passed)
		_feedback = "第一道通過，準備對準第二道。" if _passed == 1 else "兩窗通過。對準包裝籃，或先用翼尖擦鈴。"

func _cross_bell(sample: Vector3, bank: float) -> void:
	var tip := wing_offset(_fold, bank)
	var bell: Vector3 = _course.bell
	var radius := 0.49 if _assisted else 0.37
	if (sample + tip).distance_squared_to(bell) <= radius * radius or (sample - tip).distance_squared_to(bell) <= radius * radius:
		_flight.braked = true
		_flight.speed *= 0.68
		_notes.append(3)
		_feedback = "翼尖擦鈴，已減速。保持對準包裝籃。"

func _land(sample: Vector3, basket: Vector3) -> void:
	var clearance := 1.43 if _assisted else 1.15
	if absf(sample.x - basket.x) > clearance or absf(sample.y - basket.y) > 0.95 + (0.19 if _assisted else 0.0):
		_fail("飛過籃口或落在籃外。可以改摺型或投力。")
		return
	_flight.position = sample
	_success = true
	_devil = _flight.braked
	_phase = FINISHED
	_notes.append(0)
	_feedback = "擦鈴後落籃成功！" if _devil else "穿過兩窗，落籃成功！"

func _fail(message: String) -> void:
	_phase = MISSED
	_misses += 1
	_steer = 0.0
	_feedback = message

static func wing_offset(fold: int, bank: float) -> Vector3:
	var span: float = SPANS[fold]
	return Vector3(cos(bank) * span, -sin(bank) * span, 0)

func _wind_at(distance: float) -> float:
	var winds: Vector3 = _course.wind
	return winds.x if distance < _course.windows[0].z else (winds.y if distance < _course.windows[1].z else winds.z)

func _window_at(index: int, time: float) -> Dictionary:
	var center: Vector3 = _course.windows[index]
	var sway := sin(time * 1.55 + index * 2.0 + _layout)
	center.x += sway * (0.37 + _layout * 0.09)
	var width: float = _course.opening + 0.21 * cos(time * 1.9 + index * 1.8)
	return {"center": center, "half_width": width + (0.27 if _assisted else 0.0), "half_height": 0.99 + (0.20 if _assisted else 0.0)}

static func _inside_window(point: Vector3, window: Dictionary) -> bool:
	var difference: Vector3 = point - window.center
	return absf(difference.x) <= window.half_width and absf(difference.y) <= window.half_height

func _update_preview() -> void:
	_preview = PackedVector3Array()
	if not _assisted:
		return
	var forecast := Flight.new(_fold, _power)
	_preview.append(forecast.position)
	for point in 9:
		for tick in 12:
			forecast.advance(_fold, _course.mass, _wind_at(forecast.position.z), 0.0)
		_preview.append(forecast.position)

func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes

func snapshot() -> Dictionary:
	var position := START if _flight == null else _flight.position
	var time := 0.0 if _flight == null else _flight.time
	var speed := 0.0 if _flight == null else _flight.speed
	var bank := 0.0 if _flight == null else _flight.bank
	var braked := _flight != null and _flight.braked
	var windows: Array[Dictionary] = []
	for index in _course.windows.size():
		windows.append(_window_at(index, time))
	var clean_points := _best * WINDOW_POINTS + LANDING_POINTS * int(_success) + BELL_POINTS * int(_devil)
	return {"phase": _phase, "layout": _layout, "course_name": _course.name, "position": position, "speed": speed, "bank": bank,
		"wind": _wind_at(position.z), "windows": windows, "bell": _course.bell, "basket": _course.basket, "preview": _preview,
		"fold": _fold, "folded": _folded, "power": _power, "assisted": _assisted, "helper": _helper, "steer": _steer,
		"braked": braked, "passed": _passed, "best": _best, "mistakes": _misses, "feedback": _feedback,
		"elapsed": _elapsed, "remaining": ROUND_SECONDS - _elapsed,
		"ended": _phase == FINISHED, "success": _success, "devil": _devil, "ordinary_eligible": _phase == FINISHED and _worked,
		"score": maxi(0, clean_points - _misses * MISS_PENALTY)}
