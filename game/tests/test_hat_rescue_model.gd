extends SceneTree

const Model = preload("res://game/minigames/hat_rescue_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_six_hat_center_route()
	_test_wrong_timing_and_misses()
	_test_edge_grade_and_center_offset()
	_test_assist_timeout_and_retry()
	_test_bounded_clock_and_stable_snapshot()
	if failures == 0:
		print("Hat rescue model: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Hat rescue model: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_six_hat_center_route() -> void:
	var model = Model.new()
	model.reset(false)
	_drive_all_hats(model, false)
	var state: Dictionary = model.snapshot()
	_expect(state.finished and state.success and state.devil, "real axis movement and timed catch presses rescue all six hats cleanly")
	_expect(state.caught == 6 and state.misses == 0 and state.center_catches == 6 and state.edge_catches == 0, "clean route records six center catches with no fake resolution")
	_expect(state.score >= 720 and state.best_combo == 6 and state.ledger.size() == 6, "center rescue score and sequential ledger preserve per-hat results")
	for entry in state.ledger:
		_expect(entry.status == "center" and entry.grade == "中心" and entry.points >= 120, "each ledger result matches actual contact and center award")

func _test_wrong_timing_and_misses() -> void:
	var model = Model.new()
	model.reset()
	model.step(0.20)
	model.set_target_x(float(model.snapshot().hats[0].landing_x))
	model.set_catch(true)
	model.set_catch(false)
	var guard := 0
	while model.misses == 0 and guard < 180:
		var hats: Array = model.snapshot().hats
		if hats[0].active:
			model.set_target_x(float(hats[0].landing_x))
		model.step(0.025)
		guard += 1
	_expect(model.misses == 1 and model.caught == 0, "an early catch pulse expires before contact and the hat becomes a real miss")
	_expect(model.snapshot().ledger[0].status == "miss" and model.snapshot().ledger[0].points == 0, "miss ledger records zero points exactly once")
	var no_press := Model.new()
	no_press.reset()
	_drive_to_resolution_without_catching(no_press, 0)
	_expect(no_press.misses == 1 and no_press.caught == 0, "being in the hat lane without a timed catch action does not count as a rescue")

func _test_edge_grade_and_center_offset() -> void:
	var center_probe := Model.new()
	center_probe.reset()
	_rescue_one(center_probe, 0.0)
	_expect(center_probe.center_catches == 1 and center_probe.edge_catches == 0, "overlapping the actual falling brim near hand center earns center grade")
	var edge_probe := Model.new()
	edge_probe.reset()
	_rescue_one(edge_probe, 34.0)
	_expect(edge_probe.edge_catches == 1 and edge_probe.center_catches == 0, "the same contact at a visible brim edge earns lower edge grade")
	_expect(edge_probe.score == 70 and edge_probe.snapshot().ledger[0].grade == "擦帽", "edge catch score and ledger explain the contact class")

func _test_assist_timeout_and_retry() -> void:
	var assisted := Model.new()
	assisted.reset(true, "dusk")
	_drive_all_hats(assisted, true, false)
	_expect(assisted.success and not assisted.devil and assisted.assisted, "assisted route can finish but is never eligible for devil result")
	var timeout := Model.new()
	timeout.reset()
	timeout.elapsed = Model.ROUND_SECONDS - 0.01
	timeout.step(0.025)
	_expect(timeout.finished and timeout.timed_out and not timeout.success, "safety deadline is enforced while catch-up work remains bounded")
	timeout.reset(true, "night")
	_expect(not timeout.finished and timeout.elapsed == 0.0 and timeout.caught == 0 and timeout.misses == 0 and timeout.score == 0, "retry clears all outcomes and opens a fresh assisted round")
	_expect(timeout.snapshot().time_phase == "night" and timeout.snapshot().ledger.size() == 6, "retry applies requested palette phase and rebuilds six ledger rows")
	var invalid := Model.new()
	invalid.set_axis(NAN)
	invalid.set_target_x(INF)
	invalid.set_catch(true)
	invalid.step(NAN)
	_expect(is_finite(invalid.player_x) and invalid.snapshot().catch_window <= Model.ASSIST_CATCH_WINDOW, "non-finite control and delta values fail closed without corrupting state")

func _test_bounded_clock_and_stable_snapshot() -> void:
	var model = Model.new()
	model.reset()
	var stable: Dictionary = model.snapshot()
	var hats_ref: Array = stable.hats
	var ledger_ref: Array = stable.ledger
	model.step(1000000.0)
	_expect(is_equal_approx(model.elapsed, Model.MAX_FRAME_DELTA), "pathological delta advances only bounded frame catch-up")
	_expect(model.snapshot() == stable and stable.hats == hats_ref and stable.ledger == ledger_ref, "snapshot dictionary and nested arrays keep stable identities")
	_expect(stable.elapsed == model.elapsed and stable.hats[0].active, "stable snapshot scalar and live hat entry update in place")

func _drive_all_hats(model, assisted: bool, keyboard_only: bool = true) -> void:
	var guard := 0
	while not model.finished and guard < 1900:
		var state: Dictionary = model.snapshot()
		var hats: Array = state.hats
		var index := -1
		for i in hats.size():
			if hats[i].active and not hats[i].resolved:
				index = i
				break
		if index >= 0:
			var hat: Dictionary = hats[index]
			var offset := 0.0
			if assisted:
				offset = 5.0
			if keyboard_only:
				_apply_digital_axis(model, float(hat.landing_x) + offset)
			else:
				model.set_target_x(float(hat.landing_x) + offset)
			if float(hat.eta) <= 0.30 and float(model.snapshot().catch_window) <= 0.0:
				model.set_catch(true)
		else:
			var upcoming := int(state.next_hat_index)
			if upcoming >= 0:
				if keyboard_only:
					_apply_digital_axis(model, float(state.next_spawn_x))
				else:
					model.set_target_x(float(state.next_spawn_x))
			else:
				model.set_axis(0.0)
		model.step(0.02)
		guard += 1
	_expect(guard < 1900, "actual inputs resolve the fixed six-hat chart before watchdog")

func _apply_digital_axis(model, target: float) -> void:
	var distance: float = target - model.player_x
	var braking_distance: float = model.player_velocity * model.player_velocity / (2.0 * Model.PLAYER_ACCEL) + 24.0
	var direction := 0.0
	if absf(model.player_velocity) > 24.0 and signf(distance) == signf(model.player_velocity) and absf(distance) <= braking_distance:
		direction = -signf(model.player_velocity)
	elif absf(distance) > 18.0:
		direction = signf(distance)
	model.set_axis(direction)

func _rescue_one(model, offset: float) -> void:
	var guard := 0
	while model._ledger[0].status == "waiting" and guard < 100:
		var hat: Dictionary = model.snapshot().hats[0]
		if hat.active:
			model.set_target_x(float(hat.landing_x) + offset)
			if float(hat.eta) <= 0.30 and float(model.snapshot().catch_window) <= 0.0:
				model.set_catch(true)
		model.step(0.02)
		guard += 1
	_expect(guard < 100, "single actual catch reaches its physical contact")

func _drive_to_resolution_without_catching(model, index: int) -> void:
	var guard := 0
	while model._ledger[index].status == "waiting" and guard < 160:
		var hats: Array = model.snapshot().hats
		if hats[index].active:
			model.set_target_x(float(hats[index].landing_x))
		model.step(0.02)
		guard += 1
	_expect(guard < 160, "falling hat crosses the hand plane within its expected flight duration")
