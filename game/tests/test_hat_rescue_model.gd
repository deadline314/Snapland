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
	_test_paired_gusts_share_one_visible_wind()
	_test_securing_one_hat_per_pair_is_an_ordinary_choice()
	_test_calm_lead_in_shifts_the_whole_chart()
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

func _test_paired_gusts_share_one_visible_wind() -> void:
	var model = Model.new()
	model.reset()
	var max_airborne := 0
	var pair_ranks_seen := false
	var wind_consistent := true
	var response_shapes_differ := false
	var guard := 0
	while not model.finished and guard < 3200:
		model.step(0.02)
		var state: Dictionary = model.snapshot()
		max_airborne = maxi(max_airborne, int(state.airborne_count))
		if int(state.airborne_count) == 2:
			var ranks: Array = []
			for hat in state.hats:
				if hat.active and not hat.resolved: ranks.append(int(hat.airborne_rank))
			ranks.sort()
			pair_ranks_seen = pair_ranks_seen or ranks == [1, 2]
		var force := model.wind_at(model.elapsed)
		if absf(force) > 1.0 and signi(int(signf(force))) != int(state.wind_direction):
			wind_consistent = false
		if absf(force) > 1.0:
			var first := Model.HAT_GUST.find(model._gust_at(model.elapsed))
			if first >= 0 and not is_equal_approx(model._gust_force(first, model.elapsed), force * Model.HAT_WIND_RESPONSE[first]):
				wind_consistent = false
		guard += 1
	for index in Model.HAT_COUNT:
		if Model.HAT_WIND_RESPONSE[index] != Model.HAT_WIND_RESPONSE[0]: response_shapes_differ = true
	_expect(max_airborne == 2 and pair_ranks_seen, "paired gusts put two brims in the air together and rank them by time to the hand line")
	_expect(wind_consistent, "displayed wind direction and every hat's push come from one shared gust")
	_expect(response_shapes_differ and Model.HAT_WIND_RESPONSE[2] > Model.HAT_WIND_RESPONSE[5], "wide sun hat drifts farther than the canvas cap in the same gust")
	_expect(Model.HAT_GUST[2] == Model.HAT_GUST[3] and Model.HAT_GUST[4] == Model.HAT_GUST[5] and Model.WIND_DIRECTIONS[3] == Model.GUST_DIRECTIONS[Model.HAT_GUST[3]], "each pair leaves in one gust and its ledger wind matches that gust")

## A cautious player saves the first brim of each pair and lets the second fall.
func _test_securing_one_hat_per_pair_is_an_ordinary_choice() -> void:
	var model = Model.new()
	model.reset()
	var guard := 0
	while not model.finished and guard < 1900:
		var state: Dictionary = model.snapshot()
		var target := -1
		for index in Model.HAT_COUNT:
			var hat: Dictionary = state.hats[index]
			if hat.active and not hat.resolved and index != 3 and index != 5:
				target = index
				break
		if target >= 0:
			var hat: Dictionary = state.hats[target]
			_apply_digital_axis(model, float(hat.landing_x))
			if float(hat.eta) <= 0.30 and float(state.catch_window) <= 0.0:
				model.set_catch(true)
		else:
			model.set_axis(0.0)
		model.step(0.02)
		guard += 1
	var final: Dictionary = model.snapshot()
	_expect(final.finished and final.success and not final.devil, "securing one hat per pair still completes the ordinary rescue but not the devil chart")
	_expect(final.caught == 4 and final.misses == 2 and final.ledger[3].status == "miss" and final.ledger[5].status == "miss", "the skipped brims are recorded as real misses in chart order")
	_expect(final.best_combo < 6 and final.score < 816, "skipping a pair member breaks the centre streak bonus")

func _test_calm_lead_in_shifts_the_whole_chart() -> void:
	var model = Model.new()
	model.reset(false, "noon", 1.5)
	model.set_axis(1.0)
	model.step(0.2)
	model.step(0.2)
	model.step(0.2)
	model.step(0.2)
	model.step(0.2)
	model.step(0.2)
	model.step(0.2)
	var calm: Dictionary = model.snapshot()
	_expect(model.elapsed > 1.39 and not calm.hats[0].active and absf(model.wind_at(model.elapsed)) < 0.001 and model.player_x > 640.0, "during the lead-in the catcher moves freely while no hat or gust has started")
	_expect(float(calm.lead_in_left) > 0.0 and is_equal_approx(float(calm.next_spawn_time), 1.5), "the snapshot reports the remaining calm time and the shifted first launch")
	model.set_axis(0.0)
	model.step(0.2)
	_expect(model.snapshot().hats[0].active and float(model.snapshot().lead_in_left) == 0.0, "the first hat leaves its passenger exactly after the calm")
	var invalid = Model.new()
	invalid.reset(false, "noon", NAN)
	_expect(invalid.lead_in == 0.0, "a non-finite lead-in falls back to an immediate chart")
