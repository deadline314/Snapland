extends SceneTree

const Driver = preload("res://game/minigames/cotton_wind_driver.gd")
const Model = preload("res://game/minigames/cotton_wind_model.gd")
const View = preload("res://game/minigames/cotton_wind_view.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Route = preload("res://game/tests/cotton_wind_route.gd")

var checks := 0
var failures := 0
var _driver := Driver.new()
var _view: Control
var _width: Vector2i
var _output := ""
var _events := 0
var _last_point := Vector2.ZERO
var _previous_frame: Image

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(View.COMMANDS == ["left", "right", "near", "far", "spin_left", "spin_right", "finish", "helper"], "fixed eight commands")
	var physical_points := [Model.LIMIT_MIN, Model.LIMIT_MAX, Vector2(-120, 155), Vector2(120, 45), Vector2(0, 90)]
	for stick: Vector2 in physical_points:
		var design := View.stick_to_design(stick)
		check(View.WORKSPACE.has_point(design) and View.design_to_stick(design).distance_to(stick) < 0.0001, "workbench projection round trip at %s" % stick)
	check(_capture_path("res://captures").is_empty() and _capture_path("user://captures").is_empty() and _capture_path("relative").is_empty(), "asset and relative paths cannot export frames")
	if DisplayServer.get_name() == "headless":
		_complete()
		return
	_width = DisplayServer.window_get_size()
	check(_width in [Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(800, 600)], "native resolution is a required size")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = _width
	_output = _capture_path(OS.get_environment("SNAPLAND_COTTON_CAPTURE_DIR"))
	TranslationServer.set_locale("zh_TW")
	Paper.set_text_scale(1.25)
	Paper.set_reduced_motion(true)
	Input.use_accumulated_input = false
	var background := ColorRect.new()
	background.size = Vector2(_width)
	background.color = Paper.DEEP
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var other_focus := Control.new()
	other_focus.focus_mode = Control.FOCUS_ALL
	other_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(other_focus)
	_driver.reset(false, "noon")
	_view = _driver.create_view()
	check(_driver.create_view() == _view, "driver retains the installed view")
	_view.size = View.DESIGN_SIZE
	var scale_factor := minf(_width.x / View.DESIGN_SIZE.x, _width.y / View.DESIGN_SIZE.y)
	_view.scale = Vector2.ONE * scale_factor
	_view.position = (Vector2(_width) - View.DESIGN_SIZE * scale_factor) * 0.5
	root.add_child(_view)
	await process_frame
	await process_frame
	check(root.get_visible_rect().size == Vector2(_width) and _view.has_focus(), "native workbench fits and owns GUI focus")
	var stage := _view.get_node("SpatialStage") as SubViewportContainer
	var viewport := stage.get_node("CottonViewport") as SubViewport
	var camera := viewport.get_camera_3d()
	check(stage.get_rect() == View.WORKSPACE and viewport.size == Vector2i(View.WORKSPACE.size) and viewport.world_3d != root.world_3d,
		"independent SubViewport pixels equal the work area")
	for stick: Vector2 in physical_points:
		var design := View.stick_to_design(stick)
		var world := Vector3(stick.x, 90, stick.y)
		var viewport_point := design - View.WORKSPACE.position
		var ray := camera.project_ray_origin(viewport_point)
		var plane = Plane(Vector3.UP, 90).intersects_ray(ray, camera.project_ray_normal(viewport_point))
		check(camera.unproject_position(world).distance_to(viewport_point) < 0.001 and plane is Vector3 and plane.distance_to(world) < 0.001,
			"actual camera and inverse inputs agree at %s" % stick)
	_layout("initial")
	_key(KEY_E, true)
	_key(KEY_RIGHT, true)
	var start: Vector3 = _driver.snapshot().stick
	var moved := _driver.step(0.05)
	check(moved.omega > 0 and moved.stick.x > start.x and moved.angle > 0, "parsed E and Right reach focused GUI, and turn and move")
	other_focus.grab_focus()
	check(_driver.step(0.05).stick == moved.stick and is_zero_approx(_driver.snapshot().omega), "real focus change clears physical keys")
	_key(KEY_E, false)
	_key(KEY_RIGHT, false)
	_view.grab_focus()
	_tap("spin_right")
	check(_driver.snapshot().omega > 0, "parsed mouse tap latches spin")
	_view.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(is_zero_approx(_driver.snapshot().omega), "window focus out clears pointer latch")
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key(KEY_E, true)
	check(is_zero_approx(_driver.snapshot().omega), "paused presentation does not take keyboard input")
	_key(KEY_E, false)
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.grab_focus()
	_reset_a()
	_tap("spin_right")
	_move_to(Route.target(_driver.snapshot(), false))
	for i in 1200:
		var state := _driver.step(Route.DT)
		if i == 119:
			check(state.material.player > 1.0 and not state.uniform and state.quality[0].mass != state.quality[2].mass,
				"partial frame arises from unequal real deposits")
			await _capture("game-030-step-01", state)
		if state.uniform or state.ended:
			check(state.uniform and not state.ended and state.participated, "all three actual bands meet quality before F")
			await _capture("game-030-step-02", state)
			_button(_last_point, false)
			_tap("finish")
			break
		_move_to(Route.target(state, false), true)
	var ordinary := _driver.snapshot()
	check(ordinary.ended and ordinary.success and ordinary.score == 400 and ordinary.ordinary_eligible, "parsed ordinary mouse route ends successfully with 400 and ordinary eligibility")
	print("COTTON_ORDINARY_RESULT ", JSON.stringify({"ended": ordinary.ended, "success": ordinary.success, "score": ordinary.score, "ordinary_eligible": ordinary.ordinary_eligible}))
	_reset_a()
	_tap("spin_right", 0)
	check(_driver.snapshot().omega > 0, "parsed finger tap latches spin")
	_move_to(Route.target(_driver.snapshot(), true), false, 0)
	var saw_tail := false
	for i in 1750:
		var state := _driver.step(Route.DT)
		if not saw_tail and not state.tail.is_empty() and state.tail.near_break:
			saw_tail = true
			check(state.tail.length > state.tail.rest_length and state.tail.receiver_band == 2 - state.tail.anchor_band,
				"live tension and distinct receiving end arise from actual far collection")
			await _capture("game-030-step-03", state)
		if state.uniform and state.rejoins > 0:
			_button(_last_point, false, 0)
			_tap("finish", 0)
			break
		_move_to(Route.target(state, true), true, 0)
	check(saw_tail and _driver.snapshot().score == 500 and _driver.snapshot().devil, "parsed touch drag route catches the free end and confirms 500")
	await _retention()
	_complete()

func _reset_a() -> void:
	_driver.reset(false, "noon")
	if _driver.snapshot().variant != 0:
		_driver.reset(false, "noon")

func _deliver(event: InputEvent, point := Vector2.ZERO) -> void:
	if not event is InputEventKey:
		event.position = _view.get_global_transform_with_canvas() * point
		if event is InputEventMouse:
			event.global_position = event.position
	_events += 1
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	_deliver(event)

func _button(point: Vector2, pressed: bool, finger := -1) -> void:
	if finger < 0:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		_deliver(event, point)
	else:
		var event := InputEventScreenTouch.new()
		event.index = finger
		event.pressed = pressed
		_deliver(event, point)

func _tap(command: String, finger := -1) -> void:
	var point := View.command_center(command)
	_button(point, true, finger)
	_button(point, false, finger)

func _move_to(target: Vector2, dragging := false, finger := -1) -> void:
	var design := View.stick_to_design(target)
	if not dragging:
		_button(design, true, finger)
	elif finger < 0:
		var mouse := InputEventMouseMotion.new()
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
		_deliver(mouse, design)
	else:
		var touch := InputEventScreenDrag.new()
		touch.index = finger
		_deliver(touch, design)
	_last_point = design

func _capture_path(path: String) -> String:
	if path.is_empty() or path.contains("://") or not path.is_absolute_path():
		return ""
	return path

func _layout(label: String) -> void:
	var bounds := Rect2(Vector2(0, 140), Vector2(1280, 580))
	var canvas := _view.get_global_transform_with_canvas()
	var buttons := 0
	var labels := 0
	var errors: Array[String] = []
	var band_rects: Array[Rect2] = []
	for child in _view.get_children():
		if child is Button:
			var command: String = View.COMMANDS[buttons]
			if not child.get_rect().is_equal_approx(View.button_rect(command)) or not View.COMMAND_PANEL.encloses(child.get_rect()) \
				or View.command_at(View.command_center(command)) != command or child.get_minimum_size().x > child.size.x or child.get_minimum_size().y > child.size.y:
				errors.append("%s actual=%s expected=%s minimum=%s" % [command, child.get_rect(), View.button_rect(command), child.get_minimum_size()])
			buttons += 1
		elif child is Label:
			if child.text.is_empty() or not child.is_visible_in_tree():
				continue
			labels += 1
			if child.size.x < child.get_minimum_size().x or child.size.y < child.get_minimum_size().y:
				errors.append("minimum " + child.name)
			if child.name.begins_with("Band"):
				var shaped: Vector2 = child.get_theme_font("font").get_multiline_string_size(child.text, HORIZONTAL_ALIGNMENT_CENTER, -1, child.get_theme_font_size("font_size"))
				var rect: Rect2 = child.get_rect()
				if shaped.x > rect.size.x or not View.WORKSPACE.encloses(rect) or (not band_rects.is_empty() and rect.intersects(band_rects.back())):
					errors.append("band column " + child.name + " shaped " + str(shaped) + " rect " + str(rect))
				band_rects.append(rect)
		else:
			continue
		if not bounds.encloses(child.get_rect()) or not root.get_visible_rect().encloses(canvas * child.get_rect()):
			errors.append("bounds " + child.name + " " + str(child.get_rect()))
	check(buttons == 8 and labels >= 18 and band_rects.size() == 3 and errors.is_empty(), "%s complete actual labels/controls: %s" % [label, errors])
	print("COTTON_LAYOUT ", JSON.stringify({"frame": label, "labels": labels, "controls": buttons, "errors": errors}))

func _measure_cotton(stick: Node3D, bands: Array, expected_position: Vector3, angle: float) -> bool:
	if not stick.position.is_equal_approx(expected_position) or not stick.basis.is_equal_approx(Basis(Vector3.RIGHT, angle)):
		return false
	var instance := stick.get_node("DepositedCotton") as MeshInstance3D
	var mesh := instance.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != 194 or normals.size() != 194 or indices.size() != 864:
		return false
	for i in vertices.size():
		if not vertices[i].is_finite() or not normals[i].is_finite():
			return false
	for ring in 6:
		for cell in 12:
			for edge in 2:
				var sample := 24 * ring + 2 * cell + edge
				var vertex := vertices[sample]
				var expected := Model.radius(bands[ring / 2][cell])
				if absf(Vector2(vertex.y, vertex.z).length() - expected) > 0.0001:
					return false
				var world_point := stick.global_transform * vertices[24 * ring + 2 * cell]
				var polar := fposmod(atan2(world_point.z - expected_position.z, world_point.y - expected_position.y) - angle, TAU)
				if floori(polar * 12.0 / TAU) != cell:
					return false
	return true

func _geometry(state: Dictionary) -> void:
	var player := _view.find_child("PlayerStick", true, false) as Node3D
	var helper := _view.find_child("HelperStick", true, false) as Node3D
	check(_measure_cotton(player, state.bands, state.stick, state.angle), "player mesh geometry encodes every cell and actual rotation")
	check(helper.visible == state.helper and _measure_cotton(helper, state.helper_bands, state.helper_stick, state.helper_angle), "helper has its separate mesh and real transform")
	var strands := (_view.find_child("AirborneStrands", true, false) as MultiMeshInstance3D).multimesh
	check(strands.instance_count == 128 and strands.visible_instance_count == state.strands.size(), "finite strand batch holds actual visible count")
	var endpoints_match := true
	for i in state.strands.size():
		var strand: Dictionary = state.strands[i]
		var segment := strands.get_instance_transform(i)
		endpoints_match = endpoints_match and segment.is_finite() and (segment * Vector3(0, -0.5, 0)).distance_to(strand.previous) < 0.001 \
			and (segment * Vector3(0, 0.5, 0)).distance_to(strand.position) < 0.001
	check(endpoints_match, "strand transforms preserve actual world endpoints")
	var beam := _view.find_child("TailLine", true, false) as MeshInstance3D
	var left := player.get_node("Receiver1") as MeshInstance3D
	var right := player.get_node("Receiver3") as MeshInstance3D
	if state.tail.is_empty():
		check(not beam.visible and not left.visible and not right.visible, "empty tail hides line and both receivers")
	else:
		var source := _view.find_child("TailAnchor", true, false) as Node3D
		var tip := _view.find_child("TailFreeEnd", true, false) as Node3D
		var segment := beam.global_transform
		check(beam.visible and source.visible and tip.visible and source.global_position.is_equal_approx(state.tail.anchor) \
			and tip.global_position.is_equal_approx(state.tail.free_end) and segment.is_finite() \
			and (segment * Vector3(0, -0.5, 0)).distance_to(state.tail.anchor) < 0.001 \
			and (segment * Vector3(0, 0.5, 0)).distance_to(state.tail.free_end) < 0.001, "live tail uses the two actual world-space points")
		var left_bounds := left.mesh.get_aabb()
		var right_bounds := right.mesh.get_aabb()
		check(left.visible == (state.tail.receiver_band == 0) and right.visible == (state.tail.receiver_band == 2) \
			and is_equal_approx(left_bounds.end.x, -30.0) and is_equal_approx(right_bounds.position.x, 30.0) \
			and left_bounds.position.x < -90.0 and right_bounds.end.x > 90.0, "only the real opposite receiver appears, with only its outer end capped")

func _capture(label: String, state: Dictionary) -> void:
	_driver.present("noon", true)
	await process_frame
	var status := (_view.get_node("Tail") as Label).text
	if label == "game-030-step-01":
		check(state.quality[0].mass == 0 and status.contains("先補滿空段") and not status.contains("厚薄比"), "partial collection identifies the empty band")
	elif label == "game-030-step-02":
		check(state.uniform and state.ratio >= 1.0 and status.contains("厚薄比 %.2f" % state.ratio), "uniform collection displays the measured ratio")
	_layout(label)
	_geometry(state)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == _width, "read native backbuffer at " + label)
	if image == null:
		return
	var design := _view.get_global_transform_with_canvas()
	var board := Rect2i(design * View.WORKSPACE)
	var warm := 0
	var mint := 0
	var changed := 0
	for y in range(board.position.y, board.end.y, 2):
		for x in range(board.position.x, board.end.x, 2):
			var pixel := image.get_pixel(x, y)
			warm += int(pixel.r > 0.55 and pixel.r > pixel.b + 0.10)
			mint += int(pixel.g > 0.65 and pixel.g > pixel.r + 0.18 and pixel.b > 0.48)
			if _previous_frame != null:
				var previous := _previous_frame.get_pixel(x, y)
				changed += int(absf(pixel.r - previous.r) + absf(pixel.g - previous.g) + absf(pixel.b - previous.b) > 0.2)
	check(warm > 50 and (_previous_frame == null or changed > 120) and (state.tail.is_empty() or mint > 10), "native workbench raster shows real movement and visible live receiver")
	_previous_frame = image
	if not _output.is_empty():
		var path := _output.path_join(label + ".png")
		check(not FileAccess.file_exists(path) and image.save_png(path) == OK, "immutable raw native capture " + label)
	print("COTTON_NATIVE_FRAME ", JSON.stringify({"label": label, "size": [_width.x, _width.y], "time": state.elapsed,
		"material": state.material.player, "quality": state.quality, "uniform": state.uniform, "ratio": state.ratio, "status": status,
		"strands": state.strands.size(), "tail_tension": state.tail.get("tension", 0), "tail": str(state.tail),
		"warm_pixels": warm, "mint_pixels": mint, "changed_pixels": changed}))

func _retention() -> void:
	_reset_a()
	_key(KEY_R, true)
	_key(KEY_R, false)
	_move_to(Vector2(120, 45))
	for i in 180:
		_driver.step(Route.DT)
	_button(_last_point, false)
	var state := _driver.snapshot()
	check(state.helper and state.material.helper > 0, "helper deposits its own material on a public route")
	_driver.present("night", true)
	_geometry(state)
	_layout("helper")
	var ids := _retained_ids()
	var count := _view.find_children("*", "", true, false).size()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var cotton := (_view.find_child("PlayerStick", true, false).get_node("DepositedCotton") as MeshInstance3D).mesh
	var changes: Array[int] = [0]
	cotton.changed.connect(func(): changes[0] += 1)
	var untouched := state.duplicate(true)
	for i in 120:
		_view.present(state, "night", true)
	check(changes[0] == 0 and state == untouched, "unchanged revision leaves retained mesh surfaces and snapshot untouched")
	for i in 10:
		_driver.reset(i % 2 == 0, "night")
		_driver.present("night", true)
	check(changes[0] > 0 and ids == _retained_ids() and count == _view.find_children("*", "", true, false).size(),
		"revisions replace surfaces but retain node, style, font, material, mesh, and batch identities")
	await process_frame
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_after := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	check(nodes == nodes_after and resources == resources_after, "repeated presentation does not grow node or resource counts")
	_tap("spin_left")
	_move_to(Vector2(-120, 155))
	check(_driver.snapshot().omega < 0, "tree-exit check starts with a real pointer latch")
	var freed_view: WeakRef = weakref(_view)
	var freed_world: WeakRef = weakref(_view.find_child("CottonViewport", true, false).world_3d)
	root.remove_child(_view)
	check(_driver.snapshot().held_commands.is_empty() and is_zero_approx(_driver.snapshot().omega), "tree exit clears latch and active drag")
	_view.queue_free()
	await process_frame
	await process_frame
	check(freed_view.get_ref() == null and freed_world.get_ref() == null, "workbench and separate World3D are released")
	print("COTTON_RETAINED ", JSON.stringify({"scene_nodes": count, "identities": ids.size(), "node_counts": [nodes, nodes_after],
		"resource_counts": [resources, resources_after], "presentations": 120, "resets": 10, "revision_change_events": changes[0],
		"parsed_events": _events, "size": [_width.x, _width.y], "scale": Paper.text_scale(), "reduced": true}))

func _retained_ids() -> Array[int]:
	var ids: Array[int] = []
	for child in _view.find_children("*", "", true, false):
		ids.append(child.get_instance_id())
		if child is MeshInstance3D:
			ids.append(child.mesh.get_instance_id())
			ids.append(child.material_override.get_instance_id())
		elif child is MultiMeshInstance3D:
			ids.append(child.multimesh.get_instance_id())
			ids.append(child.multimesh.mesh.get_instance_id())
			ids.append(child.material_override.get_instance_id())
		elif child is Label or child is Button:
			ids.append(child.get_theme_font("font").get_instance_id())
			if child is Button:
				ids.append(child.get_theme_stylebox("normal").get_instance_id())
				ids.append(child.get_theme_stylebox("pressed").get_instance_id())
	return ids

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _complete() -> void:
	print("Cotton wind view: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))
