extends SceneTree
var checks := 0
var failures := 0
var View
func _initialize() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
static func key(driver, code: Key, pressed := true, echo := false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return driver.handle_input(event, Vector2.ZERO)
static func pointer(driver, point: Vector2, pressed: bool, finger := -1, canceled := false, emulated := false) -> bool:
	if finger >= 0:
		var event := InputEventScreenTouch.new()
		event.index = finger
		event.pressed = pressed
		event.canceled = canceled
		return driver.handle_input(event, point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	return driver.handle_input(event, point)
static func command(driver, name: String, pressed: bool, route := 0) -> bool:
	var view = load("res://game/minigames/jelly_trampoline_view.gd")
	if route == 0:
		for code in view.KEYS:
			if view.KEYS[code] == name:
				return key(driver, code, pressed)
	return pointer(driver, view.button_rect(name).get_center(), pressed, 4 if route == 2 else -1)
static func action(driver, name: String, route := 0) -> void:
	command(driver, name, true, route)
	command(driver, name, false, route)
static func advance(driver, seconds: float) -> void:
	var left := seconds
	while left > 0.00000001:
		var dt := minf(left, 1.0 / 60.0)
		driver.step(dt)
		left -= dt
static func configure(driver, x: float, tilt: float, route := 0) -> void:
	for i in 20:
		var state: Dictionary = driver.snapshot()
		if is_equal_approx(state.bed.x, x):
			break
		action(driver, "bed_right" if state.bed.x < x else "bed_left", route)
	for i in 20:
		var state: Dictionary = driver.snapshot()
		if is_equal_approx(state.tilt, tilt):
			break
		action(driver, "tilt_right" if state.tilt < tilt else "tilt_left", route)
static func launch(driver, seconds: float, route := 0) -> void:
	command(driver, "charge", true, route)
	advance(driver, seconds)
	command(driver, "charge", false, route)
static func wait_ready(driver) -> void:
	for i in 600:
		if driver.snapshot().fruit.ready or driver.snapshot().ended:
			return
		driver.step(1.0 / 120.0)
static func solve(driver, route := 0, bell := false) -> Dictionary:
	if driver.snapshot().assisted:
		configure(driver, 340, 0, route)
		action(driver, "helper", route)
		launch(driver, 0.8, route)
		wait_ready(driver)
		action(driver, "helper", route)
	for shot in 3:
		var state: Dictionary = driver.snapshot()
		var mass := float(state.fruit.mass)
		var x := 380.0 if is_equal_approx(mass, 1.0) else (420.0 if mass > 1.0 else 340.0)
		configure(driver, x + (80 if bell and shot == 0 else 0), 28 if mass > 1.0 else 21, route)
		launch(driver, 1.28 if mass >= 1.0 else 1.26, route)
		wait_ready(driver)
	return driver.snapshot()
func _run() -> void:
	var path := "res://game/minigames/jelly_trampoline_driver.gd"
	expect(ResourceLoader.exists(path), "jelly driver exists")
	if not ResourceLoader.exists(path):
		finish()
		return
	View = load("res://game/minigames/jelly_trampoline_view.gd")
	var script = load(path)
	expect(script.can_instantiate() and View.can_instantiate(), "owned scripts compile")
	if not script.can_instantiate() or not View.can_instantiate():
		finish()
		return
	var driver = script.new()
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 0 and driver.snapshot().time_text == "60 秒", "first variant and house fields")
	expect(not key(driver, KEY_SPACE, true, true) and not key(driver, KEY_G), "echo and unknown ignored")
	expect(key(driver, KEY_SPACE), "Space begins held charge")
	advance(driver, 0.8)
	expect(driver.snapshot().fruit.ready and driver.snapshot().charging and not driver.snapshot().participated, "hold never launches")
	expect(not key(driver, KEY_SPACE) and not pointer(driver, View.button_rect("charge").get_center(), true), "repeat and competing mouse rejected")
	expect(not key(driver, KEY_R, false) and driver.snapshot().charging, "unmatched keyboard release cannot launch")
	key(driver, KEY_SPACE, false)
	expect(not driver.snapshot().fruit.ready and driver.snapshot().participated, "matched release launches real fruit")
	var velocity := float(driver.snapshot().fruit.vx)
	action(driver, "tilt_right")
	expect(driver.snapshot().fruit.vx == velocity, "airborne tilt cannot steer")
	key(driver, KEY_SPACE)
	driver.clear_input()
	expect(not key(driver, KEY_SPACE, false) and not driver.snapshot().charging and not driver.snapshot().fruit.ready, "clear preserves flight and rejects ghost release")
	for route in [1, 2]:
		driver.reset(false, "noon")
		var p: Vector2 = View.button_rect("charge").get_center()
		var finger := 4 if route == 2 else -1
		expect(pointer(driver, p, true, finger), "pointer owns charge")
		advance(driver, 0.5)
		expect(not pointer(driver, p, true, 8) and not key(driver, KEY_SPACE), "second touch and keyboard cannot steal owner")
		expect(not pointer(driver, p, false, 8) and driver.snapshot().charging, "second release cannot fire")
		pointer(driver, Vector2(-100, -100), false, finger)
		expect(driver.snapshot().fruit.ready and not driver.snapshot().participated and not driver.snapshot().charging, "outside release cancels real charge")
		pointer(driver, p, true, finger)
		advance(driver, 0.2)
		pointer(driver, Vector2(NAN, INF), false, finger, route == 2)
		expect(driver.snapshot().fruit.ready and not driver.snapshot().charging, "canceled or nonfinite release never launches")
	expect(not pointer(driver, View.button_rect("charge").get_center(), true, -1, false, true), "emulated mouse ignored")
	expect(not pointer(driver, Vector2(NAN, INF), true), "invalid press ignored")
	driver.reset(false, "noon")
	key(driver, KEY_A)
	key(driver, KEY_LEFT)
	key(driver, KEY_LEFT, false)
	expect(not key(driver, KEY_D, false) and driver.snapshot().bed.x == 300, "physical aliases cannot double-step or steal release")
	key(driver, KEY_A, false)
	action(driver, "bed_right")
	expect(driver.snapshot().bed.x == 340, "alias original release clears key ownership")
	key(driver, KEY_SPACE)
	advance(driver, 0.2)
	action(driver, "reset_fruit")
	expect(not key(driver, KEY_SPACE, false) and driver.snapshot().fruit.ready and driver.snapshot().mistakes == 1, "X while keyboard held cancels without late launch")
	var sum := 0
	for row in driver.score_summary(false).rows:
		sum += row.amount
	expect(driver.snapshot().score == 0 and sum == 0, "real reset deduction reconciles zero floor")
	for route in 3:
		for assisted in [false, true]:
			for bell in [false, true]:
				for variant in 2:
					driver.reset(assisted, "noon")
					var state := solve(driver, route, bell)
					print("JELLY_INPUT_ROUTE route=%d variant=%d assisted=%s bell=%s deliveries=%d success=%s score=%d elapsed=%.9f" % [route, state.variant, assisted, bell, state.delivered, state.success, state.score, state.elapsed])
					expect(state.success and state.delivered == 3 and state.devil == bell and state.ordinary_eligible and state.score == (500 if bell else 400), "real three-modality A/B normal/assist ordinary/bell route")
					sum = 0
					for row in driver.score_summary(false).rows:
						sum += row.amount
					expect(sum == state.score and driver.score_summary(false).total == state.score, "score rows use actual model")
	expect(driver.score_summary(true).qualification_text == "練習回合不取得拍貼。", "practice excludes awards")
	driver.reset(false, "noon")
	key(driver, KEY_SPACE)
	advance(driver, 0.5)
	driver.reset(false, "night")
	expect(not key(driver, KEY_SPACE, false) and not driver.snapshot().participated, "retry cancels old held input")
	action(driver, "helper")
	advance(driver, 60)
	expect(driver.snapshot().ended and not driver.snapshot().ordinary_eligible, "helper plus waiting cannot qualify")
	finish()
func finish() -> void:
	print("Jelly trampoline driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
