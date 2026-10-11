extends SceneTree

const Model = preload("res://game/minigames/kite_flight_model.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_full_route_and_center_grade()
	_test_miss_rescue_and_exhaustion()
	_test_boost_reel_tradeoff()
	_test_gust_forecast_and_force()
	_test_assist_timeout_and_invalid_input()
	_test_snapshot_cache()
	_test_crossing_interpolation()
	_test_tension_risk_and_reel_recovery()
	_test_aim_and_height_boundaries()
	if failures == 0:
		print("Kite flight model: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Kite flight model: %d focused check(s) failed" % failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_full_route_and_center_grade() -> void:
	var model = Model.new()
	model.reset()
	_drive_to_end(model)
	_check(model.won, "feedback-controlled flight with real steps and inputs clears all five rings")
	_check(model.center_hits == 5 and model.devil_won, "five center-plane crossings award devil qualification")
	_check(model.edge_hits == 0 and model.rescues_used == 0, "clean five-ring route has no edge hits or rescue")

func _drive_to_end(model) -> void:
	var guard := 0
	while not model.ended and guard < 4000:
		if model.ring_index < 5:
			var target: float = model.RING_HEIGHT[model.ring_index]
			model.set_aim(clampf((model.height - target) * 0.06 - model.vy * 0.012, -1.0, 1.0))
		else:
			model.set_aim(0.0)
		model.set_boost(guard % 95 < 24)
		model.step(0.025)
		guard += 1

func _test_miss_rescue_and_exhaustion() -> void:
	var model = Model.new()
	model.reset()
	model.height = 600.0
	model.x = model.RING_X[0] - 1.0
	model.step(0.025)
	_check(model.ring_index == 0 and model.misses == 1 and model.rescues_used == 1, "miss does not count as a passed ring and spends one rescue")
	_check(model.x < model.RING_X[0] and model.snapshot().reset_cooldown > 0.0, "miss rewinds before the current ring with a safety cooldown")
	for attempt in 2:
		model._reset_timer = 0.0
		model.height = 600.0
		model.x = model.RING_X[0] - 1.0
		model.step(0.025)
	_check(model.ended and not model.won and model.rescues_used == 2 and model.misses == 3, "third missed attempt ends after the two available rescues")

func _test_boost_reel_tradeoff() -> void:
	var model = Model.new()
	model.reset()
	model.set_boost(true)
	model.step(0.025)
	var boost_speed: float = model.speed
	var boost_tension: float = model.tension
	model.set_reel(true)
	_check(not model.boost and model.reel, "reel input cancels boost so both cannot be exploited together")
	model.step(0.025)
	_check(model.speed < boost_speed and model.tension < boost_tension, "reeling trades forward speed for lower line tension")
	var before_height: float = model.height
	model.step(0.25)
	_check(model.height >= before_height - 2.0, "reeling creates a mild controllable sink instead of teleporting altitude")

func _test_gust_forecast_and_force() -> void:
	var model = Model.new()
	model.reset()
	model.x = -2000.0
	while model.elapsed < model.GUST_PERIOD + 0.1:
		model.step(0.025)
	var gust_snapshot: Dictionary = model.snapshot()
	_check(gust_snapshot.actualwind > 0.0, "predicted gust produces force in the actualwind value")
	_check(gust_snapshot.forecast > 0.0 and gust_snapshot.forecast_seconds >= 1.0, "forecast exposes the matching force before it arrives")
	_check(gust_snapshot.eventmarkers.size() >= 8, "fixed gust markers remain available to the presentation layer")

func _test_assist_timeout_and_invalid_input() -> void:
	var assisted = Model.new()
	assisted.reset(true)
	_drive_to_end(assisted)
	_check(assisted.won and not assisted.devil_won, "assist can win ordinary completion but cannot grant devil qualification")
	var timed = Model.new()
	timed.reset()
	timed.elapsed = timed.ROUND_SECONDS - 0.01
	timed.step(0.1)
	_check(timed.ended and not timed.won, "round timeout ends with a failed ordinary result")
	var invalid = Model.new()
	invalid.reset()
	invalid.set_aim(NAN)
	invalid.step(INF)
	_check(is_finite(invalid.aim) and is_finite(invalid.elapsed) and invalid.elapsed <= invalid.MAX_DELTA, "non-finite input and unbounded delta fall back safely")

func _test_snapshot_cache() -> void:
	var model = Model.new()
	model.reset()
	var first: Dictionary = model.snapshot()
	var second: Dictionary = model.snapshot()
	_check(is_same(first, second), "unchanged snapshot returns the cached dictionary")
	var first_markers: Array = first.eventmarkers
	model.step(0.025)
	var third: Dictionary = model.snapshot()
	_check(is_same(first, third) and third.elapsed > 0.0, "snapshot dictionary is updated in place across steps")
	_check(is_same(first_markers, third.eventmarkers), "event marker array remains stable across frames")
	model.x = model.RING_X[0] - 1.0
	model.height = model.RING_HEIGHT[0]
	model.step(0.025)
	_check(is_same(first_markers, model.snapshot().eventmarkers) and first_markers.size() > 8, "ring outcomes append to the existing event marker array")

func _test_crossing_interpolation() -> void:
	var model = Model.new()
	model.reset()
	model.x = model.RING_X[0] - 2.0
	model.height = 380.0
	model.vy = 190.0
	model.step(0.05)
	_check(model.center_hits == 1 and model.edge_hits == 0, "crossing uses the interpolated plane height across a maximum-size step")

func _test_tension_risk_and_reel_recovery() -> void:
	var model = Model.new()
	model.reset()
	model.x = -2000.0
	model.elapsed = model.GUST_PERIOD + 0.55
	model.set_aim(1.0)
	model.set_boost(true)
	var guard := 0
	while not model.tension_warning and guard < 120:
		model.step(0.025)
		guard += 1
	_check(model.tension_warning and model.snapshot().tension_risk > 0.0, "boost under a forecast gust exposes accumulating line-strain risk")
	model.set_reel(true)
	for frame in 24:
		model.step(0.025)
	_check(not model.tension_warning and model.tension_risk_seconds == 0.0, "reeling lowers tension and clears the accumulated snap risk")
	model.set_reel(false)
	model.set_boost(true)
	model.elapsed = model.GUST_PERIOD
	guard = 0
	while model.line_snaps == 0 and guard < 160:
		model.step(0.025)
		guard += 1
	_check(model.line_snaps == 1 and model.rescues_used == 1 and model.mistakes > 0, "sustained high tension causes a real mistake and rescue reset")

func _test_aim_and_height_boundaries() -> void:
	var model = Model.new()
	model.reset()
	model.x = -2000.0
	model.set_aim(1.0)
	for frame in 120:
		model.step(0.025)
	_check(model.height < 380.0, "positive aim changes height through sustained lift")
	var height_after_positive_aim: float = model.height
	model.set_aim(-1.0)
	for frame in 80:
		model.step(0.025)
	_check(model.height > height_after_positive_aim, "negative aim reverses vertical travel")
	model.height = model.MIN_HEIGHT + 0.1
	model.vy = 205.0
	model.set_aim(1.0)
	model.step(0.05)
	_check(model.height == model.MIN_HEIGHT and model.vy == 0.0, "lower height boundary clears outward velocity")
	model.set_aim(-1.0)
	model.step(0.05)
	_check(model.height > model.MIN_HEIGHT, "reverse aim moves away from the lower boundary")
	model.height = model.MAX_HEIGHT - 0.1
	model.vy = -205.0
	model.set_aim(-1.0)
	model.step(0.05)
	_check(model.height == model.MAX_HEIGHT and model.vy == 0.0, "upper height boundary clears outward velocity")
	model.set_aim(1.0)
	model.step(0.05)
	_check(model.height < model.MAX_HEIGHT, "reverse aim moves away from the upper boundary")
