extends SceneTree

const Model = preload("res://game/minigames/pancake_fold_model.gd")
const BODY_ROUTE := [
	Vector2(-2.8, -2.8), Vector2(2.8, -2.8), Vector2(-2.8, 2.8), Vector2(2.8, 2.8),
]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_controls_fields_and_conservation()
	_direct_rim_pour_is_not_reclaimable()
	_fresh_pour_cannot_fake_an_ear()
	_scooping_without_laying_cannot_prove_an_ear()
	_disconnected_wet_batter_stays_on_pan()
	_wet_hinge_must_set_again()
	_heat_pressure_and_timeout()
	for layout in 2:
		for assisted in [false, true]:
			_ordinary_round(layout, assisted)
			_recovered_ear_round(layout, assisted)
	print("Pancake fold model: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("PASS: pancake fold batter conservation and reclaimed fold ear")
	quit(int(_failures != 0))


func _controls_fields_and_conservation() -> void:
	var model := Model.new()
	var start := model.snapshot()
	var cell_count := Model.PAN_SIZE * Model.PAN_SIZE
	_expect(start.mass.size() == cell_count and start.cook.size() == cell_count and start.heat.size() == cell_count
		and start.filling_mask.size() == cell_count and start.required_mask.size() == cell_count
		and start.ear_mask.size() == cell_count and start.thin_mask.size() == cell_count and start.rim_mask.size() == cell_count,
		"bounded row-major state contains all render and gameplay fields")
	_expect(start.stock == Model.STOCK_MASS and start.tool == Model.TILT and start.cursor == Vector2.ZERO
		and start.can_pour and not start.can_salvage and start.fold_reason == "empty" and not start.engaged,
		"fresh pan, explicit tool, and no eligibility by idling")
	model.set_axis(Vector2(NAN, INF))
	model.step(INF)
	model.step(-1.0)
	model.step(Model.TICK * 0.25)
	var invalid := model.snapshot()
	_expect(invalid.elapsed == 0.0 and invalid.tilt == Vector2.ZERO and invalid.revision == start.revision,
		"rejected nonfinite control and substep leave pose and shared paint revision untouched")
	_expect(model.pour() and _mass_ok(model.snapshot()) and model.snapshot().engaged and model.snapshot().poured == 1,
		"real metered pour earns participation and transfers only one dose from stock")
	var poured := model.snapshot()
	_expect(poured.stock == Model.STOCK_MASS - Model.POUR_MASS and poured.mass[_index(Vector2i.ZERO)] > 1.5
		and poured.cook[_index(Vector2i.ZERO)] == 0.0 and poured.fold_reason == "thin"
		and _sum(start.mass) == 0.0, "cold actual pour creates a local thickness field and does not mutate the old snapshot")
	model.set_axis(Vector2(20.0, 0.0))
	_ticks(model, 18)
	var sloped := model.snapshot()
	_expect(sloped.tilt.x > 0.95 and sloped.cursor == Vector2.ZERO and _centroid(sloped.mass).x > 0.17
		and sloped.cook[_index(Vector2i.ZERO)] > 0.0 and _mass_ok(sloped),
		"held finite tilt creates real downhill transport and heating, without cursor motion")
	_expect(model.toggle_tool() and model.snapshot().tool == Model.LADLE, "switch tools while a direction is held")
	_ticks(model, 5)
	var switched := model.snapshot()
	_expect(switched.cursor == Vector2.ZERO and switched.tilt.x < sloped.tilt.x and switched.tilt.x > 0.0,
		"tool switch drops the old held direction and tilt eases towards level")
	model.set_axis(Vector2(-1.0, 1.0))
	_ticks(model, 50)
	var edge := model.snapshot()
	_expect(edge.cursor.x < -1.0 and edge.cursor.y > 1.0 and edge.cursor.length() <= Model.PAN_RADIUS
		and edge.tilt == Vector2.ZERO and _mass_ok(edge), "ladle walks smoothly and clamps against the real circular pan")
	model.clear_input()
	_ticks(model, 2)
	_expect(model.snapshot().cursor.is_equal_approx(edge.cursor), "input clear prevents tool motion on pause or focus change")

	var whole := Model.new()
	var split := Model.new()
	for item in [whole, split]:
		item.pour()
		item.set_axis(Vector2(0.3, -0.75))
	for tick in 63:
		whole.step(Model.TICK)
		split.step(Model.TICK * 0.31)
		split.step(Model.TICK * 0.69)
	var a := whole.snapshot()
	var b := split.snapshot()
	_expect(a.mass == b.mass and a.cook == b.cook and a.tilt == b.tilt and a.elapsed == b.elapsed,
		"fixed flow and heat steps exactly reproduce a split input cadence")


func _direct_rim_pour_is_not_reclaimable() -> void:
	var model := Model.new()
	_expect(_move(model, Vector2(10.65, 0.0)) and model.pour(), "pour unmoved fresh stock directly at the rim")
	_ticks(model, 18)
	var direct := model.snapshot()
	_expect(direct.mass[_index(Vector2i(11, 0))] > 0.80 and direct.flowed_to_rim == 0.0 and direct.rim_available == 0.0,
		"real fresh rim mass is present, but it has no directed-flow provenance")
	_expect(not direct.can_salvage and not model.salvage_or_lay() and model.snapshot().cup == 0.0
		and not model.snapshot().ear_proven and _mass_ok(model.snapshot()), "scoop cannot tag fresh rim batter or invent material")


func _fresh_pour_cannot_fake_an_ear() -> void:
	var model := Model.new()
	if not _body(model, "fresh ear negative"):
		return
	var target: Vector2 = model.snapshot().ear_target
	_expect(_move(model, target) and model.pour() and _wait_for_fold(model, false, 420), "fresh stock can physically patch the ear area")
	var before := model.snapshot()
	_expect(before.mass[_index(Vector2i(-6, 0))] > Model.MIN_THICKNESS and before.ear_coverage == 0
		and before.reclaimed_mass == 0.0 and not before.ear_proven, "fresh ear-like cloth cannot pass the recovered-mass proof")
	_assert_fold(model, false, "fresh stock patch")


func _scooping_without_laying_cannot_prove_an_ear() -> void:
	var model := Model.new()
	if not _body(model, "scoop-only negative") or not _collect_rim(model, "scoop-only negative"):
		return
	var held := model.snapshot()
	_expect(held.cup > 2.0 and held.reclaimed_mass == 0.0 and not held.ear_proven
		and _sum(held.recovered) == 0.0, "scooped rim mass physically moved into the cup only")
	_expect(_wait_for_fold(model, false, 160), "carrying a cup still allows a fully closed ordinary dish")
	_assert_fold(model, false, "cup kept without manually laying")


func _disconnected_wet_batter_stays_on_pan() -> void:
	var model := Model.new()
	if not _body(model, "separate wet runoff") or not _wait_for_fold(model, false, 450):
		return
	var detached := _index(Vector2i(-11, 0))
	if not _expect(_move(model, Vector2(-10.6, 0.0)) and model.pour() and model.snapshot().mass[detached] > 0.8,
		"an actual late deposit is present away from the connected cooked sheet"):
		return
	var wet := model.snapshot()
	_assert_fold(model, false, "fold with a separate wet patch still on the pan")
	var folded := model.snapshot()
	_expect(folded.fold_source_mask[detached] == 0 and wet.mass[detached] == folded.mass[detached] and _mass_ok(folded),
		"isolated wet batter remains in place and stays in the conserved mass")


func _wet_hinge_must_set_again() -> void:
	var model := Model.new()
	if not _body(model, "freshly patched hinge") or not _wait_for_fold(model, false, 450):
		return
	if not _expect(_move(model, Vector2.ZERO) and model.pour(), "place a real late dose on the fold hinge"):
		return
	var wet := model.snapshot()
	_expect(wet.coverage >= 0.94 and wet.seam == 1.0 and wet.fold_reason == "wet" and not model.fold(),
		"a physically thick but unset hinge cannot fold before it cooks")
	_expect(_wait_for_fold(model, false, 460), "the hinge becomes foldable with actual heating")
	_assert_fold(model, false, "set patched hinge")


func _heat_pressure_and_timeout() -> void:
	var a := Model.new()
	var b := Model.new()
	b.reset(true, 1)
	var first := a.snapshot()
	var second := b.snapshot()
	_expect(first.fold_axis == Vector2.RIGHT and second.fold_axis == Vector2.DOWN
		and first.filling_mask != second.filling_mask and first.required_mask != second.required_mask
		and first.heat != second.heat and first.ear_target != second.ear_target, "layouts choose physically different heat spots and ingredients")
	_expect(first.heat[_index(Vector2i(-4, 2))] > first.heat[_index(Vector2i(11, 0))]
		and second.heat[_index(Vector2i(3, -3))] > second.heat[_index(Vector2i(0, 11))], "both pans cook faster under actual heat spots than at the rim")
	a.set_axis(Vector2.LEFT)
	a.step(50.0)
	_expect(a.snapshot().elapsed <= 0.26 and not a.snapshot().engaged, "oversized elapsed input is safely bounded and does not count as cooking")
	for part in 450:
		a.step(0.25)
	var idle := a.snapshot()
	_expect(idle.ended and idle.elapsed == Model.ROUND_SECONDS and not idle.ordinary_eligible and idle.score == 0,
		"no batter and no collection eligibility after a standard timeout")

	a.reset(false, 1)
	if not _body(a, "standard char timing") or not _body(b, "assisted char timing"):
		return
	for part in 120:
		a.step(0.25)
		b.step(0.25)
	_expect(a.snapshot().burned > 0.2 and a.snapshot().fold_reason == "burned" and not a.fold(),
		"excess heat creates genuine char pressure in a covered standard pan")
	_expect(b.snapshot().burned == 0.0 and b.snapshot().can_fold and not b.snapshot().ear_proven,
		"assistance removes char only while retaining the real cooked fold and absent ear proof")
	for part in 470:
		b.step(0.25)
	var failed := b.snapshot()
	_expect(failed.ended and failed.elapsed == Model.ASSISTED_SECONDS and not failed.success
		and failed.ordinary_eligible and failed.score == 0 and _mass_ok(failed),
		"a played assisted timeout still allows the ordinary attempt contract but does not claim a finished dish")


func _ordinary_round(layout: int, assisted: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "ordinary layout %d assisted %s" % [layout, assisted]
	if not _body(model, label):
		return
	_expect(_wait_for_fold(model, false, 450), "settled complete fold is available for " + label)
	_assert_fold(model, false, label)


func _recovered_ear_round(layout: int, assisted: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var label := "recovered layout %d assisted %s" % [layout, assisted]
	if not _body(model, label) or not _collect_rim(model, label):
		return
	var target: Vector2 = model.snapshot().ear_target
	var held: float = model.snapshot().cup
	if not _expect(_move(model, target) and model.salvage_or_lay(), "manually carry and spread reclaimed rim batter at the ear in " + label):
		return
	var laid := model.snapshot()
	_expect(laid.cup == 0.0 and is_equal_approx(laid.reclaimed_mass, held) and absf(_sum(laid.recovered) - held) < 0.001
		and _mass_ok(laid), "laying physically transfers the entire cup into the new cells")
	_expect(_wait_for_fold(model, true, 350), "real anchored, overlapped and cooled ear becomes foldable in " + label)
	var ready := model.snapshot()
	_expect(ready.ear_overlap >= 2 and ready.ear_coverage >= 3 and ready.ear_attached >= 1
		and ready.ear_proven and ready.can_fold and not ready.devil,
		"ear proof requires actual thickness and contact with the reflected pastry before score")
	_assert_fold(model, true, label)


func _body(model: RefCounted, label: String) -> bool:
	var sequence_ok := true
	for point in BODY_ROUTE:
		sequence_ok = _move(model, point) and model.pour()
		if not sequence_ok:
			break
		_ticks(model, 7)
	if not _expect(sequence_ok, "actual movable ladle pours into all four recipe quadrants for " + label):
		return false
	var state: Dictionary = model.snapshot()
	_expect(state.poured == 4 and state.stock == Model.STOCK_MASS - 4.0 * Model.POUR_MASS
		and _mass_ok(state) and not state.can_fold, "fresh body layer conserves four doses and needs real heat")
	return true


func _collect_rim(model: RefCounted, label: String) -> bool:
	var laid: Dictionary = model.snapshot()
	var wait_ticks := maxi(0, ceili((14.40 - float(laid.elapsed)) / Model.TICK))
	_ticks(model, wait_ticks)
	var fold_axis: Vector2 = model.snapshot().fold_axis
	if not _expect(_move(model, fold_axis * 8.50) and model.pour()
		and model.snapshot().flowed_to_rim == 0.0, "reserve dose is deposited without unearned rim provenance in " + label):
		return false
	model.toggle_tool()
	model.set_axis(fold_axis)
	_ticks(model, 73)
	model.set_axis(Vector2.ZERO)
	var flowed: Dictionary = model.snapshot()
	if not _expect(flowed.flowed_to_rim > 4.0 and flowed.rim_available > 3.0 and _mass_ok(flowed),
		"real outward slope transports a traceable dose to the cooler rim in " + label):
		return false
	if not _expect(_move(model, fold_axis * 10.60) and model.snapshot().can_salvage and model.salvage_or_lay(),
		"aim at the real eligible rim cell before operating the scoop in " + label):
		return false
	var scooped: Dictionary = model.snapshot()
	return _expect(scooped.cup > 2.0 and scooped.reclaimed_mass == 0.0 and _mass_ok(scooped),
		"mass exists only in the cup until deliberately deposited at the ear")


func _wait_for_fold(model: RefCounted, challenge: bool, deadline: int) -> bool:
	for tick in deadline:
		var state: Dictionary = model.snapshot()
		if state.can_fold and (not challenge or state.ear_proven):
			return true
		if state.ended or state.fold_reason == "burned":
			break
		model.step(Model.TICK)
	var final: Dictionary = model.snapshot()
	print("Fold wait detail: ", [final.layout, final.assisted, final.elapsed, final.fold_reason,
		final.coverage, final.seam, final.filled, final.cooked, final.burned, final.ear_coverage,
		final.ear_overlap, final.ear_attached, final.reclaimed_mass, final.cursor])
	return false


func _assert_fold(model: RefCounted, challenge: bool, label: String) -> void:
	var before: Dictionary = model.snapshot()
	if not _expect(before.can_fold and model.fold(), "request a true physically foldable dish in " + label):
		return
	_expect(not model.snapshot().ended and model.snapshot().fold_reason == "folding" and not model.pour(),
		"fold begins with inputs locked and no early collection result")
	_ticks(model, 13)
	var middle: Dictionary = model.snapshot()
	_expect(middle.folded and middle.fold_progress > 0.5 and middle.fold_progress < 1.0
		and not middle.ended and _mass_ok(middle), "visible intermediate fold deposits actual flap onto the landing side")
	var projection_ok := true
	var moved_cells := 0
	for index in before.mass.size():
		var point := _point(index)
		var forward := roundi(Vector2(point).dot(before.fold_axis))
		var mirror := _index(point - Vector2i(before.fold_axis) * forward * 2)
		var wanted: float = before.mass[index]
		if middle.fold_source_mask[index] != 0:
			wanted = 0.0
			moved_cells += 1
		elif forward > 0 and middle.fold_source_mask[mirror] != 0:
			wanted += before.mass[mirror]
		if absf(middle.mass[index] - wanted) > 0.00002:
			projection_ok = false
			break
	_expect(projection_ok and moved_cells > 20, "finished silhouette is the exact mass-conserving reflection of the connected flap")
	_ticks(model, 12)
	var outcome: Dictionary = model.snapshot()
	_expect(outcome.ended and outcome.success and outcome.ordinary_eligible and outcome.devil == challenge
		and outcome.score == Model.DISH_POINTS + int(challenge) * Model.EAR_POINTS
		and outcome.fold_progress == 1.0 and _mass_ok(outcome), "exact 450 or 550 point real result for " + label)


func _move(model: RefCounted, target: Vector2) -> bool:
	if model.snapshot().tool != Model.LADLE:
		model.toggle_tool()
	for tick in 120:
		var offset: Vector2 = target - Vector2(model.snapshot().cursor)
		if offset.length() < 0.25:
			model.set_axis(Vector2.ZERO)
			return true
		var axis := Vector2(signf(offset.x) if absf(offset.x) > 0.176 else 0.0,
			signf(offset.y) if absf(offset.y) > 0.176 else 0.0)
		model.set_axis(axis)
		model.step(Model.TICK)
	model.set_axis(Vector2.ZERO)
	return false


func _sum(field: PackedFloat32Array) -> float:
	var total := 0.0
	for amount in field:
		total += amount
	return total


func _centroid(field: PackedFloat32Array) -> Vector2:
	var total := 0.0
	var weighted := Vector2.ZERO
	for index in field.size():
		var amount := field[index]
		total += amount
		weighted += Vector2(_point(index)) * amount
	return weighted / total


func _mass_ok(state: Dictionary) -> bool:
	if absf(_sum(state.mass) + state.stock + state.cup - Model.STOCK_MASS) > 0.006:
		return false
	for index in state.mass.size():
		if not is_finite(state.mass[index]) or state.mass[index] < 0.0 \
			or state.rim[index] + state.recovered[index] > state.mass[index] + 0.00005:
			return false
	return true


func _index(point: Vector2i) -> int:
	return (point.y + Model.CENTER) * Model.PAN_SIZE + point.x + Model.CENTER


func _point(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	var row := index / Model.PAN_SIZE
	return Vector2i(index % Model.PAN_SIZE - Model.CENTER, row - Model.CENTER)


func _ticks(model: RefCounted, count: int) -> void:
	for tick in count:
		model.step(Model.TICK)


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", description)
	return condition
