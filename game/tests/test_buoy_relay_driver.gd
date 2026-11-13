extends SceneTree
const Driver = preload("res://game/minigames/buoy_relay_driver.gd")
const View = preload("res://game/minigames/buoy_relay_view.gd")
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
	expect(state.variant == 0 and state.phase == "aim_catch", "first round aims from the outer buoy")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_SPACE, true, true), "echo rejected")
	expect(not driver.snapshot().charging, "echo never charges")
	expect(key(driver, KEY_SPACE) and driver.snapshot().charging, "space starts a charge")
	key(driver, KEY_W)
	driver.step(0.2)
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().charging, "a second held action key keeps charging")
	key(driver, KEY_W, false)
	expect(driver.snapshot().phase == "ring_flight", "releasing the last action key throws once")
	key(driver, KEY_SPACE)
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().phase == "ring_flight", "no second throw while the ring flies")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and driver.snapshot().phase == "aim_catch", "retry swaps the tide")
	key(driver, KEY_SPACE)
	driver.step(0.3)
	driver.clear_input()
	expect(not driver.snapshot().charging and driver.snapshot().ring.is_empty(), "lifecycle clear cancels a charge without throwing")
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().phase == "aim_catch", "a stale release after clearing cannot throw")
	expect(mouse(driver, View.button_rect("action").get_center(), true) and driver.snapshot().charging, "pointer hold charges")
	expect(mouse(driver, Vector2(-999, -999), false) and driver.snapshot().phase == "ring_flight", "pointer release throws")
	driver.reset(true, "noon")
	key(driver, KEY_SPACE)
	driver.step(0.2)
	expect(driver.snapshot().show_landing and is_finite(driver.snapshot().throw_preview), "assist previews the landing")
	key(driver, KEY_SPACE, false)
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("兩個郵筒"), "summary lists tubes, skips, slips and the double rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 700:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "timeout ends truthfully")
	key(driver, KEY_SPACE)
	expect(not driver.snapshot().charging, "ended round ignores input")
	print("Buoy relay driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
