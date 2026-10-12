extends Node

const Model := preload("res://game/minigames/bench_swap_model.gd")
const View := preload("res://game/minigames/bench_swap_view.gd")
const AvatarRenderer := preload("res://game/world/avatar_renderer.gd")
const EVENT_TIMEOUT_MS := 5000

var _model: RefCounted
var _view: Control
var _keyboard_cursor := 0
var _failure := false

## Local native input fixture for BenchSwapView only. It deliberately does not
## create Main/Session or write progress; all model actions arrive via view signals.
func _ready() -> void:
	call_deferred("_run")

func _process(delta: float) -> void:
	if _model == null or _view == null: return
	_model.step(delta)
	_view.update_frame(_model.snapshot(), _model.time_phase, false)

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		await _fail("Native bench view fixture requires a windowed GPU run and isolated SNAPLAND_SAVE_PATH")
		return
	_model = Model.new()
	_view = View.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.configure_avatar(AvatarRenderer.DEFAULT_APPEARANCE, {"outfit":"outfit-tide", "hat":"hat-none"})
	_view.seat_requested.connect(_on_seat_requested)
	add_child(_view)
	await _frames(2)
	_view.grab_focus()
	if not await _check_initial_and_retry(): return
	if not await _solve_three_levels(): return
	if not _model.finished or not _model.success or _model.level != 2:
		await _fail("Real pointer/keyboard inputs did not finish all three seating orders")
		return
	print("PASS: native BenchSwapView pointer/keyboard path, visible-rule BFS plans (1/2/3), non-solving route, budget retry, and natural model completion")
	get_tree().quit(0)

func _check_initial_and_retry() -> bool:
	var initial: Dictionary = _model.snapshot()
	if _satisfies_visible_rules(initial.seats, initial.rules):
		await _fail("Initial order already satisfies all visible seating rules")
		return false
	if int(initial.optimal_moves) != 1:
		await _fail("First visible-rule arrangement should require exactly one exchange")
		return false
	# Three actual input-driven wrong swaps exhaust the displayed first-table budget.
	for attempt in 3:
		if not await _swap_via_inputs(0, 2, attempt == 0, attempt == 1): return false
		if not await _wait_swap_settled(): return false
		if attempt < 2 and (int(_model.snapshot().moves) != attempt + 1 or bool(_model.snapshot().finished)):
			await _fail("A wrong input swap did not leave the unsolved model in its expected move state")
			return false
	var restarted: Dictionary = _model.snapshot()
	if int(restarted.level) != 0 or int(restarted.moves) != 0 or int(restarted.score) != 0 or not str(restarted.last_event).contains("次數用完"):
		await _fail("Exhausting the visible wrong-route budget did not naturally restart the table")
		return false
	return true

func _solve_three_levels() -> bool:
	var input_styles := [[false, false], [true, true], [false, true]]
	for expected_level in 3:
		var state: Dictionary = _model.snapshot()
		if int(state.level) != expected_level or _satisfies_visible_rules(state.seats, state.rules):
			await _fail("Level %d did not begin unsolved under its displayed rules" % (expected_level + 1))
			return false
		var plan := _visible_rule_bfs(state.seats, state.rules)
		if plan.size() != int(state.optimal_moves) or plan.size() != expected_level + 1:
			await _fail("Displayed-rule BFS found %d swaps, while model target is %d at table %d" % [plan.size(), int(state.optimal_moves), expected_level + 1])
			return false
		for move_index in plan.size():
			var move: Array = plan[move_index]
			if not await _swap_via_inputs(int(move[0]), int(move[1]), bool(input_styles[expected_level][0]) if move_index == 0 else true, bool(input_styles[expected_level][1]) if move_index == 0 else false): return false
			if not await _wait_swap_settled(): return false
			var expected_moves := move_index + 1
			if move_index < plan.size() - 1:
				var intermediate: Dictionary = _model.snapshot()
				if int(intermediate.level) != expected_level or int(intermediate.moves) != expected_moves or _satisfies_visible_rules(intermediate.seats, intermediate.rules):
					await _fail("Intermediate arrangement unexpectedly solved or moved levels before the last planned exchange")
					return false
		if not bool(_model.snapshot().finished) and int(_model.snapshot().level) == expected_level:
			await _fail("Input events did not advance past table %d" % (expected_level + 1))
			return false
		var ledger: Array = _model.snapshot().ledger
		var solved_entry: Dictionary = {}
		for entry in ledger:
			if int(entry.level) == expected_level and bool(entry.solved): solved_entry = entry
		if solved_entry.is_empty() or int(solved_entry.moves) != plan.size() or int(solved_entry.optimal_moves) != plan.size():
			await _fail("Table %d ledger does not show a naturally achieved minimum valid solution" % (expected_level + 1))
			return false
	return true

func _swap_via_inputs(first: int, second: int, first_pointer: bool, second_pointer: bool) -> bool:
	if first_pointer:
		if not await _click_seat(first): return false
	else:
		if not await _choose_seat_keyboard(first): return false
	if second_pointer:
		if not await _click_seat(second): return false
	else:
		if not await _choose_seat_keyboard(second): return false
	return true

func _choose_seat_keyboard(index: int) -> bool:
	var delta := posmod(index - _keyboard_cursor, 6)
	for ignored in delta:
		_send_key(KEY_RIGHT, true)
		await get_tree().process_frame
		_send_key(KEY_RIGHT, false)
		await get_tree().process_frame
	_keyboard_cursor = index
	_send_key(KEY_ENTER, true)
	await get_tree().process_frame
	_send_key(KEY_ENTER, false)
	await get_tree().process_frame
	return true

func _click_seat(index: int) -> bool:
	var local_point: Vector2 = _view.seat_geometry_bounds(index).get_center()
	var point: Vector2 = _view.get_global_transform_with_canvas() * local_point
	var event := InputEventMouseButton.new()
	event.window_id = get_window().get_window_id()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.window_id = get_window().get_window_id()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	return true

func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.window_id = get_window().get_window_id()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _on_seat_requested(index: int) -> void:
	_model.select_seat(index)
	_view.update_frame(_model.snapshot(), _model.time_phase, false)

func _visible_rule_bfs(start: Array, rules: Array) -> Array:
	var queue: Array = [start.duplicate()]
	var parents := {_key(start): {"previous":"", "swap":[]}}
	var cursor := 0
	var goal_key := ""
	while cursor < queue.size():
		var order: Array = queue[cursor]
		cursor += 1
		var key := _key(order)
		if _satisfies_visible_rules(order, rules):
			goal_key = key
			break
		for a in 6:
			for b in range(a + 1, 6):
				var next: Array = order.duplicate()
				var hold: Variant = next[a]
				next[a] = next[b]
				next[b] = hold
				var next_key := _key(next)
				if parents.has(next_key): continue
				parents[next_key] = {"previous":key, "swap":[a,b]}
				queue.append(next)
	if goal_key.is_empty(): return []
	var reversed: Array = []
	while str(parents[goal_key].previous) != "":
		reversed.push_front(parents[goal_key].swap)
		goal_key = str(parents[goal_key].previous)
	return reversed

func _satisfies_visible_rules(order: Array, rules: Array) -> bool:
	if order.size() != 6: return false
	var sorted: Array = order.duplicate()
	sorted.sort()
	if sorted != [0, 1, 2, 3, 4, 5]: return false
	for rule in rules:
		var kind := str(rule.kind)
		if kind == "seat" and order.find(int(rule.guest)) != int(rule.seat): return false
		if kind == "together" and absi(order.find(int(rule.a)) - order.find(int(rule.b))) != 1: return false
		if kind == "apart" and absi(order.find(int(rule.a)) - order.find(int(rule.b))) < 2: return false
	return true

func _key(order: Array) -> String:
	return ",".join(order.map(func(value: Variant) -> String: return str(value)))

func _frames(count: int) -> void:
	for ignored in count:
		await get_tree().process_frame

func _wait_swap_settled() -> bool:
	var deadline := Time.get_ticks_msec() + EVENT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if int(_model.snapshot().swap_from) < 0: return true
		await get_tree().process_frame
	await _fail("Animated seat exchange did not settle from live frames")
	return false

func _fail(reason: String) -> void:
	if _failure: return
	_failure = true
	push_error("Native bench view review: " + reason)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
