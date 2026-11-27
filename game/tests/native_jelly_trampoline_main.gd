extends "res://game/tests/native_sugar_bridge_main.gd"
## Scripted GPU Main routes. Only six welcome admission cards/opening are synthetic.
const JellyView = preload("res://game/minigames/jelly_trampoline_view.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
var checks := 0
var original_hashes: Dictionary = {}
var physical_results: Array[Dictionary] = []
var gameplay_history: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func completion_marker() -> String:
	return "PASS: native jelly Main genuine inputs, real fruit bell deliveries, GPU originals and restart"

func _run() -> void:
	review_game_id = "game-028"
	output = OS.get_environment("JELLY_CAPTURE_DIR")
	mode = OS.get_environment("JELLY_REVIEW_MODE")
	var dimensions := OS.get_environment("JELLY_REVIEW_SIZE").split("x")
	if dimensions.size() == 2: requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or not output.is_absolute_path() or requested not in [Vector2i(1280,720),Vector2i(1152,648),Vector2i(800,600)]:
		push_error("Native jelly requires GPU and isolated supported paths/size")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = requested
	get_window().size = requested
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		preload("res://game/tests/calm_daily_picks.gd").settle(Progress)
		Progress.prologue_seen = true
		Progress.settings.ui_scale = 1.25 if requested.x == 800 else 1.0
		Progress.settings.reduced_motion = requested.x == 800
		Progress.settings.fullscreen = false
		for i in range(1,7): Progress.grant_photo("photo-welcome-game-%d" % i)
		print("SYNTHETIC ADMISSION ONLY: six welcome cards/opening seen; no028 state/result/photo/reward")
		check(Progress.set_current_region("candy"), "synthetic six-card admission")
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(8)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual physical viewport")
	check(Catalog.identity("game-028").local_index == 4 and Catalog.identity("game-028").achievement_id == "ACH_GAME_028", "fixed local4/global028")
	if mode == "read":
		await read_profile()
		await finish()
		return
	# Controlled sign setup separately verifies distance-gated visible text, not walking.
	print("CONTROLLED FIXTURE SIGN PLACEMENT: (0,GROUND_Y,-10.8), not walked")
	var candy: Node3D = main.region_world("candy")
	candy.place_player(Vector3(0,candy.GROUND_Y,-10.8))
	for i in 4: await get_tree().physics_frame
	var signs: Array = candy.local_sign_labels.filter(func(label: Label3D): return label.text.begins_with("工廠遊戲 "))
	check(signs.size() == 1 and signs[0].is_visible_in_tree() and signs[0].text == "工廠遊戲 %d／12" % Catalog.definitions("candy").size(),"current catalog-derived visible world sign")
	await capture("factory-visible-sign")
	# Controlled actor placement to test the real nearest/E route, never claimed as walking.
	print("CONTROLLED FIXTURE ACTOR PLACEMENT: (7,GROUND_Y,-1), not walked")
	candy.place_player(Vector3(7,candy.GROUND_Y,-1))
	for i in 4: await get_tree().physics_frame
	check(main.world.nearest.get("id", "") == "game-028", "real physical entrance nearest")
	await capture("factory-entrance")
	await key(KEY_E)
	check(main.modal_kind == "game_info", "real E opens physical028 invitation")
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
	check(main.overlay.find_child("RegionalGameEntriesGrid",true,false).get_child_count() == Catalog.definitions("candy").size(),"real map lists all factory games")
	await capture("map-entries")
	await activate(main.overlay,"HarborGamegame-028")
	check(main.modal_kind == "game_info", "real regional map callback opens028")
	await activate(main.overlay,"InviteStart")
	check(is_instance_valid(main.tutorial_panel),"first entry real tutorial")
	if not is_instance_valid(main.tutorial_panel):
		await finish()
		return
	for i in 3:
		check(main.tutorial_panel._image.texture != null,"real lesson PNG %d decoded" % i)
		await capture("tutorial-%d" % (i+1))
		await scan_controls(main.tutorial_panel,"tutorial%d" % i)
		for copy_page in range(1,main.tutorial_panel._copy_pages.size()):
			await activate(main.tutorial_panel,"TutorialCopyNext")
			check(main.tutorial_panel._copy_page == copy_page,"actual lesson semantic copy callback slide%d page%d" % [i+1,copy_page+1])
			await capture("tutorial-%d-copy-%d" % [i+1,copy_page+1])
			await scan_controls(main.tutorial_panel,"tutorial%d-copy%d" % [i+1,copy_page+1])
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
		var first_hashes := photo_hashes()
		var coins: int = Progress.coins
		await launch(false)
		await complete_route(true,false,"devil")
		check(Progress.coins == coins and photo_hashes().get("photo-candy-game-4",{}) != first_hashes.get("photo-candy-game-4",{}),"repeated gameplay refreshes latest originals while deduplicating money")
		await launch(true)
		await complete_route(true,true,"assisted-ai")
		await recovery_and_reset_checks()
		check(Progress.coins == coins,"assisted completion no repeated receipt")
		await launch(false)
		await charge(0.2)
		await advance(61)
		await frames(8)
		check(main.session == null and results.back().ordinary_eligible and not results.back().success,"actual participated timeout honestly fails")
		await capture("timeout-result")
		record_gameplay("timeout")
		check(Progress.coins == coins,"timeout duplicate no reward")
		await launch(false,true)
		await solve(true,false,"practice")
		await frames(8)
		check(main.session == null and Progress.coins == coins,"real success practice awards nothing")
		await capture("practice-result")
		await launch(false)
		await key_event(KEY_SPACE,true)
		await advance(0.4)
		await key(KEY_ESCAPE)
		check(session.paused and not session.active_driver.snapshot().charging,"real Esc pauses and clears unlaunched charge")
		var frozen: Dictionary = session.active_driver.snapshot()
		await advance(0.25)
		check(session.active_driver.snapshot() == frozen,"pause freezes actual time and fruit")
		await key_event(KEY_SPACE,false)
		await capture("pause")
		await activate(session.minigame_hud,"LeaveButton")
		await activate(session.minigame_hud,"ConfirmAction")
		await frames(5)
		check(main.session == null and Progress.coins == coins,"actual HUD cancel has no awards")
	main._close()
	main._show_album()
	await frames(4)
	await capture("album")
	main._close()
	main._show_achievements()
	await frames(4)
	check(main.overlay.find_child("MinigameStampGrid",true,false).get_child_count() == Catalog.definitions("candy").size(),"actual factory stamp book matches the catalog")
	await capture("achievement-book")
	check(not Progress.photos.has("photo-candy-game-1") and not Progress.photos.has("photo-candy-game-2") and not Progress.photos.has("photo-candy-game-3"),"028 does not grant older factory cards")
	check(Progress.wardrobe_rewarded_games.count("game-028") == 1,"exactly one fixed028 money receipt")
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
	check(session != null and session.game_id == "game-028","real Main028 Session")
	if session == null: return
	session.set_process(false)
	session.presentation.grab_focus()
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))

func launch(assisted: bool, practice: bool = false) -> void:
	main._close()
	main._launch_game("game-028",assisted,practice)
	await bind_session()

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)
	if main.session != null: session._process(0.0)

func advance(seconds: float) -> void:
	var left := seconds
	var steps := 0
	while left > 0.000000001 and main.session != null:
		var delta := minf(left,1.0/120.0)
		session._process(delta)
		left -= delta
		steps += 1
		if steps % 60 == 0: await frames(1)

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.position = session.presentation.get_global_transform_with_canvas() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)
	if main.session != null: session._process(0)

func command(command_name: String, pressed: bool, route: int = 0) -> void:
	if route == 0:
		for code in JellyView.KEYS:
			if JellyView.KEYS[code] == command_name:
				await key_event(code,pressed)
				return
	elif route == 1:
		await pointer(JellyView.button_rect(command_name).get_center(),"press" if pressed else "release")
	else:
		await touch(JellyView.button_rect(command_name).get_center(),pressed)

func action(command_name: String, route: int = 0) -> void:
	await command(command_name,true,route)
	await command(command_name,false,route)

func configure(x: float, tilt: float, route: int = 0) -> void:
	for i in 20:
		var state: Dictionary = session.active_driver.snapshot()
		if is_equal_approx(state.bed.x,x): break
		await action("bed_right" if state.bed.x < x else "bed_left",route)
	for i in 20:
		var angle: float = session.active_driver.snapshot().tilt
		if is_equal_approx(angle,tilt): break
		await action("tilt_right" if angle < tilt else "tilt_left",route)
	check(is_equal_approx(session.active_driver.snapshot().bed.x,x) and is_equal_approx(session.active_driver.snapshot().tilt,tilt),"parsed real controls configure requested bed/slant")

func charge(seconds: float, route: int = 0, label: String = "") -> void:
	await command("charge",true,route)
	await advance(seconds)
	if not label.is_empty():
		var held: Dictionary = session.active_driver.snapshot()
		check(held.charging and held.depth > 0.5 and held.trajectory.size() > 1 and held.fruit.y > 512,"actual held depression and shared ballistic preview")
		await capture(label+"-charge-slant-depth-trajectory")
	await command("charge",false,route)

func wait_ready(label: String = "") -> void:
	var captured := false
	for i in 1000:
		if main.session == null: return
		var state: Dictionary = session.active_driver.snapshot()
		if state.fruit.ready or state.ended: return
		await advance(1.0/120.0)
		if not label.is_empty() and not captured and state.elapsed > 0 and state.fruit.bell_touched:
			await capture(label+"-real-bell-flight")
			captured = true
		if i == 42 and not label.is_empty(): await capture(label+"-ballistic-flight")
	check(false,"bounded real fruit settles/delivers")

func shot(bell: bool = false, route: int = 0, label: String = "") -> void:
	var state: Dictionary = session.active_driver.snapshot()
	var delivered: int = state.delivered
	var x := 380.0
	var tilt := 21.0
	var hold := 1.28
	if is_equal_approx(state.fruit.mass,1.15):
		x = 420
		tilt = 28
	elif is_equal_approx(state.fruit.mass,0.9):
		x = 340
		hold = 1.26
	await configure(x+(80.0 if bell else 0.0),tilt,route)
	await charge(hold,route,label)
	if not label.is_empty(): check(not session.active_driver.snapshot().fruit.ready and session.active_driver.snapshot().participated,"explicit real release launches fruit")
	await wait_ready(label)
	if main.session != null:
		check(session.active_driver.snapshot().delivered == delivered+1,"real downward high-platform delivery")
		if not label.is_empty(): await capture(label+"-delivery")

func control_scan() -> void:
	await scan_controls(session.minigame_hud,"MainHUD")
	for command_name in JellyView.COMMANDS:
		var rect: Rect2 = session.presentation.get_global_transform_with_canvas() * JellyView.button_rect(command_name)
		check(get_viewport().get_visible_rect().grow(0.5).encloses(rect),"Main transformed seven-control bounds: "+command_name)
	await action("bed_right",1)
	check(session.active_driver.snapshot().bed.x == 380,"real mouse bed right")
	await action("bed_left",2)
	check(session.active_driver.snapshot().bed.x == 340,"real parsed touch bed left")
	await action("tilt_left",1)
	await action("tilt_right",2)
	check(session.active_driver.snapshot().tilt == 21,"mouse/touch slant")
	await action("helper",2)
	check(session.active_driver.snapshot().helper,"real touch AI toggles")
	await action("helper",1)
	await command("charge",true,2)
	await advance(0.4)
	check(session.active_driver.snapshot().depth > 0,"real held touch depresses bed")
	await touch(JellyView.button_rect("reset_fruit").get_center(),false)
	await action("reset_fruit",1)
	check(not session.active_driver.snapshot().participated and not session.active_driver.snapshot().charging,"real outside touch release cancels hold; mouse X does not create participation")
	await capture("seven-controls")

func control_clip(control: Control) -> Rect2:
	var clip: Rect2 = get_viewport().get_visible_rect()
	var parent := control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents: clip = clip.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return clip

func scan_controls(node: Node, label: String) -> void:
	for child in node.get_children():
		# The house semantic pager scrolls its inactive groups; visibility flags stay true.
		if str(child.name).begins_with("TutorialCopyGroup") and is_instance_valid(main.tutorial_panel):
			if child != main.tutorial_panel._copy_pages[main.tutorial_panel._copy_page]: continue
		if child is Control and child.is_visible_in_tree() and (child is Button or child is Label or child is RichTextLabel):
			check(control_clip(child).grow(0.5).encloses(child.get_global_rect()),label+" full visible text/control "+str(child.get_path())+" text="+str(child.text)+" rect="+str(child.get_global_rect())+" viewport="+str(get_viewport().get_visible_rect()))
			if child is Button:
				var font: Font = child.get_theme_font("font")
				var font_size: int = child.get_theme_font_size("font_size")
				for line in child.text.split("\n"):
					check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= child.size.x+0.5,label+" full button text "+str(child.name))
			elif child is Label:
				check(child.get_line_count()*child.get_theme_font("font").get_height(child.get_theme_font_size("font_size")) <= child.size.y+2,label+" full Label lines "+str(child.name))
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
	if hashes.has("photo-candy-game-4") and hashes.has("photo-candy-devil-4"):
		check(hashes["photo-candy-game-4"] == hashes["photo-candy-devil-4"],label+" normal/devil share refreshed gameplay originals")
	gameplay_history.append({"label":label,"hashes":hashes,"coins":Progress.coins})

func complete_route(plug: bool, assisted: bool, label: String) -> void:
	var coins: int = Progress.coins
	var first := not Progress.achievements.has("ACH_GAME_028")
	await solve(plug,assisted,label)
	await frames(8)
	check(main.session == null and not results.is_empty(),label+" natural Main result")
	if results.is_empty(): return
	var result: Dictionary = results.back()
	check(result.success and result.devil == plug and result.ordinary_eligible,label+" genuine physical result")
	check(Progress.coins == coins + (40 if first else 0),label+" strict first40 coin receipt")
	check(Progress.achievements.has("ACH_GAME_028") and photo_valid("photo-candy-game-4"),label+" fixed card/achievement actual PNG")
	if plug: check(photo_valid("photo-candy-devil-4") and Progress.photos["photo-candy-devil-4"].challenge_earned,label+" real same-fruit bell proof")
	record_gameplay(label)
	await capture(label+"-result")

func solve(bell: bool, assisted: bool, label: String = "practice") -> void:
	var driver = session.active_driver
	if assisted:
		await configure(340,0)
		await action("helper")
		await charge(0.8,2)
		await wait_ready()
		var caught: Dictionary = driver.snapshot()
		check(caught.fruit.ready and not caught.charging and caught.fruit.vx == 0 and caught.fruit.vy == 0 and caught.delivered == 0,"AI catches only real descending bed contact and awaits manual release")
		var elapsed: float = caught.elapsed
		await advance(0.25)
		check(driver.snapshot().fruit.ready and driver.snapshot().elapsed > elapsed and not driver.snapshot().charging,"AI never launches on wait")
		await capture(label+"-ai-caught-awaiting-release")
		await action("helper")
	for fruit in 3:
		if main.session == null: break
		await shot(bell and fruit == 0,fruit % 3,label+"-fruit%d" % (fruit+1))
	var final: Dictionary = driver.snapshot()
	physical_results.append(final)
	check(final.ended and final.success and final.delivered == 3 and final.bell_deliveries == int(bell),label+" three natural deliveries / real same-fruit bell")
	check(main.session == null,label+" natural Session finish")

func recovery_and_reset_checks() -> void:
	for assisted in [false,true]:
		await launch(assisted,true)
		await shot(true)
		var before: Dictionary = session.active_driver.snapshot()
		await configure(340,0)
		await charge(0.2)
		await key(KEY_X)
		var reset: Dictionary = session.active_driver.snapshot()
		check(reset.delivered == 1 and reset.bell_deliveries == 1 and reset.mistakes == before.mistakes+1 and reset.elapsed > before.elapsed and not reset.fruit.bell_touched,"X preserves completed deliveries/bell, charges mistake and never refunds time")
		var mass: float = reset.fruit.mass
		await configure(500 if mass > 1.0 else 420,28 if mass > 1.0 else 21)
		await charge(1.28 if mass > 1.0 else 1.26)
		for step in 700:
			var flying: Dictionary = session.active_driver.snapshot()
			if flying.fruit.bell_touched: break
			if flying.fruit.ready: break
			await advance(1.0/120.0)
		var touched: Dictionary = session.active_driver.snapshot()
		check(touched.fruit.bell_touched and not touched.fruit.ready and touched.delivered == 1,"real unfinished bell fruit before X")
		await key(KEY_X)
		reset = session.active_driver.snapshot()
		check(reset.delivered == 1 and reset.bell_deliveries == 1 and not reset.fruit.bell_touched and reset.mistakes == touched.mistakes+1 and reset.elapsed >= touched.elapsed,"X clears only unfinished bell, preserves completed checkpoints, costs mistake without time refund")
		await capture("reset-unfinished-bell-assisted" if assisted else "reset-unfinished-bell-normal")
		await configure(180,-35)
		await charge(1.3)
		await wait_ready()
		var loss: Dictionary = session.active_driver.snapshot()
		check(loss.mistakes == reset.mistakes+1 and loss.delivered == int(assisted) and loss.bell_deliveries == int(assisted) and loss.elapsed > reset.elapsed,"natural loss resets normal chain / preserves assisted checkpoints")
		await capture("loss-assisted" if assisted else "loss-normal")
		main._cancel_game(false)
	# Same third fruit genuinely rings, reflects right wall, recatches, then manually launches.
	await launch(false,true)
	if session.active_driver.snapshot().variant != 0:
		await key(KEY_ESCAPE)
		await activate(session.minigame_hud,"RetryButton")
		await activate(session.minigame_hud,"ConfirmAction")
		await frames(3)
	check(session.active_driver.snapshot().variant == 0,"actual HUD retry selects A for published third-fruit recatch recipe")
	await shot()
	await shot()
	await configure(500,35)
	await action("helper")
	await charge(1.34)
	await configure(620,35)
	var saw_bell := false
	var saw_wall := false
	for step in 1000:
		var state: Dictionary = session.active_driver.snapshot()
		if state.fruit.bell_touched and not saw_bell:
			saw_bell = true
			await capture("recovery-real-bell")
		if state.fruit.vx < 0 and not saw_wall:
			saw_wall = true
			await capture("recovery-real-wall-reflection")
		if state.fruit.ready: break
		await advance(1.0/120.0)
	var caught: Dictionary = session.active_driver.snapshot()
	print("RECOVERY_STATE: ",JSON.stringify(caught))
	check(saw_bell and saw_wall and caught.fruit.ready and caught.fruit.bell_touched and caught.delivered == 2 and caught.bell_deliveries == 0 and not caught.charging,"same bell fruit truly returns via side wall and AI catch")
	await advance(0.25)
	check(session.active_driver.snapshot().fruit.ready and not session.active_driver.snapshot().charging,"recaught fruit waits for manual release")
	await capture("recovery-ai-waits")
	await shot(false,1,"recovery-manual-release")
	await frames(5)
	check(main.session == null and results.back().success,"recovered same bell fruit actual manual third delivery")

func native_retake(devil: bool) -> void:
	var target := "photo-candy-devil-4" if devil else "photo-candy-game-4"
	var other := "photo-candy-game-4" if devil else "photo-candy-devil-4"
	main._cancel_game(false)
	main._practice_for_retake("game-028",devil)
	await bind_session()
	await charge(0.2)
	await key(KEY_ESCAPE)
	await activate(session.minigame_hud,"LeaveButton")
	await activate(session.minigame_hud,"ConfirmAction")
	await frames(5)
	check(main.modal_kind == "retake" and not Progress.photos.has(target) and not Progress.photos.has(other),"actual practice cancel returns selected retake with zero028 cards")
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
	check(not Progress.photos.has(other) and Progress.coins == coins+40 and Progress.achievements.has("ACH_GAME_028"),"selected-only retake exact first40 reward")
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
	for id in ["photo-candy-game-4","photo-candy-devil-4"]:
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
	check(Progress.current_region == "candy" and Progress.has_seen_tutorial("game-028") and Progress.achievements.has("ACH_GAME_028"),"new process restores actual region/lesson/global028")
	check(Progress.photos.keys().size() == expected.photos.keys().size(),"new process exact acquired ID count")
	for id in expected.photos:
		check(Progress.photos.has(id) and Progress.photos[id] == expected.photos[id],"new process exact ID/provenance record "+id)
	check(photo_hashes() == expected.hashes and Progress.coins == int(expected.coins),"new process preserves every original SHA and exact coin receipt")
	for id in expected.hashes: check(photo_valid(id),"new process decodes original+thumbnail "+id)
	main._show_album()
	await frames(4)
	await capture("restart-album")

func finish() -> void:
	var extra := FileAccess.open(output.path_join("physical-report.json"),FileAccess.WRITE)
	if extra != null: extra.store_string(JSON.stringify({"checks":checks,"physical_results":physical_results,"original_hashes":photo_hashes(),"gameplay_capture_history":gameplay_history,"failures":failures,"synthetic_setup":"six welcome cards/opening only","actor_placement":"sign (0,GROUND_Y,-10.8) then entrance (7,GROUND_Y,-1); both controlled fixture placements, not walked"},"\t"))
	await super.finish()
