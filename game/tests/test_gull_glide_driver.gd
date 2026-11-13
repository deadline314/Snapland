extends SceneTree
const Driver = preload("res://game/minigames/gull_glide_driver.gd")
const View = preload("res://game/minigames/gull_glide_view.gd")
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
	expect(state.variant == 0 and state.progress_text.contains("0／3"), "first round shows the feather count")
	expect(not key(driver, KEY_G), "unrelated key unconsumed")
	expect(not key(driver, KEY_SPACE, true, true), "echo rejected")
	expect(key(driver, KEY_SPACE) and driver.snapshot().tucked, "Space holds tuck")
	key(driver, KEY_S)
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().tucked, "S keeps the wings tucked")
	expect(mouse(driver, View.button_rect("tuck").get_center(), true), "tuck button consumed")
	key(driver, KEY_S, false)
	expect(driver.snapshot().tucked, "pointer keeps tuck after keys lift")
	mouse(driver, Vector2(-999, -999), false)
	expect(not driver.snapshot().tucked, "last release spreads the wings")
	expect(mouse(driver, Vector2(400, 380), true) and driver.snapshot().tucked, "holding the flight stage tucks")
	mouse(driver, Vector2(400, 380), false)
	expect(not mouse(driver, Vector2(1200, 400), true), "the height meter is not a tuck target")
	key(driver, KEY_DOWN)
	driver.clear_input()
	expect(not driver.snapshot().tucked, "clear spreads the wings")
	key(driver, KEY_DOWN, false)
	driver.step(0.5)
	expect(driver.snapshot().elapsed > 0.0 and driver.snapshot().time_text.ends_with("秒"), "step advances the model clock")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1, "retry swaps the course")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 4 and summary.qualification_text.contains("岩縫"), "summary lists feathers, home, gap, falls and the devil rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 600:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "spread-only round ends truthfully")
	key(driver, KEY_SPACE)
	expect(not driver.snapshot().tucked, "ended round ignores input")
	print("Gull glide driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
