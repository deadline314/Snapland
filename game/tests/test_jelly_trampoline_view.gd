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
	var View = load("res://game/minigames/jelly_trampoline_view.gd")
	var Model = load("res://game/minigames/jelly_trampoline_model.gd")
	var Paper = load("res://game/ui/paper_ui.gd")
	expect(View != null and View.can_instantiate(), "view compiles")
	if View == null or not View.can_instantiate():
		finish()
		return
	var model = Model.new()
	var view = View.new()
	root.add_child(view)
	view.present(model.snapshot(), "noon", false)
	await process_frame
	expect(view.find_child("SpatialStage", true, false) is SubViewportContainer and view.find_child("JellyCamera", true, false) is Camera3D, "true retained viewport and camera")
	var bed: MeshInstance3D = view.find_child("ElasticBed", true, false)
	var fruit: MeshInstance3D = view.find_child("Fruit", true, false)
	var left: MeshInstance3D = view.find_child("CompressionLeft", true, false)
	var right: MeshInstance3D = view.find_child("CompressionRight", true, false)
	expect(bed.mesh is BoxMesh and fruit.mesh is SphereMesh and view.find_child("SideBell", true, false).mesh is SphereMesh, "thick elastic geometry and spherical fruit and bell")
	var initial_bed := bed.position
	model.begin_charge()
	model.step(0.25)
	var state: Dictionary = model.snapshot()
	var before := state.duplicate(true)
	view.present(state, "night", true)
	expect(state == before and view.feedback_text() == state.feedback, "same immutable model snapshot owns footer")
	expect(bed.position.y < initial_bed.y and left.scale.y != right.scale.y, "reduced motion retains actual compression and slant")
	expect(fruit.position.is_equal_approx(View.world_point(state.fruit.x, state.fruit.y, 0.24)), "fruit follows exact depressed model origin")
	var safe: MeshInstance3D = view.find_child("SafeLandingCenters", true, false)
	expect(is_equal_approx(safe.scale.x, (state.target.half_width - state.fruit.radius) * 0.04), "safe landing stripe excludes fruit radius")
	var support: MeshInstance3D = view.find_child("BedSupport", true, false)
	expect(is_equal_approx(support.scale.x, (state.bed.half_width - state.fruit.radius) * 0.04), "actual safe bed contact support excludes radius")
	var nodes: int = view.find_children("*", "", true, false).size()
	var ids: Array = []
	var meshes: Array = []
	var materials: Array = []
	for node in view.find_children("*", "MeshInstance3D", true, false):
		ids.append(node.get_instance_id())
		meshes.append(node.mesh)
		materials.append(node.material_override)
	model.release_charge()
	for i in 120:
		model.step(1.0 / 120.0)
		view.present(model.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == nodes, "120 presentations bounded node count")
	var index := 0
	var pool := {}
	for node in view.find_children("*", "MeshInstance3D", true, false):
		expect(node.get_instance_id() == ids[index] and node.mesh == meshes[index] and node.material_override == materials[index], "120 presentations retain node mesh and material identity")
		pool[node.material_override.get_instance_id()] = true
		index += 1
	print("JELLY_RETAINED nodes=%d meshes=%d materials=%d" % [nodes, meshes.size(), pool.size()])
	var driver = load("res://game/minigames/jelly_trampoline_driver.gd").new()
	driver.reset(false, "noon")
	view.command_requested.connect(driver._command)
	view.pointer_requested.connect(driver._pointer)
	view.tree_exiting.connect(driver.clear_input)
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	expect(view.handle_pointer(touch, View.button_rect("charge").get_center()), "view owns first touch")
	driver.step(0.25)
	touch.index = 8
	expect(not view.handle_pointer(touch, View.button_rect("charge").get_center()), "view rejects second touch")
	view.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	touch.index = 3
	touch.pressed = false
	expect(not view.handle_pointer(touch, Vector2.ZERO) and not driver.snapshot().charging and not driver.snapshot().participated, "focus cancel prevents ghost launch")
	Paper.set_text_scale(1.25)
	view.scale = Vector2.ONE * 0.625
	expect(view.text_size(16) * 0.625 >= 17.5, "small enlarged physical text")
	for command in View.COMMANDS:
		var rect: Rect2 = View.button_rect(command)
		expect(Rect2(Vector2.ZERO, View.DESIGN_SIZE).encloses(rect) and View.command_at(rect.get_center()) == command, "every button inside design and hittable")
		for label in [View.BUTTON_ACTIONS[View.COMMANDS.find(command)], View.BUTTON_KEYS[View.COMMANDS.find(command)]]:
			expect(Paper.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(16)).x <= rect.size.x - 16, "enlarged button text fits " + label)
	for row in view.text_rows():
		expect(Paper.font().get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(row[3])).x <= row[2], "full enlarged status/footer text fits " + row[1])
	Paper.set_text_scale(1)
	touch.pressed = true
	view.handle_pointer(touch, View.button_rect("charge").get_center())
	driver.step(0.25)
	view.queue_free()
	await process_frame
	expect(not driver.snapshot().charging and not driver.snapshot().participated, "actual tree exit cancels held charge")
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 3:
		var repeated = View.new()
		root.add_child(repeated)
		repeated.present(model.snapshot(), "noon", true)
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "teardown frees all stage nodes")
	finish()
func finish() -> void:
	print("Jelly trampoline view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
