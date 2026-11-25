extends SceneTree

const Model = preload("res://game/minigames/soup_tray_model.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_input_and_volume()
	_check_wrong_phase()
	_check_failed_crossing_and_retry()
	for layout in range(2):
		for assisted in [false, true]:
			_check_complete_route(layout, assisted)
	for failure in _failures:
		push_error(failure)
	print("Soup tray model: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("PASS: soup tray slosh, safe handoff and return crossing")
	quit(int(not _failures.is_empty()))


func _check_input_and_volume() -> void:
	var model := Model.new()
	var original := model.snapshot()
	model.step(NAN)
	model.step(INF)
	model.step(-1.0)
	model.set_lean(Vector2(NAN, INF))
	_expect(model.snapshot() == original, "non-finite and invalid inputs leave all simulation state unchanged")
	model.step(2.0)
	var unplayed := model.snapshot()
	_expect(is_equal_approx(unplayed.elapsed, 0.25) and not unplayed.engaged and not model.action(),
		"long frame is bounded and idle action cannot register play")
	_advance(model, ceili(Model.ROUND_SECONDS / Model.TICK))
	var idle := model.snapshot()
	_expect(idle.ended and not idle.ordinary_eligible and not idle.success and idle.score == 0 and idle.fill == 1.0,
		"idle timeout does not award a card, bowl or spill")
	model.reset(false, 0)
	model.set_walk(true)
	_advance(model, 26)
	var acceleration := model.snapshot()
	model.set_walk(false)
	model.set_brake(true)
	_advance(model, 18)
	var braking := model.snapshot()
	_expect(acceleration.acceleration.y > 0.0 and acceleration.liquid_slope.y < -0.045
		and braking.liquid_slope.y > 0.06 and _mass_ok(acceleration) and _mass_ok(braking),
		"actual acceleration and braking shift the same conserved liquid in opposite directions")
	_expect(not model.select_route(Model.CHANNEL), "a chosen path cannot switch under a moving tray")

	model.reset(false, 0)
	model.set_lean(Vector2.LEFT)
	_advance(model, 10)
	var below := model.snapshot()
	_expect(below.fill == 1.0 and absf(below.liquid_slope.x) * below.bowl.radius < below.freeboard,
		"tilting below the actual rim preserves every unit of soup")
	_advance(model, 27)
	var spill := model.snapshot()
	_expect(spill.spilled_volume > 0.0 and spill.liquid_volume < below.liquid_volume
		and spill.freeboard > below.freeboard and _mass_ok(spill), "actual overflowing crest drains into measured spill")
	_expect(not spill.participated and not spill.ordinary_eligible, "stationary tilting can spill but does not count as transporting")
	var weaker := Model.new()
	weaker.reset(true, 0)
	weaker.set_lean(Vector2.LEFT)
	_advance(weaker, 37)
	var assisted := weaker.snapshot()
	_expect(assisted.fill > spill.fill and assisted.assisted, "assist damps overshoot without replenishing liquid")

	model.reset(false, 1)
	var another := model.snapshot()
	_expect(original.paths.is_read_only() and original.gap.is_read_only() and original.bowl.is_read_only()
		and original.layout == 0 and another.layout == 1 and original.gap.near != another.gap.near
		and original.paths[Model.SAFE].size() > 3 and another.paths[Model.SAFE][7].x > 0.0
		and original.paths[Model.SAFE][7].x < 0.0, "historical geometry remains stable and layouts turn in opposite directions")


func _check_complete_route(layout: int, assisted: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "layout %d assist %s" % [layout, assisted]
	if not _expect(model.select_route(Model.CHANNEL) and _stage_at_lip(model), "real approach reaches the unsupported lip, " + label):
		return
	var lip := model.snapshot()
	_expect(not model.action() and model.snapshot().feedback.contains("停") and not lip.crossed,
		"flat tray at gap cannot register a launch, " + label)
	model.set_walk(true)
	model.set_brake(true)
	_advance(model, 14)
	model.clear_input()
	var stopped := model.snapshot()
	_expect(stopped.path_position <= lip.gap.near_progress + 0.0001 and stopped.bowl_position.y <= lip.gap.near.y + 0.0001
		and not stopped.crossed and not stopped.airborne, "ground movement cannot walk the bowl over missing support, " + label)
	_advance(model, 75)
	if not _expect(_arm_return(model), "opposed tilt exposes a real measured return phase, " + label):
		return
	var ready := model.snapshot()
	_expect(ready.liquid_slope.y < 0.0 and ready.liquid_rate.y > 0.0 and ready.launch_ready and not ready.crossing_proven,
		"return crest and velocity are physical; preview alone grants no crossing evidence")
	if not _expect(model.action(), "real slide releases the armed bowl, " + label):
		return
	if not _flight_result(model, ready, true, true):
		return
	var landed := model.snapshot()
	if not _expect(landed.landed_fill >= Model.PROOF_FILL and landed.crossing_proven and not landed.challenge_proven
		and not landed.devil, "only the real same-bowl safe catch qualifies before delivery, " + label):
		return
	if not _expect(_deliver(model, true), "recipient-ready controlled handoff delivers first bowl, " + label):
		return
	var first := model.snapshot()
	_expect(first.delivered == 1 and first.challenge_proven and not first.devil and first.bowl.id == 1
		and first.delivery_fills.size() == 1 and not first.crossing_proven, "next bowl cannot reuse a stale crossing")
	var profiles := [landed.bowl, first.bowl]
	if not _expect(model.select_route(Model.SAFE) and _deliver(model), "safe route delivers the second bowl, " + label):
		return
	profiles.append(model.snapshot().bowl)
	_expect(profiles[0].radius != profiles[1].radius and profiles[1].depth != profiles[2].depth
		and profiles[0].base_radius != profiles[2].base_radius, "three bowls have different physical rim/depth profiles")
	if not _expect(model.select_route(Model.SAFE) and _deliver(model), "safe route delivers the final bowl, " + label):
		return
	_expect(first.delivery_fills.size() == 1 and first.delivered == 1 and first.bowl.id == 1,
		"a retained snapshot and its history stay stable across subsequent bowls")
	var result := model.snapshot()
	_expect(result.ended and result.success and result.devil and result.ordinary_eligible and result.delivered == 3
		and result.score == 3 * Model.DELIVERY_POINTS + Model.CHALLENGE_POINTS and result.delivery_fills.size() == 3,
		"three actual deliveries and one qualifying catch are both required for 550, " + label)
	print("Soup route: ", [layout, assisted, snappedf(ready.elapsed, 0.01), landed.landed_fill, result.delivery_fills, result.score])


func _check_wrong_phase() -> void:
	for layout in range(2):
		var model := Model.new()
		model.reset(false, layout)
		if not _expect(model.select_route(Model.CHANNEL) and _stage_at_lip(model), "wrong-phase attempt stands on the real lip"):
			continue
		model.set_lean(Vector2.DOWN)
		for _tick in 30:
			model.step(Model.TICK)
			if model.snapshot().launch_ready:
				break
		var ready := model.snapshot()
		if not _expect(ready.launch_ready and not ready.return_ready and model.action(), "opposite phase can physically slide without earning return"):
			continue
		if not _flight_result(model, ready, true, false):
			continue
		if not _expect(_deliver(model) and _deliver(model) and _deliver(model), "all three bowls can finish after an unqualified launch"):
			continue
		var result := model.snapshot()
		_expect(result.success and result.ordinary_eligible and not result.devil and not result.challenge_proven
			and result.score == 3 * Model.DELIVERY_POINTS, "wrong phase never earns the physical return bonus")


func _check_failed_crossing_and_retry() -> void:
	for assisted in [false, true]:
		var model := Model.new()
		model.reset(assisted,1)
		if not _expect(_deliver(model) and model.select_route(Model.CHANNEL) and _stage_at_lip(model),
			"failed launch starts on the second bowl with one real delivery"):
			continue
		var before := model.snapshot()
		model.set_lean(Vector2.DOWN)
		_advance(model, 2)
		var weak := model.snapshot()
		if not _expect(weak.can_launch and not weak.launch_ready and model.action(), "weak actual launch is allowed to fail physically"):
			continue
		_advance(model, 40)
		var damaged := model.snapshot()
		_expect(not damaged.crossed and not damaged.crossing_proven and not damaged.devil and damaged.delivered == 1
			and damaged.score == Model.DELIVERY_POINTS, "an underpowered bowl never teleports across or grants extra reward")
		if assisted:
			_expect(damaged.stage == Model.DAMAGED and damaged.retry_ready and model.retry_bowl(),
				"assist exposes a deliberate retry only after real damage")
			var retried := model.snapshot()
			_expect(retried.bowl.id == 1 and retried.delivered == 1 and retried.delivery_fills == before.delivery_fills
				and retried.fill == 1.0 and retried.path_position == 0.0 and retried.elapsed > before.elapsed
				and retried.retries == 1 and retried.engaged and not retried.challenge_proven,
				"retry replaces only the current bowl while keeping clock, engagement and prior delivery")
			_expect(not model.retry_bowl() and _deliver(model) and _deliver(model) and model.snapshot().success,
				"saved first delivery combines with two genuine later deliveries")
		else:
			_expect(damaged.ended and damaged.ordinary_eligible and not damaged.success and not model.retry_bowl(),
				"standard mode ends the actual unsafe run while preserving participation")


func _stage_at_lip(model: RefCounted) -> bool:
	var near: float = model.snapshot().gap.near_progress
	if not _drive_carefully(model, near):
		return false
	_advance(model, 75)
	var current: Dictionary = model.snapshot()
	return current.stage == Model.GAP and current.velocity.length() <= 0.01 and _mass_ok(current)


func _arm_return(model: RefCounted) -> bool:
	model.set_lean(Vector2.UP)
	_advance(model, 8)
	model.set_lean(Vector2.DOWN)
	for _tick in 42:
		model.step(Model.TICK)
		if model.snapshot().return_ready:
			return true
	return false


func _flight_result(model: RefCounted, launch: Dictionary, crossed: bool, return_phase: bool) -> bool:
	var visibly_unsupported := false
	var consistent := true
	var integral := 0.0
	for _tick in 60:
		var current: Dictionary = model.snapshot()
		if not current.airborne:
			break
		if current.bowl_position.y > launch.gap.near.y + 0.05 and current.bowl_position.y < launch.gap.far.y - 0.05:
			visibly_unsupported = visibly_unsupported or current.bowl_height > 0.065
		consistent = consistent and _mass_ok(current) and current.bowl.id == launch.bowl.id
		integral = maxf(integral, current.bowl_position.y - launch.gap.near.y)
		model.step(Model.TICK)
	var landed: Dictionary = model.snapshot()
	return _expect(consistent and visibly_unsupported and integral > 0.46 and landed.crossed == crossed
		and landed.crossing_proven == return_phase and landed.launch_return == return_phase
		and landed.landed_position.y >= launch.gap.far.y and landed.landed_position.y <= launch.gap.landing_end.y
		and absf(landed.landed_position.x) <= launch.gap.half_width
		and landed.landed_position.distance_to(launch.projected_landing) < 0.0001
		and landed.bowl.id == launch.bowl.id and _mass_ok(landed),
		"same bowl visibly flies over real unsupported space and lands in the physical catcher")


func _deliver(model: RefCounted, prove_rejections := false) -> bool:
	var end_position: float = model.snapshot().path_length - 0.12
	if not _drive_carefully(model, end_position):
		return false
	var arrived: Dictionary = model.snapshot()
	if not _expect(arrived.stage == Model.HANDOFF and not arrived.ended and _mass_ok(arrived), "real grounded route reaches receiving table"):
		return false
	if prove_rejections:
		model.set_walk(true)
		_expect(not model.action() and model.snapshot().delivered == arrived.delivered,
			"E while the tray still intends to move cannot pass the bowl")
		model.clear_input()
	for _tick in 220:
		var current: Dictionary = model.snapshot()
		if current.handoff_ready:
			if prove_rejections:
				_expect(current.recipient_ready and current.speed <= Model.HANDOFF_SPEED and current.liquid_slope.length() <= 0.079,
					"readiness uses the actual settled liquid and the recipient's open hands")
				model.set_walk(true)
				_expect(not model.action(), "immediate walk input revokes prior handoff readiness")
				model.clear_input()
			return model.action()
		if current.ended:
			break
		model.step(Model.TICK)
	return false


func _drive_carefully(model: RefCounted, target: float) -> bool:
	for _tick in 1500:
		var state: Dictionary = model.snapshot()
		var distance: float = target - state.path_position
		if state.ended or state.stage == Model.DAMAGED:
			break
		if distance <= 0.006 and state.speed < 0.05:
			model.clear_input()
			return true
		var stop := float(state.speed) ** 2 / (2.0 * Model.BRAKE_DECEL)
		var slowing: bool = state.speed > 0.035 and distance < stop + 0.008
		model.set_brake(true)
		model.set_walk(not slowing)
		model.step(Model.TICK)
	model.clear_input()
	var stalled: Dictionary = model.snapshot()
	print("Soup route stalled: ", [stalled.stage, stalled.layout, stalled.assisted, stalled.path_position, target,
		stalled.velocity, stalled.fill, stalled.feedback])
	return false


func _advance(model: RefCounted, ticks: int) -> void:
	for _tick in ticks:
		model.step(Model.TICK)


func _mass_ok(state: Dictionary) -> bool:
	return (is_finite(state.liquid_volume) and state.liquid_volume > 0.0 and state.freeboard >= 0.0
		and absf(state.initial_volume - state.liquid_volume - state.spilled_volume) < 0.000001)


func _expect(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(message)
	return ok
