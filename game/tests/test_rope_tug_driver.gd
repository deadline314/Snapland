extends SceneTree
const Driver = preload("res://game/minigames/rope_tug_driver.gd")
const View = preload("res://game/minigames/rope_tug_view.gd")
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
	expect(state.variant == 0 and not state.hooked, "first round: heavy pontoon, unhooked")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_SPACE, true, true), "echo rejected")
	expect(not driver.snapshot().hooked, "echo never hooks")
	expect(key(driver, KEY_SPACE) and driver.snapshot().hooked, "space hooks")
	key(driver, KEY_SPACE)
	expect(driver.snapshot().hooked, "held space acts once")
	key(driver, KEY_SPACE, false)
	key(driver, KEY_W)
	key(driver, KEY_UP)
	key(driver, KEY_W, false)
	expect(driver.snapshot().thrust == 1.0, "alias keeps thrust held")
	key(driver, KEY_S)
	expect(driver.snapshot().thrust == 0.0, "opposing throttle cancels")
	key(driver, KEY_S, false)
	key(driver, KEY_UP, false)
	key(driver, KEY_A)
	expect(driver.snapshot().turn == -1.0, "left rudder")
	key(driver, KEY_A, false)
	var before: float = driver.snapshot().rope_length
	key(driver, KEY_E)
	driver.step(0.5)
	key(driver, KEY_E, false)
	expect(driver.snapshot().rope_length > before, "holding E pays out")
	key(driver, KEY_Q)
	driver.step(0.2)
	expect(driver.snapshot().reel == -1.0, "holding Q reels in")
	driver.clear_input()
	expect(driver.snapshot().reel == 0.0 and driver.snapshot().thrust == 0.0, "clear releases every owner")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and not driver.snapshot().hooked, "retry alternates the pontoon")
	expect(mouse(driver, View.button_rect("ahead").get_center(), true) and driver.snapshot().thrust == 1.0, "pointer throttle")
	key(driver, KEY_S)
	expect(driver.snapshot().thrust == 0.0, "pointer and keyboard combine")
	expect(mouse(driver, Vector2(-999, -999), false) and driver.snapshot().thrust == -1.0, "pointer release keeps keyboard owner")
	driver.clear_input()
	mouse(driver, View.button_rect("hook").get_center(), true)
	mouse(driver, Vector2.ZERO, false)
	expect(driver.snapshot().hooked, "pointer hook uses the same rule")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 4 and summary.qualification_text.contains("側灣"), "summary lists bays, dock, breaks, snags and the side-bay rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 800:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "timeout ends truthfully")
	key(driver, KEY_W)
	expect(driver.snapshot().thrust == 0.0, "ended round ignores input")
	print("Rope tug driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
