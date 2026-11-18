extends RefCounted
class_name CottonWindModel

const ROUND_SECONDS := 120.0
const SUBSTEP := 1.0 / 120.0
const SPEED := 120.0
const STRAND_MASS := 0.6
const MAX_STRANDS := 128
const LIMIT_MIN := Vector2(-120, 45)
const LIMIT_MAX := Vector2(120, 155)

var _s: Dictionary
var _motion := Vector2.ZERO
var _target := Vector2.ZERO
var _pursuing := false
var _emission := 0.0
var _revision := 0

func _init() -> void:
	reset()

static func _empty_bands() -> Array:
	var bands: Array = []
	for i in 3:
		var cells: Array[float] = []
		cells.resize(12)
		cells.fill(0.0)
		bands.append(cells)
	return bands

func reset(assisted: bool = false, variant: int = 0) -> void:
	_motion = Vector2.ZERO
	_pursuing = false
	_emission = 0.0
	_revision += 1
	_s = {"elapsed": 0.0, "remaining": ROUND_SECONDS, "ended": false, "success": false,
		"devil": false, "ordinary_eligible": false, "participated": false, "assisted": assisted,
		"variant": posmod(variant, 2), "score": 0, "mistakes": 0, "stick": Vector3(0,90,70),
		"angle": 0.0, "omega": 0.0, "travel": 0.0, "spin_travel": 0.0, "bands": _empty_bands(),
		"quality": [], "uniform": false, "ratio": 0.0, "revision": _revision, "wind": 0.0,
		"strands": [], "tail": {}, "rejoins": 0, "helper": false, "helper_stick": Vector3(0,90,146),
		"helper_angle": 0.0, "helper_yielding": false, "helper_bands": _empty_bands(),
		"material": {"emitted": 0.0, "in_flight": 0.0, "player": 0.0, "helper": 0.0, "hanging": 0.0, "lost": 0.0},
		"feedback": "移棒分別餵到三段，同時轉棒把絲捲勻"}
	_s.wind = _wind(0.0)
	_quality()

func set_motion(direction: Vector2) -> void:
	if _s.ended or not direction.is_finite():
		return
	_pursuing = false
	var scale := maxf(absf(direction.x), absf(direction.y))
	_motion = (direction / scale).normalized() if scale > 1.0 else direction.limit_length()

func move_stick_to(point: Vector2) -> void:
	if _s.ended or not point.is_finite():
		return
	_target = point.clamp(LIMIT_MIN, LIMIT_MAX)
	_motion = Vector2.ZERO
	_pursuing = true

func set_spin(direction: int) -> void:
	if not _s.ended:
		_s.omega = 3.0 * signi(direction)

func clear_input() -> void:
	_pursuing = false
	_motion = Vector2.ZERO
	_s.omega = 0.0

func toggle_helper() -> void:
	if not _s.ended:
		_s.helper = not _s.helper
		_s.helper_yielding = false

func finish() -> void:
	if _s.ended:
		return
	if _s.uniform:
		_s.ended = true
		_s.success = true
		_s.devil = _s.rejoins > 0
		_s.ordinary_eligible = _s.participated
		_s.feedback = "三段棉糖均勻，收捲完成"
		clear_input()
	else:
		_s.mistakes = mini(1000000000, _s.mistakes + 1)
		_s.feedback = "左右移棒，補足較薄的一段"
		for i in 3:
			var q: Dictionary = _s.quality[i]
			if not q.ready:
				var reason := "糖絲不足" if q.mass < 12.0 else "轉棒以補足較薄的角度"
				_s.feedback = "第%d段%s" % [i + 1, reason]
				break
	_score()

func step(delta: float) -> void:
	if _s.ended or not is_finite(delta) or delta <= 0.0:
		return
	var duration := minf(minf(delta, 0.25), _s.remaining)
	var steps := ceili(duration / SUBSTEP)
	var h := duration / steps
	for i in steps:
		var previous: Vector3 = _s.stick
		var position := Vector2(previous.x, previous.z)
		if _pursuing:
			position = position.move_toward(_target, SPEED * h)
		else:
			position = (position + _motion * SPEED * h).clamp(LIMIT_MIN, LIMIT_MAX)
		_s.stick = Vector3(position.x, 90, position.y)
		_s.travel += previous.distance_to(_s.stick)
		_s.angle = fposmod(_s.angle + _s.omega * h, TAU)
		_s.spin_travel += absf(_s.omega) * h
		_s.elapsed += h
		_s.wind = _wind(_s.elapsed)
		var previous_helper: Vector3 = _s.helper_stick
		if _s.helper:
			_move_helper(h)
		_advance_tail(h)
		_advance_strands(h, previous, previous_helper)
		_emission += h
		var interval := 0.12 if _s.variant == 0 else 0.15
		if _emission >= interval - 1e-10:
			_emission -= interval
			_emit()
	_s.participated = _s.material.player >= 1.0 and _s.travel >= 6.0 and _s.spin_travel >= 0.5
	_s.remaining = maxf(0.0, ROUND_SECONDS - _s.elapsed)
	if _s.remaining < 1e-9:
		_s.elapsed = ROUND_SECONDS
		_s.remaining = 0.0
		_s.ended = true
		_s.ordinary_eligible = _s.participated
		_s.feedback = "時間到，保留本次棉糖作品"
		clear_input()
	_score()

func snapshot() -> Dictionary:
	return _s.duplicate(true)

func _wind(time: float) -> float:
	var wind := 5.0 * sin(time * 1.1) if _s.variant == 0 else 8.0 * sin(time * 1.4 + 1.2)
	return wind * (0.55 if _s.assisted else 1.0)

func _emit() -> void:
	if _s.strands.size() >= MAX_STRANDS:
		return
	var x := 18.0 * sin(_s.elapsed * 0.87) if _s.variant == 0 else 22.0 * sin(_s.elapsed * 1.03 + 0.7)
	var source := Vector3(x, 40, 0)
	_s.strands.append({"previous": source, "position": source, "velocity": Vector3(_s.wind,100,80),
		"age": 0.0, "material": STRAND_MASS, "collectible": STRAND_MASS})
	_s.material.emitted += STRAND_MASS
	_s.material.in_flight += STRAND_MASS

func _advance_strands(h: float, previous: Vector3, previous_helper: Vector3) -> void:
	for i in range(_s.strands.size() - 1, -1, -1):
		var strand: Dictionary = _s.strands[i]
		strand.previous = strand.position
		strand.position += strand.velocity * h + Vector3(0, -40.0 * h * h, 0)
		strand.velocity.y -= 80.0 * h
		strand.age += h
		strand.collectible = _collectible(strand.age)
		var consumed := _collect(strand, previous, false, h)
		if not consumed and _s.helper and not _s.helper_yielding:
			consumed = _collect(strand, previous_helper, true, h)
		if not consumed and strand.age < 3.0:
			continue
		_s.material.in_flight -= strand.material
		_s.material.lost += strand.material - (strand.collectible if consumed else 0.0)
		_s.strands.remove_at(i)

static func _band(axial: float) -> int:
	return 0 if axial < -30.0 else (1 if axial < 30.0 else 2)

static func _cell(angle: float) -> int:
	return mini(11, floori(fposmod(angle, TAU) * 12.0 / TAU))

static func radius(mass: float) -> float:
	return minf(28.0, 6.0 + 4.0 * sqrt(mass))

static func _surface_point(center: Vector3, axial: float, angle: float, r: float) -> Vector3:
	return center + Vector3(axial, cos(angle) * r, sin(angle) * r)

static func _collectible(age: float) -> float:
	return STRAND_MASS * clampf(1.0 - 0.34 * age, 0.15, 1.0)

func _collect(strand: Dictionary, previous: Vector3, helper: bool, h: float) -> bool:
	var center: Vector3 = _s.helper_stick if helper else _s.stick
	var a: Vector3 = strand.previous - previous
	var b: Vector3 = strand.position - center
	var margin := 28.0 + (4.0 if _s.assisted else 0.0)
	if minf(a.z, b.z) > margin or maxf(a.z, b.z) < -margin or minf(a.y, b.y) > margin or maxf(a.y, b.y) < -margin:
		return false
	# Relative motion sweeps both the finite filament segment and the moving axis.
	var pair := Geometry3D.get_closest_points_between_segments(a, b, Vector3(-90,0,0), Vector3(90,0,0))
	var axial := pair[1].x
	var band := _band(axial)
	var segment := b - a
	var fraction := clampf((pair[0] - a).dot(segment) / segment.length_squared(), 0, 1) if segment.length_squared() > 0.0 else 1.0
	var contact_center := previous.lerp(center, fraction)
	var time_after_contact := (1.0 - fraction) * h
	var angle: float = _s.helper_angle - 2.0 * time_after_contact if helper else _s.angle - _s.omega * time_after_contact
	var velocity: Vector3 = strand.velocity + Vector3.UP * 80.0 * time_after_contact
	var radial := pair[0] - pair[1]
	# An on-axis crossing uses its approach side; a purely axial contact uses +Y.
	if radial.y == 0.0 and radial.z == 0.0:
		radial = a
	var world_angle := 0.0 if radial.y == 0.0 and radial.z == 0.0 else atan2(radial.z, radial.y)
	var local_angle := world_angle - angle
	var cell := _cell(local_angle)
	var bands: Array = _s.helper_bands if helper else _s.bands
	var contact_radius := radius(bands[band][cell]) + (4.0 if _s.assisted else 0.0)
	if pair[0].distance_squared_to(pair[1]) > contact_radius * contact_radius:
		return false
	strand.collectible = _collectible(strand.age - time_after_contact)
	var material: float = strand.collectible
	if not helper and band != 1 and contact_center.z >= 120.0 and _s.tail.is_empty():
		var anchor := _surface_point(contact_center, axial, angle + local_angle, radius(bands[band][cell]))
		var tip := contact_center + pair[0] - velocity.normalized() * 5.0
		var rest := anchor.distance_to(tip)
		_s.tail = {"anchor_band": band, "axial": axial, "local_angle": local_angle,
			"anchor": anchor, "free_end": tip, "material": material * 0.4, "rest_length": rest,
			"length": rest, "tension": 0.0, "age": 0.0, "near_break": false, "receiver_band": 2 - band,
			"receiver_margin": 8.0 if _s.assisted else 4.0}
		_s.material.hanging = _s.tail.material
		material *= 0.6
	_deposit(band, cell, material, helper)
	return true

func _deposit(band: int, cell: int, material: float, helper: bool) -> float:
	var bands: Array = _s.helper_bands if helper else _s.bands
	var accepted := minf(material, 4.0 - bands[band][cell])
	bands[band][cell] += accepted
	_s.material["helper" if helper else "player"] += accepted
	_s.material.lost += material - accepted
	if accepted > 0:
		_revision += 1
		_s.revision = _revision
		if not helper:
			_quality()
	return accepted

func _advance_tail(h: float) -> void:
	if _s.tail.is_empty():
		return
	var tail: Dictionary = _s.tail
	tail.age += h
	tail.free_end.x += _s.wind * h * 0.35
	var angle: float = tail.local_angle + _s.angle
	var r := radius(_s.bands[tail.anchor_band][_cell(tail.local_angle)])
	tail.anchor = _surface_point(_s.stick, tail.axial, angle, r)
	tail.length = tail.anchor.distance_to(tail.free_end)
	tail.tension = maxf(0.0, tail.length - tail.rest_length)
	tail.near_break = tail.tension >= 80.0
	if tail.tension > 140.0 or tail.age >= (3.5 if _s.assisted else 3.0):
		_s.material.lost += tail.material
		_s.material.hanging = 0.0
		_s.tail = {}
		return
	if not tail.near_break or _s.omega == 0.0:
		return
	var relative: Vector3 = tail.free_end - _s.stick
	var axial := clampf(relative.x, -90, 90)
	var receiver: int = tail.receiver_band
	if _band(axial) != receiver:
		return
	var cell := _cell(atan2(relative.z, relative.y) - _s.angle)
	var contact_radius: float = radius(_s.bands[receiver][cell]) + tail.receiver_margin
	if relative.distance_squared_to(Vector3(axial, 0, 0)) <= contact_radius * contact_radius:
		var accepted := _deposit(receiver, cell, tail.material, false)
		_s.material.hanging = 0.0
		_s.tail = {}
		if accepted > 0.0:
			_s.rejoins += 1
			_s.feedback = "另一端接回了將斷的絲！"

func _move_helper(h: float) -> void:
	var stick: Vector3 = _s.stick
	var center: Vector3 = _s.helper_stick
	var band := 0
	var lowest := INF
	for i in 3:
		var total := 0.0
		for mass in _s.helper_bands[i]:
			total += mass
		if total < lowest:
			band = i
			lowest = total
	# Stay downstream so strands reach the player first, even across different substeps.
	var depth := maxf(146.0, minf(155.0, stick.z + 32.0))
	var target := Vector3((1 - band) * 60.0, 90, depth)
	if absf(depth - stick.z) < 32.0:
		target.x = -120.0 if stick.x >= 0.0 else 120.0
	_s.helper_stick = center.move_toward(target, 75.0 * h)
	_s.helper_yielding = absf(_s.helper_stick.z - stick.z) < 32.0 and absf(_s.helper_stick.x - stick.x) < 180.0
	_s.helper_angle = fposmod(_s.helper_angle + 2.0 * h, TAU)

func _quality() -> void:
	_s.quality.clear()
	var minimum := INF
	var maximum := 0.0
	var ready := true
	for band in _s.bands:
		var total := 0.0
		var squares := 0.0
		var coverage := 0
		for mass: float in band:
			total += mass
			squares += mass * mass
			coverage += int(mass >= 0.15)
		var mean := total / 12.0
		var cv := sqrt(maxf(0.0, squares / 12.0 - mean * mean)) / mean if total > 0 else 0.0
		var ok := total >= 12.0 and coverage >= (7 if _s.assisted else 8) and cv <= (0.8 if _s.assisted else 0.65)
		_s.quality.append({"mass": total, "coverage": coverage, "cv": cv, "ready": ok})
		minimum = minf(minimum, total)
		maximum = maxf(maximum, total)
		ready = ready and ok
	_s.ratio = maximum / minimum if minimum > 0 else 0.0
	_s.uniform = ready and _s.ratio <= (1.5 if _s.assisted else 1.35)

func _score() -> void:
	var points := 100 * (int(_s.success) + int(_s.devil))
	for q in _s.quality:
		points += 100 * int(q.ready)
	_s.score = maxi(0, points - 20 * _s.mistakes)
