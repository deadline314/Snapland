extends SceneTree
const View = preload("res://game/minigames/sail_chase_view.gd")
const Model = preload("res://game/minigames/sail_chase_model.gd")
const Route = preload("res://game/tests/sail_chase_route.gd")
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
	var commands = Route.ModelCommands.new()
	var view = View.new()
	view.present(commands.snapshot(), "noon", false)
	get_root().add_child(view)
	await process_frame
	expect(view.find_child("SailViewport", true, false) is SubViewport, "one native viewport")
	for part in ["Water", "InnerLane", "Sailboat", "SailPivot", "Lightship", "Lamp", "Buoy0", "Buoy3", "Wake0", "Driftwood0"]:
		expect(view.find_child(part, true, false) != null, "sea part: " + part)
	commands.set_rudder(0.5)
	for i in 120: commands.step(1.0 / 60.0)
	var state: Dictionary = commands.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	var boat: Node3D = view.find_child("Sailboat", true, false)
	expect(is_equal_approx(boat.position.x, state.position.x) and is_equal_approx(boat.rotation.y, -state.heading), "boat pose follows the model")
	var sail: Node3D = view.find_child("SailPivot", true, false)
	expect(is_equal_approx(absf(sail.rotation.y), state.trim), "the sail opens to the model trim angle")
	var ship: Node3D = view.find_child("Lightship", true, false)
	expect(is_equal_approx(ship.position.x, state.lightship.x), "lightship follows its route")
	var flag: Node3D = view.find_child("Buoy0", true, false).find_child("Flag", true, false)
	expect(is_equal_approx(flag.rotation.y, -state.flag_wind), "flags point along the forecast wind")
	expect(view.status_text().contains("風從") and view.status_text().contains("帆角") and view.flag_text().contains("夥伴"), "wind, trim and helper advice are written out")
	var count := view.find_children("*", "", true, false).size()
	for i in 20:
		commands.step(0.1)
		view.present(commands.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	var second = Route.ModelCommands.new(false, 1)
	view.present(second.snapshot(), "noon", false)
	await process_frame
	expect(view.find_children("Driftwood*", "", true, false).size() == Model.VARIANTS[1].wood.size(), "driftwood rebuild leaves only the new layout")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("sheet_in").get_center())
	view.handle_pointer(event, View.button_rect("sheet_in").get_center())
	expect(seen.size() == 1, "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("left").get_center()), "touch-emulated mouse cannot double apply")
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
	print("Sail chase view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
