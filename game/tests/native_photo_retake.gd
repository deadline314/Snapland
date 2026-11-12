extends Node
## Automated GUI/fixed-step evidence, not human play. Exported packs exclude
## tests: copy this file AND retake_native_route.gd into one external directory.
const Catalog = preload("res://game/core/game_catalog.gd")
var Route: Script = adjacent_route(get_script().resource_path)
var main: Node
var failures: Array[String] = []
var out := ""
var profile := ""
var mode := ""
var captures: Array[Dictionary] = []
var results: Array[Dictionary] = []

static func adjacent_route(owner_path: String) -> Script:
	var path := owner_path.get_base_dir().path_join("retake_native_route.gd")
	return load(path) if FileAccess.file_exists(path) else null

func _ready() -> void:
	get_tree().create_timer(85).timeout.connect(func(): push_error("Native retake85second watchdog"); get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	out = OS.get_environment("RETAKE_CAPTURE_DIR")
	profile = OS.get_environment("SNAPLAND_SAVE_PATH")
	mode = OS.get_environment("RETAKE_REVIEW_MODE")
	if Route == null or not out.is_absolute_path() or not profile.is_absolute_path() or mode not in ["welcome","harbor","read"] or DisplayServer.get_name() == "headless":
		push_error("Native retake requires adjacent helper, GPU, absolute isolated save/capture paths and welcome|harbor|read mode")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	get_window().content_scale_size = Vector2i(1280,720)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var before := FileAccess.get_file_as_bytes(profile) if FileAccess.file_exists(profile) else PackedByteArray()
	if mode != "read":
		if not before.is_empty():
			push_error("Native retake writer requires a fresh isolated profile")
			get_tree().quit(1)
			return
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		Progress.settings.ui_scale = 1.25 if OS.get_environment("RETAKE_LARGE_TEXT") == "1" else 1.0
		Progress.settings.reduced_motion = OS.get_environment("RETAKE_LARGE_TEXT") == "1"
		check(Progress.save_progress(), "fresh review settings persist")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(6)
	if mode == "read":
		check(not before.is_empty(), "reader requires raw actual writer save")
		await read_actual()
		check(FileAccess.get_file_as_bytes(profile) == before, "reader leaves actual writer JSON bytes unchanged")
	else:
		if mode == "harbor":
			# Synthetic OLD harbor prerequisites only; never overwrite real photos.
			for index in range(1,7):
				var old_id := "photo-welcome-game-%d" % index
				if not Progress.photos.has(old_id): Progress.grant_photo(old_id)
			print("SETUP: only missing six OLD welcome prerequisites are synthetic; harbor target and attempts must be real")
			check(main._travel_to_region("harbor"), "six old cards admit actual harbor travel")
			await frames(8)
		await acquire_region("game-013" if mode == "harbor" else "game-001")
		if mode == "welcome": await natural_failure()
		else:
			main._close()
			check(main._travel_to_region("welcome"), "harbor return is free")
			await frames(8)
			await shot("free-return")
			check(main._travel_to_region("harbor"), "actual harbor reentry")
			await frames(8)
		check(Progress.save_progress(), "writer final save")
	await finish()

func acquire_region(id: String) -> void:
	var identity := Catalog.identity(id)
	print("INPUT: kiosk/album entry methods are programmatic; buttons use normal GUI-routed keyboard events")
	main._show_game_info(id)
	main._show_game_rules(id)
	await shot("kiosk-rules")
	check(not Progress.has_attempted_game(id), "kiosk invitation/rules do not invent attempt")
	await activate(main.overlay,"KioskRetakeDevil")
	check(main.session != null and main.session.practice_mode and Progress.has_attempted_game(id), "Main starts actual selected practice and persists attempt")
	if main.session == null: return
	await activate(main.session,"PauseButton")
	await activate(main.session,"LeaveButton")
	await activate(main.session,"ConfirmAction")
	check(main.modal_kind == "retake" and main.retake_target == {"id":id,"devil":true}, "actual HUD cancel preserves selected devil")
	check(not Progress.photos.has(identity.photo_id) and not Progress.photos.has(identity.devil_photo_id), "practice/cancel grants neither target card")
	# Raw actual save copy BEFORE either target award. No JSON construction/editing.
	check(DirAccess.copy_absolute(profile,out.path_join("attempt-only.json")) == OK, "unedited actual attempt-only snapshot")
	await shot("observe-devil")
	await arrange("devil")
	if mode == "welcome":
		check(DirAccess.make_dir_recursive_absolute(profile+".tmp") == OK, "isolated award-save obstruction")
		await activate(main.retake_panel,"RetakeShutter")
		await frames(8)
		check(not Progress.photos.has(identity.devil_photo_id) and not main.retake_panel._saved, "real failed save cannot claim target")
		check(main.retake_panel._status.text.contains("重試"), "visible save failure permits retry")
		await shot("save-failure")
		check(DirAccess.remove_absolute(profile+".tmp") == OK, "remove only owned obstruction")
	var coins: int = Progress.coins
	await shutter(identity.devil_photo_id,"saved-devil")
	check(Progress.coins == coins+40 and Progress.wardrobe_rewarded_games.count(id) == 1, "actual first target earns one40coin receipt")
	check(not Progress.photos.has(identity.photo_id), "selected devil leaves missing ordinary absent")
	await activate(main.retake_panel,"RetakeClose")
	main._show_achievements()
	await frames()
	var tile: Node = main.overlay.find_child("AchievementStamp_"+str(identity.achievement_id),true,false)
	var condition: Label = tile.find_child("StampCondition",true,false) if tile != null else null
	check(Progress.achievements.has(identity.achievement_id) and condition != null and condition.text.contains("首張拍貼"), "first devil-only actual stamp describes first card")
	await shot("first-devil-only-stamp")
	main._close()
	main._show_album()
	var book := album()
	book._set_category("devil")
	await focus_photo(identity.devil_photo_id)
	await shot("devil-provenance")
	# Clicking the collected card follows the actual original-photo viewer route.
	await activate(main.overlay,"AlbumPhoto_"+str(identity.devil_photo_id))
	check(main.ui.find_child("PhotoViewer",true,false) != null, "collected tile opens actual original viewer")
	await shot("devil-original-viewer")
	main._close()
	main._show_game_info(id)
	main._show_game_rules(id)
	var stable_photos := Progress.photos.duplicate(true)
	var stable_coins: int = Progress.coins
	var collected_button: Button = main.overlay.find_child("KioskRetakeDevil",true,false)
	check(collected_button == null, "collected target removes repeat kiosk action")
	print("INPUT: supplemental programmatic repeated collected-card request; no gameplay/result mutation")
	main._request_retake(id,true)
	check(Progress.coins == stable_coins and Progress.photos == stable_photos and main.retake_panel == null, "repeat collected-card request grants no payout")
	main._close()
	main._show_album()
	book = album()
	book._set_category("normal")
	await focus_photo(identity.photo_id)
	check(main.overlay.find_child("AlbumPhoto_"+str(identity.photo_id),true,false).tooltip_text == "免費補拍", "attempted missing card has concise next-action tooltip")
	await shot("album-missing-ordinary")
	await activate(main.overlay,"AlbumPhoto_"+str(identity.photo_id))
	check(main.modal_kind == "retake", "album opens selected ordinary from real saved attempt")
	await activate(main.retake_panel,"RetakeClose")
	check(main.retake_panel == null, "cancel closes without award")
	main._show_album()
	album()._set_category("normal")
	await activate(main.overlay,"AlbumPhoto_"+str(identity.photo_id))
	var old_record: Dictionary = Progress.photos[identity.devil_photo_id].duplicate(true)
	var old_bytes := photo_bytes(old_record)
	await arrange("ordinary")
	await shutter(identity.photo_id,"saved-ordinary")
	check(Progress.coins == stable_coins and Progress.wardrobe_rewarded_games.count(id) == 1, "second selected kind never pays again")
	check(Progress.photos[identity.devil_photo_id] == old_record and photo_bytes(old_record) == old_bytes, "ordinary preserves genuine devil metadata and PNG bytes")
	await activate(main.retake_panel,"RetakeClose")
	main._show_album()
	await focus_photo(identity.photo_id)
	await shot("ordinary-provenance")
	main._close()

func arrange(label: String) -> void:
	var panel: Control = main.retake_panel
	if panel == null:
		check(false,"actual panel exists for "+label)
		return
	check(panel.current_step == 0, "public route starts at demonstration")
	await activate(panel,"RetakeNext")
	check(panel.current_step == 1, "public Next reaches adjustable set")
	await frames()
	var before: PackedByteArray = panel._viewport.get_texture().get_image().get_data()
	await shot(label+"-set-before")
	var framing: Button = panel.find_child("FramingChoice",true,false)
	framing.grab_focus()
	await Route.key(get_viewport(),KEY_TAB)
	check(get_viewport().gui_get_focus_owner() == panel.find_child("DecorationChoice",true,false), "normal Tab reaches next sequential choice")
	await Route.key(get_viewport(),KEY_ENTER)
	await activate(panel,"FramingChoice")
	await frames()
	check(panel._viewport.get_texture().get_image().get_data() != before, "visible UI choices change actual rendered set")
	await shot(label+"-set-after")
	await activate(panel,"RetakeBack")
	check(panel.current_step == 0, "public Back returns to demonstration")
	await activate(panel,"RetakeNext")
	await activate(panel,"RetakeNext")
	check(panel.current_step == 2, "third public step reaches actual shutter")

func shutter(photo_id: String, label: String) -> void:
	var photograph: Image = main.retake_panel._viewport.get_texture().get_image()
	photograph.convert(Image.FORMAT_RGBA8)
	await activate(main.retake_panel,"RetakeShutter")
	await frames(8)
	check(main.retake_panel._saved and Progress.photos.has(photo_id), "real rendered shutter saves "+photo_id)
	validate_photo(photo_id)
	var record: Dictionary = Progress.photos.get(photo_id,{})
	if record.get("original_frames",[]).size() == 1:
		var stored := Image.load_from_file(record.original_frames[0])
		stored.convert(Image.FORMAT_RGBA8)
		check(stored.get_data() == photograph.get_data(), "saved original equals actual arranged set pixel-for-pixel")
	await shot(label)

func validate_photo(photo_id: String) -> void:
	var record: Dictionary = Progress.photos.get(photo_id,{})
	check(record.get("acquisition_method","") == "retake" and not record.get("challenge_earned",true), "truthful retake provenance "+photo_id)
	check(record.get("frames",[]).size() == 1 and record.get("original_frames",[]).size() == 1, "one actual thumbnail/original "+photo_id)
	for path in record.get("frames",[]):
		check(Image.load_from_file(path).get_size() == Vector2i(320,180), "actual thumbnail decodes320x180")
	for path in record.get("original_frames",[]):
		check(Image.load_from_file(path).get_size() == Vector2i(1280,720), "actual retake original decodes1280x720")

func natural_failure() -> void:
	main._launch_game("game-003",false)
	var session: Control = main.session
	check(session != null, "Main launches actual no-input fountain round")
	if session == null: return
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	# Disable automatic processing only to advance the normal process at fixed0.1s.
	# No result, score, timer, model state or finish method is assigned/called.
	session.set_process(false)
	print("TIMING: no-input legacy fountain uses normal Session._process fixed0.1s, auto-process disabled")
	for index in 400:
		if main.session == null: break
		session._process(0.1)
		if index % 8 == 0: await frames(1)
	await frames(8)
	check(results.size() == 1 and not results[0].success and results[0].ordinary_eligible and not results[0].devil, "natural failed result stays false and ordinary-only")
	check(Progress.photos.has("photo-welcome-game-3") and not Progress.photos.has("photo-welcome-devil-3") and not main.celebrate_on_close, "failed participation never grants devil or success celebration")
	print("ACTUAL RESULT: ",JSON.stringify(results))
	await shot("natural-failed-participation")
	main._close()

func read_actual() -> void:
	var count := 0
	for id in ["game-001","game-013"]:
		var identity := Catalog.identity(id)
		if not Progress.photos.has(identity.devil_photo_id): continue
		count += 1
		check(Progress.has_attempted_game(id) and Progress.wardrobe_rewarded_games.count(id) == 1, "restart reads actual attempt/one receipt")
		validate_photo(identity.devil_photo_id)
		validate_photo(identity.photo_id)
	check(count > 0, "reader finds real writer target collection")
	main._show_album()
	await shot("restart-album")
	main._close()
	main._show_achievements()
	await shot("restart-stamps")
	main._close()

func photo_bytes(record: Dictionary) -> Dictionary:
	var bytes: Dictionary = {}
	for path in record.get("frames",[])+record.get("original_frames",[]): bytes[path] = FileAccess.get_file_as_bytes(path)
	return bytes

func album() -> Control:
	for child in main.overlay.find_children("*","Control",true,false):
		if child.has_signal("retake_requested"): return child
	return null

func focus_photo(id: String) -> void:
	var tile: Control = main.overlay.find_child("AlbumPhoto_"+id,true,false)
	check(tile != null,"actual album tile "+id)
	if tile != null: tile.grab_focus()
	await frames()

func activate(root: Node, name: String) -> void:
	await frames(2)
	var button: Button = root.find_child(name,true,false) if root != null else null
	check(button != null and button.is_visible_in_tree() and not button.disabled,"visible enabled UI control "+name)
	if button != null and button.is_visible_in_tree() and not button.disabled: await Route.activate(button)
	await frames(2)

func shot(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.get_size() == get_window().size, "rendered PNG equals actual OS window dimensions")
	check(image.save_png(out.path_join(label+".png")) == OK,"screenshot "+label)
	var row := {"label":label,"os_window":str(DisplayServer.window_get_size()),"window":str(get_window().size),"logical_viewport":str(get_viewport().get_visible_rect().size),"png":str(image.get_size())}
	captures.append(row)
	print("CAPTURE: ",JSON.stringify(row))

func frames(count: int = 4) -> void:
	for index in count: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("FAIL: "+message)

func finish() -> void:
	main.audio.shutdown()
	main.queue_free()
	await frames(4)
	await get_tree().create_timer(0.15).timeout
	var report := FileAccess.open(out.path_join("native-report.json"),FileAccess.WRITE)
	if report != null: report.store_string(JSON.stringify({"mode":mode,"profile":profile,"captures":captures,"failures":failures,"results":results},"\t"))
	if failures.is_empty(): print("PASS: native retake "+mode+" actual UI, selected photos, provenance and restart contract")
	get_tree().quit(0 if failures.is_empty() else 1)
