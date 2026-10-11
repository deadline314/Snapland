extends SceneTree

const Model = preload("res://game/minigames/pipe_round_model.gd")
const FLOW_SECONDS := 1.15
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_authored_orders()
	_test_requires_every_target()
	_test_round_progress_and_flow_delay()
	_test_score_timeout_and_retry()
	_test_invalid_data_falls_back()
	_test_snapshot_and_network_cache()
	if failures == 0:
		print("PASS: pipe round model checks (%d checks)" % checks)
		quit(0)
	else:
		quit(1)

func _test_authored_orders() -> void:
	for index in range(Model.DEFAULT_ORDERS.size()):
		var order: Dictionary = Model.DEFAULT_ORDERS[index]
		var model = Model.new()
		model.reset([order, order, order])
		var start: Array = order.start_cells
		var solution: Array = order.solution_cells
		var turns := 0
		for cell in range(16):
			var rotated := int(start[cell])
			var needed := 0
			while rotated != int(solution[cell]) and needed < 4:
				rotated = ((rotated << 1) & 15) | (rotated >> 3)
				needed += 1
			_expect(rotated == int(solution[cell]), "order %d cell %d has a reachable witness mask" % [index + 1, cell])
			for _turn in range(needed):
				model.rotate(cell)
			turns += needed
		_expect(model.connected, "order %d connects every declared destination" % (index + 1))
		_expect(turns == int(order.turn_par), "order %d witness rotations match par" % (index + 1))
		_expect(model.snapshot().flow_edges.size() > 0, "order %d exposes real connected branch edges" % (index + 1))
		for route in order.witness_routes:
			_expect(_route_is_open(solution, route), "order %d witness route is reciprocal" % (index + 1))

func _test_requires_every_target() -> void:
	var order: Dictionary = Model.DEFAULT_ORDERS[1]
	var model = Model.new()
	model.reset([order, order, order])
	model.cells = _int_cells(order.solution_cells)
	model._rebuild_network_cache()
	model.cells[12] &= ~4
	model._rebuild_network_cache()
	_expect(not model._all_targets_reached(), "one powered flower bed cannot satisfy a two-bed order")
	model.cells = _int_cells(order.solution_cells)
	model._rebuild_network_cache()
	model.cells[0] &= ~1
	model._rebuild_network_cache()
	_expect(not model._all_targets_reached(), "source must have its outward port open")

func _test_round_progress_and_flow_delay() -> void:
	var order: Dictionary = Model.DEFAULT_ORDERS[0]
	var model = Model.new()
	model.reset([order, Model.DEFAULT_ORDERS[1], Model.DEFAULT_ORDERS[2]])
	_solve_current(model, order)
	_expect(model.connected and model.order_index == 0 and model.completed_beds == 0, "first connection starts flow but does not complete the bed early")
	model.step(FLOW_SECONDS - 0.01)
	_expect(model.order_index == 0 and model.completed_beds == 0 and not model.ended, "first order stays visible until the full water animation ends")
	model.step(0.02)
	_expect(model.order_index == 1 and model.completed_beds == 1 and not model.ended, "first order advances after the full water animation")
	_solve_current(model, Model.DEFAULT_ORDERS[1])
	model.step(FLOW_SECONDS + 0.01)
	_expect(model.order_index == 2 and model.completed_beds == 2 and not model.ended, "second order cannot finish the round")
	_solve_current(model, Model.DEFAULT_ORDERS[2])
	model.step(FLOW_SECONDS - 0.01)
	_expect(not model.ended and model.completed_beds == 2, "last order also waits through the full flow animation")
	model.step(0.02)
	_expect(model.ended and model.success and model.completed_beds == 3, "round succeeds only after the last flow completes")

func _test_score_timeout_and_retry() -> void:
	var model = Model.new()
	model.reset()
	_solve_current(model, Model.DEFAULT_ORDERS[0])
	model.step(FLOW_SECONDS + 0.01)
	var second: Dictionary = Model.DEFAULT_ORDERS[1]
	_solve_current(model, second)
	model.step(FLOW_SECONDS + 0.01)
	var third: Dictionary = Model.DEFAULT_ORDERS[2]
	_solve_current(model, third)
	var before_last_flow: Dictionary = model.snapshot()
	_expect(before_last_flow.score == maxi(0, 2000 - 20 * before_last_flow.total_turns), "score includes completed beds and all turn penalties")
	_expect(before_last_flow.order_turns == [4, 7, 8], "per-order turns retain authored witness counts")
	model.step(60.0)
	var timeout: Dictionary = model.snapshot()
	_expect(timeout.ended and timeout.timed_out and not timeout.success, "deadline ends an unfinished last flow as a failure")
	_expect(timeout.completed_beds == 2 and timeout.score == maxi(0, 2000 - 20 * timeout.total_turns), "timeout preserves completed beds and correct partial score")
	model.reset()
	var retry: Dictionary = model.snapshot()
	_expect(retry.order_index == 0 and retry.completed_beds == 0 and retry.total_turns == 0 and retry.elapsed == 0.0, "retry resets order, time, turns, and score")
	_expect(retry.cells == Model.DEFAULT_ORDERS[0].start_cells, "retry restores the fixed first board")

func _test_invalid_data_falls_back() -> void:
	var model = Model.new()
	model.reset([{"id":"broken"}, Model.DEFAULT_ORDERS[1], Model.DEFAULT_ORDERS[2]])
	var state: Dictionary = model.snapshot()
	_expect(state.order_count == 3 and state.order_id == "south_single", "invalid authored order data uses the complete safe fallback")

func _test_snapshot_and_network_cache() -> void:
	var model = Model.new()
	model.reset()
	var stable_snapshot: Dictionary = model.snapshot()
	var stable_cells: Array = stable_snapshot.cells
	var stable_edges: Array = stable_snapshot.flow_edges
	var network_revision := int(stable_snapshot.network_revision)
	var board_revision := int(stable_snapshot.board_revision)
	for _tick in range(8):
		model.step(0.05)
		var next: Dictionary = model.snapshot()
		_expect(is_same(next, stable_snapshot), "snapshot returns the same cached dictionary")
		_expect(is_same(next.cells, stable_cells) and is_same(next.flow_edges, stable_edges), "time-only steps reuse board and network arrays")
	_expect(is_equal_approx(stable_snapshot.elapsed, 0.4), "stable snapshot updates elapsed time in place")
	_expect(int(stable_snapshot.network_revision) == network_revision and int(stable_snapshot.board_revision) == board_revision, "time-only steps do not rebuild board reachability")
	model.rotate(0)
	_expect(is_same(model.snapshot(), stable_snapshot), "rotation retains snapshot identity")
	_expect(int(stable_snapshot.board_revision) > board_revision and int(stable_snapshot.network_revision) > network_revision, "rotation rebuilds revisions and network cache")

func _solve_current(model, order: Dictionary) -> void:
	for cell in range(16):
		var rotated := int(model.cells[cell])
		var needed := 0
		while rotated != int(order.solution_cells[cell]) and needed < 4:
			rotated = ((rotated << 1) & 15) | (rotated >> 3)
			needed += 1
		for _turn in range(needed):
			model.rotate(cell)

func _route_is_open(source_cells: Array, route: Array) -> bool:
	for index in range(route.size() - 1):
		var current := int(route[index])
		var next := int(route[index + 1])
		var dx := next % 4 - current % 4
		var dy := int(next / 4) - int(current / 4)
		var port := 0 if Vector2i(dx, dy) == Vector2i(0, -1) else 1 if dx == 1 else 2 if dy == 1 else 3
		var opposite := (port + 2) % 4
		if int(source_cells[current]) & [1, 2, 4, 8][port] == 0 or int(source_cells[next]) & [1, 2, 4, 8][opposite] == 0:
			return false
	return true

func _int_cells(source: Array) -> Array[int]:
	var result: Array[int] = []
	for value in source:
		result.append(int(value))
	return result

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error("Pipe round model check failed: " + message)
