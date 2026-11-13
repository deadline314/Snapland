extends SceneTree

const Model = preload("res://game/minigames/tide_sandbar_model.gd")
const Route = preload("res://game/tests/tide_sandbar_route.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func corridor(state: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in state.corridors:
		if row.id == id:
			return row
	return {}

func wait(commands, seconds: float, delta: float = 1.0 / 60.0) -> void:
	for i in roundi(seconds / delta):
		commands.step(delta)

func _run() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	expect(state.position == Vector2(-9, 0) and not state.ended and not state.ordinary_eligible, "fresh round starts at camp without eligibility")
	expect(is_equal_approx(state.tide, Model.TIDE_MEAN - Model.TIDE_AMPLITUDE) and not state.tide_paused, "round opens at low tide")
	expect(state.marked == ["camp"] and state.reefs_marked == 0 and state.score == 0, "camp is the implicit route root")
	for field in ["tide", "next_low_in", "next_safe", "corridors", "anchors", "markers", "rope", "helper_anchor", "standing_dry"]:
		expect(state.has(field), "snapshot exposes " + field)
	for delta in [NAN, INF, -1.0, 0.0]:
		model.step(delta)
	expect(model.snapshot().elapsed == 0.0, "invalid deltas are ignored")
	model.set_move(Vector2(INF, 0))
	model.step(0.5)
	expect(model.snapshot().position == Vector2(-9, 0), "non-finite move is ignored")
	model.set_move(Vector2(-1, 0))
	model.set_running(true)
	model.step(0.25); model.step(0.25); model.step(0.25); model.step(0.25)
	expect(model.snapshot().position.x >= -10.0 and model.snapshot().feedback.contains("深水"), "deep water off the sand blocks walking")
	model.step(10.0)
	expect(is_equal_approx(model.snapshot().elapsed, 1.5), "one long frame is capped")
	model.clear_input()
	var still: Vector2 = model.snapshot().position
	model.step(0.2)
	expect(model.snapshot().position == still and not model.snapshot().moving, "clear input stops movement")

	# Marking follows corridors from camp; unconnected reefs refuse.
	var secure = Route.ModelCommands.new()
	secure.interact()
	expect(secure.snapshot().feedback.contains("已有路標"), "camp already marked")
	expect(Route.walk_to(secure, "highland"), "walk to highland")
	secure.interact()
	expect(secure.snapshot().marked.has("highland"), "highland adjacent to camp marks")
	var outside := Route.ModelCommands.new()
	outside.set_move(Vector2(1, 0))
	for i in 4: outside.step(0.25)
	outside.interact()
	expect(outside.snapshot().markers.is_empty() and outside.snapshot().feedback.contains("中央"), "marking off an anchor is refused")

	# Secure-first: highland and dune before the first reef, all within the first tide.
	secure = Route.ModelCommands.new()
	expect(Route.solve(secure, Route.SECURE_FIRST), "secure-first route succeeds with real walking")
	state = secure.snapshot()
	expect(state.success and state.return_prepared and state.devil and state.score == 400 and state.falls == 0, "secure-first earns devil with full score")
	expect(state.ordinary_eligible and state.tide_cycle == 0 and state.elapsed < state.tide_period, "secure route finishes inside the first tide cycle")
	expect(state.markers.size() == 5 and state.markers[0].anchor_id == "highland" and state.markers[1].anchor_id == "dune", "marker ledger keeps actual order")

	# Far-first: quicker reef access, but no prepared return.
	var far = Route.ModelCommands.new()
	expect(Route.solve(far, Route.FAR_FIRST), "far-first route succeeds")
	var far_state: Dictionary = far.snapshot()
	expect(far_state.success and not far_state.return_prepared and not far_state.devil, "far-first is a real success without devil")
	expect(far_state.markers[1].anchor_id == "reef_far" and far_state.markers[1].elapsed < state.markers[3].elapsed, "far-first reaches the far reef earlier")
	expect(corridor(far_state, "shortcut").dry == false, "low shortcut is flooded by the far-first return")

	# The far shallow floods before a secure-first walker could cross it.
	var late = Route.ModelCommands.new()
	for leg in [["highland", true], ["dune", true]]:
		Route.walk_to(late, leg[0])
		late.interact()
	state = late.snapshot()
	var shallow := corridor(state, "far_shallow")
	expect(shallow.dry and shallow.flood_in < (9.0 - Model.ANCHOR_RADIUS) / Model.RUN_SPEED, "far shallow will flood before a secure walker can cross")
	Route.walk_to(late, "reef_far")
	expect(late.snapshot().falls >= 1, "crossing the flooding shallow causes a fall")

	# Walking-only crossing falls and the helper visibly pulls back to the marked dune.
	var wading = Route.ModelCommands.new()
	Route.walk_to(wading, "dune", false)
	wading.interact()
	var target: Vector2 = Route.anchor_position(wading.snapshot(), "reef_far")
	var fell := false
	var last: Vector2 = wading.snapshot().position
	var max_pull_step := 0.0
	var saw_throw := false
	for frame in 1200:
		var s: Dictionary = wading.snapshot()
		if s.rescuing:
			fell = true
			saw_throw = saw_throw or not s.rope.pulling
			max_pull_step = maxf(max_pull_step, s.position.distance_to(last))
		elif fell:
			break
		last = s.position
		wading.set_running(false)
		wading.set_move((target - s.position).normalized() if not fell else Vector2.ZERO)
		wading.step(1.0 / 60.0)
	state = wading.snapshot()
	expect(fell and state.falls == 1 and saw_throw, "slow crossing falls and the rope is thrown first")
	expect(max_pull_step <= Model.ROPE_PULL_SPEED / 60.0 + 0.001, "rope pull moves continuously, never teleports")
	expect(state.position.distance_to(Route.anchor_position(state, "dune")) < 0.01 and state.standing_dry, "pulled back to the nearest marked high point")
	expect(not state.success and not state.ended, "rope recovery is not a completion")

	# Without markers the helper anchors at camp; assistance uses any high point.
	var unmarked = Route.ModelCommands.new()
	Route.walk_to(unmarked, "dune")
	wait(unmarked, 15.0)
	unmarked.set_move(Vector2(-1, 0))
	for i in 120:
		unmarked.step(1.0 / 60.0)
		if unmarked.snapshot().rescuing: break
	expect(unmarked.snapshot().rescuing and unmarked.snapshot().rope.anchor_id == "camp", "unmarked fall is pulled to camp")
	var assisted = Route.ModelCommands.new(true)
	Route.walk_to(assisted, "dune")
	wait(assisted, 15.0)
	assisted.set_move(Vector2(-1, 0))
	for i in 120:
		assisted.step(1.0 / 60.0)
		if assisted.snapshot().rescuing: break
	expect(assisted.snapshot().rescuing and assisted.snapshot().rope.anchor_id == "dune", "assist keeps permanent safe crossing at the nearest high point")

	# Tide forecast, warnings and next safe high point.
	var tide = Route.ModelCommands.new()
	Route.walk_to(tide, "dune", false)
	tide.set_move(Vector2(-1, 0))
	wait(tide, 0.9)
	tide.clear_input()
	state = tide.snapshot()
	var shortcut := corridor(state, "shortcut")
	expect(shortcut.dry and shortcut.flood_in > 0.0 and absf(state.elapsed + shortcut.flood_in - 13.8) < 0.3, "shortcut flood time is predictable")
	expect(state.next_safe.id == "dune" and state.next_safe.safe, "next safe high point is the reachable dune")
	wait(tide, shortcut.flood_in - Model.WARNING_SECONDS + 0.2)
	expect(corridor(tide.snapshot(), "shortcut").warning, "outline warns before flooding")
	expect(corridor(tide.snapshot(), "ridge_camp").flood_in < 0.0, "highland ridge never floods")
	wait(tide, Model.WARNING_SECONDS)
	expect(tide.snapshot().rescuing or tide.snapshot().falls == 1, "standing in a flooding corridor falls")

	# Tide pause belongs to assistance only.
	var plain = Route.ModelCommands.new()
	plain.model.toggle_tide_pause()
	expect(not plain.snapshot().tide_paused and plain.snapshot().feedback.contains("輔助"), "unassisted cannot pause water")
	var helped = Route.ModelCommands.new(true)
	wait(helped, 2.0)
	helped.model.toggle_tide_pause()
	var frozen: float = helped.snapshot().tide
	wait(helped, 20.0)
	expect(helped.snapshot().tide_paused and helped.snapshot().tide == frozen and helped.snapshot().elapsed > 21.0, "assist pause freezes water while the round clock runs")
	expect(corridor(helped.snapshot(), "shortcut").flood_in < 0.0, "paused water forecasts no flooding")
	helped.model.toggle_tide_pause()
	expect(Route.solve(helped, Route.FAR_FIRST) and helped.snapshot().success, "assisted rounds still need every real step")

	# Timeout keeps truthful score and ordinary eligibility.
	var idle = Route.ModelCommands.new()
	Route.walk_to(idle, "dune")
	idle.interact()
	Route.walk_to(idle, "reef_north")
	idle.interact()
	wait(idle, Model.ROUND_SECONDS)
	state = idle.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible and state.score == 100 and not state.devil, "timeout is truthful with partial score")
	idle.interact()
	expect(idle.snapshot().markers.size() == 2, "ended round ignores input")

	# Devil only within the first tide; later-cycle success stays ordinary.
	var second = Route.ModelCommands.new()
	wait(second, 60.5)
	expect(Route.solve(second, Route.SECURE_FIRST) and second.snapshot().success and not second.snapshot().devil, "second-cycle success is not devil")

	# Variant layout and period.
	var variant = Route.ModelCommands.new(false, 1)
	state = variant.snapshot()
	expect(state.variant == 1 and state.tide_period == 52.0 and Route.anchor_position(state, "highland") == Vector2(-6, -4), "variant moves highland and shortens tide")
	expect(Route.solve(variant, Route.SECURE_FIRST) and variant.snapshot().devil, "variant secure route still earns devil")

	# Determinism and frame-rate independence.
	var again = Route.ModelCommands.new()
	Route.solve(again, Route.SECURE_FIRST)
	expect(again.snapshot().position == secure.snapshot().position and again.snapshot().markers == secure.snapshot().markers, "identical inputs reproduce")
	var slow = Route.ModelCommands.new()
	expect(Route.solve(slow, Route.SECURE_FIRST, true, 1.0 / 30.0) and slow.snapshot().devil, "30 Hz completes the same route")
	print("Tide sandbar: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
