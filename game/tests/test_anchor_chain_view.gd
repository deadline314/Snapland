extends SceneTree
const View = preload("res://game/minigames/anchor_chain_view.gd")
const Model = preload("res://game/minigames/anchor_chain_model.gd")
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
	get_root().add_child(view)
	view.present(model.snapshot(), "noon", false)
	await process_frame
	expect(view.status_text().contains("礁石1") and view.status_text().contains("未下錨"), "status names the selection and chain")
	expect(view.torque_text().contains("東邊航道") and view.torque_text().contains("90°"), "torque line names the channel and turn left")
	model.place()
	for i in 3: model.select_next(1)
	model.place()
	model.set_reeling(true)
	model.step(0.2)
	var state: Dictionary = model.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	expect(view.status_text().contains("礁石1→錨點"), "chain path reads bow → reef → anchor")
	expect(view.torque_text().contains(str(state.reason)), "torque line carries the model's reason")
	var reefs := func() -> int: return view.find_children("Reef*", "Node3D", true, false).size()
	expect(reefs.call() == 3, "three reefs are built")
	var mirrored = Model.new()
	mirrored.reset(false, 1)
	view.present(mirrored.snapshot(), "night", false)
	await process_frame
	expect(reefs.call() == 3, "layout swap replaces reefs instead of stacking them")
	expect(View.command_at(View.button_rect("reel").get_center()) == "reel" and View.command_at(View.button_rect("undo").get_center()) == "undo", "every command has a button")
	expect(View.command_at(Vector2(640, 380)).is_empty(), "the bay itself is not a button")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.button_rect("reel").get_center())
	view.handle_pointer(event, View.button_rect("reel").get_center())
	expect(seen.size() == 1 and seen[0][0] == "reel", "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	view.handle_pointer(touch, View.button_rect("reel").get_center())
	touch.index = 5
	view.handle_pointer(touch, View.button_rect("helper").get_center())
	expect(seen[-1][2] != seen[-2][2], "two fingers own separate buttons")
	view.clear_pointer_input()
	expect(not seen[-1][1] and not seen[-2][1], "clear releases both fingers")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.button_rect("place").get_center()), "touch-emulated mouse cannot double apply")
	view.queue_free()
	await process_frame
	await process_frame
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 6:
		var repeated = View.new()
		get_root().add_child(repeated)
		repeated.present(Model.new().snapshot(), "dawn", true)
		await process_frame
		repeated.queue_free()
		await process_frame
	expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= baseline + 2, "repeated create/free leaves bounded nodes")
	print("Anchor chain view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
