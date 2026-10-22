extends "res://game/tests/native_kite_main_flow_review.gd"
## A second engine process reads the first process's isolated earned profile.
func _run() -> void:
	var path:=OS.get_environment("SNAPLAND_SAVE_PATH")
	var evidence:=OS.get_environment("SNAPLAND_RESTART_EVIDENCE")
	if not path.is_absolute_path() or not evidence.is_absolute_path() or DisplayServer.get_name()=="headless":_fail("Kite restart needs GPU, an earned private profile and absolute evidence path");return
	_wall_started_msec=Time.get_ticks_msec();_guard_active=true
	progress=get_tree().root.get_node("Progress")
	if progress.normal_count()!=1 or progress.devil_count("welcome")!=1 or not progress.photos.has("photo-welcome-game-2") or not progress.photos.has("photo-welcome-devil-2") or not progress.achievements.has(EXPECTED_ACHIEVEMENT):_fail("Fresh engine did not load earned Kite cards and achievement");return
	var before:=_progress_state();var saved:=FileAccess.get_file_as_string(path)
	main=_instantiate_main(false);get_tree().root.add_child(main);await _frames(6)
	_key(KEY_M)
	if not await _wait_until(func():return main.modal_kind=="ticket","reopened voyage pass"):return
	if not await _activate_main_button("拍貼收藏本","read earned cards after actual process restart"):return
	if not await _wait_until(func():return main.modal_kind=="album","reopened album"):return
	for category in ["ordinary","devil"]:
		if category=="devil":
			var tab:=main.overlay.find_child("AlbumTab_devil",true,false) as BaseButton
			if tab==null or not await _native_click_button(tab,"read persisted devil photo"):return
			await _frames(3)
		var id:="photo-welcome-game-2" if category=="ordinary" else "photo-welcome-devil-2"
		var card:=main.overlay.find_child("AlbumPhoto_"+id,true,false) as Control
		if not await _verify_live_album_card(card,"風箏穿環" if category=="ordinary" else "風箏穿環 · 小惡魔",category):return
		if not await _scroll_control_into_view(card,"persisted "+category+" card"):return
		var image_found:=false
		for node in card.find_children("*","TextureRect",true,false):
			if node.texture!=null and node.texture.get_size()==Vector2(320,180):image_found=true
		if not image_found:_fail("Restarted album lacks the actual saved gameplay thumbnail");return
		if not main._capture("restart-"+category+"-album.png"):_fail("Capture restarted album");return
	_key(KEY_ESCAPE)
	if not await _wait_until(func():return main.modal_kind=="","close restarted album"):return
	if _progress_state()!=before or FileAccess.get_file_as_string(path)!=saved:_fail("Restart/browsing repeated an award or changed saved progression");return
	FileAccess.open(evidence.path_join("restart-check.json"),FileAccess.WRITE).store_string(JSON.stringify({"separate_engine_process":true,"normal":1,"devil":1,"achievement_loaded":true,"saved_gameplay_thumbnails":2,"protected_progress_unchanged":true,"complete_save_unchanged":true},"  "))
	print("PASS: separate Kite engine process reloads both actual gameplay photos and achievement without repeat awards or complete-save changes")
	_guard_active=false;await main._quit_game()
