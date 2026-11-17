extends Node
## Native scripted GPU/input evidence; does not enter Main or grant cards.
const Driver = preload("res://game/minigames/jelly_trampoline_driver.gd")
const View = preload("res://game/minigames/jelly_trampoline_view.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
var driver = Driver.new()
var workbench: Control
var output := ""
var requested := Vector2i.ZERO
var checks := 0
var failures := 0
var large := false
func _ready() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame
func sync() -> void:
	driver.present("noon", large)
func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.00000001:
		var dt := minf(left, 1.0 / 60.0)
		driver.step(dt)
		left -= dt
	sync()
func key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await frames(1)
	sync()
func pointer(point: Vector2, pressed: bool, finger := -1, canceled := false, emulated := false) -> void:
	var screen := workbench.get_global_transform_with_canvas() * point
	if finger >= 0:
		var event := InputEventScreenTouch.new()
		event.index = finger
		event.position = screen
		event.pressed = pressed
		event.canceled = canceled
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.global_position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
		Input.parse_input_event(event)
	await frames(1)
	sync()
func command(name: String, pressed: bool, route := 0) -> void:
	if route == 0:
		for code in View.KEYS:
			if View.KEYS[code] == name:
				await key(code, pressed)
				return
	else:
		await pointer(View.button_rect(name).get_center(), pressed, 4 if route == 2 else -1)
func action(name: String, route := 0) -> void:
	await command(name, true, route)
	await command(name, false, route)
func configure(x: float, tilt: float, route := 0) -> void:
	for i in 20:
		var state: Dictionary = driver.snapshot()
		if is_equal_approx(state.bed.x, x):
			break
		await action("bed_right" if state.bed.x < x else "bed_left", route)
	for i in 20:
		var state: Dictionary = driver.snapshot()
		if is_equal_approx(state.tilt, tilt):
			break
		await action("tilt_right" if state.tilt < tilt else "tilt_left", route)
func launch(seconds: float, route := 0) -> void:
	await command("charge", true, route)
	advance(seconds)
	await command("charge", false, route)
func wait_ready() -> void:
	for i in 600:
		if driver.snapshot().fruit.ready or driver.snapshot().ended:
			break
		driver.step(1.0 / 120.0)
	sync()
func shot(route := 0) -> void:
	var mass := float(driver.snapshot().fruit.mass)
	await configure(380 if is_equal_approx(mass, 1.0) else (420 if mass > 1.0 else 340), 28 if mass > 1.0 else 21, route)
	await launch(1.28 if mass >= 1.0 else 1.26, route)
	wait_ready()
func capture(label: String) -> void:
	sync()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and image.get_size() == requested and image.save_png(output.path_join(label + ".png")) == OK, "raw physical capture " + label)
	print("JELLY_CAPTURE %s state=%s" % [label, JSON.stringify(driver.snapshot())])
func reset_a() -> void:
	driver.reset(false, "noon")
	if driver.snapshot().variant != 0:
		driver.reset(false, "noon")
	workbench.grab_focus()
	sync()
func _run() -> void:
	output = OS.get_environment("SNAPLAND_JELLY_WORKBENCH_OUTPUT")
	var dimensions := OS.get_environment("SNAPLAND_JELLY_WORKBENCH_SIZE").split("x")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or dimensions.size() != 2:
		push_error("Jelly native review requires GPU and isolated absolute save/output and WIDTHxHEIGHT")
		get_tree().quit(1)
		return
	requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if requested not in [Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(800, 600)] or DirAccess.make_dir_recursive_absolute(output) != OK:
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
	background.size = requested
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	driver.reset(false, "noon")
	workbench = driver.create_view()
	add_child(workbench)
	workbench.size = View.DESIGN_SIZE
	var scale_factor := minf(float(requested.x) / 1280, float(requested.y) / 720)
	workbench.scale = Vector2.ONE * scale_factor
	workbench.position = (Vector2(requested) - View.DESIGN_SIZE * scale_factor) * 0.5
	var title := Label.new()
	title.text = "果凍彈床"
	title.position = workbench.position + Vector2(24, 30) * scale_factor
	title.add_theme_font_override("font", Paper.font())
	title.add_theme_font_size_override("font_size", 28 if not large else 23)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "斜壓改變水平速度 · AI接穩等你放行 · X重置不回時間"
	subtitle.position = workbench.position + Vector2(24, 88) * scale_factor
	subtitle.add_theme_font_override("font", Paper.font())
	subtitle.add_theme_font_size_override("font_size", 20 if not large else 18)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)
	workbench.grab_focus()
	sync()
	await frames(3)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual GPU physical viewport")
	var retained: Array = []
	var node_count := workbench.find_children("*", "", true, false).size()
	for mesh in workbench.find_children("*", "MeshInstance3D", true, false):
		retained.append([mesh.get_instance_id(), mesh.mesh.get_instance_id(), mesh.material_override.get_instance_id()])
	check(subtitle.get_minimum_size().x <= requested.x - 30, "native complete subtitle fits")
	for name in View.COMMANDS:
		var rect := View.button_rect(name)
		check(Rect2(Vector2.ZERO, Vector2(requested)).encloses(Rect2(workbench.get_global_transform_with_canvas() * rect.position, rect.size * scale_factor)), "physical full action bounds " + name)
		for label in [View.BUTTON_ACTIONS[View.COMMANDS.find(name)], View.BUTTON_KEYS[View.COMMANDS.find(name)]]:
			check(Paper.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, workbench.text_size(16)).x <= rect.size.x - 16, "full enlarged button text " + label)
	for row in workbench.text_rows():
		check(Paper.font().get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, workbench.text_size(row[3])).x <= row[2], "full status text " + row[1])
	for route in 3:
		reset_a()
		for name in View.COMMANDS:
			await action(name, route)
		check(driver.snapshot().bed.x == 340 and driver.snapshot().tilt == 21 and driver.snapshot().helper and not driver.snapshot().participated, "all seven real parsed controls route %d" % route)
	reset_a()
	await key(KEY_SPACE)
	advance(0.5)
	await key(KEY_SPACE, true, true)
	await key(KEY_SPACE)
	await pointer(View.button_rect("charge").get_center(), true, 3)
	await pointer(View.button_rect("charge").get_center(), false, 3)
	check(driver.snapshot().charging and driver.snapshot().fruit.ready, "echo repeat competing touch cannot launch")
	workbench.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await key(KEY_SPACE, false)
	check(not driver.snapshot().charging and not driver.snapshot().participated, "focus cancel no late keyboard launch")
	await pointer(View.button_rect("charge").get_center(), true, 3)
	advance(0.5)
	await pointer(View.button_rect("charge").get_center(), true, 8)
	await pointer(View.button_rect("charge").get_center(), false, 8)
	check(driver.snapshot().charging, "real second touch release cannot steal held charge")
	await pointer(Vector2(4, 4), false, 3, true)
	check(not driver.snapshot().charging and not driver.snapshot().participated, "real canceled touch clears charge")
	await pointer(View.button_rect("charge").get_center(), true, -1, false, true)
	check(not driver.snapshot().charging, "real emulated mouse excluded")
	await pointer(View.button_rect("charge").get_center(), false, -1, false, true)
	await pointer(View.button_rect("charge").get_center(), true)
	advance(0.5)
	await pointer(Vector2(4, 4), false)
	check(not driver.snapshot().charging and not driver.snapshot().participated, "real outside mouse up cancels")
	reset_a()
	await configure(380, 21)
	await command("charge", true)
	advance(1.28)
	check(driver.snapshot().fruit.ready and driver.snapshot().depth > 0.9 and not driver.snapshot().participated, "real depressed charged support with predicted release arc")
	await capture("01-charge-slant")
	await command("charge", false)
	advance(0.65)
	check(not driver.snapshot().fruit.ready, "real gravity flight")
	await capture("05-flight")
	wait_ready()
	check(driver.snapshot().delivered == 1 and driver.snapshot().bell_deliveries == 0, "real high platform descending delivery")
	await capture("02-real-platform-delivery")
	await shot()
	check(driver.snapshot().delivered == 2, "second real delivery before same-fruit challenge")
	await configure(500, 35)
	await action("helper")
	await launch(1.34)
	for i in 3:
		await action("bed_right")
	var bell_seen := false
	var wall_seen := false
	for i in 600:
		var state: Dictionary = driver.snapshot()
		if state.fruit.bell_touched and not bell_seen:
			bell_seen = true
			await capture("06-real-bell-contact")
		if state.fruit.vx < 0 and not wall_seen:
			wall_seen = true
			await capture("07-real-wall-reflection")
		if state.fruit.ready:
			break
		driver.step(1.0 / 120.0)
	sync()
	check(bell_seen and wall_seen and driver.snapshot().fruit.ready and driver.snapshot().fruit.bell_touched and driver.snapshot().delivered == 2 and driver.snapshot().bell_deliveries == 0 and driver.snapshot().mistakes == 0, "genuine same-fruit bell wall bed620 catch without delivery or auto launch")
	advance(0.25)
	check(driver.snapshot().fruit.ready and not driver.snapshot().charging, "AI catches and waits for manual input")
	await configure(340, 21, 2)
	await command("charge", true, 2)
	advance(1.26)
	check(driver.snapshot().fruit.bell_touched and driver.snapshot().charging, "manual recharge retains same-fruit bell")
	await capture("03-bell-recatch-manual-release")
	await command("charge", false, 2)
	wait_ready()
	check(driver.snapshot().success and driver.snapshot().devil and driver.snapshot().score == 500 and driver.snapshot().bell_deliveries == 1, "same real fruit reaches final high platform")
	await capture("04-three-real-deliveries")
	for route in 3:
		for assisted in [false, true]:
			for bell in [false, true]:
				for variant in 2:
					driver.reset(assisted, "noon")
					workbench.grab_focus()
					sync()
					if assisted:
						await configure(340, 0, route)
						await action("helper", route)
						await launch(0.8, route)
						wait_ready()
						check(driver.snapshot().fruit.ready and driver.snapshot().delivered == 0 and driver.snapshot().mistakes == 0, "assisted route real helper catch")
						await action("helper", route)
					for shot_index in 3:
						var mass := float(driver.snapshot().fruit.mass)
						var x := 380.0 if is_equal_approx(mass, 1.0) else (420.0 if mass > 1.0 else 340.0)
						await configure(x + (80 if bell and shot_index == 0 else 0), 28 if mass > 1.0 else 21, route)
						await launch(1.28 if mass >= 1.0 else 1.26, route)
						wait_ready()
					var result: Dictionary = driver.snapshot()
					check(result.success and result.delivered == 3 and result.devil == bell and result.ordinary_eligible and result.score == (500 if bell else 400), "real parsed three-modality A/B normal/assist ordinary/bell route")
					print("JELLY_NATIVE_ROUTE route=%d variant=%d assisted=%s bell=%s score=%d elapsed=%.9f" % [route, result.variant, assisted, bell, result.score, result.elapsed])
	reset_a()
	await configure(180, -35, 1)
	await launch(0.4, 1)
	wait_ready()
	check(driver.snapshot().mistakes > 0 and driver.snapshot().fruit.ready and driver.snapshot().score == 0, "real loss recovers without negative score")
	await capture("08-miss-recovery")
	var material_pool := {}
	var mesh_pool := {}
	var index := 0
	for mesh in workbench.find_children("*", "MeshInstance3D", true, false):
		check(retained[index] == [mesh.get_instance_id(), mesh.mesh.get_instance_id(), mesh.material_override.get_instance_id()], "native repeated presentations retain node mesh material identity")
		material_pool[mesh.material_override.get_instance_id()] = true
		mesh_pool[mesh.mesh.get_instance_id()] = true
		index += 1
	check(workbench.find_children("*", "", true, false).size() == node_count, "native all routes/retries bounded node count")
	print("JELLY_NATIVE_RETAINED nodes=%d mesh_instances=%d unique_meshes=%d materials=%d" % [node_count, retained.size(), mesh_pool.size(), material_pool.size()])
	await command("charge", true)
	advance(0.5)
	workbench.queue_free()
	await frames(2)
	check(not driver.snapshot().charging and driver.snapshot().fruit.ready, "real tree exit cancels held charge")
	workbench = driver.create_view()
	add_child(workbench)
	workbench.scale = Vector2.ONE * scale_factor
	workbench.position = (Vector2(requested) - View.DESIGN_SIZE * scale_factor) * 0.5
	workbench.grab_focus()
	sync()
	await command("charge", true)
	advance(0.5)
	driver.reset(false, "noon")
	await command("charge", false)
	check(not driver.snapshot().participated and not driver.snapshot().charging, "retry cancels late held release in new view")
	print("Jelly native workbench: %d checks, %d failures size=%s" % [checks, failures, requested])
	get_tree().quit(1 if failures else 0)
