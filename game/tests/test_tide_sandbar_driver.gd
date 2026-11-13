extends SceneTree
const Driver = preload("res://game/minigames/tide_sandbar_driver.gd")
const View = preload("res://game/minigames/tide_sandbar_view.gd")
const Model = preload("res://game/minigames/tide_sandbar_model.gd")
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
func moved(driver, seconds: float = 0.5) -> Vector2:
	var before: Vector2 = driver.snapshot().position
	driver.step(seconds)
	return driver.snapshot().position - before
func _run() -> void:
	var driver = Driver.new()
	driver.reset(false, "noon")
	var state: Dictionary = driver.snapshot()
	for field in ["elapsed", "score", "mistakes", "ended", "success", "devil", "ordinary_eligible", "progress_text", "time_text", "feedback_text"]:
		expect(state.has(field), "normalized field: " + field)
	expect(state.variant == 0 and not state.ordinary_eligible, "first round uses the first layout without eligibility")
	expect(not key(driver, KEY_F), "unrelated key unconsumed")
	expect(not key(driver, KEY_D, true, true), "echo rejected")
	expect(moved(driver) == Vector2.ZERO, "echo never moves")
	expect(key(driver, KEY_D), "move press consumed")
	var walk := moved(driver, 0.25)
	expect(walk.x > 0.0 and is_equal_approx(walk.length(), Model.WALK_SPEED * 0.25), "held key walks at walking speed")
	key(driver, KEY_SHIFT)
	expect(is_equal_approx(moved(driver, 0.25).length(), Model.RUN_SPEED * 0.25), "Shift runs")
	key(driver, KEY_SHIFT, false)
	key(driver, KEY_RIGHT)
	key(driver, KEY_D, false)
	expect(moved(driver, 0.1).x > 0.0, "alias keeps direction held")
	key(driver, KEY_A)
	expect(moved(driver, 0.1) == Vector2.ZERO, "opposing directions cancel")
	key(driver, KEY_A, false)
	key(driver, KEY_RIGHT, false)
	expect(moved(driver, 0.1) == Vector2.ZERO, "release stops")
	driver.reset(false, "noon")
	expect(driver.snapshot().variant == 1, "retry alternates tide period and highland side")
	key(driver, KEY_W)
	key(driver, KEY_D)
	var diagonal := moved(driver, 0.1)
	expect(is_equal_approx(diagonal.length(), Model.WALK_SPEED * 0.1), "diagonal keys are normalized, not faster")
	driver.clear_input()
	expect(moved(driver, 0.1) == Vector2.ZERO, "clear releases every owner")
	driver.reset(false, "noon")
	var right: Vector2 = View.button_rect("right").get_center()
	expect(mouse(driver, right, true), "pointer press consumed")
	expect(moved(driver, 0.1).x > 0.0, "pointer button walks")
	key(driver, KEY_LEFT)
	expect(moved(driver, 0.1) == Vector2.ZERO, "pointer and keyboard owners combine")
	expect(mouse(driver, Vector2(-999, -999), false), "release outside consumed")
	expect(moved(driver, 0.1).x < 0.0, "pointer release keeps keyboard owner")
	driver.clear_input()
	# Marking: pointer and key reach the same rule.
	driver.reset(false, "noon")
	key(driver, KEY_SPACE)
	key(driver, KEY_SPACE, false)
	var by_key: String = driver.snapshot().feedback
	driver.reset(false, "noon")
	mouse(driver, View.button_rect("mark").get_center(), true)
	mouse(driver, Vector2.ZERO, false)
	expect(driver.snapshot().feedback == by_key and by_key.contains("已有路標"), "pointer and key use identical marking")
	key(driver, KEY_T)
	key(driver, KEY_T, false)
	expect(not driver.snapshot().tide_paused, "tide pause refused without assistance")
	driver.reset(true, "noon")
	key(driver, KEY_T)
	expect(driver.snapshot().tide_paused, "assisted T pauses water")
	key(driver, KEY_T)
	expect(driver.snapshot().tide_paused, "held key does not toggle twice")
	key(driver, KEY_T, false)
	key(driver, KEY_T)
	key(driver, KEY_T, false)
	expect(not driver.snapshot().tide_paused, "second press resumes water")
	var summary: Dictionary = driver.score_summary(false)
	expect(summary.rows.size() == 3 and summary.total == 0 and summary.qualification_text.contains("小惡魔"), "summary explains reefs, return and devil rule")
	expect(driver.score_summary(true).qualification_text.contains("練習"), "practice summary withholds cards")
	for i in 700:
		driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().ordinary_eligible and not driver.snapshot().success, "timeout ends truthfully")
	key(driver, KEY_D)
	driver.step(0.25)
	expect(driver.snapshot().ended and driver.snapshot().time_text == "0 秒", "ended round ignores input")
	print("Tide sandbar driver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
