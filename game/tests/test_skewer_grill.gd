extends SceneTree

const Model = preload("res://game/minigames/skewer_grill_model.gd")
var _errors: Array[String] = []

func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Skewer grill model test requires an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	test_independent_surfaces()
	test_layout_and_zones()
	test_burn_and_replace()
	test_residual_only_challenge()
	test_assistance()
	test_fixed_step_and_expiration()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: skewer grill independent faces, charcoal zones and residual heat")
	quit(int(not _errors.is_empty()))

func test_independent_surfaces() -> void:
	var model := Model.new()
	check(model.snapshot().active == 0 and not model.serve() and not model.move(99) and not model.replace_skewer(),
		"fresh bench stays cold and invalid or premature actions do not serve")
	check(model.move(Model.NEAR), "near zone places the selected skewer")
	advance(model, 55)
	var before: Dictionary = model.snapshot().current
	check(before.down_face == 0 and before.top_face == 2 and before.heat[0] > before.heat[2]
		and before.cook[0] > before.cook[2] and before.face_states[2] == "raw",
		"radiation warms the face pointing toward coal more than the opposite face")
	check(model.turn(), "manual quarter-turn is available")
	var after: Dictionary = model.snapshot().current
	check(after.down_face == 1 and after.top_face == 3 and after.turn_gloss == 1.0
		and after.heat == before.heat and after.cook == before.cook and after.char == before.char,
		"turn changes physical incidence and gloss without swapping recorded surfaces")
	advance(model, 70)
	var turned: Dictionary = model.snapshot().current
	check(turned.heat[1] > turned.heat[0] and turned.cook[1] > after.cook[1] and turned.turn_gloss < 0.1,
		"after turning the newly downward face accumulates its own exposure")
	check(not model.serve(), "heating only part of the surface never completes the whole skewer")

func test_layout_and_zones() -> void:
	var near := Model.new()
	var far := Model.new()
	var alternate := Model.new()
	alternate.reset(false, 1)
	var main_layout := near.snapshot()
	var other_layout := alternate.snapshot()
	check(main_layout.layout == 0 and other_layout.layout == 1
		and main_layout.current.ingredient != other_layout.current.ingredient
		and main_layout.current.size != other_layout.current.size
		and main_layout.fuel != other_layout.fuel and main_layout.residual_heat != other_layout.residual_heat,
		"pan arrangement changes actual ingredient size, recipe order and charcoal reserve")
	near.move(Model.NEAR)
	far.move(Model.FAR)
	advance(near, 100)
	advance(far, 100)
	var near_state := near.snapshot()
	var far_state := far.snapshot()
	check(near_state.active == 1 and far_state.active == 1 and near_state.current.cook[0] > far_state.current.cook[0]
		and far_state.current.cook[0] > 0.15 and near_state.current.char[0] > far_state.current.char[0],
		"near coal is faster and harsher while the distant shelf genuinely cooks")
	check(near.add_coal(), "refill adds actual direct heat")
	var hot := near.snapshot()
	check(hot.refuels == 1 and hot.near_heat > near_state.near_heat and hot.current.cook == near_state.current.cook,
		"adding coal alters future heating and preserves the prior food state")

func test_burn_and_replace() -> void:
	var model := Model.new()
	check(cook_and_serve(model, 0), "first healthy skewer is served before trying a replacement")
	check(model.select_skewer(1) and model.move(Model.NEAR), "second cut can cook independently")
	advance(model, 650)
	var failed := model.snapshot()
	check(failed.current.ruined and failed.current.face_states[0] == "charred" and not model.serve(),
		"staying near the coals permanently chars only the neglected face")
	check(model.replace_skewer(), "current burnt skewer can be replaced")
	var retried := model.snapshot()
	check(retried.served == 1 and retried.skewers[0].zone == Model.SERVED and retried.current.zone == Model.BENCH
		and retried.current.cook == PackedFloat32Array([0.0, 0.0, 0.0, 0.0]) and retried.mistakes == 1,
		"replacement resets this slot while keeping prior portions and their score")
	check(model.select_skewer(0) and not model.replace_skewer() and not model.turn(),
		"served food cannot be altered or collected again")

func test_residual_only_challenge() -> void:
	for layout in 2:
		var player := Model.new()
		player.reset(false, layout)
		for index in Model.SKEWER_COUNT:
			check(cook_and_serve(player, index, index == 2), "desired layout can finish a real skewer")
		var result := player.snapshot()
		check(result.ended and result.success and result.devil and result.ordinary_eligible
			and result.served == 3 and result.score == 550 and result.refuels == 0,
			"three completed skewers and an actual residual final face award the devil")

	var parked := Model.new()
	for index in Model.SKEWER_COUNT:
		check(cook_and_serve(parked, index, false, index == 2), "approved near-roasted skewer can still be plated")
	check(parked.snapshot().success and not parked.snapshot().devil and parked.snapshot().score == 450,
		"moving an already-cooked skewer to far cannot fake its final-face source")

	var slow := Model.new()
	for index in Model.SKEWER_COUNT:
		check(cook_and_serve(slow, index, false, false, Model.FAR), "all faces can be cooked at the cooler far shelf")
	check(slow.snapshot().success and slow.snapshot().devil and slow.snapshot().elapsed > parked.snapshot().elapsed,
		"far-only play trades time for safer heat and still enables the real residual goal")

	var refueled := Model.new()
	check(refueled.add_coal(), "finite fire can be refilled")
	for index in Model.SKEWER_COUNT:
		check(cook_and_serve(refueled, index, index == 2), "refueling leaves ordinary clear available")
	check(refueled.snapshot().success and not refueled.snapshot().devil and refueled.snapshot().refuels == 1
		and refueled.snapshot().skewers[2].residual_finish, "real far finish cannot bypass the no-add-coal condition")

func test_assistance() -> void:
	var model := Model.new()
	check(not model.toggle_helper(), "normal play keeps manual turns")
	model.reset(true, 0)
	check(model.move(Model.NEAR) and model.select_skewer(1) and model.move(Model.NEAR) and model.toggle_helper(),
		"assisted helper is assigned only to the selected skewer")
	for tick in 340:
		if model.snapshot().skewers[1].down_face != 0 or model.snapshot().warning >= 0:
			break
		model.step(Model.TICK)
	var guided := model.snapshot()
	check(guided.helper == 1 and guided.skewers[1].down_face == 1 and guided.skewers[0].down_face == 0
		and guided.skewers[1].zone == Model.NEAR and guided.served == 0 and guided.refuels == 0,
		"helper rotates the specified skewer inside the ready interval without serving, moving or refilling")

	model.reset(true, 0)
	model.move(Model.NEAR)
	for tick in 540:
		model.step(Model.TICK)
		if model.snapshot().warning >= 0:
			break
	var paused := model.snapshot()
	check(paused.warning == 0 and not paused.current.ruined, "near-burn warning freezes before a real burnt surface")
	advance(model, 60)
	check(model.snapshot().elapsed == paused.elapsed and model.snapshot().current.char == paused.current.char,
		"the hint pauses both clock and heating while the player considers the next move")
	check(model.move(Model.FAR) and model.snapshot().warning < 0, "moving the affected skewer answers the warning")
	advance(model, 2)
	check(model.snapshot().elapsed > paused.elapsed, "manual response resumes fixed step")

	model.reset(true, 1)
	for index in Model.SKEWER_COUNT:
		check(cook_and_serve(model, index, index == 2), "assisted controls preserve intentional far finishing")
	check(model.snapshot().success and model.snapshot().devil and model.snapshot().assisted,
		"assisted collection can earn the same genuine last-face condition")

func test_fixed_step_and_expiration() -> void:
	var regular := Model.new()
	var grouped := Model.new()
	regular.move(Model.NEAR)
	grouped.move(Model.NEAR)
	advance(regular, 120)
	for batch in 40:
		grouped.step(3.0 * Model.TICK)
	check(regular.snapshot() == grouped.snapshot(), "same input and total time yields deterministic state")
	var original := grouped.snapshot()
	grouped.step(-1.0)
	grouped.step(NAN)
	grouped.step(INF)
	check(grouped.snapshot() == original, "invalid delta cannot heat, cook or advance the clock")
	grouped.step(100.0)
	check(is_equal_approx(grouped.snapshot().elapsed, original.elapsed + 0.25), "catch-up work is bounded")
	var idle := Model.new()
	for batch in 430:
		idle.step(0.25)
		grouped.step(0.25)
	check(idle.snapshot().ended and not idle.snapshot().ordinary_eligible and not idle.move(Model.NEAR),
		"untouched expired round earns no participation and rejects older input")
	check(grouped.snapshot().ended and grouped.snapshot().ordinary_eligible and not grouped.snapshot().success,
		"actually handling heat before timeout counts as a completed attempt")

func cook_and_serve(model: RefCounted, index: int, warm_last := false, park_after := false, zone := Model.NEAR) -> bool:
	if not model.select_skewer(index) or not model.move(zone):
		return false
	for side in Model.FACE_COUNT:
		var current: Dictionary = model.snapshot().current
		var down: int = current.down_face
		var target: float = model.snapshot().cook_target
		if warm_last and side == Model.FACE_COUNT - 1:
			if not wait_until_face(model, down, target - 0.23) or model.snapshot().current.cook[down] >= target:
				return false
			if not model.move(Model.FAR):
				return false
		if not wait_until_face(model, down, target):
			return false
		if side < Model.FACE_COUNT - 1 and not model.turn():
			return false
	if park_after and not model.move(Model.FAR):
		return false
	return model.serve()

func wait_until_face(model: RefCounted, face: int, target: float) -> bool:
	for tick in 540:
		var state: Dictionary = model.snapshot()
		if state.current.cook[face] >= target:
			return true
		if state.ended or state.current.ruined or state.warning >= 0:
			return false
		model.step(Model.TICK)
	return false

func advance(model: RefCounted, ticks: int) -> void:
	for tick in ticks:
		model.step(Model.TICK)

func check(condition: bool, reason: String) -> void:
	if not condition:
		_errors.append(reason)
