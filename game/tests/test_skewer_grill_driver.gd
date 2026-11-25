extends SceneTree

const Driver = preload("res://game/minigames/skewer_grill_driver.gd")
const Model = preload("res://game/minigames/skewer_grill_model.gd")
const View = preload("res://game/minigames/skewer_grill_view.gd")
const Surface = preload("res://game/ui/minigame_hold_controls.gd")
const OUTSIDE := Vector2(-20, 805)
var _errors: Array[String] = []

func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Skewer grill driver test requires an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	test_keyboard_and_pointer()
	test_assisted_controller()
	test_real_completion()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: skewer grill keyboard, mouse, touch, controller and actual scoring")
	quit(int(not _errors.is_empty()))

func test_keyboard_and_pointer() -> void:
	var driver := Driver.new()
	driver.reset(false, "night")
	check(key(driver, KEY_A, true) and driver.snapshot().selected == 2, "keyboard selection wraps to the last skewer")
	key(driver, KEY_A, true, true)
	key(driver, KEY_A, true)
	check(driver.snapshot().selected == 2, "repeated press and echo never duplicate a command")
	key(driver, KEY_A, false)
	check(key(driver, KEY_A, true) and driver.snapshot().selected == 1, "release permits the next intentional press")
	driver.clear_input()
	check(key(driver, KEY_A, true) and driver.snapshot().selected == 0, "host clear removes a stuck input owner")
	key(driver, KEY_A, false)
	check(not key(driver, KEY_F12, true), "keys outside the grill remain available to the host")
	tap(driver, KEY_R)
	check(driver.snapshot().helper == -1, "normal routes keep operator control")

	var near := slot(View.NEAR)
	var far := slot(View.FAR)
	var turn := slot(View.TURN)
	check(not driver.handle_input(mouse(true), OUTSIDE) and not driver.handle_input(mouse(true), slot(View.SERVE)),
		"empty space and an uncooked service target do not begin a pointer operation")
	check(driver.handle_input(mouse(true), near) and driver.snapshot().current.zone == Model.NEAR,
		"left mouse press places a fresh skewer in near heat")
	driver.handle_input(mouse(true), far)
	check(driver.snapshot().current.zone == Model.NEAR, "a mouse press cannot run a second region command before release")
	check(driver.handle_input(mouse(false), OUTSIDE), "off-canvas release terminates the active mouse gesture")
	check(driver.handle_input(mouse(true), far) and driver.snapshot().current.zone == Model.FAR,
		"after release, a new mouse press places the skewer in the residual zone")
	driver.handle_input(mouse(false), OUTSIDE)

	var emulated := mouse(true)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	check(not driver.handle_input(emulated, turn) and driver.snapshot().current.down_face == 0,
		"twin emulated mouse input cannot rotate a touch-controlled skewer")
	check(driver.handle_input(touch(9, true), turn) and driver.snapshot().current.down_face == 1,
		"one real finger rotates exactly one independently tracked face")
	driver.handle_input(touch(10, false), OUTSIDE)
	driver.handle_input(touch(9, true), turn)
	check(driver.snapshot().current.down_face == 1, "unowned finger release cannot unlock the active tap")
	var canceled := touch(9, false)
	canceled.canceled = true
	check(driver.handle_input(canceled, OUTSIDE), "off-board touch cancellation clears the owner")
	check(driver.handle_input(touch(9, true), turn) and driver.snapshot().current.down_face == 2,
		"fresh touch after cancellation rotates once")
	driver.handle_input(touch(9, false), OUTSIDE)

func test_assisted_controller() -> void:
	var driver := Driver.new()
	driver.reset(true, "night")
	check(tap_pad(driver, JOY_BUTTON_DPAD_UP) and driver.snapshot().current.zone == Model.NEAR,
		"controller up places the selected skewer where it actually heats")
	check(tap_pad(driver, JOY_BUTTON_DPAD_RIGHT) and driver.snapshot().selected == 1,
		"controller right selects another portion")
	check(tap_pad(driver, JOY_BUTTON_DPAD_UP) and tap_pad(driver, JOY_BUTTON_RIGHT_SHOULDER)
		and driver.snapshot().helper == 1, "controller can assign help to the specific second skewer")
	for tick in 360:
		if driver.snapshot().skewers[1].down_face != 0:
			break
		driver.step(Model.TICK)
	var worked := driver.snapshot()
	check(worked.skewers[1].down_face == 1 and worked.skewers[0].down_face == 0
		and worked.skewers[1].zone == Model.NEAR and worked.served == 0,
		"assisted rotation never turns another skewer or moves or serves automatically")
	check(tap_pad(driver, JOY_BUTTON_DPAD_DOWN) and driver.snapshot().current.zone == Model.FAR,
		"controller can move the warmed skewer to the residual-only shelf")
	var facing: int = driver.snapshot().current.down_face
	check(tap_pad(driver, JOY_BUTTON_X) and driver.snapshot().current.down_face == (facing + 1) % Model.FACE_COUNT,
		"controller rotation remains available after assisted action")
	var before := driver.snapshot()
	driver.present("night", true)
	check(driver.snapshot() == before, "presentation choice preserves real timing, heat and state")

func test_real_completion() -> void:
	var driver := Driver.new()
	driver.reset(false, "night")
	tap(driver, KEY_W)
	for tick in 600:
		if driver.snapshot().current.ruined:
			break
		driver.step(Model.TICK)
	check(driver.snapshot().current.ruined and driver.snapshot().current.face_states[0] == "charred",
		"real sustained coal heat burns the neglected side")
	check(tap(driver, KEY_E) and driver.snapshot().mistakes == 1 and driver.snapshot().current.zone == Model.BENCH,
		"the same edge-triggered service control replaces a ruined skewer")
	key(driver, KEY_E, true)
	for index in Model.SKEWER_COUNT:
		if index > 0:
			tap(driver, KEY_D)
		if not check(cook_selected(driver, index == Model.SKEWER_COUNT - 1),
			"typed heat-zone and turn inputs produce all four ready faces on skewer %d" % (index + 1)):
			return
		if index == 0:
			key(driver, KEY_E, true)
			check(driver.snapshot().served == 0, "service held while disabled cannot auto-submit later")
			key(driver, KEY_E, false)
		if not check(tap(driver, KEY_E) and driver.snapshot().served == index + 1, "fresh service action delivers one ready skewer"):
			return
	var result := driver.snapshot()
	check(result.ended and result.success and result.devil and result.ordinary_eligible
		and result.skewers[2].residual_finish and result.refuels == 0 and result.progress_text.contains("3 / 3"),
		"actual play serves three dishes and earns real final-face residual completion")
	var summary := driver.score_summary(false)
	var total := 0
	for row: Dictionary in summary.rows:
		total += int(row.amount)
	check(total == 530 and result.score == total and summary.total == total,
		"settlement detail reconciles 450 served + 100 residual - 20 discarded")
	check(driver.score_summary(true).qualification_text.contains("練習"),
		"practice explains why it never records a score or collection")
	check(not driver.consume_notes().is_empty() and driver.consume_notes().is_empty(), "audible action notes drain exactly once")

func cook_selected(driver: RefCounted, finish_far: bool) -> bool:
	tap(driver, KEY_W)
	var target: float = driver.snapshot().cook_target
	for side in Model.FACE_COUNT:
		var down: int = driver.snapshot().current.down_face
		if finish_far and side == Model.FACE_COUNT - 1:
			if not heat_to(driver, down, target - 0.23) or driver.snapshot().current.cook[down] >= target:
				return false
			tap(driver, KEY_S)
		if not heat_to(driver, down, target):
			return false
		if side < Model.FACE_COUNT - 1:
			tap(driver, KEY_SPACE)
	return driver.snapshot().current.serve_ready

func heat_to(driver: RefCounted, face: int, target: float) -> bool:
	for tick in 540:
		var state: Dictionary = driver.snapshot()
		if state.current.cook[face] >= target:
			return true
		if state.ended or state.current.ruined or state.warning >= 0:
			break
		driver.step(Model.TICK)
	return false

func tap(driver: RefCounted, code: Key) -> bool:
	var accepted := key(driver, code, true)
	key(driver, code, false)
	return accepted

func key(driver: RefCounted, code: Key, pressed: bool, echo := false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return driver.handle_input(event, OUTSIDE)

func tap_pad(driver: RefCounted, code: JoyButton) -> bool:
	var event := InputEventJoypadButton.new()
	event.device = 4
	event.button_index = code
	event.pressed = true
	var accepted: bool = driver.handle_input(event, OUTSIDE)
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	driver.handle_input(release, OUTSIDE)
	return accepted

func slot(action: int) -> Vector2:
	return Surface.button_rect(action).get_center()

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

func check(condition: bool, failure: String) -> bool:
	if not condition:
		_errors.append(failure)
	return condition
