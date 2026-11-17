extends "res://game/tests/native_sugar_bridge_main.gd"
## Scripted GPU Main routes. Only six welcome admission cards/opening are synthetic.
const SyrupView = preload("res://game/minigames/syrup_flood_view.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
var checks := 0
var original_hashes: Dictionary = {}
var physical_results: Array[Dictionary] = []
var gameplay_history: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func completion_marker() -> String:
	return "PASS: native syrup Main genuine inputs, tanks, cold plug, originals and restart"

func _run() -> void:
	review_game_id = "game-027"
	output = OS.get_environment("SYRUP_CAPTURE_DIR")
	mode = OS.get_environment("SYRUP_REVIEW_MODE")
	var dimensions := OS.get_environment("SYRUP_REVIEW_SIZE").split("x")
	if dimensions.size() == 2: requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or requested not in [Vector2i(1280,720),Vector2i(1152,648),Vector2i(800,600)]:
		push_error("Native syrup requires GPU and isolated supported paths/size")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = requested
	get_window().size = requested
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		Progress.settings.ui_scale = 1.25 if requested.x == 800 else 1.0
		Progress.settings.reduced_motion = requested.x == 800
		Progress.settings.fullscreen = false
		for i in range(1,7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SYNTHETIC ADMISSION ONLY: six welcome cards/opening seen; no027 state/result/photo/reward")
		check(Progress.set_current_region("candy"), "synthetic six-card admission")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(8)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual physical viewport")
	check(Catalog.identity("game-027").local_index == 3 and Catalog.identity("game-027").achievement_id == "ACH_GAME_027", "fixed local3/global027")
	if mode == "read":
		await read_profile()
		await finish()
		return
	# Controlled actor placement to test the real nearest/E route, never claimed as walking.
	print("CONTROLLED FIXTURE ACTOR PLACEMENT: (7,GROUND_Y,-6), not walked")
	main.world.player.position = Vector3(7,main.world.GROUND_Y,-6)
	main.world.player.velocity = Vector3.ZERO
	for i in 4: await get_tree().physics_frame
	check(main.world.nearest.get("id", "") == "game-027", "real physical entrance nearest")
	await capture("factory-entrance")
	await key(KEY_E)
	check(main.modal_kind == "game_info", "real E opens physical027 invitation")
	await capture("invite")
	await activate(main.overlay,"InviteRules")
	var rule_pages := ["goal","instructions","devil","participation","assist"]
	var rule_copy := ["本局目標","操作方式","小惡魔","參與操作","輔助遊玩"]
	var pager: Control = main.overlay.find_child("GameRulesExtraDetails",true,false)
	check(pager != null and pager.get_meta("page_count",0) == 5,"actual rules have five ordered pages")
	for page in 5:
		check(pager.get_meta("page_index",-1) == page and visible_copy(pager).contains(rule_copy[page]),"actual ordered rules page " + rule_pages[page])
		await capture("rules-" + rule_pages[page])
		if page < 4: await activate(main.overlay,"GameRulesExtraDetailsNext")
	main._close()
	main._show_map()
	await frames(3)
	await capture("map")
	await activate(main.overlay,"RegionGamesButton")
	check(main.overlay.find_child("RegionalGameEntriesGrid",true,false).get_child_count() == 3,"real map lists exactly3 factory games")
	await capture("map-entries")
	await activate(main.overlay,"HarborGamegame-027")
	check(main.modal_kind == "game_info", "real regional map callback opens027")
	await activate(main.overlay,"InviteStart")
	check(is_instance_valid(main.tutorial_panel),"first entry real tutorial")
	if not is_instance_valid(main.tutorial_panel):
		await finish()
		return
	for i in 3:
		check(main.tutorial_panel._image.texture != null,"real lesson PNG %d decoded" % i)
		await capture("tutorial-%d" % (i+1))
		await scan_controls(main.tutorial_panel,"tutorial%d" % i)
		if i < 2: await press_button(main.tutorial_panel._next_button)
	await press_button(main.tutorial_panel._start_button)
	await bind_session()
	if main.session == null:
		await finish()
		return
	await control_scan()
	if mode.begins_with("retake"):
		await native_retake(mode == "retake-devil")
	else:
		await complete_route(false,false,"ordinary")
		var first: Dictionary = Progress.photos.get("photo-candy-game-3",{}).duplicate(true)
		var coins: int = Progress.coins
		await launch(false)
		await complete_route(true,false,"devil")
		check(Progress.coins == coins and Progress.photos.get("photo-candy-game-3",{}) == first,"repeated game deduplicates money and original card")
		await launch(true)
		await complete_route(true,true,"assisted-ai")
		check(Progress.coins == coins,"assisted completion no repeated receipt")
		await launch(false)
		await key(KEY_SPACE)
		await key(KEY_SPACE)
		await advance(76)
		await frames(8)
		check(main.session == null and results.back().ordinary_eligible and not results.back().success,"actual participated timeout honestly fails")
		await capture("timeout-result")
		record_gameplay("timeout")
		check(Progress.coins == coins,"timeout duplicate no reward")
		await launch(false,true)
		await solve(true,false)
		await frames(8)
		check(main.session == null and Progress.coins == coins,"real success practice awards nothing")
		await capture("practice-result")
		await launch(false)
		await key(KEY_SPACE)
		await key(KEY_ESCAPE)
		check(session.paused,"real Esc pauses Session")
		await capture("pause")
		await activate(session.minigame_hud,"LeaveButton")
		await activate(session.minigame_hud,"ConfirmAction")
		await frames(5)
		check(main.session == null and Progress.coins == coins,"actual HUD cancel has no awards")
	main._close()
	main._show_album()
	await frames(4)
	await capture("album")
	check(not Progress.photos.has("photo-candy-game-1") and not Progress.photos.has("photo-candy-game-2"),"027 does not grant older factory cards")
	check(Progress.save_progress(),"actual profile writer")
	await write_original_receipt()
	await finish()

func press_button(button: Button) -> void:
	check(button != null and button.is_visible_in_tree() and not button.disabled,"enabled visible actual GUI button")
	if button == null or button.disabled: return
	button.grab_focus()
	await key(KEY_ENTER)
	await frames(3)

func bind_session() -> void:
	await frames(4)
	session = main.session
	check(session != null and session.game_id == "game-027","real Main027 Session")
	if session == null: return
	session.set_process(false)
	session.presentation.grab_focus()
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))

func launch(assisted: bool, practice: bool = false) -> void:
	main._close()
	main._launch_game("game-027",assisted,practice)
	await bind_session()

func select_branch(index: int) -> void:
	for i in 3:
		if session.active_driver.snapshot().selected == index: return
		await key(KEY_TAB)
	check(session.active_driver.snapshot().selected == index,"real focused Tab selects branch")

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = session.presentation.get_global_transform_with_canvas() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)
	if main.session != null: session._process(0)

func tap_command(command: String, use_touch: bool = false) -> void:
	var point := SyrupView.button_rect(command).get_center()
	if use_touch:
		await touch(point,true)
		await touch(point,false)
	else:
		await pointer(point,"press")
		await pointer(point,"release")

func control_scan() -> void:
	await scan_controls(session.minigame_hud,"MainHUD")
	for command in SyrupView.COMMANDS:
		var rect: Rect2 = session.presentation.get_global_transform_with_canvas() * SyrupView.button_rect(command)
		check(get_viewport().get_visible_rect().grow(0.5).encloses(rect),"Main composite control fits: " + command)
	await tap_command("configuration",true)
	check(session.active_driver.snapshot().configuration_paused,"real touch C route")
	await tap_command("next")
	check(session.active_driver.snapshot().selected == 1,"real mouse next")
	await tap_command("previous",true)
	check(session.active_driver.snapshot().selected == 0,"real touch previous")
	await tap_command("heater")
	check(session.active_driver.snapshot().heater == 0,"mouse heat")
	await tap_command("heater",true)
	await select_branch(1)
	await tap_command("diversion")
	check(session.active_driver.snapshot().diversion,"mouse bypass")
	await tap_command("diversion",true)
	await tap_command("helper")
	check(session.active_driver.snapshot().helper == 1,"mouse designatedAI")
	await tap_command("helper",true)
	await tap_command("drain")
	await pointer(SyrupView.valve_point(2),"press")
	await pointer(SyrupView.valve_point(2),"release")
	check(session.active_driver.snapshot().branches[2].valve,"actual3D valve mouse")
	await touch(SyrupView.valve_point(2),true)
	await touch(SyrupView.valve_point(2),false)
	check(not session.active_driver.snapshot().branches[2].valve,"actual3D valve touch")
	await capture("configuration-controls")
	await tap_command("configuration")
	await select_branch(0)

func scan_controls(node: Node, label: String) -> void:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree():
			check(get_viewport().get_visible_rect().grow(0.5).encloses(child.get_global_rect()),label+" visible full button "+child.name)
		await scan_controls(child,label)

func visible_copy(node: Node) -> String:
	var text: String = node.text if node is Label and node.is_visible_in_tree() else ""
	for child in node.get_children(): text += "\n" + visible_copy(child)
	return text

func capture(label: String, tutorial_step: int = 0) -> void:
	await frames(2)
	if is_instance_valid(main):
		await scan_controls(main.overlay,label)
		if main.session != null: await scan_controls(main.session.minigame_hud,label+"HUD")
	await super.capture(label,tutorial_step)

func record_gameplay(label: String) -> void:
	var hashes := photo_hashes()
	for id in hashes:
		var record: Dictionary = Progress.photos[id]
		for path in record.get("original_frames",[]):
			var image := Image.load_from_file(path)
			check(image != null and image.get_size() == requested,label+" actual full viewport original bounds")
		for path in record.get("frames",[]):
			var image := Image.load_from_file(path)
			check(image != null and image.get_size() == Vector2i(320,180),label+" bounded thumbnail decodes")
	if hashes.has("photo-candy-game-3") and hashes.has("photo-candy-devil-3"):
		check(hashes["photo-candy-game-3"] == hashes["photo-candy-devil-3"],label+" normal/devil share refreshed gameplay originals")
	gameplay_history.append({"label":label,"hashes":hashes,"coins":Progress.coins})

func complete_route(plug: bool, assisted: bool, label: String) -> void:
	var coins: int = Progress.coins
	var first := not Progress.achievements.has("ACH_GAME_027")
	await solve(plug,assisted,label)
	await frames(8)
	check(main.session == null and not results.is_empty(),label+" natural Main result")
	if results.is_empty(): return
	var result: Dictionary = results.back()
	check(result.success and result.devil == plug and result.ordinary_eligible,label+" genuine physical result")
	check(Progress.coins == coins + (40 if first else 0),label+" strict first40 coin receipt")
	check(Progress.achievements.has("ACH_GAME_027") and photo_valid("photo-candy-game-3"),label+" fixed card/achievement actual PNG")
	if plug: check(photo_valid("photo-candy-devil-3") and Progress.photos["photo-candy-devil-3"].challenge_earned,label+" real cold plug proof")
	record_gameplay(label)
	await capture(label+"-result")

func solve(plug: bool, assisted: bool, label: String = "practice") -> void:
	var driver = session.active_driver
	for i in 3:
		await select_branch(i)
		await key(KEY_SPACE)
	if plug:
		await select_branch(1)
		await key(KEY_F)
	await select_branch(0)
	await key(KEY_H)
	if assisted: await key(KEY_R)
	var shown_plug := false
	var shown_heat := false
	var helper_closed := false
	for step in 4600:
		if main.session == null: break
		var state: Dictionary = session.active_driver.snapshot()
		if state.ended:
			physical_results.append(state)
			session._process(1.0/60.0)
			break
		if assisted and state.helper >= 0 and not state.branches[state.helper].valve: helper_closed = true
		for i in 3:
			if state.branches[i].valve and state.branches[i].fill >= state.branches[i].capacity*0.92:
				await select_branch(i)
				await key(KEY_SPACE)
				if main.session == null: break
		if main.session == null:
			physical_results.append(driver.snapshot())
			break
		state = session.active_driver.snapshot()
		if not state.ended:
			for i in 3:
				if state.branches[i].fill >= state.branches[i].capacity*0.92 or (i == 1 and state.diversion): continue
				if state.heater != i:
					await select_branch(i)
					await key(KEY_H)
					if assisted:
						await key(KEY_R)
				break
		if state.elapsed > 10 and not shown_heat:
			await capture(label+"-live-heat-tanks")
			shown_heat = true
		if state.cold_plugged and not shown_plug:
			await capture(label+"-actual-cold-plug")
			shown_plug = true
		session._process(1.0/60.0)
		if step % 30 == 0: await frames(1)
	check(main.session == null,label+" final valve followed by natural Session process")
	if assisted: check(helper_closed,"designated AI actually closed a92percent tank")

func native_retake(devil: bool) -> void:
	var target := "photo-candy-devil-3" if devil else "photo-candy-game-3"
	var other := "photo-candy-game-3" if devil else "photo-candy-devil-3"
	main._cancel_game(false)
	main._practice_for_retake("game-027",devil)
	await bind_session()
	await key(KEY_SPACE)
	await key(KEY_ESCAPE)
	await activate(session.minigame_hud,"LeaveButton")
	await activate(session.minigame_hud,"ConfirmAction")
	await frames(5)
	check(main.modal_kind == "retake" and not Progress.photos.has(target) and not Progress.photos.has(other),"actual practice cancel returns selected retake with zero027 cards")
	if main.retake_panel == null: return
	await capture("retake-demonstration")
	await activate(main.retake_panel,"RetakeNext")
	await activate(main.retake_panel,"DecorationChoice")
	await activate(main.retake_panel,"FramingChoice")
	await capture("retake-arranged")
	await activate(main.retake_panel,"RetakeNext")
	await RenderingServer.frame_post_draw
	var photograph: Image = main.retake_panel._viewport.get_texture().get_image()
	photograph.convert(Image.FORMAT_RGBA8)
	var coins: int = Progress.coins
	await activate(main.retake_panel,"RetakeShutter")
	await frames(8)
	var record: Dictionary = Progress.photos.get(target,{}).duplicate(true)
	check(main.retake_panel._saved and record.get("acquisition_method","") == "retake" and not record.get("challenge_earned",true),"realGPU retake honest provenance")
	check(not Progress.photos.has(other) and Progress.coins == coins+40 and Progress.achievements.has("ACH_GAME_027"),"selected-only retake exact first40 reward")
	check(photo_valid(target),"retake real original+320x180 thumbnail")
	if record.get("original_frames",[]).size() == 1:
		var stored := Image.load_from_file(record.original_frames[0])
		stored.convert(Image.FORMAT_RGBA8)
		check(stored.get_data() == photograph.get_data(),"stored original equals actual arranged GPU pixels")
	await capture("retake-saved")
	await activate(main.retake_panel,"RetakeClose")
	var hashes := photo_hashes()
	await launch(devil)
	await solve(devil,devil,"after-retake")
	await frames(8)
	var earned: Dictionary = Progress.photos.get(target,{})
	check(earned.get("acquisition_method","") == "retake" and earned.get("original_frames",[]) == record.get("original_frames",[]) and photo_hashes().get(target,{}) == hashes.get(target,{}),"real later challenge preserves retake original bytes")
	check(Progress.coins == coins+40 and (not devil or earned.get("challenge_earned",false)),"later actual challenge has proof without second reward")
	await capture("after-retake-result")

func photo_hashes() -> Dictionary:
	var hashes := {}
	for id in ["photo-candy-game-3","photo-candy-devil-3"]:
		if not Progress.photos.has(id): continue
		var record: Dictionary = Progress.photos[id]
		var files := {}
		for path in record.get("original_frames",[]): files[path] = FileAccess.get_sha256(path)
		hashes[id] = files
	return hashes

func write_original_receipt() -> void:
	var file := FileAccess.open(OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("native-originals.json"),FileAccess.WRITE)
	check(file != null,"original provenance receipt writable")
	if file != null: file.store_string(JSON.stringify({"hashes":photo_hashes(),"coins":Progress.coins,"photos":Progress.photos},"\t"))

func read_profile() -> void:
	var receipt_path := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("native-originals.json")
	var expected = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	check(expected is Dictionary,"new process reads original writer provenance receipt")
	if not expected is Dictionary: return
	check(Progress.current_region == "candy" and Progress.has_seen_tutorial("game-027") and Progress.achievements.has("ACH_GAME_027"),"new process restores actual region/lesson/global027")
	check(photo_hashes() == expected.hashes and Progress.coins == int(expected.coins),"new process preserves every original SHA and exact coin receipt")
	for id in expected.hashes: check(photo_valid(id),"new process decodes original+thumbnail "+id)
	main._show_album()
	await frames(4)
	await capture("restart-album")

func finish() -> void:
	var extra := FileAccess.open(output.path_join("physical-report.json"),FileAccess.WRITE)
	if extra != null: extra.store_string(JSON.stringify({"checks":checks,"physical_results":physical_results,"original_hashes":photo_hashes(),"gameplay_capture_history":gameplay_history,"failures":failures,"synthetic_setup":"six welcome cards/opening only","actor_placement":"(7,GROUND_Y,-6); controlled fixture, not walked"},"\t"))
	await super.finish()
