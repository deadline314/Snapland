extends RefCounted
class_name ShadowTheatreModel

## Deterministic point-light projection and scoring for the SG-24 paper theatre.
const WALL_Z := 2.2
const PUPPET_Z := 0.0
const LAMP_Y := 0.06
const ROUND_SECONDS := 60.0
const MAX_STEP := 0.1
const LAMP_X_MIN := -1.2
const LAMP_X_MAX := 1.2
const LAMP_Z_MIN := -3.0
const LAMP_Z_MAX := -1.4
const LAMP_SPEED := 1.25
const NORMAL_ERROR_LIMITS: Array[float] = [0.135, 0.112, 0.09]
const ASSIST_ERROR_LIMITS: Array[float] = [0.20, 0.178, 0.155]
const PERFECT_ERROR_LIMITS: Array[float] = [0.045, 0.032, 0.022]
const ASSIST_PERFECT_ERROR_LIMITS: Array[float] = [0.065, 0.052, 0.04]
const ROUND_SOLUTIONS: Array[Vector2] = [Vector2(-0.32, -2.72), Vector2(0.38, -2.30), Vector2(0.02, -1.72)]
const ROUND_START_OFFSETS: Array[Vector2] = [Vector2(-0.58, 0.48), Vector2(-0.62, -0.48), Vector2(0.56, 0.42)]
const PUPPET_COORDINATES: Array[Vector2] = [
	Vector2(-0.23, -0.50), Vector2(-0.40, -0.50), Vector2(-0.44, -0.42),
	Vector2(-0.35, -0.31), Vector2(-0.47, -0.18), Vector2(-0.45, -0.09),
	Vector2(-0.35, -0.06), Vector2(-0.27, -0.17), Vector2(-0.29, 0.02),
	Vector2(-0.40, 0.14), Vector2(-0.36, 0.29), Vector2(-0.23, 0.34),
	Vector2(-0.15, 0.45), Vector2(-0.05, 0.48), Vector2(0.00, 0.42),
	Vector2(0.05, 0.48), Vector2(0.15, 0.45), Vector2(0.23, 0.34),
	Vector2(0.36, 0.29), Vector2(0.40, 0.14), Vector2(0.29, 0.02),
	Vector2(0.27, -0.17), Vector2(0.35, -0.06), Vector2(0.45, -0.09),
	Vector2(0.47, -0.18), Vector2(0.35, -0.31), Vector2(0.44, -0.42),
	Vector2(0.40, -0.50), Vector2(0.23, -0.50), Vector2(0.13, -0.43),
	Vector2(0.06, -0.49), Vector2(-0.07, -0.49), Vector2(-0.14, -0.43)
]

var assisted := false
var time_of_day := "noon"
var elapsed := 0.0
var round := 0
var lamp_position := Vector2.ZERO # x and z in the theatre world
var score := 0
var misses := 0
var qualified_count := 0
var perfect_count := 0
var finished := false
var success := false
var devil := false
var timed_out := false
var _ledger: Array[Dictionary] = []
var _puppet_vertices := PackedVector2Array()
var _cast_vertices := PackedVector2Array()
var _target_vertices := PackedVector2Array()
var _snapshot: Dictionary = {}
var _snapshot_revision := 0

func _init() -> void:
	_puppet_vertices = PackedVector2Array(PUPPET_COORDINATES)
	_snapshot = {
		"revision": 0, "elapsed": 0.0, "time_left": ROUND_SECONDS, "round": 0, "rounds": 3,
		"lamp_position": Vector2.ZERO, "round_solution": Vector2.ZERO, "cast_vertices": _cast_vertices,
		"target_vertices": _target_vertices, "shape_error": 1.0, "qualified_count": 0,
		"perfect_count": 0, "misses": 0, "score": 0, "assisted": false,
		"time_of_day": "noon", "ledger": _ledger, "finished": false, "success": false,
		"devil": false, "timed_out": false
	}
	reset()

func reset(use_assist: bool = false, phase: String = "noon") -> void:
	assisted = use_assist
	time_of_day = _normalize_phase(phase)
	elapsed = 0.0
	round = 0
	score = 0
	misses = 0
	qualified_count = 0
	perfect_count = 0
	finished = false
	success = false
	devil = false
	timed_out = false
	_ledger.clear()
	for index in 3:
		_ledger.append({"round": index, "status": "waiting", "qualified": false, "perfect": false, "error": 1.0, "score": 0})
	_set_round_start()
	_snapshot_revision += 1
	_refresh_snapshot()

## Axes are clamped to -1..1. Positive depth moves the lamp toward the puppet.
func continuous_axis(horizontal: float, depth: float, delta: float) -> void:
	if finished or not is_finite(horizontal) or not is_finite(depth) or not is_finite(delta) or delta <= 0.0:
		return
	var dt := minf(delta, MAX_STEP)
	var axis := Vector2(clampf(horizontal, -1.0, 1.0), clampf(depth, -1.0, 1.0))
	if axis.length_squared() > 1.0:
		axis = axis.normalized()
	_set_lamp_position(lamp_position + axis * LAMP_SPEED * dt)

## Pointer/API target in theatre X/Z coordinates. Finite coordinates are clamped to the rail.
func setlamp_target(target: Vector2) -> void:
	if finished or not is_finite(target.x) or not is_finite(target.y):
		return
	_set_lamp_position(target)

func step(delta: float) -> void:
	if finished or not is_finite(delta) or delta <= 0.0:
		return
	elapsed += minf(delta, MAX_STEP)
	if elapsed >= ROUND_SECONDS:
		timed_out = true
		finished = true
		success = false
		devil = false
	_snapshot_revision += 1
	_refresh_snapshot()
	return
	_snapshot_revision += 1
	_refresh_snapshot()

## A shutter always resolves the current round. It cannot pass without real lamp alignment.
func capture() -> Dictionary:
	if finished:
		return {"accepted": false, "qualified": false, "perfect": false, "error": 1.0, "round": round}
	var error := _shape_error(_cast_vertices, _target_vertices)
	var normal_limit := ASSIST_ERROR_LIMITS[round] if assisted else NORMAL_ERROR_LIMITS[round]
	var perfect_limit := ASSIST_PERFECT_ERROR_LIMITS[round] if assisted else PERFECT_ERROR_LIMITS[round]
	var qualified := is_finite(error) and error <= normal_limit
	var perfect := qualified and error <= perfect_limit
	var points := maxi(0, 500 - int(roundi(error * 1800.0))) if qualified else 0
	var row: Dictionary = _ledger[round]
	row["status"] = "perfect" if perfect else ("qualified" if qualified else "miss")
	row["qualified"] = qualified
	row["perfect"] = perfect
	row["error"] = error if is_finite(error) else 1.0
	row["score"] = points
	if qualified:
		qualified_count += 1
		score += points
	else:
		misses += 1
	if perfect:
		perfect_count += 1
	var resolved_round := round
	if round >= 2:
		finished = true
		success = qualified_count >= 2
		devil = success and not assisted and perfect_count == 3 and misses == 0
	else:
		round += 1
		_set_round_start()
	_snapshot_revision += 1
	_refresh_snapshot()
	return {"accepted": true, "qualified": qualified, "perfect": perfect, "error": error, "score": points, "round": resolved_round}

## Point-to-plane projection of every supplied puppet vertex. Returns a new fixed-size value array.
func projection_for(source: Vector2, vertices: PackedVector2Array) -> PackedVector2Array:
	var output := PackedVector2Array()
	output.resize(vertices.size())
	if not is_finite(source.x) or not is_finite(source.y):
		for i in vertices.size():
			output[i] = Vector2(NAN, NAN)
		return output
	for i in vertices.size():
		var vertex := vertices[i]
		var denominator := PUPPET_Z - source.y
		if not is_finite(vertex.x) or not is_finite(vertex.y) or absf(denominator) < 0.0001:
			output[i] = Vector2(NAN, NAN)
			continue
		var t := (WALL_Z - source.y) / denominator
		var lamp_xy := Vector2(source.x, LAMP_Y)
		output[i] = lamp_xy + (vertex - lamp_xy) * t
	return output

func round_solution(round_index: int) -> Vector2:
	return ROUND_SOLUTIONS[clampi(round_index, 0, 2)]

func puppet_vertices() -> PackedVector2Array:
	return _puppet_vertices

func snapshot() -> Dictionary:
	_refresh_snapshot()
	return _snapshot

func _set_lamp_position(target: Vector2) -> void:
	var next := Vector2(clampf(target.x, LAMP_X_MIN, LAMP_X_MAX), clampf(target.y, LAMP_Z_MIN, LAMP_Z_MAX))
	if not next.is_equal_approx(lamp_position):
		lamp_position = next
		_rebuild_projection()
		_snapshot_revision += 1
		_refresh_snapshot()

func _set_round_start() -> void:
	var solution := round_solution(round)
	var offset := ROUND_START_OFFSETS[round]
	lamp_position = Vector2(clampf(solution.x + offset.x, LAMP_X_MIN, LAMP_X_MAX), clampf(solution.y + offset.y, LAMP_Z_MIN, LAMP_Z_MAX))
	_rebuild_projection()

func _rebuild_projection() -> void:
	_cast_vertices = projection_for(lamp_position, _puppet_vertices)
	_target_vertices = projection_for(round_solution(round), _puppet_vertices)
	_snapshot["cast_vertices"] = _cast_vertices
	_snapshot["target_vertices"] = _target_vertices

func _shape_error(cast: PackedVector2Array, target: PackedVector2Array) -> float:
	if cast.size() != target.size() or cast.is_empty():
		return 1.0
	var sum := 0.0
	for i in cast.size():
		if not is_finite(cast[i].x) or not is_finite(cast[i].y) or not is_finite(target[i].x) or not is_finite(target[i].y):
			return 1.0
		sum += cast[i].distance_squared_to(target[i])
	return sqrt(sum / float(cast.size()))

func _refresh_snapshot() -> void:
	if _snapshot.is_empty():
		return
	_snapshot["revision"] = _snapshot_revision
	_snapshot["elapsed"] = elapsed
	_snapshot["time_left"] = maxf(0.0, ROUND_SECONDS - elapsed)
	_snapshot["round"] = round
	_snapshot["rounds"] = 3
	_snapshot["lamp_position"] = lamp_position
	_snapshot["round_solution"] = round_solution(round)
	_snapshot["cast_vertices"] = _cast_vertices
	_snapshot["target_vertices"] = _target_vertices
	_snapshot["shape_error"] = _shape_error(_cast_vertices, _target_vertices)
	_snapshot["normal_error_limit"] = ASSIST_ERROR_LIMITS[round] if assisted else NORMAL_ERROR_LIMITS[round]
	_snapshot["perfect_error_limit"] = ASSIST_PERFECT_ERROR_LIMITS[round] if assisted else PERFECT_ERROR_LIMITS[round]
	_snapshot["difficulty"] = ["easy", "steady", "precise"][round]
	_snapshot["qualified_count"] = qualified_count
	_snapshot["perfect_count"] = perfect_count
	_snapshot["misses"] = misses
	_snapshot["score"] = score
	_snapshot["assisted"] = assisted
	_snapshot["time_of_day"] = time_of_day
	_snapshot["ledger"] = _ledger
	_snapshot["finished"] = finished
	_snapshot["success"] = success
	_snapshot["devil"] = devil
	_snapshot["timed_out"] = timed_out

func _normalize_phase(value: String) -> String:
	return value if value in ["dawn", "noon", "dusk", "night"] else "noon"
