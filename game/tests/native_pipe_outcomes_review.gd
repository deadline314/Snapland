extends "res://game/tests/native_pipe_controls_review.gd"
## Real partial timeout, result retry, then an ordinary 23-turn completion.
## Do not set a result, score, model clock, board solution or collection flag.
var _outcomes: Array[Dictionary] = []

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Pipe outcomes require an isolated absolute save path")
		get_tree().quit(1)
		return
	if not _native_preflight("Pipe outcome review"): return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not progress.save_progress():
		await _fail("Could not save the real initial fixture for complete-file comparison")
		return
	if not await _enter_station() or not await _launch_from_station("開始遊玩"): return
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var saved := FileAccess.get_file_as_string(save_path)
	if saved.is_empty():
		await _fail("Complete-save comparison needs a nonempty real fixture")
		return
	if not await _solve_keyboard_order(0) or not await _wait_for_order(1): return
	# One deliberately wrong turn on the second order; no further input until
	# the unchanged 60-second model clock expires through normal process ticks.
	_key(KEY_SPACE)
	Input.flush_buffered_events()
	await get_tree().process_frame
	if active.pipe_model.total_turns != 5 or active.pipe_model.connected:
		await _fail("The deliberate second-order turn did not leave a real partial puzzle")
		return
	await _shot("pipe-partial-before-timeout")
	var deadline := Time.get_ticks_msec() + 300000
	while is_instance_valid(main) and main.modal_kind != "result" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if main.modal_kind != "result" or observed_result.is_empty():
		await _fail("Natural 60-second pipe timeout did not reach the real result screen")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if bool(observed_result.success) or bool(observed_result.devil) or int(observed_result.score) != 900 or _case_metrics.order_turns != [4,1,0] or int(_case_metrics.completed_beds) != 1 or float(_case_metrics.elapsed) < 60.0:
		await _fail("Partial timeout lost its real turns, partial score or failure: " + str(observed_result) + str(_case_metrics))
		return
	if FileAccess.get_file_as_string(save_path) != saved or progress.normal_count() != 0 or progress.devil_count() != 0:
		await _fail("Failed pipe play changed the complete save or awarded a photograph")
		return
	if not _result_has_text("本次成績 900") or not _result_has_text("沒有扣除任何收藏") or not _result_has_text("5 次") or not _result_has_text("未完成"):
		await _fail("Partial failure UI does not explain its score and collection safety")
		return
	_outcomes.append({"case":"partial-timeout", "result":observed_result.duplicate(true), "metrics":_case_metrics.duplicate(true), "complete_save_unchanged":true})
	await _shot("pipe-real-partial-timeout-result")
	var button := _find(main.overlay,"再玩一次")
	var retry_state: Dictionary = {}
	if button == null:
		await _fail("Actual failure result has no retry action")
		return
	button.pressed.connect(func():
		var session: Control = main.session
		if is_instance_valid(session): retry_state.merge({"elapsed":session.elapsed,"score":session.score,"turns":session.pipe_model.total_turns,"order":session.pipe_model.order_index,"completed":session.pipe_model.completed_beds,"practice":session.practice_mode,"assisted":session.assisted})
	)
	if not await _native_click_button(button,"retry the real partial timeout"): return
	if retry_state.is_empty() or float(retry_state.elapsed) != 0.0 or int(retry_state.score) != 0 or int(retry_state.turns) != 0 or int(retry_state.order) != 0 or int(retry_state.completed) != 0 or bool(retry_state.practice) or bool(retry_state.assisted):
		await _fail("Result retry did not reset the actual new round at its input event: " + str(retry_state))
		return
	active = main.session
	observed_result.clear()
	_case_metrics.clear()
	active.finished.connect(_capture_result)
	await _shot("pipe-failure-retry-reset")
	# Four extra genuine turns return the first source tile to its original
	# orientation. The following three solutions still have to be entered.
	for turn in 4:
		_key(KEY_SPACE)
		Input.flush_buffered_events()
		await get_tree().process_frame
	for order_index in 3:
		for cell in ORDER_ROUTES[order_index]:
			if not await _move_keyboard_cursor_to(int(cell)): return
			var before: int = active.pipe_model.total_turns
			_key(KEY_SPACE)
			Input.flush_buffered_events()
			if active.pipe_model.total_turns != before + 1:
				await _fail("Ordinary route input did not make one actual rotation")
				return
			await get_tree().process_frame
		if not active.pipe_model.connected or active.pipe_model.order_turns[order_index] != [8,7,8][order_index]:
			await _fail("Ordinary route did not connect each actual work order with its extra turns")
			return
		await _shot("pipe-ordinary-extra-turns-order-%d" % (order_index+1))
		if order_index < 2 and not await _wait_for_order(order_index+1): return
	if not await _wait_for_result(): return
	if not bool(observed_result.success) or bool(observed_result.devil) or int(observed_result.score) != 2540 or int(_case_metrics.turns) != 23 or _case_metrics.order_turns != [8,7,8] or progress.normal_count() != 1 or progress.devil_count() != 0:
		await _fail("23 genuine turns did not earn exactly the ordinary grade: " + str(observed_result) + str(_case_metrics))
		return
	if not _result_has_text("本次成績 2540") or not _result_has_text("普通拍貼已收藏") or _result_has_text("小惡魔也入鏡了") or not _result_has_text("23 次") or not _result_has_text("工單 1 · 目標 4 次 · 已供水"):
		await _fail("Ordinary result UI does not distinguish the non-perfect outcome")
		return
	_outcomes.append({"case":"ordinary-extra-turns", "result":observed_result.duplicate(true), "metrics":_case_metrics.duplicate(true), "retry_at_input":retry_state})
	await _shot("pipe-real-ordinary-result")
	var file := FileAccess.open(save_path.get_base_dir().path_join("outcomes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(_outcomes,"  "))
	print("PASS: native pipe natural 60-second partial timeout, complete-save safety, actual result retry and ordinary 23-turn 2540-point completion without devil award")
	await main._quit_game()
