extends SceneTree

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	expect(ResourceLoader.exists("res://game/minigames/jelly_trampoline_model.gd"), "real elastic ballistic model must exist")
	if failures == 0:
		var model = load("res://game/minigames/jelly_trampoline_model.gd").new()
		_rules(model)
		_input_and_recovery(model)
		_geometry_and_deadline(model)
		_prediction(model)
		_threshold_and_bell_checkpoint(model)
		for variant in 2:
			for assisted in [false, true]:
				for bell in [false, true]:
					model.reset(assisted, variant)
					var result := solve(model, bell)
					expect(result.success and result.ended and result.ordinary_eligible and result.delivered == 3, "three real public-input deliveries in every route")
					expect(result.devil == bell and result.bell_deliveries == (1 if bell else 0), "same-fruit physical bell distinguishes devil")
					expect(result.score == (500 if bell else 400), "unmistaken public route exact score")
					print("JELLY_ROUTE variant=%d assisted=%s bell=%s elapsed=%.9f success=%s score=%d" % [variant, assisted, bell, result.elapsed, result.success, result.score])
		_bell_recatch(model)
	print("Jelly trampoline tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

static func advance(model, seconds: float) -> void:
	var left := seconds
	while left > 1.0e-10:
		var h := minf(left, 1.0 / 60.0)
		model.step(h)
		left -= h

static func configure(model, x: float, tilt: float) -> void:
	for i in 20:
		var state: Dictionary = model.snapshot()
		if state.bed.x == x:
			break
		model.move_bed(1 if state.bed.x < x else -1)
	for i in 20:
		var state: Dictionary = model.snapshot()
		if state.tilt == tilt:
			break
		model.adjust_tilt(1 if state.tilt < tilt else -1)

static func launch(model, seconds: float) -> void:
	model.begin_charge()
	advance(model, seconds)
	model.release_charge()

static func wait_ready(model) -> Dictionary:
	for i in 420:
		var state: Dictionary = model.snapshot()
		if state.fruit.ready or state.ended:
			return state
		model.step(1.0 / 60.0)
	return model.snapshot()

# These recipes use only the Model/Driver's public controls; Session tests reuse them.
static func solve(model, bell: bool = false) -> Dictionary:
	var initial: Dictionary = model.snapshot()
	if initial.assisted:
		configure(model, 340, 0)
		model.toggle_helper()
		launch(model, 0.8)
		var caught: Dictionary = wait_ready(model)
		if not caught.fruit.ready or caught.mistakes != 0 or caught.delivered != 0 or caught.charging or caught.fruit.vx != 0 or caught.fruit.vy != 0:
			return caught
		print("JELLY_AI_CATCH variant=%d elapsed=%.9f ready=%s manual_launch_pending=%s" % [caught.variant, caught.elapsed, caught.fruit.ready, not caught.charging])
		model.toggle_helper()
	for i in 3:
		var state: Dictionary = model.snapshot()
		var mass: float = state.fruit.mass
		var x := 380.0
		var tilt := 21.0
		var seconds := 1.28
		if mass == 1.15:
			x = 420.0
			tilt = 28.0
		elif mass == 0.9:
			x = 340.0
			seconds = 1.26
		if bell and i == 0:
			x += 80.0
		configure(model, x, tilt)
		launch(model, seconds)
		wait_ready(model)
	return model.snapshot()

func _rules(model) -> void:
	var initial: Dictionary = model.snapshot()
	for key in ["elapsed", "remaining", "score", "mistakes", "ended", "success", "devil", "ordinary_eligible", "participated", "assisted", "variant", "delivered", "bell_deliveries", "charging", "charge_seconds", "depth", "tilt", "helper", "feedback", "bed", "target", "bell", "fruit", "trajectory"]:
		expect(initial.has(key), "frozen snapshot field " + key)
	expect(initial.remaining == 60 and initial.bed.x == 340 and initial.tilt == 21 and not initial.participated, "initial calibration")
	for delta in [NAN, INF, -INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot() == initial, "malicious delta is inert")
	model.step(1.0e30)
	expect(is_equal_approx(model.snapshot().elapsed, 0.25), "huge delta capped")
	var copy: Dictionary = model.snapshot()
	copy.fruit.x = 1000000
	copy.bed.x = -1000000
	copy.trajectory.append(Vector2.INF)
	expect(model.snapshot().fruit.x == 340 and model.snapshot().bed.x == 340 and model.snapshot().trajectory.is_empty(), "snapshot deep isolation")
	model.begin_charge()
	advance(model, 1.4)
	var charged: Dictionary = model.snapshot()
	expect(is_equal_approx(charged.depth, 1) and is_equal_approx(charged.fruit.y, 532) and not charged.participated and charged.fruit.ready, "held charge depresses actual fruit and never auto launches")
	model.release_charge()
	var launched: Dictionary = model.snapshot()
	expect(launched.participated and not launched.fruit.ready and is_equal_approx(launched.fruit.y, 532), "launch begins from depressed physical fruit")
	expect(is_equal_approx(launched.fruit.vx, 1000 * sin(deg_to_rad(21))) and is_equal_approx(launched.fruit.vy, -1000 * cos(deg_to_rad(21))), "energy and angle actual launch velocity")
	var before: Dictionary = model.snapshot()
	model.release_charge()
	model.begin_charge()
	model.release_charge()
	expect(model.snapshot().fruit == before.fruit, "release during flight cannot steer")
	model.clear_input()
	expect(model.snapshot().fruit == before.fruit, "clearing input preserves physical flight")
	model.reset()
	model.begin_charge()
	advance(model, 0.1)
	model.release_charge()
	expect(not model.snapshot().participated and model.snapshot().fruit.ready, "shallow tap not launch")
	model.begin_charge()
	advance(model, 0.5)
	model.clear_input()
	model.release_charge()
	expect(not model.snapshot().participated and not model.snapshot().charging and model.snapshot().fruit.y == 492, "cancellation has no ghost launch")

func _bell_recatch(model) -> void:
	model.reset()
	configure(model, 380, 21)
	launch(model, 1.28)
	wait_ready(model)
	configure(model, 420, 28)
	launch(model, 1.28)
	wait_ready(model)
	configure(model, 500, 35)
	model.toggle_helper()
	launch(model, 1.34)
	for i in 3:
		model.move_bed(1)
	expect(not model.snapshot().fruit.ready and model.snapshot().bed.x == 620, "expanded bed travel only moves support during flight")
	var caught: Dictionary = wait_ready(model)
	expect(caught.fruit.ready and caught.fruit.bell_touched and caught.delivered == 2 and caught.bell_deliveries == 0 and caught.mistakes == 0 and not caught.charging, "same physical bell-touched fruit actually recatches bed before delivery")
	print("JELLY_BELL_RECATCH elapsed=%.9f bell=%s bed_x=%.3f manual_launch_pending=%s" % [caught.elapsed, caught.fruit.bell_touched, caught.bed.x, not caught.charging])
	advance(model, 0.25)
	expect(model.snapshot().fruit.ready and model.snapshot().fruit.bell_touched, "AI preserves same-fruit bell and waits for manual charge")
	configure(model, 340, 21)
	model.begin_charge()
	advance(model, 1.26)
	expect(model.snapshot().fruit.ready and model.snapshot().charging and model.snapshot().fruit.bell_touched, "manual recharge preserves same-fruit bell")
	model.release_charge()
	expect(not model.snapshot().fruit.ready, "explicit release launches after real bell recatch")
	var delivered: Dictionary = wait_ready(model)
	expect(delivered.success and delivered.devil and delivered.delivered == 3 and delivered.bell_deliveries == 1 and delivered.score == 500, "same bell fruit after recatch and manual release earns devil only on real delivery")
	print("JELLY_BELL_RECATCH_DELIVERY elapsed=%.9f score=%d devil=%s" % [delivered.elapsed, delivered.score, delivered.devil])

func _input_and_recovery(model) -> void:
	model.reset(false, -1)
	expect(model.snapshot().variant == 1 and model.snapshot().fruit.mass == 1.15 and model.snapshot().target.y == 260, "variant bounded modulo two with B physical order")
	model.reset()
	for i in 30:
		model.move_bed(-2147483648)
		model.adjust_tilt(-2147483648)
	expect(model.snapshot().bed.x == 180 and model.snapshot().tilt == -35, "negative steps clamp physical controls")
	for i in 30:
		model.move_bed(2147483647)
		model.adjust_tilt(2147483647)
	expect(model.snapshot().bed.x == 620 and model.snapshot().tilt == 35, "positive steps clamp physical controls")
	model.reset_fruit()
	model.toggle_helper()
	advance(model, 0.25)
	expect(not model.snapshot().participated and model.snapshot().mistakes == 0 and model.snapshot().delivered == 0, "configuration helper and empty reset do not participate")
	model.begin_charge()
	advance(model, 0.5)
	var charging: Dictionary = model.snapshot()
	model.begin_charge()
	expect(model.snapshot() == charging, "duplicate begin does not restart charge")
	model.reset_fruit()
	expect(model.snapshot().mistakes == 1 and not model.snapshot().participated and model.snapshot().elapsed == charging.elapsed and model.snapshot().score == 0, "charged reset costs mistake without rewinding time or negative score")
	advance(model, 60)
	expect(model.snapshot().ended and not model.snapshot().success and not model.snapshot().ordinary_eligible, "helper configuration and hold without release cannot earn card")
	var ended: Dictionary = model.snapshot()
	model.begin_charge()
	model.release_charge()
	model.move_bed(1)
	model.adjust_tilt(-1)
	model.reset_fruit()
	model.toggle_helper()
	model.step(0.1)
	expect(model.snapshot() == ended, "settled state ignores gameplay commands")

	for mass_variant in 2:
		model.reset(false, mass_variant)
		configure(model, 340, 21)
		launch(model, 0.7)
		var shallow: Dictionary = model.snapshot()
		advance(model, 0.2)
		var shallow_moving: Dictionary = model.snapshot()
		model.reset(false, mass_variant)
		launch(model, 1.4)
		var deep: Dictionary = model.snapshot()
		expect(is_equal_approx(deep.fruit.vx, 2 * shallow.fruit.vx) and is_equal_approx(deep.fruit.vy, 2 * shallow.fruit.vy), "depth squared energy changes real launch speed linearly")
		expect(is_equal_approx(deep.fruit.vx * deep.fruit.vx + deep.fruit.vy * deep.fruit.vy, 1000000.0 / deep.fruit.mass), "mass inversely changes real kinetic speed squared")
		advance(model, 0.2)
		var moving: Dictionary = model.snapshot()
		expect(is_equal_approx(moving.fruit.vy, deep.fruit.vy + 180) and moving.fruit.y < deep.fruit.y and moving.fruit.x > deep.fruit.x, "real ballistic ascent with gravity and horizontal travel")
		expect(moving.fruit.y < shallow_moving.fruit.y and moving.fruit.x > shallow_moving.fruit.x, "deeper charge changes actual height and horizontal trajectory")
	model.reset()
	configure(model, 340, -21)
	launch(model, 0.7)
	expect(model.snapshot().fruit.vx < 0, "negative tilt changes actual horizontal velocity left")
	advance(model, 0.2)
	expect(model.snapshot().fruit.x < 340 and model.snapshot().fruit.y < 492, "negative tilt follows real leftward ballistic trajectory")
	var flying: Dictionary = model.snapshot()
	model.move_bed(1)
	model.adjust_tilt(1)
	expect(model.snapshot().fruit == flying.fruit and model.snapshot().bed.x == 380, "flight bed and tilt controls do not steer fruit")

	model.reset()
	configure(model, 340, 0)
	launch(model, 0.8)
	model.toggle_helper()
	expect(not model.snapshot().fruit.ready, "helper toggle cannot capture remote airborne fruit")
	var caught: Dictionary = wait_ready(model)
	expect(caught.fruit.ready and caught.mistakes == 0 and caught.fruit.vx == 0 and caught.fruit.vy == 0 and not caught.charging, "AI catches only real descending bed contact and waits")
	advance(model, 0.3)
	expect(model.snapshot().fruit.ready and not model.snapshot().charging, "AI never auto charges or launches")
	model.begin_charge()
	advance(model, 0.3)
	model.release_charge()
	expect(not model.snapshot().fruit.ready, "manual charge and release required after AI recovery")
	model.reset()
	configure(model, 340, 0)
	launch(model, 0.8)
	model.begin_charge()
	expect(not model.snapshot().charging and model.snapshot().charge_seconds == 0, "flight hold only prepares catch")
	caught = wait_ready(model)
	expect(caught.fruit.ready and caught.charging and caught.charge_seconds < 0.02, "held player input catches and begins charging only at actual contact")
	model.clear_input()
	expect(model.snapshot().fruit.ready and not model.snapshot().charging, "cancel after catch never launches")

	for assisted in [false, true]:
		model.reset(assisted)
		configure(model, 380, 21)
		launch(model, 1.28)
		wait_ready(model)
		expect(model.snapshot().delivered == 1, "checkpoint setup is real first delivery")
		configure(model, 180, -35)
		launch(model, 0.4)
		var missed: Dictionary = wait_ready(model)
		expect(missed.mistakes == 1 and missed.delivered == (1 if assisted else 0) and missed.bell_deliveries == 0 and missed.fruit.ready, "real miss clears ordinary progress or preserves assisted checkpoint")
		expect(missed.score == (80 if assisted else 0), "miss score reflects checkpoint and mistake")
		var elapsed: float = missed.elapsed
		model.reset_fruit()
		expect(model.snapshot().elapsed == elapsed and model.snapshot().mistakes == 1, "empty ready reset is inert for time and mistakes")
		launch(model, 0.2)
		model.reset_fruit()
		expect(model.snapshot().mistakes == 2 and model.snapshot().delivered == missed.delivered and model.snapshot().elapsed > elapsed, "flight X only resets current fruit and preserves completed deliveries")

	model.reset()
	configure(model, 500, 35)
	launch(model, 1.3)
	var touched := false
	for i in 360:
		model.step(1.0 / 120.0)
		var state: Dictionary = model.snapshot()
		touched = touched or state.fruit.bell_touched
		if state.mistakes > 0 or state.delivered > 0:
			break
	expect(touched and model.snapshot().mistakes == 1 and model.snapshot().bell_deliveries == 0 and not model.snapshot().fruit.bell_touched and not model.snapshot().devil, "real bell contact lost before delivery grants no devil progress")

func _geometry_and_deadline(model) -> void:
	var bell := {"x": 930.0, "y": 190.0, "radius": 32.0}
	expect(is_equal_approx(model._bell_fraction(Vector2(800, 250), Vector2(1060, 250), bell), 0.5), "swept segment tangent is true circle contact")
	expect(is_inf(model._bell_fraction(Vector2(800, 251), Vector2(1060, 251), bell)), "near tangent outside circle is not contact")
	expect(model._bell_fraction(Vector2(930, 190), Vector2(930, 190), bell) == 0, "stationary overlapping circle contact")
	expect(is_inf(model._bell_fraction(Vector2.ZERO, Vector2.ZERO, bell)), "stationary distant point misses")
	model.reset()
	model._s.fruit.merge({"x": 800.0, "y": 190.0, "vx": 100000.0, "vy": 0.0, "ready": false}, true)
	model.step(1.0 / 120.0)
	expect(model.snapshot().fruit.bell_touched and model.snapshot().fruit.vx < 0 and model.snapshot().delivered == 0, "fast swept flight contacts bell and reflects real right wall without duplicate delivery")
	model.reset()
	model._s.fruit.merge({"x": 870.0, "y": 190.0, "vx": 500.0, "vy": 0.0, "ready": false}, true)
	model.step(0.01)
	expect(model.snapshot().fruit.bell_touched and model.snapshot().fruit.vx == 500, "bell is sensor contact and never turns fruit")
	model.reset()
	model._s.fruit.merge({"x": 870.0, "y": 211.0, "vx": 0.0, "vy": 1000.0, "ready": false}, true)
	model.step(0.25)
	expect(model.snapshot().delivered == 1 and model.snapshot().fruit.ready, "one long step delivers only original fruit without replaying collision on next fruit")
	model.reset()
	model._s.fruit.merge({"x": 1059.0, "y": 300.0, "vx": 1000.0, "vy": 0.0, "ready": false}, true)
	model.step(0.005)
	expect(is_equal_approx(model.snapshot().fruit.vx, -850) and is_equal_approx(model.snapshot().fruit.x, 1056.6), "side-wall exact contact with0.85 reflection and remaining travel")
	model.reset()
	model._s.fruit.merge({"x": 340.0, "y": 61.0, "vx": 0.0, "vy": -1000.0, "ready": false}, true)
	model.step(0.005)
	expect(model.snapshot().fruit.y > 60 and model.snapshot().fruit.vy > 599 and model.snapshot().fruit.vy < 605, "top beam reflects vertical speed by0.60 with gravity")
	model.reset()
	model._s.fruit.merge({"x": 340.0, "y": 491.0, "vx": 20.0, "vy": 200.0, "ready": false}, true)
	model.step(0.005)
	expect(not model.snapshot().fruit.ready and model.snapshot().fruit.vx == 17 and model.snapshot().fruit.vy < -130, "unheld real bed collision retains0.65 vertical0.85 horizontal velocity")
	model.reset()
	model._s.fruit.merge({"x": 340.0, "y": 491.9, "vx": 0.0, "vy": 60.0, "ready": false}, true)
	model.step(0.005)
	expect(model.snapshot().fruit.ready, "low energy rebound settles naturally")
	for assisted in [false, true]:
		for offset in [-0.0001, 0.0001]:
			model.reset(assisted)
			var edge: float = model.snapshot().target.half_width - 28.0
			model._s.fruit.merge({"x": 870.0 + edge + offset, "y": 211.0, "vx": 0.0, "vy": 1000.0, "ready": false}, true)
			model.step(0.002)
			expect(model.snapshot().delivered == (1 if offset < 0 else 0), "platform support consistently subtracts fruit radius")
	model.reset()
	model._s.fruit.merge({"x": 870.0, "y": 213.0, "vx": 0.0, "vy": -1000.0, "ready": false}, true)
	model.step(0.002)
	expect(model.snapshot().delivered == 0, "ascending platform crossing cannot deliver")
	model.reset()
	model._s.fruit.merge({"x": 870.0, "y": 219.03125, "vx": 0.0, "vy": -112.5, "ready": false}, true)
	model._flight(model._s, 0.25, false)
	expect(model.snapshot().delivered == 0, "touching platform at apex from below is not descending crossing")
	for offset in [-0.0000001, -0.0000000001, 0.0, 0.0000000001, 0.0000001]:
		model.reset()
		var deadline_h := 0.005
		var contact_h: float = deadline_h + offset
		model._s.elapsed = 60.0 - deadline_h
		model._s.remaining = deadline_h
		model._s.delivered = 2
		model._s.participated = true
		model._s.target.y = 220.0
		model._s.fruit.merge({"x": 870.0, "y": 192.0 - 100.0 * contact_h - 450.0 * contact_h * contact_h, "vx": 0.0, "vy": 100.0, "ready": false}, true)
		model.step(0.01)
		var settled: Dictionary = model.snapshot()
		expect(settled.ended and settled.success == (offset <= 0) and settled.delivered == (3 if offset <= 0 else 2), "exact deadline contact bracket has no expanded success tolerance")
		expect(settled.ordinary_eligible and settled.elapsed <= 60, "deadline settlement eligible only after participation")
		print("JELLY_DEADLINE offset=%.12f success=%s elapsed=%.12f" % [offset, settled.success, settled.elapsed])
	model.reset()
	model.begin_charge()
	for i in 8000:
		model.step(0.01)
		if i % 1000 == 0:
			var state: Dictionary = model.snapshot()
			expect(state.trajectory.size() <= 24 and is_finite(state.fruit.x) and is_finite(state.fruit.y) and is_finite(state.fruit.vx) and is_finite(state.fruit.vy) and state.charge_seconds <= 1.4 and state.depth <= 1, "long held loop has finite fixed size state and bounded preview")
	expect(model.snapshot().ended and not model.snapshot().participated and not model.snapshot().ordinary_eligible, "long held charge times out without participation")

func _prediction(model) -> void:
	model.reset()
	configure(model, 380, 21)
	model.begin_charge()
	advance(model, 1.28)
	var before: Dictionary = model.snapshot()
	var again: Dictionary = model.snapshot()
	expect(before == again and before.trajectory.size() <= 24 and before.trajectory.size() >= 2, "prediction is bounded and cannot mutate charge physics or result")
	model.release_charge()
	var first: Vector2 = before.trajectory[0]
	expect(first.distance_to(Vector2(model.snapshot().fruit.x, model.snapshot().fruit.y)) < 0.0001, "preview begins from real depressed launch position")
	for i in range(1, mini(8, before.trajectory.size())):
		advance(model, 0.1)
		var state: Dictionary = model.snapshot()
		var predicted: Vector2 = before.trajectory[i]
		expect(predicted.distance_to(Vector2(state.fruit.x, state.fruit.y)) < 0.0001, "preview samples use same gravity ballistic and collision rules")
	var copy: Dictionary = model.snapshot()
	copy.trajectory[0] = Vector2.INF
	copy.target.y = -1
	copy.bell.radius = 100000
	expect(is_finite(model.snapshot().trajectory[0].x) and model.snapshot().target.y == 240 and model.snapshot().bell.radius == 32, "preview and nested physical snapshots are detached")
	model.reset()
	configure(model, 500, 35)
	model.begin_charge()
	advance(model, 1.4)
	before = model.snapshot()
	model.release_charge()
	for i in range(1, before.trajectory.size() - 1):
		advance(model, 0.1)
		var predicted: Vector2 = before.trajectory[i]
		var state: Dictionary = model.snapshot()
		expect(predicted.distance_to(Vector2(state.fruit.x, state.fruit.y)) < 0.0001, "preview and flight agree through side-wall reflection")

func _threshold_and_bell_checkpoint(model) -> void:
	model.reset()
	launch(model, 0.15)
	expect(model.snapshot().participated and not model.snapshot().fruit.ready, "minimum exact0.15-second held release launches")
	advance(model, 60)
	expect(model.snapshot().ended and not model.snapshot().success and model.snapshot().ordinary_eligible, "natural failed round eligible only after real launch")
	for assisted in [false, true]:
		model.reset(assisted)
		configure(model, 460, 21)
		launch(model, 1.28)
		var delivered: Dictionary = wait_ready(model)
		expect(delivered.delivered == 1 and delivered.bell_deliveries == 1 and not delivered.fruit.bell_touched, "bell-delivered checkpoint requires same real fruit and next fruit starts clean")
		model.reset_fruit()
		expect(model.snapshot().delivered == 1 and model.snapshot().bell_deliveries == 1 and model.snapshot().mistakes == 0, "empty current reset preserves completed bell checkpoint")
		configure(model, 180, -35)
		launch(model, 0.4)
		var missed: Dictionary = wait_ready(model)
		expect(missed.delivered == (1 if assisted else 0) and missed.bell_deliveries == (1 if assisted else 0) and missed.mistakes == 1 and not missed.fruit.bell_touched, "loss resets ordinary bell progress and retains assisted completed bell checkpoint")
	model.reset()
	configure(model, 500, 35)
	launch(model, 1.3)
	for i in 240:
		model.step(1.0 / 120.0)
		if model.snapshot().fruit.bell_touched:
			break
	expect(model.snapshot().fruit.bell_touched and model.snapshot().delivered == 0, "current-fruit reset setup uses actual airborne bell contact")
	model.reset_fruit()
	expect(model.snapshot().mistakes == 1 and not model.snapshot().fruit.bell_touched and model.snapshot().bell_deliveries == 0 and model.snapshot().fruit.ready, "X clears uncompleted same-fruit bell contact without delivery reward")
