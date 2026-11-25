extends SceneTree

const Driver = preload("res://game/minigames/rain_courier_driver.gd")
const Model = preload("res://game/minigames/rain_courier_model.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const View = preload("res://game/minigames/rain_courier_view.gd")
const OFF_SURFACE := Vector2(-12, 820)

var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Rain courier driver test requires an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	test_controls()
	test_gamepad()
	test_scoring()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: rain courier keyboard, mouse, touch, gamepad and score breakdown")
	quit(int(not _errors.is_empty()))

func test_controls() -> void:
	var driver := Driver.new()
	driver.reset(false, "night")
	check(keyboard(driver, KEY_D, true) and driver.snapshot().route == Model.COVERED,
		"physical keyboard chooses the canopy route")
	keyboard(driver, KEY_D, false)
	check(keyboard(driver, KEY_A, true) and driver.snapshot().route == Model.SHORT,
		"keyboard can return to the exposed route")
	keyboard(driver, KEY_A, false)
	check(not keyboard(driver, KEY_F12, true), "unbound keys stay available to the host")

	var covered := Surface.button_rect(View.COVERED).get_center()
	check(driver.handle_input(mouse(true), covered) and driver.snapshot().route == Model.COVERED,
		"actual left mouse input can choose the sheltered route")
	driver.handle_input(mouse(false), OFF_SURFACE)
	var emulated := mouse(true)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	var action := Surface.button_rect(View.ACTION).get_center()
	check(not driver.handle_input(emulated, action) and driver.snapshot().stage == Model.READY,
		"synthetic mouse event paired with touch cannot take the next meal")
	check(driver.handle_input(touch(9, true), action) and driver.snapshot().stage == Model.CARRY,
		"one real touch takes the selected order")
	driver.handle_input(touch(9, false), OFF_SURFACE)

	var umbrella := Surface.button_rect(View.UMBRELLA).get_center()
	check(driver.handle_input(touch(9, true), umbrella), "the same finger can open the umbrella")
	driver.handle_input(touch(9, false), OFF_SURFACE)
	check(driver.snapshot().umbrella_manual, "umbrella stays open after the tap")
	keyboard(driver, KEY_SPACE, true, true)
	check(driver.snapshot().umbrella_manual, "an echoed Space press cannot flip the umbrella")
	keyboard(driver, KEY_SPACE, true)
	keyboard(driver, KEY_SPACE, false)
	check(not driver.snapshot().umbrella_manual, "a fresh keyboard press can close it")

	var walk := Surface.button_rect(View.WALK).get_center()
	check(driver.handle_input(mouse(true), walk), "mouse can hold the walking control")
	advance(driver, 18)
	var mouse_distance: float = driver.snapshot().distance
	check(mouse_distance > 0.0 and driver.handle_input(mouse(false), OFF_SURFACE),
		"the mouse keeps ownership of a held walk through an off-canvas release")
	advance(driver, 18)
	check(is_equal_approx(driver.snapshot().distance, mouse_distance) and not driver.snapshot().walking,
		"off-canvas release stops physical movement")

	check(driver.handle_input(touch(9, true), walk), "one finger can hold walk after using the umbrella")
	driver.handle_input(touch(10, false), OFF_SURFACE)
	advance(driver, 18)
	var touch_distance: float = driver.snapshot().distance
	check(touch_distance > mouse_distance, "another finger cannot release the active walker")
	var canceled := touch(9, false)
	canceled.canceled = true
	check(driver.handle_input(canceled, OFF_SURFACE), "a canceled touch is consumed")
	advance(driver, 18)
	check(is_equal_approx(driver.snapshot().distance, touch_distance), "touch cancellation releases movement")

	keyboard(driver, KEY_SPACE, true)
	keyboard(driver, KEY_SPACE, false)
	check(keyboard(driver, KEY_W, true), "the walker can start again after cancel")
	advance(driver, 18)
	driver.clear_input()
	var interrupted: float = driver.snapshot().distance
	advance(driver, 18)
	check(interrupted > touch_distance and is_equal_approx(driver.snapshot().distance, interrupted)
		and not driver.snapshot().walking and not driver.snapshot().umbrella_manual,
		"clearing input releases both walking and umbrella when the host pauses")
	keyboard(driver, KEY_W, false)
	check(keyboard(driver, KEY_R, true) and driver.snapshot().stage == Model.READY and driver.snapshot().mistakes == 1,
		"retry via a normal key replaces only the active order")
	keyboard(driver, KEY_R, false)

func test_gamepad() -> void:
	var driver := Driver.new()
	driver.reset(true, "evening")
	check(pad(driver, JOY_BUTTON_DPAD_LEFT, true) and driver.snapshot().route == Model.SHORT,
		"controller can override the canopy suggested by assist")
	pad(driver, JOY_BUTTON_DPAD_LEFT, false)
	check(pad(driver, JOY_BUTTON_A, true) and driver.snapshot().stage == Model.CARRY,
		"controller action picks up the box")
	pad(driver, JOY_BUTTON_A, false)
	check(pad(driver, JOY_BUTTON_X, true) and driver.snapshot().umbrella_manual, "controller toggles the umbrella")
	pad(driver, JOY_BUTTON_X, false)
	check(pad(driver, JOY_BUTTON_DPAD_UP, true), "controller can hold forward")
	advance(driver, 18)
	var distance: float = driver.snapshot().distance
	pad(driver, JOY_BUTTON_DPAD_UP, false)
	advance(driver, 18)
	check(distance > 0.0 and is_equal_approx(driver.snapshot().distance, distance), "controller release stops travel")

func test_scoring() -> void:
	var driver := Driver.new()
	driver.reset(false, "night")
	move_to_handoff(driver, KEY_A, false)
	wait_for_handoff(driver)
	keyboard(driver, KEY_E, true)
	keyboard(driver, KEY_E, false)
	advance(driver, Model.SLIDE_TICKS)
	var spoiled: Dictionary = driver.snapshot()
	check(spoiled.stage == Model.READY and spoiled.mistakes == 1 and spoiled.feedback.contains("淋濕"),
		"real exposed travel feeds the wet-box rejection back to the UI")

	for order in Model.ORDER_COUNT:
		move_to_handoff(driver, KEY_D if order % 2 == 0 else KEY_A, true)
		var before: Dictionary = driver.snapshot()
		driver.present("night", order % 2 == 0)
		var after: Dictionary = driver.snapshot()
		check(before.distance == after.distance and before.elapsed == after.elapsed and before.stage == after.stage,
			"reduced-motion presentation leaves the real mealtime state intact")
		wait_for_handoff(driver)
		if order > 0:
			keyboard(driver, KEY_SPACE, true)
			keyboard(driver, KEY_SPACE, false)
		check(keyboard(driver, KEY_E, true) and driver.snapshot().stage == Model.SLIDING,
			"same action slides only after physically reaching the receiver")
		keyboard(driver, KEY_E, false)
		advance(driver, Model.SLIDE_TICKS)
	var state: Dictionary = driver.snapshot()
	check(state.ended and state.success and state.ordinary_eligible and state.devil and state.umbrella_catches == 1,
		"three dry boxes plus one actual umbrella crossing earn both conditions")
	var summary: Dictionary = driver.score_summary(false)
	var points := 0
	for row: Dictionary in summary.get("rows", []):
		points += int(row.amount)
	check(state.score == 530 and summary.get("total") == state.score and points == state.score,
		"the displayed breakdown preserves 450 delivery + 100 catch - 20 rejection")
	check(str(driver.score_summary(true).get("qualification_text")).contains("練習"),
		"practice summary marks the existing collection distinction")
	check(not driver.consume_notes().is_empty() and driver.consume_notes().is_empty(), "audio notes drain exactly once")

func move_to_handoff(driver: RefCounted, route_key: Key, open_umbrella: bool) -> void:
	keyboard(driver, route_key, true)
	keyboard(driver, route_key, false)
	keyboard(driver, KEY_E, true)
	keyboard(driver, KEY_E, false)
	if open_umbrella:
		keyboard(driver, KEY_SPACE, true)
		keyboard(driver, KEY_SPACE, false)
	keyboard(driver, KEY_W, true)
	for tick in 540:
		if driver.snapshot().stage != Model.CARRY:
			break
		driver.step(Model.TICK)
	keyboard(driver, KEY_W, false)
	check(driver.snapshot().stage == Model.HANDOFF, "forward hold uses the actual route to the handoff")

func wait_for_handoff(driver: RefCounted) -> void:
	for tick in 150:
		if driver.snapshot().slide_ready:
			return
		driver.step(Model.TICK)
	check(false, "receiver preview eventually shows a valid timing window")

func advance(driver: RefCounted, frames: int) -> void:
	for frame in frames:
		driver.step(Model.TICK)

func keyboard(driver: RefCounted, code: Key, pressed: bool, echo := false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return driver.handle_input(event, Vector2.ZERO)

func pad(driver: RefCounted, code: JoyButton, pressed: bool) -> bool:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = code
	event.pressed = pressed
	return driver.handle_input(event, Vector2.ZERO)

func mouse(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event

func check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
