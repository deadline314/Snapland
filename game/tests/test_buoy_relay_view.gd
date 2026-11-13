extends SceneTree
const View = preload("res://game/minigames/buoy_relay_view.gd")
const Model = preload("res://game/minigames/buoy_relay_model.gd")
const Route = preload("res://game/tests/buoy_relay_route.gd")
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
	expect(view.find_child("RelayViewport", true, false) is SubViewport, "one native viewport")
	for part in ["Sea", "Beach", "Figure0", "Figure1", "Figure2", "Tube0", "Tube2", "Ring", "Rope", "LandingMarker", "Platform1", "Platform2"]:
		expect(view.find_child(part, true, false) != null, "sea part: " + part)
	var hero: Sprite3D = view.find_child("Figure2", true, false)
	expect(hero.texture == hero.get_meta("hero") and hero.texture.get_size() == Vector2(280, 360), "the active outer buoy shows the whole player figure")
	var camera: Camera3D = view.find_child("RelayCamera", true, false)
	var outer_x := camera.position.x
	expect(not view.find_child("Ring", true, false).visible and not view.find_child("LandingMarker", true, false).visible, "no ring or preview before throwing unassisted")
	commands.set_action(true)
	commands.step(0.4)
	commands.set_action(false)
	commands.step(0.3)
	var state: Dictionary = commands.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	var ring: MeshInstance3D = view.find_child("Ring", true, false)
	expect(ring.visible and is_equal_approx(ring.position.x, state.ring.x), "the flying ring follows the model")
	expect(view.find_child("Rope", true, false).visible, "rope runs from the buoy to the ring")
	expect(view.status_text().contains("站點") and view.status_text().contains("送達"), "station and progress are written out")
	var tube: Node3D = view.find_child("Tube1", true, false)
	expect(is_equal_approx(tube.position.x, state.tubes[1].x), "tubes sit at their drifted positions")
	# Hand off to the middle buoy: the camera and the player figure switch stations.
	var relay = Route.ModelCommands.new()
	var aim: float = Route.plan_catch(relay.snapshot(), false)
	Route.throw_with(relay, Route.power_for(aim - relay.snapshot().station_x), 1.0 / 60.0)
	for i in 900:
		var s: Dictionary = relay.snapshot()
		if s.phase == "aim_pass": break
		if s.phase == "reeling": relay.set_action(absf(s.bundle_wobble) < 0.6)
		relay.step(1.0 / 60.0)
	Route.throw_with(relay, Route.power_for(5.0), 1.0 / 60.0)
	for i in 60: relay.step(1.0 / 60.0)
	view.present(relay.snapshot(), "noon", true)
	expect(relay.snapshot().station == 1 and camera.position.x < outer_x, "the camera pans to the middle buoy")
	var middle: Sprite3D = view.find_child("Figure1", true, false)
	expect(middle.texture == middle.get_meta("hero") and hero.texture == hero.get_meta("helper"), "the player figure moves with the active station")
	expect(view.find_child("Tube%d" % relay.snapshot().held[0], true, false).visible, "the held tube stays visible after the switch")
	var count := view.find_children("*", "", true, false).size()
	for i in 20:
		relay.step(0.1)
		view.present(relay.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("action").get_center())
	view.handle_pointer(event, View.button_rect("action").get_center())
	expect(seen.size() == 1, "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("action").get_center()), "touch-emulated mouse cannot double apply")
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
	expect(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 6, "repeated create/free leaves bounded resources")
	print("Buoy relay view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
