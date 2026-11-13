extends SceneTree
const Driver = preload("res://game/minigames/lighthouse_prism_driver.gd")
const View = preload("res://game/minigames/lighthouse_prism_view.gd")
const Route = preload("res://game/tests/lighthouse_prism_route.gd")
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
	expect(state.variant == 0 and state.time_text == "120 秒", "first round uses the first fog and a timed clock")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_E, true, true), "echo rejected")
	expect(Route.state_of(driver.snapshot(), "p1") == 0, "echo never rotates")
	expect(key(driver, KEY_E), "rotate press consumed")
	expect(key(driver, KEY_E), "held repeat consumed")
	expect(Route.state_of(driver.snapshot(), "p1") == 1, "a held key rotates exactly once")
	key(driver, KEY_E, false)
	tap(driver, KEY_Q)
	expect(Route.state_of(driver.snapshot(), "p1") == 0, "Q rotates back")
	tap(driver, KEY_D)
	expect(driver.snapshot().selected == "m1", "D selects next")
	tap(driver, KEY_LEFT)
	expect(driver.snapshot().selected == "p1", "left selects previous")
	tap(driver, KEY_7)
	expect(driver.snapshot().selected == "g1", "number key selects directly")
	tap(driver, KEY_SPACE)
	expect(Route.state_of(driver.snapshot(), "g1") == 1, "space toggles the selected shutter")
	tap(driver, KEY_Z)
	expect(Route.state_of(driver.snapshot(), "g1") == 1 and driver.snapshot().feedback.contains("輔助"), "undo refused without assistance")
	var by_key: int = Route.state_of(driver.snapshot(), "g1")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and Route.state_of(driver.snapshot(), "g1") == 0, "retry alternates fog and restores the opening board")
	expect(mouse(driver, View.button_rect("next").get_center(), true), "pointer press consumed")
	expect(driver.snapshot().selected == "m1", "pointer selects next")
	expect(mouse(driver, View.button_rect("next").get_center(), true) and driver.snapshot().selected == "m1", "held pointer acts once")
	expect(mouse(driver, Vector2(-999, -999), false), "release outside consumed")
	tap(driver, KEY_7)
	mouse(driver, View.button_rect("rotate_right").get_center(), true)
	mouse(driver, Vector2.ZERO, false)
	expect(Route.state_of(driver.snapshot(), "g1") == by_key, "pointer and key share the same operation")
	driver.reset(true, "noon")
	expect(driver.snapshot().time_text == "無時限", "assistance shows no time limit")
	tap(driver, KEY_E)
	tap(driver, KEY_E)
	tap(driver, KEY_Z)
	expect(Route.state_of(driver.snapshot(), "p1") == 1, "assisted Z restores the previous orientation")
	tap(driver, KEY_ENTER)
	expect(not driver.snapshot().ended and driver.snapshot().armed == "settle", "early Enter warns first")
	tap(driver, KEY_KP_ENTER)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "second Enter settles truthfully")
	tap(driver, KEY_E)
	expect(Route.state_of(driver.snapshot(), "p1") == 1, "ended round ignores input")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("小惡魔"), "summary lists beacons, side and split rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	driver.reset(false, "noon")
	for i in 600:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().time_text == "0 秒", "timed round ends at zero")
	print("Lighthouse prism driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
