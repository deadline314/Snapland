extends SceneTree

const Model = preload("res://game/minigames/scent_trail_model.gd")
const N = Model.Landmark
const MARK_ROUTE := [[N.CANOPY, N.CROSSROAD], [N.CANOPY, N.CROSSROAD, N.WEST_TURN]]
const STOVE_ROUTE := [
	[
		[N.CANOPY, N.CROSSROAD, N.WEST_TURN, N.TEA_STOVE],
		[N.TEA_STOVE, N.WEST_TURN, N.CROSSROAD, N.EAST_TURN, N.CHAR_STOVE],
		[N.CHAR_STOVE, N.EAST_TURN, N.CROSSROAD, N.CANOPY, N.ENTRY, N.WEST_EXIT, N.SWEET_STOVE],
	],
	[
		[N.CANOPY, N.CROSSROAD, N.WEST_TURN, N.TEA_STOVE],
		[N.TEA_STOVE, N.WEST_TURN, N.CROSSROAD, N.CANOPY, N.ENTRY, N.EAST_EXIT, N.EAST_COUNTER, N.CHAR_STOVE],
		[N.CHAR_STOVE, N.EAST_COUNTER, N.EAST_EXIT, N.ENTRY, N.WEST_EXIT, N.SWEET_STOVE],
	],
]
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_sample_orientation_and_finite_input()
	_walk_closures()
	_cold_counter_does_not_confirm()
	_separate_routes_cannot_prove_mix()
	_first_segment_after_merge_can_prove_mix()
	_help_follows_the_designated_scent()
	_timeout_and_timing()
	for layout in 2:
		for assisted in [false, true]:
			_round(layout, assisted, false)
			_round(layout, assisted, true)
	print("Scent trail model: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("PASS: scent trail wind sampling, shared sources and closed alleys")
	quit(int(_failures != 0))


func _sample_orientation_and_finite_input() -> void:
	var model := Model.new()
	var initial := model.snapshot()
	_expect(initial.cue.edge == 5 and initial.cue.mask == 3 and initial.sampled_mask == 0,
		"entry has an actual mixed plume and no evidence before sampling")
	_expect(not model.turn_sampler(0) and not model.set_filter(9) and not model.cycle_filter(3), "invalid controls rejected")
	_turn_to(model, Vector2.DOWN)
	var wrong := model.snapshot()
	_expect(wrong.cue.wind == Vector2.DOWN and wrong.cue.mask == 0 and not wrong.cue.aligned, "rotation changes the scan while keeping true wind direction")
	_expect(not model.interact() and model.snapshot().sampled_mask == 0, "wrong-way attempt does not create evidence")
	_turn_to(model, Vector2.UP)
	_expect(model.interact(), "wide mode can record all readable patterns")
	var wide := model.snapshot()
	_expect(wide.sampled_mask == 3 and wide.links[5].sampled_mask == 3 and wide.mixed_mask == 0,
		"wide reading records traces without proving a separated pair")
	_expect(wide.cue.strengths.x > wide.cue.strengths.y and wide.cue.strengths.z == 0.0, "distinct source attenuation survives the join")
	model.set_filter(Model.TEA)
	var filtered := model.snapshot()
	_expect(filtered.cue.mask == 1 and filtered.cue.strengths.x > 0.16 and filtered.cue.strengths.y == 0.0,
		"selected filter isolates its stripe and zeroes other visible channels")
	_expect(model.cycle_filter(-1) and model.snapshot().filter == Model.WIDE, "filter selector cycles to wide")

	model.set_walk_axis(Vector2(INF, NAN))
	model.step(Model.TICK)
	_expect(model.snapshot().player == initial.player and model.snapshot().velocity == Vector2.ZERO, "non-finite axis ignored")
	model.set_walk_axis(Vector2(12.0, -9.0))
	model.step(Model.TICK)
	var moved := model.snapshot()
	_expect(absf(moved.velocity.length() - Model.WALK_SPEED) < 0.001 and moved.player.x > initial.player.x
		and moved.player.y < initial.player.y, "diagonal input is limited to one normal walking speed")
	model.clear_input()
	var cleared := model.snapshot()
	model.step(Model.TICK)
	_expect(cleared.velocity == Vector2.ZERO and model.snapshot().player == cleared.player, "clear input stops movement immediately")


func _walk_closures() -> void:
	var model := Model.new()
	var initial := model.snapshot()
	_expect(not initial.links[6].open and initial.links[6].wind == Vector2.ZERO and initial.links[2].open and initial.links[2].wind != Vector2.ZERO,
		"layout 0 physically closes sweet-to-west and retains char-to-east")
	_expect(_walk_nodes(model, [N.WEST_EXIT, N.SWEET_STOVE]), "layout 0 keeps the south route to the sweet stove")
	var sweet_closed_midpoint := _location(N.SWEET_STOVE).lerp(_location(N.WEST_TURN), 0.5)
	_expect(not _walk_to(model, sweet_closed_midpoint, 130), "walking cannot cross the closed sweet shortcut")

	model.reset(false, 1)
	initial = model.snapshot()
	_expect(initial.links[6].open and initial.links[6].wind != Vector2.ZERO and not initial.links[2].open and initial.links[2].wind == Vector2.ZERO,
		"layout 1 opens the sweet shortcut and blocks the char link")
	_expect(initial.cue.mask == 5 and initial.cue.strengths.y == 0.0, "layout closure reroutes the actual mixed pair at the same entry")
	_expect(_walk_nodes(model, [N.CANOPY, N.CROSSROAD, N.WEST_TURN, N.SWEET_STOVE]), "new sweet shortcut is physically walkable")
	model.reset(false, 1)
	_expect(_walk_nodes(model, [N.EAST_EXIT, N.EAST_COUNTER, N.CHAR_STOVE]), "layout 1 retains a legal walk to the charcoal stove")
	var char_closed_midpoint := _location(N.CHAR_STOVE).lerp(_location(N.EAST_TURN), 0.5)
	_expect(not _walk_to(model, char_closed_midpoint, 130), "walking cannot cross the closed char alley")


func _cold_counter_does_not_confirm() -> void:
	var model := Model.new()
	model.reset(false, 1)
	_turn_to(model, Vector2.UP)
	model.set_filter(Model.CHAR)
	_expect(_walk_nodes(model, [N.EAST_EXIT, N.EAST_COUNTER]), "walk to the cold east counter")
	var before := model.snapshot()
	_expect(not before.stalls[3].cooking and before.action != "confirm" and before.cue.mask == 2,
		"cold counter can contain windborne char but is not a cooking source")
	_expect(model.interact() and model.snapshot().sampled_mask == 2 and model.snapshot().found == 0 and model.snapshot().score == 0,
		"cold counter scent is recorded without granting source credit")


func _separate_routes_cannot_prove_mix() -> void:
	var model := Model.new()
	model.set_filter(Model.TEA)
	_expect(model.interact() and model.snapshot().links[5].sampled_mask == 1, "first focused sample on shared entry segment")
	_expect(_walk_nodes(model, [N.CANOPY, N.CROSSROAD]) and _walk_to(model, Vector2(1.12, -0.55)), "walk to a separate char-only segment")
	_turn_to(model, Vector2.RIGHT)
	model.set_filter(Model.CHAR)
	_expect(model.interact() and model.snapshot().links[3].sampled_mask == 2, "second focused sample comes from distinct physical segment")
	var separate := model.snapshot()
	_expect(separate.sampled_mask == 3 and separate.mixed_mask == 0 and not separate.mix_proven, "union of independent reads cannot qualify as separated common flow")
	_expect(_walk_nodes(model, [N.CROSSROAD, N.CANOPY, N.ENTRY]), "return to entry via actual walk")
	_turn_to(model, Vector2.UP)
	_expect(model.interact() and model.snapshot().mixed_mask == 3 and not model.snapshot().mix_proven,
		"actual second focused sample on the same segment proves both channels, pending positional mark")
	_expect(model.interact() and not model.snapshot().mix_proven, "repeated sniff at entry cannot mark the real crossroad")


func _first_segment_after_merge_can_prove_mix() -> void:
	var model := Model.new()
	_expect(_walk_nodes(model, [N.CANOPY]) and _walk_to(model, Vector2(0.0, 0.19)), "reach first segment immediately below merge")
	model.set_filter(Model.TEA)
	_expect(model.interact(), "sample tea on the first segment after merge")
	model.set_filter(Model.CHAR)
	_expect(model.interact(), "sample char on the same first segment after merge")
	var state := model.snapshot()
	_expect(state.links[4].sampled_mask == 3 and state.mixed_mask == 3 and not state.mix_proven,
		"the two separate incoming channels qualify their first mixed downstream segment")
	_expect(model.interact() and not model.snapshot().mix_proven,
		"sampling the first mixed segment again cannot mark beyond reach")
	_expect(_walk_nodes(model, [N.CROSSROAD]) and model.snapshot().action == "mark"
		and model.interact() and model.snapshot().mix_proven,
		"walking to the actual meeting of the two incoming channels completes their proof")


func _help_follows_the_designated_scent() -> void:
	var model := Model.new()
	model.reset(true, 0)
	_expect(not model.request_helper() and model.snapshot().assist_direction == Vector2.ZERO, "assist starts without a known trace or helper")
	model.set_filter(Model.TEA)
	_expect(model.interact() and model.snapshot().helper_ready and model.snapshot().assist_direction.dot(Vector2.UP) > 0.99,
		"an observed faint focused trace enables the continuous direction fan and helper")
	_turn_to(model, Vector2.DOWN)
	var before := model.snapshot()
	_expect(before.action == "helper" and before.action_ready, "compact action button offers helper when no fresh physical sample is visible")
	_expect(model.interact(), "context action can request the helper")
	var helped := model.snapshot()
	_expect(helped.helper_visible and helped.helper_scent == Model.TEA and helped.helper_point == _location(N.CROSSROAD),
		"helper reports the next actual upwind junction for the specified trace")
	_expect(helped.player == before.player and helped.sampled_mask == before.sampled_mask and helped.found == before.found and not helped.mix_proven,
		"helper does not move the player, sample or complete evidence")
	model.set_filter(Model.CHAR)
	_expect(not model.snapshot().helper_visible and not model.request_helper() and not model.snapshot().helper_ready,
		"changing to an unread trace clears helper and prevents stale hints")
	model.set_filter(Model.TEA)
	_expect(model.request_helper(), "return to learned faint trace")
	for _index in Model.HELPER_TICKS + 2:
		model.step(Model.TICK)
	_expect(not model.snapshot().helper_visible and model.snapshot().sampled_mask == 1 and model.snapshot().helper_ready,
		"temporary marker expires without changing actual evidence")


func _timeout_and_timing() -> void:
	var model := Model.new()
	for _index in 500:
		model.step(0.25)
	_expect(model.snapshot().ended and not model.snapshot().ordinary_eligible and not model.interact() and not model.turn_sampler(1),
		"idle formal timeout stays ineligible and freezes actions")
	model.reset(true, 1)
	model.set_filter(Model.SWEET)
	model.interact()
	for _index in 600:
		model.step(0.25)
	_expect(model.snapshot().ended and model.snapshot().ordinary_eligible and not model.snapshot().success,
		"authentic scent record qualifies on natural assisted timeout")

	var fine := Model.new()
	var coarse := Model.new()
	fine.set_walk_axis(Vector2.UP)
	coarse.set_walk_axis(Vector2.UP)
	for _index in 10:
		coarse.step(0.1)
		for _split in 6:
			fine.step(1.0 / 60.0)
	_expect(coarse.snapshot() == fine.snapshot(), "movement and cues remain deterministic at equivalent fixed-step timings")
	var before := fine.snapshot()
	fine.step(NAN)
	fine.step(INF)
	fine.step(-1.0)
	_expect(fine.snapshot() == before, "invalid deltas leave the full state unchanged")


func _round(layout: int, assisted: bool, challenge: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "layout %d assist %s challenge %s" % [layout, assisted, challenge]
	if challenge:
		model.set_filter(Model.TEA)
		_expect(model.interact(), "sample entry tea for %s" % label)
		model.set_filter(Model.CHAR if layout == 0 else Model.SWEET)
		_expect(model.interact() and model.snapshot().mixed_mask == (3 if layout == 0 else 5),
			"sample the second entry scent for %s" % label)
		_expect(_walk_nodes(model, MARK_ROUTE[layout]), "walk actual shared corridor to true merge for %s" % label)
		_expect(model.snapshot().action == "mark" and model.interact() and model.snapshot().mix_proven,
			"actual safe mark at true merge for %s" % label)
		_expect(not model.snapshot().devil, "completed mix alone does not award the full challenge")

	for scent in Model.STALL_COUNT:
		var route: Array = STOVE_ROUTE[layout][scent]
		# Tea is already to the west of the crossroad after marking layout 1.
		if scent == Model.TEA and challenge:
			route = [N.WEST_TURN, N.TEA_STOVE]
		model.set_filter(scent)
		var arrived := _follow_to_stove(model, route)
		var cooked: bool = arrived and model.snapshot().action == "confirm" and model.interact()
		_expect(cooked and bool(model.snapshot().found_mask & (1 << scent)), "actual stroll, aimed sniff and confirmation %d for %s" % [scent, label])
		if not cooked:
			print("Route blocked: %s at %s, source %d, approaching %s, action %s" %
				[label, model.snapshot().player, scent, route, model.snapshot().action])
			return
	var state := model.snapshot()
	var points := Model.STALL_COUNT * Model.STALL_POINTS + int(challenge) * Model.MIX_POINTS
	_expect(state.found == Model.STALL_COUNT and state.found_mask == 7 and state.ended and state.success
		and state.ordinary_eligible and state.devil == challenge and state.score == points,
		"truthful results for %s" % label)


func _follow_to_stove(model: RefCounted, route: Array) -> bool:
	var last: int = route[-1]
	var emit_point := _location(last)
	var approach := _location(route[-2])
	for index in range(route.size() - 1):
		if not _walk_to(model, _location(route[index])):
			return false
	if not _walk_to(model, emit_point + (approach - emit_point).normalized() * 0.27):
		return false
	_turn_to(model, emit_point - model.snapshot().player)
	return true


func _walk_nodes(model: RefCounted, route: Array) -> bool:
	for node: int in route:
		if not _walk_to(model, _location(node)):
			return false
	return true


func _walk_to(model: RefCounted, goal: Vector2, limit := 440) -> bool:
	for _frame in limit:
		var current: Vector2 = model.snapshot().player
		var difference := goal - current
		if difference.length_squared() < 0.035 * 0.035:
			model.clear_input()
			return true
		model.set_walk_axis(difference / (Model.WALK_SPEED * Model.TICK))
		model.step(Model.TICK)
	model.clear_input()
	return false


func _turn_to(model: RefCounted, vector: Vector2) -> void:
	var target := posmod(roundi((vector.angle() + PI * 0.5) / (TAU / 8.0)), 8)
	var turns := posmod(target - int(model.snapshot().sampler_turn), 8)
	var direction := 1 if turns <= 4 else -1
	for _change in mini(turns, 8 - turns):
		model.turn_sampler(direction)


func _location(node: int) -> Vector2:
	return Model.LOCATIONS[node]


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)
