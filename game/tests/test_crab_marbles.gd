extends SceneTree

const Model = preload("res://game/minigames/crab_marbles_model.gd")
const Route = preload("res://game/tests/crab_marbles_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run(model, seconds: float, delta: float = 1.0 / 60.0) -> void:
	for i in roundi(seconds / delta):
		model.step(delta)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(not state.ended and state.balls_left == 3 and state.opened == 0 and not state.ordinary_eligible, "fresh round holds three marbles")
	for field in ["trail", "bounce_points", "gates", "rocks", "slopes", "helper_aim", "first_segment", "power", "charging"]:
		expect(state.has(field), "snapshot exposes " + field)
	expect(state.first_segment.is_empty(), "unassisted rounds show no path preview")
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.set_aim_input(1.0)
	run(model, 1.0)
	expect(is_equal_approx(model.snapshot().aim, Model.AIM_SPEED * 1.0), "held aim turns at a fixed rate")
	run(model, 3.0)
	expect(is_equal_approx(model.snapshot().aim, Model.AIM_LIMIT), "aim clamps at the limit")
	model.set_aim_input(INF)
	model.set_aim_input(0.0)

	# Power changes distance, not just animation.
	var probe = Model.new()
	var soft: Dictionary = probe.simulate(deg_to_rad(-15.0), 0.05)
	var hard: Dictionary = probe.simulate(deg_to_rad(-15.0), 0.25)
	expect(soft.stop.distance_to(Model.LAUNCHER) < hard.stop.distance_to(Model.LAUNCHER) - 0.5, "the same aim with more power rolls further")
	var played = Model.new()
	played.set_charging(true)
	run(played, Model.CHARGE_SECONDS * 0.25)
	var charged: float = played.snapshot().power
	played.set_charging(false)
	expect(played.snapshot().ball_active and played.snapshot().balls_left == 2 and absf(charged - 0.25) < 0.03, "release fires with the charged power")
	played.set_charging(true)
	expect(not played.snapshot().charging and played.snapshot().feedback.contains("停下"), "no charging while a marble rolls")
	run(played, 9.5)
	state = played.snapshot()
	var expected: Dictionary = Model.new().simulate(0.0, charged)
	expect(not state.ball_active and state.ball.distance_to(expected.stop) < 0.05, "the live roll matches the pure preview")
	expect(state.trail.size() > 3 and state.shots.size() == 1, "the sand keeps a trail and a shot record")
	played.set_charging(true)
	played.clear_input()
	expect(not played.snapshot().charging and played.snapshot().balls_left == 2, "lifecycle clear cancels a charge without firing")

	# Direct and bank shots both open gates.
	var layout = Model.new()
	var direct := 0
	var bank := 0
	var doubles := 0
	for degree in range(-69, 70):
		for step in range(0, 21, 2):
			var shot: Dictionary = layout.simulate(deg_to_rad(degree), step / 20.0, [false, false, false])
			if shot.gates.is_empty():
				continue
			if shot.bounces == 0: direct += 1
			else: bank += 1
			if shot.double_after_bounce: doubles += 1
	expect(direct > 0 and bank > 0, "both direct hits and wet-sand banks open gates")
	expect(doubles > 0 and doubles < 30, "a bank double exists but is rare")
	var guarded: bool = true
	for degree in range(-69, 70):
		for step in range(0, 21):
			var shot: Dictionary = layout.simulate(deg_to_rad(degree), step / 20.0, [false, false, false])
			if shot.bounces == 0 and shot.gates.has(1):
				guarded = false
	expect(guarded, "the rock-guarded middle gate needs a bounce")
	var nearest: Vector2 = Vector2.INF
	for gate: Vector2 in Model.LAYOUTS[0].gates:
		if gate.distance_to(Model.LAUNCHER) < nearest.distance_to(Model.LAUNCHER): nearest = gate
	var offset: Vector2 = nearest - Model.LAUNCHER
	expect(is_equal_approx(layout.helper_aim(), atan2(offset.x, -offset.y)), "helper aims straight at the nearest closed gate, ignoring hidden slopes")

	# Full rounds through public inputs.
	var normal = Route.ModelCommands.new()
	expect(Route.solve(normal), "three marbles open three gates")
	state = normal.snapshot()
	expect(state.success and state.ended and state.ordinary_eligible and not state.devil and state.score == 300, "normal success scores the gates")
	var devil = Route.ModelCommands.new()
	expect(Route.solve(devil, true), "a bank double then one more marble")
	state = devil.snapshot()
	expect(state.devil and state.double_after_bounce and state.score == 350, "bank double earns devil and a spare marble bonus")
	var other = Route.ModelCommands.new(false, 1)
	expect(Route.solve(other, true) and other.snapshot().devil, "the second layout also allows the devil double")
	expect(other.snapshot().gates[0].position != Model.new().snapshot().gates[0].position, "layouts move the gates")

	# Assistance adds marbles and a first-segment preview without removing eligibility.
	var helped = Route.ModelCommands.new(true)
	state = helped.snapshot()
	expect(state.balls_left == Model.ASSIST_BALLS and state.first_segment.size() == 2, "assist shows the first segment and adds marbles")
	expect(Route.solve(helped, true) and helped.snapshot().devil, "assisted devil remains eligible")

	# Running out of marbles or time is truthful.
	var miss = Model.new()
	for i in 3:
		miss.set_charging(true)
		miss.set_charging(false)
		run(miss, 9.5)
	state = miss.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.balls_left == 0, "empty pouch ends the round truthfully")
	var idle = Model.new()
	run(idle, Model.ROUND_SECONDS + 1.0, 0.25)
	expect(idle.snapshot().ended and not idle.snapshot().success, "time limit ends the round")
	idle.set_charging(true)
	expect(not idle.snapshot().charging, "ended round ignores input")
	var again = Route.ModelCommands.new()
	Route.solve(again)
	expect(again.snapshot().shots == normal.snapshot().shots, "identical inputs reproduce")
	print("Crab marbles: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
