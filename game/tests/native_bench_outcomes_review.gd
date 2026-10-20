extends "res://game/tests/native_bench_swap_review.gd"
## Actual wrong-route recovery and a non-optimal ordinary completion. No model writes.
func _run() -> void:
	_review_deadline = Time.get_ticks_msec() + 90000
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name() == "headless":
		await _fail("Bench outcomes need a GPU and absolute isolated profile"); return
	progress = get_tree().root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not progress.save_progress(): await _fail("Could not save nonempty fixture"); return
	if not await _launch_bench(): return
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var original := FileAccess.get_file_as_string(path)
	if original.is_empty(): await _fail("Empty save safety baseline"); return
	var live: Control = main.session
	var sid := live.get_instance_id()
	live.finished.connect(_capture_finish.bind(sid), CONNECT_ONE_SHOT)
	# Exhaust three real incorrect swaps; the table resets without a game-over.
	for attempt in 3:
		if not await _send_bench_swap_keys(sid,0,2) or not await _wait_for_settle(sid): return
	var state: Dictionary = live.bench_model.snapshot()
	if int(state.level) != 0 or int(state.moves) != 0 or state.ledger.size() != 3 or not str(state.last_event).contains("次數用完") or not _finish_latch.is_empty():
		await _fail("Actual budget exhaustion did not recover the same unsolved table"); return
	if FileAccess.get_file_as_string(path) != original:
		await _fail("Wrong-route recovery changed the complete saved file"); return
	await RenderingServer.frame_post_draw
	if not main._capture("bench-real-budget-recovery.png"): await _fail("Capture recovery"); return
	# Two extra swaps restore the original order, so table one is solved in 3,
	# then tables two and three use their independent visible-rule BFS minima.
	for extra in 2:
		if not await _send_bench_swap_keys(sid,0,2) or not await _wait_for_settle(sid): return
	for table in 3:
		state = live.bench_model.snapshot()
		var plan := _visible_bfs(state.seats,state.rules)
		if plan.size() != table+1: await _fail("Unexpected visible-rule minimum"); return
		for pair in plan:
			if not await _send_bench_swap_keys(sid,int(pair[0]),int(pair[1])) or not await _wait_for_settle(sid): return
		if table < 2 and FileAccess.get_file_as_string(path) != original:
			await _fail("Incomplete tables changed saved progress"); return
	if _finish_latch.is_empty() or not bool(_finish_latch.result.success) or bool(_finish_latch.result.devil) or int(_finish_latch.result.score) != 700 or _finish_latch.snapshot.ledger.size() != 11:
		await _fail("Non-optimal route did not earn exactly 700 ordinary points: " + str(_finish_latch)); return
	if not progress.photos.has("photo-welcome-game-11") or progress.photos.has("photo-welcome-devil-11"):
		await _fail("Ordinary route photo eligibility differs"); return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _has_text(main.overlay,"最少 1 次 · 實際 3 次") or not _has_text(main.overlay,"11 次") or not _has_text(main.overlay,"額度用完重排") or not _has_text(main.overlay,"1 次"):
		await _fail("Real result hides table costs, total swaps or retry count"); return
	await RenderingServer.frame_post_draw
	if not main._capture("bench-real-ordinary-700.png"): await _fail("Capture ordinary result"); return
	var record := _finish_latch.duplicate(true)
	var button := _find(main.overlay,"再玩一次")
	var reset: Dictionary = {}
	if button == null: await _fail("No result retry"); return
	button.pressed.connect(func():
		var active: Control = main.session
		if is_instance_valid(active): reset.merge({"score":active.score,"moves":active.move_count,"elapsed":active.elapsed,"ledger_size":active.bench_model.snapshot().ledger.size(),"level":active.bench_model.level})
	)
	if not await _native_click_button(button,"retry actual ordinary result"): return
	if reset != {"score":0,"moves":0,"elapsed":0.0,"ledger_size":0,"level":0}:
		await _fail("Result retry retained previous run state: "+str(reset)); return
	await RenderingServer.frame_post_draw
	if not main._capture("bench-result-retry-reset.png"): await _fail("Capture result retry"); return
	record["result_retry_at_input"] = reset
	record["incomplete_complete_save_unchanged"] = true
	var file := FileAccess.open(path.get_base_dir().path_join("outcomes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"  ")); file.close()
	print("PASS: native bench wrong-budget recovery, unchanged nonempty complete save, genuine 11-swap 700-point ordinary route and synchronous result retry reset")
	await main._quit_game()

func _has_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle): return true
	for child in node.get_children():
		if _has_text(child,needle): return true
	return false
