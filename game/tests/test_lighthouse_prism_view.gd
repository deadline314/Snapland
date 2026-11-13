extends SceneTree
const View = preload("res://game/minigames/lighthouse_prism_view.gd")
const Model = preload("res://game/minigames/lighthouse_prism_model.gd")
const Route = preload("res://game/tests/lighthouse_prism_route.gd")
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
	expect(view.find_child("PrismViewport", true, false) is SubViewport, "one native viewport")
	for part in ["LighthouseTower", "LighthouseLamp", "SelectionRing", "Beam0", "Deck"]:
		expect(view.find_child(part, true, false) != null, "miniature part: " + part)
	for element in Model.ELEMENTS:
		expect(view.find_child("Element_" + element.id, true, false) != null, "element built: " + element.id)
	for beacon in Model.BEACONS:
		expect(view.find_child("Beacon_" + beacon.id, true, false) != null, "beacon built: " + beacon.id)
	expect(view.find_children("Fog*", "", true, false).size() == Model.FOG_LAYOUTS[0].cells.size(), "fog cells shown")
	var beams := 0
	for i in Model.MAX_SEGMENTS:
		if view.find_child("Beam%d" % i, true, false).visible: beams += 1
	expect(beams == commands.snapshot().segments.size(), "visible beams equal the model's traced segments")
	Route.arrange(commands, Route.CHAIN)
	var state: Dictionary = commands.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	var body: Node3D = view.find_child("Element_m1", true, false).find_child("Body", true, false)
	expect(is_equal_approx(body.rotation.y, -deg_to_rad(45.0)), "mirror body shows the model orientation")
	var lamp: MeshInstance3D = view.find_child("Beacon_north", true, false).find_child("BeaconLamp", true, false)
	expect(lamp.material_override.emission_enabled, "lit beacon lamp glows")
	expect(view.beacon_text().contains("北航標") and view.beacon_text().contains("亮") and view.beacon_text().contains("門檻"), "received light is written out, not color only")
	expect(view.status_text().contains("選取") and view.status_text().contains("霧帶") and view.status_text().contains("分束"), "status names selection, fog and splits")
	var shutter: Node3D = view.find_child("Element_g1", true, false).find_child("Body", true, false)
	expect(shutter.position.y < 0.0, "open shutter panel is lowered")
	var count := view.find_children("*", "", true, false).size()
	for i in 20:
		commands.step(0.1)
		view.present(commands.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	var variant = Route.ModelCommands.new(false, 1)
	view.present(variant.snapshot(), "noon", false)
	await process_frame
	expect(view.find_children("Fog*", "", true, false).size() == Model.FOG_LAYOUTS[1].cells.size(), "fog rebuild leaves only the new band")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("next").get_center())
	view.handle_pointer(event, View.button_rect("next").get_center())
	expect(seen.size() == 1 and seen[0][0] == "next", "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("settle").get_center()), "touch-emulated mouse cannot double apply")
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
	print("Lighthouse prism view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
