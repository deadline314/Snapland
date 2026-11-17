extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	expect(ResourceLoader.exists("res://game/minigames/syrup_flood_model.gd"), "syrup physical model must exist for public thermal/valve/material routes")
	if failures == 0:
		var model = load("res://game/minigames/syrup_flood_model.gd").new()
		_rules(model)
		for variant in 2:
			for assisted in [false, true]:
				for plug in [false, true]:
					model.reset(assisted, variant)
					var state := solve(model, plug)
					expect(state.success and state.ended and state.ordinary_eligible and state.filled_tanks == 3, "public operation route succeeds for each variant/assistance")
					expect(state.devil == plug and state.cold_plugged == plug and state.score == (500 if plug else 400), "real cold material alone distinguishes devil and score")
					_bounded(state)
					print("SYRUP_ROUTE variant=%d assisted=%s plug=%s success=%s elapsed=%.5f score=%d fills=%s temperatures=%s" % [variant, assisted, plug, state.success, state.elapsed, state.score, state.branches.map(func(b): return b.fill), state.branches.map(func(b): return b.temperature)])
	print("Syrup flood tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

static func advance(model, seconds: float) -> void:
	var left := seconds
	while left > 0.0000001:
		var delta := minf(left, 1.0 / 60.0)
		model.step(delta)
		left -= delta

# Reusable with a Session input adapter exposing the same public operations.
static func solve(model, plug: bool = false, close_valves: bool = true) -> Dictionary:
	for i in 3:
		model.select_branch(i)
		model.toggle_valve()
	if plug:
		model.select_branch(1)
		model.toggle_diversion()
	model.select_branch(0)
	model.toggle_heater()
	for frame in 4501:
		var state: Dictionary = model.snapshot()
		if state.ended:
			return state
		if close_valves:
			for i in 3:
				if state.branches[i].valve and state.branches[i].fill >= state.branches[i].capacity * 0.92:
					model.select_branch(i)
					model.toggle_valve()
		var target := -1
		for i in 3:
			if state.branches[i].fill < state.branches[i].capacity * 0.92 and not (i == 1 and state.diversion):
				target = i
				break
		if target != -1 and state.heater != target:
			model.select_branch(target)
			model.toggle_heater()
		model.step(1.0 / 60.0)
	return model.snapshot()

func _bounded(state: Dictionary) -> void:
	expect(state.elapsed >= 0 and state.elapsed <= 75 and state.remaining >= 0 and state.remaining <= 75, "finite bounded round time")
	expect(state.branches.size() == 3 and state.plug_amount >= 0 and state.plug_amount <= 12, "only three bounded branches and one bounded plug")
	for branch in state.branches:
		for key in ["temperature", "viscosity", "flow", "fill", "leaked"]:
			expect(is_finite(branch[key]) and branch[key] >= 0, "finite nonnegative public physical quantities")
		expect(branch.temperature <= 1 and branch.flow <= 10.0 / 0.85 and branch.fill <= branch.capacity + 10.0 / 0.85 / 60.0 and branch.leaked <= 75.0 * 10.0 / 0.85, "bounded heat flow volume and cumulative leakage")
	var expected := maxi(0, 100 * int(state.filled_tanks) + (100 if state.success else 0) + (100 if state.devil else 0) - 20 * int(state.mistakes))
	expect(state.score == expected, "score is exact public settlement sum")

func _rules(model) -> void:
	var initial: Dictionary = model.snapshot()
	for key in ["elapsed", "remaining", "score", "mistakes", "ended", "success", "devil", "ordinary_eligible", "participated", "assisted", "variant", "selected", "heater", "helper", "configuration_paused", "diversion", "cold_plugged", "plug_amount", "plug_required", "filled_tanks", "feedback", "branches"]:
		expect(initial.has(key), "frozen snapshot field " + key)
	expect(initial.remaining == 75 and initial.heater == -1 and initial.helper == -1 and not initial.participated, "initial timer and no active automatic systems")
	for i in 3:
		var b: Dictionary = initial.branches[i]
		expect(b.temperature == 0.18 and b.fill == 0 and not b.valve and not b.spoiled and b.target == b.capacity * 0.9, "initial physical state and actual-volume target")
		expect(b.length == [1.0, 1.35, 0.85][i] and b.heat_capacity == [1.0, 1.4, 0.8][i] and b.capacity == [100.0, 110.0, 90.0][i], "configuration A retains its frozen physical calibration")
	model.select_branch(-1)
	model.select_branch(3)
	model.select_branch(2147483647)
	expect(model.snapshot() == initial, "invalid selection indices do not change state")
	for delta in [NAN, INF, -INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot() == initial, "nonfinite nonpositive delta is inert")
	model.step(1.0e30)
	expect(is_equal_approx(model.snapshot().elapsed, 0.25), "huge delta capped to quarter second")
	var changed: Dictionary = model.snapshot()
	changed.branches[0].fill = 999999
	changed.branches.append({})
	expect(model.snapshot().branches.size() == 3 and model.snapshot().branches[0].fill == 0, "nested snapshot is isolated")
	model.reset(false, -1)
	expect(model.snapshot().variant == 1 and model.snapshot().branches[0].length == 1.3 and model.snapshot().branches[1].heat_capacity == 0.75, "variant wraps and changes real physical configuration")
	for i in 3:
		expect(model.snapshot().branches[i].length == [1.3, 0.85, 1.1][i] and model.snapshot().branches[i].heat_capacity == [1.6, 0.75, 1.2][i], "configuration B retains its frozen physical calibration")
	model.select_next(-1)
	expect(model.snapshot().selected == 2, "previous selection wraps")
	model.select_next(1)
	model.select_next(0)
	expect(model.snapshot().selected == 0, "next wraps and zero direction inert")
	model.toggle_diversion()
	expect(not model.snapshot().diversion and not model.snapshot().participated, "nonmiddle diversion inert and ineligible")
	model.toggle_configuration()
	model.toggle_helper()
	model.select_branch(2)
	model.toggle_helper()
	expect(model.snapshot().helper == 2, "helper designation replaces previous branch")
	model.toggle_helper()
	expect(model.snapshot().helper == -1, "reselecting helper cancels it")
	model.drain_selected()
	expect(not model.snapshot().participated, "empty drain and helper/selection/configuration never count participation")
	model.toggle_heater()
	model.toggle_valve()
	var paused: Dictionary = model.snapshot()
	advance(model, 2)
	expect(model.snapshot() == paused, "configuration stops heat material and time while allowing commands")
	model.clear_input()
	expect(model.snapshot() == paused, "clear_input leaves latched state untouched")
	model.toggle_configuration()
	advance(model, 1)
	expect(model.snapshot().elapsed > 0 and model.snapshot().branches[2].fill > 0 and model.snapshot().branches[2].temperature > 0.18, "resume advances actual configured pipe")
	for helper in [false, true]:
		model.reset()
		if helper:
			model.toggle_helper()
		advance(model, 75)
		var idle: Dictionary = model.snapshot()
		expect(idle.ended and not idle.success and not idle.ordinary_eligible and idle.score == 0, "idle/AI alone times out without eligibility or rewards")
		var ended: Dictionary = model.snapshot()
		model.toggle_heater()
		model.toggle_valve()
		model.toggle_diversion()
		model.toggle_helper()
		model.toggle_configuration()
		model.select_branch(1)
		model.select_next()
		model.drain_selected()
		model.clear_input()
		model.step(0.25)
		expect(model.snapshot() == ended, "ended state is idempotent for every public command")
	# Identical valve time separates temperature-driven volume and viscosity.
	model.reset()
	model.toggle_valve()
	advance(model, 5)
	var cold: Dictionary = model.snapshot().branches[0]
	model.reset()
	model.toggle_heater()
	advance(model, 5)
	model.toggle_valve()
	advance(model, 5)
	var hot: Dictionary = model.snapshot().branches[0]
	expect(hot.fill > cold.fill * 2 and hot.viscosity < cold.viscosity and hot.flow > cold.flow, "matched open-valve time: heat reduces viscosity and increases actual flow")
	model.reset(true)
	model.toggle_valve()
	advance(model, 5)
	expect(is_equal_approx(model.snapshot().branches[0].fill, cold.fill * 0.75), "assistance changes real transferred volume by exactly 0.75")
	model.reset()
	model.toggle_heater()
	model.step(1.0 / 60.0)
	expect(is_equal_approx(model.snapshot().branches[0].temperature, 0.185346666666667), "one real initial heating substep matches frozen thermal calibration")
	model.reset()
	model.toggle_heater()
	advance(model, 1)
	var heated: Dictionary = model.snapshot()
	expect(heated.branches[0].temperature > 0.18 and heated.branches[1].temperature < 0.18 and heated.branches[2].temperature < 0.18, "only the shared heater target warms")
	model.select_branch(2)
	model.toggle_heater()
	advance(model, 1)
	var rotated: Dictionary = model.snapshot()
	expect(rotated.heater == 2 and rotated.branches[0].temperature < heated.branches[0].temperature and rotated.branches[1].temperature <= 0.18, "rotating heater retains one cooling hot pipe and the cold reserve")
	model.toggle_heater()
	expect(model.snapshot().heater == -1, "selecting the active heater switches shared heat off")
	var variant_a_temperature: float = heated.branches[0].temperature
	model.reset(false, 1)
	model.toggle_heater()
	advance(model, 1)
	expect(model.snapshot().branches[0].temperature < variant_a_temperature, "larger heat capacity slows heating")
	model.reset()
	for i in [0, 2]:
		model.select_branch(i)
		model.toggle_valve()
	advance(model, 1)
	expect(model.snapshot().branches[2].fill > model.snapshot().branches[0].fill, "shorter equal-temperature pipe has less resistance")
	_plug_and_spill(model)
	_closure_and_cutoff(model)

func _plug_and_spill(model) -> void:
	model.reset()
	model.select_branch(1)
	model.toggle_diversion()
	advance(model, 1)
	expect(model.snapshot().plug_amount == 0 and not model.snapshot().cold_plugged, "diversion alone cannot create material")
	model.toggle_valve()
	advance(model, 2)
	var partial: Dictionary = model.snapshot()
	expect(partial.plug_amount > 0 and partial.plug_amount < 12 and partial.branches[1].fill == 0, "actual cold volume accumulates only at bypass")
	model.toggle_heater()
	advance(model, 5)
	expect(model.snapshot().plug_amount < partial.plug_amount and not model.snapshot().cold_plugged, "hot bypass melts partial cold material")
	advance(model, 10)
	expect(model.snapshot().plug_amount == 0 and not model.snapshot().cold_plugged and model.snapshot().branches[1].leaked > 12, "plenty of hot bypass volume cannot seal crack")
	model.reset()
	model.select_branch(1)
	model.toggle_diversion()
	model.toggle_valve()
	for frame in 1200:
		if model.snapshot().cold_plugged:
			break
		model.step(1.0 / 60.0)
	var plugged: Dictionary = model.snapshot()
	expect(plugged.cold_plugged and plugged.plug_amount == 12 and plugged.branches[1].leaked >= 12 and not plugged.diversion, "12 real cold units permanently seal and restore tank outlet")
	model.toggle_diversion()
	expect(not model.snapshot().diversion, "completed plug blocks bypass switch")
	advance(model, 1)
	expect(model.snapshot().branches[1].fill > 0 and model.snapshot().branches[1].leaked == plugged.branches[1].leaked, "sealed middle pipe no longer leaks")
	model.reset()
	model.toggle_heater()
	model.toggle_valve()
	for frame in 3600:
		if model.snapshot().branches[0].spoiled:
			break
		model.step(1.0 / 60.0)
	var spilled: Dictionary = model.snapshot()
	expect(spilled.branches[0].fill > 100 and spilled.branches[0].spoiled and not spilled.branches[0].valve and spilled.mistakes == 1, "overflow marks overline and closes its valve once")
	model.toggle_valve()
	advance(model, 1)
	expect(model.snapshot().mistakes == 1 and model.snapshot().branches[0].fill == spilled.branches[0].fill, "spoiled branch cannot reopen or count another spill")
	var before_drain: Dictionary = model.snapshot()
	model.drain_selected()
	var drained: Dictionary = model.snapshot()
	expect(drained.elapsed == before_drain.elapsed and drained.mistakes == 1 and drained.branches[0].fill == 0 and not drained.branches[0].spoiled, "free retry clears only selected volume/spoil, never time/mistakes")
	model.drain_selected()
	expect(model.snapshot().elapsed == drained.elapsed and model.snapshot().score == drained.score, "empty retry neither refunds time nor farms score")
	model.toggle_valve()
	advance(model, 1)
	expect(model.snapshot().branches[0].fill > 0 and not model.snapshot().branches[0].spoiled, "drained tank resumes genuine fill")
	while model.snapshot().branches[0].fill < 92 and not model.snapshot().ended:
		model.step(1.0 / 60.0)
	model.toggle_valve()
	var recovered: Dictionary = model.snapshot()
	expect(recovered.filled_tanks == 1 and recovered.score == 80, "refill score counts one actual tank minus the original mistake")
	model.select_branch(1)
	model.toggle_heater()
	model.toggle_valve()
	while not model.snapshot().branches[1].spoiled and not model.snapshot().ended:
		model.step(0.25)
	var second_spill: Dictionary = model.snapshot()
	model.drain_selected()
	var preserved: Dictionary = model.snapshot()
	expect(second_spill.mistakes == 2 and preserved.branches[0].fill == recovered.branches[0].fill and preserved.filled_tanks == 1 and preserved.score == 60, "spill retry preserves another completed tank and each event penalty")
	_bounded(preserved)
	model.reset()
	model.toggle_heater()
	model.toggle_valve()
	model.toggle_helper()
	advance(model, 30)
	var helped: Dictionary = model.snapshot()
	expect(helped.branches[0].fill >= 92 and helped.branches[0].fill < 93 and not helped.branches[0].valve and helped.branches[1].fill == 0, "AI only closes designated incoming tank at 92 percent")
	model.reset()
	model.select_branch(1)
	model.toggle_valve()
	advance(model, 2)
	var leaky: Dictionary = model.snapshot().branches[1]
	expect(leaky.leaked > 0 and is_equal_approx(leaky.fill / leaky.leaked, 0.65 / 0.35), "normal middle outlet splits 65 percent tank and 35 percent leak")

func _closure_and_cutoff(model) -> void:
	model.reset()
	# Fill in turn; preserve each band with closed valves, then reopen for one substep.
	for i in 3:
		model.select_branch(i)
		model.toggle_heater()
		model.toggle_valve()
		while model.snapshot().branches[i].fill < model.snapshot().branches[i].capacity * 0.92 and not model.snapshot().ended:
			model.step(1.0 / 60.0)
		if i < 2:
			model.toggle_valve()
	var open: Dictionary = model.snapshot()
	expect(open.filled_tanks == 3 and not open.ended and not open.success and open.branches[2].valve, "three in-band tanks with any valve open cannot win")
	model.toggle_configuration()
	model.toggle_valve()
	expect(not model.snapshot().ended and not model.snapshot().success, "closing final valve during configuration cannot award a result")
	model.toggle_configuration()
	model.step(1.0 / 60.0)
	expect(model.snapshot().success and model.snapshot().score == 400, "resuming with final valve closed settles actual three filled tanks")
	model.reset()
	model.toggle_valve()
	advance(model, 74.99)
	expect(not model.snapshot().ended, "unfilled round stays live until actual cutoff")
	model.step(0.25)
	var cutoff: Dictionary = model.snapshot()
	expect(cutoff.ended and cutoff.elapsed == 75 and cutoff.remaining == 0 and not cutoff.success and cutoff.ordinary_eligible, "final substep clips time and honestly fails unfilled round with participation")
	_bounded(cutoff)
	# Calibrate only a public opening time: straddle the helper's real final fill.
	var early := 60.0
	var late := 72.0
	for iteration in 18:
		var midpoint := (early + late) * 0.5
		var trial := _late_helper_route(model, midpoint)
		if trial.success:
			early = midpoint
		else:
			late = midpoint
	var on_cutoff := _late_helper_route(model, early)
	expect(on_cutoff.success and on_cutoff.elapsed == 75 and on_cutoff.remaining == 0, "AI closing in the clipped final substep succeeds before timeout")
	var after_cutoff := _late_helper_route(model, late)
	expect(not after_cutoff.success and after_cutoff.ended and after_cutoff.elapsed == 75, "slightly later public opening honestly misses the cutoff")
	print("SYRUP_CUTOFF opening_success=%.8f opening_failure=%.8f final_time=%.8f final_fill=%.8f" % [early, late, on_cutoff.elapsed, on_cutoff.branches[2].fill])

func _late_helper_route(model, opening: float) -> Dictionary:
	model.reset()
	for i in 2:
		model.select_branch(i)
		model.toggle_heater()
		model.toggle_valve()
		model.toggle_helper()
		while model.snapshot().branches[i].valve and not model.snapshot().ended:
			model.step(0.25)
	model.select_branch(2)
	model.toggle_heater()
	advance(model, maxf(0.0, opening - float(model.snapshot().elapsed)))
	model.toggle_helper()
	model.toggle_valve()
	while not model.snapshot().ended:
		model.step(0.25)
	return model.snapshot()
