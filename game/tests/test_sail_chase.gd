extends SceneTree

const Model = preload("res://game/minigames/sail_chase_model.gd")
const Route = preload("res://game/tests/sail_chase_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run(commands, seconds: float, delta: float = 1.0 / 60.0) -> void:
	for i in roundi(seconds / delta):
		commands.step(delta)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(not state.ended and not state.ordinary_eligible and state.catches == 0 and state.speed == 0.0, "chase starts becalmed behind the lightship")
	for field in ["wind", "point_of_sail", "efficiency", "optimal_trim", "flag_wind", "helper_trim", "lightship", "region", "gybes"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")

	# Sail physics: trim and point of sail set speed; head to wind stops.
	var probe = Model.new()
	var wind := deg_to_rad(90.0)
	var beam := 0.0
	expect(probe.target_speed(Vector2(-12, 0), beam, probe.optimal_trim(probe.point_of_sail(beam, wind)), wind) > probe.target_speed(Vector2(-12, 0), beam, deg_to_rad(10.0), wind) + 0.5, "the right trim is faster than an over-sheeted sail")
	expect(probe.target_speed(Vector2(-12, 0), -PI / 2.0, deg_to_rad(20.0), wind) == 0.0, "heading straight into the wind makes no way")
	expect(probe.target_speed(Vector2(-12, 0), beam, deg_to_rad(45.0), wind) > probe.target_speed(Vector2(0, 0), beam, deg_to_rad(45.0), wind), "the outer lane has more wind than the inner lane")
	var trimmed = Route.ModelCommands.new()
	trimmed.set_trim_input(-1.0)
	run(trimmed, 2.0)
	trimmed.set_trim_input(0.0)
	run(trimmed, 2.0)
	var loose = Route.ModelCommands.new()
	run(loose, 4.0)
	expect(absf(trimmed.snapshot().speed - loose.snapshot().speed) > 0.3, "different sail angles on the same course give different speeds")
	var irons = Route.ModelCommands.new()
	irons.set_rudder(-1.0)
	run(irons, 1.4)
	irons.set_rudder(0.0)
	run(irons, 4.0)
	expect(irons.snapshot().in_irons or irons.snapshot().speed < 1.0, "turning head to wind stalls the boat")

	# Flags forecast the next shift; the helper follows the flag, not the boat.
	var shift = Model.new()
	var first: Dictionary = shift.next_shift()
	for i in roundi((float(first["at"]) - Model.FORECAST - 0.5) * 60.0):
		shift.step(1.0 / 60.0)
	expect(not shift.snapshot().shift_visible and is_equal_approx(shift.snapshot().flag_wind, shift.snapshot().wind), "flags show the current wind before the forecast window")
	for i in 60:
		shift.step(1.0 / 60.0)
	state = shift.snapshot()
	expect(state.shift_visible and is_equal_approx(state.flag_wind, first.wind) and not is_equal_approx(state.wind, first.wind), "flags turn to the coming wind before it arrives")
	var helped_shift = Route.ModelCommands.new(true)
	run(helped_shift, float(first["at"]) - Model.ASSIST_FORECAST + 0.2)
	expect(helped_shift.snapshot().shift_visible, "assistance shows the forecast earlier")

	# Assistance eases the sail toward its best angle.
	var auto = Route.ModelCommands.new(true)
	run(auto, 3.0)
	expect(absf(auto.snapshot().trim - auto.snapshot().optimal_trim) < deg_to_rad(3.0), "assisted sail settles near the best angle")

	# Full chases.
	var normal = Route.ModelCommands.new()
	expect(Route.solve(normal), "three catches with a direct chase")
	state = normal.snapshot()
	expect(state.success and state.ordinary_eligible and state.score == 300 and not state.devil, "a chase without a gybe overtake is not devil")
	var devil = Route.ModelCommands.new()
	expect(Route.solve(devil, true), "a deliberate gybe before a catch")
	state = devil.snapshot()
	expect(state.devil and state.gybe_catch and state.catch_log.any(func(row): return row.after_gybe), "a catch soon after a downwind gybe earns devil")
	var second = Route.ModelCommands.new(false, 1)
	expect(Route.solve(second, true) and second.snapshot().devil, "the second wind pattern also allows devil")
	expect(second.snapshot().wood != Model.new().snapshot().wood, "variants move the driftwood")
	var helped = Route.ModelCommands.new(true)
	expect(Route.solve(helped, true, 1.0 / 60.0, true) and helped.snapshot().devil, "assisted devil with digital keys")

	# Driftwood slows the boat.
	var wood = Model.new()
	var log_at: Vector2 = Model.VARIANTS[0].wood[0]
	wood._position = log_at - Vector2(1.5, 0)
	wood._heading = 0.0
	wood._speed = 2.5
	wood._ship_distance = 100.0
	for i in 60:
		wood.step(1.0 / 60.0)
	expect(wood.snapshot().bumps == 1 and wood.snapshot().speed < 2.0, "hitting driftwood slows the boat")

	# Timeout and ended input.
	var idle = Model.new()
	run(idle, Model.ROUND_SECONDS + 1.0, 0.25)
	state = idle.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "timeout ends truthfully")
	idle.set_rudder(1.0)
	expect(idle.snapshot().rudder == 0.0, "ended round ignores input")
	var again = Route.ModelCommands.new()
	Route.solve(again)
	expect(again.snapshot().catch_log == normal.snapshot().catch_log, "identical inputs reproduce")
	print("Sail chase: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
