extends SceneTree

const Route := preload("res://game/tests/cotton_wind_route.gd")
const MODEL := "res://game/minigames/cotton_wind_model.gd"
var failures := 0
var checks := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	expect(FileAccess.file_exists(MODEL), "Cotton wind requires its bounded collection model")
	if not failures:
		var script = load(MODEL)
		if script != null and script.can_instantiate():
			var model = script.new()
			_boundaries(model)
			_material(model)
			_tail_negatives(model)
			_rejoin_contact(model)
			_unconfirmed_deadline(model)
			for variant in 2:
				for assisted in [false, true]:
					for rejoin in [false, true]:
						model.reset(assisted, variant)
						var end := Route.solve(model, rejoin)
						expect(end.ended and end.uniform and end.success and end.participated and end.ordinary_eligible, "Public collection route reaches real quality")
						expect(end.devil == rejoin and end.score == (500 if rejoin else 400), "Only actual rejoin adds the clean devil score")
						_conservation(end)
						print("COTTON_ROUTE variant=%d assist=%s rejoin=%s elapsed=%.6f score=%d travel=%.4f spin=%.4f bands=%s rejoins=%d" % [variant, assisted, rejoin, end.elapsed, end.score, end.travel, end.spin_travel, end.quality, end.rejoins])
		else:
			expect(false, "Cotton wind model must instantiate")
	print("Cotton wind model: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _advance(model, seconds: float) -> void:
	for i in roundi(seconds * 30):
		model.step(Route.DT)

func _conservation(s: Dictionary) -> void:
	var m: Dictionary = s.material
	var flying := 0.0
	for strand in s.strands:
		flying += strand.material
	var player := 0.0
	var helper := 0.0
	var bounded: bool = s.strands.size() <= 128
	for band in 3:
		for cell in 12:
			var p: float = s.bands[band][cell]
			var q: float = s.helper_bands[band][cell]
			bounded = bounded and p >= 0 and p <= 4 and q >= 0 and q <= 4
			player += p
			helper += q
	var hanging := float(s.tail.get("material", 0.0))
	expect(bounded and absf(flying - m.in_flight) < 1e-5 and absf(player - m.player) < 1e-5 and absf(helper - m.helper) < 1e-5 and absf(hanging - m.hanging) < 1e-5, "Material ledger agrees with actual bounded geometry")
	expect(absf(m.emitted - flying - player - helper - hanging - m.lost) < 1e-5, "Every emitted strand is accounted for exactly once")

func _boundaries(model) -> void:
	model.reset()
	var initial: Dictionary = model.snapshot()
	model.step(NAN)
	model.step(INF)
	model.step(-1.0)
	model.move_stick_to(Vector2(INF, NAN))
	model.set_motion(Vector2(NAN, 1))
	expect(model.snapshot() == initial, "Reject nonfinite targets, motion and invalid time")
	model.move_stick_to(Vector2(10000, 10000))
	expect(model.snapshot().stick == initial.stick, "No immediate teleport or swept collection")
	model.set_spin(5)
	model.step(200.0)
	var moved: Dictionary = model.snapshot()
	expect(absf(moved.elapsed - 0.25) < 1e-7 and absf(moved.travel - 30.0) < 0.001 and absf(moved.spin_travel - 0.75) < 0.0001, "Positive huge delta and diagonal pursuit respect speed caps")
	model.clear_input()
	_advance(model, 0.5)
	expect(model.snapshot().stick == moved.stick and model.snapshot().angle == moved.angle, "Clear cancels target and angular motion")
	var independent: Dictionary = model.snapshot()
	independent.bands[1][2] = 100
	independent.strands[0].material = -30
	expect(model.snapshot().bands[1][2] == 0 and model.snapshot().strands[0].material == 0.6, "Deeply independent snapshots")
	model.finish()
	expect(not model.snapshot().ended and model.snapshot().mistakes == 1 and not model.snapshot().feedback.is_empty(), "Fake finish charges one mistake with actionable feedback")
	model.reset()
	model.set_spin(1)
	for i in 480:
		model.step(0.25)
	var frozen: Dictionary = model.snapshot()
	expect(frozen.elapsed == 120.0 and frozen.ended and not frozen.success and not frozen.participated and not frozen.ordinary_eligible, "Stationary deadline cannot win or earn participation")
	model.set_motion(Vector2.ONE)
	model.move_stick_to(Vector2.ZERO)
	model.set_spin(-1)
	model.finish()
	model.toggle_helper()
	model.step(1.0)
	expect(model.snapshot() == frozen, "Ended round immutable via public input")
	model.reset()
	for i in 480:
		model.move_stick_to(Route.target(model.snapshot(), false))
		model.step(0.25)
	var no_spin: Dictionary = model.snapshot()
	expect(no_spin.material.player > 1 and not no_spin.uniform and not no_spin.participated and no_spin.spin_travel == 0, "Translation alone collects but cannot spread around stick")
	expect(no_spin.material.lost > 100 and no_spin.bands[0].max() == 4.0, "Overflow really reaches cell capacity and is accounted as loss")
	_conservation(no_spin)
	model.reset()
	model.set_motion(Vector2(1e35, -1e35))
	model.step(0.1)
	var diagonal: Dictionary = model.snapshot()
	expect(diagonal.stick.is_finite() and absf(diagonal.travel - 12.0) < 0.001, "Huge finite direction still travels at normalized speed")
	model.move_stick_to(Vector2(120, 155))
	model.set_motion(Vector2.LEFT)
	model.step(0.1)
	expect(absf(model.snapshot().stick.z - diagonal.stick.z) < 0.001 and model.snapshot().stick.x < diagonal.stick.x, "Directional input replaces pending drag target")
	model.reset(true, 1)
	model.move_stick_to(Vector2(0, Route.NEAR_Z))
	model.set_spin(1)
	for i in 480:
		model.step(0.25)
	var fixed_lane: Dictionary = model.snapshot()
	expect(fixed_lane.quality[1].ready and not fixed_lane.uniform and not fixed_lane.success, "Spinning in a productive fixed lane cannot balance the outer bands even with assist")

func _material(model) -> void:
	model.reset()
	model.move_stick_to(Vector2(0, 65))
	for i in 240:
		model.step(1.0 / 120.0)
		if model.snapshot().material.player > 0:
			break
	var first: Dictionary = model.snapshot()
	expect(first.bands[1][9] > 0 and first.bands[1][8] == 0, "First offset contact must deposit on middle radial cell 9; cell 8 remains empty")
	print("COTTON_FIRST elapsed=%.6f middle8=%.9f middle9=%.9f" % [first.elapsed, first.bands[1][8], first.bands[1][9]])
	var per_strand: Array[float] = []
	for depth in [56.0, 146.0]:
		model.reset()
		model.move_stick_to(Vector2(0, depth))
		model.set_spin(1)
		for i in 120:
			model.step(Route.DT)
			var s: Dictionary = model.snapshot()
			if s.material.player > 0:
				per_strand.append(s.material.player)
				break
	expect(per_strand.size() == 2 and per_strand[0] > per_strand[1], "Actual near contact retains more material than far contact")
	var signatures: Array = []
	for variant in 2:
		model.reset(false, variant)
		_advance(model, 1)
		var s: Dictionary = model.snapshot()
		signatures.append([s.wind, s.strands.size(), s.strands[0].position])
	expect(signatures[0][0] != signatures[1][0] and signatures[0][1] != signatures[1][1] and signatures[0][2] != signatures[1][2], "Variants differ in wind, spacing and real trajectory")
	model.reset()
	model.move_stick_to(Vector2(120, 55))
	model.toggle_helper()
	_advance(model, 15)
	var s: Dictionary = model.snapshot()
	expect(s.helper and s.material.helper > 1 and not s.participated and s.rejoins == 0, "Second stick actually collects its own material")
	_conservation(s)
	model.toggle_helper()
	_advance(model, 2)
	expect(not model.snapshot().helper and model.snapshot().material.helper == s.material.helper, "Disabling helper preserves its separate deposits")
	model.toggle_helper()
	model.move_stick_to(Vector2(0,146))
	_advance(model, 1.3)
	s = model.snapshot()
	var yielding_center: Vector3 = s.helper_stick
	var yielding_mass: float = s.material.helper
	_advance(model, 0.4)
	s = model.snapshot()
	expect(s.helper_yielding and s.helper_stick.x < yielding_center.x and s.material.helper == yielding_mass, "Nearby helper physically yields and leaves the strand for the player")

func _tail_negatives(model) -> void:
	for action in ["same", "middle", "no_spin", "away", "early"]:
		model.reset()
		model.move_stick_to(Vector2(40 if action == "early" else 60, 146))
		for i in 240:
			model.step(Route.DT)
			if not model.snapshot().tail.is_empty():
				break
		var birth: Dictionary = model.snapshot()
		expect(not birth.tail.is_empty(), "Public far-outer catch makes a free end")
		if birth.tail.is_empty():
			continue
		_conservation(birth)
		var tail: Dictionary = birth.tail
		var tip: Vector3 = tail.free_end
		var side := 1.0 if tail.anchor_band == 0 else -1.0
		model.set_spin(0 if action == "no_spin" else 1)
		model.toggle_helper()
		model.finish()
		var target := Vector2(tip.x, tip.z)
		if action == "same":
			target.x += 60 * side
		elif action == "no_spin":
			target.x -= 60 * side
		elif action == "away":
			target = Vector2(120 * side, 45)
		elif action == "early":
			target.x -= 31.0 * side
		model.move_stick_to(target)
		var saw_near := false
		var expired := false
		var saw_early_contact := false
		for i in 115:
			model.step(Route.DT)
			var active: Dictionary = model.snapshot().tail
			if active.is_empty() or active.age < tail.age:
				expired = true
				break
			saw_near = saw_near or active.near_break
			var relative: Vector3 = active.free_end - model.snapshot().stick
			saw_early_contact = saw_early_contact or (not active.near_break and relative.x * side >= 30.0 and relative.x * side <= 90 and Vector2(relative.y, relative.z).length() < 10.0)
			tail = active
		var s: Dictionary = model.snapshot()
		expect(s.rejoins == 0 and not s.success and expired, "Same/middle/outside/expired or nonrotating contact cannot rejoin: " + action)
		if action == "no_spin":
			expect(saw_near, "Nonrotating opposite end really crosses the near-breaking window")
			model.set_spin(1)
			model.step(Route.DT)
			expect(model.snapshot().rejoins == 0, "Starting spin after expiry cannot recover the old free end")
		if action == "early":
			expect(saw_early_contact, "Opposite end touches the free tip with spin before the tension window, without receiving it")
		_conservation(s)

func _rejoin_contact(model) -> void:
	model.reset()
	model.set_spin(1)
	for i in 1200:
		var before: Dictionary = model.snapshot()
		model.move_stick_to(Route.target(before, true))
		model.step(1.0 / 120.0)
		var after: Dictionary = model.snapshot()
		if after.rejoins == 0:
			continue
		var tail: Dictionary = before.tail
		expect(not tail.is_empty() and after.tail.is_empty(), "Real free end is consumed once")
		if tail.is_empty():
			return
		var tip: Vector3 = tail.free_end + Vector3.RIGHT * after.wind * 0.35 / 120.0
		var relative: Vector3 = tip - after.stick
		var axial := clampf(relative.x, -90, 90)
		var distance := relative.distance_to(Vector3(axial, 0, 0))
		var contact_cell := floori(fposmod(atan2(relative.z, relative.y) - after.angle, TAU) * 12 / TAU)
		var cell_pre: float = before.bands[tail.receiver_band][contact_cell]
		var cell_post: float = after.bands[tail.receiver_band][contact_cell]
		var angle: float = after.angle + tail.local_angle
		var anchor_cell := floori(fposmod(tail.local_angle, TAU) * 12 / TAU)
		var anchor_r := 6.0 + 4.0 * sqrt(before.bands[tail.anchor_band][anchor_cell])
		var anchor: Vector3 = after.stick + Vector3(tail.axial, cos(angle) * anchor_r, sin(angle) * anchor_r)
		var tension := anchor.distance_to(tip) - float(tail.rest_length)
		expect(tension >= 80.0 and tension <= 140.0 and tail.age < 3.0 and after.omega != 0, "Receiving substep is inside physical live tension window")
		expect((axial >= 30 if tail.receiver_band == 2 else axial < -30) and distance <= 6 + 4 * sqrt(cell_pre) + tail.receiver_margin, "Actual free point intersects the opposite finite capsule")
		expect(absf(cell_post - cell_pre - tail.material) < 1e-5 and after.material.hanging == 0, "Measured tail mass is deposited into the actual receiving cell")
		_conservation(after)
		print("COTTON_REJOIN elapsed=%.6f tail_age=%.6f tension=%.6f axial=%.6f gap=%.6f material=%.9f" % [after.elapsed, tail.age, tension, axial, distance, tail.material])
		return
	expect(false, "Real rejoin was not observed through public pursuit")

func _unconfirmed_deadline(model) -> void:
	model.reset()
	model.set_spin(1)
	for i in 480:
		model.move_stick_to(Route.target(model.snapshot(), true))
		model.step(0.25)
	var end: Dictionary = model.snapshot()
	expect(end.uniform and end.rejoins > 0 and end.ordinary_eligible and end.ended, "An unconfirmed but uniform rejoined work survives the deadline")
	expect(not end.success and not end.devil and end.score == 300, "Deadline without F awards only three ready bands")
	_conservation(end)
