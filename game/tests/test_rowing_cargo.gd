extends SceneTree

const Model = preload("res://game/minigames/rowing_cargo_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_physics_and_copies()
	_test_clock_and_input_bounds()
	_test_docking_fixtures()
	_test_environment_fixtures()
	_test_crate_impact_route()
	_test_wall_recovery_route()
	_test_public_routes()
	print("Rowing cargo: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _test_physics_and_copies() -> void:
	var a = Model.new()
	var b = Model.new()
	a.reset()
	b.reset()
	var initial: Dictionary = a.snapshot()
	var pickup_distance: float = initial.position.distance_to(initial.cargo[0].position)
	_expect(initial.carrying.is_empty() and initial.cargo[0].status == "waiting" and pickup_distance > Model.BOAT_RADIUS + Model.CRATE_RADIUS and pickup_distance <= Model.PICKUP_RADIUS, "empty initial hull is separate from waiting cargo but within pickup reach")
	for i in 180:
		for model in [a, b]:
			model.set_rudder(0.3)
			if i % 20 == 0:
				model.paddle()
			model.step(0.025)
	_expect(a.snapshot() == b.snapshot(), "identical public commands reproduce every snapshot field")
	var copy: Dictionary = a.snapshot()
	copy.cargo[0].status = "delivered"
	copy.delivery_ledger.append({})
	copy.docks[0].position = Vector2.ZERO
	_expect(a.snapshot().cargo[0].status == "waiting" and a.snapshot().delivery_ledger.is_empty(), "nested snapshot writes cannot mutate rules")
	_expect(a.snapshot().docks[0].position != Vector2.ZERO, "dock geometry is independently copied")
	a.reset()
	_expect(b.snapshot().elapsed > 0.0 and a.snapshot().elapsed == 0.0, "reset does not alter another independent model")
	a.reset()
	a.paddle()
	var velocity: Vector2 = a.snapshot().velocity
	for i in 100:
		a.paddle()
	_expect(a.snapshot().velocity == velocity, "command repeats cannot stack impulses in one instant")
	a.clear_input()
	a.step(0.1)
	_expect(a.snapshot().velocity.length() > 0.0 and a.snapshot().position != Model.START, "released boat retains physical inertia")
	a.reset()
	a.paddle(-1.0)
	_expect(a.snapshot().velocity.x < 0.0, "reverse paddle really reverses heading-relative impulse")
	a.reset()
	b.reset()
	for i in 100:
		a.set_rudder(0.65)
		b.set_rudder(0.65)
		if i % 20 == 0:
			a.paddle()
		if i % 20 == 8:
			b.paddle()
		a.step(0.025)
		b.step(0.025)
	_expect(absf(angle_difference(a.snapshot().heading, b.snapshot().heading)) > 0.005, "same steering route with shifted stroke timing changes approach angle")
	a.reset()
	a._heading = PI / 2.0
	a.paddle()
	_expect(a.snapshot().velocity.y > 0.7 and absf(a.snapshot().velocity.x) < 0.001, "paddle follows heading instead of world X")
	a.reset()
	a.sideslip(1.0)
	velocity = a.snapshot().velocity
	for i in 100:
		a.sideslip(-1.0)
	_expect(a.snapshot().velocity == velocity and not a.snapshot().sideslip_ready, "side impulses are lateral and cannot repeat before cooldown")
	_expect(absf(velocity.x) < 0.001 and velocity.y > 0.0, "positive sideslip moves starboard relative to heading")
	_expect(a.snapshot().lateral_speed > 0.0, "reported lateral speed shares the sideslip sign convention")
	a.step(Model.SLIP_COOLDOWN)
	_expect(not a.snapshot().sideslip_ready, "frame cap also applies when waiting for cooldown")
	for i in 3:
		a.step(0.25)
	_expect(a.snapshot().sideslip_ready and a.snapshot().paddle_ready, "cooldown readiness recovers on simulation clock")

func _test_clock_and_input_bounds() -> void:
	var model = Model.new()
	model.reset()
	_expect(not model.snapshot().ordinary_eligible, "unended practice or cancelled run has no card eligibility")
	var before: Dictionary = model.snapshot()
	for invalid in [NAN, INF, -INF, -1.0, 0.0]:
		model.step(invalid)
	model.set_rudder(NAN)
	model.paddle(INF)
	model.sideslip(NAN)
	_expect(model.snapshot() == before, "nonfinite commands and invalid time are ignored")
	model.set_rudder(90.0)
	_expect(model.snapshot().rudder == 1.0, "rudder clamps at physical limit")
	model.clear_input()
	_expect(model.snapshot().rudder == 0.0, "clear_input releases held rudder")
	model.paddle(1e20)
	model.sideslip(-1e20)
	_expect(model.snapshot().speed < Model.MAX_SPEED and model.snapshot().velocity.is_finite(), "huge finite impulse inputs clamp before physical application")
	model.step(1e20)
	_expect(model.snapshot().elapsed <= Model.MAX_FRAME_DELTA + 0.00001, "huge delta discards catchup beyond bounded frame")
	while not model.snapshot().ended:
		model.step(0.25)
	_expect(model.snapshot().ordinary_eligible and not model.snapshot().success and not model.snapshot().devil, "natural timeout earns ordinary eligibility only")
	before = model.snapshot()
	model.paddle()
	model.set_rudder(1.0)
	model.sideslip(1.0)
	model.interact()
	model.step(0.25)
	_expect(model.snapshot() == before, "terminal model freezes all commands and time")
	_expect(model.snapshot().delivery_ledger.size() <= 3, "storage remains bounded after unattended round")

func _test_docking_fixtures() -> void:
	# Explicit internal fixtures exercise rejection edges; only solve() earns route proof.
	var model = Model.new()
	model.reset()
	model.interact()
	_expect(model.snapshot().carrying == "crate-1", "pickup requires real nearby waiting crate")
	model._position = Model.DOCKS[0].position
	model._velocity = Vector2(2.0, 0.0)
	model.interact()
	_expect(model.snapshot().delivery_ledger.is_empty() and model.snapshot().feedback.contains("速度"), "fast docking is rejected with reason")
	model._velocity = Vector2.ZERO
	model._heading = PI / 2.0
	model.interact()
	_expect(model.snapshot().delivery_ledger.is_empty() and model.snapshot().feedback.contains("角度"), "crosswise docking is rejected")
	model._heading = 0.0
	model.interact()
	model.interact()
	_expect(model.snapshot().delivery_ledger.size() == 1 and model.snapshot().score == 100, "delivered cargo cannot repeat credit")
	model.reset()
	model.interact()
	model._position = Model.DOCKS[1].position
	model.interact()
	_expect(model.snapshot().delivery_ledger.is_empty() and model.snapshot().feedback.contains("碼頭 1"), "wrong dock does not accept cargo")
	model.reset()
	model._velocity = Vector2(1.2, 0.0)
	model.interact()
	_expect(model.snapshot().carrying.is_empty() and model.snapshot().feedback.contains("速度"), "pickup also requires safe speed")
	model.reset(true)
	model.interact()
	model._position = Model.DOCKS[0].position + Vector2(1.25, 0.0)
	model._velocity = Vector2(0.95, 0.0)
	model._heading = 0.42
	model.interact()
	_expect(model.snapshot().delivery_ledger.size() == 1, "assist widens radius, speed and angle while still requiring delivery")
	model.reset()
	model.interact()
	model._position = Model.DOCKS[0].position
	model._elapsed = 1.5
	model.sideslip(1.0)
	model.interact()
	_expect(not model.snapshot().crest_dock, "pressing side key without actual lateral travel cannot earn crest dock")

func _test_environment_fixtures() -> void:
	# These state arrangements are collision/tide fixtures, never earned route evidence.
	var model = Model.new()
	model.reset()
	var normal: Dictionary = model.snapshot()
	model._position.y = Model.LONG_ROUTE_Y
	var sheltered: Dictionary = model.snapshot()
	_expect(sheltered.sheltered and is_equal_approx(sheltered.water.strength, normal.water.strength * Model.SHELTER_FACTOR), "long passage has physically reduced modeled waves")
	model.reset(true)
	_expect(is_equal_approx(model.snapshot().water.strength, normal.water.strength * Model.ASSIST_WAVE_FACTOR), "assist lowers physical wave force")
	model.reset()
	model.step(0.25)
	_expect(model.snapshot().velocity.length() > 0.01 and absf(model.snapshot().angular_velocity) > 0.001, "visible waves alter translation and heading without input")
	model._elapsed = 4.5
	var high_gap: float = model.snapshot().gap.half_width
	model._elapsed = 13.5
	_expect(high_gap - model.snapshot().gap.half_width > 1.0, "tide changes the actual collision gap")
	model._position = Vector2(0.0, 0.7)
	model._velocity = Vector2.ZERO
	model.step(0.02)
	var state: Dictionary = model.snapshot()
	var free := true
	for wall in state.breakwaters:
		free = free and not wall.grow(Model.BOAT_RADIUS).has_point(state.position)
	_expect(free and Model.BOUNDS.grow(-Model.BOAT_RADIUS).has_point(state.position), "closing tide ejects hull to free playable water")
	model._position = Vector2(0.0, -6.65)
	model.step(0.02)
	_expect(Model.BOUNDS.grow(-Model.BOAT_RADIUS).has_point(model.snapshot().position), "breakwater recovery near south boundary cannot eject outside playable bounds")
	model.reset()
	model._position = Vector2(10.6, 0.0)
	model._velocity = Vector2(3.0, 0.0)
	model.step(0.25)
	_expect(model.snapshot().wall_collisions > 0 and model.snapshot().crate_impacts == 0, "wall collision is distinct from crate impact")
	_expect(model.snapshot().speed <= Model.MAX_SPEED and model.snapshot().position.x <= Model.BOUNDS.end.x - Model.BOAT_RADIUS, "wall collision keeps bounded speed and position")
	model.reset()
	model._position = Vector2(-0.85, 2.0)
	model._velocity = Vector2(3.0, 0.0)
	model.step(0.25)
	_expect(model.snapshot().wall_collisions > 0 and model.snapshot().position.x < -Model.BREAKWATER_X, "breakwater blocks travel outside tide gap")
	model.reset()
	model._position = Vector2(-0.85, 0.0)
	model._velocity = Vector2(3.0, 0.0)
	model.step(0.25)
	_expect(model.snapshot().wall_collisions == 0 and model.snapshot().position.x > -Model.BREAKWATER_X, "short exposed tide gap can actually be traversed")
	model.reset()
	model._position = Vector2(-0.85, Model.LONG_ROUTE_Y)
	model._velocity = Vector2(3.0, 0.0)
	model._elapsed = 13.5
	model.step(0.25)
	_expect(model.snapshot().wall_collisions == 0 and model.snapshot().position.x > -Model.BREAKWATER_X, "sheltered passage stays open at lowest tide")
	model.reset(true)
	model.interact()
	model._position = Model.DOCKS[0].position + Vector2(1.0, 0.0)
	model._elapsed = 0.0
	model.step(0.02)
	_expect(model.snapshot().velocity.x < 0.0 and not model.snapshot().success, "modest assist attraction is physical and does not complete cargo")
	model.reset()
	model._position = Model.DOCKS[0].position
	model._elapsed = 1.5
	model.sideslip(1.0)
	var crest_velocity: Vector2 = model.snapshot().velocity
	model.reset()
	model._position = Model.DOCKS[0].position
	model.sideslip(1.0)
	_expect(crest_velocity.length() > model.snapshot().velocity.length(), "actual crest amplifies the lateral stroke")

func _test_crate_impact_route() -> void:
	# Collision fixture creates a real impact, then public controls recover and deliver.
	var model = Model.new()
	model.reset()
	model._position = Vector2(-9.0, -3.0)
	model._velocity = Vector2(3.0, 0.0)
	model.step(0.25)
	_expect(model.snapshot().crate_impacts == 1 and model.snapshot().wall_collisions == 0, "fast hull contact records a real crate impact")
	_expect(model.snapshot().cargo[0].status == "waiting" and model.snapshot().cargo[0].position == Model.CARGO_STARTS[0], "impacted cargo remains recoverable at its anchored pickup")
	solve(model)
	_expect(model.snapshot().success and model.snapshot().ordinary_eligible and not model.snapshot().devil, "real impact denies devil while recovered three-crate finish still succeeds")

func _test_wall_recovery_route() -> void:
	# Boundary fixture, followed by public recovery; wall bumps alone never deny devil.
	var model = Model.new()
	model.reset()
	model._position = Vector2(-10.6, -3.0)
	model._velocity = Vector2(-3.0, 0.0)
	model.step(0.25)
	_expect(model.snapshot().wall_collisions == 1 and model.snapshot().crate_impacts == 0, "wall fixture records only hull collision")
	navigate(model, Model.CARGO_STARTS[0])
	solve(model)
	_expect(model.snapshot().success and model.snapshot().devil, "recovering from an actual wall bump preserves earned devil")

func _test_public_routes() -> void:
	var normal_angles: Array = []
	for assisted in [false, true]:
		var model = Model.new()
		model.reset(assisted)
		solve(model)
		var state: Dictionary = model.snapshot()
		_expect(state.success and state.devil and state.ordinary_eligible, "public route delivers three and earns actual crest dock: assisted=%s" % assisted)
		_expect(state.delivery_ledger.size() == 3 and state.crate_impacts == 0, "three distinct clean deliveries: assisted=%s" % assisted)
		_expect(state.delivery_ledger[0].dock_id == 1 and state.delivery_ledger[1].dock_id == 2 and state.delivery_ledger[2].dock_id == 1, "cargo identities reach both assigned docks")
		if not assisted:
			for delivery in state.delivery_ledger:
				normal_angles.append(delivery.angle)
		print("PUBLIC ROUTE assisted=%s elapsed=%.3f crate_impacts=%d walls=%d ledger=%s" % [assisted, state.elapsed, state.crate_impacts, state.wall_collisions, state.delivery_ledger])
	var shifted = Model.new()
	shifted.reset()
	solve(shifted, 0.2)
	_expect(shifted.snapshot().success, "same waypoints remain deliverable with shifted stroke timing")
	var angle_changed := false
	for i in shifted.snapshot().delivery_ledger.size():
		angle_changed = angle_changed or absf(shifted.snapshot().delivery_ledger[i].angle - normal_angles[i]) > 0.001
	_expect(angle_changed, "shifted stroke timing changes recorded physical docking angles on the same route")
	print("SHIFTED STROKES elapsed=%.3f ledger=%s" % [shifted.snapshot().elapsed, shifted.snapshot().delivery_ledger])

static func solve(model, stroke_shift: float = 0.0) -> void:
	for i in 3:
		var state: Dictionary = model.snapshot()
		if i > 0:
			navigate(model, Vector2(5.0, Model.LONG_ROUTE_Y), false, stroke_shift)
			navigate(model, Vector2(-4.0, Model.LONG_ROUTE_Y), false, stroke_shift)
			navigate(model, Model.CARGO_STARTS[i], false, stroke_shift)
		model.interact()
		navigate(model, Vector2(-4.0, Model.LONG_ROUTE_Y), false, stroke_shift)
		navigate(model, Vector2(4.0, Model.LONG_ROUTE_Y), false, stroke_shift)
		var dock: Vector2 = Model.DOCKS[Model.DESTINATIONS[i] - 1].position
		navigate(model, dock - Vector2(2.0, 0.0), false, stroke_shift)
		navigate(model, dock, true, stroke_shift)
		state = model.snapshot()
		var guard := 0
		while not state.ended and not state.crest and guard < 260:
			steer(model, 0.0)
			model.step(0.025)
			state = model.snapshot()
			guard += 1
		model.sideslip(-1.0 if state.position.y > dock.y else 1.0)
		for frame in 16:
			steer(model, 0.0)
			model.step(0.025)
		model.interact()
		if model.snapshot().delivery_ledger.size() != i + 1:
			print("SOLVER delivery failure i=%d state=%s" % [i, model.snapshot()])
			return

static func steer(model, heading: float) -> void:
	var state: Dictionary = model.snapshot()
	var correction: float = angle_difference(state.heading, heading) * 4.0 - state.angular_velocity * 2.0
	model.set_rudder(signf(correction) if absf(correction) > 0.1 else 0.0)

static func navigate(model, target: Vector2, dock_align: bool = false, stroke_shift: float = 0.0) -> void:
	for frame in 2000:
		var state: Dictionary = model.snapshot()
		if state.ended:
			return
		var offset: Vector2 = target - state.position
		var distance := offset.length()
		var heading: float = offset.angle()
		if dock_align:
			heading = 0.0
		if distance < 0.45 and state.speed < 0.6 and (not dock_align or absf(angle_difference(state.heading, 0.0)) < 0.15):
			model.clear_input()
			return
		steer(model, heading)
		var error := absf(angle_difference(state.heading, heading))
		var desired_speed := minf(2.5, distance * 0.9) if error < 0.5 else 0.0
		if dock_align:
			desired_speed = clampf(offset.x, -1.0, 1.0) if error < 0.2 else 0.0
			if error < 0.2 and state.sideslip_ready and absf(offset.y) > 0.2:
				model.sideslip(signf(offset.y * 0.8 - state.velocity.y))
		if state.paddle_ready and fposmod(state.elapsed, 0.5) >= stroke_shift:
			if state.forward_speed < desired_speed - 0.35:
				model.paddle(1.0)
			elif state.forward_speed > desired_speed + 0.35:
				model.paddle(-1.0)
		model.step(0.025)
	print("SOLVER waypoint timeout target=%s state=%s" % [target, model.snapshot()])
