extends RefCounted
class_name Hero2DPose

const ACTIONS := ["idle", "start", "walk", "stop", "turn", "photo"]
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const DEFAULT_FRAME_COUNTS := {"idle": 4, "start": 4, "walk": 8, "stop": 4, "turn": 5, "photo": 8}
const DEFAULT_STRIDE_DISTANCE := 1.25
const START_DURATION := 0.20
const STOP_DURATION := 0.20
const TURN_DURATION := 0.24
const PHOTO_DURATION := 1.20
const IDLE_DURATION := 1.60
const MAX_ADVANCE_DELTA := 10.0
const MIN_STRIDE_DISTANCE := 0.000001
const MAX_STRIDE_DISTANCE := 1000000.0
const MAX_CONFIGURED_FRAME_COUNT := 4096
const MOVE_EPSILON_SQUARED := 0.000001
const DIRECTION_HYSTERESIS := deg_to_rad(5.0)

var action: String = "idle"
var direction: String = "front"
var _elapsed: float = 0.0
var _idle_elapsed: float = 0.0
var _gait_phase: float = 0.0
var _paused: bool = false
var _pending_turn: bool = false
var _pending_turn_direction: String = ""
var _turn_from_direction: String = ""
var _shutter_fired: bool = false
var _stride_distances: Dictionary = {}
var _frame_counts: Dictionary = {}

func _init() -> void:
	for heading in DIRECTIONS:
		_stride_distances[heading] = DEFAULT_STRIDE_DISTANCE
		_frame_counts[heading] = DEFAULT_FRAME_COUNTS.duplicate(true)

func set_paused(value: bool) -> void:
	_paused = value

func set_direction(value: String) -> bool:
	if _paused or not DIRECTIONS.has(value):
		return false
	direction = value
	return true

func set_stride_distance(heading: String, distance: float) -> bool:
	if _paused or not DIRECTIONS.has(heading) or not is_finite(distance) or distance < MIN_STRIDE_DISTANCE or distance > MAX_STRIDE_DISTANCE:
		return false
	_stride_distances[heading] = distance
	return true

func stride_distance(heading: String) -> float:
	return float(_stride_distances.get(heading, DEFAULT_STRIDE_DISTANCE))

func set_frame_count(state: String, heading: String, count: int) -> bool:
	if _paused or not ACTIONS.has(state) or not DIRECTIONS.has(heading) or count < 1 or count > MAX_CONFIGURED_FRAME_COUNT:
		return false
	_frame_counts[heading][state] = count
	return true

func frame_count(state: String, heading: String) -> int:
	if not ACTIONS.has(state) or not DIRECTIONS.has(heading):
		return 0
	return int(_frame_counts[heading][state])

func advance(dt: float, actual_displacement: Vector2, intent: Vector2, photo: bool = false) -> Dictionary:
	var events: Array[String] = []
	if _paused:
		return _state(events)
	var delta := clampf(dt, 0.0, MAX_ADVANCE_DELTA) if is_finite(dt) else 0.0
	var moving := _is_usable_vector(actual_displacement)
	var has_intent := _is_usable_vector(intent)
	var intent_heading := _direction_from_vector(intent) if has_intent else ""
	var actual_heading := _direction_from_vector(actual_displacement) if moving else ""

	if _pending_turn:
		if not has_intent or _direction_vector(direction).dot(intent.normalized()) >= -0.5:
			_pending_turn = false
			_pending_turn_direction = ""
		elif action == "stop":
			_pending_turn_direction = intent_heading
	if action == "walk" and has_intent and _direction_vector(direction).dot(intent.normalized()) < -0.5:
		_pending_turn = true
		_pending_turn_direction = intent_heading
		action = "stop"
		_elapsed = 0.0
	elif moving and action != "turn" and not _pending_turn:
		direction = actual_heading

	if action == "photo" and moving:
		action = "start"
		_elapsed = 0.0
		_pending_turn = false
		_pending_turn_direction = ""
		direction = actual_heading
		_shutter_fired = false
		events.append("photo_cancelled")
	elif photo and not moving and action != "photo":
		_pending_turn = false
		_pending_turn_direction = ""
		action = "photo"
		_elapsed = 0.0
		_shutter_fired = false

	if moving:
		_gait_phase = fposmod(_gait_phase + actual_displacement.length() / stride_distance(actual_heading), 1.0)
		if action == "idle" or (action == "stop" and not _pending_turn):
			action = "start"
			_elapsed = 0.0
			direction = actual_heading
	elif action == "walk" or (action == "start" and not has_intent):
		action = "stop"
		_elapsed = 0.0

	_advance_timers(delta, has_intent, moving, intent, events)

	return _state(events)

func _state(events: Array[String]) -> Dictionary:
	var visual_heading := _visual_direction()
	var count := frame_count(action, visual_heading)
	var phase := _action_phase()
	var frame := 0
	if action == "walk":
		frame = mini(int(floor(_gait_phase * count)), count - 1)
	elif action == "idle":
		frame = mini(int(floor(phase * count)), count - 1)
	else:
		frame = mini(int(floor(phase * count)), count - 1)
	return {
		"action": action,
		"direction": direction,
		"turn_from": _turn_from_direction if action == "turn" else "",
		"visual_direction": visual_heading,
		"frame": frame,
		"phase": phase,
		"gait_phase": _gait_phase,
		"contact_left": fposmod(_gait_phase, 1.0) < 0.5,
		"root_locked": _pending_turn or action == "turn",
		"events": events,
	}

func _advance_timers(delta: float, has_intent: bool, moving: bool, intent: Vector2, events: Array[String]) -> void:
	var remaining := delta
	var transition_count := 0
	while remaining > 0.0 and transition_count < 8:
		transition_count += 1
		if action == "idle":
			_idle_elapsed += remaining
			return
		if action == "walk":
			return
		if action == "start" and not moving:
			_elapsed = minf(_elapsed + remaining, START_DURATION)
			return
		var duration := _duration_for(action)
		var time_left := maxf(duration - _elapsed, 0.0)
		var step := minf(remaining, time_left)
		var old_elapsed := _elapsed
		_elapsed += step
		remaining -= step
		if action == "photo" and not _shutter_fired and old_elapsed < PHOTO_DURATION * 0.5 and _elapsed >= PHOTO_DURATION * 0.5:
			_shutter_fired = true
			events.append("shutter")
		if _elapsed < duration:
			return
		match action:
			"start":
				action = "walk"
				_elapsed = 0.0
			"stop":
				if _pending_turn and has_intent and _direction_vector(direction).dot(intent.normalized()) < -0.5:
					_turn_from_direction = direction
					direction = _pending_turn_direction
					_pending_turn = false
					_pending_turn_direction = ""
					action = "turn"
				else:
					_pending_turn = false
					_pending_turn_direction = ""
					action = "idle"
					_idle_elapsed = 0.0
				_elapsed = 0.0
			"turn":
				action = "start" if has_intent else "idle"
				_elapsed = 0.0
				_idle_elapsed = 0.0
			"photo":
				action = "idle"
				_elapsed = 0.0
				_idle_elapsed = 0.0
			"_":
				return

func _action_phase() -> float:
	if action == "walk":
		return _gait_phase
	if action == "idle":
		return fposmod(_idle_elapsed, IDLE_DURATION) / IDLE_DURATION
	var duration := START_DURATION
	match action:
		"stop": duration = STOP_DURATION
		"turn": duration = TURN_DURATION
		"photo": duration = PHOTO_DURATION
	return clampf(_elapsed / duration, 0.0, 1.0)

func _duration_for(state: String) -> float:
	match state:
		"start": return START_DURATION
		"stop": return STOP_DURATION
		"turn": return TURN_DURATION
		"photo": return PHOTO_DURATION
		_: return IDLE_DURATION

func _visual_direction() -> String:
	if action != "turn" or _turn_from_direction.is_empty():
		return direction
	var from_index := DIRECTIONS.find(_turn_from_direction)
	var to_index := DIRECTIONS.find(direction)
	var signed_steps := posmod(to_index - from_index + 4, 8) - 4
	var step_count := absi(signed_steps)
	if step_count == 0:
		return direction
	var completed_steps := mini(int(floor(_action_phase() * float(step_count) + 0.5)), step_count)
	var sign_step := 1 if signed_steps > 0 else -1
	return DIRECTIONS[posmod(from_index + sign_step * completed_steps, 8)]

func _is_usable_vector(value: Vector2) -> bool:
	if not is_finite(value.x) or not is_finite(value.y):
		return false
	var squared_length := value.length_squared()
	return is_finite(squared_length) and squared_length > MOVE_EPSILON_SQUARED

func _direction_from_vector(value: Vector2) -> String:
	var unit := value.normalized()
	if _direction_vector(direction).dot(unit) >= cos(PI / 8.0 + DIRECTION_HYSTERESIS):
		return direction
	var sector := int(round(atan2(unit.x, unit.y) / (PI / 4.0)))
	return DIRECTIONS[posmod(sector, 8)]

func _direction_vector(heading: String) -> Vector2:
	var index := DIRECTIONS.find(heading)
	if index < 0:
		return Vector2(0.0, 1.0)
	var angle := float(index) * PI / 4.0
	return Vector2(sin(angle), cos(angle))
