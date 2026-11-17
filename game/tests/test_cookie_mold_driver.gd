extends SceneTree
const Driver = preload("res://game/minigames/cookie_mold_driver.gd")
const View = preload("res://game/minigames/cookie_mold_view.gd")
var checks := 0
var failures := 0

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

static func move(driver, point: Vector2, finger := -1) -> bool:
	if finger >= 0:
		var event := InputEventScreenDrag.new()
		event.index = finger
		return driver.handle_input(event, point)
	return driver.handle_input(InputEventMouseMotion.new(), point)

static func advance(driver, seconds: float) -> void:
	var left := seconds
	while left > 0.000001:
		var dt := minf(left, 1.0 / 120.0)
		driver.step(dt)
		left -= dt

# Public input only: snapshots select targets but never assign physical state.
static func solve(driver, keyboard := false, finger := -1, inertial := false) -> Dictionary:
	for slot in 6:
		for knock in 180:
			var state: Dictionary = driver.snapshot()
			var edge := 0
			for i in state.edges.size():
				if state.edges[i].adhesion > state.edges[edge].adhesion:
					edge = i
			if state.edges[edge].adhesion <= 0.15 or state.phase != "molded":
				break
			if keyboard:
				for change in state.edges.size():
					if driver.snapshot().selected_edge == edge:
						break
					tap(driver, KEY_TAB)
				key(driver, KEY_SPACE)
			else:
				pointer(driver, View.edge_point(state, edge), true, finger)
			advance(driver, 0.16)
			if keyboard:
				key(driver, KEY_SPACE, false)
			else:
				pointer(driver, View.edge_point(driver.snapshot(), edge), false, finger)
		var start: Dictionary = driver.snapshot()
		if not start.helper:
			if keyboard:
				tap(driver, KEY_R)
			else:
				pointer(driver, View.button_rect("helper").get_center(), true, finger)
				pointer(driver, View.button_rect("helper").get_center(), false, finger)
		if keyboard:
			key(driver, KEY_D)
		else:
			pointer(driver, View.mold_handle_point(driver.snapshot()), true, finger)
		for frame in 900:
			var state: Dictionary = driver.snapshot()
			if state.phase != "molded" or state.ended:
				break
			if not keyboard:
				var target := state.duplicate(true)
				target.mold_angle = 2.8 if inertial and slot == 5 else minf(PI, float(frame + 1) * 0.9 / 120.0)
				move(driver, View.mold_handle_point(target), finger)
			driver.step(1.0 / 120.0)
		if keyboard:
			key(driver, KEY_D, false)
		else:
			pointer(driver, View.mold_handle_point(driver.snapshot()), false, finger)
		for frame in 600:
			var state: Dictionary = driver.snapshot()
			if state.phase != "flying" or state.ended:
				break
			if keyboard:
				var difference := float(state.cookie_position.x) - float(state.tray_target)
				if absf(difference) > 0.001:
					var code: Key = KEY_RIGHT if difference > 0 else KEY_LEFT
					key(driver, code)
					driver.step(minf(absf(difference) / 4.0, 1.0 / 120.0))
					key(driver, code, false)
				driver.step(1.0 / 120.0)
			else:
				pointer(driver, View.tray_point(state), true, finger)
				move(driver, View.design_point(Vector2(state.cookie_position.x + 1.4, state.tray_y - 0.05)), finger)
				pointer(driver, Vector2.ZERO, false, finger)
				driver.step(1.0 / 120.0)
		if driver.snapshot().phase != "caught":
			return driver.snapshot()
		if not driver.snapshot().ended:
			advance(driver, 0.46)
	return driver.snapshot()

func _run() -> void:
	var driver = Driver.new()
	driver.reset(false, "noon")
	expect(driver.snapshot().time_text == "150 秒", "full session fields")
	expect(not key(driver, KEY_G) and not key(driver, KEY_TAB, true, false, true), "unbound and echoed keys ignored")
	tap(driver, KEY_TAB)
	expect(driver.snapshot().selected_edge == 1, "Tab next")
	tap(driver, KEY_TAB, true)
	expect(driver.snapshot().selected_edge == 0, "Shift Tab previous")
	key(driver, KEY_SPACE)
	advance(driver, 0.2)
	var charged: Dictionary = driver.snapshot()
	tap(driver, KEY_TAB)
	expect(driver.snapshot().selected_edge == 0 and is_equal_approx(driver.snapshot().charge, 0.2), "same keyboard owner preserves held charge during edge key")
	expect(not pointer(driver, View.button_rect("helper").get_center(), true), "mouse cannot steal keyboard owner")
	key(driver, KEY_SPACE, false)
	expect(driver.snapshot().edges[0].adhesion < charged.edges[0].adhesion, "Space release knocks once")
	key(driver, KEY_D)
	key(driver, KEY_RIGHT)
	advance(driver, 0.2)
	key(driver, KEY_D, false)
	key(driver, KEY_RIGHT, false)
	expect(driver.snapshot().mold_omega > 0 and driver.snapshot().tray_x > 0, "one keyboard owner can turn and slide continuously")
	var omega: float = driver.snapshot().mold_omega
	advance(driver, 0.05)
	expect(driver.snapshot().mold_omega > 0 and driver.snapshot().mold_omega < omega, "release retains inertia")
	driver.clear_input()
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1, "whole retry alternates physical config")
	var point := View.edge_point(driver.snapshot(), 0)
	var before: Dictionary = driver.snapshot()
	expect(pointer(driver, point, true, 3), "owned touch charges visible edge")
	advance(driver, 0.3)
	expect(not pointer(driver, point, true, 8) and not key(driver, KEY_SPACE), "other finger and keyboard cannot steal touch")
	expect(not move(driver, point + Vector2(20, 20), 8), "unowned touch drag rejected")
	expect(pointer(driver, point, false, 3, true), "touch cancellation handled")
	pointer(driver, point, false, 3)
	expect(driver.snapshot().edges == before.edges and not driver.snapshot().charging, "canceled touch never knocks on late release")
	pointer(driver, View.edge_point(driver.snapshot(), 0), true)
	advance(driver, 0.3)
	driver.clear_input()
	pointer(driver, point, false)
	expect(driver.snapshot().edges == before.edges, "lifecycle clear cancels mouse charge")
	var tray_before: Dictionary = driver.snapshot()
	pointer(driver, View.tray_point(tray_before), true)
	expect(driver.snapshot().tray_target == tray_before.tray_target, "pressing tray handle does not jump target")
	move(driver, View.tray_point(tray_before) + Vector2(20, 0))
	expect(is_equal_approx(driver.snapshot().tray_target, tray_before.tray_x + 20.0 / (View.STAGE.size.y / View.HEIGHT)), "tray drag preserves actual handle offset")
	pointer(driver, Vector2.ZERO, false)
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	expect(not driver.handle_input(emulated, View.button_rect("tap").get_center()), "touch emulated mouse excluded")
	expect(not pointer(driver, Vector2(NAN, INF), true), "nonfinite pointer rejected")
	var unchanged: Dictionary = driver.snapshot()
	driver.step(NAN)
	driver.step(INF)
	driver.step(-1)
	expect(driver.snapshot() == unchanged, "invalid step leaves all input and physics unchanged")
	driver.reset(false, "noon")
	for knock in 12:
		key(driver, KEY_SPACE)
		advance(driver, 0.9)
		key(driver, KEY_SPACE, false)
		if driver.snapshot().phase == "cracked":
			break
	var broken: Dictionary = driver.snapshot()
	expect(broken.phase == "cracked" and broken.mistakes == 1, "actual repeated keyboard charge cracks current cookie")
	tap(driver, KEY_X)
	expect(driver.snapshot().phase == "molded" and driver.snapshot().mistakes == 1 and driver.snapshot().elapsed == broken.elapsed and driver.snapshot().variant == broken.variant, "X free retry retains time mistakes and config")
	for route in 3:
		driver.reset(false, "noon")
		var result := solve(driver, route == 0, 4 if route == 2 else -1, route == 2)
		print("COOKIE_INPUT_ROUTE route=%d phase=%s caught=%d score=%d elapsed=%.3f" % [route, result.phase, result.caught, result.score, result.elapsed])
		expect(result.success and result.caught == 6, "full actual keyboard/mouse/owned-touch route %d" % route)
		if route > 0:
			expect(result.devil == (route == 2), "actual pointer low/high inertia distinction")
		var summary: Dictionary = driver.score_summary(false)
		expect(summary.total == result.score and summary.rows[0].count == result.caught, "result rows consume model score")
	expect(driver.score_summary(true).qualification_text == "練習回合不取得拍貼。", "practice truthfully excludes rewards")
	driver.reset(false, "noon")
	tap(driver, KEY_R)
	advance(driver, 151)
	expect(driver.snapshot().ended and not driver.snapshot().ordinary_eligible and driver.snapshot().caught == 0, "helper-only idle has no completion or ordinary award")
	expect(driver.score_summary(false).qualification_text.contains("沒有普通"), "idle summary truthful")
	print("Cookie mold driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
