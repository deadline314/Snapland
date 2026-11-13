extends SceneTree
const View = preload("res://game/minigames/rope_tug_view.gd")
const Model = preload("res://game/minigames/rope_tug_model.gd")
const Route = preload("res://game/tests/rope_tug_route.gd")
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
	expect(view.find_child("TugViewport", true, false) is SubViewport, "one native viewport")
	for part in ["Tug", "Pontoon", "Dock", "Water", "CleatBow", "CleatStern", "Rope0"]:
		expect(view.find_child(part, true, false) != null, "bay part: " + part)
	expect(view.find_children("Breakwater*", "", true, false).size() == commands.snapshot().walls.size(), "every wall segment is built")
	expect(not view.find_child("Rope0", true, false).visible, "no rope before hooking")
	commands.interact()
	commands.set_thrust(1.0)
	commands.set_turn(0.4)
	for i in 90: commands.step(1.0 / 60.0)
	var state: Dictionary = commands.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	var tug: Node3D = view.find_child("Tug", true, false)
	var pontoon: Node3D = view.find_child("Pontoon", true, false)
	expect(is_equal_approx(tug.position.x, state.tug.x) and is_equal_approx(tug.position.z, state.tug.y) and is_equal_approx(tug.rotation.y, -state.tug_heading), "tug pose follows the model")
	expect(is_equal_approx(pontoon.position.x, state.pontoon.x) and is_equal_approx(pontoon.rotation.y, -state.pontoon_heading), "pontoon pose follows the model")
	expect(view.find_child("Rope0", true, false).visible, "hooked rope is drawn")
	expect(view.status_text().contains("繩長") and view.status_text().contains("張力") and view.status_text().contains("斷繩"), "tension and length are written out")
	expect(view.route_text().contains("已通過"), "route progress is written out")
	expect(View.strain({"tension": 3.0, "break_tension": 6.0}) == 0.5 and View.strain({}) == 0.0, "strain is a bounded fraction of the break limit")
	var count := view.find_children("*", "", true, false).size()
	for i in 20:
		commands.step(0.1)
		view.present(commands.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("ahead").get_center())
	view.handle_pointer(event, View.button_rect("ahead").get_center())
	expect(seen.size() == 1, "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("hook").get_center()), "touch-emulated mouse cannot double apply")
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
	print("Rope tug view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
