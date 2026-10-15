extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	if not FileAccess.file_exists("res://game/world/hero_2d_hair_spring.gd"):
		printerr("FAIL missing 2D hair spring: hair cannot yet lag, return, freeze or reset")
		quit(1)
		return
	var script = load("res://game/world/hero_2d_hair_spring.gd")
	var spring = script.new()
	spring.advance(0.0, Vector2.ZERO, "front", false)
	for i in range(12): spring.advance(1.0/60.0, Vector2(90.0, 0.0), "front", false)
	check(spring.angles.length() > 0.004, "moving hair tips must show a measurable lag")
	var peak: float = spring.angles.x
	var crossed := false
	var previous: float = peak
	for i in range(240):
		spring.advance(1.0/120.0, Vector2.ZERO, "front", false)
		if previous * spring.angles.x < 0.0 and absf(previous) > 0.00001: crossed = true
		previous = spring.angles.x
	check(crossed, "release must visibly rebound across rest before settling")
	check(spring.angles.length() < 0.0002 and spring.tip_angles.length() < 0.0002, "stopped hair must converge to rest")
	for i in range(8): spring.advance(1.0/60.0, Vector2(90.0, 0.0), "front", false)
	var before: Dictionary = spring.snapshot()
	for i in range(60): spring.advance(1.0/30.0, Vector2.ZERO, "front", false, true)
	check(spring.snapshot() == before, "pause must freeze angles, velocities and movement history")
	spring.advance(0.0, Vector2(90.0, 0.0), "front", false)
	check(spring.snapshot() == before, "zero-time resume must not jump")
	spring.advance(1.0/60.0, Vector2.LEFT*90.0, "left", false)
	check(spring.angles == Vector2.ZERO and spring.tip_angles == Vector2.ZERO, "direction changes clear old-view momentum")
	spring.advance(1.0/60.0, Vector2.RIGHT*90.0, "left", true)
	check(spring.angles == Vector2.ZERO, "hat changes clear old hair momentum")
	for i in range(180):
		spring.advance(1.0/120.0, Vector2.RIGHT*90.0 if i%10<5 else Vector2.LEFT*90.0, "left", true)
		check(absf(spring.angles.x)+absf(spring.angles.y) <= deg_to_rad(3.01), "hat restricts every base-bone swing")
	spring.set_enabled(false)
	check(spring.angles == Vector2.ZERO and spring.tip_angles == Vector2.ZERO, "turning dynamic hair off restores original rest")
	spring.advance(0.1, Vector2.RIGHT*90.0, "left", true)
	check(spring.angles == Vector2.ZERO, "disabled dynamics stay at rest")
	var normal = _simulate(script, 1.0/30.0)
	var quarter = _simulate(script, 1.0/120.0)
	check(normal.angles.distance_to(quarter.angles) < 0.001, "normal and quarter time partitions must agree")
	check(normal.tip_angles.distance_to(quarter.tip_angles) < 0.001, "tip timing must agree at normal and quarter rates")
	if failures.is_empty(): print("PASS 2D hair spring: lag, rebound, convergence, pause, view/hat reset, disable and time partition")
	else: printerr("FAIL " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)

func _simulate(script: Script, step: float):
	var value = script.new()
	value.advance(0.0, Vector2.ZERO, "right", false)
	for i in range(roundi(1.0/step)):
		var t: float = (i+1)*step
		value.advance(step, Vector2(minf(t*400.0,90.0), 0.0) if t < 0.5 else Vector2.ZERO, "right", false)
	return value
