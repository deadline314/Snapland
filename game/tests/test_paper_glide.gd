extends SceneTree

const Model = preload("res://game/minigames/paper_glide_model.gd")
const View = preload("res://game/minigames/paper_glide_view.gd")
const Driver = preload("res://game/minigames/paper_glide_driver.gd")
const Session = preload("res://game/minigames/session.gd")

var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	test_setup()
	test_flights()
	test_misses()
	test_controls()
	test_session()
	for issue in _errors:
		push_error(issue)
	if _errors.is_empty():
		print("PASS: paper glide folding, moving windows, wingtip braking and collection")
	quit(int(not _errors.is_empty()))

func test_setup() -> void:
	var model := Model.new()
	model.reset(true, 0)
	var original := model.snapshot()
	model.fold_side(Model.LEFT)
	model.launch_or_recover()
	check(model.phase() == Model.SETUP and model.snapshot().folded == Model.LEFT, "a single folded wing cannot launch")
	model.select_fold(1)
	var narrow := model.snapshot()
	check(narrow.folded == 0 and narrow.preview.size() == 10, "changing fold reopens both wings and regenerates bounded preview")
	check(narrow.preview[-1].z > original.preview[-1].z and narrow.preview[-1].y < original.preview[-1].y,
		"narrow wing actually travels farther and sinks faster over a fixed interval")
	model.change_power(1)
	var upper := model.snapshot()
	check(upper.preview[-1].z > narrow.preview[-1].z, "initial power changes the forecast flight distance")
	model.change_power(10)
	check(model.snapshot().power == 2, "power stays within the detents")
	model.toggle_helper()
	model.fold_side(Model.RIGHT)
	check(model.snapshot().folded == Model.BOTH and model.snapshot().fold == 1, "AI folds the other wing using the selected crease")
	model.launch_or_recover()
	for tick in 108:
		model.step(Model.TICK)
	check(model.snapshot().position.is_equal_approx(upper.preview[-1]), "first-segment preview reuses the same flight equations")
	var elapsed: float = model.snapshot().elapsed
	model.steer(-1.0)
	model.launch_or_recover()
	check(model.phase() == Model.SETUP and model.snapshot().folded == 0 and model.snapshot().steer == 0.0 and model.snapshot().elapsed == elapsed,
		"assisted recall preserves the round clock and clears steering and folds")
	model.reset(true, 1)
	var heavy := model.snapshot()
	check(heavy.preview[-1].y < original.preview[-1].y and heavy.preview[-1].x < original.preview[-1].x, "heavier paper and opposite wind change the live preview")

func test_flights() -> void:
	for layout in 2:
		for assisted in [false, true]:
			var model := Model.new()
			model.reset(assisted, layout)
			if layout == 1:
				model.select_fold(1)
				model.change_power(1)
			model.fold_side(Model.BOTH)
			model.launch_or_recover()
			var wanted_bonus: bool = assisted or layout == 1
			var initial_window: Dictionary = model.snapshot().windows[0]
			var braked_speed := 0.0
			for tick in 1400:
				if model.phase() != Model.FLIGHT:
					break
				var before := model.snapshot()
				var distance: float = before.position.z
				if layout == 0:
					model.steer(1.0 if distance >= 10.0 and distance < 14.0 else (-1.0 if distance >= 21.0 and distance < (24.0 if wanted_bonus else 26.5) else 0.0))
				else:
					model.steer(-1.0 if distance >= 20.0 and distance < 23.0 else 0.0)
				model.step(Model.TICK)
				var after := model.snapshot()
				if after.braked and not before.braked:
					braked_speed = after.speed
					check(after.speed < before.speed * 0.72 and after.passed == 2, "wingtip collision drops forward speed only after both windows")
			var result := model.snapshot()
			check(result.windows[0] != initial_window, "window clearance and position advance with real flight time")
			check(result.ended and result.success and result.passed == 2 and result.ordinary_eligible, "both courses can land through two moving windows")
			check(result.devil == wanted_bonus and (braked_speed > 0.0) == wanted_bonus, "bell provenance controls the real challenge result")
			check(result.score == (500 if wanted_bonus else 400), "validated triggers produce the expected bounded result score")
			var notes := model.consume_notes()
			check(notes == ([1, 2, 3, 0] if wanted_bonus else [1, 2, 0]) and model.consume_notes().is_empty(),
				"each physical event emits exactly one playable cue")

func test_misses() -> void:
	var model := Model.new()
	model.reset(false, 0)
	model.fold_side(Model.BOTH)
	model.launch_or_recover()
	model.launch_or_recover()
	check(model.phase() == Model.FLIGHT, "standard mode cannot recall during flight")
	for tick in 400:
		model.step(Model.TICK)
	check(model.phase() == Model.MISSED and model.snapshot().passed == 1 and model.snapshot().feedback.contains("翼尖"), "a glider center can enter while its wide wing clips the second window")
	model.launch_or_recover()
	check(model.phase() == Model.SETUP and model.snapshot().best == 1 and model.snapshot().mistakes == 1, "recovery preserves best pass count without double scoring")
	for tick in 305:
		model.step(0.25)
	check(model.snapshot().ordinary_eligible and not model.snapshot().success, "natural result remembers an actual launched flight")
	model.reset(false, 0)
	for tick in 305:
		model.step(0.25)
	check(model.snapshot().ended and not model.snapshot().ordinary_eligible, "idle timeout cannot publish a card")

func test_controls() -> void:
	var driver := Driver.new()
	driver.reset(true, "noon")
	driver.handle_input(key(KEY_2, true), Vector2.ZERO)
	driver.handle_input(key(KEY_R, true), Vector2.ZERO)
	var left := View.button_rect(View.LEFT).get_center()
	var outside := Vector2(-20, -20)
	check(driver.handle_input(touch(true), left) and driver.snapshot().folded == Model.BOTH and driver.snapshot().fold == 1,
		"single touch folds the real chosen profile with AI")
	var launch := View.button_rect(View.THROW).get_center()
	check(driver.handle_input(touch(true), launch) and driver.snapshot().phase == Model.FLIGHT, "touch launches its folded plane")
	check(driver.handle_input(touch(true), left) and driver.snapshot().steer == -1.0, "left touch owns steering")
	driver.handle_input(key(KEY_D, true), Vector2.ZERO)
	check(driver.snapshot().steer == 0.0, "opposing sources neutralize")
	check(driver.handle_input(touch(false), outside) and driver.snapshot().steer == 1.0, "out-of-bounds release clears only its own steering source")
	var cancelled := touch(false)
	cancelled.canceled = true
	driver.handle_input(cancelled, outside)
	check(driver.snapshot().steer == 0.0, "cancel clears remaining held inputs")
	check(not driver.handle_input(touch(true), View.button_rect(View.NARROW).get_center()), "hidden fold controls ignore in-flight touches")
	driver.handle_input(key(KEY_SPACE, true), Vector2.ZERO)
	check(driver.snapshot().phase == Model.SETUP and driver.snapshot().steer == 0.0, "assisted keyboard recall returns to safe setup")

func test_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var results: Array[Dictionary] = []
	session.finished.connect(func(result: Dictionary): results.append(result))
	session.start("game-034")
	participate(session)
	for tick in 310:
		session._process(0.25)
	check(results.size() == 1 and results[0].ordinary_eligible and not results[0].success and not results[0].devil,
		"normal Session finalizes exactly one honest participation result")
	session.free()

static func participate(session: Control) -> void:
	for button in [KEY_A, KEY_D, KEY_SPACE]:
		session._unhandled_input(key(button, true))
		session._unhandled_input(key(button, false))
	session._unhandled_input(key(KEY_A, true))
	for tick in 32:
		session._process(0.1)
	session._unhandled_input(key(KEY_A, false))

static func key(code: int, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	return event

func touch(down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = down
	return event

func check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
