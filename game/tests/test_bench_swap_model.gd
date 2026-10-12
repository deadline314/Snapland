extends SceneTree

const Model := preload("res://game/minigames/bench_swap_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_handcrafted_optimal_rounds()
	_test_rejected_input_retry_and_cached_snapshot()
	_test_assisted_hint_still_requires_player_action()
	if failures == 0:
		print("Bench swap model: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Bench swap model: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_handcrafted_optimal_rounds() -> void:
	var model = Model.new()
	model.reset(false, "dusk")
	var definitions: Array = Model.LEVELS
	var optimal_paths: Array = [
		[[0, 5]],
		[[0, 3], [3, 5]],
		[[0, 2], [2, 3], [3, 5]],
	]
	for level_index in definitions.size():
		var definition: Dictionary = definitions[level_index]
		var independently_computed: int = _test_shortest_solution(definition.initial, definition.rules)
		_expect(int(model.snapshot().optimal_moves) == independently_computed and independently_computed == level_index + 1, "level %d production BFS matches independent rule-based search at %d moves" % [level_index, independently_computed])
		_expect(int(definition.budget) > int(model.snapshot().optimal_moves), "ordinary move budget leaves room above the true minimum")
		_expect(_is_permutation(model.snapshot().seats), "level %d starts with each guest seated exactly once" % level_index)
		_expect(not _test_rules_satisfied(model.snapshot().seats, definition.rules), "level %d authored start visibly violates at least one displayed constraint" % level_index)
		_expect(not model.select_seat(-1) and not model.select_seat(Model.SEATS), "out-of-range seat %d is ignored" % level_index)
		var guard := 0
		for swap: Array in optimal_paths[level_index]:
			model.select_seat(int(swap[0]))
			model.select_seat(int(swap[1]))
			_settle_swap(model)
			guard += 1
		_expect(guard == independently_computed and _test_rules_satisfied(model.snapshot().ledger.back().order, definition.rules), "level %d reaches a rule-valid seating order in an optimal hand-authored sequence" % level_index)
		if level_index < definitions.size() - 1:
			_expect(int(model.snapshot().level) == level_index + 1 and int(model.snapshot().moves) == 0, "solved level advances to a fresh finite seating order")
	_expect(model.finished and model.success and model.devil, "three exact optimal orders produce an honest devil result")
	_expect(model.snapshot().ledger.size() == 6 and model.score == 750, "ledger and total score are calculated from actual swaps")
	var solved_rounds := 0
	for entry in model.snapshot().ledger:
		_expect(entry.valid, "every committed seat exchange is recorded as a valid player action")
		if entry.solved:
			solved_rounds += 1
			_expect(int(entry.moves) == int(entry.optimal_moves), "completed round records its actual optimal move count")
	_expect(solved_rounds == definitions.size(), "ledger has one actual solved result for every authored order")
	_expect(model.snapshot().time_phase == "dusk", "reset keeps the requested island light phase")
	_test_alternate_rule_valid_order()

func _test_rejected_input_retry_and_cached_snapshot() -> void:
	var model = Model.new()
	var stable: Dictionary = model.snapshot()
	var seats_ref: Array = stable.seats
	model.select_seat(1)
	_expect(stable.selected_seat == 1 and stable.seats == seats_ref, "snapshot object and seat array stay stable as selection changes")
	model.select_seat(1)
	_expect(model.snapshot().selected_seat == -1 and model.moves == 0, "reselecting the same marker cancels without a move")
	for _wrong_action in 3:
		model.select_seat(0)
		model.select_seat(2)
		_settle_swap(model)
	_expect(model.snapshot().level == 0 and model.moves == 0 and model.snapshot().ledger.size() == 3, "using the forgiving move budget without satisfying rules retries the level")
	_expect(not model.finished and not model.success and not model.devil and model.score == 0, "an unsolved swap never awards a win or guessed points")
	var before: float = model.elapsed
	model.step(9999.0)
	_expect(is_equal_approx(model.elapsed - before, Model.MAX_FRAME_DELTA), "large frame delta is bounded")
	_expect(model.snapshot() == stable, "snapshot dictionary identity remains stable through step and retry")
	model.reset(true, "invalid-phase")
	_expect(model.snapshot().time_phase == "noon" and model.snapshot().ledger.is_empty(), "retry resets outcome state and normalizes invalid lighting phase")

func _test_assisted_hint_still_requires_player_action() -> void:
	var model = Model.new()
	model.reset(true)
	model.select_seat(0)
	model.select_seat(2)
	var state: Dictionary = model.snapshot()
	_expect(state.hint_pair.size() == 2 and not state.finished and not state.success, "assistance marks a useful next swap but cannot resolve the game")
	var ledger_count: int = state.ledger.size()
	model.step(0.1)
	_expect(model.snapshot().ledger.size() == ledger_count and not model.finished and model.snapshot().hint_pair.size() == 2, "time leaves the useful hint visible but cannot make a move")
	_expect(not model.devil, "assisted play is never eligible for devil grade")

func _is_permutation(values: Array) -> bool:
	if values.size() != Model.SEATS: return false
	var sorted := values.duplicate()
	sorted.sort()
	return sorted == [0, 1, 2, 3, 4, 5]

func _test_alternate_rule_valid_order() -> void:
	var model = Model.new()
	model.reset(false)
	var alternative := [3, 5, 2, 1, 4, 0]
	_expect(_test_rules_satisfied(alternative, Model.LEVELS[0].rules), "independent rule evaluator confirms a non-authored alternate solution")
	var swaps: Array = [[0, 1], [1, 5], [0, 3]]
	for index in swaps.size():
		model.select_seat(swaps[index][0])
		model.select_seat(swaps[index][1])
		_settle_swap(model)
		if index < swaps.size() - 1:
			_expect(model.snapshot().level == 0 and not model.snapshot().ledger.back().solved, "alternate order is not accepted before all visible rules hold")
	_expect(model.snapshot().level == 1 and model.snapshot().ledger.back().solved and model.snapshot().ledger.back().order == alternative, "any alternate order satisfying visible rules is accepted and logged")
	_expect(model.snapshot().ledger.back().moves == 3 and model.snapshot().ledger.back().moves > model.snapshot().ledger.back().optimal_moves, "ordinary clear tolerates extra legal swaps while the perfect badge remains separate")
	var later_optimal_paths: Array = [[[0, 3], [3, 5]], [[0, 2], [2, 3], [3, 5]]]
	for path: Array in later_optimal_paths:
		for swap: Array in path:
			model.select_seat(swap[0])
			model.select_seat(swap[1])
			_settle_swap(model)
	_expect(model.finished and model.success and not model.devil, "a valid ordinary clear remains possible after a longer first solution without earning the optimal-only mark")

func _test_shortest_solution(start: Array, rules: Array) -> int:
	var queue: Array = [start.duplicate()]
	var distances := {_test_key(start): 0}
	var cursor := 0
	while cursor < queue.size():
		var order: Array = queue[cursor]
		cursor += 1
		var depth: int = distances[_test_key(order)]
		if _test_rules_satisfied(order, rules): return depth
		for a in Model.SEATS:
			for b in range(a + 1, Model.SEATS):
				var next: Array = order.duplicate()
				var hold: Variant = next[a]
				next[a] = next[b]
				next[b] = hold
				var key := _test_key(next)
				if not distances.has(key):
					distances[key] = depth + 1
					queue.append(next)
	return 999

func _test_rules_satisfied(order: Array, rules: Array) -> bool:
	if not _is_permutation(order): return false
	for rule in rules:
		var guest_a: int = order.find(int(rule.get("a", -1)))
		var guest_b: int = order.find(int(rule.get("b", -1)))
		match str(rule.kind):
			"seat": if order.find(int(rule.guest)) != int(rule.seat): return false
			"together": if absi(guest_a - guest_b) != 1: return false
			"apart": if absi(guest_a - guest_b) < 2: return false
	return true

func _test_key(order: Array) -> String:
	return ",".join(order.map(func(value: Variant) -> String: return str(value)))

func _settle_swap(model) -> void:
	model.step(0.25)
	model.step(0.05)
