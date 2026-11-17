extends Node
## Scripted standalone workbench input/GPU evidence; does not launch Main or award cards.
const Driver = preload("res://game/minigames/sugar_bridge_driver.gd")
const View = preload("res://game/minigames/sugar_bridge_view.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
var driver = Driver.new()
var workbench: Control
var output := ""
var requested := Vector2i.ZERO
var failures: Array[String] = []
var checks := 0
var captures: Array[String] = []
var large := false
var started := Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - started > 120000:
		push_error("Standalone sugar workbench exceeded 120 second guard")
		get_tree().quit(1)

func _ready() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame

func sync() -> void:
	driver.present("noon", large)

func advance(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var delta := minf(remaining, 1.0 / 60.0)
		driver.step(delta)
		remaining -= delta
	sync()

func pointer(point: Vector2, action: String) -> void:
	var screen := workbench.get_global_transform_with_canvas() * point
	if action == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		motion.global_position = screen
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
	else:
		var button := InputEventMouseButton.new()
		button.position = screen
		button.global_position = screen
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = action == "press"
		Input.parse_input_event(button)
	await frames(1)
	sync()

func drag(endpoint: int, destination: Vector2) -> void:
	await pointer(View.design_point(driver.snapshot().endpoints[endpoint].position), "press")
	check(driver.snapshot().grabbed == endpoint, "actual pointer grabs endpoint %d" % endpoint)
	await pointer(View.design_point(destination), "move")
	await pointer(View.design_point(destination), "release")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)
	sync()

func capture(label: String) -> void:
	sync()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output.path_join(label + ".png")
	check(image != null and image.get_size() == requested and image.save_png(path) == OK, "GPU capture " + label)
	captures.append(path)

func _run() -> void:
	output = OS.get_environment("SNAPLAND_SUGAR_WORKBENCH_OUTPUT")
	var dimensions := OS.get_environment("SNAPLAND_SUGAR_WORKBENCH_SIZE").split("x")
	var profile := OS.get_environment("SNAPLAND_SAVE_PATH")
	if DisplayServer.get_name() == "headless" or not profile.is_absolute_path() or not output.is_absolute_path() or dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
		push_error("Workbench review requires GPU, absolute isolated save/output and WIDTHxHEIGHT")
		get_tree().quit(1)
		return
	requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if requested not in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)] or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Unsupported workbench viewport or unwritable output")
		get_tree().quit(1)
		return
	large = requested == Vector2i(800, 600)
	Paper.set_text_scale(1.25 if large else 1.0)
	Paper.set_reduced_motion(large)
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = requested
	get_window().size = requested
	await frames(3)
	var background := ColorRect.new()
	background.color = Paper.DEEP
	background.size = Vector2(requested)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	driver.reset(false, "noon")
	workbench = driver.create_view()
	check(workbench != null, "GPU driver creates actual retained workbench")
	if workbench == null:
		get_tree().quit(1)
		return
	add_child(workbench)
	workbench.size = View.DESIGN_SIZE
	var scale_factor := minf(float(requested.x) / View.DESIGN_SIZE.x, float(requested.y) / View.DESIGN_SIZE.y)
	workbench.scale = Vector2.ONE * scale_factor
	workbench.position = (Vector2(requested) - View.DESIGN_SIZE * scale_factor) * 0.5
	workbench.grab_focus()
	sync()
	await frames(3)
	check(get_window().size == requested and get_viewport().get_visible_rect().size == Vector2(requested), "actual physical viewport matches requested dimensions")
	for command in View.COMMANDS:
		var rect := View.button_rect(command)
		var screen := Rect2(workbench.get_global_transform_with_canvas() * rect.position, rect.size * scale_factor)
		check(Rect2(Vector2.ZERO, Vector2(requested)).encloses(screen), "physical command bounds " + command)
	check(Paper.font().get_string_size(workbench.status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, workbench.text_size(17)).x <= 1200, "actual physical status width fits")
	for text in ["金固定 · 白抓取", "藍 AI · 圈選中", "越長越細、越下垂"]:
		check(Paper.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, workbench.text_size(16)).x <= 260, "actual physical right-column width " + text)
	await capture("01-initial")
	await key(KEY_TAB)
	check(driver.snapshot().selected == 1, "native focused Tab changes endpoint")
	for endpoint in 4:
		await drag(endpoint, Vector2(driver.snapshot().anchors[[0, 1, 1, 2][endpoint]]))
	check(driver.snapshot().endpoints.all(func(endpoint): return endpoint.pin >= 0), "actual drag route builds complete short bridge")
	for i in 3:
		await pointer(View.button_rect("next").get_center(), "press")
		await pointer(View.button_rect("next").get_center(), "release")
	check(driver.snapshot().selected == 2, "actual on-screen Next selects second material at shared support")
	var central: Vector2 = driver.snapshot().anchors[1]
	await pointer(View.design_point(central), "press")
	await pointer(View.design_point(central + Vector2(0, 0.75)), "move")
	check(driver.snapshot().grabbed == 2 and driver.snapshot().endpoints[1].pin == 1, "actual shared knob drag honors selected second material")
	await capture("02a-shared-support-drag")
	await pointer(View.design_point(central), "release")
	check(driver.snapshot().endpoints[2].pin == 1, "shared selected endpoint repins through actual pointer release")
	for i in 3:
		await key(KEY_ENTER)
	var queued: Array = driver.snapshot().balls
	check(queued.all(func(ball): return ball.state == "queued") and queued[0].position.distance_to(queued[1].position) > 0.28 and queued[1].position.distance_to(queued[2].position) > 0.28, "three actual loads remain visibly distinct in feed queue")
	await capture("02-short-loaded")
	advance(1.2)
	check(driver.snapshot().balls.filter(func(ball): return ball.state == "rolling").size() == 3, "three distinct balls actually roll on short bridge")
	await capture("03-short-rolling")
	advance(14)
	check(driver.snapshot().success, "short bridge succeeds from actual input")
	driver.reset(false, "noon")
	sync()
	await drag(0, Vector2.ZERO)
	await drag(1, driver.snapshot().anchors[2])
	await key(KEY_ENTER)
	await key(KEY_ENTER)
	advance(0.1)
	await capture("04-long-loaded")
	driver.clear_input()
	driver.reset(true, "noon")
	sync()
	await drag(0, Vector2.ZERO)
	var state: Dictionary = driver.snapshot()
	var pull: Vector2 = (Vector2(state.hopper) + Vector2(0, 2.4 * 0.9 * 0.9)) / (1 - 4 * float(state.elasticity) * 0.9)
	await pointer(View.design_point(state.endpoints[1].position), "press")
	await pointer(View.design_point(pull), "move")
	check(driver.snapshot().grabbed == 1 and not driver.snapshot().preview.is_empty(), "actual pull holds endpoint and shows assisted trajectory")
	await capture("05-trial-pull")
	await pointer(View.design_point(pull), "release")
	advance(1.25)
	check(driver.snapshot().bands[0].hit, "released bean actually collides with side hopper")
	await capture("06-trial-hit")
	await drag(1, driver.snapshot().anchors[2])
	await key(KEY_ENTER)
	advance(2.0)
	check(driver.snapshot().balls[0].state == "rolling" and driver.snapshot().bands[0].hit, "real ball traverses same hit material")
	await capture("07-same-band-rolling")
	advance(14)
	for i in 2:
		await key(KEY_ENTER)
		advance(14)
	check(driver.snapshot().devil and driver.snapshot().score == 500, "actual same-band transport completes devil route")
	var report := {"scope": "standalone workbench scripted input/GPU capture; no Main, catalog or card-award claim", "viewport": requested, "ui_scale": Paper.text_scale(), "reduced_motion": large, "save_path": profile, "checks": checks, "failures": failures, "captures": captures, "actual_final_snapshot": driver.snapshot()}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	driver.clear_input()
	print("Sugar bridge standalone GPU: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
