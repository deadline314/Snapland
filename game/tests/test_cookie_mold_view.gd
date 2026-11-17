extends SceneTree
const View = preload("res://game/minigames/cookie_mold_view.gd")
const Model = preload("res://game/minigames/cookie_mold_model.gd")
const Route = preload("res://game/tests/test_cookie_mold.gd")
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
static func projected_bounds(node: Node3D, camera: Camera3D) -> Rect2:
	var bounds := Rect2()
	var started := false
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		for corner in 8:
			var point := camera.unproject_position(mesh.global_transform * mesh.mesh.get_aabb().get_endpoint(corner))
			if not started:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
			else:
				bounds = bounds.expand(point)
	return bounds

static func idle_hand_clear(view: Control) -> bool:
	var camera: Camera3D = view.find_child("CookieCamera", true, false)
	var hand: Node3D = view.find_child("RightTappingHand", true, false)
	var cookie: Node3D = view.find_child("ActualCookie", true, false)
	var selection: MeshInstance3D = view.find_child("SelectedEdge", true, false)
	var hand_bounds := projected_bounds(hand, camera)
	var cue_bounds := Rect2(camera.unproject_position(selection.global_position) - Vector2.ONE * 8.0, Vector2.ONE * 16.0)
	return hand.visible and not hand_bounds.intersects(projected_bounds(cookie, camera).grow(4.0)) and not hand_bounds.intersects(cue_bounds)

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var model = Model.new()
	var view = View.new()
	get_root().add_child(view)
	var state: Dictionary = model.snapshot()
	var original := state.duplicate(true)
	view.present(state, "noon", false)
	await process_frame
	expect(state == original, "presentation never mutates model data")
	expect(view.find_child("CookieWorkbench", true, false) is Node3D, "real isolated 3D workbench")
	expect(view.find_children("CookieLayer?", "MeshInstance3D", true, false).size() == 3, "retained lower cookie filling upper cookie")
	expect(view.find_children("MoldSide*", "MeshInstance3D", true, false).size() == 32, "bounded actual mold walls")
	expect(view.find_children("Finger?Knuckle", "MeshInstance3D", true, false).size() == 8 and view.find_children("Finger?Tip", "MeshInstance3D", true, false).size() == 8, "two articulated four-finger gloved hands")
	expect(view.find_children("WrappedThumb", "MeshInstance3D", true, false).size() == 2, "recognizable thumbs wrap the handles")
	var camera: Camera3D = view.find_child("CookieCamera", true, false)
	expect(idle_hand_clear(view), "visible idle right hand clears cookie silhouette and selected cue")
	for i in state.edges.size():
		var p := View.edge_world(state, i)
		var actual := camera.unproject_position(p) + View.STAGE.position
		expect(actual.distance_to(View.edge_point(state, i)) < 0.01, "edge depth helper matches rendered physical edge")
		var hit := View.edge_at(View.edge_point(state, i), state)
		expect(hit == i, "each visible edge has its own actual pointer hit")
	var p := Vector2(1.25, -0.7)
	expect(View.work_point(View.design_point(p, 0.3), 0.3).distance_to(p) < 0.00001, "depth-aware projection round trip")
	var mesh: MeshInstance3D = view.find_child("CookieLayer0", true, false)
	var retained_mesh := mesh.mesh
	var retained_material := mesh.material_override
	var nodes := view.find_children("*", "", true, false).size()
	for frame in 120:
		model.step(1.0 / 120.0)
		view.present(model.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == nodes and mesh.mesh == retained_mesh and mesh.material_override == retained_material, "present retains all nodes meshes materials")
	model.reset(true, 1)
	view.present(model.snapshot(), "noon", true)
	expect(mesh.mesh != retained_mesh and view.find_children("*", "", true, false).size() == nodes, "actual config rebuilds finite geometry only")
	model.reset(false, 0)
	for shape in 6:
		var shape_state: Dictionary = model.snapshot()
		view.present(shape_state, "noon", true)
		expect(idle_hand_clear(view), "idle right hand clears each real shape and selected cue")
		for edge in shape_state.edges.size():
			var edge_position := View.edge_world(shape_state, edge)
			var projected := camera.unproject_position(edge_position) + View.STAGE.position
			expect(projected.distance_to(View.edge_point(shape_state, edge)) < 0.01 and View.edge_at(projected, shape_state) == edge, "all six real polygon edge projections and hits")
		expect(view.find_children("*", "", true, false).size() == nodes, "shape change preserves fixed node bound")
		Route.release_cookie(model)
		Route.catch_cookie(model)
		if not model.snapshot().ended:
			Route.advance(model, 0.46)
	model.reset(true, 1)
	view.present(model.snapshot(), "noon", true)
	view.scale = Vector2.ONE * 0.625
	Paper.set_text_scale(1.25)
	expect(view.text_size(16) * 0.625 >= 17.5, "800px enlarged physical font is readable")
	for i in View.COMMANDS.size():
		var rect := View.button_rect(View.COMMANDS[i])
		expect(rect.end.x <= 1256 and rect.end.y <= 720 and View.command_at(rect.get_center()) == View.COMMANDS[i], "visible action fits design bounds")
		expect(Paper.font().get_string_size(View.BUTTON_ACTIONS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(16)).x <= 118, "enlarged command text fits: " + View.BUTTON_ACTIONS[i])
	expect(Paper.font().get_string_size(view.status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, view.text_size(18)).x <= 1200, "enlarged status fits")
	Paper.set_text_scale(1.0)
	view.scale = Vector2.ONE
	var seen: Array = []
	var commands: Array = []
	view.pointer_requested.connect(func(action, point, source): seen.append([action, point, source]))
	view.command_requested.connect(func(command, pressed, source): commands.append([command, pressed, source]))
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	var point := View.edge_point(model.snapshot(), 0)
	expect(view.handle_pointer(touch, point), "visible edge receives owned finger")
	touch.index = 8
	expect(not view.handle_pointer(touch, point), "second finger rejected by retained view")
	touch.index = 3
	touch.canceled = true
	touch.pressed = false
	expect(view.handle_pointer(touch, point) and seen[-1] == ["cancel", point, "touch:3"], "touch cancel retains original owner and never emits release")
	touch.canceled = false
	touch.pressed = true
	view.handle_pointer(touch, point)
	view.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(commands[-1] == ["clear", false, "lifecycle"], "focus loss clears all input without shot")
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	expect(not view.handle_pointer(drag, point), "focus loss removes pointer ownership")
	view.queue_free()
	await process_frame
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 3:
		var repeated = View.new()
		get_root().add_child(repeated)
		repeated.present(model.snapshot(), "noon", true)
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "teardown retains no workbench nodes")
	print("Cookie mold view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
