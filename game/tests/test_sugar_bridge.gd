extends SceneTree
const Model = preload("res://game/minigames/sugar_bridge_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func advance(model, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		model.step(1.0 / 60.0)

func select(model, id: int) -> void:
	for i in 4:
		if model.snapshot().selected == id:
			return
		model.select_next(1)

func place(model, id: int, position: Vector2) -> void:
	select(model, id)
	model.grab_selected()
	model.move_selected(position)
	model.release_selected()

func bridge(model, short: bool = false, band: int = 0) -> void:
	var anchors: Array = model.snapshot().anchors
	if short:
		place(model, 0, anchors[0])
		place(model, 1, anchors[1])
		place(model, 2, anchors[1])
		place(model, 3, anchors[2])
	else:
		place(model, band * 2, anchors[0])
		place(model, band * 2 + 1, anchors[2])

func deliver(model) -> void:
	for i in 3:
		model.load_ball()
		advance(model, 14.0)

func sling(model, band: int = 0) -> void:
	place(model, band * 2, Vector2.ZERO)
	select(model, band * 2 + 1)
	model.grab_selected()
	# Real ballistic arc through the hopper, preserving the same material.
	var state: Dictionary = model.snapshot()
	var flight := 0.9
	var gain: float = 1.0 - 4.0 * state.elasticity * flight
	var pull: Vector2 = (state.hopper + Vector2(0, 2.4 * flight * flight)) / gain
	model.move_selected(pull)
	model.release_selected()
	advance(model, 1.2)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.endpoints.size() == 4 and state.bands.size() == 2 and state.balls.size() == 3, "bounded material and transport pools")
	expect(not state.ordinary_eligible and state.score == 0, "idle cannot earn a card")
	for variant in 2:
		model.reset(false, variant)
		bridge(model)
		state = model.snapshot()
		expect(state.bands[0].capacity > state.weight and state.bands[0].capacity < state.weight * 2, "long bridge supports one ball in variant %d" % variant)
		model.load_ball()
		var start: Vector2 = model.snapshot().balls[0].position
		advance(model, 0.5)
		state = model.snapshot()
		expect(state.balls[0].state == "rolling" and state.balls[0].position.x > start.x and state.balls[0].position.x < state.anchors[2].x, "ball rolls continuously before delivery")
		advance(model, 14.0)
		for i in 2:
			model.load_ball()
			advance(model, 14.0)
		state = model.snapshot()
		expect(state.success and state.delivered == 3 and state.score == 400 and state.ordinary_eligible and not state.devil, "long route delivers all three in variant %d" % variant)
		model.reset(false, variant)
		bridge(model, true)
		for i in 3:
			model.load_ball()
		state = model.snapshot()
		expect(Vector2(state.balls[0].position).distance_to(state.balls[1].position) >= 0.4 and Vector2(state.balls[1].position).distance_to(state.balls[2].position) >= 0.4, "three real feed positions stay visibly separate before entering")
		expect(state.bands[0].load == 0, "left bank feed queue does not count as bridge load")
		advance(model, 1.1)
		expect(model.snapshot().bands[0].load > state.weight * 2 and not model.snapshot().bands[0].broken, "short bridge carries simultaneous three balls")
		state = model.snapshot()
		expect(Vector2(state.balls[0].position).distance_to(state.balls[1].position) > 0.28 and Vector2(state.balls[1].position).distance_to(state.balls[2].position) > 0.28, "three actually rolling balls remain visibly separated")
		var separated := true
		for sample in 28:
			advance(model, 0.5)
			state = model.snapshot()
			for first in 3:
				for second in range(first + 1, 3):
					if state.balls[first].state == "rolling" and state.balls[second].state == "rolling":
						separated = separated and Vector2(state.balls[first].position).distance_to(state.balls[second].position) > 0.28
		expect(separated, "rolling balls keep visible spacing across the whole short route")
		expect(model.snapshot().success and model.snapshot().breaks == 0, "short route succeeds in variant %d" % variant)
		model.reset(false, variant)
		sling(model)
		expect(model.snapshot().bands[0].hit and model.snapshot().bean.hit and not model.snapshot().devil, "actual projectile hits hopper before any qualification")
		bridge(model)
		deliver(model)
		expect(model.snapshot().devil and model.snapshot().score == 500, "post-hit same generation transports all three for devil")
	# Overload, actual falls, free recovery and no duplicate balls.
	model.reset()
	bridge(model)
	model.load_ball()
	model.load_ball()
	advance(model, 0.4)
	state = model.snapshot()
	expect(not state.bands[0].broken and is_equal_approx(state.bands[0].load, state.weight), "queued second ball cannot overload until it actually enters long bridge")
	advance(model, 1.6)
	state = model.snapshot()
	expect(state.breaks == 1 and state.falls == 2 and state.bands[0].broken, "simultaneous load breaks long material and drops both balls")
	select(model, 0)
	var generation: int = state.bands[0].generation
	model.recall_selected()
	expect(model.snapshot().bands[0].generation != generation and not model.snapshot().bands[0].broken, "recall renews material")
	bridge(model, true)
	for i in 4:
		model.load_ball()
	advance(model, 15.0)
	expect(model.snapshot().success and model.snapshot().delivered == 3 and model.snapshot().score == 340, "unused then fallen balls recover without duplication or lost score")
	model.reset()
	model.load_ball()
	advance(model, 2.0)
	expect(model.snapshot().falls == 1 and model.snapshot().delivered == 0, "disconnected loading genuinely falls")
	# A hit on a different strip, old traversal, and recycled material cannot qualify.
	model.reset()
	sling(model)
	bridge(model, false, 1)
	deliver(model)
	expect(model.snapshot().success and not model.snapshot().devil, "unused marked material cannot qualify")
	model.reset()
	sling(model)
	select(model, 0)
	model.recall_selected()
	bridge(model)
	deliver(model)
	expect(model.snapshot().success and not model.snapshot().devil, "recall clears hit identity")
	model.reset()
	bridge(model)
	model.load_ball()
	advance(model, 14.0)
	sling(model)
	bridge(model, false, 1)
	for i in 2:
		model.load_ball()
		advance(model, 14.0)
	expect(model.snapshot().success and not model.snapshot().devil, "pre-hit delivery over marked material cannot count as post-hit traversal")
	model.reset()
	sling(model)
	bridge(model)
	model.load_ball()
	advance(model, 14.0)
	select(model, 0)
	model.recall_selected()
	bridge(model, false, 1)
	for i in 2:
		model.load_ball()
		advance(model, 14.0)
	expect(model.snapshot().success and not model.snapshot().devil, "recall clears even a delivered marked generation")
	model.reset()
	bridge(model)
	model.load_ball()
	advance(model, 14.0)
	select(model, 0)
	model.toggle_pin()
	sling(model)
	bridge(model)
	for i in 2:
		model.load_ball()
		advance(model, 14.0)
	expect(model.snapshot().devil, "a real later delivery after the hit qualifies")
	# Boundary inputs, zero length, maximum extension and detached snapshots.
	model.reset()
	model.step(NAN)
	model.step(INF)
	model.step(-1.0)
	expect(model.snapshot().elapsed == 0, "invalid deltas do not advance")
	model.grab_selected()
	model.move_selected(Vector2(NAN, 0))
	model.move_selected(Vector2(INF, 0))
	expect(model.snapshot().endpoints[0].position == Vector2(-1, -1), "nonfinite motion ignored")
	model.clear_input()
	model.move_selected(Vector2.ZERO)
	expect(not model.snapshot().bean.active and model.snapshot().grabbed == -1 and model.snapshot().endpoints[0].position == Vector2(-1, -1), "cancel neither shoots nor moves")
	model.grab_selected()
	model.move_selected(Vector2(100, -100))
	expect(model.snapshot().endpoints[0].position == Vector2(12, -3), "valid motion clamps to work bounds")
	model.clear_input()
	select(model, 1)
	model.grab_selected()
	model.move_selected(Vector2.ZERO)
	model.clear_input()
	expect(model.snapshot().endpoints[1].pin == -1, "cancel near support does not pin")
	model.grab_selected()
	model.select_next(1)
	model.release_selected()
	expect(model.snapshot().grabbed == -1 and not model.snapshot().bean.active, "selection changes cancel single drag owner")
	model.reset()
	place(model, 0, Vector2.ZERO)
	place(model, 1, Vector2.ZERO)
	state = model.snapshot()
	expect(is_finite(state.bands[0].capacity) and is_finite(state.bands[0].sag), "zero length safe")
	state.endpoints[0].position = Vector2(50, 50)
	state.bands[0].points.clear()
	state.balls[0].traversed[0] = 42
	state.anchors.clear()
	expect(model.snapshot().anchors.size() == 3 and model.snapshot().endpoints[0].position == Vector2.ZERO and model.snapshot().balls[0].traversed[0] == -1, "nested snapshot data detached")
	select(model, 1)
	model.grab_selected()
	model.move_selected(Vector2(12, 5))
	advance(model, 0.1)
	expect(model.snapshot().bands[0].broken, "maximum extension breaks material")
	model.reset()
	bridge(model)
	model.load_ball()
	model.load_ball()
	model.load_ball()
	model.load_ball()
	expect(model.snapshot().balls.size() == 3 and model.snapshot().balls[0].state == "queued", "loading never duplicates an active feed ball")
	model.reset()
	var anchors: Array = model.snapshot().anchors
	place(model, 0, anchors[0])
	place(model, 1, anchors[1])
	model.load_ball()
	advance(model, 8.0)
	expect(model.snapshot().falls == 1 and model.snapshot().delivered == 0, "missing onward segment drops ball at central platform")
	model.reset()
	bridge(model)
	model.load_ball()
	advance(model, 0.4)
	select(model, 1)
	model.toggle_pin()
	advance(model, 0.1)
	expect(model.snapshot().falls == 1 and model.snapshot().balls[0].state == "falling", "disconnecting a loaded segment drops a real moving ball")
	# Helper never chooses a route, pins, fires or loads; assistance only changes tolerance.
	var held = Model.new()
	var free = Model.new()
	held.cycle_helper()
	var held_start: Vector2 = held.snapshot().endpoints[0].position
	advance(held, 0.5)
	advance(free, 0.5)
	expect(held.snapshot().endpoints[0].position == held_start and free.snapshot().endpoints[0].position.y < held_start.y - 0.3, "AI physically holds the specified endpoint while a free endpoint settles")
	held.cycle_helper()
	advance(held, 0.5)
	expect(held.snapshot().endpoints[0].position.y < held_start.y - 0.3, "disabling AI releases endpoint to gravity")
	free.grab_selected()
	free.move_selected(Vector2(0, 1))
	advance(free, 0.2)
	expect(free.snapshot().endpoints[0].position == Vector2(0, 1), "grabbed endpoint stays at explicit pointer position")
	free.clear_input()
	advance(free, 0.1)
	var settled: Vector2 = free.snapshot().endpoints[0].position
	expect(settled.y < 1.0 and settled.y > 0.9 and not free.snapshot().bean.active, "pointer motion resets velocity and cancel releases without shooting")
	free.grab_selected()
	free.move_selected(Vector2.ZERO)
	free.toggle_pin()
	advance(free, 2.0)
	expect(free.snapshot().endpoints[0].position == Vector2.ZERO and free.snapshot().endpoints[0].pin == 0, "pinned endpoint remains fixed after a fall")
	advance(held, 5.0)
	expect(held.snapshot().endpoints[0].position.y == Model.BOUNDS.position.y, "free endpoints stop at the bounded workbench catch")
	for assisted in [false, true]:
		model.reset(assisted, 1)
		model.cycle_helper()
		advance(model, 2.0)
		state = model.snapshot()
		expect(state.helper[0] and state.endpoints[0].pin == -1 and state.delivered == 0 and not state.bean.active and not state.ordinary_eligible, "helper holds only chosen endpoint")
		model.grab_selected()
		expect(not model.snapshot().helper[0], "taking held endpoint releases helper")
		model.clear_input()
		bridge(model, true)
		deliver(model)
		expect(model.snapshot().success, "assistance preserves real route")
	model.reset(true, 1)
	sling(model)
	bridge(model, true)
	deliver(model)
	expect(model.snapshot().devil, "assisted actual shot and transport keep devil eligibility")
	model.reset()
	model.step(99)
	expect(is_equal_approx(model.snapshot().elapsed, 0.25), "frame delta capped")
	for i in 610:
		model.step(0.25)
	expect(model.snapshot().ended and not model.snapshot().ordinary_eligible and not model.snapshot().success, "idle timeout is honest and unqualified")
	model.reset()
	model.load_ball()
	for i in 610:
		model.step(0.25)
	state = model.snapshot()
	expect(state.ended and state.ordinary_eligible and not state.success and state.score == 0, "participating timeout qualifies ordinary without false success")
	expect(state.balls.size() == 3 and state.bands.size() == 2 and state.preview.size() <= 31, "fixed pools survive timeout")
	print("Sugar bridge: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
