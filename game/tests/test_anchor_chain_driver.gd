extends SceneTree
const Driver = preload("res://game/minigames/anchor_chain_driver.gd")
const View = preload("res://game/minigames/anchor_chain_view.gd")
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
	expect(state.variant == 0 and state.progress_text.contains("90°"), "first round shows the turn still needed")
	expect(not key(driver, KEY_G), "unrelated key unconsumed")
	expect(not key(driver, KEY_E, true, true), "echo rejected")
	key(driver, KEY_E)
	key(driver, KEY_D)
	expect(driver.snapshot().selected == 2, "E and D each select once per press")
	key(driver, KEY_E, false)
	key(driver, KEY_D, false)
	tap(driver, KEY_Q)
	tap(driver, KEY_LEFT)
	expect(driver.snapshot().selected == 0, "Q and left step back")
	tap(driver, KEY_F)
	expect(driver.snapshot().wraps == [0], "F wraps the selected reef")
	tap(driver, KEY_Z)
	expect(driver.snapshot().wraps == [0], "Z undo is assist-only")
	for i in 3: tap(driver, KEY_E)
	tap(driver, KEY_F)
	expect(driver.snapshot().anchor == 0, "F drops the anchor at a spot")
	key(driver, KEY_SPACE)
	mouse(driver, View.button_rect("reel").get_center(), true)
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().reeling, "pointer keeps reeling after the key lifts")
	mouse(driver, Vector2(-999, -999), false)
	expect(not driver.snapshot().reeling, "last release stops reeling")
	key(driver, KEY_SPACE)
	driver.clear_input()
	expect(not driver.snapshot().reeling, "clear stops reeling")
	key(driver, KEY_SPACE, false)
	tap(driver, KEY_R)
	expect(driver.snapshot().helper == 1, "R sets the deckhand rudder")
	tap(driver, KEY_X)
	expect(driver.snapshot().anchor < 0 and driver.snapshot().wraps.is_empty(), "X recalls the chain")
	expect(mouse(driver, View.button_rect("place").get_center(), true) and driver.snapshot().anchor == 0, "place button acts on the selection")
	mouse(driver, View.button_rect("place").get_center(), false)
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1 and driver.snapshot().channel == "西", "retry mirrors the stranding")
	driver.reset(true, "noon")
	tap(driver, KEY_F)
	tap(driver, KEY_Z)
	expect(driver.snapshot().wraps.is_empty(), "assisted Z steps back a wrap")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.qualification_text.contains("同一顆礁石"), "summary lists freeing, double turn, breaks and the devil rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 700:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "idle round ends truthfully")
	tap(driver, KEY_E)
	expect(driver.snapshot().selected == 0, "ended round ignores input")
	print("Anchor chain driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
