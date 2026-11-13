extends SceneTree
const Driver = preload("res://game/minigames/cargo_balance_driver.gd")
const View = preload("res://game/minigames/cargo_balance_view.gd")
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
	expect(state.variant == 0 and state.phase == "loading" and state.cursor == Vector2i(0, 0), "first voyage loads from the pier")
	expect(not key(driver, KEY_G), "unrelated key unconsumed")
	expect(not key(driver, KEY_D, true, true), "echo rejected")
	expect(driver.snapshot().cursor == Vector2i(0, 0), "echo never moves the hook")
	expect(key(driver, KEY_D) and driver.snapshot().cursor == Vector2i(1, 0), "D moves right once")
	key(driver, KEY_D)
	expect(driver.snapshot().cursor == Vector2i(1, 0), "a held key acts once")
	key(driver, KEY_D, false)
	tap(driver, KEY_W)
	expect(driver.snapshot().cursor == Vector2i(1, 1), "W lifts the hook a row")
	tap(driver, KEY_SPACE)
	expect(driver.snapshot().held == 4, "space lifts the top pier crate")
	for i in 3: tap(driver, KEY_RIGHT)
	tap(driver, KEY_DOWN)
	tap(driver, KEY_SPACE)
	expect(driver.snapshot().held < 0 and driver.snapshot().crates[4].cell == Vector2i(4, 0), "arrow keys and space set the crate in the hold")
	tap(driver, KEY_F)
	expect(driver.snapshot().crates[4].strap_timer >= 0.0, "F designates the crate for strapping")
	tap(driver, KEY_ENTER)
	expect(driver.snapshot().phase == "loading", "Enter refuses to sail with cargo ashore")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and driver.snapshot().port_order == ["B", "A"], "retry swaps weights and port order")
	expect(mouse(driver, View.button_rect("right").get_center(), true) and driver.snapshot().cursor == Vector2i(1, 0), "pointer button moves the hook")
	expect(mouse(driver, View.button_rect("right").get_center(), true) and driver.snapshot().cursor == Vector2i(1, 0), "held pointer acts once")
	expect(mouse(driver, Vector2(-999, -999), false), "release outside consumed")
	mouse(driver, View.button_rect("up").get_center(), true)
	mouse(driver, Vector2.ZERO, false)
	mouse(driver, View.button_rect("grab").get_center(), true)
	mouse(driver, Vector2.ZERO, false)
	expect(driver.snapshot().held == 4, "pointer grab uses the same rule")
	driver.clear_input()
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("移重"), "summary lists waves, crates, slides and the shift rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 1000:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "timeout ends truthfully")
	tap(driver, KEY_SPACE)
	expect(driver.snapshot().held == 4, "ended round ignores input")
	print("Cargo balance driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
