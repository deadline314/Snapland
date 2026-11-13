extends SceneTree
const Driver = preload("res://game/minigames/sail_chase_driver.gd")
const View = preload("res://game/minigames/sail_chase_view.gd")
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
	expect(state.variant == 0 and state.rudder == 0.0, "first chase starts with a neutral helm")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_D, true, true), "echo rejected")
	expect(driver.snapshot().rudder == 0.0, "echo never steers")
	key(driver, KEY_D)
	key(driver, KEY_RIGHT)
	key(driver, KEY_D, false)
	expect(driver.snapshot().rudder == 1.0, "alias keeps the helm held")
	key(driver, KEY_A)
	expect(driver.snapshot().rudder == 0.0, "opposing helm cancels")
	key(driver, KEY_A, false)
	key(driver, KEY_RIGHT, false)
	var trim: float = driver.snapshot().trim
	key(driver, KEY_E)
	driver.step(0.5)
	key(driver, KEY_E, false)
	expect(driver.snapshot().trim > trim, "holding E eases the sail out")
	key(driver, KEY_Q)
	driver.step(0.5)
	key(driver, KEY_Q, false)
	expect(driver.snapshot().trim < trim + 0.2, "holding Q sheets the sail in")
	key(driver, KEY_D)
	driver.clear_input()
	expect(driver.snapshot().rudder == 0.0 and driver.snapshot().trim_input == 0.0, "clear releases every owner")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1, "retry swaps the wind pattern")
	expect(mouse(driver, View.button_rect("left").get_center(), true) and driver.snapshot().rudder == -1.0, "pointer helm")
	key(driver, KEY_D)
	expect(driver.snapshot().rudder == 0.0, "pointer and keyboard combine")
	expect(mouse(driver, Vector2(-999, -999), false) and driver.snapshot().rudder == 1.0, "pointer release keeps keyboard owner")
	driver.clear_input()
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("換舷"), "summary lists catches, gybes, bumps and the gybe rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 700:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "timeout ends truthfully")
	key(driver, KEY_A)
	expect(driver.snapshot().rudder == 0.0, "ended round ignores input")
	print("Sail chase driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
