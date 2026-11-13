extends SceneTree
const Driver = preload("res://game/minigames/crab_marbles_driver.gd")
const View = preload("res://game/minigames/crab_marbles_view.gd")
const Model = preload("res://game/minigames/crab_marbles_model.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func key(driver, code: Key, pressed := true, echo := false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return driver.handle_input(event, Vector2.ZERO)
func mouse(driver, point: Vector2, pressed: bool) -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return driver.handle_input(event, point)
func _run() -> void:
	var driver = Driver.new()
	driver.reset(false, "noon")
	var state: Dictionary = driver.snapshot()
	for field in ["elapsed", "score", "mistakes", "ended", "success", "devil", "ordinary_eligible", "progress_text", "time_text", "feedback_text"]:
		expect(state.has(field), "normalized field: " + field)
	expect(state.variant == 0 and state.balls_left == 3, "first round: east slopes, three marbles")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_SPACE, true, true), "echo rejected")
	expect(not driver.snapshot().charging, "echo never charges")
	key(driver, KEY_D)
	driver.step(0.5)
	expect(driver.snapshot().aim > 0.0, "held D aims right")
	key(driver, KEY_RIGHT)
	key(driver, KEY_D, false)
	var aim: float = driver.snapshot().aim
	driver.step(0.2)
	expect(driver.snapshot().aim > aim, "alias keeps aim held")
	key(driver, KEY_A)
	aim = driver.snapshot().aim
	driver.step(0.2)
	expect(driver.snapshot().aim == aim, "opposing aim cancels")
	key(driver, KEY_A, false)
	key(driver, KEY_RIGHT, false)
	expect(key(driver, KEY_SPACE) and driver.snapshot().charging, "space starts charging")
	key(driver, KEY_W)
	driver.step(0.3)
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().charging and not driver.snapshot().ball_active, "a second held charge key keeps charging")
	key(driver, KEY_W, false)
	expect(driver.snapshot().ball_active and driver.snapshot().balls_left == 2, "releasing the last charge key fires once")
	key(driver, KEY_SPACE)
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().balls_left == 2, "no second marble while one rolls")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and driver.snapshot().balls_left == 3, "retry swaps the layout and refills marbles")
	key(driver, KEY_SPACE)
	driver.step(0.2)
	driver.clear_input()
	expect(not driver.snapshot().charging and driver.snapshot().balls_left == 3, "lifecycle clear cancels a charge without firing")
	expect(mouse(driver, View.button_rect("charge").get_center(), true) and driver.snapshot().charging, "pointer hold charges")
	expect(mouse(driver, Vector2(-999, -999), false) and driver.snapshot().ball_active, "pointer release fires")
	driver.reset(true, "noon")
	expect(driver.snapshot().balls_left == Model.ASSIST_BALLS and driver.snapshot().first_segment.size() == 2, "assist adds marbles and the first segment")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("反彈"), "summary lists gates, spares, shots and the bounce rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 600:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "timeout ends truthfully")
	key(driver, KEY_SPACE)
	expect(not driver.snapshot().charging, "ended round ignores input")
	print("Crab marbles driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
