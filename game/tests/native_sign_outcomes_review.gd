extends "res://game/tests/native_sign_balance_review.gd"
## Genuine wrong-direction and five-stage ordinary routes, with UI result pages.
func _run() -> void:
	_wall_deadline_msec=Time.get_ticks_msec()+300000
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name()=="headless":await _fail("Sign outcomes need GPU and isolated absolute profile");return
	progress=get_tree().root.get_node("Progress");progress.reset_progress();progress.intro_seen=true
	progress.settings.assist=false;progress.settings.reduced_motion=false
	main=_instantiate_main();get_tree().root.add_child(main);await _frames(4)
	if not progress.save_progress():await _fail("Could not save nonempty sign fixture");return
	if not await _launch_sign_balance():return
	var path:=OS.get_environment("SNAPLAND_SAVE_PATH");var original:=FileAccess.get_file_as_string(path)
	if original.is_empty():await _fail("Empty sign complete-save baseline");return
	var live:Control=main.session;live.finished.connect(_capture_result.bind(live),CONNECT_ONE_SHOT)
	if not await _drive_seven_stages(live,false,0):return
	await _frames(3)
	if bool(_result_snapshot.success) or int(_result_snapshot.score)!=0 or int(_finish_state.completed_stage_count)!=7 or int(_finish_state.safe_stages)!=0 or int(_finish_state.impacts)<1 or FileAccess.get_file_as_string(path)!=original or progress.normal_count()!=0 or progress.devil_count()!=0:
		await _fail("Actual wrong-direction seven-stage route did not fail with unchanged complete save: "+str(_result_snapshot));return
	if not await _review_result_pages("sign-failed"):return
	var failed:Dictionary={"result":_result_snapshot.duplicate(true),"model":_finish_state.duplicate(true),"complete_save_unchanged":true}
	var button:=_find(main.overlay,"再玩一次");var reset:Dictionary={}
	if button==null:await _fail("Missing sign result retry");return
	button.pressed.connect(func():
		var active:Control=main.session
		if is_instance_valid(active):reset.merge({"score":active.score,"elapsed":active.elapsed,"stage":active.sign_model.stage,"stage_elapsed":active.sign_model.stage_elapsed,"impacts":active.sign_model.impacts,"events":active.score_events.size(),"balance":active.sign_model.balance,"angle":active.sign_model.angle})
	)
	if not await _native_click_button(button,"retry failed physical sign route"):return
	if reset!={"score":0,"elapsed":0.0,"stage":0,"stage_elapsed":0.0,"impacts":0,"events":0,"balance":0.0,"angle":0.0}:await _fail("Result retry retained sign state: "+str(reset));return
	_result_snapshot.clear();_finish_state.clear();live=main.session
	live.finished.connect(_capture_result.bind(live),CONNECT_ONE_SHOT)
	if not main._capture("sign-result-retry-reset.png"):await _fail("Capture sign retry");return
	if not await _drive_seven_stages(live,false,5):return
	await _frames(3)
	if not bool(_result_snapshot.success) or bool(_result_snapshot.devil) or int(_finish_state.safe_stages)!=5 or int(_finish_state.precise_stages)!=5 or int(_result_snapshot.score)!=500 or not progress.photos.has("photo-welcome-game-8") or progress.photos.has("photo-welcome-devil-8"):
		await _fail("Five precise keyboard stages and two actual failed stages did not earn500 ordinary only: "+str(_result_snapshot)+" model="+str(_finish_state));return
	if not await _review_result_pages("sign-ordinary"):return
	var file:=FileAccess.open(path.get_base_dir().path_join("outcomes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed":failed,"retry_at_input":reset,"ordinary":{"result":_result_snapshot,"model":_finish_state},"result_pages_actual_pointer":true},"  "));file.close()
	if not await _activate_main_button("返回遊園","leave ordinary sign result"):return
	if not await _wait_until(func():return main.session==null and main.modal_kind=="","ordinary sign returns to park"):return
	print("PASS: native sign seven actual wrong-direction stages fail with complete-save safety, real retry reset, five precise stages plus two missed stages earn500 ordinary only; all result pages clicked and return to park")
	await main._quit_game()

func _review_result_pages(prefix:String) -> bool:
	var pager:=main.overlay.find_child("ResultScorePages",true,false) as VBoxContainer
	if pager==null or not pager.has_meta("page_entries"):await _fail("Missing live score pager");return false
	var entries:Array=pager.get_meta("page_entries");var seen:Dictionary={}
	var next:=main.overlay.find_child("ResultScorePagesNext",true,false) as Button
	for page in int(pager.get_meta("page_count",0)):
		await _frames(2)
		var content:=pager.find_child("PageContent",true,false)
		for node in content.get_children():
			if not node is Label or not node.visible:continue
			var label:=node as Label
			if not get_viewport().get_visible_rect().encloses(label.get_global_rect()):await _fail("Actual result row is clipped");return false
			var index:=int(str(label.name).trim_prefix("ResultScoreRow"))
			if index>=entries.size() or not label.text.contains(str(entries[index].label)):await _fail("Actual result row text differs");return false
			seen[index]=label.text
		await RenderingServer.frame_post_draw
		if not main._capture("%s-page-%d.png"%[prefix,page+1]):await _fail("Capture actual result page");return false
		if page+1<int(pager.get_meta("page_count")):
			if not await _native_click_button(next,"read next actual sign score page"):return false
	if seen.size()!=entries.size():await _fail("Not all actual sign score rows were shown");return false
	return true
