extends SceneTree
const View = preload("res://game/minigames/shell_tide_view.gd")
const Model = preload("res://game/minigames/shell_tide_model.gd")
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
	expect(view.status_text().contains("第 1 / 3 段") and view.status_text().contains("聽潮聲示範"), "status names the phrase and phase")
	expect(view.pattern_text().contains("靜") and view.pattern_text().contains("珍珠貝"), "the ripple score lists shells and silences in words")
	for i in 600:
		if model.snapshot().phase == "echo": break
		model.step(1.0 / 120.0)
	var state: Dictionary = model.snapshot()
	var unchanged: Dictionary = state.duplicate(true)
	view.present(state, "dusk", true)
	expect(state == unchanged, "view treats snapshot as read-only")
	expect(view.pattern_text().contains("收起"), "unassisted echo hides the score in text too")
	var helped = Model.new()
	helped.reset(true, 0)
	for i in 600:
		if helped.snapshot().phase == "echo": break
		helped.step(1.0 / 120.0)
	view.present(helped.snapshot(), "night", false)
	expect(view.pattern_text().begins_with("波紋譜"), "assist keeps the score readable while echoing")
	expect(View.command_at(View.SHELL_CENTERS[1]) == "shell_1" and View.command_at(View.button_rect("wait").get_center()) == "wait", "shells and buttons are distinct tap targets")
	expect(View.command_at(Vector2(640, 330)).is_empty(), "the calm water between shells is not a target")
	var seen: Array = []
	view.command_requested.connect(func(command, pressed, source): seen.append([command, pressed, source]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	view.handle_pointer(event, View.SHELL_CENTERS[0])
	view.handle_pointer(event, View.SHELL_CENTERS[0])
	expect(seen.size() == 1 and seen[0][0] == "shell_0", "duplicate pointer press applied once")
	event.pressed = false
	view.handle_pointer(event, Vector2(-100, -100))
	expect(seen.size() == 2 and not seen[1][1], "release outside clears owner")
	event.pressed = true
	view.handle_pointer(event, Vector2(NAN, INF))
	expect(seen.size() == 2, "nonfinite pointer rejected")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	view.handle_pointer(touch, View.SHELL_CENTERS[1])
	touch.index = 5
	view.handle_pointer(touch, View.SHELL_CENTERS[2])
	expect(seen[-1][2] != seen[-2][2], "two fingers hold two shells independently")
	view.clear_pointer_input()
	expect(not seen[-1][1] and not seen[-2][1], "clear releases both fingers")
	event.device = InputEvent.DEVICE_ID_EMULATION
	expect(not view.handle_pointer(event, View.SHELL_CENTERS[3]), "touch-emulated mouse cannot double apply")
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
	print("Shell tide view: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
