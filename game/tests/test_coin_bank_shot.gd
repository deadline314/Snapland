extends SceneTree

const Model = preload("res://game/minigames/coin_bank_shot_model.gd")
const DIRECT := [
	[[-34, 2], [2, 2], [33, 2]],
	[[36, 2], [4, 2], [-32, 2]],
]
const DOUBLE_BANK := [[-37, 5, 3, -3], [42, 6, -2, -1]]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_setup_and_misses()
	_material_and_sweep()
	_wrong_pocket_discards_double_contact()
	_timing_and_participation()
	_helpers_and_preview()
	for layout in 2:
		for assisted in [false, true]:
			_round(layout, assisted, false)
			_round(layout, assisted, true)
	print("Coin bank shot model: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("PASS: coin bank shot physical boards, material and called pockets")
	quit(int(_failures != 0))


func _setup_and_misses() -> void:
	var model := Model.new()
	var state := model.snapshot()
	_expect(state.selected == Model.AIM and state.shots_left == 5 and state.called == 0 and state.power == 2, "normal round starts at the first called hole")
	_expect(state.preview.is_empty() and state.boards.size() == 2 and not state.boards[0].placed and not state.boards[1].placed, "normal mode starts without a suggested line or deployed boards")
	_expect(not model.toggle_board() and not model.select(2) and not model.adjust_power(3), "invalid controls cannot alter a board or start a shot")
	_expect(model.cycle_selection() and model.snapshot().selected == Model.BOARD_A, "selection advances to first board")
	_expect(model.toggle_board() and model.adjust_angle(1), "first board installs and rotates")
	var original := model.snapshot()
	_expect(original.boards[0].a != state.boards[0].a and original.boards[1].a == state.boards[1].a
		and original.boards[1].detent == 0 and original.aim == 0.0, "board rotation changes only its own segment")
	_expect(not model.assist_board(), "normal helper cannot change the selected board")
	_setup_aim(model, 2, 2)
	_expect(model.launch() and not model.launch() and not model.adjust_angle(1) and not model.select(Model.BOARD_B), "setup freezes during travel")
	_advance_until_settled(model)
	state = model.snapshot()
	_expect(state.settled_pocket == 1 and state.sunk == 0 and state.called == 0 and state.misses == 1 and state.shots_left == 4, "actual wrong-hole drop spends one attempt and preserves the called target")
	_expect(state.boards == original.boards and state.power == 2 and state.aim_degrees == 2 and state.trail.size() > 3, "miss retains board setup and actual trail")

	model.reset(false, 0)
	_setup_aim(model, -34, 10)
	model.launch()
	_advance_until_settled(model)
	state = model.snapshot()
	_expect(state.rim_scrapes > 0 and state.sunk == 0 and state.contacts_mask == 0, "fast centered coin scrapes the rim and never counts a board")

	model.reset(false, 0)
	_setup_aim(model, -65, 0)
	for _index in Model.NORMAL_SHOTS:
		_expect(model.launch(), "normal miss consumes one available attempt")
		_advance_until_settled(model)
	state = model.snapshot()
	_expect(state.ended and not state.success and state.sunk == 0 and state.ordinary_eligible and state.shots_left == 0 and not model.launch(), "normal misses exhaust supply honestly")

	model.reset(true, 0)
	_setup_aim(model, -65, 0)
	for _index in Model.NORMAL_SHOTS + 1:
		_expect(model.launch(), "assist replaces a missed coin without exhausting stock")
		_advance_until_settled(model)
	state = model.snapshot()
	_expect(not state.ended and state.shots_left == -1 and state.misses == 6 and state.mistakes == 0, "assist retains history without loss points")
	_setup_aim(model, -34, 2)
	_expect(model.launch(), "assisted round remains playable after replacements")
	_advance_until_settled(model)
	_expect(model.snapshot().sunk == 1 and model.snapshot().called == 1, "replacements can still enter the same called hole")


func _material_and_sweep() -> void:
	var model := Model.new()
	var wet := Model.Shot.new()
	wet.position = Vector2(1.2, -1.7)
	wet.velocity = Vector2(3.0, 0.0)
	var dry := Model.Shot.new()
	dry.position = Vector2(0.1, -1.7)
	dry.velocity = wet.velocity
	var contact := Model.Sweep.new()
	model._step_shot(wet, contact)
	model._step_shot(dry, contact)
	_expect(is_equal_approx((3.0 - wet.velocity.length()) / Model.TICK, Model.FELT_DRAG)
		and is_equal_approx((3.0 - dry.velocity.length()) / Model.TICK, Model.LACQUER_DRAG), "same shot loses more speed on felt in the shared kernel")
	_expect(wet.position.x - 1.2 < dry.position.x - 0.1, "material changes real movement distance")

	model.select(Model.BOARD_A)
	model.toggle_board()
	var state := model.snapshot()
	var face: Dictionary = state.boards[0]
	var tangent: Vector2 = (face.b - face.a).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var start: Vector2 = face.center + normal * 0.82
	model._find_contact(start, -normal * 1.64, -normal * 8.0, contact)
	_expect(contact.kind == Model.Contact.BOARD and contact.index == Model.BOARD_A and contact.time > 0.0 and contact.time < 1.0, "swept segment hits a thin board between safe endpoints")
	var tangent_start: Vector2 = face.center + normal * (Model.BOARD_RADIUS + Model.COIN_RADIUS + 0.03)
	model._find_contact(tangent_start, tangent * 0.38, tangent * 6.0, contact)
	_expect(contact.kind != Model.Contact.BOARD, "near tangent path has no false contact")

	var repeated := Model.Shot.new()
	repeated.velocity = -normal * 4.0
	contact.clear()
	contact.offer(0.5, Model.Contact.BOARD, Model.BOARD_A, normal)
	model._apply_contact(repeated, contact)
	repeated.velocity = -normal * 4.0
	model._apply_contact(repeated, contact)
	_expect(repeated.bounces == 2 and repeated.contacts_mask == 1, "repeated hits on one physical board cannot satisfy both bits")
	var soft := Model.Shot.new()
	soft.velocity = -normal * 0.14
	model._apply_contact(soft, contact)
	_expect(soft.bounces == 1 and soft.contacts_mask == 0, "low impact does not count as useful redirection")


func _wrong_pocket_discards_double_contact() -> void:
	var model := Model.new()
	_setup_double(model, 0)
	_expect(model.launch(), "launch two-board route toward an uncalled pocket")
	_advance_until_settled(model)
	var wrong := model.snapshot()
	_expect(wrong.contacts_mask == 3 and wrong.settled_pocket == 2 and wrong.sunk == 0 and wrong.misses == 1, "real double contact in wrong pocket cannot advance the called pocket")
	for index in 2:
		model.select(index)
		model.toggle_board()
	for slot in Model.POCKET_COUNT:
		var preset: Array = DIRECT[0][slot]
		_setup_aim(model, preset[0], preset[1])
		_expect(model.launch(), "launch direct recovery for %d" % slot)
		_advance_until_settled(model)
		_expect(model.snapshot().sunk == slot + 1 and model.snapshot().contacts_mask == 0, "new coin starts with no inherited board visits")
	var state := model.snapshot()
	_expect(state.success and not state.devil and state.shots == 4 and state.score == 3 * Model.POT_POINTS - Model.LOSS_POINTS, "the completed run discards the wrong pocket's double proof")


func _timing_and_participation() -> void:
	var model := Model.new()
	for _index in 600:
		model.step(0.25)
	_expect(model.snapshot().ended and not model.snapshot().ordinary_eligible and not model.launch(), "idle formal timeout never earns participation")
	model.reset(true, 1)
	_setup_aim(model, -65, 0)
	model.launch()
	_advance_until_settled(model)
	for _index in 620:
		model.step(0.25)
	_expect(model.snapshot().ended and model.snapshot().ordinary_eligible and not model.snapshot().success and not model.launch(), "assisted attempts qualify only after real travel inside the time limit")

	var slow := Model.new()
	var quick := Model.new()
	_setup_aim(slow, -65, 0)
	_setup_aim(quick, -65, 5)
	slow.launch()
	quick.launch()
	_advance_until_settled(slow)
	_advance_until_settled(quick)
	_expect(quick.snapshot().coin.distance_to(Model.LAUNCHER) > slow.snapshot().coin.distance_to(Model.LAUNCHER) + 1.0, "power changes physical range")

	var coarse := Model.new()
	var fine := Model.new()
	for simulator in [coarse, fine]:
		_setup_aim(simulator, -34, 2)
		simulator.launch()
	for _index in 14:
		coarse.step(0.1)
		for _split in 6:
			fine.step(1.0 / 60.0)
	_expect(coarse.snapshot() == fine.snapshot(), "equal simulated time yields identical state across update cadence")
	var before := coarse.snapshot()
	coarse.step(NAN)
	coarse.step(INF)
	coarse.step(-1.0)
	_expect(coarse.snapshot() == before, "non-finite and negative elapsed times ignored")


func _helpers_and_preview() -> void:
	var model := Model.new()
	model.reset(true, 0)
	var baseline := model.snapshot()
	_expect(baseline.preview.size() >= 2 and baseline.preview.size() <= 23 and baseline.preview[0] == Model.LAUNCHER, "bounded first-segment preview originates at launch")
	_expect(not model.assist_board(), "helper requires selected board")
	model.select(Model.BOARD_A)
	_expect(not model.assist_board(), "helper cannot place stowed board")
	model.toggle_board()
	model.select(Model.BOARD_B)
	model.toggle_board()
	model.select(Model.BOARD_A)
	var before := model.snapshot()
	var changed := model.assist_board()
	var after := model.snapshot()
	_expect(changed and absi(int(after.boards[0].detent) - int(before.boards[0].detent)) == 1 and before.boards[1] == after.boards[1]
		and before.aim == after.aim and before.power == after.power and after.shots == 0, "helper adjusts only the selected board one detent")
	model.select(Model.BOARD_B)
	_expect(model.snapshot().preview == after.preview and model.snapshot().shots == 0, "selection has no physical preview effect")

	model.reset(true, 0)
	_setup_double(model, 0)
	var assisted_preview: PackedVector2Array = model.snapshot().preview
	model.launch()
	_expect(model.snapshot().preview.is_empty(), "preview is hidden in flight")
	for _frame in 180:
		model.step(1.0 / 60.0)
		if model.snapshot().shot_bounces > 0:
			break
	var real := model.snapshot()
	_expect(real.shot_bounces == 1 and real.impact.distance_to(assisted_preview[-1]) < 0.001, "preview terminates at the same first genuine collision")


func _round(layout: int, assisted: bool, bank_shot: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	for called in Model.POCKET_COUNT:
		var wants_double := bank_shot and called == Model.POCKET_COUNT - 1
		if wants_double:
			_setup_double(model, layout)
		else:
			var preset: Array = DIRECT[layout][called]
			_setup_aim(model, preset[0], preset[1])
		var label := "layout %d assist %s pocket %d double %s" % [layout, assisted, called, wants_double]
		_expect(model.launch(), "launch %s" % label)
		_advance_until_settled(model)
		var state := model.snapshot()
		_expect(state.sunk == called + 1 and state.settled_pocket == called and state.pockets[called].filled, "capture %s" % label)
		if state.sunk != called + 1:
			print("Failed %s; settled %d, bounces %d, mask %d, rim %d, stop %s" % [
				label, state.settled_pocket, state.shot_bounces, state.contacts_mask, state.rim_scrapes, state.coin,
			])
			return
		var expected_mask := 3 if wants_double else 0
		_expect(state.contacts_mask == expected_mask and (not wants_double or state.shot_bounces >= 2), "genuine contact sequence for %s" % label)

	var result := model.snapshot()
	var expected_points := 3 * Model.POT_POINTS + int(bank_shot) * Model.DOUBLE_POINTS
	_expect(result.ended and result.success and result.ordinary_eligible and result.devil == bank_shot and result.score == expected_points and result.misses == 0,
		"three called holes, truthful awards and independent boards")


func _setup_double(model: RefCounted, layout: int) -> void:
	var spec: Array = DOUBLE_BANK[layout]
	_setup_aim(model, spec[0], spec[1])
	for index in 2:
		model.select(index)
		if not model.snapshot().boards[index].placed:
			model.toggle_board()
		var old: int = model.snapshot().boards[index].detent
		var change := int(spec[2 + index]) - old
		for _step_index in absi(change):
			model.adjust_angle(signi(change))


func _setup_aim(model: RefCounted, aim: int, power: int) -> void:
	model.select(Model.AIM)
	var current := model.snapshot() as Dictionary
	var angle_difference := aim - int(current.aim_degrees)
	for _index in absi(angle_difference):
		model.adjust_angle(signi(angle_difference))
	var power_difference := power - int(current.power)
	for _index in absi(power_difference):
		model.adjust_power(signi(power_difference))


func _advance_until_settled(model: RefCounted) -> void:
	for _frame in 660:
		model.step(1.0 / 60.0)
		if not model.snapshot().active:
			break


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)
