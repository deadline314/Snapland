extends SceneTree
const View = preload("res://game/minigames/tide_sandbar_view.gd")
const Model = preload("res://game/minigames/tide_sandbar_model.gd")
const Route = preload("res://game/tests/tide_sandbar_route.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
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
	expect(view.find_child("SandbarViewport", true, false) is SubViewport, "one native viewport")
	for part in ["Water", "SeaFloor", "NextSafeRing", "Traveller", "Helper", "Rope", "Anchor_camp", "Anchor_dune", "Anchor_highland", "Anchor_reef_north", "Anchor_reef_far", "Anchor_reef_south"]:
		expect(view.find_child(part, true, false) != null, "complete diorama part: " + part)
	for row in Model.CORRIDORS:
		expect(view.find_child("Corridor_" + row.id, true, false) != null, "corridor built: " + row.id)
	var traveller: Sprite3D = view.find_child("Traveller", true, false)
	var helper: Sprite3D = view.find_child("Helper", true, false)
	expect(traveller.texture != null and helper.texture != null, "whole authored frames on both characters")
	expect(traveller.texture.get_size() == Vector2(280, 360), "traveller keeps the full fixed canvas, never cropped or stretched")
	var water: MeshInstance3D = view.find_child("Water", true, false)
	expect(is_equal_approx(water.position.y, commands.snapshot().tide) or absf(water.position.y - commands.snapshot().tide) < 0.02, "water plane sits at the real tide level")
	var camp: Node3D = view.find_child("Anchor_camp", true, false)
	expect(camp.find_child("RouteFlag", true, false).visible, "camp root flag is visible")
	expect(not view.find_child("Anchor_dune", true, false).find_child("RouteFlag", true, false).visible, "unmarked dune has no flag")
	Route.walk_to(commands, "dune")
	commands.interact()
	commands.set_move(Vector2.RIGHT)
	commands.step(0.2)
	var state: Dictionary = commands.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	expect(view.find_child("Anchor_dune", true, false).find_child("RouteFlag", true, false).visible, "placed marker shows a flag")
	expect(is_equal_approx(traveller.position.x, state.position.x) and is_equal_approx(traveller.position.z, state.position.y), "traveller X/Z match the model")
	expect(View.direction_name(Vector2.RIGHT) == "right" and View.direction_name(Vector2(0, 1)) == "front" and View.direction_name(Vector2(-1, -1)) == "back_left", "eight-way facing maps to authored walk directions")
	expect(view.status_text().contains("水位") and view.status_text().contains("下一安全高點") and view.status_text().contains("礁"), "essential tide cues are text, not color only")
	expect(view.route_text().contains("中繼沙丘") and view.route_text().contains("夥伴守在"), "route and helper are named")
	var sun: DirectionalLight3D = view.find_child("SandbarSun", true, false)
	var dusk := sun.light_color
	view.present(state, "night", true)
	expect(sun.light_color != dusk, "phase refresh changes real lighting")
	# Wait into the warning window: the outline is shown steadily with reduced motion.
	for i in 600:
		commands.step(1.0 / 60.0)
		var row: Dictionary = {}
		for candidate in commands.snapshot().corridors:
			if candidate.id == "shortcut": row = candidate
		if row.warning: break
	view.present(commands.snapshot(), "noon", true)
	var outline: Node3D = view.find_child("Corridor_shortcut", true, false).find_child("FloodOutline", true, false)
	expect(outline.visible, "imminent flood outline is visible with reduced motion")
	var count := view.find_children("*", "", true, false).size()
	for i in 30:
		commands.step(0.1)
		view.present(commands.snapshot(), "night", true)
	expect(view.find_children("*", "", true, false).size() == count, "present reuses nodes")
	# Variant change rebuilds terrain once, without leaking old anchors.
	var variant = Route.ModelCommands.new(false, 1)
	view.present(variant.snapshot(), "noon", false)
	await process_frame
	var highland: Node3D = view.find_child("Anchor_highland", true, false)
	expect(highland != null and is_equal_approx(highland.position.z, -4.0), "variant moves the visible highland")
	expect(view.find_children("Anchor_*", "", true, false).size() == 6, "variant rebuild leaves exactly six anchors")
	var commands_seen: Array = []
	view.command_requested.connect(func(command, pressed, source): commands_seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("left").get_center())
	view.handle_pointer(event, View.button_rect("left").get_center())
	expect(commands_seen.size() == 1, "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(commands_seen.size() == 2 and not commands_seen[1][1], "release outside button clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(commands_seen.size() == 2, "nonfinite pointer rejected")
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	view.handle_pointer(touch, View.button_rect("up").get_center())
	touch.index = 7
	view.handle_pointer(touch, View.button_rect("run").get_center())
	expect(commands_seen[-1][2] != commands_seen[-2][2], "touch owners are independent")
	view.clear_pointer_input()
	expect(not commands_seen[-1][1] and not commands_seen[-2][1], "clear releases all touch owners")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("mark").get_center()), "touch-emulated mouse cannot double apply")
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
	print("Tide sandbar view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
