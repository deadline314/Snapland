extends RefCounted
## Small grounded patrol intent. Owns XZ movement only; the existing billboard
## owner places visible feet. Authored poses consume the actual distance phase.

const HALF_WIDTH := 0.30
const SPEED := 0.36
const STRIDE := 0.36
const REST_SECONDS := 2.6
const MAX_STEP_SECONDS := 0.1
const MAX_GROUND_CHANGE := 0.12
const DEFAULT_PROFILE := {"minimum_offset":-HALF_WIDTH, "maximum_offset":HALF_WIDTH, "speed":SPEED, "stride":STRIDE, "rest_seconds":REST_SECONDS, "initial_rest":1.2}
const PROFILE_LIMITS := {"minimum_offset":Vector2(-2,0), "maximum_offset":Vector2(0,2), "speed":Vector2(0.01,3), "stride":Vector2(0.05,4), "rest_seconds":Vector2(0.1,30), "initial_rest":Vector2(0,30)}

var _anchor: WeakRef
var _ground: Callable
var _obstacle_test: Callable
var _origin := Vector3.ZERO
var _last_position := Vector3.ZERO
var _sign := 1.0
var _rest := 1.2
var phase := 0.0
var blocked_reason := ""
var _profile: Dictionary = DEFAULT_PROFILE.duplicate()

func configure(anchor: Node3D, ground: Callable, obstacle_test: Callable = Callable(), profile: Dictionary = {}) -> bool:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree() or not ground.is_valid(): return false
	var validated := _validated_profile(profile)
	if validated.is_empty(): return false
	var changed_actor: bool = _anchor == null or _anchor.get_ref() != anchor
	_profile = validated
	_anchor = weakref(anchor)
	_ground = ground
	_obstacle_test = obstacle_test
	if changed_actor: reset()
	return true

func reset() -> void:
	var anchor := _anchor.get_ref() as Node3D if _anchor != null else null
	if not is_instance_valid(anchor) or not anchor.is_inside_tree(): return
	_origin = anchor.global_position
	_last_position = _origin
	_sign = 1.0
	_rest = float(_profile.initial_rest)
	phase = 0.0
	blocked_reason = ""

func advance(delta: float) -> Dictionary:
	var result := {"moving": false, "distance": 0.0, "phase": phase, "direction": "right" if _sign > 0.0 else "left"}
	var anchor := _anchor.get_ref() as Node3D if _anchor != null else null
	if not is_instance_valid(anchor) or not anchor.is_inside_tree() or not is_finite(delta) or delta <= 0.0: return result
	var current := anchor.global_position
	if not current.is_finite(): return result
	if current.distance_to(_last_position) > 0.01:
		# A scene/system teleport is not a walking step and must not advance feet.
		reset()
		return result
	var step := minf(delta, MAX_STEP_SECONDS)
	if _rest > 0.0:
		_rest = maxf(0.0, _rest - step)
		return result
	var destination := _origin + Vector3(float(_profile.maximum_offset if _sign > 0.0 else _profile.minimum_offset), 0.0, 0.0)
	var candidate := current.move_toward(destination, float(_profile.speed) * step)
	var current_ground := _height(current)
	var next_ground := _height(candidate)
	if not is_finite(current_ground) or not is_finite(next_ground) or absf(current_ground - next_ground) > MAX_GROUND_CHANGE:
		blocked_reason = "ground"
	elif not _path_clear(anchor, current, candidate, current_ground):
		blocked_reason = "obstacle"
	else:
		blocked_reason = ""
	if not blocked_reason.is_empty():
		_sign *= -1.0
		_rest = 0.6
		return result
	anchor.global_position = candidate
	var distance := Vector2(candidate.x-current.x, candidate.z-current.z).length()
	_last_position = anchor.global_position
	phase = fposmod(phase + distance / float(_profile.stride), 1.0)
	result.moving = distance > 0.000001
	result.distance = distance
	result.phase = phase
	if candidate.distance_to(destination) < 0.000001:
		_sign *= -1.0
		_rest = float(_profile.rest_seconds)
	return result

static func _validated_profile(profile: Dictionary) -> Dictionary:
	var result := DEFAULT_PROFILE.duplicate()
	for key in profile:
		if not PROFILE_LIMITS.has(key): return {}
		var value: Variant = profile[key]
		var limits: Vector2 = PROFILE_LIMITS[key]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < limits.x or float(value) > limits.y: return {}
		result[key] = float(value)
	if float(result.minimum_offset) >= float(result.maximum_offset): return {}
	return result

func _height(position: Vector3) -> float:
	if not _ground.is_valid(): return NAN
	var value: Variant = _ground.call(Vector2(position.x, position.z))
	return float(value) if value is int or value is float else NAN

func _path_clear(anchor: Node3D, from: Vector3, to: Vector3, ground: float) -> bool:
	if _obstacle_test.is_valid(): return bool(_obstacle_test.call(from, to))
	var world := anchor.get_world_3d()
	if world == null: return false
	# A narrow three-ray footprint prevents walking through the player or walls.
	# No collision body, hidden gait rig, or unbounded navigation cache is added.
	for offset in [-0.12, 0.0, 0.12]:
		var start := Vector3(from.x, ground + 0.35, from.z + offset)
		var finish := Vector3(to.x, ground + 0.35, to.z + offset)
		var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
		query.hit_from_inside = true
		if not world.direct_space_state.intersect_ray(query).is_empty(): return false
	return true
