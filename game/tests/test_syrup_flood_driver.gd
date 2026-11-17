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
static func key(driver, code: Key, pressed := true, shift := false, echo := false) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	event.echo = echo
	return driver.handle_input(event, Vector2.ZERO)
static func tap(driver, code: Key, shift := false) -> void:
	key(driver, code, true, shift)
	key(driver, code, false, shift)
static func pointer(driver, point: Vector2, pressed: bool, finger := -1, canceled := false) -> bool:
	if finger >= 0:
		var event := InputEventScreenTouch.new()
		event.index = finger
		event.pressed = pressed
		event.canceled = canceled
		return driver.handle_input(event, point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return driver.handle_input(event, point)
static func action(driver, command: String, route := 0) -> void:
	var view = load("res://game/minigames/syrup_flood_view.gd")
	if route == 0:
		if command == "previous":
			tap(driver, KEY_TAB, true)
			return
		for code in view.KEYS:
			if view.KEYS[code] == command:
				tap(driver, code)
				return
	else:
		var point: Vector2 = view.button_rect(command).get_center()
		pointer(driver, point, true, 4 if route == 2 else -1)
		pointer(driver, Vector2(-100, -100), false, 4 if route == 2 else -1)
static func select(driver, index: int, route := 0) -> void:
	for i in 3:
		if driver.snapshot().selected == index:
			return
		action(driver, "next", route)
static func solve(driver, route := 0, plug := true) -> Dictionary:
	for i in 3:
		select(driver, i, route)
		action(driver, "valve", route)
	if plug:
		select(driver, 1, route)
		action(driver, "diversion", route)
	for frame in 4501:
		var state: Dictionary = driver.snapshot()
		if state.ended:
			return state
		for i in 3:
			var branch: Dictionary = state.branches[i]
			if branch.valve and branch.fill >= branch.capacity * 0.92:
				select(driver, i, route)
				action(driver, "valve", route)
		state = driver.snapshot()
		for i in 3:
			if state.branches[i].fill < state.branches[i].capacity * 0.92 and not (i == 1 and state.diversion):
				if state.heater != i:
					select(driver, i, route)
					action(driver, "heater", route)
				break
		driver.step(1.0 / 60.0)
	return driver.snapshot()
func _run() -> void:
	var path := "res://game/minigames/syrup_flood_driver.gd"
	expect(ResourceLoader.exists(path), "syrup driver resource exists")
	if not ResourceLoader.exists(path):
		finish()
		return
	View = load("res://game/minigames/syrup_flood_view.gd")
	expect(View != null and View.can_instantiate(), "view script compiles")
	if View == null or not View.can_instantiate():
		finish()
		return
	var driver_script = load(path)
	expect(driver_script != null and driver_script.can_instantiate(), "driver script compiles")
	if driver_script == null or not driver_script.can_instantiate():
		finish()
		return
	var driver = driver_script.new()
	driver.reset(false, "noon")
	expect(driver.snapshot().time_text == "75 秒" and driver.snapshot().variant == 0, "house session fields and first variant")
	expect(not key(driver, KEY_G) and not key(driver, KEY_TAB, true, false, true), "unbound and echo ignored")
	tap(driver, KEY_TAB)
	expect(driver.snapshot().selected == 1, "Tab next")
	key(driver, KEY_TAB)
	expect(not key(driver, KEY_TAB, true, true) and driver.snapshot().selected == 2, "held physical Tab cannot repeat by changing Shift")
	key(driver, KEY_TAB, false, true)
	tap(driver, KEY_TAB, true)
	key(driver, KEY_TAB, true, true)
	key(driver, KEY_TAB, false, false)
	expect(driver.snapshot().selected == 0 and key(driver, KEY_SPACE), "Shift Tab release follows original command")
	expect(not key(driver, KEY_SPACE) and not pointer(driver, View.button_rect("heater").get_center(), true), "held repeat and second source rejected")
	expect(driver.snapshot().branches[0].valve, "Space toggles once on press")
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().branches[0].valve, "release never toggles")
	tap(driver, KEY_H)
	tap(driver, KEY_R)
	expect(driver.snapshot().heater == 0 and driver.snapshot().helper == 0, "heat and helper target selected branch")
	tap(driver, KEY_C)
	var paused: Dictionary = driver.snapshot()
	driver.step(0.25)
	expect(driver.snapshot() == paused, "configuration halts heat flow and time")
	tap(driver, KEY_C)
	driver.step(0.25)
	expect(driver.snapshot().elapsed > 0 and driver.snapshot().branches[0].temperature > paused.branches[0].temperature, "resume continues actual physics")
	driver.reset(false, "night")
	expect(driver.snapshot().variant == 1, "retry alternates bounded configuration")
	var p: Vector2 = View.valve_point(1)
	expect(pointer(driver, p, true, 3), "actual valve touch selects and toggles")
	expect(driver.snapshot().selected == 1 and driver.snapshot().branches[1].valve, "selected physical valve changes once")
	expect(not pointer(driver, p, true, 8) and not key(driver, KEY_H), "other finger and keyboard cannot steal touch")
	expect(pointer(driver, Vector2(NAN, INF), false, 3, true), "canceled touch clears owner")
	expect(not pointer(driver, p, false, 3) and driver.snapshot().branches[1].valve, "late release adds no operation")
	expect(pointer(driver, View.button_rect("diversion").get_center(), true), "mouse acts after cancellation")
	expect(pointer(driver, Vector2(-100, -100), false) and driver.snapshot().diversion, "outside release clears without extra toggle")
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	expect(not driver.handle_input(emulated, p) and not pointer(driver, Vector2(NAN, INF), true), "emulated and nonfinite presses excluded")
	key(driver, KEY_H)
	driver.clear_input()
	expect(not key(driver, KEY_H, false) and driver.snapshot().heater == 1, "clear retains latched valve and heater without extra actions")
	tap(driver, KEY_X)
	expect(driver.snapshot().branches[1].fill == 0, "drain control uses model")
	var state: Dictionary = driver.snapshot()
	state.branches[0].fill = 999
	expect(driver.snapshot().branches[0].fill == 0, "snapshot remains deeply independent")
	for route in 3:
		driver.reset(false, "noon")
		action(driver, "next", route)
		expect(driver.snapshot().selected == 1, "each input selects next")
		action(driver, "previous", route)
		expect(driver.snapshot().selected == 0, "each input selects previous")
		action(driver, "next", route)
		action(driver, "valve", route)
		action(driver, "heater", route)
		action(driver, "diversion", route)
		action(driver, "helper", route)
		expect(driver.snapshot().branches[1].valve and driver.snapshot().heater == 1 and driver.snapshot().diversion and driver.snapshot().helper == 1, "each input toggles selected valve heat bypass and helper identically")
		action(driver, "configuration", route)
		var frozen: Dictionary = driver.snapshot()
		driver.step(0.25)
		expect(driver.snapshot() == frozen, "each input configuration pauses simulation")
		action(driver, "configuration", route)
		action(driver, "diversion", route)
		driver.step(0.25)
		expect(driver.snapshot().branches[1].fill > 0, "each input resumes actual filling")
		var elapsed: float = driver.snapshot().elapsed
		action(driver, "drain", route)
		expect(driver.snapshot().branches[1].fill == 0 and driver.snapshot().elapsed == elapsed, "each input drains real material without returning time")
	for route in 3:
		for assisted in [false, true]:
			for plug in [false, true]:
				for variant in 2:
					driver.reset(assisted, "noon")
					var result := solve(driver, route, plug)
					print("SYRUP_INPUT_ROUTE route=%d assisted=%s variant=%d success=%s devil=%s score=%d elapsed=%.5f" % [route, assisted, result.variant, result.success, result.devil, result.score, result.elapsed])
					expect(result.success and result.devil == plug and result.ordinary_eligible, "real keyboard/mouse/touch A/B assisted ordinary/devil solve")
					var summary: Dictionary = driver.score_summary(false)
					var total := 0
					for row in summary.rows:
						total += row.amount
					expect(summary.total == result.score and total == result.score, "model score and result rows agree")
	expect(driver.score_summary(true).qualification_text == "練習回合不取得拍貼。", "practice excludes award")
	driver.reset(false, "noon")
	tap(driver, KEY_R)
	for i in 301:
		driver.step(0.25)
	expect(driver.snapshot().ended and not driver.snapshot().ordinary_eligible, "helper-only timeout never qualifies")
	driver.reset(false, "noon")
	tap(driver, KEY_SPACE)
	tap(driver, KEY_H)
	for i in 300:
		if driver.snapshot().branches[0].spoiled:
			break
		driver.step(0.25)
	expect(driver.snapshot().mistakes == 1 and driver.snapshot().branches[0].spoiled, "actual overflow creates deduction")
	tap(driver, KEY_X)
	var summary: Dictionary = driver.score_summary(false)
	var sum := 0
	for row in summary.rows:
		sum += row.amount
	expect(summary.total == 0 and sum == 0 and summary.rows[-1].key == "score_adjustment", "zero-floor model total reconciles every displayed row after actual overflow and drain")
	finish()
func finish() -> void:
	print("Syrup flood driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
