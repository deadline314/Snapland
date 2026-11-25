extends RefCounted

const AIM := -1
const BOARD_A := 0
const BOARD_B := 1
const LACQUER := 0
const FELT := 1
const MIN_POWER := 0
const MAX_POWER := 10
const POCKET_COUNT := 3
const POT_POINTS := 150
const DOUBLE_POINTS := 100
const LOSS_POINTS := 20
const NORMAL_SHOTS := 5
const ROUND_SECONDS := 118.0
const ASSISTED_SECONDS := 142.0
const TICK := 1.0 / 120.0

const TRAY := Rect2(-4.73, -3.17, 9.46, 6.19)
const LAUNCHER := Vector2(0.0, 2.68)
const COIN_RADIUS := 0.105
const BOARD_RADIUS := 0.033
const POT_RADIUS := 0.145
const RIM_RADIUS := 0.29
const POT_SPEED := 2.60
const LACQUER_DRAG := 1.16
const FELT_DRAG := 2.32

const AIM_LIMIT := 65
const BOARD_LIMIT := 5
const BOARD_STEP := deg_to_rad(2.5)
const STOP_SPEED := 0.055
const SHOT_SECONDS := 10.0
const TRAIL_LIMIT := 108
const PREVIEW_TICKS := 264
const CONTACT_EPSILON := 0.00004
const MIN_USEFUL_IMPACT := 0.30
const MAX_USEFUL_DOT := cos(deg_to_rad(12.0))
const BOTH_BOARDS := (1 << BOARD_A) | (1 << BOARD_B)

enum Contact { NONE, BOARD, RIM, POT, EDGE }
enum Result { MOVING, STOPPED, OFF_EDGE, POTTED }

const LAYOUTS := [
	{
		"felt": Rect2(0.58, -3.17, 4.15, 1.96),
		"pockets": [Vector2(-2.35, -0.75), Vector2(0.20, -2.16), Vector2(2.65, -1.42)],
		"boards": [[Vector2(-2.20, 0.72), -75.0, 0.61], [Vector2(1.92, -0.18), -35.0, 0.54]],
	},
	{
		"felt": Rect2(-4.73, -3.17, 4.06, 2.35),
		"pockets": [Vector2(2.57, -0.90), Vector2(0.31, -2.32), Vector2(-2.78, -1.75)],
		"boards": [[Vector2(2.36, 0.94), 76.0, 0.61], [Vector2(-1.93, -0.48), 36.0, 0.54]],
	},
]


class Board:
	var center := Vector2.ZERO
	var base_angle := 0.0
	var angle := 0.0
	var axis := Vector2.RIGHT
	var normal := Vector2.DOWN
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var half_length := 0.0
	var normal_retention := 0.0
	var tangent_retention := 0.0
	var detent := 0
	var placed := false


class Sweep:
	var time := INF
	var kind := Contact.NONE
	var index := -1
	var normal := Vector2.ZERO

	func clear() -> void:
		time = INF
		kind = Contact.NONE
		index = -1
		normal = Vector2.ZERO

	func offer(at: float, type: int, item: int, axis := Vector2.ZERO) -> void:
		if at >= 0.0 and at <= 1.0 and at < time:
			time = at
			kind = type
			index = item
			normal = axis


class Shot:
	var position := LAUNCHER
	var velocity := Vector2.ZERO
	var elapsed := 0.0
	var distance := 0.0
	var bounces := 0
	var contacts_mask := 0
	var rim_scrapes := 0
	var impact := LAUNCHER
	var last_surface := ""
	var pocket := -1
	var result := Result.MOVING


var _assisted := false
var _layout := 0
var _felt := Rect2()
var _pockets := PackedVector2Array()
var _boards: Array[Board] = []
var _selected := AIM
var _aim_degrees := 0
var _power := 2
var _sunk := 0
var _shots := 0
var _misses := 0
var _ticks := 0
var _accumulator := 0.0
var _active := false
var _ended := false
var _participated := false
var _double_potted := false
var _feedback := ""
var _shot := Shot.new()
var _sweep := Sweep.new()
var _trail := PackedVector2Array()
var _preview := PackedVector2Array()
var _preview_dirty := true
var _notes: Array[int] = []


func _init() -> void:
	reset(false, 0)


func reset(assisted: bool, layout: int) -> void:
	_assisted = assisted
	_layout = posmod(layout, LAYOUTS.size())
	var data: Dictionary = LAYOUTS[_layout]
	_felt = data.felt
	_pockets = PackedVector2Array(data.pockets)
	_boards.clear()
	for index in data.boards.size():
		var board := Board.new()
		var spec: Array = data.boards[index]
		board.center = spec[0]
		board.base_angle = deg_to_rad(float(spec[1]))
		board.half_length = spec[2]
		board.normal_retention = 0.77 if index == BOARD_A else 0.62
		board.tangent_retention = 0.89 if index == BOARD_A else 0.85
		_orient(board, 0)
		_boards.append(board)
	_selected = AIM
	_aim_degrees = 0
	_power = 2
	_sunk = 0
	_shots = 0
	_misses = 0
	_ticks = 0
	_accumulator = 0.0
	_active = false
	_ended = false
	_participated = false
	_double_potted = false
	_shot = Shot.new()
	_trail.clear()
	_preview.clear()
	_preview_dirty = true
	_notes.clear()
	_feedback = "先瞄準叫號孔，再選力道與斜板。"


func cycle_selection(direction: int = 1) -> bool:
	if direction not in [-1, 1]:
		return false
	return select(posmod(_selected + 1 + direction, 3) - 1)


func select(index: int) -> bool:
	if not _can_set_up() or index not in [AIM, BOARD_A, BOARD_B]:
		return false
	_selected = index
	_feedback = "調整投幣角度。" if index == AIM else "調整第 %d 片斜板。" % (index + 1)
	return true


func adjust_angle(direction: int) -> bool:
	if not _can_set_up() or direction not in [-1, 1]:
		return false
	if _selected == AIM:
		var degrees := clampi(_aim_degrees + direction, -AIM_LIMIT, AIM_LIMIT)
		if degrees == _aim_degrees:
			return false
		_aim_degrees = degrees
		_preview_dirty = true
	else:
		var board := _boards[_selected]
		var detent := clampi(board.detent + direction, -BOARD_LIMIT, BOARD_LIMIT)
		if detent == board.detent:
			return false
		_orient(board, detent)
		_preview_dirty = _preview_dirty or board.placed
	return true


func adjust_power(direction: int) -> bool:
	if not _can_set_up() or direction not in [-1, 1]:
		return false
	var power := clampi(_power + direction, MIN_POWER, MAX_POWER)
	if power == _power:
		return false
	_power = power
	_preview_dirty = true
	return true


func toggle_board() -> bool:
	if not _can_set_up() or _selected == AIM:
		return false
	var board := _boards[_selected]
	board.placed = not board.placed
	_preview_dirty = true
	_feedback = "已放下斜板。" if board.placed else "已收起斜板。"
	_note(8)
	return true


func assist_board() -> bool:
	if not _assisted or not _can_set_up() or _selected == AIM:
		return false
	var board := _boards[_selected]
	if not board.placed:
		_feedback = "先放下要調整的斜板。"
		return false

	# The helper rotates one selected board one detent toward a visible line.
	# An installed partner provides the next or previous point on that line.
	var partner := _boards[1 - _selected]
	var from := partner.center if _selected == BOARD_B and partner.placed else LAUNCHER
	var toward: Vector2 = partner.center if _selected == BOARD_A and partner.placed else _pockets[_sunk]
	var incoming := (board.center - from).normalized()
	var outgoing := (toward - board.center).normalized()
	var best := board.detent
	var best_alignment := -INF
	for detent in range(-BOARD_LIMIT, BOARD_LIMIT + 1):
		var axis := Vector2.from_angle(board.base_angle + float(detent) * BOARD_STEP)
		var normal := Vector2(-axis.y, axis.x)
		var reflected := _reflect(incoming, normal, board.normal_retention, board.tangent_retention)
		var alignment := reflected.normalized().dot(outgoing)
		if alignment > best_alignment + 0.00001 or (is_equal_approx(alignment, best_alignment) and absi(detent - board.detent) < absi(best - board.detent)):
			best = detent
			best_alignment = alignment
	if best == board.detent:
		_feedback = "這片板已對向下一點。"
		return false
	_orient(board, board.detent + signi(best - board.detent))
	_preview_dirty = true
	_feedback = "幫手微調了選中的斜板。"
	return true


func launch() -> bool:
	if not _can_set_up():
		return false
	_shot = _new_shot()
	_shots += 1
	_active = true
	_trail = PackedVector2Array([LAUNCHER])
	_feedback = "銅板正在滑行。"
	_note(6)
	return true


func clear_input() -> void:
	# The driver tracks held controls. The shot continues under the model clock.
	pass


func step(delta: float) -> void:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK and not _ended:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_ticks += 1
		if _active:
			_step_active_shot()
		if not _ended and float(_ticks) * TICK >= _seconds_limit():
			_finish("時間到，已投進 %d / %d 孔。" % [_sunk, POCKET_COUNT])


func _step_active_shot() -> void:
	var previous_bounces := _shot.bounces
	var previous_scrapes := _shot.rim_scrapes
	_step_shot(_shot, _sweep)
	if _shot.bounces > previous_bounces:
		_feedback = "借第 %d 片斜板反彈。" % (int(_shot.last_surface == "斜板 B") + 1)
		_note(9)
	if _shot.rim_scrapes > previous_scrapes:
		_feedback = "擦到孔緣。再調整角度或力道。"
		_note(5)
	if _trail.size() < TRAIL_LIMIT and _trail[-1].distance_squared_to(_shot.position) >= 0.10 * 0.10:
		_trail.append(_shot.position)
	if _shot.distance >= 0.55:
		_participated = true
	if _shot.result != Result.MOVING:
		_settle_shot()


func _settle_shot() -> void:
	_active = false
	_shot.velocity = Vector2.ZERO
	if _shot.result == Result.POTTED and _shot.pocket == _sunk:
		_sunk += 1
		_double_potted = _double_potted or _shot.contacts_mask == BOTH_BOARDS
		_note(14)
		if _sunk == POCKET_COUNT:
			_finish("三枚銅板都落進了指定孔。")
			return
		_feedback = "已落孔。下一枚瞄準第 %d 孔。" % (_sunk + 1)
	else:
		_misses += 1
		match _shot.result:
			Result.POTTED: _feedback = "滑進旁邊的孔。指定孔仍等著這枚。"
			Result.OFF_EDGE: _feedback = "銅板滑出桌沿。試試減少力道。"
			_: _feedback = "銅板停在桌面。可調整路線再投。"
		if _assisted:
			_feedback += " 可免費補幣。"
		_note(3)
	if not _assisted and _shots >= NORMAL_SHOTS:
		_finish("銅板用完，已投進 %d / %d 孔。" % [_sunk, POCKET_COUNT])


func _finish(message: String) -> void:
	_active = false
	_ended = true
	_shot.velocity = Vector2.ZERO
	_feedback = message
	_preview.clear()


func _can_set_up() -> bool:
	return not _ended and not _active and (_assisted or _shots < NORMAL_SHOTS)


func _seconds_limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS


func _direction() -> Vector2:
	var angle := deg_to_rad(float(_aim_degrees))
	return Vector2(sin(angle), -cos(angle))


func _new_shot() -> Shot:
	var shot := Shot.new()
	shot.velocity = _direction() * (2.4 + 0.72 * float(_power))
	return shot


func _orient(board: Board, detent: int) -> void:
	board.detent = detent
	board.angle = board.base_angle + float(detent) * BOARD_STEP
	board.axis = Vector2.from_angle(board.angle)
	board.normal = Vector2(-board.axis.y, board.axis.x)
	board.a = board.center - board.axis * board.half_length
	board.b = board.center + board.axis * board.half_length


func _material_at(position: Vector2) -> int:
	return FELT if _felt.has_point(position) else LACQUER


## The same fixed-step kernel runs the table and the limited assist preview.
## Sweeps preserve contact at thin boards and mouths even between frame samples.
func _step_shot(shot: Shot, sweep: Sweep, stop_at_contact := false) -> void:
	shot.elapsed += TICK
	var speed := shot.velocity.length()
	if speed <= STOP_SPEED or shot.elapsed >= SHOT_SECONDS:
		shot.result = Result.STOPPED
		return
	var drag := FELT_DRAG if _material_at(shot.position) == FELT else LACQUER_DRAG
	shot.velocity *= maxf(0.0, 1.0 - drag * TICK / speed)

	var remaining := TICK
	for _contact_index in 2:
		var delta := shot.velocity * remaining
		_find_contact(shot.position, delta, shot.velocity, sweep)
		var fraction := sweep.time if sweep.kind != Contact.NONE else 1.0
		var motion := delta * fraction
		shot.position += motion
		shot.distance += motion.length()
		if sweep.kind == Contact.NONE:
			break
		_apply_contact(shot, sweep)
		remaining *= 1.0 - fraction
		if stop_at_contact or shot.result != Result.MOVING or remaining <= 0.000001:
			break


func _find_contact(point: Vector2, delta: Vector2, velocity: Vector2, result: Sweep) -> void:
	result.clear()
	for index in _boards.size():
		var board := _boards[index]
		if board.placed:
			_offer_board(point, delta, board, index, result)

	var speed := velocity.length()
	var heading := velocity / speed if speed > STOP_SPEED else Vector2.ZERO
	for index in _pockets.size():
		var center := _pockets[index]
		var mouth := _circle_entry(point, delta, center, POT_RADIUS)
		if speed <= POT_SPEED:
			result.offer(mouth, Contact.POT, index)
		var rim := _circle_entry(point, delta, center, RIM_RADIUS)
		if rim >= result.time:
			continue
		var offset := center - point
		var across := absf(offset.cross(heading))
		if speed > POT_SPEED or across > POT_RADIUS:
			var normal := (point + delta * rim - center).normalized()
			result.offer(rim, Contact.RIM, index, normal)

	# Leaving the table ends the shot in the vendor's catch tray.
	for axis in 2:
		var motion: float = delta[axis]
		if is_zero_approx(motion):
			continue
		var edge: float = TRAY.end[axis] if motion > 0.0 else TRAY.position[axis]
		result.offer((edge - point[axis]) / motion, Contact.EDGE, -1)


func _offer_board(point: Vector2, delta: Vector2, board: Board, index: int, result: Sweep) -> void:
	var radius := BOARD_RADIUS + COIN_RADIUS
	var offset := point - board.center
	var distance := offset.dot(board.normal)
	var across := delta.dot(board.normal)
	if absf(across) > 0.00000001:
		var side := -1.0 if across > 0.0 else 1.0
		if side * distance >= radius - CONTACT_EPSILON:
			var hit := (radius * side - distance) / across
			if hit >= -CONTACT_EPSILON and hit <= 1.0:
				var along := (offset + delta * hit).dot(board.axis)
				if absf(along) <= board.half_length:
					result.offer(maxf(0.0, hit), Contact.BOARD, index, board.normal * side)
	for cap_index in 2:
		var cap := board.a if cap_index == 0 else board.b
		var hit := _circle_entry(point, delta, cap, radius)
		if hit < result.time:
			var normal := (point + delta * hit - cap).normalized()
			result.offer(hit, Contact.BOARD, index, normal)


func _circle_entry(point: Vector2, delta: Vector2, center: Vector2, radius: float) -> float:
	var offset := point - center
	var a := delta.length_squared()
	var b := offset.dot(delta)
	var c := offset.length_squared() - radius * radius
	if a < 0.000000000001 or b >= 0.0 or c < -0.00001:
		return INF
	var discriminant := b * b - a * c
	if discriminant < 0.0:
		return INF
	var time := (-b - sqrt(discriminant)) / a
	return maxf(0.0, time) if time >= -CONTACT_EPSILON and time <= 1.0 else INF


func _apply_contact(shot: Shot, hit: Sweep) -> void:
	shot.impact = shot.position
	match hit.kind:
		Contact.BOARD:
			var board := _boards[hit.index]
			var incoming := shot.velocity
			shot.velocity = _reflect(incoming, hit.normal, board.normal_retention, board.tangent_retention)
			shot.bounces += 1
			shot.last_surface = "斜板 A" if hit.index == BOARD_A else "斜板 B"
			if -incoming.dot(hit.normal) >= MIN_USEFUL_IMPACT and incoming.normalized().dot(shot.velocity.normalized()) <= MAX_USEFUL_DOT:
				shot.contacts_mask |= 1 << hit.index
			shot.position += hit.normal * CONTACT_EPSILON
		Contact.RIM:
			shot.velocity = _reflect(shot.velocity, hit.normal, 0.45, 0.80)
			shot.rim_scrapes += 1
			shot.last_surface = "孔緣"
			shot.position += hit.normal * CONTACT_EPSILON
		Contact.POT:
			shot.pocket = hit.index
			shot.result = Result.POTTED
		Contact.EDGE:
			shot.result = Result.OFF_EDGE


func _reflect(velocity: Vector2, normal: Vector2, rebound: float, glide: float) -> Vector2:
	var normal_velocity := normal * velocity.dot(normal)
	return (velocity - normal_velocity) * glide - normal_velocity * rebound


func _refresh_preview() -> void:
	_preview_dirty = false
	_preview = PackedVector2Array([LAUNCHER])
	var forecast := _new_shot()
	var hit := Sweep.new()
	for index in PREVIEW_TICKS:
		_step_shot(forecast, hit, true)
		var terminal := hit.kind != Contact.NONE or forecast.result != Result.MOVING
		if terminal or index % 12 == 11 or index == PREVIEW_TICKS - 1:
			_preview.append(forecast.position)
		if terminal:
			return


func _note(note: int) -> void:
	if _notes.size() < 8:
		_notes.append(note)


func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes


func snapshot() -> Dictionary:
	if _assisted and _preview_dirty and _can_set_up():
		_refresh_preview()
	var success := _sunk == POCKET_COUNT
	var devil := success and _double_potted
	var mistakes := 0 if _assisted else _misses
	var elapsed := minf(float(_ticks) * TICK, _seconds_limit())
	var called := mini(_sunk, POCKET_COUNT - 1)
	var pockets: Array[Dictionary] = []
	for index in _pockets.size():
		pockets.append({"id": index, "center": _pockets[index], "filled": index < _sunk, "called": not _ended and index == called})
	var boards: Array[Dictionary] = []
	for index in _boards.size():
		var board := _boards[index]
		boards.append({
			"id": index, "center": board.center, "a": board.a, "b": board.b, "angle": board.angle,
			"detent": board.detent, "placed": board.placed, "half_length": board.half_length, "radius": BOARD_RADIUS,
		})
	return {
		"layout": _layout, "assisted": _assisted, "selected": _selected,
		"aim": deg_to_rad(float(_aim_degrees)), "aim_degrees": _aim_degrees, "direction": _direction(),
		"power": _power, "power_fraction": float(_power) / float(MAX_POWER),
		"tray": TRAY, "felt": _felt, "launcher": LAUNCHER, "boards": boards, "pockets": pockets,
		"called": called, "sunk": _sunk, "shots_left": -1 if _assisted else maxi(0, NORMAL_SHOTS - _shots),
		"shots": _shots, "misses": _misses, "mistakes": mistakes,
		"coin": _shot.position, "velocity": _shot.velocity, "speed": _shot.velocity.length(),
		"active": _active, "shot_elapsed": _shot.elapsed, "material": _material_at(_shot.position),
		"shot_bounces": _shot.bounces, "contacts_mask": _shot.contacts_mask, "rim_scrapes": _shot.rim_scrapes,
		"impact": _shot.impact, "last_surface": _shot.last_surface, "settled_pocket": _shot.pocket,
		"trail": _trail.duplicate(), "preview": _preview.duplicate() if _assisted and _can_set_up() else PackedVector2Array(),
		"elapsed": elapsed, "remaining": _seconds_limit() - elapsed, "ended": _ended, "success": success, "devil": devil,
		"ordinary_eligible": _ended and (_participated or success),
		"score": maxi(0, _sunk * POT_POINTS + int(devil) * DOUBLE_POINTS - mistakes * LOSS_POINTS), "feedback": _feedback,
	}
