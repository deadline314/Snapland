extends SceneTree

const Model = preload("res://game/minigames/lighthouse_prism_model.gd")
const Route = preload("res://game/tests/lighthouse_prism_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func beacon(state: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in state.beacons:
		if row.id == id:
			return row
	return {}

## Independent exhaustive check over every orientation/shutter combination.
func enumerate(variant: int) -> Dictionary:
	var ids: Array = Model.element_ids()
	var kinds: Dictionary = {}
	for element in Model.ELEMENTS:
		kinds[element.id] = element.kind
	var counts := {"total": 0, "solutions": 0, "chain": 0, "split": 0, "devil": 0, "chain_hidden": 0}
	var states: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	var model = Model.new()
	while true:
		model.reset(false, variant)
		for i in ids.size():
			model._states[ids[i]] = states[i]
		model._retrace()
		var s: Dictionary = model.snapshot()
		counts.total += 1
		if s.main_lit == 3:
			counts.solutions += 1
			if s.splits == 0: counts.chain += 1
			if s.splits == 1: counts.split += 1
			if s.splits == 1 and s.hidden_lit: counts.devil += 1
		if s.splits == 0 and s.hidden_lit and s.main_lit == 3: counts.chain_hidden += 1
		var carry := ids.size() - 1
		while carry >= 0:
			states[carry] += 1
			if states[carry] < (2 if kinds[ids[carry]] == "shutter" else 4):
				break
			states[carry] = 0
			carry -= 1
		if carry < 0:
			break
	return counts

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(not state.ended and not state.ordinary_eligible and state.main_lit == 0 and not state.hidden_lit, "opening board lights nothing")
	expect(state.segments.size() == 1 and state.segments[0].exits, "lamp beam starts straight across the board")
	for field in ["segments", "beacons", "elements", "fog", "splits", "main_lit", "hidden_lit", "selected", "undo_available"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.step(10.0)
	expect(is_equal_approx(model.snapshot().elapsed, Model.MAX_FRAME_DELTA), "long frame is capped")

	# Rotation and reflection follow the actual beam.
	model.reset()
	model.select_element("m1")
	model.operate(1)
	state = model.snapshot()
	expect(Route.state_of(state, "m1") == 1 and state.segments.size() >= 2 and state.segments[1].from == Vector2i(8, 3) and state.segments[1].to == Vector2i(8, 6), "east mirror turned \\ sends the beam south")
	model.operate(-1)
	expect(Route.state_of(model.snapshot(), "m1") == 0 and model.snapshot().segments.size() == 1, "reverse rotation restores the straight beam")
	model.select_next(1)
	expect(model.snapshot().selected == "m2", "next selects the following element")
	model.select_next(-1)
	model.select_next(-1)
	expect(model.snapshot().selected == "p1", "previous wraps through the board order")
	model.select_element("g1")
	model.operate()
	expect(Route.state_of(model.snapshot(), "g1") == 1 and model.snapshot().feedback.contains("打開"), "shutter toggles open")

	# Two genuinely different routes, both from the same opening board.
	var chain = Route.ModelCommands.new()
	Route.arrange(chain, Route.CHAIN)
	state = chain.snapshot()
	expect(Route.matches(state, Route.CHAIN) and state.main_lit == 3 and state.splits == 0 and not state.hidden_lit, "series chain lights all three without splitting")
	var chained_far: float = beacon(state, "far").received
	var split = Route.ModelCommands.new()
	Route.arrange(split, Route.SPLIT)
	var split_state: Dictionary = split.snapshot()
	expect(split_state.main_lit == 3 and split_state.splits == 1 and not split_state.hidden_lit, "single split lights all three by a different path")
	expect(not is_equal_approx(beacon(split_state, "far").received, chained_far), "the two routes deliver different light to the far beacon")
	split.settle()
	split_state = split.snapshot()
	expect(split_state.ended and split_state.success and not split_state.devil and split_state.score == 300, "split route succeeds without the hidden side")
	chain.settle()
	expect(chain.snapshot().success and not chain.snapshot().devil, "chain route succeeds")

	# Devil: exactly one split and the hidden side beacon.
	var devil = Route.ModelCommands.new()
	Route.arrange(devil, Route.DEVIL)
	state = devil.snapshot()
	expect(state.main_lit == 3 and state.hidden_lit and state.splits == 1, "one split also reaches the hidden side beacon")
	devil.settle()
	expect(devil.snapshot().devil and devil.snapshot().score == 350 and devil.snapshot().ordinary_eligible, "devil route earns devil with full score")

	# Helper lock: a mirror feeding a lit beacon needs a confirming second press.
	var lock = Route.ModelCommands.new()
	Route.arrange(lock, Route.CHAIN)
	lock.model.select_element("m1")
	expect(lock.snapshot().elements[1].locked, "helper locks a mirror that feeds lit beacons")
	lock.model.operate(1)
	expect(Route.state_of(lock.snapshot(), "m1") == 1 and lock.snapshot().armed == "m1" and lock.snapshot().feedback.contains("鎖"), "first press only warns")
	lock.model.operate(1)
	expect(Route.state_of(lock.snapshot(), "m1") == 2 and lock.snapshot().main_lit < 3, "second press rotates deliberately")
	lock.model.select_element("m2")
	expect(lock.snapshot().armed == "", "changing selection clears the confirmation")

	# Settling early needs confirmation and stays truthful.
	var early = Route.ModelCommands.new()
	early.settle()
	expect(not early.snapshot().ended and early.snapshot().armed == "settle", "first early settle only warns")
	early.settle()
	state = early.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 0, "confirmed early settle ends truthfully")
	early.rotate()
	expect(state.moves == early.snapshot().moves, "ended round ignores input")

	# Timeout and assistance.
	var timed = Route.ModelCommands.new()
	for i in 600:
		timed.step(0.25)
	expect(timed.snapshot().ended and timed.snapshot().elapsed == Model.ROUND_SECONDS and not timed.snapshot().success, "standard round ends at the time limit")
	var assisted = Route.ModelCommands.new(true)
	for i in 1200:
		assisted.step(0.25)
	expect(not assisted.snapshot().ended and assisted.snapshot().remaining == INF, "assistance removes the time limit")
	var plain = Route.ModelCommands.new()
	plain.rotate()
	plain.undo()
	expect(Route.state_of(plain.snapshot(), "p1") == 1 and plain.snapshot().feedback.contains("輔助"), "undo refused without assistance")
	assisted.select(1)
	assisted.rotate()
	assisted.rotate()
	assisted.undo()
	expect(Route.state_of(assisted.snapshot(), "m1") == 1 and assisted.snapshot().undo_available, "assist undo restores the previous orientation")
	assisted.undo()
	assisted.undo()
	expect(Route.state_of(assisted.snapshot(), "m1") == 0 and assisted.snapshot().feedback.contains("沒有"), "undo history is bounded and empty-safe")
	Route.arrange(assisted, Route.DEVIL)
	assisted.settle()
	expect(assisted.snapshot().devil, "assisted devil remains eligible")

	# Fog variants thin crossing beams differently; every variant keeps both routes and devil.
	var fog_far: Array = []
	for variant in Model.FOG_LAYOUTS.size():
		var counts := enumerate(variant)
		expect(counts.total == 4 * 4 * 4 * 4 * 4 * 4 * 2 * 2, "exhaustive search covers every board state")
		expect(counts.chain >= 1 and counts.split >= 1 and counts.devil >= 1 and counts.chain_hidden == 0, "variant %d keeps chain, split and devil-only hidden routes" % variant)
		expect(counts.solutions < counts.total / 100, "variant %d is not trivially solved" % variant)
		var c = Route.ModelCommands.new(false, variant)
		Route.arrange(c, Route.SPLIT)
		fog_far.append(beacon(c.snapshot(), "far").received)
	expect(not is_equal_approx(fog_far[0], fog_far[1]), "fog layout changes the delivered light")
	var cycle = Route.ModelCommands.new(false, 3)
	expect(cycle.snapshot().variant == 1, "variant index wraps")
	print("Lighthouse prism: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
