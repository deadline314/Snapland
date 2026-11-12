extends Node
const MainScene = preload("res://game/main.tscn")
var main: Node
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Region travel needs an absolute isolated save path")
		get_tree().quit(1)
		return
	get_window().size=Vector2i(1280,720)
	if OS.get_cmdline_user_args().has("--region-travel-failure-child"):
		await _failure_child()
		return
	Progress.reset_progress()
	Progress.intro_seen=true
	Progress.prologue_seen=true
	await _spawn()
	_check(main.has_method("_travel_to_region"), "Main has guarded regional travel")
	if not main.has_method("_travel_to_region"):
		await _finish()
		return
	var original: Node=main.world
	_check(main.world_region=="welcome", "fresh profile selects welcome")
	_check(_labels3d(main.world).contains("6 張 · 不消耗") and _labels3d(main.world).count("準備中")==8, "physical harbor gate is open while eight future gates stay truthful")
	_check(not main._travel_to_region("moon") and not main._travel_to_region("welcome"), "unknown/same destinations do nothing")
	for index in range(1,6): Progress.photos["photo-welcome-game-%d"%index]={}
	_check(not main._travel_to_region("harbor") and main.world==original, "five ordinary cards cannot enter")
	Progress.photos["photo-welcome-devil-1"]={}
	Progress.photos["postcard-time-dawn"]={}
	_check(not main._travel_to_region("harbor"), "devil cards and postcards do not replace six ordinary cards")
	# A sixth card from a different region proves admission uses the global count.
	Progress.photos["photo-candy-game-1"]={}
	_check(Progress.normal_count()==6 and Progress.normal_count_for_zone("welcome")==5, "global threshold fixture is distinct and regional")
	main._refresh()
	main._show_map()
	await _frames(2)
	var welcome_map: Node=main.overlay.find_child("MapGate_harbor",true,false)
	_check(welcome_map!=null, "welcome retains its station map")
	welcome_map.pressed.emit()
	_check(_labels(main.overlay).contains("可前往"), "welcome map truthfully shows open harbor")
	main._close()
	main._start_dialogue([{ "speaker":"票票", "text":"測試對話" }],Callable())
	_check(not main._travel_to_region("harbor"), "dialogue owns the world")
	main._cancel_dialogue()
	main.capture_mode=true
	_check(not main._travel_to_region("harbor"), "capture owns the world")
	main.capture_mode=false
	main.session=main.Session.new()
	_check(not main._travel_to_region("harbor"), "session owns the world")
	main.session.free()
	main.session=null
	Progress.set_setting("reduced_motion",true)
	main._select_time_phase("night")
	_check(Progress.set_appearance_batch({"skin":"olive","species":"elf","gender":"female","hair":"bob","hair_color":"silver","face":"smiling"}), "nondefault current look saves")
	_check(Progress.equip_clothing("outfit-rainvest"), "current owned outfit saves")
	var before := _snapshot()
	main._interact("gate:harbor","潮汐碼頭")
	var travel: Button=main.overlay.find_child("TravelHarborButton",true,false)
	_check(travel!=null, "qualified gate has an explicit travel button")
	if travel==null:
		await _finish()
		return
	travel.pressed.emit()
	_check(main.changing_region and main.world==original and Progress.current_region=="harbor", "save precedes deferred old-world release")
	var old_area: String=main.area_label.text
	original.area_changed.emit("stale old area")
	_check(main.area_label.text==old_area and not main._travel_to_region("welcome"), "transition ignores old events and rejects reentry")
	await _frames(4)
	_check(not is_instance_valid(original) and main.world_region=="harbor", "old world is released and saved harbor is visible")
	_check(main.world.coastal_play==null and main.world.npc_activity==null, "harbor never instantiates welcome toys/NPCs")
	_check(main.audio._active_context=="harbor" and main.world.reduced_motion and main.world.night, "harbor applies current settings/time/audio")
	_check(main.world.avatar_appearance==Progress.appearance and main.world.avatar_equipped==Progress.equipped, "harbor reapplies complete current look")
	_check(main.normal_count_label.text.contains("0 / 18") and main.devil_count_label.text.contains("0 / 12"), "harbor HUD uses local numerators")
	main.world.nearest=main.world.points[0]
	_check(not main._context_prompt().is_empty(), "optional coastal prompt is safe")
	await _harbor_ui(before)
	for tide in [false,true]:
		main.world.set_tide(tide)
		main._interact("harbor:ferry:shore","免費渡船")
		_check(main.world.player.position.is_equal_approx(main.world.LIGHTHOUSE_DOCK), "free ferry reaches lighthouse in either tide")
		main._interact("harbor:ferry:lighthouse","免費渡船")
		_check(main.world.player.position.is_equal_approx(main.world.SHORE_DOCK), "free ferry reaches shore in either tide")
		_check(_snapshot()==before, "tides and ferry grant and consume nothing")
		var harbor: Node=main.world
		var saved_cards: Dictionary=Progress.photos.duplicate(true)
		Progress.photos.clear()
		# Emit from the real world signal: its stack must survive deferred release.
		harbor.interaction_requested.emit("region:welcome","返回迎賓大道")
		await _frames(4)
		_check(not is_instance_valid(harbor) and main.world_region=="welcome", "free return in either tide releases harbor")
		_check(main.world.player.position.distance_to(_point("gate:harbor").position)<2.5, "return uses safe welcome gate spawn")
		_check(Progress.photos.is_empty(), "free return requires no cards and grants none")
		Progress.photos=saved_cards
		main._show_pause()
		_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)!=null, "welcome boat replay remains available after return")
		main._close()
		_check(main._travel_to_region("harbor"), "repeat qualified trip starts")
		await _frames(4)
	_check(_snapshot()==before, "repeated trips preserve all rewards and appearance")
	_check(_world_count()==1, "steady state has exactly one world")
	_check(Progress.save_progress(), "harbor profile saves for restart")
	await _dispose()
	Progress.load_progress()
	Progress.intro_seen=false
	Progress.prologue_seen=false
	await _spawn()
	_check(main.world_region=="harbor" and main.boat_stage==null and main.modal_kind=="", "saved harbor restart skips welcome boat/arrival")
	Progress.reset_progress()
	await _frames(4)
	_check(main.world_region=="welcome" and Progress.current_region=="welcome" and _world_count()==1, "reset rebuilds actual welcome world")
	await _dispose()
	# Missing and malformed region saves preserve legacy welcome startup.
	for supplied in [null,"moon"]:
		var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Progress._save_path()))
		payload.intro_seen=true
		if supplied==null: payload.erase("current_region")
		else: payload.current_region=supplied
		var file := FileAccess.open(Progress._save_path(),FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
		Progress.load_progress()
		await _spawn()
		_check(main.world_region=="welcome" and main.boat_stage==null, "legacy/invalid saved region starts welcome")
		await _dispose()
	await _failure_process()
	await _finish()

func _harbor_ui(before: Dictionary) -> void:
	main._show_pause()
	_check(main.overlay.find_child("PauseBoatPrologueButton",true,false)==null, "harbor pause has no boat replay")
	main._close()
	main._show_boat_prologue()
	_check(main.boat_stage==null, "harbor refuses boat replay directly")
	main._show_map()
	await _frames(3)
	var map: Node=main.overlay.find_child("HarborMapPanel",true,false)
	_check(map!=null and main.overlay.find_child("MapStop_game-001",true,false)==null, "harbor map uses real terrain without welcome stations")
	_check(map.snapshot.bounds==main.world.BOUNDS and map.snapshot.player==main.world.player.position, "map snapshot reflects actual world")
	main._close()
	main._show_album()
	await _frames(3)
	var selector: OptionButton=main.overlay.find_child("AlbumRegionSelector",true,false)
	var book: Node=selector.get_parent().get_parent()
	_check(book._region=="harbor" and book._entries().size()==1 and book._entries()[0].id=="photo-harbor-game-1", "harbor collection shows delivered local first game")
	selector.select(0)
	selector.item_selected.emit(0)
	_check(book._region=="welcome" and book._entries().size()==18, "switching back retains welcome's original eighteen sources")
	main._close()
	main._show_tasks()
	_check(_labels(main.overlay).contains("沒有當地任務") and main.overlay.find_child("Task_quest-001",true,false)==null, "harbor tasks explain welcome destination")
	main._close()
	main._show_settings()
	Progress.set_setting("ui_scale",1.25)
	main._close()
	_check(main.audio._active_context=="harbor" and main.world.visible and not main.world.blocked, "settings returns to harbor audio and input")
	main._launch_game("game-001",false)
	_check(main.session!=null, "existing welcome game guide remains usable")
	main._cancel_game()
	_check(main.session==null and main.world_region=="harbor" and main.audio._active_context=="harbor", "cancel welcome minigame restores harbor audio")
	_check(_snapshot()==before, "menus, settings and game cancellation grant nothing")

func _failure_process() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var child_path := save_path.get_base_dir().path_join("travel-failure-child/progress.json")
	OS.set_environment("SNAPLAND_SAVE_PATH",child_path)
	var output: Array=[]
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--audio-driver","Dummy","--rendering-method","gl_compatibility","--max-fps","120","--quit-after","3600","res://game/tests/test_region_travel.tscn","--","--region-travel-failure-child"],output,true)
	OS.set_environment("SNAPLAND_SAVE_PATH",save_path)
	var expected := "ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path
	var errors: Array[String]=[]
	var passed := false
	var child_output := str(output[0] if not output.is_empty() else "")
	for line in child_output.split("\n"):
		var clean := line.strip_edges()
		if clean.contains("ERROR:"): errors.append(clean)
		if clean=="PASS: region travel failed save retains live world and permits retry": passed=true
	_check(code==0 and passed and errors==[expected], "isolated travel IO failure: exit=%d passed=%s expected=%s errors=%s output_tail=%s" % [code,passed,expected.left(500),JSON.stringify(errors).left(1000),child_output.right(3000)])

func _failure_child() -> void:
	Progress.reset_progress()
	Progress.intro_seen=true
	for index in range(1,7): Progress.photos["photo-welcome-game-%d"%index]={}
	_check(Progress.save_progress(), "failure fixture saves")
	await _spawn()
	main._interact("gate:harbor","潮汐碼頭")
	var old: Node=main.world
	var player: Transform3D=old.player.transform
	var camera: Transform3D=old.camera.transform
	var flags := [old.blocked,old.is_processing(),old.is_physics_processing(),main.modal_kind]
	var before := _snapshot()
	var path := Progress._save_path()
	var saved := FileAccess.get_file_as_string(path)
	_check(DirAccess.make_dir_absolute(path+".tmp")==OK, "block temporary write")
	_check(not main._travel_to_region("harbor"), "failed durable write rejects travel")
	_check(main.world==old and Progress.current_region=="welcome" and main.world_region=="welcome" and not main.changing_region, "failure retains world identity and region flags")
	_check(old.player.transform==player and old.camera.transform==camera and flags==[old.blocked,old.is_processing(),old.is_physics_processing(),main.modal_kind], "failure retains player camera and input/modal state")
	_check(_snapshot()==before and FileAccess.get_file_as_string(path)==saved and main.toast.text.contains("再試"), "failure leaves save/rewards intact with retry message")
	DirAccess.remove_absolute(path+".tmp")
	_check(main._travel_to_region("harbor"), "same gate supports retry")
	await _frames(4)
	_check(main.world_region=="harbor" and not is_instance_valid(old), "retry reaches harbor")
	await _dispose()
	for failure in failures: push_error("FAIL: "+failure)
	if failures.is_empty(): print("PASS: region travel failed save retains live world and permits retry")
	get_tree().quit(0 if failures.is_empty() else 1)

func _spawn() -> void:
	main=MainScene.instantiate()
	get_tree().root.add_child(main)
	await _frames(3)

func _point(id: String) -> Dictionary:
	for point in main.world.points:
		if point.id==id: return point
	return {}

func _world_count() -> int:
	var count := 0
	for child in main.get_children():
		if child is Node3D: count+=1
	return count

func _labels3d(node: Node) -> String:
	var text := str(node.text) if node is Label3D else ""
	for child in node.get_children(): text+=_labels3d(child)
	return text

func _labels(node: Node) -> String:
	var text := str(node.text) if node is Label else ""
	for child in node.get_children(): text+=_labels(child)
	return text

func _snapshot() -> Dictionary:
	var result := {}
	for field in ["coins","photos","achievements","quests","visited","appearance","equipped","owned_clothes","_extra_fields"]:
		var value = Progress.get(field)
		result[field]=value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _frames(count: int) -> void:
	for index in range(count): await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition: failures.append(reason)

func _dispose() -> void:
	if not is_instance_valid(main): return
	main.quitting=true
	main.audio.shutdown()
	main.world.area_changed.emit("海風碼頭")
	await get_tree().create_timer(0.2).timeout
	_check(main.audio._active_context.is_empty(), "pending area events respect quitting")
	main.free()
	main=null
	await _frames(3)

func _finish() -> void:
	await _dispose()
	for failure in failures: push_error("FAIL: "+failure)
	if failures.is_empty(): print("PASS: region travel admission, lifecycle, scoped UI, restart, and unchanged rewards")
	get_tree().quit(0 if failures.is_empty() else 1)
