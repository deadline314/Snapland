extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var path := "res://game/minigames/syrup_flood_view.gd"
	expect(ResourceLoader.exists(path), "syrup view resource exists")
	if not ResourceLoader.exists(path):
		finish()
		return
	var View = load(path)
	expect(View != null and View.can_instantiate(), "view script compiles")
	if View == null or not View.can_instantiate():
		finish()
		return
	var Model = load("res://game/minigames/syrup_flood_model.gd")
	var Paper = load("res://game/ui/paper_ui.gd")
	var model = Model.new()
	var view = View.new()
	root.add_child(view)
	var state: Dictionary = model.snapshot()
	var before := state.duplicate(true)
	view.present(state, "noon", false)
	await process_frame
	expect(state == before, "view does not mutate snapshot")
	expect(view.feedback_text() == state.feedback, "reset footer consumes actual model feedback")
	expect(view.find_child("SyrupWorkbench", true, false) is Node3D and view.find_child("SyrupCamera", true, false) is Camera3D, "real isolated retained stage and camera")
	var camera: Camera3D = view.find_child("SyrupCamera", true, false)
	for i in 3:
		var valve: MeshInstance3D = view.find_child("Valve%d" % i, true, false)
		expect(valve != null and view.find_child("TankLevel%d" % i, true, false) is MeshInstance3D and view.find_child("TargetBand%d" % i, true, false) is MeshInstance3D, "retained valve liquid and target band")
		expect((camera.unproject_position(valve.global_position) + View.STAGE.position).distance_to(View.valve_point(i)) < 0.01 and View.valve_at(View.valve_point(i)) == i, "hit helper matches actual spatial valve")
	var nodes: int = view.find_children("*", "", true, false).size()
	var meshes: Array = []
	var materials: Array = []
	for node in view.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node.mesh)
		materials.append(node.material_override)
	model.toggle_valve()
	model.toggle_heater()
	for frame in 120:
		model.step(1.0 / 60.0)
		view.present(model.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == nodes, "present has constant bounded node count")
	var index := 0
	for node in view.find_children("*", "MeshInstance3D", true, false):
		expect(node.mesh == meshes[index] and node.material_override == materials[index], "present retains meshes and materials")
		index += 1
	var level: MeshInstance3D = view.find_child("TankLevel0", true, false)
	expect(level.visible and level.scale.y > 0 and view.find_child("Heater", true, false).visible, "actual hot fill updates geometry")
	expect(is_equal_approx(level.scale.y, model.snapshot().branches[0].fill / model.snapshot().branches[0].capacity), "retained level is exact model fill ratio")
	var hot: StandardMaterial3D = level.material_override
	var cold: MeshInstance3D = view.find_child("TankLevel1", true, false)
	expect(hot.albedo_color != cold.material_override.albedo_color, "temperature changes live StandardMaterial3D color")
	model.toggle_configuration()
	view.present(model.snapshot(), "noon", false)
	expect(view.status_text().contains("配置") and not view.find_child("Flow0", true, false).visible, "configuration clearly visible and no false flow")
	for variant in 2:
		model.reset(false, variant)
		view.present(model.snapshot(), "noon", false)
		for i in 3:
			var pipe: MeshInstance3D = view.find_child("PipeFloor%d" % i, true, false)
			expect(is_equal_approx(pipe.scale.x, model.snapshot().branches[i].length), "configuration changes actual pipe length")
			expect(is_equal_approx(pipe.position.x + 1.05 * pipe.scale.x, (i - 1) * 6.3 + 0.45), "both configuration pipe ends remain connected to outlet")
			var band: MeshInstance3D = view.find_child("TargetBand%d" % i, true, false)
			expect(is_equal_approx(band.position.y - 0.075 * band.scale.y, 1.5 * model.snapshot().branches[i].target / model.snapshot().branches[i].capacity), "target band starts exactly at model target")
	model.reset()
	model.toggle_valve()
	model.toggle_heater()
	for i in 300:
		if model.snapshot().branches[0].spoiled:
			break
		model.step(0.25)
	view.present(model.snapshot(), "noon", false)
	expect(view.feedback_text() == model.snapshot().feedback and view.feedback_text().contains("溢出"), "actual overflow reason reaches footer")
	model.drain_selected()
	view.present(model.snapshot(), "noon", false)
	expect(view.feedback_text() == model.snapshot().feedback and view.feedback_text().contains("免費排空"), "actual drain consequence reaches footer")
	model.reset()
	view.present(model.snapshot(), "noon", false)
	expect(view.feedback_text() == state.feedback, "retry restores model instruction without stale overflow feedback")
	Paper.set_text_scale(1.25)
	view.scale = Vector2.ONE * 0.625
	expect(view.text_size(16) * 0.625 >= 17.5, "small viewport enlarged text physical size")
	for command in View.COMMANDS:
		var rect: Rect2 = View.button_rect(command)
		expect(Rect2(Vector2.ZERO, View.DESIGN_SIZE).encloses(rect) and View.command_at(rect.get_center()) == command, "all visible actions fit and hit")
		var label: String = View.BUTTON_ACTIONS[View.COMMANDS.find(command)]
		expect(Paper.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(16)).x <= rect.size.x - 16, "enlarged action text fits " + label)
	Paper.set_text_scale(1.0)
	view.scale = Vector2.ONE
	var driver = load("res://game/minigames/syrup_flood_driver.gd").new()
	driver.reset(false, "noon")
	view.command_requested.connect(driver._command)
	view.pointer_requested.connect(driver._pointer)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 3
	expect(view.handle_pointer(touch, View.valve_point(0)), "view owns first touch")
	touch.index = 8
	expect(not view.handle_pointer(touch, View.valve_point(1)), "view rejects second touch")
	view.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	touch.index = 3
	touch.pressed = false
	expect(not view.handle_pointer(touch, Vector2.ZERO) and driver.snapshot().branches[0].valve, "focus clear discards late release without changing latched valve")
	view.queue_free()
	await process_frame
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 3:
		var repeated = View.new()
		root.add_child(repeated)
		repeated.present(model.snapshot(), "noon", true)
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "teardown leaks no stage nodes")
	finish()
func finish() -> void:
	print("Syrup flood view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
