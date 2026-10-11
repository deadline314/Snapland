extends RefCounted
class_name KiteFlightModel

## Deterministic side-plane flight model for the kite-ring challenge.
const ROUND_SECONDS := 60.0
const RING_X := [520.0, 1040.0, 1560.0, 2080.0, 2600.0]
const RING_HEIGHT := [390.0, 285.0, 430.0, 315.0, 405.0]
const RING_HALF_OPENING := 54.0
const KITE_HALF_HEIGHT := 17.0
const CENTER_TOLERANCE := 18.0
const EDGE_TOLERANCE := 37.0
const MAX_RESCUES := 2
const GUST_PERIOD := 8.0
const GUST_PREVIEW_SECONDS := 1.25
const GUST_DURATION := 2.1
const GUST_STRENGTH := 185.0
const MAX_DELTA := 0.05
const APPROACH_DISTANCE := 120.0
const RESET_COOLDOWN := 0.7
const MIN_HEIGHT := 110.0
const MAX_HEIGHT := 650.0
const TENSION_RISK_THRESHOLD := 0.78
const TENSION_CLEAR_THRESHOLD := 0.58
const TENSION_SNAP_SECONDS := 0.65

var assisted := false
var x := 120.0
var height := 380.0
var vy := 0.0
var aim := 0.0
var boost := false
var reel := false
var elapsed := 0.0
var tension := 0.22
var speed := 118.0
var ring_index := 0
var center_hits := 0
var edge_hits := 0
var rescues_used := 0
var misses := 0
var mistakes := 0
var line_snaps := 0
var tension_risk_seconds := 0.0
var tension_warning := false
var ended := false
var won := false
var devil_won := false
var last_event := ""
var event_timer := 0.0
var _reset_timer := 0.0
var _snapshot_dirty := true
var _snapshot_cache: Dictionary = {}
var _event_markers: Array[Dictionary] = []

func reset(p_assisted: bool = false) -> void:
	assisted = p_assisted
	x = 120.0
	height = 380.0
	vy = 0.0
	aim = 0.0
	boost = false
	reel = false
	elapsed = 0.0
	tension = 0.22
	speed = 118.0
	ring_index = 0
	center_hits = 0
	edge_hits = 0
	rescues_used = 0
	misses = 0
	mistakes = 0
	line_snaps = 0
	tension_risk_seconds = 0.0
	tension_warning = false
	ended = false
	won = false
	devil_won = false
	last_event = ""
	event_timer = 0.0
	_reset_timer = 0.0
	_event_markers.clear()
	for gust_index in 8:
		_event_markers.append({"kind": "gust", "at": float(gust_index) * GUST_PERIOD})
	_snapshot_dirty = true

func set_aim(value: float) -> void:
	if not is_finite(value):
		aim = 0.0
	else:
		aim = clampf(value, -1.0, 1.0)
	_snapshot_dirty = true

func set_boost(value: bool) -> void:
	boost = value
	if value:
		reel = false
	_snapshot_dirty = true

func set_reel(value: bool) -> void:
	reel = value
	if value:
		boost = false
	_snapshot_dirty = true

func step(delta: float) -> void:
	if ended:
		return
	var dt := clampf(delta if is_finite(delta) else 0.0, 0.0, MAX_DELTA)
	if dt <= 0.0:
		return
	_snapshot_dirty = true
	var old_x := x
	var old_height := height
	_elapsed_step(dt)
	if ended:
		return
	event_timer = maxf(0.0, event_timer - dt)
	if _reset_timer > 0.0:
		_reset_timer = maxf(0.0, _reset_timer - dt)
		return
	var gust_force := _wind_at(elapsed)
	var gust := gust_force / GUST_STRENGTH
	var angle := clampf(aim * 0.72 + gust * 0.28, -1.0, 1.0)
	var lift := angle * (310.0 if not assisted else 270.0) + gust * 72.0
	var reel_sink := 34.0 if reel else 0.0
	vy += (lift - vy * 1.9 - reel_sink) * dt
	vy = clampf(vy, -205.0, 205.0)
	height = clampf(height - vy * dt, MIN_HEIGHT, MAX_HEIGHT)
	if height <= MIN_HEIGHT and vy > 0.0:
		height = MIN_HEIGHT
		vy = 0.0
	elif height >= MAX_HEIGHT and vy < 0.0:
		height = MAX_HEIGHT
		vy = 0.0
	var thrust := 30.0 if boost else 0.0
	var drag := 22.0 if reel else 0.0
	speed = clampf(118.0 + thrust - drag + absf(gust) * (4.0 if boost else 1.4), 78.0, 155.0)
	var attack := clampf(0.5 + angle * 0.33 + (0.16 if boost else 0.0) - (0.15 if reel else 0.0), 0.0, 1.0)
	tension = clampf(0.18 + attack * 0.45 + (0.2 if boost else 0.0) - (0.14 if reel else 0.0) + absf(gust) * 0.07, 0.05, 1.0)
	x += speed * dt
	if _update_tension_risk(dt):
		return
	_check_ring_crossing(old_x, x, old_height, height)
	if not ended and x >= RING_X[4] + 250.0:
		_finish(ring_index == 5)

func snapshot() -> Dictionary:
	if _snapshot_dirty:
		_update_snapshot_cache()
		_snapshot_dirty = false
	return _snapshot_cache

func _update_snapshot_cache() -> void:
	var forecast_time := elapsed + GUST_PREVIEW_SECONDS
	_snapshot_cache["assisted"] = assisted
	_snapshot_cache["x"] = x
	_snapshot_cache["progress"] = clampf(x / (RING_X[4] + 250.0), 0.0, 1.0)
	_snapshot_cache["height"] = height
	_snapshot_cache["vy"] = vy
	_snapshot_cache["aim"] = aim
	_snapshot_cache["speed"] = speed
	_snapshot_cache["tension"] = tension
	_snapshot_cache["tension_risk"] = clampf(tension_risk_seconds / TENSION_SNAP_SECONDS, 0.0, 1.0)
	_snapshot_cache["tension_warning"] = tension_warning
	_snapshot_cache["line_snaps"] = line_snaps
	_snapshot_cache["boost"] = boost
	_snapshot_cache["reel"] = reel
	_snapshot_cache["elapsed"] = elapsed
	_snapshot_cache["time_left"] = maxf(0.0, ROUND_SECONDS - elapsed)
	_snapshot_cache["actualwind"] = _wind_at(elapsed)
	_snapshot_cache["forecast"] = _wind_at(forecast_time)
	_snapshot_cache["forecast_seconds"] = GUST_PREVIEW_SECONDS
	_snapshot_cache["gust_seconds"] = _seconds_to_gust(elapsed)
	_snapshot_cache["nextRing"] = ring_index
	_snapshot_cache["ring_x"] = RING_X[ring_index] if ring_index < 5 else -1.0
	_snapshot_cache["ring_height"] = RING_HEIGHT[ring_index] if ring_index < 5 else -1.0
	_snapshot_cache["center_hits"] = center_hits
	_snapshot_cache["edge_hits"] = edge_hits
	_snapshot_cache["rescues_used"] = rescues_used
	_snapshot_cache["misses"] = misses
	_snapshot_cache["mistakes"] = mistakes
	_snapshot_cache["ended"] = ended
	_snapshot_cache["won"] = won
	_snapshot_cache["devil"] = devil_won
	_snapshot_cache["event"] = last_event if event_timer > 0.0 else ""
	_snapshot_cache["eventmarkers"] = _event_markers
	_snapshot_cache["reset_cooldown"] = _reset_timer

func _update_tension_risk(dt: float) -> bool:
	if tension >= TENSION_RISK_THRESHOLD:
		tension_warning = true
		tension_risk_seconds += dt
		if tension_risk_seconds >= TENSION_SNAP_SECONDS:
			line_snaps += 1
			mistakes += 1
			_event("line_snap", mini(ring_index, 4), "line_snap")
			if rescues_used >= MAX_RESCUES:
				_finish(false)
				return true
			_use_rescue()
			return true
	elif tension <= TENSION_CLEAR_THRESHOLD:
		tension_warning = false
		tension_risk_seconds = maxf(0.0, tension_risk_seconds - dt * 2.5)
	else:
		tension_risk_seconds = maxf(0.0, tension_risk_seconds - dt * 0.2)
	return false

func _use_rescue() -> void:
	rescues_used += 1
	x = maxf(0.0, RING_X[ring_index] - APPROACH_DISTANCE)
	vy = 0.0
	_reset_timer = RESET_COOLDOWN
	tension_risk_seconds = 0.0
	tension_warning = false

func _elapsed_step(dt: float) -> void:
	elapsed = minf(ROUND_SECONDS, elapsed + dt)
	if elapsed >= ROUND_SECONDS:
		_finish(false)

func _wind_at(at_time: float) -> float:
	var phase := fposmod(at_time, GUST_PERIOD)
	if phase <= GUST_DURATION:
		return sin(PI * phase / GUST_DURATION) * GUST_STRENGTH
	return 0.0

func _seconds_to_gust(at_time: float) -> float:
	var phase := fposmod(at_time, GUST_PERIOD)
	return fposmod(-phase, GUST_PERIOD)

func _check_ring_crossing(old_x: float, new_x: float, old_height: float, new_height: float) -> void:
	if ring_index >= 5 or old_x >= RING_X[ring_index] or new_x < RING_X[ring_index]:
		return
	var fraction: float = (RING_X[ring_index] - old_x) / maxf(0.0001, new_x - old_x)
	var crossing_height := lerpf(old_height, new_height, fraction)
	var offset := absf(crossing_height - RING_HEIGHT[ring_index])
	var allowable := EDGE_TOLERANCE + (12.0 if assisted else 0.0)
	if offset <= CENTER_TOLERANCE:
		center_hits += 1
		_event("center", ring_index, "center")
		_advance_ring()
	elif offset <= allowable:
		edge_hits += 1
		mistakes += 1
		_event("edge", ring_index, "edge")
		_advance_ring()
	else:
		misses += 1
		mistakes += 1
		_event("miss", ring_index, "miss")
		if rescues_used >= MAX_RESCUES:
			_finish(false)
			return
		_use_rescue()

func _advance_ring() -> void:
	ring_index += 1
	if ring_index >= 5:
		_finish(true)

func _event(kind: String, index: int, marker: String) -> void:
	last_event = kind
	event_timer = 1.1
	_event_markers.append({"ring": index, "kind": marker, "x": RING_X[index], "height": RING_HEIGHT[index]})

func _finish(all_rings: bool) -> void:
	ended = true
	won = all_rings and ring_index == 5
	devil_won = won and center_hits == 5 and edge_hits == 0 and rescues_used == 0 and not assisted
	_snapshot_dirty = true
