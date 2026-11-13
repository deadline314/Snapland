extends SceneTree

const Model = preload("res://game/minigames/buoy_relay_model.gd")
const Route = preload("res://game/tests/buoy_relay_route.gd")
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

func charge(commands, seconds: float) -> void:
	commands.set_action(true)
	run(commands, seconds)
	commands.set_action(false)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.phase == "aim_catch" and state.station == 2 and not state.ended and not state.ordinary_eligible, "relay starts at the outer buoy")
	for field in ["tubes", "ring", "power", "strain", "lock", "throw_preview", "stations", "held"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")

	# Charge sets distance.
	var short = Route.ModelCommands.new()
	charge(short, 0.05)
	run(short, 0.1)
	var long = Route.ModelCommands.new()
	charge(long, 0.9)
	run(long, 0.1)
	expect(short.snapshot().ring.to < long.snapshot().ring.to - 4.0, "longer charge throws further")
	expect(short.snapshot().phase == "ring_flight", "release throws the ring")
	run(short, 3.0)
	state = short.snapshot()
	expect(state.phase == "aim_catch" and state.misses == 1, "a ring that lands on empty water is a miss")

	# Tubes drift with the tide.
	var drift = Model.new()
	var before: float = drift.snapshot().tubes[2].x
	for i in 60: drift.step(1.0 / 60.0)
	expect(not is_equal_approx(drift.snapshot().tubes[2].x, before), "tubes drift on the tide")

	# Reeling at a crest slips; calm reeling lands the tube.
	var slip = Route.ModelCommands.new()
	var target: float = Route.plan_catch(slip.snapshot(), false)
	Route.throw_with(slip, Route.power_for(target - slip.snapshot().station_x), 1.0 / 60.0)
	for i in 300:
		if slip.snapshot().phase == "reeling": break
		slip.step(1.0 / 60.0)
	expect(slip.snapshot().phase == "reeling" and slip.snapshot().held.size() == 1, "a well-placed ring hooks a tube")
	slip.set_action(true)
	run(slip, 3.0)
	expect(slip.snapshot().slips >= 1 and slip.snapshot().phase == "aim_catch", "hauling through the crests slips the rope")

	# Full relays.
	var direct = Route.ModelCommands.new()
	expect(Route.solve(direct, false, true), "direct throws to shore")
	state = direct.snapshot()
	expect(state.success and not state.devil and state.direct == 3 and state.score == 450 and state.ordinary_eligible, "direct throws skip each handoff")
	var near = Route.ModelCommands.new()
	expect(Route.solve(near, false, false), "near handoffs via the middle buoy")
	state = near.snapshot()
	expect(state.success and state.direct == 0 and state.score == 300, "near handoffs score without the skip bonus")
	var devil = Route.ModelCommands.new()
	expect(Route.solve(devil, true, true), "a double catch relay")
	state = devil.snapshot()
	expect(state.double_catch and state.devil and state.delivered == 3, "one ring around two tubes earns devil")
	var second = Route.ModelCommands.new(false, 1)
	expect(Route.solve(second, true, false) and second.snapshot().devil, "the second tide also allows a double catch")
	expect(second.snapshot().tubes[0].drift != Model.VARIANTS[0].tubes[0][1], "variants change the drift")

	# Handoff lock and the camera station switch keep the tube.
	var pass_test = Route.ModelCommands.new()
	var aim: float = Route.plan_catch(pass_test.snapshot(), false)
	Route.throw_with(pass_test, Route.power_for(aim - pass_test.snapshot().station_x), 1.0 / 60.0)
	for i in 900:
		var s: Dictionary = pass_test.snapshot()
		if s.phase == "aim_pass": break
		if s.phase == "reeling":
			pass_test.set_action(absf(s.bundle_wobble) < 0.6)
		pass_test.step(1.0 / 60.0)
	expect(pass_test.snapshot().phase == "aim_pass", "the tube reaches the outer buoy")
	pass_test.set_action(true)
	var locked := false
	for i in 120:
		pass_test.step(1.0 / 60.0)
		if pass_test.snapshot().lock == 1: locked = true; break
	expect(locked, "a charge landing at the middle buoy shows the lock")
	pass_test.set_action(false)
	run(pass_test, 1.0)
	state = pass_test.snapshot()
	expect(state.station == 1 and state.phase == "aim_pass" and state.held.size() == 1, "the middle buoy takes over with the tube still held")
	charge(pass_test, 0.05)
	run(pass_test, 1.0)
	expect(pass_test.snapshot().misses >= 1 and pass_test.snapshot().phase == "pass_return", "an unlocked pass misses and the rope pulls it back")
	run(pass_test, Model.MISS_RETURN + 0.1)
	expect(pass_test.snapshot().phase == "aim_pass" and pass_test.snapshot().held.size() == 1, "the tube comes back to the same station")

	# Assistance: longer floats, wider catch, landing preview.
	var helped = Route.ModelCommands.new(true)
	helped.set_action(true)
	helped.step(0.2)
	expect(helped.snapshot().show_landing and is_finite(helped.snapshot().throw_preview) and helped.snapshot().catch_radius > Model.CATCH_RADIUS, "assist previews the landing with a wider ring")
	helped.set_action(false)
	var assisted = Route.ModelCommands.new(true)
	expect(Route.solve(assisted, true, false) and assisted.snapshot().devil, "assisted devil remains eligible")

	# Lifecycle and timeout.
	var cancel = Model.new()
	cancel.set_action(true)
	cancel.step(0.5)
	cancel.clear_input()
	cancel.set_action(false)
	expect(cancel.snapshot().phase == "aim_catch" and cancel.snapshot().ring.is_empty(), "clearing input cancels a charge without throwing")
	var idle = Model.new()
	run(idle, Model.ROUND_SECONDS + 1.0, 0.25)
	state = idle.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "timeout ends truthfully")
	idle.set_action(true)
	expect(not idle.snapshot().charging, "ended round ignores input")
	var again = Route.ModelCommands.new()
	Route.solve(again, false, true)
	expect(again.snapshot().elapsed == direct.snapshot().elapsed, "identical inputs reproduce")
	print("Buoy relay: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
