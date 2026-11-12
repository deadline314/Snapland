extends Node
## Scripted fixture records are setup data, never evidence of earning cards or human play.
const MainScene = preload("res://game/main.tscn")
var main: Node
var output_directory := ""
var requested_size := Vector2i(1280,720)
var failures: Array[String]=[]
var baseline: Dictionary={}
var report := {"scripted_fixture":true,"scripted_profile_setup":false,"earned_in_human_play":false,"human_played":false,"captures":[]}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if DisplayServer.get_name()=="headless" or not save_path.is_absolute_path():
		push_error("Native harbor review needs a GPU window and absolute isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	var dimensions := OS.get_environment("SNAPLAND_HARBOR_REVIEW_SIZE")
	if not dimensions.is_empty():
		var parts := dimensions.split("x")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			push_error("Harbor review size must be WIDTHxHEIGHT")
			get_tree().quit(1)
			return
		requested_size=Vector2i(int(parts[0]),int(parts[1]))
	if requested_size not in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		push_error("Harbor review size must be 800x600, 1280x720 or 1920x1080")
		get_tree().quit(1)
		return
	output_directory=OS.get_environment("SNAPLAND_HARBOR_REVIEW_OUTPUT")
	if output_directory.is_empty(): output_directory=save_path.get_base_dir().path_join("native-harbor-review")
	if not output_directory.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_directory)!=OK:
		push_error("Harbor review output must be an absolute writable directory")
		get_tree().quit(1)
		return
	var restart := OS.get_environment("SNAPLAND_HARBOR_REVIEW_MODE")=="restart"
	var text_scale := OS.get_environment("SNAPLAND_HARBOR_REVIEW_TEXT_SCALE")
	if text_scale.is_empty(): text_scale="1"
	if text_scale not in ["1","1.0","1.25"]:
		push_error("Harbor review text scale must be 1 or 1.25")
		get_tree().quit(1)
		return
	if not restart:
		var appearance: Dictionary=Progress.appearance.duplicate(true)
		var equipped: Dictionary=Progress.equipped.duplicate(true)
		var owned: Array=Progress.owned_clothes.duplicate()
		Progress.reset_progress()
		Progress.appearance=appearance
		Progress.equipped=equipped
		Progress.owned_clothes.assign(owned)
		Progress.intro_seen=true
		Progress.prologue_seen=true
		Progress.settings.ui_scale=float(text_scale)
		Progress.settings.reduced_motion=OS.get_environment("SNAPLAND_HARBOR_REVIEW_REDUCED_MOTION")=="1"
		Progress.settings.fullscreen=false
		report.scripted_profile_setup=true
		# Six existing welcome sources are synthetic saved fixture data, not awarded gameplay.
		for index in range(1,7): Progress.photos["photo-welcome-game-%d"%index]={"fixture":"scripted_profile_setup"}
		_check(Progress.save_progress(),"scripted setup saves isolated canonical records")
	else:
		_check(FileAccess.file_exists(save_path) and Progress.current_region=="harbor","fresh process actually loads saved harbor")
		if not failures.is_empty():
			await _finish()
			return
	baseline=_snapshot()
	report.merge({"mode":"restart_reader" if restart else "scripted_setup_and_real_travel","save_path":save_path,"appearance":Progress.appearance.duplicate(true),"equipped":Progress.equipped.duplicate(true),"text_scale":Progress.settings.ui_scale,"reduced_motion":Progress.settings.reduced_motion,"rewards_before":baseline},true)
	var window := get_window()
	window.mode=Window.MODE_WINDOWED
	window.content_scale_size=requested_size
	window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	window.size=requested_size
	await _frames(4)
	main=MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	_check(window.size==requested_size and Vector2i(window.get_visible_rect().size)==requested_size,"actual window and viewport match requested dimensions")
	report.merge({"requested_size":str(requested_size),"window_size":str(window.size),"viewport_size":str(window.get_visible_rect().size),"renderer":RenderingServer.get_current_rendering_method()},true)
	if restart:
		_check(main.world_region=="harbor" and main.boat_stage==null and main.modal_kind=="","saved harbor startup has no boat/arrival")
		await _capture("restart-harbor")
	else:
		_check(main.world_region=="welcome" and Progress.normal_count()==6,"scripted setup starts welcome with six ordinary cards")
		main._interact("gate:harbor","潮汐碼頭")
		await _frames(4)
		await _capture("qualified-gate")
		var travel: Button=main.overlay.find_child("TravelHarborButton",true,false)
		_check(travel!=null,"actual Main gate offers qualified travel button")
		if travel==null:
			await _finish()
			return
		travel.pressed.emit()
		await _frames(6)
		_check(main.world_region=="harbor" and Progress.current_region=="harbor","actual gate button saves and replaces world")
		await _capture("harbor-arrival")
	_check(main.world.avatar_appearance==Progress.appearance and main.world.avatar_equipped==Progress.equipped,"world applies current complete look")
	_check(main.world.reduced_motion==Progress.settings.reduced_motion and main.audio._active_context=="harbor","current settings and region audio are applied")
	for high in [false,true]:
		if main.world.is_high_tide()!=high: main.world.interaction_requested.emit("harbor:tide","潮汐鐘")
		_check(main.world.is_high_tide()==high,"actual Main tide interaction previews requested tide")
		main._show_map()
		await _frames(5)
		_check(main.overlay.find_child("HarborMapPanel",true,false)!=null,"actual harbor map is open")
		await _capture("map-high" if high else "map-low")
		main._close()
		main.world.interaction_requested.emit("harbor:ferry:shore","免費渡船")
		await _frames(5)
		_check(main.world.player.position.distance_to(main.world.LIGHTHOUSE_DOCK)<0.15,"actual ferry interaction reaches safe lighthouse dock")
		await _capture("lighthouse-high" if high else "lighthouse-low")
		main.world.interaction_requested.emit("harbor:ferry:lighthouse","免費渡船")
		await _frames(5)
		_check(main.world.player.position.distance_to(main.world.SHORE_DOCK)<0.15,"free ferry returns to shore in both tides")
	main._show_album()
	await _frames(5)
	await _capture("harbor-empty-collection")
	var selector: OptionButton=main.overlay.find_child("AlbumRegionSelector",true,false)
	_check(selector!=null and selector.selected==1,"collection defaults to harbor")
	if selector!=null:
		selector.select(0)
		selector.item_selected.emit(0)
		await _frames(5)
		await _capture("saved-welcome-collection")
	main._close()
	main._show_settings()
	await _frames(5)
	await _capture("harbor-settings")
	main._close()
	main._show_pause()
	await _frames(5)
	_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)==null,"harbor pause excludes welcome-only replay")
	await _capture("harbor-pause")
	main._close()
	main.world.interaction_requested.emit("region:welcome","返回迎賓大道")
	await _frames(6)
	_check(main.world_region=="welcome","actual permanent return interaction is free")
	await _capture("free-return-welcome")
	main._show_pause()
	_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)!=null,"free return restores welcome boat replay")
	main._close()
	# Leave a real travel-written harbor save for a separate process to read.
	main._interact("gate:harbor","潮汐碼頭")
	var return_trip: Button=main.overlay.find_child("TravelHarborButton",true,false)
	_check(return_trip!=null,"repeat trip still admits the same six cards")
	if return_trip!=null: return_trip.pressed.emit()
	await _frames(6)
	_check(main.world_region=="harbor" and Progress.current_region=="harbor","writer ends in durable harbor for restart reader")
	_check(_snapshot()==baseline,"travel/tide/ferry/menus/return preserve every reward and fixture record")
	await _finish()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image==null or image.is_empty():
		_check(false,"GPU capture is empty: "+label)
		return
	_check(image.get_size()==requested_size,"actual PNG dimensions match: "+label)
	var bounds := get_viewport().get_visible_rect()
	for name in ["TravelHarborButton","MenuBackButton","AlbumRegionSelector","PauseResumeButton","PauseQuitButton"]:
		var control := main.overlay.find_child(name,true,false) as Control
		if control!=null and control.is_visible_in_tree(): _check(bounds.encloses(control.get_global_rect()),"visible action fits: "+label+"/"+name)
	var file := output_directory.path_join(label+".png")
	_check(image!=null and image.save_png(file)==OK and FileAccess.file_exists(file),"capture writes: "+label)
	report.captures.append({"label":label,"path":file,"image_size":str(image.get_size()),"region":main.world_region,"high_tide":main.world.is_high_tide() if main.world_region=="harbor" else false})

func _snapshot() -> Dictionary:
	var result := {}
	for field in ["photos","coins","quests","achievements","visited","appearance","equipped","owned_clothes"]:
		var value = Progress.get(field)
		result[field]=value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func _finish() -> void:
	if is_instance_valid(main):
		main.quitting=true
		main.audio.shutdown()
		main.world.area_changed.emit("海風碼頭")
		await get_tree().create_timer(0.25).timeout
		_check(main.audio._active_context.is_empty(),"pending area events cannot restart audio during teardown")
		main.free()
		await _frames(5)
	report["rewards_after"]=_snapshot()
	report["failures"]=failures
	var file := FileAccess.open(output_directory.path_join("report.json"),FileAccess.WRITE)
	_check(file!=null,"review report opens")
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	for failure in failures: push_error("Harbor review: "+failure)
	if failures.is_empty(): print("PASS: native Main harbor travel and saved restart review ",requested_size,"; scripted fixture, inspect images for visual acceptance")
	get_tree().quit(0 if failures.is_empty() else 1)
