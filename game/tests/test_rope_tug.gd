extends SceneTree

const Model = preload("res://game/minigames/rope_tug_model.gd")
const Route = preload("res://game/tests/rope_tug_route.gd")
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
	expect(not state.hooked and not state.ended and not state.ordinary_eligible and state.score == 0, "fresh round starts unhooked")
	for field in ["tension", "rope_length", "rope_span", "cleats", "walls", "gates", "gates_passed", "snagged", "break_tension"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.set_thrust(INF)
	model.step(0.5)
	expect(model.snapshot().tug_speed == 0.0, "non-finite thrust is ignored")
	model.step(10.0)
	expect(is_equal_approx(model.snapshot().elapsed, 0.5), "long frames are capped")

	# Hook range, speed and the nearer cleat.
	var far = Route.ModelCommands.new()
	far.set_thrust(1.0)
	run(far, 1.5)
	far.set_thrust(0.0)
	far.interact()
	expect(not far.snapshot().hooked and (far.snapshot().feedback.contains("遠") or far.snapshot().feedback.contains("快")), "hooking needs range and low speed")
	var hook = Route.ModelCommands.new()
	hook.interact()
	state = hook.snapshot()
	expect(state.hooked and state.cleat == 1 and state.rope_length >= Model.ROPE_MIN, "hooking takes the nearer bow cleat")
	Route.reel_to(hook, 4.0)
	expect(absf(hook.snapshot().rope_length - 4.0) < 0.06, "holding E pays out rope")
	Route.reel_to(hook, 1.0)
	expect(is_equal_approx(hook.snapshot().rope_length, Model.ROPE_MIN), "rope length clamps at the minimum")
	hook.interact()
	expect(not hook.snapshot().hooked, "space unhooks away from the dock")

	# The pontoon only moves through rope tension.
	var drag = Route.ModelCommands.new()
	drag.set_thrust(-1.0)
	run(drag, 1.0)
	expect(drag.snapshot().pontoon == Model.PONTOON_START, "unhooked pontoon stays put")

	# Short and long rope give different results on the same line.
	var short = Route.ModelCommands.new()
	expect(Route.solve(short, Route.MAIN, 1.6), "short rope follows through all three bays")
	var short_state: Dictionary = short.snapshot()
	expect(short_state.success and not short_state.devil and short_state.score == 400 and short_state.breaks == 0 and short_state.ordinary_eligible, "main bays succeed without devil")
	var long = Route.ModelCommands.new()
	Route.solve(long, Route.MAIN, 4.5)
	var long_state: Dictionary = long.snapshot()
	expect(long_state.snags > 0 and long_state.gates_passed.size() < 3, "long rope swings wide and snags on the same tight line")

	# Devil: the narrow side bay with no rope break.
	var side = Route.ModelCommands.new()
	expect(Route.solve(side, Route.SIDE, 1.6), "side bay route succeeds")
	state = side.snapshot()
	expect(state.side_pass and state.devil and state.breaks == 0 and state.gates_passed[2].side, "side bay without breaks earns devil")

	# A slack long rope snapping taut at speed breaks on the heavy pontoon.
	var snap = Route.ModelCommands.new()
	snap.interact()
	Route.reel_to(snap, 5.0)
	for i in 300:
		var s: Dictionary = snap.snapshot()
		snap.set_turn(clampf(angle_difference(s.tug_heading, -PI / 2.0) * 3.0, -1.0, 1.0))
		snap.set_thrust(1.0)
		snap.step(1.0 / 60.0)
	expect(snap.snapshot().breaks == 1 and not snap.snapshot().hooked and snap.snapshot().feedback.contains("斷"), "snapping a slack long rope breaks it")
	var light = Route.ModelCommands.new(false, 1)
	light.interact()
	Route.reel_to(light, 5.0)
	for i in 300:
		var s: Dictionary = light.snapshot()
		light.set_turn(clampf(angle_difference(s.tug_heading, -PI / 2.0) * 3.0, -1.0, 1.0))
		light.set_thrust(1.0)
		light.step(1.0 / 60.0)
	expect(light.snapshot().breaks == 0, "the light pontoon variant survives the same snap")
	var elastic = Route.ModelCommands.new(true)
	elastic.interact()
	Route.reel_to(elastic, 6.0)
	expect(elastic.snapshot().rope_length > Model.ROPE_MAX, "assist rope reaches further")
	for i in 300:
		var s: Dictionary = elastic.snapshot()
		elastic.set_turn(clampf(angle_difference(s.tug_heading, -PI / 2.0) * 3.0, -1.0, 1.0))
		elastic.set_thrust(1.0)
		elastic.step(1.0 / 60.0)
	expect(elastic.snapshot().breaks == 0, "elastic assist rope survives the snap")

	# Variants change weight and the cleat, so the pontoon yaws differently.
	var v0 = Route.ModelCommands.new(false, 0)
	var v1 = Route.ModelCommands.new(false, 1)
	expect(v0.snapshot().pontoon_mass != v1.snapshot().pontoon_mass and v0.snapshot().cleats[0] != v1.snapshot().cleats[0], "variants differ in weight and cleat")
	for c in [v0, v1]:
		c.interact()
		Route.reel_to(c, 1.6)
		c.set_thrust(1.0)
		c.set_turn(-0.6)
		run(c, 2.0)
	expect(not is_equal_approx(v0.snapshot().pontoon_heading, v1.snapshot().pontoon_heading), "cleat position changes how the pontoon yaws")

	# Delivery rules: dock only after all bays, slowly.
	var early = Route.ModelCommands.new()
	early.interact()
	expect(early.snapshot().hooked, "hooked")
	early.interact()
	expect(not early.snapshot().ended, "unhooking before the bays never completes")

	# Timeout stays truthful; ended rounds ignore input.
	var idle = Route.ModelCommands.new()
	run(idle, Model.ROUND_SECONDS + 1.0, 0.25)
	state = idle.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "timeout ends truthfully")
	idle.interact()
	expect(not idle.snapshot().hooked, "ended round ignores input")

	# Assisted snag relief and the digital keyboard route.
	var helped = Route.ModelCommands.new(true)
	Route.solve(helped, Route.MAIN, 4.5)
	expect(helped.snapshot().feedback != "" , "assisted long-rope run reports state")
	var digital = Route.ModelCommands.new()
	expect(Route.solve(digital, Route.SIDE, 1.6, 1.1, 1.0 / 60.0, true) and digital.snapshot().devil, "digital keys complete the side bay")
	var slow = Route.ModelCommands.new()
	expect(Route.solve(slow, Route.MAIN, 1.6, 1.1, 1.0 / 30.0), "30 Hz completes the main bays")
	var again = Route.ModelCommands.new()
	Route.solve(again, Route.MAIN, 1.6)
	expect(again.snapshot().tug == short.snapshot().tug and again.snapshot().elapsed == short_state.elapsed, "identical inputs reproduce")
	print("Rope tug: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
