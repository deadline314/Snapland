extends RefCounted
## Bounded secondary motion. Inputs and time use the same simulated clock as the pose.

var angles := Vector2.ZERO
var tip_angles := Vector2.ZERO
var angular_velocity := Vector2.ZERO
var tip_velocity := Vector2.ZERO
var enabled := true
var direction := ""
var hat_on := false
var _previous_velocity := Vector2.ZERO

func snapshot() -> Dictionary:
	return {"angles": angles, "tip_angles": tip_angles, "velocity": angular_velocity, "tip_velocity": tip_velocity, "previous_velocity": _previous_velocity, "direction": direction, "hat_on": hat_on, "enabled": enabled}

func reset(view: String = "front", hat: bool = false, actual_velocity: Vector2 = Vector2.ZERO) -> void:
	angles = Vector2.ZERO
	tip_angles = Vector2.ZERO
	angular_velocity = Vector2.ZERO
	tip_velocity = Vector2.ZERO
	_previous_velocity = actual_velocity
	direction = view
	hat_on = hat

func set_enabled(value: bool) -> void:
	enabled = value
	reset(direction, hat_on, _previous_velocity)

func advance(dt: float, actual_velocity: Vector2, view: String, hat: bool, paused := false) -> Dictionary:
	if paused: return snapshot()
	if not is_finite(dt) or not actual_velocity.is_finite():
		reset(view, hat)
		return snapshot()
	if direction != view or hat_on != hat or dt > 0.25:
		reset(view, hat, actual_velocity)
		return snapshot()
	if dt <= 0.0: return snapshot()
	if not enabled:
		reset(view, hat, actual_velocity)
		return snapshot()
	var acceleration := (actual_velocity - _previous_velocity) / dt
	var count := maxi(1, ceili(dt * 240.0 - 0.00001))
	var step := dt / float(count)
	for i in range(count):
		var velocity := _previous_velocity.lerp(actual_velocity, (float(i) + 0.5) / float(count))
		var target := Vector2(-velocity.x * 0.00042 - acceleration.x * 0.000075, velocity.y * 0.00016 + acceleration.y * 0.000035)
		var limit := deg_to_rad(3.0 if hat_on else 6.0)
		target = _limit_sum(target, limit)
		var x := _spring(angles.x, angular_velocity.x, target.x, step, 13.0, 0.61)
		var y := _spring(angles.y, angular_velocity.y, target.y, step, 13.0, 0.61)
		angles = _limit_sum(Vector2(x.x, y.x), limit)
		angular_velocity = Vector2(x.y, y.y)
		var tip_target := target * 0.55 + angles * 0.15
		x = _spring(tip_angles.x, tip_velocity.x, tip_target.x, step, 16.0, 0.55)
		y = _spring(tip_angles.y, tip_velocity.y, tip_target.y, step, 16.0, 0.55)
		tip_angles = _limit_sum(Vector2(x.x, y.x), limit * 0.7)
		tip_velocity = Vector2(x.y, y.y)
	_previous_velocity = actual_velocity
	return snapshot()

func _limit_sum(value: Vector2, limit: float) -> Vector2:
	var amount := absf(value.x) + absf(value.y)
	return value * minf(1.0, limit / maxf(amount, 0.000001))

func _spring(position: float, velocity: float, target: float, dt: float, omega: float, damping: float) -> Vector2:
	var decay := damping * omega
	var frequency := omega * sqrt(1.0 - damping * damping)
	var relative := position - target
	var cosine := cos(frequency * dt)
	var sine := sin(frequency * dt)
	var envelope := exp(-decay * dt)
	return Vector2(target + envelope * (relative * cosine + (velocity + decay * relative) / frequency * sine), envelope * (velocity * cosine - (decay * velocity + omega * omega * relative) / frequency * sine))
