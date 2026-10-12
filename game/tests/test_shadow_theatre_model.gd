extends SceneTree

const Model = preload("res://game/minigames/shadow_theatre_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_projection_uses_actual_point_and_vertices()
	_test_three_round_perfect_route_from_controls()
	_test_ordinary_miss_and_retry()
	_test_assist_keeps_real_input_and_blocks_devil()
	_test_bounded_time_and_invalid_values()
	if failures == 0:
		print("Shadow theatre model: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Shadow theatre model: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_projection_uses_actual_point_and_vertices() -> void:
	var model = Model.new()
	var source := Vector2(-0.2, -2.5)
	var one_vertex := PackedVector2Array([Vector2(0.4, 0.5)])
	var result: PackedVector2Array = model.projection_for(source, one_vertex)
	var factor := (Model.WALL_Z - source.y) / (Model.PUPPET_Z - source.y)
	var expected := Vector2(source.x, Model.LAMP_Y) + (one_vertex[0] - Vector2(source.x, Model.LAMP_Y)) * factor
	_expect(result.size() == 1 and result[0].distance_to(expected) < 0.00001, "wall point is the finite ray intersection from lamp through each fixed puppet vertex")
	var puppet: PackedVector2Array = model.puppet_vertices()
	var left := model.projection_for(Vector2(-0.5, -2.5), puppet)
	var right := model.projection_for(Vector2(0.5, -2.5), puppet)
	_expect(left[0].distance_to(right[0]) > 0.5, "changing actual lamp X changes the projected vertices")
	var near := model.projection_for(Vector2(0.0, -1.6), puppet)
	var far := model.projection_for(Vector2(0.0, -2.9), puppet)
	_expect(near[6].distance_to(near[7]) > far[6].distance_to(far[7]), "moving the point source toward the puppet enlarges its wall projection")
	_expect(not model.snapshot().cast_vertices.is_empty() and model.snapshot().cast_vertices.size() == puppet.size(), "snapshot exposes the full projected outline, not a shifted screen texture")

func _test_three_round_perfect_route_from_controls() -> void:
	var model = Model.new()
	model.reset(false, "dawn")
	var stable: Dictionary = model.snapshot()
	var ledger_ref: Array = stable.ledger
	var previous_limit := INF
	for round_index in 3:
		_drive_controls_to_solution(model)
		var before: float = float(model.snapshot().shape_error)
		var current_limit: float = float(model.snapshot().normal_error_limit)
		_expect(before <= float(model.snapshot().perfect_error_limit), "analog axis controls can physically align round %d within the precision threshold" % (round_index + 1))
		_expect(str(model.snapshot().difficulty) == ["easy", "steady", "precise"][round_index], "round %d exposes its rising difficulty" % (round_index + 1))
		_expect(current_limit < previous_limit, "ordinary shape tolerance tightens on each successive round")
		previous_limit = current_limit
		var result: Dictionary = model.capture()
		_expect(result.accepted and result.qualified and result.perfect, "shutter records a real precise alignment for round %d" % (round_index + 1))
	_expect(stable == model.snapshot() and stable.ledger == ledger_ref, "snapshot and round ledger retain stable identities through all captures")
	_expect(model.finished and model.success and model.devil and model.score > 0 and model.misses == 0, "three actual precise rounds earn ordinary and devil results")
	_expect(model.snapshot().time_of_day == "dawn" and model.snapshot().ledger.size() == 3, "run records selected time phase and all three rounds")

func _test_ordinary_miss_and_retry() -> void:
	var model = Model.new()
	model.reset(false)
	model.setlamp_target(model.round_solution(0) + Vector2(0.20, 0.0))
	var first := model.capture()
	_expect(first.accepted and not first.qualified and model.misses == 1 and model.round == 1, "misaligned shutter is a scored miss and advances only one real round")
	model.setlamp_target(model.round_solution(1))
	model.capture()
	model.setlamp_target(model.round_solution(2))
	model.capture()
	_expect(model.finished and model.success and not model.devil and model.qualified_count == 2, "ordinary result requires at least two of three qualifying shapes")
	model.reset(true, "night")
	_expect(not model.finished and model.round == 0 and model.elapsed == 0.0 and model.score == 0 and model.misses == 0, "retry resets clock, round, score, errors, and results")
	_expect(model.snapshot().time_of_day == "night" and model.snapshot().ledger[0].status == "waiting", "retry starts a clean ledger in the selected phase")

func _test_assist_keeps_real_input_and_blocks_devil() -> void:
	var regular := Model.new()
	regular.reset(false)
	regular.setlamp_target(regular.round_solution(0) + Vector2(0.19, 0.0))
	var regular_result := regular.capture()
	var assisted := Model.new()
	assisted.reset(true)
	assisted.setlamp_target(assisted.round_solution(0) + Vector2(0.19, 0.0))
	var assisted_result := assisted.capture()
	_expect(not regular_result.qualified and assisted_result.qualified and not assisted_result.perfect, "assistance widens shape error tolerance for the same player-moved lamp")
	_expect(float(assisted.snapshot().normal_error_limit) > float(regular.snapshot().normal_error_limit), "assisted snapshot exposes its wider geometric tolerance")
	for index in range(1, 3):
		_drive_controls_to_solution(assisted)
		assisted.capture()
	_expect(assisted.finished and assisted.success and not assisted.devil and assisted.assisted, "assisted real controls can complete but cannot unlock devil")

func _test_bounded_time_and_invalid_values() -> void:
	var model = Model.new()
	model.reset()
	var initial: Vector2 = model.lamp_position
	model.continuous_axis(INF, 0.0, 0.1)
	model.continuous_axis(1.0, 1.0, 1000.0)
	_expect(model.lamp_position.distance_to(initial) <= Model.LAMP_SPEED * Model.MAX_STEP + 0.0001, "control axes and pathological frame delta have a strict travel bound")
	model.setlamp_target(Vector2(NAN, INF))
	_expect(model.lamp_position.is_finite(), "non-finite lamp target is rejected")
	model.setlamp_target(Vector2(-100.0, 100.0))
	_expect(model.lamp_position == Vector2(Model.LAMP_X_MIN, Model.LAMP_Z_MAX), "lamp target clamps to the finite rail")
	model.step(NAN)
	model.step(1000.0)
	_expect(is_equal_approx(model.elapsed, Model.MAX_STEP) and not model.finished, "invalid and oversized frame deltas cannot skip the deadline")
	var clock := Model.new()
	clock.reset()
	var clock_guard := 0
	while not clock.finished and clock_guard < 700:
		clock.step(Model.MAX_STEP)
		clock_guard += 1
	_expect(clock.finished and clock.timed_out and not clock.success and not clock.devil and clock_guard >= 599, "60-second timeout fails safely without granting a result")
	var vertices: PackedVector2Array = model.puppet_vertices()
	var invalid_projection: PackedVector2Array = model.projection_for(Vector2(0.0, Model.PUPPET_Z), vertices)
	_expect(invalid_projection.size() == vertices.size() and not is_finite(invalid_projection[0].x), "near-zero light-to-puppet distance produces non-finite vertices that cannot score as a pass")

func _drive_controls_to_solution(model) -> void:
	var desired: Vector2 = model.round_solution(model.round)
	var step_size := Model.LAMP_SPEED * Model.MAX_STEP
	var guard := 0
	while model.lamp_position.distance_to(desired) > 0.00001 and guard < 100:
		var difference: Vector2 = desired - model.lamp_position
		model.continuous_axis(clampf(difference.x / step_size, -1.0, 1.0), clampf(difference.y / step_size, -1.0, 1.0), Model.MAX_STEP)
		guard += 1
