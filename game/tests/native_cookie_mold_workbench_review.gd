extends Node
## Standalone scripted GPU/control evidence; this does not launch Main or award cards.
const Driver = preload("res://game/minigames/cookie_mold_driver.gd")
const View = preload("res://game/minigames/cookie_mold_view.gd")
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
		var dt := minf(left, 1.0 / 120.0)
		driver.step(dt)
		left -= dt
	sync()
func pointer(point: Vector2, action: String) -> void:
	var screen := workbench.get_global_transform_with_canvas() * point
	if action == "move":
		var event := InputEventMouseMotion.new()
		event.position = screen
		event.global_position = screen
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.global_position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = action == "press"
		Input.parse_input_event(event)
	await frames(1)
	sync()
func capture(label: String) -> void:
	sync()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and image.get_size() == requested and image.save_png(output.path_join(label + ".png")) == OK, "physical capture " + label)
func hand_inside_stage(node_name: String) -> bool:
	var camera: Camera3D = workbench.find_child("CookieCamera", true, false)
	var hand: Node3D = workbench.find_child(node_name, true, false)
	for mesh: MeshInstance3D in hand.find_children("*", "MeshInstance3D", true, false):
		var bounds := mesh.mesh.get_aabb()
		for corner in 8:
			var projected := camera.unproject_position(mesh.global_transform * bounds.get_endpoint(corner)) + View.STAGE.position
			if not View.STAGE.has_point(projected):
				print("HAND_CLIP %s/%s point=%s angle=%.3f" % [node_name, mesh.name, projected, driver.snapshot().mold_angle])
				return false
	return true
func _run() -> void:
	output = OS.get_environment("SNAPLAND_COOKIE_WORKBENCH_OUTPUT")
	var dimensions := OS.get_environment("SNAPLAND_COOKIE_WORKBENCH_SIZE").split("x")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or dimensions.size() != 2:
		push_error("Cookie workbench requires GPU, absolute isolated save/output and WIDTHxHEIGHT")
		get_tree().quit(1)
		return
	requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if requested not in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)] or DirAccess.make_dir_recursive_absolute(output) != OK:
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
	workbench.grab_focus()
	sync()
	await frames(3)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual viewport dimensions")
	for command in View.COMMANDS:
		var rect := View.button_rect(command)
		check(Rect2(Vector2.ZERO, Vector2(requested)).encloses(Rect2(workbench.get_global_transform_with_canvas() * rect.position, rect.size * scale_factor)), "physical action bounds " + command)
		await pointer(rect.get_center(), "press")
		advance(0.03)
		await pointer(rect.get_center(), "release")
	check(not driver.snapshot().charging and not driver.snapshot().mold_held, "nine actual onscreen actions release cleanly")
	driver.reset(false, "noon")
	sync()
	await capture("01-initial")
	for knock in 2:
		await pointer(View.edge_point(driver.snapshot(), 0), "press")
		check(driver.snapshot().charging, "actual physical corner charges")
		advance(0.65)
		await pointer(View.edge_point(driver.snapshot(), 0), "release")
	check(driver.snapshot().edges[0].adhesion < 0.7 and driver.snapshot().edges[0].stress > 0.65, "actual knocks show adhesion gap and crack warning")
	await capture("02-gap-crack")
	driver.reset(false, "noon")
	sync()
	await pointer(View.mold_handle_point(driver.snapshot()), "press")
	for i in 40:
		var target := driver.snapshot()
		target.mold_angle = float(i + 1) * PI / 40.0
		var point := View.mold_handle_point(target)
		check(View.STAGE.has_point(point), "handle remains in physical workspace")
		await pointer(point, "move")
		advance(0.03)
		check(hand_inside_stage("LeftGrippingHand") and hand_inside_stage("RightTappingHand"), "both articulated hands fit during actual continuous rotation")
	await pointer(View.mold_handle_point(driver.snapshot()), "release")
	check(absf(driver.snapshot().mold_angle) > 1.0 and not driver.snapshot().mold_held, "actual mold drag rotates and releases")
	await capture("03-rotated")
	print("Cookie native workbench: %d checks, %d failures size=%s" % [checks, failures, requested])
	get_tree().quit(1 if failures else 0)
