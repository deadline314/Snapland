extends RefCounted
class_name BuoyRelayModel

## Side-view relay along one axis: x is distance from the shore. Stations sit at
## fixed x; mail tubes drift on the tide. One Space key charges, reels and passes.
const ROUND_SECONDS := 150.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const STATIONS := [0.0, 5.0, 10.0]
const STATION_NAMES := ["岸邊", "中繼浮標", "外海浮標"]
const MIN_THROW := 1.5
const MAX_THROW := 10.6
const CHARGE_SECONDS := 1.3
const FLIGHT_SECONDS := 0.8
const RING_FLOAT := 1.2
const ASSIST_RING_FLOAT := 2.6
const CATCH_RADIUS := 0.55
const ASSIST_CATCH_RADIUS := 0.8
const PASS_RADIUS := 0.6
const ASSIST_PASS_RADIUS := 1.0
const REEL_SPEED := 2.2
const WOBBLE_RATE := 2.4
const SLIP_WOBBLE := 0.75
const BUNDLE_SLIP_WOBBLE := 0.55
const SLIP_SECONDS := 0.35
const MISS_RETURN := 2.0
const SEA_LIMIT := 17.6
const TUBE_POINTS := 100
const DIRECT_BONUS := 50
## Retries alternate tube spacing and the tide push (per-tube drift differs so pairs converge).
const VARIANTS := [
	{"name": "向岸潮", "tubes": [[13.0, 0.10], [15.2, -0.06], [16.9, 0.22]]},
	{"name": "離岸潮", "tubes": [[12.6, 0.18], [14.4, -0.04], [16.8, -0.12]]},
]

var _assisted := false
var _variant := 0
var _elapsed := 0.0
var _phase := "aim_catch"
var _station := 2
var _charging := false
var _power := 0.0
var _ring := {}
var _tubes: Array[Dictionary] = []
var _held: Array[int] = []
var _reeling := false
var _strain := 0.0
var _miss_timer := 0.0
var _delivered := 0
var _direct := 0
var _slips := 0
var _misses := 0
var _double := false
var _ended := false
var _success := false
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, VARIANTS.size())
	_elapsed = 0.0
	_phase = "aim_catch"
	_station = 2
	_charging = false
	_power = 0.0
	_ring = {}
	_tubes.clear()
	var spec: Array = VARIANTS[_variant].tubes
	for index in spec.size():
		_tubes.append({"id": index, "x": float(spec[index][0]), "drift": float(spec[index][1]), "phase": index * 1.7, "state": "drifting"})
	_held.clear()
	_reeling = false
	_strain = 0.0
	_miss_timer = 0.0
	_delivered = 0
	_direct = 0
	_slips = 0
	_misses = 0
	_double = false
	_ended = false
	_success = false
	_feedback = "按住空白蓄力，放開把浮環投向漂流郵筒"

func _catch_radius() -> float:
	return ASSIST_CATCH_RADIUS if _assisted else CATCH_RADIUS

func _pass_radius() -> float:
	return ASSIST_PASS_RADIUS if _assisted else PASS_RADIUS

func throw_distance(power: float) -> float:
	return lerpf(MIN_THROW, MAX_THROW, clampf(power, 0.0, 1.0))

## The single action key: charge a throw, or hold to reel a caught tube.
func set_action(pressed: bool) -> void:
	if _ended:
		return
	match _phase:
		"aim_catch", "aim_pass":
			if pressed:
				_charging = true
				_power = 0.0
			elif _charging:
				_charging = false
				_throw()
		"reeling":
			_reeling = pressed
		_:
			pass

func clear_input() -> void:
	_charging = false
	_power = 0.0
	_reeling = false

func _throw() -> void:
	var origin: float = STATIONS[_station]
	if _phase == "aim_catch":
		_ring = {"from": origin, "to": origin + throw_distance(_power), "time": 0.0, "kind": "ring"}
		_phase = "ring_flight"
		_feedback = "浮環飛出 %.1f" % throw_distance(_power)
	else:
		_ring = {"from": origin, "to": origin - throw_distance(_power), "time": 0.0, "kind": "pass"}
		_phase = "pass_flight"
		_feedback = "把郵筒拋向岸邊 %.1f" % throw_distance(_power)

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
	if _charging:
		_power = minf(1.0, _power + dt / CHARGE_SECONDS)
	for tube: Dictionary in _tubes:
		if tube.state == "drifting":
			tube.x = clampf(tube.x + tube.drift * dt, STATIONS[2] + 0.8, SEA_LIMIT)
	match _phase:
		"ring_flight":
			_ring.time += dt
			if _ring.time >= FLIGHT_SECONDS:
				_phase = "ring_float"
				_ring.time = 0.0
				_feedback = "浮環落水，郵筒漂進圈內就會套住"
		"ring_float":
			_ring.time += dt
			_try_catch()
			if _phase == "ring_float" and _ring.time >= (ASSIST_RING_FLOAT if _assisted else RING_FLOAT):
				_phase = "aim_catch"
				_ring = {}
				_misses += 1
				_feedback = "沒套到，收回浮環再投一次"
		"reeling":
			_step_reel(dt)
		"pass_flight":
			_ring.time += dt
			if _ring.time >= FLIGHT_SECONDS:
				_land_pass()
		"pass_return":
			_miss_timer -= dt
			if _miss_timer <= 0.0:
				_phase = "aim_pass"
				_feedback = "郵筒拉回來了，再拋一次"
	if not _ended and _elapsed >= ROUND_SECONDS:
		_ended = true
		_charging = false
		_feedback = "時間到：送達 %d / 3 個郵筒" % _delivered

func _try_catch() -> void:
	var caught: Array[int] = []
	for tube: Dictionary in _tubes:
		if tube.state == "drifting" and absf(tube.x - _ring.to) <= _catch_radius():
			caught.append(tube.id)
	if caught.is_empty():
		return
	for id in caught:
		_tubes[id].state = "hooked"
		_tubes[id].x = _ring.to
	_held = caught
	if caught.size() >= 2:
		_double = true
	_phase = "reeling"
	_ring = {}
	_strain = 0.0
	_feedback = "套住 %d 個郵筒！按住空白拉回" % caught.size()

func wobble(tube_id: int) -> float:
	return sin(_elapsed * WOBBLE_RATE + _tubes[tube_id].phase)

func bundle_wobble() -> float:
	if _held.is_empty():
		return 0.0
	var total := 0.0
	for id in _held:
		total += wobble(id)
	return total / _held.size()

## Reeling while the tube rides a wobble crest builds strain until the rope slips.
func _step_reel(dt: float) -> void:
	if not _reeling:
		_strain = maxf(0.0, _strain - dt)
		return
	# Tubes on one ring swing together, so the bundle follows their mean wobble.
	var crest := absf(bundle_wobble()) > (SLIP_WOBBLE if _held.size() == 1 else BUNDLE_SLIP_WOBBLE)
	_strain = _strain + dt if crest else maxf(0.0, _strain - dt * 2.0)
	if _strain >= SLIP_SECONDS:
		for id in _held:
			_tubes[id].state = "drifting"
		_held.clear()
		_slips += 1
		_strain = 0.0
		_reeling = false
		_phase = "aim_catch"
		_feedback = "郵筒晃太大時硬拉，繩子滑脫了"
		return
	var station: float = STATIONS[_station]
	for id in _held:
		_tubes[id].x = maxf(station, _tubes[id].x - REEL_SPEED * dt)
	if _tubes[_held[0]].x <= station + 0.001:
		for id in _held:
			_tubes[id].state = "held"
		_reeling = false
		_phase = "aim_pass"
		_feedback = "郵筒到手，蓄力拋向中繼浮標或直接上岸"

func _land_pass() -> void:
	var landing: float = _ring.to
	var target := -1
	for index in range(_station - 1, -1, -1):
		if absf(landing - STATIONS[index]) <= _pass_radius():
			target = index
	_ring = {}
	if target < 0:
		_misses += 1
		_phase = "pass_return"
		_miss_timer = MISS_RETURN
		_feedback = "落點沒對準，夥伴沒鎖定；繩子把郵筒拉回來"
		return
	if target == 0:
		var skipped := _station - 1
		_direct += skipped
		_delivered += _held.size()
		for id in _held:
			_tubes[id].state = "delivered"
		_held.clear()
		_feedback = "送上岸！已送達 %d / 3" % _delivered + ("，遠投省下交接" if skipped > 0 else "")
		_station = 2
		_phase = "aim_catch"
		if _delivered >= 3:
			_ended = true
			_success = true
			_feedback = "三個郵筒都送上岸"
		return
	_station = target
	_phase = "aim_pass"
	_feedback = "中繼浮標接住了，鏡頭切到%s；再拋向岸邊" % STATION_NAMES[target]

## Lock appears when the current charge would land inside a receiving station's ring.
func lock_target() -> int:
	if _phase != "aim_pass" or not _charging:
		return -1
	var landing: float = STATIONS[_station] - throw_distance(_power)
	for index in range(_station - 1, -1, -1):
		if absf(landing - STATIONS[index]) <= _pass_radius():
			return index
	return -1

## INF when nothing is charging, so snapshots stay comparable (NAN never equals itself).
func preview_landing() -> float:
	if not _charging:
		return INF
	var origin: float = STATIONS[_station]
	return origin + throw_distance(_power) if _phase == "aim_catch" else origin - throw_distance(_power)

func snapshot() -> Dictionary:
	var devil := _success and _double
	var tubes: Array = []
	for tube: Dictionary in _tubes:
		var row := tube.duplicate()
		row.wobble = sin(_elapsed * WOBBLE_RATE + tube.phase)
		tubes.append(row)
	var ring := _ring.duplicate()
	if not ring.is_empty():
		var progress := clampf(float(ring.time) / FLIGHT_SECONDS, 0.0, 1.0) if _phase in ["ring_flight", "pass_flight"] else 1.0
		ring.x = lerpf(ring.from, ring.to, progress)
		ring.height = sin(PI * progress) * 1.6 if _phase in ["ring_flight", "pass_flight"] else 0.0
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": VARIANTS[_variant].name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil, "devil_success": devil,
		"ordinary_eligible": _ended, "score": _delivered * TUBE_POINTS + _direct * DIRECT_BONUS, "mistakes": _slips + _misses,
		"phase": _phase, "station": _station, "stations": STATIONS, "station_x": STATIONS[_station], "charging": _charging, "power": _power,
		"throw_preview": preview_landing(), "lock": lock_target(), "show_landing": _assisted, "ring": ring, "tubes": tubes, "held": _held.duplicate(),
		"reeling": _reeling, "strain": _strain / SLIP_SECONDS, "bundle_wobble": bundle_wobble(), "delivered": _delivered, "direct": _direct, "slips": _slips, "misses": _misses,
		"double_catch": _double, "catch_radius": _catch_radius(), "pass_radius": _pass_radius(), "feedback": _feedback, "last_event": _feedback,
	}
