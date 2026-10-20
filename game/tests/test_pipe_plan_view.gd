extends SceneTree

const View = preload("res://game/minigames/pipe_plan_view.gd")
const Model = preload("res://game/minigames/pipe_round_model.gd")
const Session = preload("res://game/minigames/session.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = View.new()
	root.add_child(view)
	await process_frame
	_test_board_mapping(view)
	_test_present_is_immutable(view)
	_test_flow_and_bloom(view)
	_test_cache_and_pause(view)
	_test_multi_target_order(view)
	_test_flower_bed_bounds_and_bloom(view)
	_test_actual_hud_clearance(view)
	_test_session_pause_delivery()
	view.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: pipe plan view checks (%d checks)" % checks)
		quit(0)
	else:
		quit(1)

func _test_board_mapping(view: Control) -> void:
	var rect: Rect2 = view.get_board_rect()
	_expect(view.cell_at(rect.position) == 0, "board top-left maps to inlet tile")
	_expect(view.cell_at(rect.end - Vector2(0.01, 0.01)) == 15, "last point inside board maps to outlet tile")
	_expect(view.cell_at(rect.position - Vector2(0.01, 0.0)) == -1, "point before board is rejected")
	_expect(view.cell_at(rect.end) == -1, "right-bottom border is exclusive")
	_expect(view.cell_at(Vector2(-1, -1)) == -1, "unrelated point is rejected")
	view.custom_minimum_size = Vector2.ZERO
	view.size = Vector2(640, 360)
	var local_center := (rect.position + rect.size / 8.0) * 0.5
	_expect(view.cell_at(view.design_point_from_local(local_center)) == 0, "scaled local pointer maps through design coordinates")

func _test_session_pause_delivery() -> void:
	var session: Control = Session.new()
	root.add_child(session)
	session.start("game-007", false)
	var presentation: Control = session.presentation
	_expect(presentation != null and presentation.animation_active, "live Session starts the water presentation")
	session.set_paused(true)
	_expect(not presentation.animation_active, "pause immediately delivers the paused state to the 2D water animation")
	session._process(0.5)
	_expect(not presentation.animation_active, "paused ticks keep the 2D water animation stopped")
	session.set_paused(false)
	session._process(0.0)
	_expect(presentation.animation_active, "resume restores the live 2D water animation")
	session.queue_free()

func _test_present_is_immutable(view: Control) -> void:
	var cells: Array = [5,3,10,0,3,10,12,0,0,0,5,0,0,0,3,12]
	var before: Array = cells.duplicate(true)
	view.present(cells, 6, 2, false, 0.0, false)
	_expect(cells == before, "present does not mutate caller cells")
	_expect(view.cells == before and view.cursor == 6 and view.move_count == 2, "present copies puzzle state")
	_expect(view.flow_progress == 0.0 and not view.bloom_visible(), "disconnected board has no water payoff")

func _test_flow_and_bloom(view: Control) -> void:
	var solved: Array = [5,3,10,0,3,10,12,0,0,0,5,0,0,0,3,12]
	view.configure(false, "noon")
	view.present(solved, 15, 4, true, 12.0, false)
	_expect(view.flow_route == [0,4,5,6,10,14,15], "connected water follows reciprocal path in order")
	_expect(is_equal_approx(view.flow_progress, 0.0), "normal flow begins at the inlet")
	view._process(0.6)
	_expect(view.flow_progress > 0.0 and view.flow_progress < 1.0, "normal flow animates continuously")
	view.present(solved, 15, 4, true, 12.0, true)
	_expect(view.flow_progress < 1.0, "round end does not skip the visible water payoff")
	view.configure(true, "night")
	_expect(is_equal_approx(view.flow_progress, 1.0) and view.bloom_visible(), "reduced motion shows completed static bloom")
	view.present(solved, 0, 0, false, 0.0, false)
	_expect(is_equal_approx(view.flow_progress, 0.0) and not view.bloom_visible(), "new unconnected puzzle resets payoff")

func _test_cache_and_pause(view: Control) -> void:
	var solved: Array = [5,3,10,0,3,10,12,0,0,0,5,0,0,0,3,12]
	view.configure(false, "noon")
	view.set_animation_active(true)
	view.present(solved, 15, 4, true, 0.0, false)
	view._process(0.25)
	var initial_rebuilds: int = view.route_rebuild_count
	var progress_before_pause: float = view.flow_progress
	view.set_animation_active(false)
	view._process(0.5)
	_expect(is_equal_approx(view.flow_progress, progress_before_pause), "paused gameplay freezes water animation")
	view.set_animation_active(true)
	view.present(solved.duplicate(), 14, 5, true, 0.0, false)
	_expect(view.route_rebuild_count == initial_rebuilds, "cursor and move updates reuse cached route")
	view._process(0.5)
	_expect(view.flow_progress > progress_before_pause, "unpaused gameplay advances flow animation (%f → %f, active=%s, connected=%s, reduced=%s)" % [progress_before_pause, view.flow_progress, str(view.animation_active), str(view.connected), str(view.reduced_motion)])

func _test_multi_target_order(view: Control) -> void:
	var order: Dictionary = Model.DEFAULT_ORDERS[1]
	var model = Model.new()
	model.reset([order, order, order])
	for cell in range(16):
		var rotated := int(model.cells[cell])
		var turns := 0
		while rotated != int(order.solution_cells[cell]) and turns < 4:
			rotated = ((rotated << 1) & 15) | (rotated >> 3)
			turns += 1
		for _turn in range(turns):
			model.rotate(cell)
	view.present_order(model.snapshot(), 4.0, false, "noon")
	_expect(view.order_targets == [[3, 0], [12, 2]], "order presentation keeps both differently placed flower-bed outlets")
	_expect(view.flow_edges.has([0, 1]) and view.flow_edges.has([0, 4]), "order presentation carries both real water branches")
	_expect(view.order_index == 0 and view.order_count == 3 and view.order_brief == "東北＋西南雙花床", "order presentation exposes active contract context")
	var shown_cells: Array = view.cells
	var shown_edges: Array = view.flow_edges
	var shown_targets: Array = view.order_targets
	var shown_starts: Array = view._flow_starts
	var shown_lengths: Array = view._flow_lengths
	var shown_outlets: Array = view._target_outlet_paths
	model.step(0.1)
	var same_state: Dictionary = model.snapshot()
	view.present_order(same_state, float(same_state.elapsed), false, "noon")
	_expect(is_same(view.cells, shown_cells) and is_same(view.flow_edges, shown_edges) and is_same(view.order_targets, shown_targets), "time-only presentation reuses copied board, branch, and target arrays")
	_expect(is_same(view.flow_edges, same_state.flow_edges) and is_same(view.order_targets, same_state.targets), "view holds the model's read-only network and target arrays")
	_expect(is_same(view._flow_starts, shown_starts) and is_same(view._flow_lengths, shown_lengths), "time-only presentation reuses cached flow geometry")
	_expect(is_same(view._target_outlet_paths,shown_outlets), "time-only presentation also reuses the exterior water supply geometry")
	var next_model = Model.new()
	next_model.reset()
	view.present_order(next_model.snapshot(), 0.0, false, "noon")
	var before_rotation: Array = view._flow_starts
	next_model.rotate(1)
	view.present_order(next_model.snapshot(), 0.0, false, "noon")
	_expect(not is_same(view._flow_starts, before_rotation), "network revision rebuilds flow geometry after a board change")

func _test_flower_bed_bounds_and_bloom(view: Control) -> void:
	for order_index in range(Model.DEFAULT_ORDERS.size()):
		var order: Dictionary = Model.DEFAULT_ORDERS[order_index]
		for target in order.targets:
			var bed: Rect2 = view.target_bed_rect(target)
			_expect(bed.size.x >= 64.0 and bed.size.y >= 64.0, "target %s receives a readable planter footprint" % str(target))
			_expect(not bed.intersects(view.get_board_rect().grow(18.0)), "target planter %s stays outside the pipe tray" % str(target))
			_expect(not bed.intersects(view.UI_LABEL_RECT) and not bed.intersects(view.UI_TURN_RECT), "target planter %s does not cover order or turn labels" % str(target))
	var split: Dictionary = Model.DEFAULT_ORDERS[1]
	var model = Model.new()
	model.reset([split, split, split])
	_solve_active_order(model, split)
	var solved: Dictionary = model.snapshot()
	view.present_order(solved, float(solved.elapsed), true, "noon")
	_expect(view.bloom_visible(), "reduced motion preserves immediate completed-water feedback")
	for target in split.targets:
		_expect(view.flower_bed_is_blooming(target), "every successfully watered target displays its flower")
	_expect(not view.flower_bed_is_blooming([15, 2]), "a flower outside the active order is never fabricated")

func _test_actual_hud_clearance(view: Control) -> void:
	var actual_header_with_shadow := Rect2(34,18,1212,112)
	var canvas := Rect2(Vector2.ZERO,Vector2(1280,720))
	_expect(not actual_header_with_shadow.intersects(view.target_bed_rect([3,0]).grow(5)), "north planter frame clears the actual HUD, not only local side labels")
	for order: Dictionary in Model.DEFAULT_ORDERS:
		for target: Array in order.targets:
			var visual: Rect2 = view.target_bed_visual_bounds(target)
			_expect(canvas.encloses(visual), "complete flower, planter, and plate %s remain within the design canvas" % str(target))
			_expect(not actual_header_with_shadow.intersects(visual), "complete target %s clears the actual HUD and shadow to y130" % str(target))
			_expect(not visual.intersects(view.get_board_rect().grow(18.0)), "complete target %s clears the tray including its frame" % str(target))
			_expect(not visual.intersects(view.UI_LABEL_RECT.grow(2)) and not visual.intersects(view.UI_TURN_RECT.grow(2)), "complete target %s clears both printed work labels" % str(target))
			var path: PackedVector2Array = view.target_outlet_path(target)
			for index in range(path.size()-1):
				var line_bounds := Rect2(path[index],Vector2.ZERO).expand(path[index+1]).grow(8.0)
				_expect(canvas.encloses(line_bounds) and not line_bounds.intersects(actual_header_with_shadow), "target %s supply segment %d clears canvas and actual HUD" % [str(target),index])
				if index > 0:
					_expect(not line_bounds.intersects(view.get_board_rect().grow(18)), "exterior target %s water segment %d clears the framed tray" % [str(target),index])
				_expect(not line_bounds.intersects(view.UI_LABEL_RECT.grow(2)) and not line_bounds.intersects(view.UI_TURN_RECT.grow(2)), "target %s supply segment %d avoids printed labels" % [str(target),index])
	var north: Rect2 = view.target_bed_rect([3,0])
	_expect(north.position.x > view.get_board_rect().end.x + 18 and north.position.y > 260, "northern outlet has a full-size, readable planting box in the right margin")
	_expect(view.get_board_rect() == Rect2(320,166,640,400), "fix preserves the native click board coordinates")
	var finished_model = Model.new()
	finished_model.reset()
	var total_targets := 0
	for order: Dictionary in Model.DEFAULT_ORDERS:
		total_targets += order.targets.size()
		_solve_active_order(finished_model,order)
		finished_model.step(Model.FLOW_SECONDS + 0.01)
	view.present_order(finished_model.snapshot(),finished_model.elapsed,true,"noon")
	_expect(total_targets == 5 and view.completed_beds == 3 and finished_model.success, "real three-order completion waters five targets while counting three completed orders")
	_expect(view.completed_order_text() == "已完成 3 單", "footer describes three finished orders rather than five planted beds")

func _solve_active_order(model, order: Dictionary) -> void:
	for cell in range(16):
		var rotated := int(model.cells[cell])
		var turns := 0
		while rotated != int(order.solution_cells[cell]) and turns < 4:
			rotated = ((rotated << 1) & 15) | (rotated >> 3)
			turns += 1
		for _turn in range(turns):
			model.rotate(cell)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error("Pipe plan view check failed: " + message)
