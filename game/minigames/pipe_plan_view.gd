extends Control
## A 4×4 harbor engineer's plan, drawn in stable 1280×720 design coordinates.
## cell_at() accepts points in those design coordinates; convert local pointer positions
## with design_point_from_local() when the Control is scaled or letterboxed.

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const BOARD_RECT := Rect2(320.0, 166.0, 640.0, 400.0)
const GRID_SIDE := 4
const FLOW_SECONDS := 1.15
const FontProfiles = preload("res://game/ui/font_profiles.gd")
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const BITS: Array[int] = [1, 2, 4, 8]
const PORT_NORMALS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const PHASES: Array[String] = ["dawn", "noon", "dusk", "night"]
const LEGACY_TARGETS: Array = [[15, 2]]
const INK := Color("#263f50")
const TEAL := Color("#4b8985")
const CORAL := Color("#c86d60")
const OCHRE := Color("#a97848")
const WATER := Color("#38aeb0")
const WOOD_DARK := Color("#634936")
const WOOD := Color("#9d7650")
const WOOD_LIGHT := Color("#c6a477")
const PAPER_EDGE := Color("#e7d8b9")
const SOIL := Color("#816448")
const LEAF := Color("#628b62")
const LEAF_LIGHT := Color("#87a96b")
const PETAL := Color("#e8877e")
const UI_LABEL_RECT := Rect2(96.0, 180.0, 220.0, 64.0)
const UI_TURN_RECT := Rect2(1080.0, 180.0, 120.0, 68.0)
const FLOWER_SIZE := Vector2(102.0, 64.0)

var cells: Array[int] = []
var cursor := -1
var move_count := 0
var connected := false
var ended := false
var elapsed := 0.0
var reduced_motion := false
var animation_active := true
var time_phase := "noon"
var flow_progress := 0.0
var flow_route: Array[int] = []
var flow_edges: Array = []
var order_targets: Array = []
var source_cell := 0
var source_port := 0
var order_index := 0
var order_count := 1
var order_brief := ""
var completed_beds := 0
var _target_outlet_paths: Array[PackedVector2Array] = []
var _flow_starts: Array[Vector2] = []
var _flow_ends: Array[Vector2] = []
var _flow_lengths: Array[float] = []
var _flow_total_length := 0.0
var _bloom_visible := false
var _route_connected_input := false
var route_rebuild_count := 0
var _seen_board_revision := -1
var _seen_order_revision := -1
var _seen_network_revision := -1

func _ready() -> void:
	custom_minimum_size = Vector2(960.0, 540.0)
	set_process(true)
	queue_redraw()

func configure(use_reduced_motion: bool, phase_id: String) -> void:
	var normalized_phase := phase_id if phase_id in PHASES else "noon"
	if reduced_motion == use_reduced_motion and time_phase == normalized_phase:
		return
	reduced_motion = use_reduced_motion
	time_phase = normalized_phase
	if connected and reduced_motion:
		flow_progress = 1.0
	_bloom_visible = connected and (reduced_motion or flow_progress >= 1.0)
	queue_redraw()

func present(next_cells: Array, next_cursor: int, next_move_count: int, is_connected: bool, round_elapsed: float, is_ended: bool) -> void:
	var was_connected := connected
	var cells_changed := not _same_cells(next_cells)
	var route_input_changed := cells_changed or is_connected != _route_connected_input
	if cells_changed:
		cells.clear()
		for value in next_cells:
			cells.append(clampi(int(value), 0, 15))
	cursor = next_cursor if next_cursor >= 0 and next_cursor < cells.size() else -1
	move_count = maxi(0, next_move_count)
	elapsed = maxf(0.0, round_elapsed)
	ended = is_ended
	if route_input_changed:
		_route_connected_input = is_connected
		route_rebuild_count += 1
		flow_route.clear()
		if is_connected and cells.size() == GRID_SIDE * GRID_SIDE:
			flow_route = _find_flow_route(cells)
	connected = is_connected and flow_route.size() >= 2
	flow_edges = []
	order_targets = LEGACY_TARGETS
	source_cell = 0
	source_port = 0
	order_index = 0
	order_count = 1
	order_brief = "南側單花床"
	completed_beds = 0
	_seen_board_revision = -1
	_seen_order_revision = -1
	_seen_network_revision = -1
	_rebuild_flow_geometry()
	if not connected:
		flow_progress = 0.0
	elif not was_connected:
		flow_progress = 1.0 if reduced_motion else 0.0
	elif reduced_motion:
		flow_progress = 1.0
	_bloom_visible = connected and (reduced_motion or flow_progress >= 1.0)
	queue_redraw()

func present_order(state: Dictionary, round_elapsed: float, use_reduced_motion: bool, phase_id: String) -> void:
	configure(use_reduced_motion, phase_id)
	var next_cells: Array = state.get("cells")
	var board_revision := int(state.get("board_revision", -1))
	var board_changed := board_revision >= 0 and board_revision != _seen_board_revision
	if board_revision < 0:
		board_changed = not _same_cells(next_cells)
	if next_cells != null and next_cells.size() == GRID_SIDE * GRID_SIDE and board_changed:
		cells.clear()
		for value in next_cells:
			cells.append(clampi(int(value), 0, 15))
		_seen_board_revision = board_revision
	cursor = int(state.get("cursor", -1))
	if cursor < 0 or cursor >= cells.size():
		cursor = -1
	move_count = int(state.get("total_turns", 0))
	elapsed = maxf(0.0, round_elapsed)
	ended = bool(state.get("ended", false))
	order_index = int(state.get("order_index", 0))
	order_count = int(state.get("order_count", 3))
	order_brief = str(state.get("brief", ""))
	completed_beds = int(state.get("completed_beds", 0))
	var order_revision := int(state.get("order_revision", -1))
	var order_changed := order_revision >= 0 and order_revision != _seen_order_revision
	if order_revision < 0:
		order_changed = order_index != _seen_order_revision
	if order_changed:
		var source: Array = state.get("source")
		source_cell = int(source[0]) if source != null and source.size() > 0 else 0
		source_port = int(source[1]) if source != null and source.size() > 1 else 0
		var target_data: Array = state.get("targets")
		order_targets = target_data if target_data != null else LEGACY_TARGETS
		_seen_order_revision = order_revision if order_revision >= 0 else order_index
	var was_connected := connected
	connected = bool(state.get("connected", false))
	var network_revision := int(state.get("network_revision", -1))
	var network_changed := network_revision >= 0 and network_revision != _seen_network_revision
	if network_revision < 0:
		network_changed = connected != _route_connected_input or board_changed
	if network_changed:
		flow_edges = state.get("flow_edges") if state.get("flow_edges") != null else []
		flow_route.clear()
		_seen_network_revision = network_revision
		_rebuild_flow_geometry()
	_route_connected_input = connected
	if not connected:
		flow_progress = 0.0
	elif use_reduced_motion:
		flow_progress = 1.0
	else:
		flow_progress = clampf(float(state.get("flow_progress", 0.0)), 0.0, 1.0)
	if connected and not was_connected and use_reduced_motion:
		_bloom_visible = true
	else:
		_bloom_visible = connected and (use_reduced_motion or flow_progress >= 1.0)
	queue_redraw()

func _same_cells(next_cells: Array) -> bool:
	if next_cells.size() != cells.size():
		return false
	for index in range(cells.size()):
		if int(next_cells[index]) != cells[index]:
			return false
	return true

func set_animation_active(active: bool) -> void:
	animation_active = active

func get_board_rect() -> Rect2:
	return BOARD_RECT

func cell_at(point: Vector2) -> int:
	if not BOARD_RECT.has_point(point):
		return -1
	var cell_size := BOARD_RECT.size / float(GRID_SIDE)
	var column := int(floor((point.x - BOARD_RECT.position.x) / cell_size.x))
	var row := int(floor((point.y - BOARD_RECT.position.y) / cell_size.y))
	if column < 0 or column >= GRID_SIDE or row < 0 or row >= GRID_SIDE:
		return -1
	return row * GRID_SIDE + column

func design_point_from_local(point: Vector2) -> Vector2:
	var scale_factor := _design_scale()
	var offset := (size - DESIGN_SIZE * scale_factor) * 0.5
	return (point - offset) / scale_factor

func cell_rect(index: int) -> Rect2:
	if index < 0 or index >= GRID_SIDE * GRID_SIDE:
		return Rect2()
	var cell_size := BOARD_RECT.size / float(GRID_SIDE)
	var position := BOARD_RECT.position + Vector2(index % GRID_SIDE, int(index / GRID_SIDE)) * cell_size
	return Rect2(position, cell_size)

func bloom_visible() -> bool:
	return _bloom_visible

func _process(delta: float) -> void:
	if not animation_active or not connected or reduced_motion or flow_progress >= 1.0:
		return
	flow_progress = minf(1.0, flow_progress + maxf(0.0, delta) / FLOW_SECONDS)
	_bloom_visible = flow_progress >= 1.0
	queue_redraw()

func _draw() -> void:
	var scale_factor := _design_scale()
	var offset := (size - DESIGN_SIZE * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	var paper := _paper_color()
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), paper, true)
	_draw_workbench()
	_draw_blueprint_margins(paper)
	_draw_board(paper)
	_draw_flow()
	_draw_bloom()
	draw_set_transform(Vector2.ZERO)

func _draw_workbench() -> void:
	# A quiet joiner's table gives the plan its own harbor-garden identity.
	draw_rect(Rect2(0, 0, 1280, 720), WOOD_DARK, true)
	draw_rect(Rect2(18, 18, 1244, 684), WOOD, true)
	for y in [34.0, 686.0]:
		draw_line(Vector2(28, y), Vector2(1252, y), WOOD_LIGHT, 2.0)
	for x in [34.0, 1246.0]:
		draw_line(Vector2(x, 30), Vector2(x, 690), WOOD_DARK, 1.0)
	# The plan is pinned as one broad sheet; its margins remain open for instructions.
	draw_rect(Rect2(55, 70, 1170, 596), Color("#493a2d"), true)
	draw_rect(Rect2(48, 62, 1170, 596), PAPER_EDGE, true)
	draw_rect(Rect2(56, 70, 1154, 580), _paper_color(), true)
	for x in [66.0, 1200.0]:
		for y in [80.0, 640.0]:
			draw_circle(Vector2(x, y), 4.0, WOOD_DARK)
			draw_circle(Vector2(x - 1.0, y - 1.0), 1.5, WOOD_LIGHT)

func _draw_blueprint_margins(paper: Color) -> void:
	# Separate the order slip and turn tally from the board and all garden beds.
	draw_rect(UI_LABEL_RECT, Color("#f5e9ce"), true)
	draw_rect(UI_LABEL_RECT, WOOD, false, 2.0)
	draw_line(Vector2(108, 191), Vector2(108, 232), TEAL, 4.0)
	draw_string(FontProfiles.current_font(), Vector2(122, 200), "配水工單　%d / %d" % [order_index + 1, order_count], HORIZONTAL_ALIGNMENT_LEFT, 178, 16, INK)
	draw_string(FontProfiles.current_font(), Vector2(122, 227), _compact_brief(), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, TEAL)
	draw_rect(UI_TURN_RECT, Color("#f5e9ce"), true)
	draw_rect(UI_TURN_RECT, WOOD, false, 2.0)
	draw_string(FontProfiles.current_font(), Vector2(1096, 199), "轉動管節", HORIZONTAL_ALIGNMENT_LEFT, 90, 14, INK)
	draw_string(FontProfiles.current_font(), Vector2(1096, 230), "%02d" % move_count, HORIZONTAL_ALIGNMENT_LEFT, 90, 23, OCHRE)
	draw_line(Vector2(96, 673), Vector2(1184, 673), Color(INK, 0.2), 1.0)
	draw_string(FontProfiles.current_font(), Vector2(96, 694), "泉口　・　分流　・　花床", HORIZONTAL_ALIGNMENT_LEFT, 290, 15, Color("#f1dfbb"))
	draw_string(FontProfiles.current_font(), Vector2(1090, 694), "4 × 4 配水盤", HORIZONTAL_ALIGNMENT_LEFT, 115, 14, Color("#f1dfbb"))

func _draw_board(paper: Color) -> void:
	var size_per_cell := BOARD_RECT.size / float(GRID_SIDE)
	# The sheet is a garden-bed plan: raised soil islands, fine survey lines, no repeated park frame.
	draw_rect(BOARD_RECT.grow(18), WOOD_DARK, true)
	draw_rect(BOARD_RECT.grow(13), WOOD_LIGHT, true)
	draw_rect(BOARD_RECT.grow(8), Color("#f5e9ce"), true)
	draw_rect(BOARD_RECT, Color("#d7e3d1"), true)
	for i in range(GRID_SIDE + 1):
		var x := BOARD_RECT.position.x + i * size_per_cell.x
		var y := BOARD_RECT.position.y + i * size_per_cell.y
		draw_line(Vector2(x, BOARD_RECT.position.y), Vector2(x, BOARD_RECT.end.y), Color(TEAL, 0.24), 1.0)
		draw_line(Vector2(BOARD_RECT.position.x, y), Vector2(BOARD_RECT.end.x, y), Color(TEAL, 0.24), 1.0)
	for index in range(GRID_SIDE * GRID_SIDE):
		var rect := cell_rect(index)
		var tile := rect.grow(-5.0)
		var selected := index == cursor
		draw_rect(tile, Color("#f7efda"), true)
		draw_rect(tile, Color(CORAL if selected else OCHRE, 0.9 if selected else 0.48), false, 2.5 if selected else 1.0)
		_draw_pipe(index, tile)
		if selected:
			draw_circle(tile.position + Vector2(12, 12), 8, CORAL)
			draw_string(FontProfiles.current_font(), tile.position + Vector2(9.5, 16), "•", HORIZONTAL_ALIGNMENT_CENTER, 7, 11, paper)
	_draw_source(cell_rect(source_cell), source_port)
	for target_index in range(order_targets.size()):
		var target: Array = order_targets[target_index]
		if target.size() == 2:
			var path := _target_outlet_paths[target_index] if target_index < _target_outlet_paths.size() else PackedVector2Array()
			_draw_outlet(cell_rect(int(target[0])), int(target[1]), path)
			_draw_flower_bed(target)

func _draw_pipe(index: int, tile: Rect2) -> void:
	var mask := cells[index] if index < cells.size() else 0
	var center := tile.get_center()
	var half := tile.size * 0.5
	# Every connector has a visible dark socket and a solid direction, even when color perception is limited.
	for direction in range(4):
		if mask & BITS[direction] == 0:
			continue
		var endpoint := _pipe_endpoint(center, half, direction)
		draw_line(center, endpoint, INK, 18, true)
		draw_line(center, endpoint, Color("#cf9b5c"), 12, true)
		draw_circle(endpoint, 5, INK)
		draw_circle(endpoint, 2, Color("#fff4dc"))
	# A different center mark makes straight, elbow, and branch pieces identifiable without relying on hue.
	var open_sides := _bit_count(mask)
	if open_sides == 2:
		draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), INK, false, 2.0)
	elif open_sides == 3:
		draw_circle(center, 6, INK)
	elif open_sides == 4:
		var north := center + Vector2(0, -8)
		var east := center + Vector2(8, 0)
		var south := center + Vector2(0, 8)
		var west := center + Vector2(-8, 0)
		draw_line(north, east, INK, 2.0)
		draw_line(east, south, INK, 2.0)
		draw_line(south, west, INK, 2.0)
		draw_line(west, north, INK, 2.0)
	else:
		draw_circle(center, 4, Color("#8f795d"))

func _pipe_endpoint(center: Vector2, half: Vector2, direction: int) -> Vector2:
	match direction:
		0: return center + Vector2(0, -half.y + 4)
		1: return center + Vector2(half.x - 4, 0)
		2: return center + Vector2(0, half.y - 4)
		_: return center + Vector2(-half.x + 4, 0)

func _draw_source(source_cell: Rect2, port: int) -> void:
	var point := _edge_point(source_cell, port, 0.0)
	var inlet_color := _phase_accent()
	var normal := _port_normal(port)
	var tangent := Vector2(-normal.y, normal.x)
	var marker_radius := 10.0 if port == 0 else 17.0
	var diamond_center := point + normal * (23.0 if port == 0 else 36.0)
	draw_line(diamond_center - normal * marker_radius, point + normal * 2.0, OCHRE, 6, true)
	var north := diamond_center - normal * marker_radius
	var east := diamond_center + tangent * marker_radius
	var south := diamond_center + normal * marker_radius
	var west := diamond_center - tangent * marker_radius
	draw_line(north, east, INK, 2.0)
	draw_line(east, south, INK, 2.0)
	draw_line(south, west, INK, 2.0)
	draw_line(west, north, INK, 2.0)
	draw_circle(diamond_center, 5, inlet_color)
	draw_string(FontProfiles.current_font(), diamond_center + tangent * 23.0 - normal * 4.0, "泉口", HORIZONTAL_ALIGNMENT_LEFT, 52, 15, INK)

func _draw_outlet(last_cell: Rect2, port: int, path: PackedVector2Array) -> void:
	var point := _edge_point(last_cell, port, 0.0)
	var normal := _port_normal(port)
	var tangent := Vector2(-normal.y, normal.x)
	var trough_center := point + normal * 27.0
	# Northern beds use a continuous exterior copper run rather than hiding under the HUD.
	for segment in range(path.size()-1):
		draw_line(path[segment], path[segment+1], INK, 11, true)
		draw_line(path[segment], path[segment+1], OCHRE, 7, true)
	var trough := Rect2(trough_center - Vector2(20, 8), Vector2(40, 16)) if port == 0 or port == 2 else Rect2(trough_center - Vector2(8, 20), Vector2(16, 40))
	draw_rect(trough, Color("#fff5dd"), true)
	draw_rect(trough, INK, false, 2.0)
	draw_line(trough_center - tangent * 12.0, trough_center + tangent * 12.0, _phase_accent(), 2.0)

func _draw_flower_bed(target: Array) -> void:
	var rect := target_bed_rect(target)
	if rect.size == Vector2.ZERO:
		return
	var bed_center := rect.get_center()
	# Individual cedar planter, dark soil, rim and a visible pair of seedlings.
	draw_rect(rect.grow(4), WOOD_DARK, true)
	draw_rect(rect, WOOD, true)
	draw_rect(rect.grow(-5), Color("#d7ba83"), true)
	draw_rect(rect.grow(-10), SOIL, true)
	var plant_y := rect.position.y + rect.size.y * 0.57
	for offset in [-22.0, 0.0, 22.0]:
		var root := Vector2(bed_center.x + offset, plant_y + 8.0)
		var height := 15.0 + (6.0 if _bloom_visible else 0.0)
		draw_line(root, root + Vector2(0, -height), LEAF, 3.0, true)
		_draw_leaf(root + Vector2(-5, -height * 0.55), Vector2(-10, -5), LEAF_LIGHT)
		_draw_leaf(root + Vector2(5, -height * 0.82), Vector2(10, -6), LEAF)
		if _bloom_visible:
			_draw_flower(root + Vector2(0, -height - 4), 8.5)
		else:
			draw_circle(root + Vector2(0, -height - 2), 3.5, Color("#d7ba83"))
	draw_string(FontProfiles.current_font(), Vector2(rect.position.x + 6.0, rect.position.y + rect.size.y - 4.0), "花床", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12, 11, Color("#fff2d7"))

func target_bed_rect(target: Array) -> Rect2:
	if target.size() != 2:
		return Rect2()
	var cell := int(target[0])
	var port := int(target[1])
	if cell < 0 or cell >= GRID_SIDE * GRID_SIDE or port < 0 or port > 3:
		return Rect2()
	var edge := _edge_point(cell_rect(cell), port, 0.0)
	var normal := _port_normal(port)
	if port == 0:
		return Rect2(Vector2(1002.0, 290.0), FLOWER_SIZE)
	var center := edge + normal * 66.0
	var bed_size := FLOWER_SIZE if port == 0 or port == 2 else Vector2(FLOWER_SIZE.y, FLOWER_SIZE.x)
	return Rect2(center - bed_size * 0.5, bed_size)

func target_outlet_path(target: Array) -> PackedVector2Array:
	var bed := target_bed_rect(target)
	if bed.size == Vector2.ZERO:
		return PackedVector2Array()
	var port := int(target[1])
	var edge := _edge_point(cell_rect(int(target[0])),port,0.0)
	var normal := _port_normal(port)
	var trough := edge + normal * 27.0
	if port == 0:
		# Above the tray but below the header shadow, then down the clear right margin.
		var bend_x := BOARD_RECT.end.x + 30.0
		return PackedVector2Array([edge,trough,Vector2(bend_x,trough.y),Vector2(bend_x,bed.get_center().y),Vector2(bed.position.x,bed.get_center().y)])
	var bed_contact := bed.get_center() - normal * (bed.size.y * 0.5 if port == 2 else bed.size.x * 0.5)
	return PackedVector2Array([edge,trough,bed_contact])

func target_bed_visual_bounds(target: Array) -> Rect2:
	var bed := target_bed_rect(target)
	if bed.size == Vector2.ZERO:
		return Rect2()
	# Rim includes its outer cedar frame and AA; the plate is printed within this rim.
	var bounds := bed.grow(5.0)
	var plant_y := bed.position.y + bed.size.y * 0.57
	for offset in [-22.0,0.0,22.0]:
		var root := Vector2(bed.get_center().x + offset,plant_y+8.0)
		for height in [15.0,21.0]:
			bounds = bounds.merge(Rect2(root-Vector2(2,height+2),Vector2(4,height+4)))
			for point in _leaf_polygon(root+Vector2(-5,-height*0.55),Vector2(-10,-5)):
				bounds = bounds.merge(Rect2(point-Vector2.ONE,Vector2.ONE*2.0))
			for point in _leaf_polygon(root+Vector2(5,-height*0.82),Vector2(10,-6)):
				bounds = bounds.merge(Rect2(point-Vector2.ONE,Vector2.ONE*2.0))
			# Four petals extend 8.5px from the flower center, each with a 5px radius.
			var bloom_center := root + Vector2(0,-height-4)
			bounds = bounds.merge(Rect2(bloom_center-Vector2(15,15),Vector2(30,30)))
	return bounds

func _leaf_polygon(center: Vector2, direction: Vector2) -> PackedVector2Array:
	var axis := direction.normalized()
	var side := Vector2(-axis.y,axis.x)*4.0
	var tip := center+axis*9.0
	return PackedVector2Array([center-side,center+axis*3.0-side*0.7,tip,center+axis*3.0+side*0.7,center+side])

func _draw_leaf(center: Vector2, direction: Vector2, color: Color) -> void:
	draw_colored_polygon(_leaf_polygon(center,direction),color)

func _draw_flow() -> void:
	if connected and not flow_edges.is_empty() and flow_progress > 0.0:
		_draw_branch_flow()
		return
	if not connected or flow_route.size() < 2 or flow_progress <= 0.0:
		return
	var total_length := 0.0
	var segment_count := flow_route.size() + 1
	for segment in range(segment_count):
		total_length += _flow_point(segment).distance_to(_flow_point(segment + 1))
	var remaining := total_length * flow_progress
	for segment in range(segment_count):
		if remaining <= 0.0:
			break
		var start := _flow_point(segment)
		var finish := _flow_point(segment + 1)
		var segment_length := start.distance_to(finish)
		var amount := minf(1.0, remaining / segment_length)
		var segment_end := start.lerp(finish, amount)
		draw_line(start, segment_end, Color("#d7f2e4"), 14.0, true)
		draw_line(start, segment_end, _phase_accent(), 7.0, true)
		draw_circle(segment_end, 4.0, Color("#fff6d7"))
		remaining -= segment_length
	if flow_progress >= 1.0:
		_bloom_visible = true

func _draw_branch_flow() -> void:
	var remaining := _flow_total_length * flow_progress
	for index in range(_flow_starts.size()):
		if remaining <= 0.0:
			break
		var start := _flow_starts[index]
		var finish := _flow_ends[index]
		var length := _flow_lengths[index]
		var amount := minf(1.0, remaining / length) if length > 0.0 else 0.0
		var end_point := start.lerp(finish, amount)
		draw_line(start, end_point, Color("#d7f2e4"), 14.0, true)
		draw_line(start, end_point, _phase_accent(), 7.0, true)
		draw_circle(end_point, 4.0, Color("#fff6d7"))
		remaining -= length
	if flow_progress >= 1.0:
		_bloom_visible = true

func _rebuild_flow_geometry() -> void:
	_target_outlet_paths = []
	_flow_starts = []
	_flow_ends = []
	_flow_lengths = []
	_flow_total_length = 0.0
	if source_cell < 0 or source_cell >= GRID_SIDE * GRID_SIDE:
		return
	var source_outer := _edge_point(cell_rect(source_cell), source_port, 0.0) + _port_normal(source_port) * (23.0 if source_port == 0 else 36.0)
	_append_flow_segment(source_outer, cell_rect(source_cell).get_center())
	for edge in flow_edges:
		if edge.size() == 2:
			_append_flow_segment(cell_rect(int(edge[0])).get_center(), cell_rect(int(edge[1])).get_center())
	for target in order_targets:
		if target is Array and target.size() == 2:
			var cell := int(target[0])
			var port := int(target[1])
			if cell >= 0 and cell < GRID_SIDE * GRID_SIDE:
				var path := target_outlet_path(target)
				_target_outlet_paths.append(path)
				if not path.is_empty():
					_append_flow_segment(cell_rect(cell).get_center(), path[0])
					for segment in range(path.size()-1):
						_append_flow_segment(path[segment],path[segment+1])

func _append_flow_segment(start: Vector2, finish: Vector2) -> void:
	var length := start.distance_to(finish)
	_flow_starts.append(start)
	_flow_ends.append(finish)
	_flow_lengths.append(length)
	_flow_total_length += length

func _port_normal(port: int) -> Vector2:
	return PORT_NORMALS[posmod(port, 4)]

func _edge_point(rect: Rect2, port: int, inset: float) -> Vector2:
	var center := rect.get_center()
	if port == 0:
		return Vector2(center.x, rect.position.y + inset)
	if port == 1:
		return Vector2(rect.end.x - inset, center.y)
	if port == 2:
		return Vector2(center.x, rect.end.y - inset)
	return Vector2(rect.position.x + inset, center.y)

func _flow_point(point_index: int) -> Vector2:
	if point_index == 0:
		return Vector2(cell_rect(flow_route[0]).get_center().x, BOARD_RECT.position.y)
	if point_index == flow_route.size() + 1:
		return Vector2(cell_rect(flow_route[-1]).get_center().x, BOARD_RECT.end.y)
	return cell_rect(flow_route[point_index - 1]).get_center()

func _draw_bloom() -> void:
	if completed_beds > 0:
		draw_string(FontProfiles.current_font(), Vector2(420, 694), completed_order_text(), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("#f1dfbb"))

func completed_order_text() -> String:
	return "已完成 %d 單" % completed_beds

func flower_bed_is_blooming(target: Array) -> bool:
	return _bloom_visible and order_targets.has(target)

func _draw_flower(center: Vector2, petal_radius: float) -> void:
	for petal in range(4):
		var petal_center := center + Vector2.RIGHT.rotated(TAU * petal / 4.0) * petal_radius
		draw_circle(petal_center, 5.0 if petal_radius > 7.0 else 3.5, Color(PETAL if petal % 2 == 0 else "#e6bd69"))
	draw_circle(center, 3.0, Color("#fff0bd"))

func _compact_brief() -> String:
	match order_brief:
		"南側單花床": return "南側單床"
		"東北＋西南雙花床": return "東北＋西南分水"
		"東側＋南側雙花床": return "東側＋南側分水"
		_: return order_brief

func _find_flow_route(source_cells: Array[int]) -> Array[int]:
	if source_cells.size() != GRID_SIDE * GRID_SIDE:
		return []
	var parents: Dictionary = {0: -1}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == 15:
			break
		var x := current % GRID_SIDE
		var y := int(current / GRID_SIDE)
		for direction in range(4):
			if source_cells[current] & BITS[direction] == 0:
				continue
			var nx := x + DIRS[direction].x
			var ny := y + DIRS[direction].y
			if nx < 0 or nx >= GRID_SIDE or ny < 0 or ny >= GRID_SIDE:
				continue
			var neighbor := ny * GRID_SIDE + nx
			var opposite := (direction + 2) % 4
			if source_cells[neighbor] & BITS[opposite] != 0 and not parents.has(neighbor):
				parents[neighbor] = current
				queue.append(neighbor)
	if not parents.has(15) or source_cells[0] & BITS[0] == 0 or source_cells[15] & BITS[2] == 0:
		return []
	var route: Array[int] = []
	var index := 15
	while index != -1:
		route.push_front(index)
		index = int(parents[index])
	return route

func _bit_count(mask: int) -> int:
	var count := 0
	for bit in BITS:
		if mask & bit != 0:
			count += 1
	return count

func _paper_color() -> Color:
	match time_phase:
		"dawn": return Color("#f4ebd6")
		"dusk": return Color("#f3e3d4")
		"night": return Color("#e4e7e4")
		_: return Color("#f7efd9")

func _phase_accent() -> Color:
	match time_phase:
		"dawn": return Color("#b87c4c")
		"dusk": return Color("#c46b61")
		"night": return Color("#537b92")
		_: return WATER

func _design_scale() -> float:
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
