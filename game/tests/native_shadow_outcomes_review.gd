extends "res://game/tests/native_shadow_theatre_review.gd"
## Real failed and ordinary three-plate routes, with full-file safety and result retry.
func _run() -> void:
	_review_deadline = _wall_deadline_ms(180000)
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name() == "headless":
		await _fail("Shadow outcomes need GPU and isolated absolute profile"); return
	progress = get_tree().root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["assist"] = false
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.0).timeout
	if not progress.save_progress(): await _fail("Could not save fixture"); return
	if not await _launch_shadow(false,false): return
	var sid: int = main.session.get_instance_id()
	main.session.finished.connect(_latch_finished.bind(sid),CONNECT_ONE_SHOT)
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var original := FileAccess.get_file_as_string(path)
	if original.is_empty(): await _fail("Empty complete-save baseline"); return
	# Deliberately shoot three visibly misaligned initial projections.
	for index in 3:
		if float(main.session.shadow_model.snapshot().shape_error) <= float(main.session.shadow_model.snapshot().normal_error_limit):
			await _fail("Failure input was accidentally aligned"); return
		if not await _capture_live_cast(sid,"miss",index): return
		_key(KEY_SPACE)
		await _frames(2)
	if not await _wait_result_modal(): return
	if bool(_finished_result.success) or int(_finished_result.score) != 0 or int(_finished_model.misses) != 3 or progress.normal_count() != 0 or progress.devil_count() != 0 or FileAccess.get_file_as_string(path) != original:
		await _fail("Three real misses did not preserve the complete save with a failed zero result"); return
	await _frames(2)
	if not _find_label_text(main.overlay,"未達投影門檻") or not _find_label_text(main.overlay,"沒有扣除任何收藏"):
		await _fail("Failure screen hides projection failure or collection safety"); return
	if not main._capture("shadow-real-three-misses.png"): await _fail("Capture failed result"); return
	var failed_record := {"result":_finished_result.duplicate(true),"model":_finished_model.duplicate(true),"complete_save_unchanged":true}
	var button := _find(main.overlay,"再玩一次")
	var reset: Dictionary = {}
	if button == null: await _fail("Missing result retry"); return
	button.pressed.connect(func():
		var active: Control = main.session
		if is_instance_valid(active): reset.merge({"score":active.score,"elapsed":active.elapsed,"round":active.shadow_model.round,"misses":active.shadow_model.misses,"qualified":active.shadow_model.qualified_count})
	)
	if not await _native_click_button(button,"retry actual three-miss failure"): return
	if reset != {"score":0,"elapsed":0.0,"round":0,"misses":0,"qualified":0}:
		await _fail("Actual result retry retained shadow state: "+str(reset)); return
	_finished_id = 0
	_finished_result.clear()
	_finished_model.clear()
	sid = main.session.get_instance_id()
	main.session.finished.connect(_latch_finished.bind(sid),CONNECT_ONE_SHOT)
	if not main._capture("shadow-result-retry-reset.png"): await _fail("Capture result retry"); return
	# Two precise keyboard alignments plus one deliberately wrong shutter.
	for index in 3:
		if index != 1:
			if not await _move_keyboard_lamp_to(sid,main.session.shadow_model.round_solution(index)): return
		if not await _capture_live_cast(sid,"ordinary",index): return
		_key(KEY_SPACE)
		await _frames(2)
	if not await _wait_result_modal(): return
	await _frames(2)
	if not bool(_finished_result.success) or bool(_finished_result.devil) or int(_finished_model.qualified_count) != 2 or int(_finished_model.perfect_count) != 2 or int(_finished_model.misses) != 1 or int(_finished_result.score) <= 0 or not progress.photos.has(SHADOW_PHOTO) or progress.photos.has(SHADOW_DEVIL_PHOTO):
		await _fail("Two precise plates and a miss did not earn ordinary-only success: "+str(_finished_result)); return
	if not _find_label_text(main.overlay,"精準定影") or not _find_label_text(main.overlay,"未達投影門檻") or not _find_label_text(main.overlay,"普通拍貼已收藏"):
		await _fail("Ordinary result does not distinguish its precise and missed plates"); return
	if not main._capture("shadow-real-ordinary-result.png"): await _fail("Capture ordinary result"); return
	var file := FileAccess.open(path.get_base_dir().path_join("outcomes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed":failed_record,"retry_at_input":reset,"ordinary":{"result":_finished_result,"model":_finished_model}},"  ")); file.close()
	print("PASS: native shadow three genuine misses with complete-save safety, actual failure-result retry and two precise keyboard plates plus one miss earning ordinary-only success")
	await main._quit_game()
