extends SceneTree
const View = preload("res://game/minigames/cargo_balance_view.gd")
const Model = preload("res://game/minigames/cargo_balance_model.gd")
const Route = preload("res://game/tests/cargo_balance_route.gd")
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
	expect(view.find_child("HoldViewport", true, false) is SubViewport, "one native viewport")
	for part in ["Ship", "Pier", "Water", "Cursor", "Keel", "HoldFloor", "Crate0", "Crate5", "GravityProjection"]:
		expect(view.find_child(part, true, false) != null, "section part: " + part)
	expect(view.find_child("Pier", true, false).visible, "pier shows while loading")
	expect(not view.find_child("GravityProjection", true, false).visible, "no centre-of-gravity projection without assistance")
	Route.load_hold(commands, Route.plan(commands.snapshot()))
	commands.confirm()
	for i in 500: commands.step(1.0 / 60.0)
	var state: Dictionary = commands.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	var ship: Node3D = view.find_child("Ship", true, false)
	expect(is_equal_approx(ship.rotation.z, -deg_to_rad(state.heel)), "the hull rolls by the model heel")
	expect(not view.find_child("Pier", true, false).visible, "pier hides at sea")
	expect(view.status_text().contains("傾斜") and view.status_text().contains("繫帶"), "heel and straps are written out")
	expect(view.wave_text() != "", "wave forecast line is present")
	var crate: MeshInstance3D = view.find_child("Crate0", true, false)
	var expected: Vector3 = ship.global_transform * View.cell_local(state.crates[0].cell)
	expect(crate.global_position.distance_to(expected) < 0.01, "hold crates ride with the rolling ship")
	var count := view.find_children("*", "", true, false).size()
	for i in 20:
		commands.step(0.1)
		view.present(commands.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	var helped = Route.ModelCommands.new(true)
	view.present(helped.snapshot(), "noon", false)
	expect(view.find_child("GravityProjection", true, false).visible, "assist projects the centre of gravity")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("grab").get_center())
	view.handle_pointer(event, View.button_rect("grab").get_center())
	expect(seen.size() == 1, "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("confirm").get_center()), "touch-emulated mouse cannot double apply")
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
	print("Cargo balance view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
