extends RefCounted
class_name TideSandbarModel

## Planar coordinates map to world X/Z. Heights share one unit: anchors stay dry,
## each sand corridor floods while the tide is above its fixed elevation.
const ROUND_SECONDS := 150.0
const MAX_FRAME_DELTA := 0.25
const MAX_SUBSTEP := 0.02
const WALK_SPEED := 1.6
const RUN_SPEED := 2.6
const ANCHOR_RADIUS := 1.0
const MARK_RADIUS := 0.9
const CORRIDOR_HALF_WIDTH := 0.6
const ANCHOR_HEIGHT := 1.2
const TIDE_MEAN := 0.5
const TIDE_AMPLITUDE := 0.4
const WARNING_SECONDS := 4.0
const ROPE_THROW_SECONDS := 0.6
const ASSIST_ROPE_THROW_SECONDS := 0.25
const ROPE_PULL_SPEED := 3.0
const REEF_POINTS := 100
const RETURN_POINTS := 100
const BOUNDS := Rect2(-11.0, -7.0, 19.0, 14.0)
const ANCHORS := [
	{"id": "camp", "name": "營地", "kind": "camp", "position": Vector2(-9.0, 0.0)},
	{"id": "dune", "name": "中繼沙丘", "kind": "relay", "position": Vector2(-3.0, 0.0)},
	{"id": "highland", "name": "高地", "kind": "highland", "position": Vector2(-6.0, 4.0)},
	{"id": "reef_north", "name": "北礁", "kind": "reef", "position": Vector2(2.0, -3.5)},
	{"id": "reef_far", "name": "遠礁", "kind": "reef", "position": Vector2(6.0, 0.0)},
	{"id": "reef_south", "name": "南礁", "kind": "reef", "position": Vector2(2.0, 3.5)},
]
## Elevations: the far shallow opens only near low tide, the camp shortcut floods
## at mid tide, and the highland ridge stays above the highest tide.
const CORRIDORS := [
	{"id": "shortcut", "name": "低窪捷徑", "a": "camp", "b": "dune", "elevation": 0.45, "gauge": "低窪捷徑"},
	{"id": "ridge_camp", "name": "高地沙脊", "a": "camp", "b": "highland", "elevation": 0.95, "gauge": "高地沙脊"},
	{"id": "ridge_dune", "name": "高地沙脊", "a": "highland", "b": "dune", "elevation": 0.95, "gauge": "高地沙脊"},
	{"id": "north_bar", "name": "北礁沙路", "a": "dune", "b": "reef_north", "elevation": 0.6, "gauge": "南北沙路"},
	{"id": "south_bar", "name": "南礁沙路", "a": "dune", "b": "reef_south", "elevation": 0.6, "gauge": "南北沙路"},
	{"id": "far_shallow", "name": "遠礁淺灘", "a": "dune", "b": "reef_far", "elevation": 0.19, "gauge": "遠礁淺灘"},
	{"id": "north_link", "name": "北遠礁脊", "a": "reef_north", "b": "reef_far", "elevation": 0.5, "gauge": "遠礁兩脊"},
	{"id": "south_link", "name": "南遠礁脊", "a": "reef_south", "b": "reef_far", "elevation": 0.5, "gauge": "遠礁兩脊"},
]
## Retries alternate the tide period and which side holds the safe highland.
const VARIANTS := [
	{"period": 60.0, "highland": Vector2(-6.0, 4.0)},
	{"period": 52.0, "highland": Vector2(-6.0, -4.0)},
]

var _assisted := false
var _variant := 0
var _period := 60.0
var _anchors: Dictionary = {}
var _elapsed := 0.0
var _tide_clock := 0.0
var _tide_paused := false
var _position := Vector2.ZERO
var _facing := Vector2.DOWN
var _move := Vector2.ZERO
var _running := false
var _moving := false
var _markers: Array[Dictionary] = []
var _marked: Dictionary = {}
var _prepared := false
var _first_reef_at := -1.0
var _falls := 0
var _rescue: Dictionary = {}
var _ended := false
var _success := false
var _finish_cycle := -1
var _feedback := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, VARIANTS.size())
	_period = float(VARIANTS[_variant].period)
	_anchors.clear()
	for anchor: Dictionary in ANCHORS:
		var copy := anchor.duplicate(true)
		if copy.id == "highland":
			copy.position = VARIANTS[_variant].highland
		_anchors[copy.id] = copy
	_elapsed = 0.0
	_tide_clock = 0.0
	_tide_paused = false
	_position = _anchors.camp.position
	_facing = Vector2.RIGHT
	_move = Vector2.ZERO
	_running = false
	_moving = false
	_markers.clear()
	_marked = {"camp": true}
	_prepared = false
	_first_reef_at = -1.0
	_falls = 0
	_rescue.clear()
	_ended = false
	_success = false
	_finish_cycle = -1
	_feedback = "退潮中：沿沙路走到沙丘，按空白放路標"

func set_move(direction: Vector2) -> void:
	if _ended or not direction.is_finite():
		return
	_move = direction.limit_length(1.0)

func set_running(value: bool) -> void:
	if not _ended:
		_running = value

func clear_input() -> void:
	_move = Vector2.ZERO
	_running = false
	_moving = false

func toggle_tide_pause() -> void:
	if _ended:
		return
	if not _assisted:
		_feedback = "水位暫停只在輔助模式提供"
		return
	_tide_paused = not _tide_paused
	_feedback = "水位暫停：潮水不再升降" if _tide_paused else "水位恢復流動"

func interact() -> void:
	if _ended:
		return
	if not _rescue.is_empty():
		_feedback = "正在被拉回，稍等再放路標"
		return
	var anchor := _anchor_at(_position, MARK_RADIUS)
	if anchor.is_empty():
		_feedback = "走到沙丘或礁石中央才能放路標"
		return
	if _marked.has(anchor.id):
		_feedback = "%s已有路標" % anchor.name
		return
	if not _has_marked_neighbor(anchor.id):
		_feedback = "路標要從營地一路相連：先標相鄰的沙丘"
		return
	if anchor.kind == "reef" and _first_reef_at < 0.0:
		_first_reef_at = _elapsed
		_prepared = _marked.has("highland") and _marked.has("dune")
	_marked[anchor.id] = true
	_markers.append({"anchor_id": anchor.id, "elapsed": _elapsed, "tide_clock": _tide_clock, "tide": tide_level()})
	var reefs := _reef_count()
	_feedback = "%s插上路標（礁 %d / 3）" % [anchor.name, reefs] if anchor.kind == "reef" else "%s插上路標" % anchor.name
	if reefs == 3:
		_feedback += "，回到營地完成"

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	var start := _position
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, minf(MAX_SUBSTEP, ROUND_SECONDS - _elapsed))
		remaining -= dt
		_step_slice(dt)
	_moving = _rescue.is_empty() and _position.distance_squared_to(start) > 0.0000001
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	if not _tide_paused:
		_tide_clock += dt
	if not _rescue.is_empty():
		_step_rescue(dt)
	elif _move != Vector2.ZERO:
		_walk(_move * (RUN_SPEED if _running else WALK_SPEED) * dt)
	if _rescue.is_empty() and not is_dry(_position):
		_start_rescue()
	if _rescue.is_empty() and _reef_count() == 3 and _position.distance_to(_anchors.camp.position) <= ANCHOR_RADIUS:
		_ended = true
		_success = true
		_finish_cycle = tide_cycle()
		_feedback = "三礁相連並平安回到營地"
		clear_input()
		return
	if _elapsed >= ROUND_SECONDS:
		_ended = true
		_feedback = "時間到：已連接 %d / 3 座礁" % _reef_count()
		clear_input()

func _walk(offset: Vector2) -> void:
	_facing = offset.normalized()
	# Slide along the sand edge on whichever axis still has footing.
	for candidate in [_position + offset, _position + Vector2(offset.x, 0.0), _position + Vector2(0.0, offset.y)]:
		if candidate != _position and on_sand(candidate):
			_position = candidate
			return
	_feedback = "前方是深水，沿沙路或礁石走"

func _start_rescue() -> void:
	var target := _rescue_anchor()
	_falls += 1
	_rescue = {"anchor_id": target.id, "origin": _position, "timer": 0.0,
		"throw": ASSIST_ROPE_THROW_SECONDS if _assisted else ROPE_THROW_SECONDS}
	_move = Vector2.ZERO
	_feedback = "落水！夥伴從%s拋繩拉回" % target.name

func _step_rescue(dt: float) -> void:
	_rescue.timer += dt
	if _rescue.timer < _rescue.throw:
		return
	var target: Vector2 = _anchors[_rescue.anchor_id].position
	_position = _position.move_toward(target, ROPE_PULL_SPEED * dt)
	if _position.distance_to(target) <= 0.001:
		_feedback = "已拉回%s，看水位再出發" % _anchors[_rescue.anchor_id].name
		_rescue.clear()

func _rescue_anchor() -> Dictionary:
	# The helper only anchors rope at marked ground; assistance keeps every
	# high point as a permanent safe crossing.
	var best: Dictionary = _anchors.camp
	for anchor: Dictionary in _anchors.values():
		if not _assisted and not _marked.has(anchor.id):
			continue
		if _position.distance_squared_to(anchor.position) < _position.distance_squared_to(best.position):
			best = anchor
	return best

func _anchor_at(point: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	for anchor: Dictionary in _anchors.values():
		var distance := point.distance_to(anchor.position)
		if distance <= radius and (best.is_empty() or distance < point.distance_to(best.position)):
			best = anchor
	return best

func _has_marked_neighbor(anchor_id: String) -> bool:
	for corridor: Dictionary in CORRIDORS:
		if corridor.a == anchor_id and _marked.has(corridor.b) or corridor.b == anchor_id and _marked.has(corridor.a):
			return true
	return false

func _reef_count() -> int:
	var count := 0
	for anchor: Dictionary in _anchors.values():
		if anchor.kind == "reef" and _marked.has(anchor.id):
			count += 1
	return count

func _segment_distance(point: Vector2, corridor: Dictionary) -> float:
	var a: Vector2 = _anchors[corridor.a].position
	var b: Vector2 = _anchors[corridor.b].position
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))

func on_sand(point: Vector2) -> bool:
	if not BOUNDS.has_point(point):
		return false
	if not _anchor_at(point, ANCHOR_RADIUS).is_empty():
		return true
	for corridor: Dictionary in CORRIDORS:
		if _segment_distance(point, corridor) <= CORRIDOR_HALF_WIDTH:
			return true
	return false

func is_dry(point: Vector2) -> bool:
	if not _anchor_at(point, ANCHOR_RADIUS).is_empty():
		return true
	var level := tide_level()
	for corridor: Dictionary in CORRIDORS:
		if corridor.elevation > level and _segment_distance(point, corridor) <= CORRIDOR_HALF_WIDTH:
			return true
	return false

func tide_level(clock: float = NAN) -> float:
	var at := _tide_clock if is_nan(clock) else clock
	return TIDE_MEAN - TIDE_AMPLITUDE * cos(TAU * at / _period)

func tide_cycle() -> int:
	return floori(_tide_clock / _period)

## Seconds until the tide next reaches `elevation` rising (flood) or falling (dry);
## -1 when it never crosses or the tide is paused.
func _crossing_in(elevation: float, rising: bool) -> float:
	var c := (TIDE_MEAN - elevation) / TIDE_AMPLITUDE
	if _tide_paused or absf(c) >= 1.0:
		return -1.0
	var omega := TAU / _period
	var target := acos(c) if rising else TAU - acos(c)
	return fposmod(target - fposmod(omega * _tide_clock, TAU), TAU) / omega

func _corridor_states() -> Array:
	var level := tide_level()
	var rows: Array = []
	for corridor: Dictionary in CORRIDORS:
		var row := corridor.duplicate(true)
		row.from = _anchors[corridor.a].position
		row.to = _anchors[corridor.b].position
		row.dry = corridor.elevation > level
		row.flood_in = _crossing_in(corridor.elevation, true) if row.dry else -1.0
		row.dry_in = -1.0 if row.dry else _crossing_in(corridor.elevation, false)
		row.warning = row.dry and row.flood_in >= 0.0 and row.flood_in <= WARNING_SECONDS
		rows.append(row)
	return rows

func _next_safe(corridors: Array) -> Dictionary:
	var here := _anchor_at(_position, ANCHOR_RADIUS)
	if not here.is_empty():
		return {"id": here.id, "name": here.name, "seconds": 0.0, "safe": true}
	var best: Dictionary = {}
	for row: Dictionary in corridors:
		if _segment_distance(_position, row) > CORRIDOR_HALF_WIDTH:
			continue
		for end in [row.a, row.b]:
			var seconds: float = _position.distance_to(_anchors[end].position) / RUN_SPEED
			var safe: bool = row.dry and (row.flood_in < 0.0 or row.flood_in > seconds)
			if best.is_empty() or (safe and not best.safe) or (safe == best.safe and seconds < best.seconds):
				best = {"id": end, "name": _anchors[end].name, "seconds": seconds, "safe": safe}
	if best.is_empty():
		var anchor := _rescue_anchor()
		best = {"id": anchor.id, "name": anchor.name, "seconds": _position.distance_to(anchor.position) / RUN_SPEED, "safe": false}
	return best

func snapshot() -> Dictionary:
	var corridors := _corridor_states()
	var level := tide_level()
	var rising := fposmod(_tide_clock, _period) < _period * 0.5
	var low_in := 0.0 if _tide_paused else fposmod(-_tide_clock, _period)
	var reefs := _reef_count()
	var helper: Dictionary = _rescue_anchor() if _rescue.is_empty() else _anchors[_rescue.anchor_id]
	var rope: Dictionary = {}
	if not _rescue.is_empty():
		rope = {"anchor_id": _rescue.anchor_id, "from": helper.position, "to": _position,
			"progress": clampf(_rescue.timer / _rescue.throw, 0.0, 1.0), "pulling": _rescue.timer >= _rescue.throw}
	var devil := _success and _prepared and _finish_cycle == 0
	return {
		"assisted": _assisted, "variant": _variant, "tide_period": _period, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success,
		"devil": devil, "devil_success": devil, "ordinary_eligible": _ended,
		"score": reefs * REEF_POINTS + (RETURN_POINTS if _success else 0), "mistakes": _falls, "falls": _falls,
		"position": _position, "facing": _facing, "moving": _moving, "running": _running and _moving,
		"anchors": _anchors.values().duplicate(true), "corridors": corridors, "bounds": BOUNDS,
		"markers": _markers.duplicate(true), "marked": _marked.keys(), "reefs_marked": reefs,
		"return_prepared": _prepared, "first_reef_at": _first_reef_at,
		"tide": level, "tide_clock": _tide_clock, "tide_cycle": tide_cycle(), "tide_rising": rising,
		"tide_paused": _tide_paused, "next_low_in": low_in, "next_safe": _next_safe(corridors),
		"standing_dry": is_dry(_position), "helper_anchor": helper.id, "helper_position": helper.position,
		"rescuing": not _rescue.is_empty(), "rope": rope, "feedback": _feedback, "last_event": _feedback,
	}
