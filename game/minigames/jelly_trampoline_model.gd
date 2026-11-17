extends RefCounted
class_name JellyTrampolineModel

const ROUND_SECONDS := 60.0
const SUBSTEP := 1.0 / 120.0
const GRAVITY := 900.0
const RADIUS := 28.0
const MASSES := [[1.0, 1.15, 0.9], [1.15, 0.9, 1.0]]
const HEIGHTS := [[240.0, 260.0, 220.0], [260.0, 220.0, 240.0]]

var _s: Dictionary
var _held := false

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_held = false
	_s = {"elapsed": 0.0, "remaining": ROUND_SECONDS, "score": 0, "mistakes": 0,
		"ended": false, "success": false, "devil": false, "ordinary_eligible": false,
		"participated": false, "assisted": assisted, "variant": posmod(variant, 2),
		"delivered": 0, "bell_deliveries": 0, "charging": false, "charge_seconds": 0.0,
		"depth": 0.0, "tilt": 21.0, "helper": false, "feedback": "按住蓄彈，放開才發射；斜壓改變水平速度",
		"bed": {"x": 340.0, "y": 520.0, "half_width": 90.0 if assisted else 70.0},
		"target": {"x": 870.0, "y": 240.0, "half_width": 115.0 if assisted else 90.0},
		"bell": {"x": 930.0, "y": 190.0, "radius": 42.0 if assisted else 32.0}}
	_new_fruit(_s)

func move_bed(direction: int) -> void:
	if not _s.ended and direction != 0:
		_s.bed.x = clampf(_s.bed.x + 40.0 * signi(direction), 180.0, 620.0)
		if _s.fruit.ready:
			_s.fruit.x = _s.bed.x

func adjust_tilt(direction: int) -> void:
	if not _s.ended and direction != 0:
		_s.tilt = clampf(_s.tilt + 7.0 * signi(direction), -35.0, 35.0)

func begin_charge() -> void:
	if _s.ended or _held:
		return
	_held = true
	_s.charging = _s.fruit.ready

func release_charge() -> void:
	if _s.ended or not _held:
		return
	_held = false
	if _s.fruit.ready and _s.charging and _s.charge_seconds >= 0.15:
		var speed := sqrt(1000000.0 * _s.depth * _s.depth / _s.fruit.mass)
		var angle := deg_to_rad(float(_s.tilt))
		_s.fruit.vx = speed * sin(angle)
		_s.fruit.vy = -speed * cos(angle)
		_s.fruit.ready = false
		_s.participated = true
		_s.feedback = "已發射；空中移床只影響實際回接"
	elif _s.fruit.ready:
		_s.feedback = "至少按住0.15秒再放開"
	_stop_charge(_s)
	if _s.fruit.ready:
		_s.fruit.y = 492.0

func cancel_charge() -> void:
	_held = false
	_stop_charge(_s)
	if _s.fruit.ready:
		_s.fruit.y = 492.0

func clear_input() -> void:
	cancel_charge()

func toggle_helper() -> void:
	if not _s.ended:
		_s.helper = not _s.helper

func reset_fruit() -> void:
	if _s.ended:
		return
	if not _s.fruit.ready or _s.charge_seconds > 0:
		_s.mistakes += 1
	_held = false
	_new_fruit(_s)
	_s.feedback = "當顆已重置；時間不回復"
	_refresh_score(_s)

func step(delta: float) -> void:
	if _s.ended or not is_finite(delta) or delta <= 0:
		return
	var bounded := minf(delta, 0.25)
	var count := ceili(bounded / SUBSTEP)
	for i in count:
		if _s.ended:
			break
		var h := minf(bounded / count, float(_s.remaining))
		var consumed := h
		if _s.fruit.ready:
			_charge(_s, h, _held)
		else:
			consumed = _flight(_s, h, _held)
			if not _s.ended and _s.fruit.ready:
				_charge(_s, h - consumed, _held)
		if not _s.ended:
			consumed = h
		_s.elapsed = minf(ROUND_SECONDS, _s.elapsed + consumed)
		if ROUND_SECONDS - _s.elapsed < 1.0e-9:
			_s.elapsed = ROUND_SECONDS
		_s.remaining = maxf(0.0, ROUND_SECONDS - _s.elapsed)
		if _s.remaining <= 0 and not _s.ended:
			_s.ended = true
			_s.feedback = "時間到；需實際送達三顆果實"
		if _s.ended:
			_s.ordinary_eligible = _s.participated
			_held = false
			_stop_charge(_s)
		_refresh_score(_s)

func _stop_charge(s: Dictionary) -> void:
	s.charging = false
	s.charge_seconds = 0.0
	s.depth = 0.0

func _charge(s: Dictionary, h: float, held: bool) -> void:
	s.charging = held
	if held:
		s.charge_seconds = minf(1.4, s.charge_seconds + h)
		s.depth = clampf(s.charge_seconds / 1.4, 0.0, 1.0)
		s.fruit.y = 492.0 + 40.0 * s.depth

func _new_fruit(s: Dictionary) -> void:
	_stop_charge(s)
	var index := mini(int(s.delivered), 2)
	s.target.y = HEIGHTS[s.variant][index]
	s.fruit = {"x": s.bed.x, "y": 492.0, "vx": 0.0, "vy": 0.0, "radius": RADIUS,
		"mass": MASSES[s.variant][index], "ready": true, "bell_touched": false}

func _refresh_score(s: Dictionary) -> void:
	s.score = maxi(0, s.delivered * 100 + (100 if s.success else 0) + (100 if s.devil else 0) - s.mistakes * 20)

# Descending ballistic crossing; the negative root is the upward crossing.
func _down_time(y: float, vy: float, plane: float) -> float:
	var discriminant := vy * vy + 2.0 * GRAVITY * (plane - y)
	if discriminant < 0:
		return INF
	var t := (-vy + sqrt(discriminant)) / GRAVITY
	return t if t >= 0 else INF

func _bell_fraction(start: Vector2, finish: Vector2, bell: Dictionary) -> float:
	var offset := start - Vector2(bell.x, bell.y)
	var radius: float = RADIUS + bell.radius
	if offset.length_squared() <= radius * radius:
		return 0.0
	var segment := finish - start
	var a := segment.length_squared()
	if a == 0:
		return INF
	var b := 2.0 * offset.dot(segment)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0:
		return INF
	var t := (-b - sqrt(discriminant)) / (2.0 * a)
	return t if t >= 0 and t <= 1 else INF

# At most four wall/beam events can occur in a bounded 1/120-second step.
func _flight(s: Dictionary, h: float, held: bool) -> float:
	var used := 0.0
	var f: Dictionary = s.fruit
	for event in 4:
		var left := h - used
		if left <= 0:
			break
		var t := left
		var contact := ""
		if f.vx != 0:
			var wall: float = 1060.0 if f.vx > 0 else 60.0
			var wall_t: float = (wall - f.x) / f.vx
			if wall_t >= 0 and wall_t <= t:
				t = wall_t
				contact = "wall"
		if f.vy < 0:
			var disc: float = f.vy * f.vy + 2.0 * GRAVITY * (60.0 - f.y)
			if disc >= 0:
				var top_t: float = (-f.vy - sqrt(disc)) / GRAVITY
				if top_t >= 0 and top_t <= t:
					t = top_t
					contact = "top"
		for surface in ["target", "bed"]:
			var support: Dictionary = s[surface]
			var support_t := _down_time(f.y, f.vy, support.y - RADIUS)
			if support_t <= t and f.vy + GRAVITY * support_t > 0 and absf(f.x + f.vx * support_t - support.x) <= support.half_width - RADIUS:
				t = support_t
				contact = surface
		var lost_t := _down_time(f.y, f.vy, 620.0 - RADIUS)
		if lost_t <= t:
			t = lost_t
			contact = "lost"
		var start := Vector2(f.x, f.y)
		var finish := start + Vector2(f.vx * t, f.vy * t + 0.5 * GRAVITY * t * t)
		if _bell_fraction(start, finish, s.bell) <= 1:
			f.bell_touched = true
		f.x += f.vx * t
		f.y += f.vy * t + 0.5 * GRAVITY * t * t
		f.vy += GRAVITY * t
		used += t
		match contact:
			"wall":
				f.vx *= -0.85
			"top":
				f.vy *= -0.60
			"target":
				s.delivered += 1
				if f.bell_touched:
					s.bell_deliveries += 1
				if s.delivered == 3:
					s.ended = true
					s.success = true
					s.devil = s.bell_deliveries >= 1
					s.feedback = "三顆真實送達！"
				else:
					_new_fruit(s)
					s.feedback = "果實送達；下一顆等你蓄彈"
				return used
			"bed":
				f.vy *= -0.65
				f.vx *= 0.85
				if held or s.helper or absf(f.vy) < 80:
					f.ready = true
					f.x = s.bed.x
					f.y = 492.0
					f.vx = 0.0
					f.vy = 0.0
					s.feedback = "實際回接穩定；等你蓄彈放開"
					return used
			"lost":
				s.mistakes += 1
				if not s.assisted:
					s.delivered = 0
					s.bell_deliveries = 0
				_new_fruit(s)
				s.feedback = "果實失落；移床接回，時間不回復"
				return used
	return used

func snapshot() -> Dictionary:
	var result := _s.duplicate(true)
	var preview := _s.duplicate(true)
	var points: Array[Vector2] = []
	if not preview.ended:
		if preview.fruit.ready and preview.depth > 0:
			var speed := sqrt(1000000.0 * preview.depth * preview.depth / preview.fruit.mass)
			preview.fruit.vx = speed * sin(deg_to_rad(float(preview.tilt)))
			preview.fruit.vy = -speed * cos(deg_to_rad(float(preview.tilt)))
			preview.fruit.ready = false
		if not preview.fruit.ready:
			points.append(Vector2(preview.fruit.x, preview.fruit.y))
			for i in 23:
				var predicted_fruit: Dictionary = preview.fruit
				for j in 12:
					_flight(preview, SUBSTEP, _held)
					if preview.fruit.ready or preview.ended:
						break
				points.append(Vector2(predicted_fruit.x, predicted_fruit.y))
				if preview.fruit.ready or preview.ended:
					break
	result.trajectory = points
	return result
