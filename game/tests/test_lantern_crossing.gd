extends SceneTree

const Model = preload("res://game/minigames/lantern_crossing_model.gd")
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_controls_and_guard()
	_collision_and_recovery()
	_proof_belongs_to_current_lantern()
	_precise_swept_collision()
	_timestep_cadence()
	for layout in 2:
		_round(layout, false, false)
		_round(layout, false, true)
		_round(layout, true, false)
		_round(layout, true, true)
	print("Lantern crossing model: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("PASS: lantern crossing controls, pendulum clearance and four hooks")
	quit(int(_failures != 0))


func _controls_and_guard() -> void:
	var model := Model.new()
	var initial := model.snapshot()
	_expect(initial.hooks.size() == 4 and not initial.sign.has_area() and initial.can_load, "four hooks and clear first approach")
	_expect(not model.toggle_brake() and not model.recover() and not model.toggle_helper(), "unladen brake and normal helper do not begin transport")
	_expect(not model.select_endpoint(-1) and not model.adjust_endpoint(2), "unrecognized inputs rejected")
	_expect(model.interact() and model.snapshot().loaded and not model.interact(), "pick up a lantern and reject an early hook")
	_heights(model, 7, 2)
	_advance(model, 0.5)
	var high := model.snapshot()
	_expect(high.height_left == 7 and high.height_right == 2 and high.rope_left.y < high.rope_right.y, "left hoist changes independently")
	_expect(high.trolley.x == initial.trolley.x and high.velocity == 0.0, "brake holds the trolley during hoisting")
	model.toggle_brake()
	_advance(model, 0.65)
	var moving := model.snapshot()
	_expect(moving.velocity > 0.0 and moving.trolley.x > initial.trolley.x and moving.swing < 0.0, "slope drives the trolley and lamp initially lags")
	model.toggle_brake()
	_advance(model, 0.65)
	var stopped := model.snapshot()
	_expect(stopped.braking and stopped.velocity == 0.0 and stopped.trolley.x > moving.trolley.x, "braking decelerates rather than teleporting")

	model.reset(false, 0)
	for _index in 600:
		model.step(0.25)
	_expect(model.snapshot().ended and not model.snapshot().ordinary_eligible and model.snapshot().score == 0, "idle timeout is ineligible")
	_expect(not model.interact() and not model.toggle_brake() and not model.adjust_endpoint(1), "ending freezes controls")
	model.reset(false, 0)
	model.interact()
	_heights(model, 7, 4)
	model.toggle_brake()
	_advance(model, 2.5)
	for _index in 600:
		model.step(0.25)
	_expect(model.snapshot().ended and model.snapshot().ordinary_eligible and not model.snapshot().success, "real loaded travel qualifies as participation")

	model.reset(true, 1)
	_expect(model.toggle_helper() and model.snapshot().helper_endpoint == Model.RIGHT, "helper holds the opposite end")
	_heights(model, 4, 2, false)
	_advance(model, 0.4)
	var held := model.snapshot()
	_expect(held.height_left == 4 and held.height_right == 2 and held.helper_endpoint == Model.RIGHT, "helper holding a fixed height never alters the other detent")
	_expect(model.select_endpoint(Model.RIGHT) and model.snapshot().helper_endpoint == -1, "explicit control take-over releases helper")
	_expect(model.adjust_endpoint(-1) and model.snapshot().height_right == 1, "the player can operate the reclaimed hoist")


func _collision_and_recovery() -> void:
	var model := Model.new()
	_expect(_hang_at_target(model) and _hang_at_target(model), "two early jobs hang normally")
	var ahead := model.snapshot()
	_expect(ahead.job == 2 and ahead.hung == 2 and ahead.sign.has_area(), "third job introduces actual sign collision geometry")
	model.interact()
	_heights(model, 2, 0)
	_advance(model, 0.5)
	model.toggle_brake()
	_advance(model, 7.0)
	var crashed := model.snapshot()
	_expect(crashed.stalled and crashed.braking and crashed.mistakes == 1 and not crashed.swing_proven and not crashed.can_hook, "contact stalls the lamp and records only one loss")
	_expect(not model.interact() and not model.adjust_endpoint(1), "stalled carrier cannot hang or hoist")
	_expect(model.recover(), "recovery after actual contact")
	var recovered := model.snapshot()
	_expect(recovered.hung == 2 and recovered.job == 2 and recovered.mistakes == 1 and not recovered.loaded and not recovered.stalled, "retry preserves prior hung lamps without charging a second loss")
	_expect(recovered.trolley.x == ahead.trolley.x and recovered.swing == 0.0, "recovery resets trolley pose")
	_expect(_hang_at_target(model) and _hang_at_target(model), "two safe paths after recovery")
	var result := model.snapshot()
	_expect(result.success and not result.devil and result.score == 4 * Model.LAMP_POINTS - Model.LOSS_POINTS, "recovered safe run scores exactly one collision loss")


func _proof_belongs_to_current_lantern() -> void:
	var model := Model.new()
	_expect(_hang_at_target(model) and _hang_at_target(model), "approach tricky third hook")
	_expect(_move_to_target(model, true) and model.snapshot().swing_proven, "moving proof exists before hanging")
	_expect(not model.snapshot().devil and model.recover() and not model.snapshot().swing_proven, "recovering discards uncommitted proof")
	_expect(_hang_at_target(model) and _hang_at_target(model), "safely rehang recovered lamp and complete round")
	_expect(model.snapshot().success and not model.snapshot().devil and model.snapshot().mistakes == 1, "abandoned trick cannot award card to replacement lantern")


func _precise_swept_collision() -> void:
	var model := Model.new()
	var sign := Rect2(0.44, 0.42, 0.06, 0.16)
	_expect(model._sweep_hits_sign(Vector2(0.34, 0.43), Vector2(0.62, 0.43), sign), "fast body sweep catches the sign between safe endpoints")
	var corner := sign.position - Vector2(0.020, 0.020)
	_expect(not model._sweep_hits_sign(corner, corner, sign), "rounded hit test accepts outside corner with square expansion overlap")
	_expect(not model._sweep_hits_sign(Vector2(0.30, 0.37), Vector2(0.74, 0.37), sign), "swept clearance over the sign does not imply upright collision")


func _timestep_cadence() -> void:
	var coarse := Model.new()
	var fine := Model.new()
	for model in [coarse, fine]:
		model.interact()
		_heights(model, 8, 1)
		model.toggle_brake()
	for _frame in 12:
		coarse.step(0.1)
		for _split in 6:
			fine.step(1.0 / 60.0)
	_expect(coarse.snapshot() == fine.snapshot(), "fixed step produces identical state for equivalent update schedules")
	var before := coarse.snapshot()
	coarse.step(NAN)
	coarse.step(INF)
	coarse.step(-1.0)
	_expect(coarse.snapshot() == before, "invalid frame times ignored")


func _round(layout: int, assisted: bool, with_swing: bool) -> void:
	var model := Model.new()
	model.reset(assisted, layout)
	var challenge_job := 2 if layout == 0 else 3
	for job in Model.LAMP_COUNT:
		var swing_route := with_swing and job == challenge_job
		var label := "layout %d assist %s job %d swing %s" % [layout, assisted, job, swing_route]
		_expect(_hang_at_target(model, swing_route), "complete %s" % label)
		if model.snapshot().hung != job + 1:
			print("Route diagnostic %s %s" % [label, model.snapshot()])
			return
	var state := model.snapshot()
	_expect(state.ended and state.success and state.ordinary_eligible and state.hung == 4, "all four delivered and eligible")
	_expect(state.devil == with_swing and state.mistakes == 0 and state.score == 4 * Model.LAMP_POINTS + int(with_swing) * Model.SWING_POINTS, "actual challenge and safe route award distinct honest scores")


func _hang_at_target(model: RefCounted, use_swing := false) -> bool:
	return _move_to_target(model, use_swing) and model.interact()


func _move_to_target(model: RefCounted, use_swing: bool) -> bool:
	var state: Dictionary = model.snapshot()
	var rightward: bool = state.job % 2 == 0
	var direction := 1.0 if rightward else -1.0
	var left_height := 8 if rightward else 7
	var right_height := 7 if rightward else 8
	if use_swing:
		left_height = 5 if rightward else 2
		right_height = 2 if rightward else 5
	if not model.interact():
		return false
	_heights(model, left_height, right_height)
	if state.assisted:
		model.select_endpoint(Model.LEFT if rightward else Model.RIGHT)
		model.toggle_helper()
	_advance(model, 0.65)
	model.toggle_brake()
	var target: Vector2 = state.target
	for _frame in 750:
		state = model.snapshot()
		if state.stalled:
			return false
		var projected_stop: float = state.velocity * state.velocity / (2.0 * Model.BRAKE_DECELERATION)
		var remaining: float = direction * (target.x - state.trolley.x)
		if remaining <= maxf(projected_stop, 0.002):
			break
		model.step(1.0 / 60.0)
	model.toggle_brake()
	var goal_height := roundi((Model.ROPE_BASE_Y + Model.CLIP_LENGTH - target.y) / Model.HEIGHT_STEP)
	_heights(model, goal_height, goal_height)
	_advance(model, 2.7)
	state = model.snapshot()
	return state.swing_proven == use_swing and state.can_hook


func _heights(model: RefCounted, left: int, right: int, include_right := true) -> void:
	model.select_endpoint(Model.LEFT)
	var old_left: int = model.snapshot().height_left
	for _step in absi(left - old_left):
		model.adjust_endpoint(1 if left > old_left else -1)
	if include_right:
		model.select_endpoint(Model.RIGHT)
		var old_right: int = model.snapshot().height_right
		for _step in absi(right - old_right):
			model.adjust_endpoint(1 if right > old_right else -1)


func _advance(model: RefCounted, seconds: float) -> void:
	for _frame in roundi(seconds * 60.0):
		model.step(1.0 / 60.0)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)
