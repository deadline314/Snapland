extends SceneTree

const Model = preload("res://game/minigames/banner_cart_model.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_controls_and_geometry()
	_roof_block_is_recoverable()
	_pedestrian_stop_and_wait()
	_timeout_and_pacing()
	_separate_banners_cannot_claim_pair()
	for layout in 2:
		for assisted in [false, true]:
			_ordinary_round(layout, assisted)
			_challenge_round(layout, assisted)
	print("Banner cart model: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("PASS: banner cart physical clearance, timing and delivery")
	quit(int(_failures > 0))


func _controls_and_geometry() -> void:
	var model := Model.new()
	var first := model.snapshot()
	_expect(first.banner_index == 0 and first.banners.size() == Model.BANNER_COUNT
		and first.banners[0].width < first.banners[1].width and first.banners[1].width < first.banners[2].width
		and first.banners[0].height < first.banners[1].height and first.banners[1].height < first.banners[2].height,
		"three distinct banner widths and heights")
	_expect(first.gates.size() == 5 and first.lanes.size() == 2 and first.clearance.gate_id == 4
		and first.carriage_max.z > first.cart.z + first.canvas_half_depth
		and first.carriage_min.z < first.cart.z - first.canvas_half_depth,
		"physical neck, roofs and distinct banner/carriage footprints")
	_expect(not model.choose_route(9) and model.choose_route(Model.DIRECT) and model.choose_route(Model.BYPASS),
		"explicit staged route choices reject an unknown route")
	model.set_drive_axis(NAN)
	model.set_lift_axis(INF)
	model.set_roll_axis(-INF)
	model.step(-1.0)
	model.step(NAN)
	model.step(Model.TICK)
	var invalid := model.snapshot()
	_expect(invalid.cart == first.cart and invalid.lift == first.lift and invalid.roll == first.roll and invalid.elapsed < 0.02,
		"invalid controls and elapsed time leave the pose intact")

	model.set_drive_axis(5.0)
	model.set_lift_axis(-1.0)
	model.set_roll_axis(1.0)
	model.step(Model.TICK)
	var moved := model.snapshot()
	_expect(moved.cart.z > 0.0 and moved.speed < 0.1 and moved.lift < first.lift and moved.lift > 0.0
		and moved.roll > 0.0 and moved.roll < 0.1, "forward, lift and roll change gradually on the same tick")
	_expect(moved.canvas[2].y > moved.canvas[3].y and is_equal_approx(moved.canvas[0].distance_to(moved.canvas[1]), moved.banners[0].width)
		and is_equal_approx(moved.canvas[1].distance_to(moved.canvas[2]), moved.banners[0].height),
		"positive roll raises the actual right edge while width and height remain rigid")
	_expect(moved.canvas[0].z == moved.cart.z and moved.pivot.y < first.pivot.y,
		"render coordinates reflect the same canvas plane and mast as movement")
	model.clear_input()
	var parked := model.snapshot()
	_ticks(model, 10)
	_expect(model.snapshot().cart == parked.cart and model.snapshot().speed == 0.0 and model.snapshot().roll == parked.roll,
		"external input clear stops held actions immediately")
	_expect(_go_to_z(model, 3.2) and model.snapshot().route_locked and not model.choose_route(Model.DIRECT),
		"entry motion locks the selected branch")
	var before := model.snapshot()
	model.set_brake(true)
	model.step(Model.TICK)
	var braking := model.snapshot()
	_expect(braking.braking and braking.speed > 0.0 and braking.speed < before.speed and braking.cart.z > before.cart.z,
		"brake decelerates a moving cart instead of teleporting it")
	_expect(_park(model) and model.snapshot().cart.z - before.cart.z < 0.55,
		"physical braking stops before the next obstacle")


func _roof_block_is_recoverable() -> void:
	var model := Model.new()
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.block_id == 4, 450),
		"upright raised banner physically reaches and contacts the bypass ceiling"):
		return
	var hit := model.snapshot()
	var roof: Dictionary = hit.gates[4]
	_expect(hit.block_kind == "roof" and hit.cart.z + hit.canvas_half_depth < roof.min.z and hit.speed == 0.0
		and hit.clearance.margin < 0.0 and hit.clearance.distance < 0.06 and hit.mistakes == 1,
		"swept contact stops the canvas before penetration and reports a negative clearance")
	_ticks(model, 20)
	_expect(model.snapshot().cart == hit.cart and model.snapshot().mistakes == hit.mistakes and model.snapshot().delivered == 0,
		"continued input cannot tunnel through a ceiling or count the same block every tick")
	_expect(_park(model) and _lower(model) and model.snapshot().clearance.margin > 0.0,
		"physical lowering changes which pose fits below the same roof")
	_expect(_deliver(model) and model.snapshot().delivered == 1 and model.snapshot().banner_index == 1
		and not model.snapshot().ended and not model.snapshot().challenge_proven,
		"recovering the clearance allows one real delivery without skipping remaining banners")


func _pedestrian_stop_and_wait() -> void:
	var model := Model.new()
	_expect(_lower(model), "lower for the bypass approach to the live crosswalk")
	var initial := model.snapshot()
	var crosswalk_boundary: float = initial.pedestrian.position.z - initial.pedestrian.half_depth - Model.CARRIAGE_HALF_DEPTH
	if not _expect(_go_to_z(model, crosswalk_boundary - 0.61) and _park(model)
		and _go_to_z(model, crosswalk_boundary - 0.075, 0.18) and _park(model), "bring the carriage to the front of the marked pedestrian gap"):
		return
	var waiting := model.snapshot()
	_expect(waiting.cart.z < crosswalk_boundary and waiting.cart.z > crosswalk_boundary - 0.12
		and waiting.lanes[1].points[5].x == waiting.cart.x, "actual carriage nose stops just outside the physical crosswalk")
	if not _expect(_until(model, func(state: Dictionary) -> bool: return absf(state.pedestrian.position.x - state.cart.x) < 0.075, 600),
		"the pedestrian actually walks into the carriage lane"):
		return
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.block_kind == "person", 35),
		"swinging through a crossing person is blocked by physical position"):
		return
	var blocked := model.snapshot()
	_expect(blocked.cart.z <= crosswalk_boundary + 0.00001 and blocked.speed == 0.0 and blocked.block_id == -1,
		"pedestrian collision uses the leading carriage, not only the rear canvas or a global timer")
	_expect(_park(model) and _until(model,
		func(state: Dictionary) -> bool: return absf(state.pedestrian.position.x - state.cart.x) > 1.28, 180),
		"waiting with the brake gives the walking person time to leave")
	var safe := model.snapshot()
	_expect(safe.cart == blocked.cart and safe.pedestrian.position != blocked.pedestrian.position
		and safe.pedestrian.velocity.x != 0.0, "waiting changes the real pedestrian position while the cart remains still")
	_expect(_deliver(model) and model.snapshot().delivered == 1, "valid passage remains after timing the crossing")


func _timeout_and_pacing() -> void:
	var idle := Model.new()
	idle.set_roll_axis(1.0)
	idle.set_brake(true)
	idle.step(2.0)
	_expect(is_equal_approx(idle.snapshot().elapsed, 0.25) and not idle.snapshot().engaged,
		"long delta is bounded and stationary controls alone are not participation")
	_finish_clock(idle)
	var ended := idle.snapshot()
	_expect(ended.ended and not ended.ordinary_eligible and not ended.success and not ended.devil
		and ended.score == 0 and ended.remaining == 0.0 and ended.elapsed == Model.ROUND_SECONDS,
		"idling, changing tilt and braking cannot earn a collection result or challenge")
	var engaged := Model.new()
	engaged.reset(true, 1)
	_expect(_go_to_z(engaged, 0.35) and _park(engaged), "advance the physical cart and then leave the clock running")
	_finish_clock(engaged)
	ended = engaged.snapshot()
	_expect(ended.ended and ended.ordinary_eligible and not ended.success and ended.score == 0
		and ended.elapsed == Model.ASSISTED_SECONDS and not ended.devil,
		"real movement qualifies an ordinary attempt, while the longer assisted timeout remains a truthful loss")
	engaged.reset(false, -1)
	var new_round := engaged.snapshot()
	_expect(new_round.layout == 1 and new_round.elapsed == 0.0 and new_round.cart == Vector3.ZERO
		and not new_round.engaged and not new_round.ended and new_round.mistakes == 0,
		"fresh layout reset clears stale input, elapsed, evidence and collisions")

	var whole := Model.new()
	var divided := Model.new()
	for model in [whole, divided]:
		model.set_drive_axis(0.6)
		model.set_lift_axis(0.13)
		model.set_roll_axis(-0.7)
	_ticks(whole, 90)
	for frame in 90:
		divided.step(Model.TICK * 0.4)
		divided.step(Model.TICK * 0.6)
	var a := whole.snapshot()
	var b := divided.snapshot()
	_expect(a.cart == b.cart and a.speed == b.speed and a.lift == b.lift and a.roll == b.roll
		and a.pedestrian.position == b.pedestrian.position and a.elapsed == b.elapsed,
		"fixed physics step gives identical world pose, acceleration and pedestrian under split frame deltas")


func _ordinary_round(layout: int, assisted: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "layout %d assisted %s" % [layout, assisted]
	var geometry := model.snapshot()
	_expect(geometry.gates[2].side == (1 if layout == 0 else -1)
		and geometry.gates[3].side == -geometry.gates[2].side
		and is_equal_approx(geometry.gates[4].min.y, 1.74 if layout == 0 else 1.71)
		and geometry.pedestrian.position.z != 0.0, "opposed shelves and differing bypass fit on " + label)
	for banner in Model.BANNER_COUNT:
		var route := Model.DIRECT if banner == 0 else Model.BYPASS
		if not _expect(model.choose_route(route) and _lower(model) and _deliver(model),
			"upright physical delivery %d on %s" % [banner, label]):
			print("Blocked ordinary route: ", model.snapshot())
			return
		_expect(model.snapshot().delivered == banner + 1 and model.snapshot().roof_passes == 0
			and not model.snapshot().challenge_proven, "upright or bypass delivery cannot record a sideways bonus")
	var outcome := model.snapshot()
	_expect(outcome.success and outcome.ended and outcome.ordinary_eligible and not outcome.devil
		and outcome.score == Model.BANNER_COUNT * Model.DELIVERY_POINTS,
		"all three intact is an ordinary win on both branches on " + label)


func _separate_banners_cannot_claim_pair() -> void:
	var model := Model.new()
	model.choose_route(Model.DIRECT)
	_lower(model)
	model.set_lift_axis(1.0)
	_ticks(model, 9)
	model.set_lift_axis(0.0)
	if not _expect(_go_to_z(model, 5.53) and _park(model) and _turn(model, -Model.MAX_ROLL),
		"the short banner can hold a raised and useful tilt before the first shelf"):
		return
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.roof_passes == 1, 150) and _park(model),
		"a deliberate raised tilt earns one actual shelf on the short banner"):
		return
	if not _expect(_lower(model) and _turn(model, 0.0) and _deliver(model)
		and model.snapshot().banner_index == 1 and model.snapshot().roof_passes == 0,
		"upright second-shelf delivery discards the short banner's unpaired proof"):
		return
	var second_shelf: Dictionary = model.snapshot().gates[3]
	if not _expect(model.choose_route(Model.DIRECT) and _lower(model) and _go_to_z(model, 7.12)
		and _park(model) and _turn(model, Model.MAX_ROLL),
		"the middle banner reaches the second shelf without useful tilt at the first"):
		return
	var before := model.snapshot()
	_expect(before.clearance.gate_id == 3 and before.clearance.margin > 0.0 and before.clearance.neutral_margin < 0.0,
		"the middle banner has a genuine complementary clearance against an upright collision")
	if not _expect(_go_to_z(model, second_shelf.max.z + Model.CANVAS_HALF_DEPTH + 0.05)
		and not model.snapshot().challenge_proven and _deliver(model),
		"exiting only the useful second shelf cannot inherit proof from another banner"):
		return
	_expect(_lower(model) and _deliver(model) and model.snapshot().success and not model.snapshot().devil
		and model.snapshot().score == Model.BANNER_COUNT * Model.DELIVERY_POINTS,
		"complementary tilted passages on different banners end with an ordinary result")


func _challenge_round(layout: int, assisted: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "layout %d assisted %s" % [layout, assisted]
	for banner in 2:
		if not _expect(model.choose_route(Model.BYPASS) and _lower(model) and _deliver(model)
			and model.snapshot().delivered == banner + 1, "safe preceding delivery %d on %s" % [banner, label]):
			return
	_expect(model.choose_route(Model.DIRECT) and _lower(model), "set the tall canvas on the real direct route on " + label)
	var gates: Array = model.snapshot().gates
	var first_side: float = gates[2].side
	var second_side: float = gates[3].side
	_expect(first_side == -second_side and _turn(model, first_side * Model.MAX_ROLL)
		and _turn(model, -first_side * Model.MAX_ROLL) and not model.snapshot().challenge_proven
		and model.snapshot().roof_passes == 0, "opposite rolls at staging never qualify on " + label)
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.block_kind == "wall", 350),
		"the laid-over tall canvas is too wide for the real narrow neck on " + label):
		print("Missing width block: ", model.snapshot())
		return
	var neck := model.snapshot()
	_expect(neck.cart.z + neck.canvas_half_depth < gates[0].min.z and neck.speed == 0.0,
		"real wide projection stops before entering either side wall")
	if not _expect(_park(model) and _turn(model, 0.0) and _go_to_z(model, 5.53) and _park(model),
		"recover upright, drive through the neck and brake in its free adjustment bay on " + label):
		return
	var before_first := model.snapshot()
	_expect(before_first.cart.z - before_first.canvas_half_depth > gates[0].max.z
		and before_first.cart.z + before_first.canvas_half_depth < gates[2].min.z
		and before_first.clearance.gate_id == 2 and before_first.clearance.neutral_margin < 0.0,
		"the tallest upright rectangle would hit the very next low roof")
	_expect(_turn(model, first_side * Model.MAX_ROLL) and model.snapshot().clearance.margin < 0.0,
		"wrong signed roll still intersects the next roof")
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.block_id == 2, 90),
		"wrong roll actually stops at the first shelf on " + label):
		return
	_expect(model.snapshot().roof_passes == 0 and not model.snapshot().challenge_proven
		and model.snapshot().cart.z + model.snapshot().canvas_half_depth < gates[2].min.z,
		"wrong-angle hit and waiting outside the first shelf do not count as proof")
	_expect(_park(model) and _turn(model, -first_side * Model.MAX_ROLL)
		and model.snapshot().clearance.margin > 0.0 and model.snapshot().clearance.neutral_margin < 0.0,
		"opposed tilt clears that same exact envelope while the corresponding upright rectangle still intersects")
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.roof_passes == 1, 150) and _park(model),
		"first useful angle qualifies only after the canvas fully exits the first roof on " + label):
		return
	var first_out := model.snapshot()
	_expect(first_out.cart.z - first_out.canvas_half_depth > gates[2].max.z and first_out.roof_passes == 1
		and not first_out.challenge_proven and not first_out.devil and first_out.delivered == 2,
		"one real qualifying shelf is insufficient for the paired challenge")
	_expect(_turn(model, -second_side * Model.MAX_ROLL) and model.snapshot().clearance.gate_id == 3
		and model.snapshot().clearance.margin > 0.0 and model.snapshot().clearance.neutral_margin < 0.0,
		"same canvas needs the reverse roll at the second asymmetric shelf")
	_drive(model)
	if not _expect(_until(model, func(state: Dictionary) -> bool: return state.roof_passes == 2, 180),
		"opposing useful angle exits the adjacent second roof on " + label):
		return
	var second_out := model.snapshot()
	_expect(second_out.cart.z - second_out.canvas_half_depth > gates[3].max.z
		and second_out.challenge_proven and not second_out.devil and not second_out.ended and second_out.score == 300,
		"physical paired evidence exists before the final delivery without prematurely awarding points or a result")
	if not _expect(_deliver(model), "safe exit and third actual delivery on " + label):
		return
	var outcome := model.snapshot()
	_expect(outcome.success and outcome.ended and outcome.ordinary_eligible and outcome.devil
		and outcome.delivered == Model.BANNER_COUNT and is_equal_approx(outcome.cart.z, Model.FINISH_Z)
		and outcome.score == Model.BANNER_COUNT * Model.DELIVERY_POINTS + Model.CHALLENGE_POINTS,
		"all three deliveries and a real alternating shelf pair earn the challenge on " + label)


func _drive(model: RefCounted, fraction: float = 1.0) -> void:
	model.set_brake(false)
	model.set_drive_axis(fraction)


func _go_to_z(model: RefCounted, depth: float, fraction: float = 1.0) -> bool:
	_drive(model, fraction)
	return _until(model, func(state: Dictionary) -> bool: return state.cart.z >= depth, 600)


func _park(model: RefCounted) -> bool:
	model.set_brake(true)
	var stopped := _until(model, func(state: Dictionary) -> bool: return state.speed == 0.0, 36)
	model.set_drive_axis(0.0)
	return stopped


func _lower(model: RefCounted) -> bool:
	model.set_lift_axis(-1.0)
	var lowered := _until(model, func(state: Dictionary) -> bool: return state.lift == 0.0, 48)
	model.set_lift_axis(0.0)
	return lowered


func _turn(model: RefCounted, target: float) -> bool:
	var initial: float = model.snapshot().roll
	model.set_roll_axis(signf(target - initial))
	var turned := _until(model, func(state: Dictionary) -> bool: return absf(state.roll - target) <= 0.012, 86)
	model.set_roll_axis(0.0)
	return turned


func _deliver(model: RefCounted) -> bool:
	var previous: int = model.snapshot().delivered
	_drive(model)
	var delivered := _until(model, func(state: Dictionary) -> bool: return state.delivered == previous + 1, 960)
	model.set_drive_axis(0.0)
	return delivered


func _until(model: RefCounted, predicate: Callable, deadline: int) -> bool:
	for tick in deadline:
		var state: Dictionary = model.snapshot()
		if predicate.call(state):
			return true
		if state.ended:
			return false
		model.step(Model.TICK)
	return bool(predicate.call(model.snapshot()))


func _ticks(model: RefCounted, count: int) -> void:
	for tick in count:
		model.step(Model.TICK)


func _finish_clock(model: RefCounted) -> void:
	for interval in 600:
		if model.snapshot().ended:
			return
		model.step(0.25)


func _expect(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", label)
	return condition
