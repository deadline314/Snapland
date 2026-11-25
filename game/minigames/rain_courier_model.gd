extends RefCounted
## Fixed-step route, box condition, and handoff for a single courier.

const SHORT := 0
const COVERED := 1
const READY := "ready"
const CARRY := "carry"
const HANDOFF := "handoff"
const SLIDING := "sliding"
const COMPLETE := "complete"
const EXPIRED := "expired"

const DELIVERY_POINTS := 150
const PUDDLE_POINTS := 100
const LOSS_POINTS := 20
const ORDER_COUNT := 3
const TICK := 1.0 / 60.0
const ROUND_SECONDS := 42.0
const ASSISTED_SECONDS := 54.0
const SLIDE_TICKS := 30
const WALK_SPEED := 0.35
const UMBRELLA_SPEED := 0.69
const KITCHEN := Vector2(0.09, 0.57)
const RECIPIENTS := ["熱湯攤", "茶席", "夜班窗口"]
const DESTINATIONS := [Vector2(0.87, 0.60), Vector2(0.88, 0.47), Vector2(0.84, 0.69)]
const RECIPIENT_ORDERS := [[0, 1, 2], [2, 0, 1]]
const RECEIVER_PERIODS := [1.8, 1.62, 2.05]

var _layout := 0
var _stage := READY
var _assist := false
var _route := SHORT
var _delivered := 0
var _recipient := 0
var _rain_direction := 1
var _paths: Array[PackedVector2Array] = []
var _open_segments: Array[PackedVector2Array] = []
var _path_lengths: Array[PackedFloat32Array] = []
var _distance := 0.0
var _total_distance := 0.0
var _walking := false
var _manual_umbrella := false
var _temperature := 1.0
var _wetness := 0.0
var _ticks := 0
var _accumulator := 0.0
var _elapsed_slide_ticks := 0
var _landing_phase := 0.0
var _puddle_span := Vector2.ZERO
var _caught_slide := false
var _crossed_slides := 0
var _mistakes := 0
var _message := ""
var _notes: Array[int] = []

func _init() -> void:
	reset(false, 0)

func reset(assisted: bool, layout: int) -> void:
	_assist = assisted
	_layout = posmod(layout, RECIPIENT_ORDERS.size())
	_delivered = 0
	_ticks = 0
	_accumulator = 0.0
	_total_distance = 0.0
	_crossed_slides = 0
	_mistakes = 0
	_notes.clear()
	_configure_order()
	_prepare_box("選路後取餐。")

func choose_route(route: int) -> bool:
	if _stage != READY or route not in [SHORT, COVERED]:
		return false
	_route = route
	return true

func pickup() -> bool:
	if _stage != READY:
		return false
	_stage = CARRY
	_message = "持續前行，注意棚隙和餐盒狀態。"
	_note(7)
	return true

func hold(walking: bool) -> void:
	_walking = walking and _stage == CARRY

func set_umbrella(open: bool) -> void:
	if not _ended():
		_manual_umbrella = open

func toggle_umbrella() -> void:
	set_umbrella(not _manual_umbrella)

func clear_input() -> void:
	_walking = false
	_manual_umbrella = false

func slide() -> bool:
	if _stage != HANDOFF:
		return false
	_landing_phase = _incoming_phase()
	_elapsed_slide_ticks = 0
	_caught_slide = true
	_stage = SLIDING
	_message = "餐盒正滑向收件口。"
	_note(10)
	return true

func retry_order() -> bool:
	if _stage not in [CARRY, HANDOFF]:
		return false
	_reject_box("已換新餐盒。選路後取餐。")
	return true

func step(delta: float) -> void:
	if _ended() or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_advance()
		if _ended():
			_accumulator = 0.0
			break

func _advance() -> void:
	_ticks += 1
	match _stage:
		CARRY:
			_walk()
		HANDOFF:
			_temperature = maxf(0.0, _temperature - 0.029 * TICK)
		SLIDING:
			_advance_slide()
	if _stage != COMPLETE and _ticks * TICK >= _seconds_limit():
		clear_input()
		_stage = EXPIRED
		_message = "時間到，已送達 %d 份。" % _delivered

func _walk() -> void:
	var sheltered := _is_sheltered()
	var umbrella := _umbrella_open(sheltered)
	if sheltered:
		_temperature = maxf(0.0, _temperature - 0.030 * TICK)
		_wetness = maxf(0.0, _wetness - 0.045 * TICK)
	elif umbrella:
		_temperature = maxf(0.0, _temperature - 0.052 * TICK)
	else:
		_temperature = maxf(0.0, _temperature - 0.076 * TICK)
		var rain_rate := 0.36 if _rain_direction > 0 else 0.43
		_wetness = minf(1.0, _wetness + rain_rate * TICK)
	if not _walking:
		return
	var last := _distance
	var speed := WALK_SPEED * (UMBRELLA_SPEED if umbrella else 1.0)
	_distance = minf(_route_length(), _distance + speed * TICK)
	_total_distance += _distance - last
	if _distance >= _route_length():
		_walking = false
		_stage = HANDOFF
		_message = "等收件口進入亮帶，再滑遞餐盒。"
		_note(8)

func _advance_slide() -> void:
	var previous := _slide_progress()
	_elapsed_slide_ticks += 1
	var current := _slide_progress()
	var contact := minf(current, _puddle_span.y) - maxf(previous, _puddle_span.x)
	if contact > 0.0 and not _manual_umbrella:
		_caught_slide = false
		_wetness = minf(1.0, _wetness + contact * 0.53)
	_temperature = maxf(0.0, _temperature - 0.036 * TICK)
	if _elapsed_slide_ticks >= SLIDE_TICKS:
		_finish_slide()

func _finish_slide() -> void:
	if _wetness > _wet_limit():
		_reject_box("餐盒已淋濕。換一份並避開雨水。")
	elif _temperature < _warm_limit():
		_reject_box("餐盒已放涼。換一份並盡快交付。")
	elif not _in_handoff_window(_landing_phase):
		_reject_box("餐盒沒接穩。等指針進入亮帶再滑。")
	else:
		_accept_box()

func _reject_box(message: String) -> void:
	var chosen := _route
	_mistakes += 1
	_note(3)
	_prepare_box(message)
	_route = chosen

func _accept_box() -> void:
	_delivered += 1
	_crossed_slides += int(_caught_slide)
	_note(15 if _caught_slide else 12)
	if _delivered == ORDER_COUNT:
		clear_input()
		_stage = COMPLETE
		_message = "三份餐盒都已乾爽送達。"
		return
	var message := "乾爽送達！可取下一份。"
	if _caught_slide:
		message = "傘接跨過積水！可取下一份。"
	_configure_order()
	_prepare_box(message)

func _prepare_box(message: String) -> void:
	clear_input()
	_stage = READY
	_route = COVERED if _assist else SHORT
	_distance = 0.0
	_temperature = 1.0
	_wetness = 0.0
	_caught_slide = false
	_elapsed_slide_ticks = 0
	_landing_phase = 0.0
	_message = message

func _configure_order() -> void:
	_recipient = RECIPIENT_ORDERS[_layout][_delivered]
	_rain_direction = 1 if (_layout + _delivered) % 2 == 0 else -1
	var destination: Vector2 = DESTINATIONS[_recipient]
	var canopy_turn := 0.18 + 0.035 * float(_recipient)
	var slant := 0.032 * float(_rain_direction)
	_paths = [
		PackedVector2Array([KITCHEN, Vector2(0.23, 0.57), Vector2(0.68, destination.y + slant), destination]),
		PackedVector2Array([KITCHEN, Vector2(0.17, 0.34), Vector2(0.39, canopy_turn),
			Vector2(0.67, canopy_turn + slant), Vector2(0.78, 0.35), destination]),
	]
	_paths.make_read_only()
	var gap_start := 0.30 + 0.11 * float(_recipient) + slant
	var late_gap := 0.73 - slant
	_open_segments = [
		PackedVector2Array([Vector2(0.17 + slant, 0.87 + slant)]),
		PackedVector2Array([Vector2(gap_start, gap_start + 0.065), Vector2(late_gap, late_gap + 0.058)]),
	]
	_open_segments.make_read_only()
	_path_lengths = []
	for path in _paths:
		var lengths := PackedFloat32Array([0.0])
		for index in range(1, path.size()):
			lengths.append(lengths[-1] + path[index - 1].distance_to(path[index]))
		_path_lengths.append(lengths)
	_puddle_span = Vector2(0.36, 0.64) if _rain_direction > 0 else Vector2(0.44, 0.72)

func _route_length() -> float:
	return _path_lengths[_route][-1]

func _route_progress() -> float:
	return _distance / _route_length()

func _position() -> Vector2:
	var path := _paths[_route]
	var lengths := _path_lengths[_route]
	for index in range(1, path.size()):
		if _distance <= lengths[index]:
			return path[index - 1].lerp(path[index], inverse_lerp(lengths[index - 1], lengths[index], _distance))
	return path[-1]

func _is_sheltered() -> bool:
	var progress := _route_progress()
	for gap in _open_segments[_route]:
		if progress >= gap.x and progress < gap.y:
			return false
	return true

func _umbrella_open(sheltered: bool) -> bool:
	return _manual_umbrella or (_assist and _stage == CARRY and not sheltered)

func _incoming_phase() -> float:
	var future := (_ticks + SLIDE_TICKS) * TICK
	return fposmod(future / RECEIVER_PERIODS[_recipient] + 0.17 * float(_layout + _delivered), 1.0)

func _handoff_window() -> Vector2:
	return Vector2(0.12, 0.85) if _assist else Vector2(0.24, 0.72)

func _in_handoff_window(phase: float) -> bool:
	var window := _handoff_window()
	return phase >= window.x and phase <= window.y

func _slide_progress() -> float:
	return float(_elapsed_slide_ticks) / float(SLIDE_TICKS)

func _warm_limit() -> float:
	return 0.53 if _assist else 0.59

func _wet_limit() -> float:
	return 0.34 if _assist else 0.27

func _seconds_limit() -> float:
	return ASSISTED_SECONDS if _assist else ROUND_SECONDS

func _ended() -> bool:
	return _stage == COMPLETE or _stage == EXPIRED

func _note(pitch: int) -> void:
	if _notes.size() < 8:
		_notes.append(pitch)

func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes

func result() -> Dictionary:
	var success := _stage == COMPLETE
	var devil := success and _crossed_slides > 0
	var score := maxi(0, _delivered * DELIVERY_POINTS + int(devil) * PUDDLE_POINTS - _mistakes * LOSS_POINTS)
	return {"ended": _ended(), "success": success, "devil": devil, "score": score,
		"ordinary_eligible": _ended() and _total_distance >= 0.60, "delivered": _delivered,
		"mistakes": _mistakes, "umbrella_catches": _crossed_slides, "assisted": _assist}

func snapshot() -> Dictionary:
	var sheltered := _is_sheltered()
	var phase := _landing_phase if _stage == SLIDING else _incoming_phase()
	var state := result()
	state.merge({
		"stage": _stage, "layout": _layout, "route": _route, "route_paths": _paths,
		"route_length": _route_length(), "distance": _distance, "position": _position(),
		"route_progress": _route_progress(), "recipient": RECIPIENTS[_recipient],
		"recipient_index": _recipient, "order": mini(_delivered + 1, ORDER_COUNT),
		"remaining": maxf(0.0, _seconds_limit() - _ticks * TICK), "elapsed": _ticks * TICK,
		"temperature": _temperature, "wetness": _wetness, "sheltered": sheltered,
		"umbrella": _umbrella_open(sheltered), "umbrella_manual": _manual_umbrella, "walking": _walking,
		"assist": _assist, "rain_direction": _rain_direction, "open_segments": _open_segments,
		"handoff_phase": phase, "handoff_window": _handoff_window(),
		"slide_ready": _stage == HANDOFF and _in_handoff_window(phase), "slide_progress": _slide_progress(),
		"puddle_span": _puddle_span, "puddle_protected": _stage == SLIDING and _manual_umbrella,
		"warm_limit": _warm_limit(), "wet_limit": _wet_limit(), "message": _message, "feedback": _message,
	})
	return state
