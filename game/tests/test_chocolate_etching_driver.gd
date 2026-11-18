extends SceneTree

const DRIVER_PATH := "res://game/minigames/chocolate_etching_driver.gd"
const VIEW_PATH := "res://game/minigames/chocolate_etching_view.gd"
const Geometry = preload("res://game/minigames/chocolate_etching_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(DRIVER_PATH):
		print("FAIL: missing Chocolate Etching Driver at ", DRIVER_PATH)
		quit(1)
		return
	for source: String in ["keyboard", "pointer", "touch"]:
		for variant in 2:
			for assisted: bool in [false, true]:
				for idler: bool in [false, true]:
					var route := Route.new(source, assisted, variant)
					var outcome := route.solve(idler)
					var expected := 500 if idler else 400
					var topology := [Vector2i(0, 1), Vector2i(1, 3), Vector2i(2, 3)] if idler else [Vector2i(0, 1), Vector2i(1, 2)]
					check(outcome.ended and outcome.success and outcome.score == expected and outcome.devil == idler
						and outcome.ordinary_eligible and outcome.output_travel >= TAU - 1.0e-8
						and outcome.connections == topology and route.driver.score_summary(false).total == expected,
						"%s %s assisted=%s idler=%s reaches %d" % [source, "AB"[variant], assisted, idler, expected])
					if source == "keyboard" and variant == 0 and not assisted and not idler:
						check(outcome.held_commands.is_empty() and outcome == route.driver.snapshot(),
							"terminal step while holding Space agrees with the settled snapshot")
					if outcome.success:
						print("ROUTE ", JSON.stringify(route.result(outcome)))
					else:
						print("ROUTE REJECTED ", JSON.stringify(route.diagnostic(outcome)))
	_check_boundaries()
	_check_mouse_cancellation()
	_check_shaft_isolation()
	_check_leftover_margin()
	print("Chocolate etching driver: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

# The native fixture supplies a dispatcher that parses into the focused Control.
# The same route uses actual Godot event objects at the Driver boundary in headless tests.
class Route:
	const KEY_FOR := {
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"select": KEY_TAB, "shallow": KEY_Q, "deep": KEY_E, "tool": KEY_SPACE,
		"fold": KEY_F, "phase": KEY_M, "undo": KEY_X, "helper": KEY_R
	}
	var driver
	var view: Script = load(VIEW_PATH)
	var source: String
	var assisted: bool
	var variant: int
	var dispatch: Callable
	var raw: Vector2
	var route_name: String
	var cut_shapes: Array = []
	var placement_centers: Array = []
	var drive_angles: Array = []
	var _assist_guides: Array = []
	var _prefer_merged_samples := false
	var _avoid_short_samples := false

	func _init(input_source: String, assist: bool, board_variant: int, existing = null, parsed := Callable()) -> void:
		source = input_source
		assisted = assist
		variant = board_variant
		driver = existing if existing != null else load(DRIVER_PATH).new()
		dispatch = parsed if parsed.is_valid() else driver.handle_input
		if existing == null:
			driver.reset(assisted, "noon")
			if variant == 1:
				driver.reset(assisted, "noon")
		raw = driver.snapshot().cursor
		route_name = "%s-%s-%s" % [source, "AB"[variant], "assist" if assisted else "normal"]

	func key(code: Key, pressed: bool, echo := false) -> bool:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.echo = echo
		return dispatch.call(event, Vector2.ZERO)

	func pointer(point: Vector2, pressed: bool, finger := -1, canceled := false, emulated := false) -> bool:
		if finger >= 0:
			var event := InputEventScreenTouch.new()
			event.index = finger
			event.pressed = pressed
			event.canceled = canceled
			return dispatch.call(event, point)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.canceled = canceled
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
		return dispatch.call(event, point)

	func motion(point: Vector2, finger := -1) -> bool:
		if finger >= 0:
			var event := InputEventScreenDrag.new()
			event.index = finger
			return dispatch.call(event, point)
		var event := InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		return dispatch.call(event, point)

	func finger() -> int:
		return 1 if source == "touch" else -1

	func command(name: String, pressed: bool) -> void:
		if source == "keyboard":
			key(KEY_FOR[name], pressed)
		else:
			pointer(view.command_center(name), pressed, finger())

	func tap(name: String) -> void:
		command(name, true)
		command(name, false)
		if name in ["select", "shallow", "deep", "fold", "phase", "undo"]:
			raw = driver.snapshot().cursor

	func select(index: int) -> void:
		for _i in posmod(index - driver.snapshot().selected, 4):
			tap("select")

	func advance(duration: float) -> void:
		while duration > 1.0e-8:
			var step_size := minf(duration, 0.25)
			driver.step(step_size)
			duration -= step_size

	func _nudge(approach: Vector2) -> void:
		if approach.length_squared() < 0.000001:
			return
		var keys: Array[Key] = []
		var direction := Vector2.ZERO
		if absf(approach.x) > 0.0001:
			direction.x = signf(approach.x)
			keys.append(KEY_D if approach.x > 0 else KEY_A)
		if absf(approach.y) > 0.0001:
			direction.y = signf(approach.y)
			keys.append(KEY_S if approach.y > 0 else KEY_W)
		for code in keys:
			key(code, true)
		var duration := approach.length() / 120.0
		direction = direction.limit_length()
		while duration > 1.0e-8:
			if not _assist_guides.is_empty() and _prefer_merged_samples:
				var guided_step := _choose_assisted_step(minf(duration, 1.0 / 120.0), direction)
				if guided_step == 0.0:
					break
				driver.step(guided_step)
				raw += direction * 120.0 * guided_step
				duration -= guided_step
				continue
			var step_size := minf(duration, 0.25)
			driver.step(step_size)
			var substeps := ceili(step_size / (1.0 / 120.0))
			for _i in substeps:
				raw += direction * 120.0 * (step_size / substeps)
			duration -= step_size
		for code in keys:
			key(code, false)

	func go(target: Vector2) -> void:
		var delta := target - raw
		var minor := minf(absf(delta.x), absf(delta.y))
		_nudge(delta.sign() * minor)
		var residual := target - raw
		_nudge(Vector2(residual.x, 0) if absf(delta.x) >= absf(delta.y) else Vector2(0, residual.y))

	func _keyboard_contour(points: PackedVector2Array) -> PackedVector2Array:
		const GRID := 2.5
		var lattice := PackedVector2Array()
		var visited := {}
		var shift := Vector2.ONE * (0.5 if variant == 1 else 0.0)
		for i in points.size():
			var a := (points[i] / GRID - shift).round()
			var b := (points[(i + 1) % points.size()] / GRID - shift).round()
			var extent := (b - a).abs()
			var count := int(maxf(extent.x, extent.y))
			for j in count:
				var p := a.lerp(b, float(j) / count).round()
				if visited.has(p):
					if p == lattice[0]:
						continue
					while lattice.size() > int(visited[p]) + 1:
						visited.erase(lattice[-1])
						lattice.remove_at(lattice.size() - 1)
				else:
					visited[p] = lattice.size()
					lattice.append(p)
		var path := PackedVector2Array([(lattice[0] + shift) * GRID])
		for i in range(1, lattice.size() - 1):
			if lattice[i] - lattice[i - 1] != lattice[i + 1] - lattice[i]:
				path.append((lattice[i] + shift) * GRID)
		path.append((lattice[-1] + shift) * GRID)
		if path[0].distance_to(path[-1]) > 3.7:
			path.append(path[-1].lerp(path[0], 0.5))
		return path

	func trace(points: PackedVector2Array, closed := true) -> void:
		if source == "keyboard":
			if assisted and closed:
				_trace_assisted(points)
				return
			var path := _keyboard_contour(points) if closed else points
			go(path[0])
			command("tool", true)
			for i in range(1, path.size()):
				_nudge(path[i] - path[i - 1])
			command("tool", false)
		else:
			var start: Vector2 = view.board_to_design(points[0])
			pointer(start, true, finger())
			for i in range(1, points.size()):
				motion(view.board_to_design(points[i]), finger())
			pointer(start if closed else view.board_to_design(points[-1]), false, finger())

	func _trace_assisted(points: PackedVector2Array) -> void:
		var guides: Array = driver.snapshot().selected_guides
		go(points[0])
		command("tool", true)
		_assist_guides = guides
		for i in points.size():
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			var end := a.move_toward(b, maxf(0, a.distance_to(b) - 1.5)) if i == points.size() - 1 else b
			var steps := maxi(1, ceili(a.distance_to(end) / 4.0))
			for j in range(1, steps + 1):
				_assisted_step(a.lerp(end, float(j) / steps), a, b, guides)
		_assist_guides = []
		command("tool", false)

	func _choose_assisted_step(maximum: float, direction: Vector2) -> float:
		var stroke: PackedVector2Array = driver.snapshot().current_stroke
		if stroke.is_empty():
			return maximum
		var previous := stroke[-1] - stroke[-2] if stroke.size() >= 2 else Vector2.ZERO
		var favor_merge := previous != Vector2.ZERO and previous.length() < 3.0
		# Select legal held-key timings whose visible samples stay on the same line.
		# This keeps the trace under the fixed input cap without dropping a turn.
		var fallback := 0.0
		for i in 24:
			var candidate := maximum * (1.0 - float(i) / 32.0)
			var next := _snap_guess(raw + direction * 120.0 * candidate, _assist_guides) - stroke[-1]
			if _avoid_short_samples and next != Vector2.ZERO and next.length_squared() < 0.000025:
				continue
			if fallback == 0.0:
				fallback = candidate
			if not favor_merge or next == Vector2.ZERO or (previous.dot(next) > 0 and absf(previous.cross(next)) <= 0.00001):
				return candidate
		return fallback

	func _assisted_step(target: Vector2, a: Vector2, b: Vector2, guides: Array, splits := 2) -> void:
		var delta := target - raw
		var diagonal := delta.sign() * minf(absf(delta.x), absf(delta.y))
		var straight := delta - diagonal
		var options := [[diagonal, straight], [straight, diagonal], [straight * 0.5, diagonal, straight * 0.5], [diagonal * 0.5, straight, diagonal * 0.5]]
		var best: Array = options[0]
		var best_cost := INF
		var axis := (b - a).normalized()
		for path: Array in options:
			var anchor := raw
			var previous := _snap_guess(anchor, guides)
			var cost := 0.0
			for leg: Vector2 in path:
				if leg.length_squared() < 0.000001:
					continue
				var count := ceili(leg.length() / 120.0 / (1.0 / 120.0))
				for _i in count:
					anchor += leg / count
					var snapped := _snap_guess(anchor, guides)
					var jump := snapped - previous
					cost += snapped.distance_to(Geometry2D.get_closest_point_to_segment(snapped, a, b))
					cost += maxf(0.0, -jump.dot(axis)) * 4.0
					if jump.length_squared() > 0 and jump.length_squared() < 0.0001:
						cost += 1.0
					previous = snapped
			if cost < best_cost:
				best = path
				best_cost = cost
		if best_cost > 0.005 and splits > 0 and delta.length() > 0.25:
			_assisted_step(raw.lerp(target, 0.5), a, b, guides, splits - 1)
			_assisted_step(target, a, b, guides, splits - 1)
		else:
			for leg in best:
				_nudge(leg)

	func _snap_guess(point: Vector2, guides: Array) -> Vector2:
		var nearest := point
		var distance := 10.0
		for guide: PackedVector2Array in guides:
			for i in guide.size():
				var projected := Geometry2D.get_closest_point_to_segment(point, guide[i], guide[(i + 1) % guide.size()])
				var d := point.distance_to(projected)
				if d < distance:
					nearest = projected
					distance = d
		return nearest

	func cut(index: int) -> bool:
		select(index)
		var state: Dictionary = driver.snapshot()
		var points: PackedVector2Array = state.selected_guides[0]
		if points.is_empty():
			return false
		var count := ceili((0.75 if assisted else 0.85) / float(state.depth))
		for _i in count:
			trace(points)
		tap("fold")
		state = driver.snapshot()
		if state.parts[index].freed:
			cut_shapes.append({"gear": index, "teeth": state.parts[index].teeth,
				"points": state.parts[index].outline.size(), "radius": state.parts[index].pitch_radius,
				"strokes": state.selected_strokes.map(func(s): return s.points.size())})
		return state.parts[index].freed

	func place(index: int, center: Vector2) -> void:
		select(index)
		if source == "keyboard":
			go(center)
			tap("fold")
		else:
			var from: Vector2 = view.board_to_design(driver.snapshot().cursor)
			var target: Vector2 = view.board_to_design(center)
			pointer(from, true, finger())
			motion(target, finger())
			pointer(target, false, finger())

	func arrange(idler: bool) -> void:
		tap("phase")
		var state: Dictionary = driver.snapshot()
		var pin_in: Vector2 = state.pins[0]
		var pin_out: Vector2 = state.pins[1]
		var r: Array = state.parts.map(func(p): return p.pitch_radius)
		var middle := Vector2((pin_in.x + pin_out.x + r[0] - r[2]) * 0.5, pin_in.y)
		var idler_center := Vector2.ZERO
		if idler:
			middle = pin_in + Vector2.from_angle(-PI / 6.0) * (r[0] + r[1])
			var to_out := pin_out - middle
			var distance := to_out.length()
			var a: float = r[1] + r[3]
			var b: float = r[2] + r[3]
			var x := (a * a - b * b + distance * distance) / (2.0 * distance)
			var axis := to_out / distance
			idler_center = middle + axis * x + Vector2(axis.y, -axis.x) * sqrt(maxf(0.0, a * a - x * x))
		place(0, pin_in)
		place(1, middle)
		place(2, pin_out)
		if idler:
			place(3, idler_center)
		placement_centers = driver.snapshot().parts.map(func(p): return p.position if p.mounted else null)

	func craft(idler: bool) -> bool:
		if source == "keyboard":
			tap("shallow")
		for i in (4 if idler else 3):
			# Longer outlines and the coarser float spacing at the rightmost wheel need more deliberate key timing.
			_prefer_merged_samples = assisted and (i == 2 or variant == 0 and i == 1)
			_avoid_short_samples = i == 2
			if not cut(i):
				return false
		return true

	func solve(idler: bool) -> Dictionary:
		if not craft(idler):
			return driver.snapshot()
		arrange(idler)
		command("tool", true)
		advance(0.75)
		var state: Dictionary = driver.snapshot()
		drive_angles = state.parts.map(func(p): return p.angle)
		for _i in 18:
			if state.ended:
				break
			state = driver.step(0.25)
		command("tool", false)
		return state if state.ended else driver.snapshot()

	func result(state: Dictionary) -> Dictionary:
		var positions := placement_centers.map(func(p): return [p.x, p.y] if p != null else null)
		var contacts: Array = state.connections.map(func(pair): return [pair.x, pair.y])
		return {"route": route_name, "success": state.success, "idler": state.devil, "ordinary_eligible": state.ordinary_eligible,
			"score": state.score, "elapsed": state.elapsed, "travel": state.output_travel, "contacts": contacts,
			"positions": positions, "cut_shapes": cut_shapes, "drive_angles_at_075": drive_angles}

	func diagnostic(state: Dictionary) -> Dictionary:
		var lengths: Array = []
		for stroke in state.selected_strokes:
			var poly: PackedVector2Array = stroke.points
			lengths.append([poly.size(), poly[0].distance_to(poly[-1]), Geometry.simple(poly.slice(0, poly.size() - 1))])
		return {"route": route_name, "selected": state.selected, "depth": state.depth, "strokes": lengths,
			"elapsed": state.elapsed, "feedback": state.feedback, "assembled": state.phase == "assembly",
			"contacts": state.connections, "cut_shapes": cut_shapes, "positions": placement_centers}

func _check_boundaries() -> void:
	var keyboard := Route.new("keyboard", false, 0)
	var driver = keyboard.driver
	var initial: Vector2 = driver.snapshot().cursor
	keyboard.key(KEY_W, true)
	keyboard.key(KEY_UP, true)
	keyboard.advance(0.1)
	check(driver.snapshot().cursor.distance_to(initial + Vector2(0, -12)) < 0.001, "W and Up share one direction at 120 units per second")
	keyboard.key(KEY_W, false)
	keyboard.advance(0.1)
	var still_moving: Vector2 = driver.snapshot().cursor
	check(still_moving.distance_to(initial + Vector2(0, -24)) < 0.001, "releasing W leaves held Up in effect")
	keyboard.key(KEY_S, true)
	keyboard.advance(0.1)
	check(driver.snapshot().cursor == still_moving, "opposite held directions cancel")
	keyboard.key(KEY_S, false)
	keyboard.advance(0.1)
	check(driver.snapshot().cursor.distance_to(still_moving + Vector2(0, -12)) < 0.001, "releasing opposite direction restores held Up")
	keyboard.key(KEY_UP, false)
	for _i in 3:
		keyboard.tap("shallow")
	check(driver.snapshot().depth == 0.25, "Q clamps at quarter depth")
	for _i in 4:
		keyboard.tap("deep")
	check(driver.snapshot().depth == 1.0, "E clamps at full depth")
	check(not keyboard.key(KEY_TAB, true, true) and driver.snapshot().selected == 0, "echo Tab neither claims nor selects")
	keyboard.command("tool", true)
	keyboard.key(KEY_D, true)
	keyboard.advance(0.1)
	check(driver.snapshot().cutting, "held key and Space compose into a live trace")
	keyboard.tap("shallow")
	keyboard.key(KEY_D, false)
	keyboard.command("tool", false)
	check(not driver.snapshot().cutting and driver.snapshot().depth == 0.75 and driver.snapshot().selected_strokes.is_empty(), "depth change cancels live stroke before matched key release")
	keyboard.command("tool", true)
	keyboard.tap("select")
	keyboard.command("tool", false)
	check(driver.snapshot().selected == 1 and driver.snapshot().undo_available == 0, "selection cancels uncommitted stroke")
	keyboard.command("tool", true)
	keyboard.tap("phase")
	keyboard.command("tool", false)
	check(driver.snapshot().phase == "assembly" and not driver.snapshot().driving and not driver.snapshot().cutting, "workspace change cancels active craft input")
	keyboard.command("tool", true)
	driver.clear_input()
	check(not driver.snapshot().driving and driver.snapshot().held_commands.is_empty(), "pause adapter clears all held input")
	keyboard.key(KEY_A, true)
	driver.reset(true, "dusk")
	var reset_state: Dictionary = driver.snapshot()
	keyboard.advance(0.2)
	check(reset_state.variant == 1 and reset_state.assisted and driver.snapshot().cursor == reset_state.cursor, "retry alternates board and clears held movement")

	var pointer := Route.new("pointer", false, 0)
	driver = pointer.driver
	var first: Vector2 = pointer.view.board_to_design(Vector2(100, 100))
	var second: Vector2 = pointer.view.board_to_design(Vector2(130, 100))
	var outside := Vector2(100, 220)
	check(not pointer.pointer(Vector2(NAN, INF), true) and not pointer.pointer(first, true, -1, false, true), "nonfinite press and emulated mouse are ignored")
	check(pointer.pointer(first, true, 3) and driver.snapshot().cutting, "actual touch index owns an active stroke")
	check(not pointer.pointer(second, true, 4) and not pointer.motion(second, 4) and not pointer.pointer(second, false, 4), "second touch cannot move or finalize the first")
	check(not pointer.pointer(second, false) and driver.snapshot().cutting, "non-owner mouse release leaves first touch live")
	check(not pointer.pointer(second, false, -1, true) and driver.snapshot().cutting, "canceled non-owner mouse release leaves first touch live")
	pointer.key(KEY_TAB, true)
	pointer.key(KEY_TAB, false)
	check(driver.snapshot().selected == 0 and driver.snapshot().cutting, "competing keyboard cannot alter touch-owned preview")
	pointer.motion(second, 3)
	pointer.pointer(second, false, 3, true)
	check(driver.snapshot().selected_strokes.is_empty() and not driver.snapshot().cutting, "matched touch cancel rolls back preview")
	pointer.pointer(first, true)
	pointer.motion(second)
	pointer.pointer(outside, false)
	check(driver.snapshot().selected_strokes.is_empty(), "matched outside mouse release does not commit")
	pointer.pointer(first, true)
	pointer.motion(Vector2(INF, NAN))
	pointer.pointer(second, false)
	check(driver.snapshot().selected_strokes.is_empty(), "nonfinite active drag cannot commit")
	pointer.key(KEY_D, true)
	check(not pointer.pointer(first, true), "pointer cannot take over a held keyboard direction")
	pointer.key(KEY_D, false)
	pointer.pointer(first, true)
	pointer.pointer(first, false)
	check(not driver.snapshot().participated, "stationary click is not participation")
	var line := PackedVector2Array([Vector2(100, 100), Vector2(130, 100)])
	for i in 9:
		pointer.select(i % 4)
		pointer.trace(line, false)
	pointer.advance(0.3)
	var before: Dictionary = driver.snapshot()
	check(before.undo_available == 8 and before.participated, "nine real strokes retain eight undo entries")
	for _i in 9:
		pointer.tap("undo")
	pointer.select(0)
	var after: Dictionary = driver.snapshot()
	check(after.undo_available == 0 and after.selected_strokes.size() == 1 and after.elapsed == before.elapsed
		and after.participated and after.mistakes == before.mistakes + 8, "ninth undo preserves oldest stroke, time and participation")
	pointer.tap("helper")
	after = driver.snapshot()
	check(after.helper and after.helper_clamp != null and after.selected_strokes.size() == 1, "AI second clamp adds no stroke")
	var assisted := Route.new("touch", true, 0)
	assisted.trace(line, false)
	assisted.tap("undo")
	check(assisted.driver.snapshot().mistakes == 0 and assisted.driver.snapshot().selected_strokes.is_empty(), "assisted undo is free and restores real touch stroke")
	pointer.select(1)
	for _i in 8:
		pointer.trace(line, false)
	pointer.trace(line, false)
	after = driver.snapshot()
	check(after.selected_strokes.size() == 8 and after.feedback.contains("最多8筆"), "ninth real same-wheel stroke is explicitly refused")
	pointer.select(2)
	pointer.pointer(first, true)
	for i in 520:
		pointer.motion(second if i % 2 == 0 else first)
	pointer.pointer(first, false)
	after = driver.snapshot()
	check(after.selected_strokes.is_empty() and after.feedback.contains("512點"), "point capacity refuses a partial stroke")
	check(driver.score_summary(true).qualification_text.contains("練習") and driver.score_summary(false).rows.size() == 4, "score summary exposes four rules and practice eligibility")
	print("DRIVER_BOUNDARIES aliases/opposites, depth/selection/phase, pointer owner/cancel, retry, capacity and undo")

func _check_mouse_cancellation() -> void:
	var route := Route.new("pointer", false, 0)
	var driver = route.driver
	var start: Vector2 = route.view.board_to_design(Vector2(100, 100))
	var finish: Vector2 = route.view.board_to_design(Vector2(130, 100))
	route.pointer(start, true)
	route.motion(finish)
	var live: Dictionary = driver.snapshot()
	check(live.cutting and live.current_stroke.size() >= 2 and live.current_stroke[0].distance_to(live.current_stroke[-1]) > 8.0
		and live.undo_available == 0 and not live.participated, "mouse cancellation trial starts from traveled, uncommitted heat")
	check(not route.pointer(finish, false, 4, true) and driver.snapshot() == live, "wrong-owner touch cancellation leaves mouse heat preview live")
	check(route.pointer(finish, false, -1, true), "matching canceled mouse cut is consumed")
	var canceled_cut: Dictionary = driver.snapshot()
	check(not canceled_cut.cutting and canceled_cut.current_stroke.is_empty() and canceled_cut.held_commands.is_empty()
		and canceled_cut.selected_strokes.is_empty() and canceled_cut.undo_available == live.undo_available
		and canceled_cut.participated == live.participated, "canceled interior mouse cut adds no stroke, undo or participation")
	check(not route.pointer(finish, false) and driver.snapshot() == canceled_cut, "delayed genuine mouse release leaves canceled cut discarded")
	print("CANCELED_MOUSE_CUT ", JSON.stringify({"preview_distance": live.current_stroke[0].distance_to(live.current_stroke[-1]),
		"strokes": canceled_cut.selected_strokes.size(), "undo": canceled_cut.undo_available, "participated": canceled_cut.participated}))

	route = Route.new("pointer", false, 0)
	driver = route.driver
	if not route.cut(0):
		check(false, "canceled assembly drop setup must extract a real wheel")
		return
	route.tap("phase")
	route.place(0, driver.snapshot().pins[0])
	var mounted: Dictionary = driver.snapshot()
	var old_position: Vector2 = mounted.parts[0].position
	var drag_target := old_position + Vector2(48, 36)
	start = route.view.board_to_design(old_position)
	finish = route.view.board_to_design(drag_target)
	route.pointer(start, true)
	route.motion(finish)
	live = driver.snapshot()
	check(mounted.parts[0].mounted and live.parts[0].position == old_position and live.cursor.distance_to(drag_target) < 0.001
		and live.undo_available == mounted.undo_available, "mouse cancellation trial drags a real mounted wheel preview inside the board")
	check(route.pointer(finish, false, -1, true), "matching canceled mouse drop is consumed")
	var canceled_drop: Dictionary = driver.snapshot()
	check(canceled_drop.parts[0].mounted and canceled_drop.parts[0].position == old_position
		and canceled_drop.undo_available == mounted.undo_available and canceled_drop.participated == mounted.participated
		and canceled_drop.selected_strokes == mounted.selected_strokes and canceled_drop.held_commands.is_empty(),
		"canceled interior mouse drop preserves mount, history and participation")
	check(not route.pointer(finish, false) and driver.snapshot() == canceled_drop, "delayed genuine mouse release leaves canceled drop discarded")
	print("CANCELED_MOUSE_DROP ", JSON.stringify({"original": [old_position.x, old_position.y],
		"target": [drag_target.x, drag_target.y], "after": [canceled_drop.parts[0].position.x, canceled_drop.parts[0].position.y],
		"mounted": canceled_drop.parts[0].mounted, "undo_before": mounted.undo_available, "undo_after": canceled_drop.undo_available}))

func _check_shaft_isolation() -> void:
	var route := Route.new("pointer", false, 0)
	if not route.craft(false):
		check(false, "shaft isolation setup must actually cut three wheels")
		return
	route.arrange(false)
	route.command("tool", true)
	route.advance(0.25)
	check(route.driver.snapshot().output_travel > 0.0, "control graph transmits before shaft-isolation mutations")
	route.command("tool", false)
	var connected: Dictionary = route.driver.snapshot()
	for pivot_index in [0, 2]:
		var pivot: Vector2 = connected.parts[pivot_index].position
		for i in 3:
			if i != pivot_index:
				var original: Vector2 = connected.parts[i].position
				route.place(i, pivot + (original - pivot).rotated(0.18))
		var incomplete: Dictionary = route.driver.snapshot()
		var moving_pin: Vector2 = connected.parts[2 - pivot_index].position
		check(incomplete.parts[pivot_index].position.distance_to(pivot) < 0.001 and incomplete.parts[2 - pivot_index].position.distance_to(moving_pin) > 3.0
			and incomplete.connections == connected.connections, "rigid turn about shaft %d keeps both contacts and isolates the other shaft" % pivot_index)
		route.command("tool", true)
		route.advance(0.25)
		route.command("tool", false)
		var result: Dictionary = route.driver.snapshot()
		check(result.output_travel == 0.0 and result.mistakes == incomplete.mistakes + 1, "missing shaft %d alone vetoes contact traversal" % (2 - pivot_index))
		print("SHAFT_ISOLATION ", JSON.stringify({"pivot": pivot_index, "missing": 2 - pivot_index, "contacts": result.connections.map(func(p): return [p.x, p.y]), "travel": result.output_travel}))
		for i in 3:
			if i != pivot_index:
				route.place(i, connected.parts[i].position)

func _check_leftover_margin() -> void:
	var route := Route.new("pointer", false, 0)
	var footprints: Array[PackedVector2Array] = []
	var retained := PackedVector2Array()
	for i in 4:
		route.select(i)
		var selected: Dictionary = route.driver.snapshot()
		var outline: PackedVector2Array = selected.selected_guides[0]
		var p: Vector2 = selected.parts[i].source_center
		var half_width: float = 1.0 + 3.0 * selected.depth * selected.depth
		footprints.append(Geometry.offset(outline, half_width, p))
		if i == 3:
			retained = Geometry.offset(outline, -half_width, p)
	var removal := footprints[3]
	var intrusion := PackedVector2Array()
	for i in removal.size():
		var a := removal[i]
		var b := removal[(i + 1) % removal.size()]
		var midpoint := a.lerp(b, 0.5)
		var direction := (b - a).normalized() * minf(4.0, a.distance_to(b) * 0.25)
		var line := PackedVector2Array([midpoint - direction, midpoint + direction])
		if Geometry.kerf_intrudes(line, 1.75, removal) and not Geometry.kerf_intrudes(line, 1.75, retained):
			var main_clear := true
			for j in 3:
				main_clear = main_clear and not Geometry.kerf_intrudes(line, 1.75, footprints[j])
			if main_clear:
				intrusion = line
				break
	if intrusion.is_empty():
		check(false, "no proven fourth removal-only kerf band could be constructed")
		return
	route.select(0)
	route.trace(intrusion, false)
	var owner: Dictionary = route.driver.snapshot()
	var committed: Dictionary = owner.selected_strokes[0]
	check(Geometry.kerf_intrudes(committed.points, committed.width / 2.0, removal)
		and not Geometry.kerf_intrudes(committed.points, committed.width / 2.0, retained), "actual other-piece kerf intersects removal margin and clears retained idler")
	if not route.craft(false):
		check(false, "margin case must still cut all three main wheels")
		return
	var main_clear := true
	for i in 3:
		var footprint: PackedVector2Array = route.driver.snapshot().parts[i].removed_outline
		main_clear = main_clear and not Geometry.kerf_intrudes(committed.points, committed.width / 2.0, footprint)
		main_clear = main_clear and not Geometry.overlaps(removal, footprint)
	check(main_clear, "actual removals and actual other-piece kerf stay disjoint from each other and prospective idler removal")
	check(not route.cut(3) and route.driver.snapshot().feedback.contains("惰輪耗料範圍碰到其他片的舊切縫"), "actual fourth fold specifically refuses other-piece kerf in removal-only band")
	print("LEFTOVER_MARGIN ", JSON.stringify({"owner": 0, "line": Array(committed.points).map(func(p): return [p.x, p.y]),
		"half_width": committed.width / 2.0, "retained": retained.size(), "removal": removal.size(), "feedback": route.driver.snapshot().feedback}))
