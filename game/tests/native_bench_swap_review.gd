extends "res://game/tests/native_review.gd"

const Model := preload("res://game/minigames/bench_swap_model.gd")

var _finish_latch: Dictionary = {}
var _finished_session_id := 0
var _retry_latch := false
var _failure := false
var _review_deadline := 0

func _process(_delta: float) -> void:
	if _review_deadline > 0 and Time.get_ticks_msec() > _review_deadline:
		_review_deadline = 0
		push_error("Native BenchSwap review exceeded its finite 90-second deadline")
		if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
		get_tree().quit(1)
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)

## Main integration fixture: native park/menu launch, Session input, pause/retry,
## result latch, screenshots, and progression observation. Never writes a game
## model, score, result, or completion field to simulate a player action.
func _run() -> void:
	_review_deadline = Time.get_ticks_msec() + 90000
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		await _fail("Native BenchSwap review requires windowed rendering and isolated SNAPLAND_SAVE_PATH"); return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null: await _fail("Progress autoload is missing"); return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	var private_before := _private_progress()
	main = _instantiate_main()
	if main == null: get_tree().quit(1); return
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not await _launch_bench(): return
	var session: Control = main.session
	var sid := session.get_instance_id()
	session.finished.connect(_capture_finish.bind(sid), CONNECT_ONE_SHOT)
	if not await _exercise_pause_retry(session, private_before): return
	if not await _solve_tables(session, private_before): return
	if _finish_latch.is_empty() or _finished_session_id != sid:
		await _fail("Session finished signal did not synchronously latch its matching instance id"); return
	var result: Dictionary = _finish_latch.result
	var model_state: Dictionary = _finish_latch.snapshot
	if not bool(result.get("success", false)) or not bool(result.get("devil", false)) or int(result.get("score", -1)) != 750 or int(model_state.score) != 750 or bool(result.get("practice", true)) or bool(result.get("assisted", true)):
		await _fail("Natural result disagrees with exact visible-rule solutions and score ledger: %s" % str(_finish_latch)); return
	if not progress.photos.has("photo-welcome-game-11") or not progress.photos.has("photo-welcome-devil-11") or not progress.achievements.has("ACH_GAME_011"):
		await _fail("Formal exact play did not award the expected game-011 normal/devil records"); return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-bench-swap-result.png"):
		await _fail("Could not capture naturally earned BenchSwap result"); return
	print("PASS: native Main BenchSwap station/menu launch, pause/resume, synchronous retry reset, keyboard BFS minimum tables 1/2/3, exact-result latch, and result capture")
	var formal_before := _private_progress()
	if not await _activate_main_button("返回遊園", "return after formal BenchSwap"): return
	progress.settings["assist"] = true
	progress.settings["reduced_motion"] = true
	if not await _launch_bench(): return
	var private_session: Control = main.session
	var private_sid := private_session.get_instance_id()
	_finish_latch = {}; _finished_session_id = 0
	private_session.finished.connect(_capture_finish.bind(private_sid), CONNECT_ONE_SHOT)
	if not await _click_hud(private_session, "PauseButton", "pause for practice"): return
	if not await _click_hud(private_session, "PracticeButton", "restart in private practice"): return
	if not await _require_live(private_sid): return
	if not private_session.practice_mode or not private_session.assisted or not private_session.reduced_motion:
		await _fail("HUD practice did not retain assisted reduced-motion settings"); return
	if not await _exercise_pause_retry(private_session, formal_before): return
	if not await _solve_tables(private_session, formal_before, true): return
	if _finish_latch.is_empty() or _finished_session_id != private_sid or not bool(_finish_latch.result.practice) or not bool(_finish_latch.result.assisted) or bool(_finish_latch.result.devil) or not bool(_finish_latch.result.success) or int(_finish_latch.result.score) != 750 or int(_finish_latch.snapshot.score) != 750:
		await _fail("Private pointer completion result is inconsistent"); return
	if _private_progress() != formal_before:
		await _fail("Assisted private practice changed collectible or wardrobe progression"); return
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-bench-swap-private-result.png"):
		await _fail("Could not capture private practice result"); return
	print("PASS: assisted reduced-motion HUD practice/retry, pointer BFS minimum tables 1/2/3, unchanged private progression")
	await main._quit_game()

func _launch_bench() -> bool:
	for point in main.world.points:
		if point.id == "game-011":
			main.world.player.position = point.position + Vector3(0.0, 0.3, 0.0)
			break
	var deadline := Time.get_ticks_msec() + 4000
	while main.world.nearest.get("id", "") != "game-011" and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if main.world.nearest.get("id", "") != "game-011": await _fail("BenchSwap station never became the nearest park interaction"); return false
	_key(KEY_E)
	deadline = Time.get_ticks_msec() + 3000
	while main.modal_kind != "game_info" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if main.modal_kind != "game_info": await _fail("Real E input did not open the BenchSwap station menu"); return false
	if _find(main.overlay,"開始遊玩") == null:
		if not await _activate_main_button("玩法與選項", "open BenchSwap options"): return false
	if not await _activate_main_button("開始遊玩", "launch BenchSwap through its station menu"): return false
	deadline = Time.get_ticks_msec() + 3000
	while main.session == null and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if main.session == null or main.session.game_id != "game-011" or main.session.mode != "bench_swap":
		await _fail("Station menu did not launch the game-011 BenchSwap Session"); return false
	if not is_instance_valid(main.session.presentation) or not main.session.presentation is Control:
		await _fail("BenchSwap Session did not create its Control presentation"); return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-bench-swap-gameplay.png"): await _fail("Could not capture live BenchSwap gameplay"); return false
	return true

func _exercise_pause_retry(session: Control, private_before: Dictionary) -> bool:
	var sid := session.get_instance_id()
	if not await _wait_for_elapsed(session, 0.20): return false
	if not await _require_live(sid): return false
	var pause := session.minigame_hud.find_child("PauseButton", true, false) as BaseButton
	if pause == null: await _fail("Missing Session PauseButton"); return false
	if not await _native_click_button(pause, "pause BenchSwap"): return false
	if not await _require_live(sid): return false
	if not session.paused: await _fail("Actual pause click did not pause Session"); return false
	var frozen := float(session.bench_model.snapshot().elapsed)
	var revision := int(session.bench_model.snapshot().revision)
	await get_tree().physics_frame
	if not await _require_live(sid): return false
	await get_tree().physics_frame
	if not await _require_live(sid): return false
	if float(session.bench_model.snapshot().elapsed) != frozen or int(session.bench_model.snapshot().revision) != revision:
		await _fail("BenchSwap model advanced while paused"); return false
	var resume := session.minigame_hud.find_child("ResumeButton", true, false) as BaseButton
	if resume == null: await _fail("Missing Session ResumeButton"); return false
	if not await _native_click_button(resume, "resume BenchSwap"): return false
	if not await _require_live(sid): return false
	if session.paused: await _fail("Actual resume click left BenchSwap paused"); return false
	# Burn exactly the first table's displayed budget through real wrong seat keys,
	# then confirm retry and latch the model inside the synchronous pressed signal.
	var snap: Dictionary = session.bench_model.snapshot()
	for index in int(snap.move_budget):
		var pair := _first_unsolved_pair(snap)
		if pair.is_empty(): await _fail("Could not find an input route that leaves visible table one unsolved"); return false
		if not await _send_bench_swap_keys(sid, int(pair[0]), int(pair[1])): return false
		if not await _wait_for_settle(sid): return false
		if not await _require_live(sid): return false
		snap = _node_for_id(sid).bench_model.snapshot()
		if int(snap.level) != 0: await _fail("A non-solution route unexpectedly left table one"); return false
	if int(snap.moves) != 0 or not str(snap.last_event).contains("次數用完"):
		await _fail("Exhausted route did not naturally return to the unsolved table start"); return false
	if not await _click_hud(session, "PauseButton", "pause before BenchSwap retry"): return false
	if not await _require_live(sid): return false
	if not await _click_hud(session, "RetryButton", "open BenchSwap retry confirmation"): return false
	if not await _require_live(sid): return false
	var confirm := session.minigame_hud.find_child("ConfirmAction", true, false) as BaseButton
	if confirm == null: await _fail("Missing retry ConfirmAction"); return false
	_retry_latch = false
	confirm.pressed.connect(_capture_retry.bind(session.get_instance_id(), private_before), CONNECT_ONE_SHOT)
	if not await _native_click_button(confirm, "confirm BenchSwap retry"): return false
	if not await _require_live(sid): return false
	if not _retry_latch: await _fail("Confirmed retry did not synchronously reset BenchSwap in pressed callback"); return false
	if _private_progress() != private_before: await _fail("Retry changed private progression or wardrobe-pending state"); return false
	await RenderingServer.frame_post_draw
	if not main._capture(".review/native-bench-swap-%s-retry.png" % ("private" if session.practice_mode else "formal")): await _fail("Could not capture synchronous retry state"); return false
	return true


func _solve_tables(session: Control, private_before: Dictionary, pointer := false) -> bool:
	var sid := session.get_instance_id()
	for table in 3:
		if not await _require_live(sid): return false
		var state: Dictionary = _node_for_id(sid).bench_model.snapshot()
		await RenderingServer.frame_post_draw
		if not main._capture(".review/native-bench-swap-%s-table-%d.png" % ["private" if pointer else "formal", table + 1]):
			await _fail("Could not capture visible table"); return false
		if int(state.level) != table or _satisfies(state.seats, state.rules): await _fail("Table %d must start visibly unsolved" % (table + 1)); return false
		var plan := _visible_bfs(state.seats, state.rules)
		if plan.size() != int(state.optimal_moves) or plan.size() != table + 1:
			await _fail("Visible rules yield %d swaps, model reports %d at table %d" % [plan.size(), int(state.optimal_moves), table + 1]); return false
		for step_index in plan.size():
			var pair: Array = plan[step_index]
			# Formal uses only keys; private assisted practice uses only pointer seats.
			if not pointer:
				if not await _send_bench_swap_keys(sid, int(pair[0]), int(pair[1])): return false
			else:
				if not await _click_seat(sid, int(pair[0])): return false
				if not await _click_seat(sid, int(pair[1])): return false
			if not await _wait_for_settle(sid): return false
			state = _finish_latch.snapshot if table == 2 and not _finish_latch.is_empty() else _node_for_id(sid).bench_model.snapshot()
			if step_index < plan.size() - 1 and _satisfies(state.seats, state.rules):
				await _fail("Table solved before the last BFS-required exchange"); return false
		var solved_state: Dictionary = _finish_latch.snapshot if table == 2 and not _finish_latch.is_empty() else _node_for_id(sid).bench_model.snapshot()
		var ledger: Array = solved_state.ledger
		var solved := false
		for entry in ledger:
			if int(entry.level) == table and bool(entry.solved) and int(entry.moves) == plan.size() and int(entry.optimal_moves) == plan.size() and int(entry.get("points", -1)) == 300 - 25 * plan.size(): solved = true
		if not solved: await _fail("Table %d ledger does not record the exact visible-rule minimum" % (table + 1)); return false
		if table < 2 and _private_progress() != private_before: await _fail("Gameplay changed private progress before formal completion"); return false
	return true

func _send_bench_swap_keys(sid: int, first: int, second: int) -> bool:
	for seat in [first, second]:
		if not await _require_live(sid): return false
		var event := InputEventKey.new()
		event.keycode = KEY_1 + seat
		event.physical_keycode = KEY_1 + seat
		event.pressed = true
		Input.parse_input_event(event)
		event = InputEventKey.new()
		event.keycode = KEY_1 + seat
		event.physical_keycode = KEY_1 + seat
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame

	return await _live_or_finished(sid)

func _click_seat(sid: int, index: int) -> bool:
	if not await _require_live(sid): return false
	var view: Control = _node_for_id(sid).presentation
	var rect: Rect2 = view.seat_geometry_bounds(index)
	var point: Vector2 = view.get_viewport().get_final_transform() * (view.get_global_transform_with_canvas() * rect.get_center())
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion); Input.flush_buffered_events()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point; event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()
	await get_tree().process_frame
	return await _live_or_finished(sid)

func _wait_for_settle(sid: int) -> bool:
	var deadline := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		if _finished_session_id == sid and not _finish_latch.is_empty() and int(_finish_latch.snapshot.swap_from) < 0: return true
		if not await _require_live(sid): return false
		if int(_node_for_id(sid).bench_model.snapshot().swap_from) < 0: return true
		await get_tree().physics_frame
	await _fail("BenchSwap exchange animation timed out"); return false

func _require_live(sid: int) -> bool:
	var live := _node_for_id(sid)
	if not is_instance_valid(live) or live.is_queued_for_deletion() or main.session != live:
		await _fail("BenchSwap instance %d disappeared unexpectedly" % sid); return false
	return true

func _live_or_finished(sid: int) -> bool:
	if _finished_session_id == sid and not _finish_latch.is_empty(): return true
	return await _require_live(sid)

func _wait_for_elapsed(session: Control, target: float) -> bool:
	var sid := session.get_instance_id()
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if not await _require_live(sid): return false
		if float(_node_for_id(sid).bench_model.snapshot().elapsed) >= target: return true
		await get_tree().physics_frame
	await _fail("BenchSwap elapsed time did not advance"); return false

func _click_hud(session: Control, name: String, context: String) -> bool:
	if not is_instance_valid(session): await _fail("Session disappeared before HUD control " + name); return false
	var button := session.minigame_hud.find_child(name, true, false) as BaseButton
	if button == null: await _fail("Missing HUD control " + name); return false
	return await _native_click_button(button, context)

func _capture_retry(session_id: int, private_before: Dictionary) -> void:
	var live := _node_for_id(session_id)
	if not is_instance_valid(live) or main.session != live: return
	var state: Dictionary = live.bench_model.snapshot()
	_retry_latch = int(state.level) == 0 and int(state.moves) == 0 and int(state.score) == 0 and state.ledger.is_empty() and float(state.elapsed) == 0.0 and not live.paused and not live.ended and _private_progress() == private_before

func _capture_finish(result: Dictionary, session_id: int) -> void:
	var completed := _node_for_id(session_id)
	if not is_instance_valid(completed): call_deferred("_fail", "BenchSwap finished Session vanished before synchronous latch"); return
	if str(result.get("game_id", "")) != "game-011":
		call_deferred("_fail", "Matching BenchSwap Session emitted another game result"); return
	_finish_latch = {"result":result.duplicate(true), "snapshot":completed.bench_model.snapshot().duplicate(true), "session_id":session_id}
	_finished_session_id = session_id

func _node_for_id(id: int) -> Control:
	return instance_from_id(id) as Control if is_instance_id_valid(id) else null

func _private_progress() -> Dictionary:
	return {"photos":progress.photos.duplicate(true), "achievements":progress.achievements.duplicate(true), "quests":progress.quests.duplicate(true), "coins":progress.coins, "owned":progress.owned_clothes.duplicate(true), "equipped":progress.equipped.duplicate(true), "wardrobe_rewards":progress.wardrobe_rewarded_games.duplicate(true), "pending":progress.platform_pending_achievements.duplicate(true), "normal_count":progress.normal_count(), "devil_count":progress.devil_count()}

func _satisfies(seats: Array, rules: Array) -> bool:
	if seats.size() != 6: return false
	var sorted := seats.duplicate(); sorted.sort()
	if sorted != [0,1,2,3,4,5]: return false
	for rule in rules:
		var a := seats.find(int(rule.get("a", -1))); var b := seats.find(int(rule.get("b", -1)))
		match str(rule.kind):
			"seat": if seats.find(int(rule.guest)) != int(rule.seat): return false
			"together": if absi(a-b) != 1: return false
			"apart": if absi(a-b) < 2: return false
	return true

func _visible_bfs(start: Array, rules: Array) -> Array:
	var queue: Array = [start.duplicate()]
	var parents := {_order_key(start): {"prev":"", "swap":[]}}
	var cursor := 0; var goal := ""
	while cursor < queue.size():
		var order: Array = queue[cursor]; cursor += 1
		var key := _order_key(order)
		if _satisfies(order, rules): goal = key; break
		for a in 6:
			for b in range(a+1,6):
				var next: Array = order.duplicate(); var hold: Variant = next[a]; next[a] = next[b]; next[b] = hold
				var next_key := _order_key(next)
				if not parents.has(next_key): parents[next_key] = {"prev":key,"swap":[a,b]}; queue.append(next)
	if goal.is_empty(): return []
	var path: Array = []; var cursor_key := goal
	while str(parents[cursor_key].prev) != "": path.push_front(parents[cursor_key].swap); cursor_key = str(parents[cursor_key].prev)
	return path

func _first_unsolved_pair(state: Dictionary) -> Array:
	for a in 6:
		for b in range(a+1,6):
			var next: Array = state.seats.duplicate(); var hold: Variant = next[a]; next[a] = next[b]; next[b] = hold
			if not _satisfies(next, state.rules): return [a,b]
	return []

func _order_key(order: Array) -> String:
	return ",".join(order.map(func(value: Variant) -> String: return str(value)))

func _activate_main_button(needle: String, context: String) -> bool:
	await get_tree().process_frame
	var button := _find(main.overlay, needle)
	if button == null: await _fail("Missing main button %s for %s" % [needle,context]); return false
	return await _native_click_button(button, context)

func _find(node: Node, needle: String) -> Button:
	if node is Button and (node as Button).text.contains(needle): return node as Button
	for child in node.get_children():
		var found := _find(child, needle)
		if found != null: return found
	return null

func _fail(message: String) -> void:
	_failure = true
	push_error("Native BenchSwap review: " + message)
	if is_instance_valid(main) and is_instance_valid(main.audio): main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)
