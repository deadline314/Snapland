extends SceneTree
const View = preload("res://game/minigames/sugar_bridge_view.gd")
const Model = preload("res://game/minigames/sugar_bridge_model.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
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
	get_root().size = Vector2i(1280, 720)
	var model = Model.new()
	var view = View.new()
	get_root().add_child(view)
	var state: Dictionary = model.snapshot()
	var original: Dictionary = state.duplicate(true)
	view.present(state, "noon", false)
	await process_frame
	expect(state == original, "presentation never mutates model snapshot")
	expect(view.find_child("SugarWorkbench", true, false) is Node3D, "workbench is a real isolated 3D world")
	expect(view.find_children("Support?", "Node3D", true, false).size() == 3, "three physical supports")
	expect(view.find_children("Endpoint?", "MeshInstance3D", true, false).size() == 4, "four retained draggable handles")
	expect(view.find_children("Sugar?Segment*", "MeshInstance3D", true, false).size() == 64, "two finite retained material curves")
	expect(view.find_children("DeliveryBall?", "MeshInstance3D", true, false).size() == 3, "three physical delivery balls")
	expect(view.status_text().contains("端點 1") and view.status_text().contains("自由"), "selected state is named without hover")
	view.scale = Vector2.ONE * 0.625
	Paper.set_text_scale(1.25)
	expect(view.text_size(15) * 0.625 >= 17.5, "small viewport enlarged text retains physical legibility")
	expect(Paper.font().get_string_size(view.status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(17)).x <= 1200, "enlarged status fits small viewport")
	for action in View.BUTTON_ACTIONS:
		expect(Paper.font().get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(15)).x <= 186, "two-line command fits enlarged text: " + action)
	view.present(state, "noon", false)
	var label_camera: Camera3D = view.find_child("SugarCamera", true, false)
	var enlarged_label_sizes: Array[float] = []
	for label: Label3D in view.find_children("*", "Label3D", true, false):
		enlarged_label_sizes.append(label.pixel_size)
		var bottom := label_camera.unproject_position(label.global_position)
		var top := label_camera.unproject_position(label.to_global(Vector3(0, label.font_size * label.pixel_size, 0)))
		var physical_font := bottom.distance_to(top) * 0.625
		expect(physical_font >= 17.49, "world label respects enlarged physical font size: " + label.text)
	Paper.set_text_scale(1.0)
	view.present(state, "noon", false)
	var scaled_correctly := true
	var label_index := 0
	for label: Label3D in view.find_children("*", "Label3D", true, false):
		scaled_correctly = scaled_correctly and is_equal_approx(enlarged_label_sizes[label_index], label.pixel_size * 1.25)
		label_index += 1
	expect(scaled_correctly, "all retained world labels honor 125 percent text scale")
	view.scale = Vector2.ONE
	for endpoint: Dictionary in state.endpoints:
		var point: Vector2 = View.design_point(endpoint.position)
		expect(View.work_point(point).is_equal_approx(endpoint.position) and View.endpoint_at(point, state) == endpoint.id, "pointer projection round trip for endpoint %d" % endpoint.id)
		var camera: Camera3D = view.find_child("SugarCamera", true, false)
		var actual := camera.unproject_position(Vector3(endpoint.position.x, endpoint.position.y, 0.18)) + View.STAGE.position
		expect(actual.distance_to(point) < 0.01, "hit target agrees with actual 3D projection")
	for command in View.COMMANDS:
		expect(View.command_at(View.button_rect(command).get_center()) == command, "visible command " + command)
	var nodes := view.find_children("*", "", true, false).size()
	var mesh: MeshInstance3D = view.find_child("Sugar0Segment0", true, false)
	var retained_mesh := mesh.mesh
	var retained_material := mesh.material_override
	for i in 100:
		model.step(0.016)
		view.present(model.snapshot(), "night" if i % 2 else "dawn", true)
	expect(view.find_children("*", "", true, false).size() == nodes and mesh.mesh == retained_mesh and mesh.material_override == retained_material, "per-frame presentation retains nodes, meshes and materials")
	model.reset(true, 1)
	view.present(model.snapshot(), "dusk", true)
	expect(view.find_children("*", "", true, false).size() == nodes, "retry updates retained layout without additions")
	model.select_next(1)
	model.grab_selected()
	model.move_selected(model.snapshot().anchors[1])
	model.toggle_pin()
	model.select_next(1)
	model.grab_selected()
	model.move_selected(model.snapshot().anchors[1])
	model.toggle_pin()
	view.present(model.snapshot(), "noon", false)
	var handles: Array[Node] = view.find_children("Endpoint?", "MeshInstance3D", true, false)
	var left_number: Label3D = handles[1].get_child(0)
	var right_number: Label3D = handles[2].get_child(0)
	expect(left_number.global_position.distance_to(right_number.global_position) >= 0.64, "coincident pinned endpoint labels remain individually readable")
	expect(View.endpoint_at(View.design_point(model.snapshot().anchors[1]), model.snapshot()) == 2, "shared support hit prefers selected endpoint on nearest-distance tie")
	expect(View.endpoint_at(View.design_point(model.snapshot().endpoints[0].position), model.snapshot()) == 0, "distinct nearest hit retains ordinary pointer selection")
	var nearby: Dictionary = model.snapshot()
	nearby.endpoints[1].position = Vector2.ZERO
	nearby.endpoints[2].position = Vector2(0.35, 0)
	expect(View.endpoint_at(View.design_point(Vector2.ZERO), nearby) == 1, "selected nearby endpoint cannot override a closer hit inside both hit circles")
	var seen: Array = []
	var cancelled: Array = []
	view.pointer_requested.connect(func(action, point, source): seen.append([action, point, source]))
	view.command_requested.connect(func(command, pressed, source): cancelled.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var point := View.design_point(model.snapshot().endpoints[0].position)
	expect(view.handle_pointer(event, point), "handle press accepted")
	expect(not view.handle_pointer(event, point) and seen.size() == 1, "duplicate press rejected")
	expect(view.handle_pointer(InputEventMouseMotion.new(), point + Vector2(30, 0)) and seen[-1][0] == "move", "held pointer movement reaches driver")
	event.pressed = false
	expect(view.handle_pointer(event, Vector2(-500, -500)) and seen[-1][0] == "release", "release outside is owned")
	event.pressed = true
	expect(not view.handle_pointer(event, Vector2(NAN, INF)), "nonfinite press rejected")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	view.handle_pointer(touch, point)
	var move := InputEventScreenDrag.new()
	move.index = 3
	expect(view.handle_pointer(move, point + Vector2(0, 20)) and seen[-1][2] == "touch:3", "touch motion retains finger identity")
	view.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(cancelled[-1] == ["clear", false, "lifecycle"], "focus loss cancels instead of emitting release shots")
	expect(not view.handle_pointer(move, point), "focus loss drops pointer ownership")
	view.grab_focus()
	await process_frame
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	expect(cancelled[-1] == ["next", true, "key:%d" % KEY_TAB], "focused native Tab routes to endpoint selection")
	tab.pressed = false
	Input.parse_input_event(tab)
	await process_frame
	expect(cancelled[-1] == ["next", false, "key:%d" % KEY_TAB], "focused key release retains source identity")
	view.queue_free()
	await process_frame
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 4:
		var repeated = View.new()
		get_root().add_child(repeated)
		repeated.present(model.snapshot(), "noon", true)
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "repeated teardown does not retain workbench nodes")
	print("Sugar bridge view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
