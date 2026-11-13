extends SceneTree
const View = preload("res://game/minigames/crab_marbles_view.gd")
const Model = preload("res://game/minigames/crab_marbles_model.gd")
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
	expect(view.find_child("SandViewport", true, false) is SubViewport, "one native viewport")
	for part in ["SandBed", "Launcher", "AimArrow", "Marble", "HelperHint", "SandTrail", "CrabGate1", "CrabGate2", "CrabGate3", "Rock0", "Slope0"]:
		expect(view.find_child(part, true, false) != null, "tray part: " + part)
	expect(not view.find_child("FirstSegment", true, false).visible, "no path preview without assistance")
	model.set_aim_input(1.0)
	model.step(0.25)
	model.set_aim_input(0.0)
	model.set_charging(true)
	model.step(0.6)
	var state: Dictionary = model.snapshot()
	view.present(state, "noon", true)
	var aim: Node3D = view.find_child("AimArrow", true, false)
	expect(is_equal_approx(aim.rotation.y, -state.aim) and view.status_text().contains("蓄力"), "aim arrow and charge text follow the model")
	model.set_charging(false)
	for i in 600:
		model.step(1.0 / 60.0)
	state = model.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	var trail: MultiMeshInstance3D = view.find_child("SandTrail", true, false)
	expect(trail.multimesh.visible_instance_count == mini(state.trail.size(), View.TRAIL_DOTS) and trail.multimesh.visible_instance_count > 0, "sand trail shows the real path")
	var marks := 0
	for i in View.BOUNCE_MARKS:
		if view.find_child("Bounce%d" % i, true, false).visible: marks += 1
	expect(marks == mini(state.bounce_points.size(), View.BOUNCE_MARKS), "bounce rings mark the real bounces")
	expect(view.shot_text().contains("反彈") and view.status_text().contains("彈珠剩"), "shot results are written out")
	var count := view.find_children("*", "", true, false).size()
	for i in 10:
		view.present(model.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	var second = Model.new()
	second.reset(true, 1)
	view.present(second.snapshot(), "noon", false)
	await process_frame
	var gate: Node3D = view.find_child("CrabGate1", true, false)
	expect(gate != null and is_equal_approx(gate.position.x, Model.LAYOUTS[1].gates[0].x), "layout rebuild moves the gates")
	expect(view.find_children("CrabGate*", "", true, false).size() == 3, "rebuild leaves exactly three gates")
	expect(view.find_child("FirstSegment", true, false).visible, "assist shows the first segment")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("charge").get_center())
	view.handle_pointer(event, View.button_rect("charge").get_center())
	expect(seen.size() == 1 and seen[0][0] == "charge", "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("aim_left").get_center()), "touch-emulated mouse cannot double apply")
	view.queue_free()
	await process_frame
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for i in 6:
		var repeated = View.new()
		get_root().add_child(repeated)
		repeated.present(Model.new().snapshot(), "dawn", true)
		await process_frame
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "repeated create/free leaves bounded nodes")
	expect(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 4, "repeated create/free leaves bounded resources")
	print("Crab marbles view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
