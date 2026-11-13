extends SceneTree
const Driver = preload("res://game/minigames/shell_tide_driver.gd")
const View = preload("res://game/minigames/shell_tide_view.gd")
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
func until_phase(driver, phase: String) -> void:
	for i in 4000:
		if driver.snapshot().phase == phase: return
		driver.step(1.0 / 120.0)
func _run() -> void:
	var driver = Driver.new()
	driver.reset(false, "noon")
	var state: Dictionary = driver.snapshot()
	for field in ["elapsed", "score", "mistakes", "ended", "success", "devil", "ordinary_eligible", "progress_text", "time_text", "feedback_text"]:
		expect(state.has(field), "normalized field: " + field)
	expect(state.variant == 0 and state.phase == "demo", "first round opens on the demo")
	expect(not key(driver, KEY_G), "unrelated key unconsumed")
	expect(not key(driver, KEY_1, true, true), "echo rejected")
	expect(key(driver, KEY_1) and driver.snapshot().held.has(0), "1 holds the first shell")
	key(driver, KEY_A)
	key(driver, KEY_1, false)
	expect(driver.snapshot().held.has(0), "A keeps the same shell held")
	key(driver, KEY_A, false)
	expect(not driver.snapshot().held.has(0), "the shell releases when its last key lifts")
	until_phase(driver, "echo")
	var events: Array = driver.snapshot().events
	for i in roundi((events[0].start + 0.02 - driver.snapshot().phase_time) * 120.0): driver.step(1.0 / 120.0)
	driver.consume_notes()
	key(driver, KEY_1)
	key(driver, KEY_1, false)
	expect(driver.snapshot().hits == 1 and Array(driver.consume_notes()) == [0], "an echoed shell is judged and sounds once")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and driver.snapshot().phrase == 0, "retry swaps tempo and silences")
	until_phase(driver, "ready")
	key(driver, KEY_W)
	key(driver, KEY_W, false)
	expect(driver.snapshot().slow, "W waits for the long wave")
	key(driver, KEY_Q)
	key(driver, KEY_Q, false)
	expect(driver.snapshot().offset == 0.0, "calibration refused without assistance")
	key(driver, KEY_2)
	driver.clear_input()
	expect(driver.snapshot().held.is_empty(), "clear releases every shell")
	driver.reset(true, "noon")
	key(driver, KEY_E)
	key(driver, KEY_E, false)
	expect(driver.snapshot().offset > 0.0, "assisted E calibrates later")
	expect(mouse(driver, View.SHELL_CENTERS[2], true) and driver.snapshot().held.has(2), "tapping a shell holds it")
	expect(mouse(driver, Vector2(-999, -999), false) and not driver.snapshot().held.has(2), "pointer release lets go")
	expect(mouse(driver, View.button_rect("shell_3").get_center(), true) and driver.snapshot().held.has(3), "shell buttons work too")
	mouse(driver, Vector2.ZERO, false)
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("靜默"), "summary lists hits, phrases, rests and the silence rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 700:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "silence through the round ends truthfully")
	key(driver, KEY_1)
	expect(driver.snapshot().held.is_empty(), "ended round ignores input")
	print("Shell tide driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
