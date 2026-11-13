extends SceneTree
const Driver = preload("res://game/minigames/tide_lock_driver.gd")
const View = preload("res://game/minigames/tide_lock_view.gd")
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
func tap(driver, code: Key) -> void:
	key(driver, code)
	key(driver, code, false)
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
	expect(state.variant == 0 and state.progress_text.contains("0／3"), "first round shows ships passed")
	expect(not key(driver, KEY_G), "unrelated key unconsumed")
	expect(not key(driver, KEY_Q, true, true), "echo rejected")
	key(driver, KEY_Q)
	expect(driver.snapshot().lower_open, "Q opens the lower gate")
	key(driver, KEY_Q)
	expect(driver.snapshot().lower_open, "a held key does not toggle twice")
	key(driver, KEY_Q, false)
	tap(driver, KEY_Q)
	expect(not driver.snapshot().lower_open, "next press closes it")
	tap(driver, KEY_D)
	expect(driver.snapshot().valve == 1, "D fills")
	tap(driver, KEY_A)
	expect(driver.snapshot().valve == -1, "A switches to draining")
	tap(driver, KEY_E)
	expect(not driver.snapshot().upper_open, "E refuses while the level differs")
	tap(driver, KEY_R)
	expect(driver.snapshot().helper, "R puts the gatekeeper on duty")
	expect(mouse(driver, View.button_rect("drain").get_center(), true) and driver.snapshot().valve == 0, "drain button toggles the valve")
	mouse(driver, View.button_rect("drain").get_center(), false)
	expect(not mouse(driver, Vector2(640, 380), true), "the section view is not a button")
	key(driver, KEY_D)
	driver.clear_input()
	key(driver, KEY_D)
	expect(driver.snapshot().valve == 0, "after clear a fresh press toggles again")
	key(driver, KEY_D, false)
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and driver.snapshot().ships[0].name != "藍篷漁船", "retry changes ships and tide")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 5 and summary.qualification_text.contains("一次蓄水"), "summary lists ships, close, pair, groundings, horns and the devil rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 800:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "idle round ends truthfully")
	tap(driver, KEY_Q)
	expect(not driver.snapshot().lower_open, "ended round ignores input")
	print("Tide lock driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
