extends SceneTree
const View = preload("res://game/minigames/rowing_cargo_view.gd")
const Model = preload("res://game/minigames/rowing_cargo_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var model = Model.new()
	var view = View.new()
	view.present(model.snapshot(), "noon", false)
	get_root().add_child(view)
	await process_frame
	expect(view.find_child("RowingViewport", true, false) is SubViewport, "one native viewport")
	expect(view.find_child("Boat", true, false) is Node3D, "boat geometry exists")
	for part in ["OarLeft", "OarRight", "Crew", "Dock1", "Dock2", "crate-1", "crate-2", "crate-3", "WaveForce", "Breakwater0", "Breakwater1"]:
		expect(view.find_child(part, true, false) != null, "complete prop: " + part)
	var boat: Node3D = view.find_child("Boat", true, false)
	var state: Dictionary = model.snapshot()
	state.position = Vector2(4, 2)
	state.heading = 0.7
	view.present(state, "dusk", true)
	expect(boat.position.x == 4 and boat.position.z == 2 and is_equal_approx(boat.rotation.y, -0.7), "X/Z and yaw match model")
	var sun: DirectionalLight3D = view.find_child("RowingSun", true, false)
	var dusk := sun.light_color
	view.present(state, "night", true)
	expect(sun.light_color != dusk, "phase refresh changes real lighting")
	var count := view.find_children("*", "", true, false).size()
	var mesh: MeshInstance3D = view.find_child("Hull", true, false)
	var mesh_id := mesh.mesh.get_instance_id()
	for i in 30:
		view.present(state, "night", true)
	expect(view.find_children("*", "", true, false).size() == count and mesh.mesh.get_instance_id() == mesh_id, "present reuses nodes and mesh")
	expect(view.status_text().contains("浪峰") and view.status_text().contains("缺口") and view.status_text().contains("航向"), "essential cues survive reduced motion")
	var commands: Array = []
	view.command_requested.connect(func(command, pressed, source): commands.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("left").get_center())
	view.handle_pointer(event, View.button_rect("left").get_center())
	expect(commands.size() == 1, "duplicate pointer event not applied twice")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(commands.size() == 2 and not commands[1][1], "release outside button clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(commands.size() == 2, "nonfinite pointer rejected")
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	view.handle_pointer(touch, View.button_rect("left").get_center())
	touch.index = 7
	view.handle_pointer(touch, View.button_rect("right").get_center())
	expect(commands[-1][2] != commands[-2][2], "touch owners are independent")
	view.clear_pointer_input()
	expect(not commands[-1][1] and not commands[-2][1], "clear releases all touch owners")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("stroke").get_center()), "touch-emulated mouse cannot double apply")
	model.paddle()
	model.step(0.15)
	view.present(model.snapshot(), "noon", true)
	var oar: Node3D = view.find_child("OarLeft", true, false)
	expect(absf(oar.rotation.y) > 0.2, "essential player stroke cue survives reduced motion")
	model.step(0.25)
	view.present(model.snapshot(), "noon", true)
	expect(absf(oar.rotation.y) < 0.001, "crew does not paddle while player is idle")
	for i in 4:
		model.step(0.25)
	state = model.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "noon", true)
	var wall: Node3D = view.find_child("Breakwater0", true, false)
	var wave: Node3D = view.find_child("Wave0", true, false)
	var force: Node3D = view.find_child("WaveForce", true, false)
	expect(state == unchanged, "view treats snapshot as read-only")
	expect(is_equal_approx(wall.scale.z, state.breakwaters[0].size.y), "actual tide changes visible collision gap")
	expect(state.crest and wave.scale.z > 1, "crest wave geometry remains explicit with reduced motion")
	expect(is_equal_approx(force.rotation.y, -state.water.force.angle()), "physical force arrow follows actual signed force")
	model.reset()
	model.interact()
	view.present(model.snapshot(), "noon", false)
	expect(view._carrying_text() == "第1箱 → 碼頭1" and not "crate-" in View.feedback_text(model.snapshot()), "player cargo and pickup feedback show Chinese number and destination")
	if DisplayServer.get_name() != "headless":
		get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_root().content_scale_size = Vector2i.ZERO
		var window_size := Vector2(get_root().size)
		var factor := minf(window_size.x / 1280, window_size.y / 720)
		view.scale = Vector2.ONE * factor
		view.position = (window_size - View.DESIGN_SIZE * factor) * 0.5
		Paper.set_text_scale(1.25 if OS.get_environment("ROWING_LARGE_TEXT") == "1" else 1.0)
		model.reset()
		view.present(model.snapshot(), "noon", false)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := OS.get_environment("ROWING_VIEW_CAPTURE")
		if not capture.is_empty():
			expect(get_root().get_texture().get_image().save_png(capture) == OK, "native image written")
			model.interact()
			for i in 4:
				model.step(0.25)
			model.paddle()
			model.step(0.1)
			view.present(model.snapshot(), "dusk", true)
			await process_frame
			await RenderingServer.frame_post_draw
			expect(get_root().get_texture().get_image().save_png(capture.trim_suffix(".png") + "-reduced.png") == OK, "reduced motion crest image written")
	view.queue_free()
	await process_frame
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for i in 8:
		var repeated = View.new()
		get_root().add_child(repeated)
		repeated.present(model.snapshot(), "dawn", true)
		await process_frame
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "repeated create/free leaves bounded nodes")
	expect(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 2, "repeated create/free leaves bounded resources")
	print("Lifecycle8: nodes %d -> %d; resources %d -> %d" % [baseline, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	print("Rowing view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
