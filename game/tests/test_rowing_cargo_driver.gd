extends SceneTree
const Driver = preload("res://game/minigames/rowing_cargo_driver.gd")
const View = preload("res://game/minigames/rowing_cargo_view.gd")
const Solver = preload("res://game/tests/test_rowing_cargo.gd")
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
	expect(not state.ordinary_eligible and not state.ended, "fresh round has no eligibility")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_W, true, true), "echo rejected")
	expect(driver.snapshot().velocity == Vector2.ZERO, "echo never strokes")
	expect(key(driver, KEY_W) and key(driver, KEY_W, false), "stroke press and release consumed")
	expect(driver.snapshot().velocity.x > 0, "stroke reaches model")
	driver.reset(false, "dawn")
	key(driver, KEY_A)
	key(driver, KEY_LEFT)
	key(driver, KEY_A, false)
	expect(driver.snapshot().rudder == -1, "alias remains held")
	key(driver, KEY_D)
	expect(driver.snapshot().rudder == 0, "opposing rudders cancel")
	key(driver, KEY_D, false)
	expect(driver.snapshot().rudder == -1, "opposing release restores held direction")
	var right: Vector2 = View.button_rect("right").get_center()
	expect(mouse(driver, right, true), "pointer press consumed")
	expect(driver.snapshot().rudder == 0, "pointer and keyboard ownership combine")
	expect(mouse(driver, Vector2(-999, -999), false), "release outside consumed")
	expect(driver.snapshot().rudder == -1, "pointer release preserves keyboard owner")
	driver.clear_input()
	expect(driver.snapshot().rudder == 0, "clear releases all owners")
	driver.reset(false, "noon")
	mouse(driver, View.button_rect("stroke").get_center(), true)
	var pointer_velocity: Vector2 = driver.snapshot().velocity
	mouse(driver, Vector2.ZERO, false)
	driver.reset(false, "noon")
	key(driver, KEY_UP)
	expect(driver.snapshot().velocity == pointer_velocity, "pointer and key use identical stroke")
	driver.reset(false, "noon")
	key(driver, KEY_S)
	expect(driver.snapshot().velocity.x < 0, "reverse key brakes along heading")
	driver.reset(false, "noon")
	key(driver, KEY_Q)
	expect(driver.snapshot().velocity.y < 0, "left slip key reaches model")
	driver.reset(false, "noon")
	mouse(driver, View.button_rect("slip_right").get_center(), true)
	expect(driver.snapshot().velocity.y > 0, "right slip pointer reaches same digital model command")
	driver.reset(false, "noon")
	key(driver, KEY_SPACE)
	expect(driver.snapshot().carrying == "crate-1", "space interacts with actual nearby cargo")
	expect("第1箱" in driver.snapshot().feedback_text and not "crate-" in driver.snapshot().feedback_text, "player feedback uses cargo number, preserving canonical model identity")
	driver.reset(false, "noon")
	mouse(driver, View.button_rect("interact").get_center(), true)
	expect(driver.snapshot().carrying == "crate-1", "pointer interact has identical cargo effect")
	for delta in [NAN, INF, -1.0, 0.0]:
		driver.step(delta)
	expect(driver.snapshot().elapsed == 0, "invalid time ignored by sole model clock")
	driver.step(0.1)
	state = driver.snapshot()
	for i in 5:
		driver.present("night", true)
	expect(driver.snapshot() == state, "presentation does not advance simulation")
	var view = driver.create_view()
	if DisplayServer.get_name() == "headless":
		expect(view == null, "headless driver does not create renderer")
	else:
		expect(view == driver.create_view(), "one view reused")
		get_root().add_child(view)
		await process_frame
		driver.clear_input()
		view.command_requested.emit("right", true, "mouse")
		expect(driver.snapshot().rudder == 1, "view signal uses driver ownership")
		key(driver, KEY_D)
		view._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		expect(driver.snapshot().rudder == 0, "focus loss clears keyboard and pointer owners")
		key(driver, KEY_A)
		view.queue_free()
		await process_frame
		expect(driver.snapshot().rudder == 0, "view exit clears held input")
	for i in 1000:
		driver.step(0.25)
	state = driver.snapshot()
	expect(state.ended and not state.success and state.ordinary_eligible, "natural timeout normalized truthfully")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.total == 0 and summary.rows[0].count == 0 and "普通" in summary.qualification_text, "timeout summary has real deliveries")
	expect("練習" in driver.score_summary(true).qualification_text, "practice summary suppresses qualification")
	driver.reset(true, "noon")
	Solver.solve(driver._model)
	state = driver.snapshot()
	summary = driver.score_summary(false)
	expect(state.success and state.devil and state.ordinary_eligible, "assisted actual route preserves devil")
	expect(summary.total == 300 and summary.rows[0].count == 3, "summary counts three actual identities")
	print("Rowing driver: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
