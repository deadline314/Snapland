extends "res://game/tests/native_region_travel_review.gd"
## Synthetic admission setup; actual menu buttons, never a human-play claim.

func _ready() -> void:
	call_deferred("_run_maps")

func _run_maps() -> void:
	output_directory=OS.get_environment("SNAPLAND_MAP_REVIEW_OUTPUT")
	var parts:=OS.get_environment("SNAPLAND_MAP_REVIEW_SIZE").split("x")
	if DisplayServer.get_name()=="headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output_directory.is_absolute_path() or parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("Map review requires GPU, isolated absolute paths and WIDTHxHEIGHT");get_tree().quit(1);return
	requested_size=Vector2i(int(parts[0]),int(parts[1]))
	if requested_size not in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)] or DirAccess.make_dir_recursive_absolute(output_directory)!=OK:
		push_error("Map review requires a supported size and writable output");get_tree().quit(1);return
	report["scripted_profile_setup"]=true
	Progress.reset_progress()
	Progress.intro_seen=true;Progress.prologue_seen=true
	Progress.settings.ui_scale=1.25 if requested_size.x==800 else 1.0
	Progress.settings.reduced_motion=requested_size.x==800
	Progress.settings.fullscreen=false
	for index in range(1,7):Progress.photos["photo-welcome-game-%d"%index]={"fixture":"scripted_admission"}
	_check(Progress.save_progress(),"isolated admission profile saves")
	baseline=_snapshot()
	report.merge({"scope":"Actual regional map and complete game-entry menus, scripted setup/buttons","text_scale":Progress.settings.ui_scale},true)
	get_window().content_scale_size=requested_size
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	get_window().size=requested_size
	await _frames(4)
	main=MainScene.instantiate();get_tree().root.add_child(main)
	await _frames(8)
	main._interact("gate:harbor","潮汐碼頭")
	var travel:=main.overlay.find_child("TravelHarborButton",true,false) as Button
	_check(travel!=null,"actual harbor travel available")
	if travel==null:await _finish();return
	travel.pressed.emit();await _frames(8)
	main._show_map();await _frames(8)
	await _capture("harbor-map")
	_check(_inside(main.modal_footer),"harbor map fixed footer fits")
	var map:=main.overlay.find_child("HarborMapPanel",true,false) as Control
	_check(map!=null and _inside(map),"complete actual harbor map fits")
	var entries:=main.overlay.find_child("RegionGamesButton",true,false) as Button
	_check(entries!=null,"map has one clear game-entry action")
	if entries==null:await _finish();return
	entries.pressed.emit();await _frames(6)
	await _capture("harbor-game-entries")
	var grid:=main.overlay.find_child("RegionalGameEntriesGrid",true,false) as GridContainer
	_check(grid!=null and grid.columns==2 and _inside(grid),"complete two-column game grid fits")
	_check(main.overlay.find_children("*","ScrollContainer",true,false).is_empty(),"game entries need no scrolling")
	var definitions:Array=main.Catalog.definitions("harbor")
	_check(definitions.size()==12,"all twelve delivered harbor games are covered")
	for definition:Dictionary in definitions:
		var button:=main.overlay.find_child("HarborGame"+str(definition.id),true,false) as Button
		_check(button!=null and _inside(button),"complete visible entry: "+str(definition.id))
		if button==null:continue
		var font:=button.get_theme_font("font")
		var font_size:=button.get_theme_font_size("font_size")
		var face:=button.get_theme_stylebox("normal")
		var text_width:=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		_check(text_width<=button.size.x-face.get_content_margin(SIDE_LEFT)-face.get_content_margin(SIDE_RIGHT)+0.5,"full game-entry text fits: "+str(definition.id))
		_check(font.get_height(font_size)*button.get_global_transform_with_canvas().y.length()>=14.0*float(Progress.settings.ui_scale)-0.5,"game-entry physical type remains readable")
		button.pressed.emit();await _frames(4)
		_check(main.modal_kind=="game_info" and main.overlay.get_child_count()==1 and main.overlay.get_child(0).definition.id==definition.id,"actual callback opens correct invitation: "+str(definition.id))
		if definition.id=="game-024":await _capture("twelfth-game-invitation")
		main._close();main._show_map();await _frames(4)
		entries=main.overlay.find_child("RegionGamesButton",true,false) as Button
		if entries==null:break
		entries.pressed.emit();await _frames(4)
	var back:=main.overlay.find_child("MenuBackButton",true,false) as Button
	_check(back!=null and _inside(back),"game-entry return is fixed and visible")
	if back!=null:back.pressed.emit();await _frames(4)
	_check(main.modal_kind=="map","entry return restores actual map")
	main._close()
	main.world.interaction_requested.emit("region:welcome","返回迎賓大道");await _frames(6)
	main._show_map();await _frames(6);await _capture("welcome-map")
	_check(main.overlay.find_child("IslandChartCanvas",true,false)!=null,"welcome map remains available")
	main._close();main._interact("gate:candy","糖果工廠")
	var candy:=main.overlay.find_child("TravelCandyButton",true,false) as Button
	_check(candy!=null,"factory remains accessible")
	if candy!=null:
		candy.pressed.emit();await _frames(6)
		main._show_map();await _frames(6);await _capture("candy-map")
		_check(_inside(main.modal_footer),"factory footer remains inside viewport")
	_check(_snapshot()==baseline,"all map/menu actions preserve rewards")
	await _finish()

func _inside(control:Control)->bool:
	return control!=null and get_viewport().get_visible_rect().grow(0.5).encloses(control.get_global_rect())

func _finish()->void:
	var playbacks:Array[WeakRef]=[]
	if is_instance_valid(main):
		main.quitting=true
		for player in main.audio.get_children():
			if player is AudioStreamPlayer and player.has_stream_playback():playbacks.append(weakref(player.get_stream_playback()))
		main.audio.shutdown();main.free();await _frames(5)
	var deadline:=Time.get_ticks_msec()+2000
	while playbacks.any(func(playback:WeakRef):return playback.get_ref()!=null):
		if Time.get_ticks_msec()>=deadline:
			_check(false,"audio backend releases stopped playbacks before native map exit")
			break
		await get_tree().process_frame
	report["failures"]=failures
	var file:=FileAccess.open(output_directory.path_join("report.json"),FileAccess.WRITE)
	if file==null:push_error("Map review report failed");get_tree().quit(1);return
	file.store_string(JSON.stringify(report,"\t"));file.close()
	for failure in failures:push_error("Map review: "+failure)
	if failures.is_empty():print("PASS: native regional maps, complete game entries and unchanged rewards; scripted menu review")
	get_tree().quit(0 if failures.is_empty() else 1)
