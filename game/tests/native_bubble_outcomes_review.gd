extends "res://game/tests/native_bubble_photo_review.gd"
## No model/result writes: natural timeouts and two keyboard captures, real result retry.
func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name()=="headless":await _fail("Bubble outcomes need GPU and an isolated profile");return
	progress=get_tree().root.get_node("Progress");progress.reset_progress();progress.intro_seen=true
	progress.settings.assist=false;progress.settings.reduced_motion=false
	main=_instantiate_main();get_tree().root.add_child(main);await get_tree().create_timer(1.0).timeout
	if not progress.save_progress():await _fail("Could not save nonempty bubble fixture");return
	if not await _launch_bubble(false):return
	var path:=OS.get_environment("SNAPLAND_SAVE_PATH");var original:=FileAccess.get_file_as_string(path)
	if original.is_empty():await _fail("Empty complete-save baseline");return
	var sid:int=main.session.get_instance_id()
	main.session.finished.connect(_capture_earned_result.bind(sid),CONNECT_ONE_SHOT)
	# Window focus loss cancels a real unlaunched charge; no direct model call.
	_held_key(KEY_E,true);Input.flush_buffered_events();await get_tree().physics_frame
	if str(main.session.bubble_model.snapshot().bubble.phase)!="charging":await _fail("Real held E did not charge");return
	main.session.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_held_key(KEY_E,false);Input.flush_buffered_events();await get_tree().physics_frame
	if str(main.session.bubble_model.snapshot().bubble.phase)!="idle":await _fail("Focus loss restored a stale unlaunched bubble");return
	_key(KEY_SPACE);Input.flush_buffered_events();await get_tree().physics_frame
	if not main.session.bubble_model.snapshot().photos.is_empty() or main.session.mistakes!=0:await _fail("Early shutter consumed a photo or miss");return
	_held_key(KEY_E,true);Input.flush_buffered_events();await get_tree().physics_frame
	_held_key(KEY_E,false);Input.flush_buffered_events();await get_tree().physics_frame
	if str(main.session.bubble_model.snapshot().bubble.phase)!="launched":await _fail("Real E release did not launch a bubble");return
	if not await _click_session_hud(main.session,"PauseButton","pause the already launched bubble"):return
	var frozen:Dictionary=main.session.bubble_model.snapshot().duplicate(true)
	await _frames(12)
	var held:Dictionary=main.session.bubble_model.snapshot()
	if not main.session.paused or str(held.bubble.phase)!="launched" or held.bubble!=frozen.bubble or held.round_elapsed!=frozen.round_elapsed:await _fail("Paused launched bubble or round clock changed");return
	if not main._capture("bubble-real-launched-pause.png"):await _fail("Capture launched pause");return
	if not await _click_session_hud(main.session,"ResumeButton","resume the same launched bubble"):return
	if not await _wait_bubble_result():return
	await _frames(2)
	if bool(_earned_result.success) or int(_earned_result.score)!=0 or _earned_photos.size()!=3 or int(_earned_result.mistakes)!=3 or FileAccess.get_file_as_string(path)!=original or progress.normal_count()!=0 or progress.devil_count()!=0:
		await _fail("Three natural timeouts did not fail safely with unchanged complete save");return
	for i in 3:
		if bool(_earned_photos[i].captured) or str(_earned_photos[i].get("reason",""))!="timeout" or not _find_label_text(main.overlay,"第 %d 張 · 錯過快門"%(i+1)):await _fail("Failure result hides an actual zero-point timeout");return
	if not main._capture("bubble-real-three-timeouts.png"):await _fail("Capture failed bubble result");return
	var failed:Dictionary={"result":_earned_result.duplicate(true),"photos":_earned_photos.duplicate(true),"complete_save_unchanged":true,"focus_loss_notification_cancels_charge":true,"actual_launched_bubble_pause_clock_frozen":true}
	var button:=_find(main.overlay,"再玩一次");var reset:Dictionary={}
	if button==null:await _fail("Missing actual result retry");return
	button.pressed.connect(func():
		var active:Control=main.session
		if is_instance_valid(active):reset.merge({"score":active.score,"elapsed":active.elapsed,"round":active.bubble_model.round,"round_elapsed":active.bubble_model.round_elapsed,"photos":active.bubble_model.snapshot().photos.size(),"misses":active.mistakes,"bubble":active.bubble_model.snapshot().bubble.phase})
	)
	if not await _native_click_button(button,"retry actual failed three-timeout result"):return
	if reset!={"score":0,"elapsed":0.0,"round":0,"round_elapsed":0.0,"photos":0,"misses":0,"bubble":"idle"}:await _fail("Result retry retained photo or charge state: "+str(reset));return
	_earned_result.clear();_earned_photos.clear();_earned_finished_id=0
	sid=main.session.get_instance_id();main.session.finished.connect(_capture_earned_result.bind(sid),CONNECT_ONE_SHOT)
	if not main._capture("bubble-result-retry-reset.png"):await _fail("Capture result retry");return
	if not await _capture_three_photos(main.session,"keyboard",2):return
	if not await _wait_bubble_result():return
	await _frames(2)
	if not bool(_earned_result.success) or bool(_earned_result.devil) or _earned_photos.size()!=3 or int(_earned_result.mistakes)!=1 or int(_earned_result.score)!=int(_earned_photos[0].score)+int(_earned_photos[1].score) or not progress.photos.has("photo-welcome-game-10") or progress.photos.has("photo-welcome-devil-10"):
		await _fail("Two actual complete keyboard photos and a timeout did not earn ordinary only: "+str(_earned_result));return
	if not bool(_earned_photos[0].perfect) or not bool(_earned_photos[1].perfect) or bool(_earned_photos[2].captured) or not _find_label_text(main.overlay,"完美全身") or not _find_label_text(main.overlay,"第 3 張 · 錯過快門") or not _find_label_text(main.overlay,"普通拍貼已收藏"):
		await _fail("Ordinary result does not explain its real photo outcomes");return
	if not main._capture("bubble-real-ordinary-result.png"):await _fail("Capture ordinary result");return
	var file:=FileAccess.open(path.get_base_dir().path_join("outcomes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed":failed,"retry_at_input":reset,"ordinary":{"result":_earned_result,"photos":_earned_photos}},"  "));file.close()
	if not await _activate_main_button("返回遊園","leave ordinary bubble result"):return
	if not await _wait_until(func():return main.session==null and main.modal_kind=="","ordinary result returns to park"):return
	print("PASS: native bubble three natural timeout failure with complete-save safety, focus-loss charge cancellation, actual result retry reset, two keyboard full-body photos plus one timeout ordinary-only and return to park")
	await main._quit_game()
