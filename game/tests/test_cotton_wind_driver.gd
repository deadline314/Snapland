extends SceneTree

const DRIVER_PATH := "res://game/minigames/cotton_wind_driver.gd"
const VIEW_PATH := "res://game/minigames/cotton_wind_view.gd"
const Route = preload("res://game/tests/cotton_wind_route.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(DRIVER_PATH):
		print("FAIL: missing Cotton Wind Driver at ", DRIVER_PATH)
		quit(1)
		return
	var driver = load(DRIVER_PATH).new()
	var view: Script = load(VIEW_PATH)
	driver.reset(false, "noon")
	check(driver.create_view() == null, "headless driver does not instantiate a render tree")
	key(driver, KEY_A, true)
	key(driver, KEY_LEFT, true)
	key(driver, KEY_A, false)
	check(driver.step(0.05).stick.x < 0, "physical movement alias holds after sibling release")
	var x: float = driver.snapshot().stick.x
	key(driver, KEY_D, true)
	check(is_equal_approx(driver.step(0.05).stick.x, x), "opposite movement cancels")
	key(driver, KEY_LEFT, false)
	check(driver.step(0.05).stick.x > x, "releasing the opposite restores movement")
	key(driver, KEY_D, false)
	key(driver, KEY_E, true)
	key(driver, KEY_SPACE, true)
	key(driver, KEY_E, false)
	check(driver.snapshot().omega > 0, "physical spin alias holds after sibling release")
	key(driver, KEY_Q, true)
	check(is_zero_approx(driver.snapshot().omega), "opposite spin cancels")
	key(driver, KEY_Q, false)
	check(driver.snapshot().omega > 0, "releasing opposite spin restores clockwise spin")
	key(driver, KEY_SPACE, false)
	key(driver, KEY_R, true)
	key(driver, KEY_R, true, true)
	check(driver.snapshot().helper, "echo does not toggle helper twice")
	key(driver, KEY_R, false)
	driver.clear_input()
	for source in [-1, 0]:
		var spin: Vector2 = view.command_center("spin_right")
		var target: Vector2 = view.stick_to_design(Vector2(100, 130))
		check(pointer(driver, spin, true, source) and pointer(driver, spin, false, source), "first tap selects spin")
		check(driver.snapshot().omega > 0, "spin is latched on release")
		var initial: Vector3 = driver.snapshot().stick
		check(pointer(driver, target, true, source), "same pointer can now drag in 3D workspace")
		check(driver.snapshot().stick == initial, "pointer cannot teleport or sweep the rod")
		check(not pointer(driver, spin, true, 1), "a second finger cannot steal source")
		check(not pointer(driver, spin, true, -1, false, true), "emulated mouse cannot steal source")
		check(not pointer(driver, target, false, 1, true), "canceled second finger cannot cancel owner")
		check(driver.step(0.05).stick.distance_to(initial) <= 6.0001 and driver.snapshot().stick != initial and driver.snapshot().omega > 0,
			"drag movement is bounded and can occur while spinning")
		check(pointer(driver, Vector2(-50, -20), false, source), "outside owner release is captured")
		var stopped: Vector3 = driver.snapshot().stick
		check(driver.step(0.05).stick == stopped and driver.snapshot().omega > 0, "release stops drag while preserving spin latch")
		pointer(driver, spin, true, source)
		pointer(driver, spin, false, source)
		check(is_zero_approx(driver.snapshot().omega), "same spin command unlatches")
	var spin: Vector2 = view.command_center("spin_right")
	var target: Vector2 = view.stick_to_design(Vector2(-100, 140))
	pointer(driver, spin, true, 0)
	pointer(driver, spin, false, 0)
	pointer(driver, target, true, 0)
	check(pointer(driver, target, false, 0, true), "owner cancellation is captured")
	check(driver.snapshot().held_commands.is_empty() and is_zero_approx(driver.snapshot().omega), "owner cancellation clears latch and drag")
	check(not pointer(driver, Vector2(NAN, 300), true, -1), "non-finite press cannot capture input")
	pointer(driver, spin, true, -1)
	pointer(driver, spin, false, -1)
	pointer(driver, target, true, -1)
	check(drag(driver, Vector2(NAN, 300), -1), "non-finite owner motion is consumed")
	check(driver.snapshot().held_commands.is_empty() and is_zero_approx(driver.snapshot().omega), "non-finite drag clears input")
	pointer(driver, spin, true, -1)
	pointer(driver, spin, false, -1)
	key(driver, KEY_Q, true)
	check(driver.snapshot().omega < 0, "keyboard spin temporarily owns the spinning motion")
	key(driver, KEY_Q, false)
	check(driver.snapshot().omega > 0, "keyboard release restores pointer latch")
	driver.clear_input()
	check(driver.snapshot().held_commands.is_empty() and is_zero_approx(driver.snapshot().omega), "pause clear neutralizes all sources")
	for source in ["keyboard", "mouse", "touch"]:
		for variant in 2:
			for assisted in [false, true]:
				for rejoin in [false, true]:
					var outcome: Dictionary = solve(source, variant, assisted, rejoin)
					var score := 500 if rejoin else 400
					check(outcome.ended and outcome.success and outcome.ordinary_eligible and outcome.score == score and outcome.devil == rejoin
						and outcome.rejoins == int(rejoin) and outcome.held_commands.is_empty(), "%s %s assist=%s rejoin=%s expected %d, actual %d at %.3f after %d rejoins" %
						[source, "AB"[variant], assisted, rejoin, score, outcome.score, outcome.elapsed, outcome.rejoins])
					print("COTTON_DRIVER_ROUTE ", JSON.stringify({"source": source, "variant": "AB"[variant], "assisted": assisted,
						"rejoin": rejoin, "elapsed": outcome.elapsed, "score": outcome.score, "rejoins": outcome.rejoins, "quality": outcome.quality}))
	print("Cotton wind driver: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

static func key(driver, code: Key, pressed: bool, echo := false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return driver.handle_input(event, Vector2.ZERO)

static func pointer(driver, point: Vector2, pressed: bool, finger: int, canceled := false, emulated := false) -> bool:
	if finger >= 0:
		var touch := InputEventScreenTouch.new()
		touch.index = finger
		touch.position = point
		touch.pressed = pressed
		touch.canceled = canceled
		return driver.handle_input(touch, point)
	var button := InputEventMouseButton.new()
	button.position = point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	return driver.handle_input(button, point)

static func drag(driver, point: Vector2, finger: int) -> bool:
	if finger >= 0:
		var touch := InputEventScreenDrag.new()
		touch.index = finger
		touch.position = point
		return driver.handle_input(touch, point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	return driver.handle_input(motion, point)

static func solve(source: String, variant: int, assisted: bool, rejoin: bool) -> Dictionary:
	var driver = load(DRIVER_PATH).new()
	var view: Script = load(VIEW_PATH)
	for i in variant + 1:
		driver.reset(assisted, "noon")
	var finger := 0 if source == "touch" else -1
	var pointer_point: Vector2
	var key_direction := Vector2.ZERO
	var directions := {KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_W: Vector2.UP, KEY_S: Vector2.DOWN}
	if source == "keyboard":
		key(driver, KEY_E, true)
	else:
		var spin: Vector2 = view.command_center("spin_right")
		pointer(driver, spin, true, finger)
		pointer(driver, spin, false, finger)
		pointer_point = view.stick_to_design(Route.target(driver.snapshot(), rejoin))
		pointer(driver, pointer_point, true, finger)
	for i in 14500:
		var state: Dictionary = driver.snapshot()
		if state.ended:
			return state
		if state.uniform and (not rejoin or state.rejoins > 0):
			if source == "keyboard":
				key(driver, KEY_F, true)
			else:
				pointer(driver, pointer_point, false, finger)
				var finish: Vector2 = view.command_center("finish")
				pointer(driver, finish, true, finger)
				pointer(driver, finish, false, finger)
			return driver.step(0.0)
		var target: Vector2 = Route.target(state, rejoin)
		if source == "keyboard":
			var difference := target - Vector2(state.stick.x, state.stick.z)
			var direction := Vector2(signf(difference.x) if absf(difference.x) >= 0.5 else 0.0,
				signf(difference.y) if absf(difference.y) >= 0.5 else 0.0)
			for code: Key in directions:
				var basis: Vector2 = directions[code]
				if direction.dot(basis) != key_direction.dot(basis):
					key(driver, code, direction.dot(basis) > 0)
			key_direction = direction
			driver.step(1.0 / 120.0)
		else:
			pointer_point = view.stick_to_design(target)
			drag(driver, pointer_point, finger)
			driver.step(Route.DT)
	return driver.snapshot()
