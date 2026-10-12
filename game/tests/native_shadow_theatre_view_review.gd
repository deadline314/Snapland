extends Control

## Native input fixture for ShadowTheatreView only; no Main, Session, HUD, or save writes.
const ModelScript := preload("res://game/minigames/shadow_theatre_model.gd")
const ViewScript := preload("res://game/minigames/shadow_theatre_view.gd")
const NORMAL_TIME_SCALE := 1.0
const QUARTER_TIME_SCALE := 0.25
const INPUT_GUARD := 900

var _model: RefCounted
var _view: Control
var _frame_delta := 0.0
var _failed := false
var _captures: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run_review")

func _process(delta: float) -> void:
	_frame_delta = delta
	if _model == null or _view == null:
		return
	_model.step(delta)
	_view.present_state(_model.snapshot(), _model.time_of_day, _reduced_motion)

var _reduced_motion := false

func _run_review() -> void:
	if not _native_guard():
		_fail("Native ShadowTheatreView review requires a windowed GPU run and an absolute isolated SNAPLAND_SAVE_PATH")
		return
	Engine.time_scale = NORMAL_TIME_SCALE
	_model = ModelScript.new()
	_model.reset(false, "noon")
	_view = ViewScript.new()
	_view.name = "ShadowTheatreSurface"
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.axis_requested.connect(_on_axis_requested)
	_view.lamp_target_requested.connect(_on_lamp_target_requested)
	_view.shutter_requested.connect(_on_shutter_requested)
	add_child(_view)
	await _frames(3)
	_view.grab_focus()
	if not _verify_physical_projection("normal initial state"):
		return
	for round_index in 3:
		var scale := QUARTER_TIME_SCALE if round_index == 2 else NORMAL_TIME_SCALE
		Engine.time_scale = scale
		if not await _align_and_shutter(round_index, scale, false):
			return
	Engine.time_scale = NORMAL_TIME_SCALE
	var normal: Dictionary = _model.snapshot()
	if not bool(normal.finished) or not bool(normal.success) or not bool(normal.devil):
		_fail("Normal route did not earn a genuine three-perfect, zero-miss devil result: %s" % str(normal))
		return
	var ledger: Array = normal.ledger
	if ledger.size() != 3 or _captures.size() != 3:
		_fail("Normal route did not resolve exactly three actual Space captures")
		return
	for index in 3:
		if str(ledger[index].status) != "perfect" or not bool(ledger[index].qualified) or not bool(ledger[index].perfect):
			_fail("Normal round %d did not record a perfect model judgement: %s" % [index + 1, str(ledger[index])])
			return
	print("SHADOW_NATIVE_NORMAL: " + JSON.stringify({"success": normal.success, "devil": normal.devil, "qualified": normal.qualified_count, "perfect": normal.perfect_count, "misses": normal.misses, "ledger": ledger}))
	# A separate assisted/reduced route first proves that the initial offset is not
	# auto-qualified, then earns the ordinary result from two real alignments.
	_model.reset(true, "night")
	_reduced_motion = true
	_view.present_state(_model.snapshot(), "night", true)
	await _frames(2)
	if int(_model.snapshot().qualified_count) != 0 or bool(_model.snapshot().finished):
		_fail("Assisted reduced route began with an automatic result")
		return
	_send_key(KEY_RIGHT, true)
	await get_tree().process_frame
	_send_key(KEY_RIGHT, false)
	await get_tree().process_frame
	var unaligned: Dictionary = _model.snapshot()
	var miss_limit := float(unaligned.normal_error_limit)
	if float(unaligned.shape_error) <= miss_limit:
		_fail("Assisted route's unaligned lamp is unexpectedly within its first-round tolerance")
		return
	if not _verify_physical_projection("assisted pre-miss"):
		return
	var misses_before: int = int(_model.misses)
	_send_key(KEY_SPACE, true)
	await get_tree().process_frame
	_send_key(KEY_SPACE, false)
	await get_tree().process_frame
	if _model.misses != misses_before + 1 or str(_model.snapshot().ledger[0].status) != "miss":
		_fail("Space at the real unaligned position did not create an assisted miss")
		return
	for round_index in [1, 2]:
		Engine.time_scale = QUARTER_TIME_SCALE
		if not await _align_and_shutter(round_index, QUARTER_TIME_SCALE, true):
			return
	Engine.time_scale = NORMAL_TIME_SCALE
	var assisted: Dictionary = _model.snapshot()
	if not bool(assisted.finished) or not bool(assisted.success) or bool(assisted.devil) or not bool(assisted.assisted) or int(assisted.qualified_count) != 2 or int(assisted.misses) != 1:
		_fail("Assisted/reduced route did not earn exactly two real qualifications without a devil result: %s" % str(assisted))
		return
	print("SHADOW_NATIVE_ASSISTED: " + JSON.stringify({"success": assisted.success, "devil": assisted.devil, "qualified": assisted.qualified_count, "perfect": assisted.perfect_count, "misses": assisted.misses, "ledger": assisted.ledger}))
	print("PASS: native ShadowTheatreView keyboard axes/depth, actual pointer rail adjustment, Space shutters, point-source/mesh/model projection match, three normal perfects, and assisted reduced route with a real miss")
	get_tree().quit(0)

func _native_guard() -> bool:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	return not path.is_empty() and path.is_absolute_path() and DisplayServer.get_name() != "headless"

func _align_and_shutter(round_index: int, time_scale: float, reduced: bool) -> bool:
	if int(_model.snapshot().round) != round_index or bool(_model.snapshot().finished):
		_fail("Expected round %d, live model shows %s" % [round_index + 1, str(_model.snapshot())])
		return false
	var target: Vector2 = _model.round_solution(round_index)
	var initial: Vector2 = _model.snapshot().lamp_position
	# Use the target only as a navigation waypoint. Held arrow events make every
	# intermediate move through ShadowTheatreView.axis_requested/model.continuous_axis.
	if not await _walk_axis_to(0, target.x, time_scale):
		return false
	if not await _walk_axis_to(1, target.y, time_scale):
		return false
	var after_keys: Vector2 = _model.snapshot().lamp_position
	if initial.distance_to(after_keys) < 0.08:
		_fail("Actual keyboard movement failed to change the lamp in both screen/depth controls")
		return false
	var before_pointer: Vector2 = _model.snapshot().lamp_position
	if not await _click_lamp_target(target):
		return false
	var after_pointer: Vector2 = _model.snapshot().lamp_position
	if after_pointer.distance_to(target) > 0.00002 or before_pointer.distance_to(after_pointer) < 0.0001:
		_fail("Actual pointer click did not adjust the lamp rail precisely: before=%s after=%s target=%s" % [str(before_pointer), str(after_pointer), str(target)])
		return false
	_view.present_state(_model.snapshot(), _model.time_of_day, reduced)
	if not _verify_physical_projection("round %d before shutter" % (round_index + 1)):
		return false
	var ready: Dictionary = _model.snapshot()
	if float(ready.shape_error) > float(ready.perfect_error_limit):
		_fail("Real keys and pointer did not align all cast vertices for round %d: error=%.6f limit=%.6f scale=%.2f" % [round_index + 1, float(ready.shape_error), float(ready.perfect_error_limit), time_scale])
		return false
	var previous_round := int(ready.round)
	var previous_capture_count := _captures.size()
	_send_key(KEY_SPACE, true)
	await get_tree().process_frame
	_send_key(KEY_SPACE, false)
	await get_tree().process_frame
	if _captures.size() != previous_capture_count + 1:
		_fail("Space key did not reach the view's shutter signal in round %d" % (round_index + 1))
		return false
	var entry: Dictionary = _captures.back()
	if int(entry.round) != previous_round or not bool(entry.accepted) or not bool(entry.perfect) or not bool(entry.qualified):
		_fail("Physical Space shutter did not yield the expected perfect result: %s" % str(entry))
		return false
	if not bool(_model.snapshot().finished) and int(_model.snapshot().round) != round_index + 1:
		_fail("Actual capture did not advance exactly one model round")
		return false
	return true

func _walk_axis_to(axis_index: int, destination: float, time_scale: float) -> bool:
	var guard := 0
	while guard < INPUT_GUARD:
		var lamp: Vector2 = _model.snapshot().lamp_position
		var current := lamp.x if axis_index == 0 else lamp.y
		var difference := destination - current
		var step := ModelScript.LAMP_SPEED * minf(maxf(_frame_delta, 0.0001), ModelScript.MAX_STEP)
		if absf(difference) <= step * 1.02 + 0.0002:
			return true # The pointer control finishes the last sub-frame remainder.
		var key := KEY_RIGHT if axis_index == 0 and difference > 0.0 else KEY_LEFT if axis_index == 0 else KEY_UP if difference > 0.0 else KEY_DOWN
		var before := lamp
		_send_key(key, true)
		await get_tree().process_frame
		_send_key(key, false)
		await get_tree().process_frame
		var after: Vector2 = _model.snapshot().lamp_position
		var moved := after.x - before.x if axis_index == 0 else after.y - before.y
		if moved * difference <= 0.0 or absf(moved) > ModelScript.LAMP_SPEED * ModelScript.MAX_STEP + 0.0002:
			_fail("Axis input did not move the real lamp toward its waypoint within the model's clamped step")
			return false
		guard += 1
	_fail("Keyboard lamp navigation exceeded %d actual key frames at time_scale %.2f" % [INPUT_GUARD, time_scale])
	return false

func _click_lamp_target(target: Vector2) -> bool:
	var design := Vector2(160.0 + (target.x - ModelScript.LAMP_X_MIN) / (ModelScript.LAMP_X_MAX - ModelScript.LAMP_X_MIN) * 960.0, 176.0 + (ModelScript.LAMP_Z_MAX - target.y) / (ModelScript.LAMP_Z_MAX - ModelScript.LAMP_Z_MIN) * 440.0)
	var local := Vector2(design.x * _view.size.x / 1280.0, design.y * _view.size.y / 720.0)
	var screen := _view.get_global_transform_with_canvas() * local
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.position = screen
	down.global_position = screen
	down.window_id = get_window().get_window_id()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = screen
	up.global_position = screen
	up.window_id = get_window().get_window_id()
	up.button_index = MOUSE_BUTTON_LEFT
	up.button_mask = 0
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	return true

func _verify_physical_projection(context: String) -> bool:
	var snapshot: Dictionary = _model.snapshot()
	var source: Vector2 = snapshot.lamp_position
	var actual_source: Vector3 = _view.lamp_light().global_position
	var expected_source := Vector3(source.x, ModelScript.LAMP_Y, source.y)
	if actual_source.distance_to(expected_source) > 0.00002 or _view.visible_emitter().global_position.distance_to(actual_source) > 0.00002:
		_fail("Visible emitter/spot source and model lamp diverged at " + context)
		return false
	var vertices: PackedVector3Array = _view.puppet_mesh().mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected: PackedVector2Array = snapshot.cast_vertices
	var matched := 0
	var maximum_error := 0.0
	for local_vertex in vertices:
		if absf(local_vertex.z + 0.045) > 0.00001:
			continue
		var world_vertex: Vector3 = _view.puppet_mesh().global_transform * local_vertex
		var denominator: float = world_vertex.z - actual_source.z
		if absf(denominator) < 0.00001:
			_fail("Physical light ray is parallel to the wall at " + context)
			return false
		var t: float = (ModelScript.WALL_Z - actual_source.z) / denominator
		var wall_point: Vector3 = actual_source + (world_vertex - actual_source) * t
		var nearest := INF
		for formula_vertex in expected:
			nearest = minf(nearest, Vector2(wall_point.x, wall_point.y).distance_to(formula_vertex))
		maximum_error = maxf(maximum_error, nearest)
		matched += 1
	if matched < 20 or maximum_error > 0.0001:
		_fail("Extruded mesh light-facing vertices disagree with point-projection formula at %s: vertices=%d max_error=%.7f" % [context, matched, maximum_error])
		return false
	return true

func _on_axis_requested(horizontal: float, depth: float) -> void:
	_model.continuous_axis(horizontal, depth, _frame_delta)

func _on_lamp_target_requested(target: Vector2) -> void:
	_model.setlamp_target(target)

func _on_shutter_requested() -> void:
	_captures.append(_model.capture())
	_view.present_state(_model.snapshot(), _model.time_of_day, _reduced_motion)

func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.window_id = get_window().get_window_id()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	Engine.time_scale = NORMAL_TIME_SCALE
	push_error("Native ShadowTheatreView review: " + message)
	get_tree().quit(1)
