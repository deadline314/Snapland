extends Node

const Driver = preload("res://game/minigames/chocolate_etching_driver.gd")
const View = preload("res://game/minigames/chocolate_etching_view.gd")
const DriverTest = preload("res://game/tests/test_chocolate_etching_driver.gd")
const ViewTest = preload("res://game/tests/test_chocolate_etching_view.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
var driver := Driver.new()
var workbench: Control
var output := ""
var requested := Vector2i.ZERO
var large := false
var checks := 0
var failures := 0
var captures: Array[String] = []
var events := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("CHOCOLATE_CAPTURE_DIR")
	var dimensions := OS.get_environment("CHOCOLATE_REVIEW_SIZE").split("x")
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or dimensions.size() != 2:
		push_error("Native chocolate workbench requires a native window and absolute isolated save/capture paths")
		get_tree().quit(1)
		return
	requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if requested not in [Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(800, 600)]:
		get_tree().quit(1)
		return
	large = requested == Vector2i(800, 600)
	TranslationServer.set_locale("zh_TW")
	Paper.set_text_scale(1.25 if large else 1.0)
	Paper.set_reduced_motion(large)
	Input.use_accumulated_input = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = requested
	await frames(4)
	var background := ColorRect.new()
	background.color = Paper.DEEP
	background.size = Vector2(requested)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.clip_contents = true
	add_child(background)
	var other_focus := Control.new()
	other_focus.name = "OtherFocus"
	other_focus.focus_mode = Control.FOCUS_ALL
	other_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(other_focus)
	driver.reset(false, "noon")
	workbench = driver.create_view()
	background.add_child(workbench)
	workbench.focus_next = workbench.get_path_to(other_focus)
	workbench.size = View.DESIGN_SIZE
	var factor := minf(requested.x / View.DESIGN_SIZE.x, requested.y / View.DESIGN_SIZE.y)
	workbench.scale = Vector2.ONE * factor
	workbench.position = (Vector2(requested) - View.DESIGN_SIZE * factor) * 0.5
	workbench.grab_focus()
	driver.present("noon", large)
	await frames(3)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual viewport dimensions")
	var route := new_route("keyboard", false, 0)
	check(workbench.has_focus(), "native active workbench owns focus before delivery")
	route.tap("select")
	check(driver.snapshot().selected == 1 and workbench.has_focus() and not other_focus.has_focus(), "parsed Tab changes selected gear without GUI traversal")
	route.key(KEY_W, true)
	route.advance(0.1)
	var before_focus_change: Vector2 = driver.snapshot().cursor
	other_focus.grab_focus()
	route.advance(0.1)
	check(driver.snapshot().cursor == before_focus_change, "real Control focus exit clears movement")
	route.key(KEY_W, false)
	workbench.grab_focus()
	await _missteps()
	await _clean_route("keyboard", false, 0, false, "tutorial-02-three-gear")
	await _clean_route("pointer", false, 1, true, "tutorial-03-leftover-output")
	await _clean_route("touch", true, 0, true, "touch-assisted-output")
	await _retention()
	route = new_route("keyboard", false, 0)
	route.key(KEY_SPACE, true)
	route.key(KEY_D, true)
	route.advance(0.1)
	check(driver.snapshot().cutting, "tree-exit check starts from a real live preview")
	background.remove_child(workbench)
	check(not driver.snapshot().cutting and driver.snapshot().held_commands.is_empty(), "actual tree exit cancels held input")
	workbench.queue_free()
	await frames(2)
	check(captures.size() == 11, "all eleven raw native checkpoints were captured")
	print("NATIVE_CHOCOLATE ", JSON.stringify({"size": [requested.x, requested.y], "text_scale": Paper.text_scale(),
		"reduced_motion": large, "parsed_events": events, "captures": captures, "checks": checks, "failures": failures}))
	get_tree().quit(int(failures != 0))

func parse(event: InputEvent, design_point: Vector2) -> bool:
	if not event is InputEventKey:
		event.position = workbench.get_global_transform_with_canvas() * design_point
		if event is InputEventMouse:
			event.global_position = event.position
	events += 1
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return true

func new_route(source: String, assisted: bool, variant: int) -> DriverTest.Route:
	driver.reset(assisted, "noon")
	if driver.snapshot().variant != variant:
		driver.reset(assisted, "noon")
	workbench.grab_focus()
	return DriverTest.Route.new(source, assisted, variant, driver, parse)

func _missteps() -> void:
	var route := new_route("pointer", false, 0)
	var state := driver.snapshot()
	var points: PackedVector2Array = state.selected_guides[0]
	route.trace(points)
	route.tap("fold")
	state = driver.snapshot()
	check(state.selected_strokes.size() == 1 and state.participated and not state.parts[0].freed and state.depth == 0.5 and state.feedback.contains("未切透"), "real single shallow stroke remains connected")
	await capture("tutorial-01-heat")
	route.trace(points)
	route.tap("fold")
	check(driver.snapshot().parts[0].freed, "actual shallow retrace makes the first material hole")
	await capture("shallow-retrace-hole")
	route.select(1)
	var center: Vector2 = driver.snapshot().source_centers[1]
	route.trace(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(10, 0)]), false)
	check(not route.cut(1) and driver.snapshot().feedback.contains("舊熱線"), "actual interior kerf prevents second wheel extraction")
	await capture("interior-kerf-rejected")
	route.tap("undo")
	var before := driver.snapshot()
	check(before.selected_strokes.size() == 2 and before.feedback.contains("已撤銷"), "actual undo restores last committed stroke state")
	var start := View.board_to_design(center + Vector2(0, -8))
	route.pointer(start, true)
	route.motion(start + Vector2(12, 0))
	check(driver.snapshot().cutting and driver.snapshot().current_stroke.size() >= 2, "native press/drag presents a real live kerf")
	await capture("live-before-cancel")
	route.pointer(Vector2(100, 240), false)
	state = driver.snapshot()
	check(not state.cutting and state.current_stroke.is_empty() and state.selected_strokes == before.selected_strokes, "matched outside release discards live preview")
	await capture("undo-and-outside-cancel")
	route.select(0)
	route.tap("phase")
	route.place(0, Vector2(5, 5))
	check(not driver.snapshot().parts[0].mounted and driver.snapshot().feedback.contains("旋轉範圍"), "real invalid envelope drop is rejected")
	await capture("placement-rejected")
	route.place(0, driver.snapshot().pins[0])
	var mounted := driver.snapshot()
	var from: Vector2 = View.board_to_design(mounted.parts[0].position)
	route.pointer(from, true)
	route.motion(View.board_to_design(Vector2(210, 300)))
	check(driver.snapshot().parts[0].position == mounted.parts[0].position and driver.snapshot().cursor.distance_to(Vector2(210, 300)) < 0.01, "actual assembly drag moves only the preview")
	await capture("solid-mount-dashed-preview")
	route.pointer(Vector2(100, 240), false)
	check(driver.snapshot().parts[0].position == mounted.parts[0].position, "outside assembly drop leaves previous placement")

func _clean_route(source: String, assisted: bool, variant: int, idler: bool, label: String) -> void:
	var input_start := events
	var route := new_route(source, assisted, variant)
	if not route.craft(idler):
		check(false, "scripted input failed to cut genuine wheels %s" % JSON.stringify(route.diagnostic(driver.snapshot())))
		return
	if idler and source == "pointer":
		await capture("measured-leftover-idler-hole")
	route.arrange(idler)
	var before := driver.snapshot()
	var contacts := [Vector2i(0, 1), Vector2i(1, 3), Vector2i(2, 3)] if idler else [Vector2i(0, 1), Vector2i(1, 2)]
	check(before.connections == contacts, "measured placements yield expected topology " + route.route_name)
	route.command("tool", true)
	route.advance(0.75)
	var rotating := driver.snapshot()
	route.drive_angles = rotating.parts.map(func(p): return p.angle)
	check(rotating.output_travel > 1.0 and (rotating.output_omega < 0.0 if idler else rotating.output_omega > 0.0)
		and rotating.parts[0].angle != before.parts[0].angle and rotating.parts[2].angle != before.parts[2].angle, "actual gear angles, direction and outlet progress " + route.route_name)
	await capture(label)
	for _i in 18:
		if driver.snapshot().ended:
			break
		route.advance(0.25)
	route.command("tool", false)
	var result := driver.snapshot()
	check(result.success and result.devil == idler and result.score == (500 if idler else 400) and result.ordinary_eligible,
		"native genuine natural result " + route.route_name)
	print("NATIVE_ROUTE ", JSON.stringify({"parsed_events": events - input_start, "capture": label, "mid_turn": rotating.output_travel,
		"output_omega": rotating.output_omega, "result": route.result(result)}))

func frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame

func capture(label: String) -> void:
	driver.present("noon", large)
	await frames(2)
	var layout := ViewTest.layout_errors(workbench, get_viewport().get_visible_rect())
	check(layout.is_empty(), "%s all active text and control rectangles fit: %s" % [label, layout])
	for command: String in View.COMMANDS:
		var button: Button = workbench.get_node(command.capitalize())
		check(button.get_rect().is_equal_approx(View.button_rect(command)), "retained control and transformed hit rectangle agree at " + command)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var saved := image != null and image.get_size() == requested and image.save_png(output.path_join(label + ".png")) == OK
	check(saved, "native raw capture " + label)
	if saved:
		captures.append(label)
	print("NATIVE_LAYOUT ", JSON.stringify({"capture": label, "active_text": workbench.get_children().filter(func(n): return n is Label and n.is_visible_in_tree()).size(),
		"controls": View.COMMANDS.size(), "errors": layout}))

func _retention() -> void:
	var ids := ViewTest.retained_ids(workbench)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_before := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for i in 120:
		if i % 12 == 0:
			driver.reset(bool(i % 24), "night")
		driver.present("night", large)
	await frames(2)
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_after := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	check(ViewTest.retained_ids(workbench) == ids and nodes_before == nodes_after and resources_before == resources_after,
		"120 native presentations and ten retries preserve node/font/style identities and object counts")
	print("NATIVE_RETAINED ", JSON.stringify({"ids": ids, "nodes": [nodes_before, nodes_after],
		"resources": [resources_before, resources_after], "presentations": 120, "retries": 10}))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
