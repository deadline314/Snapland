extends SceneTree

const Model = preload("res://game/minigames/sign_balance_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_predictable_gusts_and_full_precision_route()
	_test_wrong_correction_causes_real_impacts()
	_test_recovery_after_single_impact()
	_test_five_stage_ordinary_threshold()
	_test_assist_and_timeout()
	_test_snapshot_reuse_and_reset()
	_test_large_delta_is_bounded()
	if failures == 0:
		print("Sign balance model: %d checks passed" % checks)
		quit(0)
	else:
		push_error("Sign balance model: %d check(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_predictable_gusts_and_full_precision_route() -> void:
	var model = Model.new()
	model.reset()
	var initial: Dictionary = model.snapshot()
	_expect(bool(initial.forecast_visible) and int(initial.wind_direction) == 1 and is_zero_approx(float(initial.wind_torque)), "first pennant previews a rightward gust before force begins")
	_expect(int(initial.completed_stage_count) == 0, "no stage is complete before the first boundary")
	for completed_count in range(1, Model.STAGE_COUNT + 1):
		_drive(model, completed_count, true)
		_expect(int(model.snapshot().completed_stage_count) == completed_count, "snapshot reports exactly %d completed ledger entries" % completed_count)
	var result: Dictionary = model.snapshot()
	_expect(result.ended and result.success and result.devil_success, "feedback-controlled counterweight stabilizes all seven wind stages cleanly")
	_expect(result.safe_stages == 7 and result.precise_stages == 7 and result.impacts == 0 and result.score == 700, "seven precision stages map to 700 and no impact")
	_expect(result.stage_results.size() == 7, "all seven staged outcomes remain available for result reporting")
	for stage_result in result.stage_results:
		_expect(stage_result.passed and stage_result.precise, "every recorded stage reflects sustained precise stability")

func _test_wrong_correction_causes_real_impacts() -> void:
	var model = Model.new()
	model.reset()
	var guard := 0
	while not model.ended and guard < 800:
		var state: Dictionary = model.snapshot()
		var direction := int(state.wind_direction)
		model.set_balance(float(direction))
		model.step(0.025)
		guard += 1
	_expect(model.impacts >= 3 and model.ended and not model.success, "weight moved with the forecast gust crosses the safety line and ends after three real impacts")
	_expect(int(model.snapshot().completed_stage_count) == int(model.snapshot().stage) and int(model.snapshot().completed_stage_count) < Model.STAGE_COUNT, "three early impacts report only prior completed stage boundaries")
	_expect(model.last_event.contains("三次"), "third impact explains why the sign challenge ended")

func _test_recovery_after_single_impact() -> void:
	var model = Model.new()
	model.reset()
	var guard := 0
	while model.impacts == 0 and guard < 500:
		model.set_balance(float(Model.WIND_DIRECTIONS[model.stage]))
		model.step(0.01)
		guard += 1
	_expect(model.impacts == 1 and not model.ended, "one severe wrong-way correction records a recoverable impact")
	_drive(model, 7, true)
	_expect(not model.ended or model.impacts == 1, "closed-loop counterweight moves the sign back through the reset zone without repeating the same collision")
	_expect(model.ended and model.success and model.impacts == 1 and not model.devil_success, "recovery enables ordinary finish while the recorded impact correctly denies devil")

func _test_five_stage_ordinary_threshold() -> void:
	var model = Model.new()
	model.reset()
	var guard := 0
	while not model.ended and guard < 5000:
		if model.stage < 5:
			_drive_input(model)
		else:
			model.set_balance(float(Model.WIND_DIRECTIONS[model.stage]))
		model.step(0.01)
		guard += 1
	_expect(model.ended and model.safe_stages >= 5 and model.success, "five truly stable stages meet ordinary completion even when the remaining stages are missed")
	_expect(not model.devil_success and model.score < 700, "ordinary completion cannot be mistaken for seven precise stages")

func _test_assist_and_timeout() -> void:
	var assisted = Model.new()
	assisted.reset(true)
	_drive(assisted, 7, true)
	_expect(assisted.success and assisted.safe_stages == 7 and assisted.precise_stages == 7, "assist lowers gust strength but still requires the controller to hold the moving board in its narrow band")
	var unattended = Model.new()
	unattended.reset(true)
	while not unattended.ended:
		unattended.step(0.025)
	_expect(not unattended.success or unattended.safe_stages < 5, "assist never grants ordinary success when the player does not move the counterweight")
	var timed = Model.new()
	timed.reset()
	timed.elapsed = Model.ROUND_SECONDS - 0.01
	timed.step(0.025)
	_expect(timed.ended and timed.timed_out, "60 second safety deadline is enforced even if stages have not advanced")
	_expect(timed.stage < Model.STAGE_COUNT and not timed.success, "timeout cannot claim completion merely from the clock")
	_expect(int(timed.snapshot().completed_stage_count) == 0, "timeout before any stage boundary reports zero completed ledger entries")

func _test_snapshot_reuse_and_reset() -> void:
	var model = Model.new()
	model.reset()
	var stable_view: Dictionary = model.snapshot()
	var results_ref: Array = stable_view.stage_results
	var before := float(stable_view.elapsed)
	model.step(0.05)
	_expect(stable_view.elapsed > before and is_equal_approx(float(stable_view.elapsed), model.elapsed), "snapshot dictionary is reused and its scalar fields update in place on each step")
	_expect(stable_view.stage_results.size() == 7 and results_ref.size() == 7, "nested stage-results view is retained through ordinary clock updates")
	model.set_balance(0.75)
	_expect(is_equal_approx(float(stable_view.balance), 0.75), "input updates the same snapshot without allocating a replacement")
	model.reset(true)
	_expect(model.snapshot().assisted and model.snapshot().elapsed == 0.0 and model.snapshot().stage == 0 and model.snapshot().balance == 0.0, "retry reset restores clean assisted state and stage")
	_expect(model.snapshot().stage_results.size() == 7 and model.snapshot().safe_stages == 0 and model.snapshot().score == 0, "retry clears prior stage outcomes and score")

func _test_large_delta_is_bounded() -> void:
	var model = Model.new()
	model.reset()
	model.step(1000000.0)
	_expect(is_equal_approx(model.elapsed, Model.MAX_FRAME_DELTA), "a pathological frame hitch advances only the bounded catch-up window")
	_expect(model.elapsed < 1.0 and not model.ended, "large input delta cannot cause an unbounded simulation loop or instant timeout")

func _drive(model, stage_limit: int, precise: bool) -> void:
	var guard := 0
	while not model.ended and model.stage < stage_limit and guard < 6000:
		_drive_input(model, precise)
		model.step(0.01)
		guard += 1
	_expect(guard < 6000, "closed-loop counterweight route stays within deterministic guard")

func _drive_input(model, precise: bool = true) -> void:
	var state: Dictionary = model.snapshot()
	var target := float(state.target_angle)
	var torque := float(state.wind_torque)
	if bool(state.forecast_visible):
		torque = float(state.forecast_torque)
	var error := float(model.angle) - target
	var desired_accel: float = (-8.0 if precise else -5.0) * error - (4.0 if precise else 2.5) * model.angular_velocity
	var restoring: float = -Model.RESTORE_TORQUE * error
	var balance: float = (desired_accel - torque - restoring + Model.ANGULAR_DAMPING * model.angular_velocity) / Model.COUNTERWEIGHT_TORQUE
	model.set_balance(clampf(balance, -1.0, 1.0))
