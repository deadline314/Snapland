extends SceneTree

const Model = preload("res://game/minigames/rain_courier_model.gd")
var _errors: Array[String] = []

func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Rain courier model test requires an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	test_route_variants_and_umbrella()
	test_puddle_contact()
	test_bad_timing_and_retry()
	test_assistance_and_round_progress()
	test_fixed_step_and_expiration()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: rain courier routes, dry meals, timed handoff and umbrella catch")
	quit(int(not _errors.is_empty()))

func test_route_variants_and_umbrella() -> void:
	var first := Model.new()
	var second := Model.new()
	second.reset(false, 1)
	var start := first.snapshot()
	var alternate := second.snapshot()
	check(start.recipient != alternate.recipient and start.rain_direction == -alternate.rain_direction
		and start.open_segments != alternate.open_segments and start.route_paths != alternate.route_paths,
		"the second layout changes route geometry, rain, gaps and the first recipient")
	check(not first.choose_route(-1) and not first.slide(), "ready starts with bounded choice and cannot slide")
	move_to_handoff(first, Model.SHORT, false)
	var exposed := first.snapshot()
	move_to_handoff(second, Model.SHORT, true)
	var protected := second.snapshot()
	check(exposed.stage == Model.HANDOFF and protected.stage == Model.HANDOFF, "short paths reach real handoffs")
	check(exposed.wetness > exposed.wet_limit and protected.wetness == 0.0
		and protected.temperature > protected.warm_limit, "an umbrella keeps actual rain off the meal")
	check(exposed.elapsed < protected.elapsed, "an uncovered short path moves faster than one under umbrella")

	var covered := Model.new()
	move_to_handoff(covered, Model.COVERED, false)
	var sheltered := covered.snapshot()
	check(sheltered.route_length > exposed.route_length and sheltered.elapsed > exposed.elapsed,
		"the sheltered detour has a physically longer path")
	check(sheltered.temperature > exposed.temperature and sheltered.wetness < exposed.wetness,
		"the canopy reduces rain exposure and slows cooling")
	var covered_path: PackedVector2Array = sheltered.route_paths[Model.COVERED]
	check(sheltered.position.is_equal_approx(covered_path[-1]), "handoff starts at the chosen route endpoint")

func test_puddle_contact() -> void:
	var bridged := Model.new()
	move_to_handoff(bridged, Model.SHORT, true)
	wait_window(bridged, true)
	bridged.set_umbrella(false)
	check(bridged.slide(), "a box may be released with a closed umbrella")
	var puddle_start: float = bridged.snapshot().puddle_span.x
	while bridged.snapshot().slide_progress < puddle_start - 0.04:
		bridged.step(Model.TICK)
	bridged.set_umbrella(true)
	check(bridged.snapshot().puddle_protected, "opening over the upcoming puddle protects the moving box")
	advance(bridged, 30)
	check(bridged.snapshot().delivered == 1 and bridged.snapshot().umbrella_catches == 1,
		"the real umbrella contact duration supplies a successful puddle catch")

	var missed := Model.new()
	move_to_handoff(missed, Model.SHORT, true)
	wait_window(missed, true)
	check(missed.slide(), "comparison releases through the same receive window")
	missed.set_umbrella(false)
	advance(missed, 22)
	var moisture: float = missed.snapshot().wetness
	missed.set_umbrella(true)
	advance(missed, 8)
	check(moisture > 0.0 and missed.snapshot().delivered == 1 and missed.snapshot().umbrella_catches == 0,
		"opening after puddle contact cannot erase moisture or award the catch")

func test_bad_timing_and_retry() -> void:
	var model := Model.new()
	move_to_handoff(model, Model.SHORT, true)
	wait_window(model, true)
	model.slide()
	advance(model, 30)
	check(model.snapshot().delivered == 1, "first box is secured before the next attempt")
	move_to_handoff(model, Model.SHORT, true)
	wait_window(model, false)
	check(model.slide(), "out-of-window release is an actual attempt")
	advance(model, 30)
	var rejected := model.snapshot()
	check(rejected.stage == Model.READY and rejected.delivered == 1 and rejected.mistakes == 1
		and rejected.message.contains("沒接穩"), "timing failure replaces only the current meal")
	check(model.pickup() and model.retry_order(), "current meal can be exchanged immediately")
	check(model.snapshot().delivered == 1 and model.snapshot().mistakes == 2,
		"manual retry preserves accepted deliveries and records the attempt")
	move_to_handoff(model, Model.SHORT, false)
	wait_window(model, true)
	model.slide()
	advance(model, 30)
	check(model.snapshot().stage == Model.READY and model.snapshot().message.contains("淋濕"),
		"a saturated box is rejected even when its slide would otherwise arrive on time")

func test_assistance_and_round_progress() -> void:
	for layout in 2:
		var ordinary := Model.new()
		ordinary.reset(false, layout)
		for order in Model.ORDER_COUNT:
			move_to_handoff(ordinary, Model.SHORT if order % 2 == 0 else Model.COVERED, true)
			wait_window(ordinary, true)
			ordinary.set_umbrella(false)
			check(ordinary.slide(), "each order needs an explicit slide")
			advance(ordinary, 30)
		var result := ordinary.result()
		check(result.success and not result.devil and result.ordinary_eligible and result.score == 450,
			"alternating routes gives three dry ordinary deliveries in each layout")

	var assisted := Model.new()
	assisted.reset(true, 1)
	advance(assisted, 61)
	check(assisted.snapshot().stage == Model.READY and assisted.snapshot().route == Model.COVERED,
		"assistant favours canopy and waits for the player's pickup")
	check(assisted.pickup(), "assisted player picks up the first box")
	advance(assisted, 60)
	check(assisted.snapshot().distance == 0.0, "assistant does not move a box without the player")
	assisted.hold(true)
	advance(assisted, 27)
	assisted.clear_input()
	var stopped: float = assisted.snapshot().distance
	advance(assisted, 30)
	check(is_equal_approx(assisted.snapshot().distance, stopped) and not assisted.snapshot().walking,
		"clearing input stops movement until a fresh command")
	finish_walk(assisted)
	advance(assisted, 120)
	check(assisted.snapshot().stage == Model.HANDOFF and assisted.snapshot().delivered == 0,
		"assistant waits for the player's slide as the handoff cycles")
	wait_window(assisted, true)
	assisted.set_umbrella(true)
	assisted.slide()
	advance(assisted, 30)
	for order in range(1, Model.ORDER_COUNT):
		move_to_handoff(assisted, Model.COVERED, false)
		wait_window(assisted, true)
		assisted.slide()
		advance(assisted, 30)
	var result := assisted.result()
	check(result.success and result.devil and result.umbrella_catches == 1 and result.score == 550,
		"assisted players can complete and earn the optional puddle catch through manual input")

func test_fixed_step_and_expiration() -> void:
	var steady := Model.new()
	var grouped := Model.new()
	for model in [steady, grouped]:
		model.pickup()
		model.hold(true)
	advance(steady, 120)
	for group in 40:
		grouped.step(3.0 * Model.TICK)
	check(steady.snapshot() == grouped.snapshot(), "same input and simulated duration gives identical state")
	var state := grouped.snapshot()
	grouped.step(-1.0)
	grouped.step(INF)
	grouped.step(NAN)
	check(grouped.snapshot() == state, "malformed non-finite or negative delta does not advance state")
	for batch in 200:
		grouped.step(0.25)
	check(grouped.result().ended and not grouped.result().success and not grouped.result().devil
		and grouped.result().ordinary_eligible, "a natural lapse after a meaningful attempt has ordinary participation")
	var idle := Model.new()
	for batch in 200:
		idle.step(0.25)
	check(idle.result().ended and not idle.result().ordinary_eligible and not idle.pickup(),
		"idle expiration is not eligible and cannot be revived by a stale event")

func move_to_handoff(model: RefCounted, route: int, umbrella: bool) -> void:
	check(model.choose_route(route) and model.pickup(), "courier chooses a valid route and takes the box")
	model.set_umbrella(umbrella)
	finish_walk(model)

func finish_walk(model: RefCounted) -> void:
	model.hold(true)
	for tick in 600:
		if model.snapshot().stage != Model.CARRY:
			break
		model.step(Model.TICK)
	check(model.snapshot().stage == Model.HANDOFF, "the chosen path reaches its handoff on foot")

func wait_window(model: RefCounted, inside: bool) -> void:
	for tick in 160:
		if model.snapshot().slide_ready == inside:
			return
		model.step(Model.TICK)
	check(false, "the receiver must cycle through both the valid and invalid handoff windows")

func advance(model: RefCounted, ticks: int) -> void:
	for tick in ticks:
		model.step(Model.TICK)

func check(condition: bool, reason: String) -> void:
	if not condition:
		_errors.append(reason)
