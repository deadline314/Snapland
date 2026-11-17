extends Node
## Standalone scripted GPU/input evidence; no Main, player save or card award.
const Driver = preload("res://game/minigames/syrup_flood_driver.gd")
const View = preload("res://game/minigames/syrup_flood_view.gd")
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
	while left > 0.000001:
		var dt := minf(left, 1.0 / 60.0)
		driver.step(dt)
		left -= dt
	sync()
func key(code: Key, pressed := true, shift := false, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
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
func action(command: String, route := 0) -> void:
	if route == 0:
		var index := View.COMMANDS.find(command)
		var codes := [KEY_TAB, KEY_TAB, KEY_SPACE, KEY_H, KEY_F, KEY_R, KEY_X, KEY_C]
		await key(codes[index], true, index == 0)
		await key(codes[index], false, index == 0)
	else:
		var point := View.button_rect(command).get_center()
		await pointer(point, true, 4 if route == 2 else -1)
		await pointer(Vector2(4, 4), false, 4 if route == 2 else -1)
func select(index: int, route := 0) -> void:
	for i in 3:
		if driver.snapshot().selected == index:
			return
		await action("next", route)
func capture(label: String) -> void:
	sync()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and image.get_size() == requested and image.save_png(output.path_join(label + ".png")) == OK, "physical raw capture " + label)
	print("SYRUP_CAPTURE %s state=%s" % [label, JSON.stringify(driver.snapshot())])
func solve(route: int, pause_final := false) -> void:
	for i in 3:
		await select(i, route)
		await action("valve", route)
	await select(1, route)
	await action("diversion", route)
	for frame in 4501:
		var state: Dictionary = driver.snapshot()
		if state.ended:
			break
		for i in 3:
			var branch: Dictionary = state.branches[i]
			if branch.valve and branch.fill >= branch.capacity * 0.92:
				var final_close: bool = state.filled_tanks == 3
				if pause_final and final_close and not driver.snapshot().configuration_paused:
					await action("configuration", route)
				await select(i, route)
				await action("valve", route)
		state = driver.snapshot()
		if state.configuration_paused:
			check(not state.ended and not state.success and not state.ordinary_eligible, "all closed in configuration does not award")
			var frozen := state.duplicate(true)
			advance(0.25)
			check(driver.snapshot() == frozen, "all-closed paused heat flow time remain frozen")
			await capture("04-configuration-paused")
			await action("configuration", route)
			check(not driver.snapshot().ended, "resume waits for real simulation step")
			driver.step(1.0 / 60.0)
			break
		for i in 3:
			if state.branches[i].fill < state.branches[i].capacity * 0.92 and not (i == 1 and state.diversion):
				if state.heater != i:
					await select(i, route)
					await action("heater", route)
				break
		driver.step(1.0 / 60.0)
	sync()
	var result: Dictionary = driver.snapshot()
	check(result.success and result.devil and result.ordinary_eligible and result.score == 500, "real parsed-input route reaches cold-plug success")
	print("SYRUP_NATIVE_ROUTE route=%d variant=%d success=%s devil=%s elapsed=%.5f score=%d" % [route, result.variant, result.success, result.devil, result.elapsed, result.score])
func _run() -> void:
	output = OS.get_environment("SNAPLAND_SYRUP_WORKBENCH_OUTPUT")
	var dimensions := OS.get_environment("SNAPLAND_SYRUP_WORKBENCH_SIZE").split("x")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or dimensions.size() != 2:
		push_error("Syrup workbench requires GPU, isolated absolute save/output and WIDTHxHEIGHT")
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
	var scale_factor := minf(float(requested.x) / 1280.0, float(requested.y) / 720.0)
	workbench.scale = Vector2.ONE * scale_factor
	workbench.position = (Vector2(requested) - View.DESIGN_SIZE * scale_factor) * 0.5
	var title := Label.new()
	title.text = "糖漿分洪｜冷糖與熱源"
	title.position = workbench.position + Vector2(24, 30) * scale_factor
	title.add_theme_font_override("font", Paper.font())
	title.add_theme_font_size_override("font_size", 28 if not large else 23)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "共享熱源輪轉三管 · 留冷糖成塞 · 到綠帶關閥"
	subtitle.position = workbench.position + Vector2(24, 88) * scale_factor
	subtitle.add_theme_font_override("font", Paper.font())
	subtitle.add_theme_font_size_override("font_size", 20 if not large else 18)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)
	workbench.grab_focus()
	sync()
	await frames(3)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual GPU viewport size")
	check(workbench.text_size(16) * scale_factor >= (17.5 if large else 14.0), "essential text physical minimum including large-text profile")
	for i in 3:
		var label := "%d缸 %d–100%%" % [i + 1, roundi(100.0 * driver.snapshot().branches[i].target / driver.snapshot().branches[i].capacity)]
		check(Paper.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, workbench.text_size(16)).x <= 230, "compact tank target caption fully fits")
	for command in View.COMMANDS:
		var rect := View.button_rect(command)
		check(Rect2(Vector2.ZERO, Vector2(requested)).encloses(Rect2(workbench.get_global_transform_with_canvas() * rect.position, rect.size * scale_factor)), "physical action bounds " + command)
		check(Paper.font().get_string_size(View.BUTTON_ACTIONS[View.COMMANDS.find(command)], HORIZONTAL_ALIGNMENT_LEFT, -1, workbench.text_size(16)).x <= rect.size.x - 16, "physical enlarged button text fits " + command)
	for route in 3:
		if route > 0:
			driver.reset(false, "noon")
			sync()
		for command in View.COMMANDS:
			await action(command, route)
		var state: Dictionary = driver.snapshot()
		check(state.selected == 0 and state.configuration_paused and not state.diversion and state.heater == 0 and state.helper == 0 and state.branches[0].valve, "all eight parsed keyboard/mouse/touch controls have the same outcome")
	driver.reset(false, "noon")
	sync()
	await key(KEY_SPACE)
	await key(KEY_SPACE, true, false, true)
	await key(KEY_SPACE)
	await pointer(View.valve_point(1), true, 3)
	check(driver.snapshot().branches[0].valve and not driver.snapshot().branches[1].valve, "echo repeat and second source cannot double-toggle")
	await pointer(Vector2(4, 4), false, 3, true)
	await key(KEY_SPACE, false)
	await key(KEY_TAB, true, true)
	await key(KEY_TAB, false, false)
	await action("next")
	check(driver.snapshot().selected == 0, "actual Shift Tab release after Shift changed clears original command")
	await key(KEY_TAB)
	await key(KEY_TAB, true, true)
	await key(KEY_TAB, false, true)
	check(driver.snapshot().selected == 1, "physical held Tab cannot repeat when Shift changes")
	await action("previous")
	await pointer(View.valve_point(1), true, 3)
	await pointer(View.valve_point(2), true, 8)
	check(driver.snapshot().selected == 1 and driver.snapshot().branches[1].valve and not driver.snapshot().branches[2].valve, "first real touch owns spatial valve")
	await pointer(Vector2(4, 4), false, 3, true)
	await pointer(Vector2(4, 4), false, 8, true)
	await pointer(View.button_rect("heater").get_center(), true, -1, false, true)
	await pointer(Vector2(4, 4), false, -1, false, true)
	check(driver.snapshot().heater == -1, "actual emulated mouse excluded")
	await action("heater", 1)
	check(driver.snapshot().heater == 1, "cancel outside then mouse remains usable")
	await key(KEY_H)
	workbench.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await key(KEY_H, false)
	check(driver.snapshot().heater == -1, "focus clear adds no release action")
	await action("heater")
	check(driver.snapshot().heater == 1, "focus clear releases command ownership")
	driver.reset(false, "noon")
	sync()
	for i in 3:
		await pointer(View.valve_point(i), true)
		await pointer(Vector2(4, 4), false)
	await select(1)
	await action("diversion")
	await select(0)
	await action("heater")
	advance(5.0)
	check(driver.snapshot().plug_amount > 0 and not driver.snapshot().cold_plugged and driver.snapshot().branches[0].temperature > driver.snapshot().branches[1].temperature, "real hot outer and reserved cold middle")
	await capture("01-cold-reserve-hot-flow")
	advance(6.0)
	check(driver.snapshot().cold_plugged and not driver.snapshot().diversion and workbench.find_child("ColdPlug", true, false).visible, "real material forms visible permanent cold plug")
	await capture("02-real-cold-plug")
	await action("configuration", 2)
	var paused: Dictionary = driver.snapshot()
	advance(0.25)
	check(driver.snapshot() == paused and not workbench.find_child("Flow0", true, false).visible and not workbench.find_child("SideLeak", true, false).visible, "configuration freezes simulation and all flow graphics")
	await capture("03-configuration-hot-paused")
	await action("configuration", 2)
	for i in 300:
		if driver.snapshot().branches[0].spoiled:
			break
		advance(0.25)
	check(driver.snapshot().branches[0].spoiled and driver.snapshot().mistakes == 1, "real hot flow overflows and closes valve")
	check(workbench.feedback_text() == driver.snapshot().feedback and workbench.feedback_text().contains("溢出"), "actual model overflow consequence visibly reaches footer")
	await capture("06-overflow-cold-plug")
	await select(0, 2)
	var elapsed: float = driver.snapshot().elapsed
	await action("drain", 2)
	check(driver.snapshot().branches[0].fill == 0 and not driver.snapshot().branches[0].spoiled and driver.snapshot().elapsed == elapsed and driver.snapshot().mistakes == 1, "actual touch free drain preserves time and mistakes")
	check(workbench.feedback_text() == driver.snapshot().feedback and workbench.feedback_text().contains("免費排空"), "actual model drain consequence visibly reaches footer")
	await capture("07-overflow-recovery")
	var nodes := workbench.find_children("*", "", true, false).size()
	var material_ids: Array = []
	for mesh in workbench.find_children("*", "MeshInstance3D", true, false):
		material_ids.append(mesh.material_override.get_instance_id())
	for route in 3:
		driver.reset(false, "noon")
		workbench.grab_focus()
		sync()
		await solve(route, route == 0)
		check(workbench.find_children("*", "", true, false).size() == nodes, "repeated present and retry keep node count constant")
		if route == 0:
			await capture("05-filled-closed")
	var materials: Dictionary = {}
	for mesh in workbench.find_children("*", "MeshInstance3D", true, false):
		materials[mesh.material_override.get_instance_id()] = true
	check(materials.size() <= 12, "bounded real material pool")
	print("SYRUP_RETAINED nodes=%d meshes=%d material_pool=%d" % [nodes, material_ids.size(), materials.size()])
	driver.reset(false, "noon")
	workbench.grab_focus()
	sync()
	await key(KEY_H)
	check(driver.snapshot().heater == 0, "real held input before tree exit")
	workbench.queue_free()
	await frames(2)
	check(driver.snapshot().heater == 0 and not driver.snapshot().branches[0].valve, "tree exit clears ownership without changing latched controls")
	workbench = driver.create_view()
	add_child(workbench)
	workbench.size = View.DESIGN_SIZE
	workbench.scale = Vector2.ONE * scale_factor
	workbench.position = (Vector2(requested) - View.DESIGN_SIZE * scale_factor) * 0.5
	workbench.grab_focus()
	sync()
	await key(KEY_H)
	await key(KEY_H, false)
	check(driver.snapshot().heater == -1, "new view accepts same command after actual tree exit")
	await key(KEY_SPACE)
	driver.reset(false, "noon")
	await key(KEY_SPACE, false)
	check(not driver.snapshot().branches[0].valve, "reset while held adds no late-release action")
	print("Syrup native workbench: %d checks, %d failures size=%s" % [checks, failures, requested])
	get_tree().quit(1 if failures else 0)
