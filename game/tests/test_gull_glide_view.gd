extends SceneTree
const View = preload("res://game/minigames/gull_glide_view.gd")
const Model = preload("res://game/minigames/gull_glide_model.gd")
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
	expect(view.status_text().contains("展翼滑翔") and view.status_text().contains("羽毛 0／3") and view.status_text().contains("展翼可滑到"), "status names wing state, feathers and glide reach")
	expect(view.guide_text().contains("下一根羽毛"), "guide points at the next feather")
	model.set_tucked(true)
	model.step(0.5)
	var state: Dictionary = model.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	expect(view.status_text().contains("收翼俯衝"), "status shows the tuck")
	var gap: Dictionary = state.gap
	model._bird.position = Vector2(gap.x - 3.0, 9.0)
	view.present(model.snapshot(), "noon", false)
	expect(view.guide_text().contains("岩縫只容收翼"), "approach explains the gap rule")
	var thermals := func() -> int: return view.find_children("Thermal*", "MeshInstance3D", true, false).size()
	expect(thermals.call() == 3, "three thermals are built")
	var other = Model.new()
	other.reset(false, 1)
	view.present(other.snapshot(), "night", false)
	await process_frame
	expect(thermals.call() == 3, "layout swap replaces thermals instead of stacking them")
	expect(View.command_at(View.button_rect("tuck").get_center()) == "tuck" and View.command_at(Vector2(600, 400)) == "tuck", "button and stage hold tuck")
	expect(View.command_at(View.METER.get_center()).is_empty() and View.command_at(Vector2(640, 160)).is_empty(), "meter and status band are not targets")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, Vector2(600, 400))
	view.handle_pointer(event, Vector2(600, 400))
	expect(seen.size() == 1 and seen[0][0] == "tuck", "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	view.handle_pointer(touch, Vector2(500, 300))
	touch.index = 5
	view.handle_pointer(touch, View.button_rect("tuck").get_center())
	expect(seen[-1][2] != seen[-2][2], "two fingers own the tuck separately")
	view.clear_pointer_input()
	expect(not seen[-1][1] and not seen[-2][1], "clear releases both fingers")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, Vector2(600, 400)), "touch-emulated mouse cannot double apply")
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
	print("Gull glide view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
