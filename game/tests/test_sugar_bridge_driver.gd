extends SceneTree
const Driver = preload("res://game/minigames/sugar_bridge_driver.gd")
const View = preload("res://game/minigames/sugar_bridge_view.gd")
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

func motion(driver, point: Vector2) -> bool:
	return driver.handle_input(InputEventMouseMotion.new(), point)

func touch(driver, index: int, point: Vector2, pressed: bool) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return driver.handle_input(event, point)

func drag(driver, endpoint: int, destination: Vector2) -> void:
	mouse(driver, View.design_point(driver.snapshot().endpoints[endpoint].position), true)
	motion(driver, View.design_point(destination))
	mouse(driver, View.design_point(destination), false)

func advance(driver, seconds: float) -> void:
	for i in ceili(seconds / 0.25):
		driver.step(0.25)

func keyboard_pin(driver, endpoint: int, destination: Vector2) -> void:
	for i in 4:
		if driver.snapshot().selected == endpoint:
			break
		tap(driver, KEY_TAB)
	tap(driver, KEY_SPACE)
	for axis in 2:
		var difference: float = destination[axis] - Vector2(driver.snapshot().endpoints[endpoint].position)[axis]
		var code: Key = (KEY_RIGHT if difference >= 0 else KEY_LEFT) if axis == 0 else (KEY_UP if difference >= 0 else KEY_DOWN)
		key(driver, code)
		var remaining := absf(difference) / Driver.MOVE_SPEED
		while remaining > 0.00001:
			var delta := minf(remaining, 0.25)
			driver.step(delta)
			remaining -= delta
		key(driver, code, false)
	tap(driver, KEY_F)

func _run() -> void:
	var driver = Driver.new()
	driver.reset(false, "noon")
	var state: Dictionary = driver.snapshot()
	for field in ["elapsed", "score", "mistakes", "ended", "success", "devil", "ordinary_eligible", "progress_text", "time_text", "feedback_text"]:
		expect(state.has(field), "session field " + field)
	expect(state.time_text == "150 秒", "complete 150 second round")
	expect(not key(driver, KEY_G) and not key(driver, KEY_TAB, true, true), "unrelated and repeated keys rejected")
	tap(driver, KEY_TAB)
	expect(driver.snapshot().selected == 1, "Tab selects next endpoint")
	tap(driver, KEY_SPACE)
	key(driver, KEY_RIGHT)
	key(driver, KEY_UP)
	driver.step(0.2)
	key(driver, KEY_RIGHT, false)
	key(driver, KEY_UP, false)
	state = driver.snapshot()
	expect(state.grabbed == 1 and state.endpoints[1].position.x > 1 and state.endpoints[1].position.y > -1, "arrows continuously move the grabbed endpoint")
	var position: Vector2 = state.endpoints[1].position
	driver.step(NAN)
	driver.step(INF)
	driver.step(-1)
	expect(driver.snapshot().endpoints[1].position == position, "invalid deltas do not move the selection")
	driver.clear_input()
	expect(driver.snapshot().grabbed == -1 and not driver.snapshot().bean.active, "clear cancels without a shot")
	tap(driver, KEY_R)
	expect(driver.snapshot().helper[1], "R holds only selected endpoint")
	tap(driver, KEY_SPACE)
	expect(not driver.snapshot().helper[1], "grabbing releases selected AI holder")
	tap(driver, KEY_TAB)
	expect(driver.snapshot().grabbed == -1 and not driver.snapshot().bean.active, "changing endpoint cancels without shooting")
	tap(driver, KEY_X)
	expect(driver.snapshot().bands[1].generation > 0, "X recalls selected material")
	driver.reset(false, "dawn")
	expect(driver.snapshot().variant == 1, "retry changes real material configuration")
	drag(driver, 0, Vector2.ZERO)
	expect(driver.snapshot().endpoints[0].pin == 0, "mouse drag release pins first endpoint")
	var point := View.design_point(driver.snapshot().endpoints[1].position)
	expect(touch(driver, 3, point, true), "touch grabs second endpoint")
	expect(not mouse(driver, View.design_point(driver.snapshot().endpoints[2].position), true), "second device cannot steal drag")
	var move := InputEventScreenDrag.new()
	move.index = 8
	expect(not driver.handle_input(move, View.design_point(Vector2(8.8, 0))), "unowned touch cannot move endpoint")
	move.index = 3
	expect(driver.handle_input(move, View.design_point(Vector2(8.8, 0))), "owned touch moves continuously")
	expect(driver.snapshot().endpoints[1].position.is_equal_approx(Vector2(8.8, 0)), "touch maps to absolute model coordinates")
	touch(driver, 3, View.design_point(Vector2(8.8, 0)), false)
	expect(driver.snapshot().endpoints[1].pin == 2, "touch release pins destination")
	tap(driver, KEY_ENTER)
	advance(driver, 10)
	expect(driver.snapshot().delivered == 1, "actual input long bridge delivers first ball")
	for i in 2:
		mouse(driver, View.button_rect("load").get_center(), true)
		mouse(driver, Vector2(-100, -100), false)
		advance(driver, 10)
	state = driver.snapshot()
	expect(state.success and state.delivered == 3 and state.score == 400, "three separately loaded balls complete actual route")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.total == state.score and summary.rows[0].count == 3, "score rows follow actual snapshot")
	expect(summary.qualification_text.contains("普通拍貼資格") and summary.qualification_text.contains("先彈中"), "result truthfully explains ordinary and missing devil")
	expect(driver.score_summary(true).qualification_text == "練習回合不取得拍貼。", "practice has no cards")
	driver.reset(true, "night")
	advance(driver, 151)
	expect(driver.snapshot().ended and not driver.snapshot().ordinary_eligible, "idle timeout has no participation award")
	expect(driver.score_summary(false).qualification_text.contains("沒有普通"), "idle result avoids false ordinary claim")
	driver.reset(false, "noon")
	tap(driver, KEY_ENTER)
	advance(driver, 151)
	expect(driver.snapshot().ended and not driver.snapshot().success and driver.snapshot().ordinary_eligible, "played failure still participates honestly")
	driver.reset(false, "noon")
	drag(driver, 0, Vector2.ZERO)
	mouse(driver, View.design_point(driver.snapshot().endpoints[1].position), true)
	motion(driver, View.design_point(Vector2(-0.7, -0.3)))
	driver.clear_input()
	mouse(driver, View.design_point(Vector2(-0.7, -0.3)), false)
	expect(not driver.snapshot().bean.active and driver.snapshot().grabbed == -1, "late pointer release after cancellation cannot shoot")
	tap(driver, KEY_SPACE)
	key(driver, KEY_RIGHT)
	key(driver, KEY_UP)
	driver.step(0.1)
	key(driver, KEY_RIGHT, false)
	key(driver, KEY_UP, false)
	tap(driver, KEY_F)
	expect(driver.snapshot().grabbed == -1, "F pins grabbed endpoint and ends keyboard drag")
	expect(not mouse(driver, Vector2(NAN, INF), true), "nonfinite press rejected")
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	expect(not driver.handle_input(emulated, View.button_rect("load").get_center()), "emulated mouse cannot duplicate touch")
	var keyboard_driver = Driver.new()
	keyboard_driver.reset(false, "noon")
	keyboard_pin(keyboard_driver, 0, Vector2.ZERO)
	keyboard_pin(keyboard_driver, 1, Vector2(4, 0))
	keyboard_pin(keyboard_driver, 2, Vector2(4, 0))
	keyboard_pin(keyboard_driver, 3, Vector2(8, 0))
	expect(keyboard_driver.snapshot().endpoints.all(func(endpoint): return endpoint.pin >= 0), "keyboard alone builds complete two-band route")
	for i in 3:
		tap(keyboard_driver, KEY_ENTER)
	advance(keyboard_driver, 14)
	expect(keyboard_driver.snapshot().success and keyboard_driver.snapshot().delivered == 3, "keyboard alone loads and completes short bridge")
	var sling_driver = Driver.new()
	sling_driver.reset(true, "noon")
	drag(sling_driver, 0, Vector2.ZERO)
	state = sling_driver.snapshot()
	var pull: Vector2 = (Vector2(state.hopper) + Vector2(0, 2.4 * 0.9 * 0.9)) / (1 - 4 * float(state.elasticity) * 0.9)
	drag(sling_driver, 1, pull)
	advance(sling_driver, 1.25)
	expect(sling_driver.snapshot().bands[0].hit, "actual pointer release trajectory hits side hopper")
	drag(sling_driver, 1, Vector2(8, 0))
	for i in 3:
		tap(sling_driver, KEY_ENTER)
		advance(sling_driver, 14)
	expect(sling_driver.snapshot().devil and sling_driver.snapshot().score == 500, "same material after real sling delivers three balls and earns devil")
	var helper_driver = Driver.new()
	helper_driver.reset(false, "noon")
	tap(helper_driver, KEY_SPACE)
	tap(helper_driver, KEY_R)
	expect(helper_driver.snapshot().grabbed == -1 and helper_driver.snapshot().helper[0], "AI takes over a keyboard-held endpoint")
	expect(mouse(helper_driver, View.design_point(helper_driver.snapshot().endpoints[1].position), true) and helper_driver.snapshot().grabbed == 1, "mouse can grab immediately after Space then R")
	helper_driver.clear_input()
	tap(helper_driver, KEY_SPACE)
	tap(helper_driver, KEY_R)
	expect(touch(helper_driver, 4, View.design_point(helper_driver.snapshot().endpoints[2].position), true) and helper_driver.snapshot().grabbed == 2, "touch can grab immediately after Space then R")
	var shared_driver = Driver.new()
	shared_driver.reset(false, "noon")
	for endpoint in 4:
		drag(shared_driver, endpoint, shared_driver.snapshot().anchors[[0, 1, 1, 2][endpoint]])
	for i in 3:
		mouse(shared_driver, View.button_rect("next").get_center(), true)
		mouse(shared_driver, View.button_rect("next").get_center(), false)
	expect(shared_driver.snapshot().selected == 2, "on-screen Next selects second material at shared support")
	var central: Vector2 = shared_driver.snapshot().anchors[1]
	mouse(shared_driver, View.design_point(central), true)
	motion(shared_driver, View.design_point(central + Vector2(0, 0.75)))
	expect(shared_driver.snapshot().grabbed == 2 and shared_driver.snapshot().endpoints[1].pin == 1 and shared_driver.snapshot().endpoints[2].position.is_equal_approx(central + Vector2(0, 0.75)), "shared knob drag moves the selected second material only")
	shared_driver.clear_input()
	mouse(shared_driver, View.design_point(shared_driver.snapshot().anchors[0]), true)
	expect(shared_driver.snapshot().grabbed == 0, "selected endpoint does not override a genuinely nearer pointer hit")
	shared_driver.clear_input()
	shared_driver.reset(false, "noon")
	mouse(shared_driver, View.button_rect("grab").get_center(), true)
	mouse(shared_driver, View.button_rect("grab").get_center(), false)
	key(shared_driver, KEY_RIGHT)
	shared_driver.step(0.1)
	key(shared_driver, KEY_RIGHT, false)
	expect(shared_driver.snapshot().grabbed == 0 and shared_driver.snapshot().endpoints[0].position.x > -1, "on-screen Grab intentionally toggles arrow-controlled grab after pointer release")
	print("Sugar bridge driver: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
