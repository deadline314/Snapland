extends "res://game/tests/native_sugar_bridge_main.gd"
## Actual Main GPU and parsed-input proof with controlled factory admission.
const Catalog = preload("res://game/core/game_catalog.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const CottonView = preload("res://game/minigames/cotton_wind_view.gd")
const Route = preload("res://game/tests/cotton_wind_route.gd")
const Book = preload("res://game/ui/collection_book_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SessionScript = preload("res://game/minigames/session.gd")
const DIRECTIONS := {KEY_A: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_W: Vector2.UP, KEY_S: Vector2.DOWN}
const GAME := "game-030"
const ORDINARY := "photo-candy-game-6"
const DEVIL := "photo-candy-devil-6"
const ACHIEVEMENT := "ACH_GAME_030"

var checks := 0
var events := {}
var layouts: Array[Dictionary] = []
var lessons: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var gameplay_photos: Array[Dictionary] = []
var retake_proof := {}
var admission_coins := 0
var clock: SessionClock
var near_far := {}

class SessionClock:
	var session: Control
	var driver: RefCounted
	var simulated := 0.0

	func _init(active_session: Control) -> void:
		session = active_session
		driver = session.active_driver

	func snapshot() -> Dictionary:
		return driver.snapshot()

	func step(delta: float) -> Dictionary:
		if is_instance_valid(session) and session.is_inside_tree():
			var before: float = session.elapsed
			session._process(delta)
			simulated += session.elapsed - before
		return snapshot()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func completion_marker() -> String:
	return "PASS: native cotton Main parsed input, actual strands, GPU originals and restart"

func _run() -> void:
	review_game_id = GAME
	output = OS.get_environment("COTTON_CAPTURE_DIR")
	mode = OS.get_environment("COTTON_REVIEW_MODE")
	var dimensions := OS.get_environment("COTTON_REVIEW_SIZE").split("x")
	if dimensions.size() == 2:
		requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if (DisplayServer.get_name() == "headless" or requested not in [Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(800, 600)]
		or mode not in ["suite", "retake-ordinary", "retake-devil", "read"]):
		push_error("Native cotton requires GPU, isolated paths, and an explicit supported mode and size")
		get_tree().quit(1)
		return
	var save := OS.get_environment("SNAPLAND_SAVE_PATH")
	var refusal := destination_error(save)
	if not refusal.is_empty():
		push_error("Native cotton preflight: " + refusal)
		get_tree().quit(1)
		return
	Input.use_accumulated_input = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = requested
	get_window().size = requested
	if mode != "read":
		Progress.reset_progress()
		Progress.intro_seen = true
		Progress.prologue_seen = true
		Progress.settings.ui_scale = 1.25
		Progress.settings.reduced_motion = true
		Progress.settings.fullscreen = false
		for card in range(1, 7):
			Progress.grant_photo("photo-welcome-game-%d" % card)
		print("SYNTHETIC ADMISSION ONLY: six welcome cards, intro/prologue seen, isolated viewport settings")
		check(Progress.set_current_region("candy"), "six admission cards enable candy")
		admission_coins = Progress.coins
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	main.ui.child_entered_tree.connect(func(child: Node):
		if child.get_script() == SessionScript:
			child.ready.connect(func(): child.set_process(false), CONNECT_ONE_SHOT)
	)
	await frames(8)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual window viewport")
	check(Paper.text_scale() == 1.25 and Paper.reduced_motion(), "actual accessibility settings")
	check(Catalog.identity(GAME) == {"id": GAME, "mode": "cotton_wind", "zone": "candy", "local_index": 6,
		"photo_id": ORDINARY, "devil_photo_id": DEVIL, "achievement_id": ACHIEVEMENT}, "fixed cotton identity")
	if mode == "read":
		await read_profile()
		await finish()
		return
	check(owned_cards().is_empty() and not Progress.achievements.has(ACHIEVEMENT), "fresh writer begins with zero cotton cards and no achievement")
	if await enter_station():
		if mode == "suite":
			await run_suite()
		else:
			await run_retake(mode == "retake-devil")
		await open_book("TicketAction2", "album")
		await open_book("TicketAction3", "achievement-book")
		for card in range(1, 6):
			check(not Progress.photos.has("photo-candy-game-%d" % card) and not Progress.photos.has("photo-candy-devil-%d" % card), "cotton never grants older factory cards")
		check(Progress.coins == admission_coins + 40 and Progress.wardrobe_rewarded_games.count(GAME) == 1 and Progress.achievements.has(ACHIEVEMENT), "exact one 40-coin fixed achievement receipt")
		check(Progress.save_progress(), "writer saves actual progress")
		write_json(provenance_path(), {"mode": mode, "save_path": save, "save_sha256": FileAccess.get_sha256(save), "profile": profile_receipt()})
	await finish()

func destination_error(save: String) -> String:
	for path: String in [save, output]:
		var error := SaveGuard.validate_save_path(path, OS.get_user_data_dir())
		if not error.is_empty():
			return error
	var save_dir := save.get_base_dir()
	if not save.get_file().is_valid_filename() or save.get_file().to_lower() in ["native-originals.json", "photos"] or DirAccess.dir_exists_absolute(save):
		return "expected a usable save file path: " + save
	if save_dir.simplify_path().to_lower() == output.simplify_path().trim_suffix("/").to_lower():
		return "save and capture require separate directories"
	var fresh_paths: Array[String] = [output]
	if mode == "read":
		if not FileAccess.file_exists(save) or not FileAccess.file_exists(provenance_path()):
			return "reader requires its writer's save and provenance"
		var writer = JSON.parse_string(FileAccess.get_file_as_string(provenance_path()))
		if not writer is Dictionary or writer.get("save_path") != save or writer.get("save_sha256") != FileAccess.get_sha256(save):
			return "reader save does not match its writer's provenance"
	else:
		fresh_paths.push_front(save_dir)
	for path: String in fresh_paths:
		var dir := DirAccess.open(path)
		if dir == null:
			return "missing or inaccessible directory: " + path
		dir.include_hidden = true
		if dir.list_dir_begin() != OK or not dir.get_next().is_empty():
			return "expected a fresh empty directory: " + path
	for path: String in fresh_paths:
		var probe := save + ".tmp" if path == save_dir else path.path_join(".cotton-write-test")
		var file := FileAccess.open(probe, FileAccess.WRITE)
		if file == null:
			return "cannot write in directory: " + path
		file.close()
		if DirAccess.remove_absolute(probe) != OK:
			return "cannot remove write probe: " + probe
	return ""

func parse(event: InputEvent, point := Vector2.ZERO) -> void:
	if not event is InputEventKey:
		event.position = session.presentation.get_global_transform_with_canvas() * point
		if event is InputEventMouse:
			event.global_position = event.position
	var kind := event.get_class()
	events[kind] = int(events.get(kind, 0)) + 1
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func hold(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	parse(event)

func board_pointer(point: Vector2, finger: int, pressed: bool, moving := false) -> void:
	var event: InputEvent
	if finger >= 0 and moving:
		var drag := InputEventScreenDrag.new()
		drag.index = finger
		event = drag
	elif finger >= 0:
		var touch := InputEventScreenTouch.new()
		touch.index = finger
		touch.pressed = pressed
		event = touch
	elif moving:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		event = motion
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.pressed = pressed
		event = button
	parse(event, point)

func tap(command: String, finger: int) -> void:
	var point := CottonView.command_center(command)
	board_pointer(point, finger, true)
	board_pointer(point, finger, false)

func key(code: Key) -> void:
	for pressed in [true, false]:
		hold(code, pressed)
		await frames(1)

func press_button(button: Button) -> void:
	check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "enabled visible GUI button: %s" % str(button))
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():
		return
	button.grab_focus()
	check(button.has_focus(), "actual GUI focus: " + str(button.name))
	await key(KEY_ENTER)
	await frames(3)

func activate(parent: Node, button_name: String) -> void:
	await press_button(parent.find_child(button_name, true, false) as Button)

func enter_station() -> bool:
	if mode == "suite":
		print("CONTROLLED ACTOR PLACEMENT: (0,GROUND_Y,-10.8) sign")
		await place_actor(Vector2(0, -10.8))
		var signs: Array = main.world.local_sign_labels.filter(func(label: Label3D): return label.text.begins_with("工廠遊戲 "))
		check(signs.size() == 1 and signs[0].is_visible_in_tree() and signs[0].text == "工廠遊戲 %d／12" % Catalog.definitions("candy").size(), "real current physical factory sign")
		await capture("factory-visible-sign")
	print("CONTROLLED ACTOR PLACEMENT: (6.5,GROUND_Y,10) station")
	await place_actor(Vector2(6.5, 10))
	check(main.world.nearest.get("id", "") == GAME, "actual physical nearest cotton entrance")
	await capture("factory-entrance")
	await key(KEY_E)
	if not invitation("physical E"):
		return false
	await capture("invite")
	if mode != "suite":
		return true
	await activate(main.overlay, "InviteRules")
	await read_rules()
	await key(KEY_ESCAPE)
	await key(KEY_M)
	check(main.modal_kind == "ticket", "actual M opens the world ticket")
	await activate(main.overlay, "TicketAction0")
	await capture("map")
	await activate(main.overlay, "RegionGamesButton")
	var grid: Control = main.overlay.find_child("RegionalGameEntriesGrid", true, false)
	check(grid != null and grid.get_child_count() == Catalog.definitions("candy").size(), "actual regional map lists all factory games")
	await capture("map-entries")
	await activate(main.overlay, "HarborGame" + GAME)
	if not invitation("focused map action"):
		return false
	return await start_first_entry(true)

func start_first_entry(all_pages: bool) -> bool:
	await activate(main.overlay, "InviteStart")
	check(is_instance_valid(main.tutorial_panel) and main.tutorial_target == GAME, "actual first entry opens the cotton lesson")
	if not is_instance_valid(main.tutorial_panel):
		return false
	if all_pages:
		await read_lessons()
	await press_button(main.tutorial_panel._start_button)
	check(Progress.has_seen_tutorial(GAME) and Progress.has_attempted_game(GAME), "tutorial and actual attempt persisted by Main")
	return await bind_session()

func place_actor(point: Vector2) -> void:
	main.world.player.position = Vector3(point.x, main.world.GROUND_Y, point.y)
	main.world.player.velocity = Vector3.ZERO
	for i in 4:
		await get_tree().physics_frame

func invitation(source: String) -> bool:
	var title := main.overlay.find_child("InviteTitle", true, false) as Label
	var visible_invite: bool = main.modal_kind == "game_info" and title != null and title.is_visible_in_tree() and title.text == "棉糖捲風"
	check(visible_invite, source + " opens the visible cotton invitation")
	return visible_invite

func read_rules() -> void:
	var pager: Control = main.overlay.find_child("GameRulesExtraDetails", true, false)
	check(pager != null and pager.get_meta("page_count", 0) == 7, "seven actual rules pages")
	if pager == null:
		return
	var copy := ["本局目標", "操作方式", "小惡魔", "親自收絲至少 1 單位", "AI 只用另一支棒收自己的絲", "CV 越低表示繞棒越勻", "有接回且通關再加 100 分"]
	for page in copy.size():
		check(pager.get_meta("page_index", -1) == page and visible_copy(pager).contains(copy[page]), "ordered rules page " + copy[page])
		var label := "rules-%d" % (page + 1)
		await capture(label)
		check_layout(label, main.overlay)
		if page < copy.size() - 1:
			await activate(main.overlay, "GameRulesExtraDetailsNext")

func read_lessons() -> void:
	var panel: Control = main.tutorial_panel
	for slide in 3:
		var texture: Texture2D = panel._image.texture
		check(texture != null and texture.resource_path == "res://assets/ui/tutorials/game-030-step-%02d.png" % (slide + 1),
			"actual ordered game-030 lesson texture %d" % (slide + 1))
		var image := texture.get_image() if texture != null else null
		check(image != null and image.get_size() == Vector2i(1280, 720), "actual tutorial PNG %d decodes at native resolution" % (slide + 1))
		var covered: Array = []
		for page in panel._copy_pages.size():
			if page > 0:
				await activate(panel, "TutorialCopyNext")
			check(panel._copy_page == page, "actual tutorial semantic page %d/%d" % [slide + 1, page + 1])
			var label := "tutorial-%d-copy-%d" % [slide + 1, page + 1]
			var group: Control = panel._copy_pages[page]
			var semantic: Array = group.get_meta("semantic_indices")
			covered.append_array(semantic)
			await capture(label)
			check_layout(label, panel, group)
			var image_rect := screen_rect(panel._image)
			var image_clip := clip_for(panel._image)
			check(panel._image.is_visible_in_tree() and image_clip.grow(0.5).encloses(image_rect), label + " actual tutorial picture fits")
			lessons.append({"capture": label + ".png", "image": texture.resource_path if texture != null else "",
				"image_rect": rect_data(image_rect), "image_clip": rect_data(image_clip), "semantic_indices": semantic, "copy": visible_copy(group)})
		check(covered == [0, 1, 2, 3, 4], "all five semantic fields in order for slide %d" % (slide + 1))
		if requested == Vector2i(800, 600):
			await check_caption_zoom(panel, slide)
		if slide < 2:
			await press_button(panel._next_button)

func check_caption_zoom(panel: Control, slide: int) -> void:
	var preview: Button = panel._screenshot_zoom_button
	for i in 24:
		if preview.has_focus():
			break
		await key(KEY_TAB)
	check(preview.has_focus(), "Tab reaches the screenshot preview on slide %d" % (slide + 1))
	await key(KEY_ENTER)
	await frames(3)
	var caption: Label = panel._zoom_caption
	var image: TextureRect = panel._zoom_image
	var back: Button = panel._zoom_back
	var expected: String = panel.current_step_data().alt
	var label := "tutorial-%d-zoom" % (slide + 1)
	check(panel._screenshot_zoom.is_visible_in_tree() and back.has_focus() and caption.text == expected and not expected.is_empty()
		and caption.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, label + " opens the full caption and focuses Back")
	var text_size := caption.get_theme_font("font").get_multiline_string_size(caption.text, caption.horizontal_alignment, caption.size.x, caption.get_theme_font_size("font_size"))
	check(text_size.x <= caption.size.x + 1.0 and text_size.y <= caption.size.y + 1.0 and caption.get_visible_line_count() == caption.get_line_count(),
		label + " entire shaped caption fits")
	check(image.texture != null and image.texture == panel._image.texture and image.is_visible_in_tree() and clip_for(image).encloses(screen_rect(image))
		and not screen_rect(image).intersects(screen_rect(caption)) and not screen_rect(caption).intersects(screen_rect(back)), label + " image, text and Back are visible and separate")
	await capture(label)
	check_layout(label, panel._screenshot_zoom)
	await key(KEY_ENTER)
	await frames(2)
	var restored: bool = preview.has_focus() and not panel._screenshot_zoom.is_visible_in_tree()
	check(restored, label + " Back returns focus to the slide screenshot")
	lessons.append({"capture": label + ".png", "caption": expected, "caption_shaped_size": [text_size.x, text_size.y],
		"caption_rect": rect_data(screen_rect(caption)), "image_rect": rect_data(screen_rect(image)), "back_rect": rect_data(screen_rect(back)),
		"caption_lines": caption.get_line_count(), "focus_restored": restored})

func bind_session() -> bool:
	session = main.session
	check(is_instance_valid(session) and session.game_id == GAME and session.presentation_mode == "cotton_wind", "real Main cotton Session and View")
	if not is_instance_valid(session) or not is_instance_valid(session.presentation):
		return false
	# Drive the regular Session update with bounded deltas while rendering uses ordinary frames.
	check(not session.is_processing() and is_zero_approx(session.elapsed), "Session clock starts at zero before rendering waits")
	session.set_process(false)
	session.presentation.grab_focus()
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	clock = SessionClock.new(session)
	check(session.presentation.has_focus(), "actual board focus")
	return true

func launch_from_result(text: String) -> bool:
	var match_button: Button
	for button: Button in main.modal_footer.find_children("*", "Button", true, false):
		if button.text == text:
			match_button = button
			break
	await press_button(match_button)
	return await bind_session()

func capture_board(label: String) -> void:
	# Show the current score summary during capture even inside the HUD refresh interval.
	session._refresh_hud(true)
	await capture(label)
	check_layout(label + "-hud", session.minigame_hud)
	var board: Control = session.presentation
	check_layout(label, board)
	var controls := {}
	for command: String in CottonView.COMMANDS:
		var button := board.get_node_or_null(command.capitalize().replace(" ", "")) as Button
		if button == null:
			continue
		var screen := screen_rect(button)
		var hit: Vector2 = board.get_global_transform_with_canvas() * CottonView.command_center(command)
		check(button.is_visible_in_tree() and screen.has_point(hit) and clip_for(button).grow(0.01).encloses(screen)
			and CottonView.command_at(CottonView.command_center(command)) == command, "actual painted and hit bounds for " + command)
		controls[command] = {"text": button.text, "rect": rect_data(screen), "clip": rect_data(clip_for(button))}
	check(controls.size() == 8, "all eight Cotton controls present")
	layouts.append({"capture": label + ".png", "controls": controls, "board": rect_data(screen_rect(board))})

func retry() -> void:
	var variant: int = clock.snapshot().variant
	await key(KEY_ESCAPE)
	await activate(session.minigame_hud, "RetryButton")
	await activate(session.minigame_hud, "ConfirmAction")
	session.presentation.grab_focus()
	clock = SessionClock.new(session)
	var state := clock.snapshot()
	check(state.variant != variant and is_zero_approx(state.elapsed) and is_zero_approx(state.material.player) and not state.participated
		and session.presentation.has_focus() and not session.paused, "actual HUD retry switches wind and clears deposits and input")

func first_contact(depth: float, label: String) -> Dictionary:
	var point := CottonView.stick_to_design(Vector2(0, depth))
	tap("spin_right", -1)
	board_pointer(point, -1, true)
	var state := clock.snapshot()
	for tick in 120:
		state = clock.step(Route.DT)
		if state.material.player > 0.0:
			break
	board_pointer(point, -1, false)
	tap("spin_right", -1)
	check(state.material.player > 0.0 and is_equal_approx(state.stick.z, depth) and not state.uniform
		and state.spin_travel > 0.5, "actual first %s strand deposits at the intended depth" % label)
	await capture_board(label)
	return {"mass": state.material.player, "elapsed": state.elapsed, "depth": state.stick.z, "variant": state.variant, "quality": state.quality}

func run_suite() -> void:
	var near := await first_contact(56.0, "near-first-strand")
	await retry()
	await retry()
	var far := await first_contact(146.0, "far-first-strand")
	near_far = {"near": near, "far": far}
	check(near.variant == far.variant and near.mass > far.mass and far.mass > 0.0, "same-wind actual near strand deposits more than far strand")
	await retry()
	if not await solve("keyboard", false, "ordinary"):
		return
	check(owned_cards().keys() == [ORDINARY] and Progress.coins == admission_coins + 40, "ordinary route grants only its card and a first +40")
	var ordinary_images := record_gameplay("ordinary")
	if not await launch_from_result("再玩一次") or not await solve("mouse", true, "rejoin"):
		return
	var rejoin_images := record_gameplay("rejoin")
	check(owned_cards().keys() == [ORDINARY, DEVIL] and Progress.photos[DEVIL].challenge_earned
		and Progress.photos[ORDINARY].get("acquisition_method", "gameplay") == "gameplay"
		and Progress.photos[DEVIL].get("acquisition_method", "gameplay") == "gameplay",
		"the real rejoin earns the fixed devil card with gameplay provenance")
	check(rejoin_images.get(ORDINARY, {}) != ordinary_images.get(ORDINARY, {})
		and rejoin_images.get(ORDINARY, {}) == rejoin_images.get(DEVIL, {}), "later genuine gameplay refreshes shared latest gameplay photos")
	var formal := profile_receipt()
	if not await launch_from_result("練習操作") or not await solve("touch", true, "practice"):
		return
	check(profile_receipt() == formal, "genuine practice preserves cards, pixels, provenance, achievement and coins")
	if not await launch_from_result("再練一次"):
		return
	check(await participate("touch"), "cancelled practice has genuine movement, spin and deposit")
	await pause_and_cancel("pause-cancel", 0)
	check(profile_receipt() == formal, "paused cancellation preserves cards, pixels and receipts")

func solve(source: String, rejoin: bool, label: String) -> bool:
	var time_started := Time.get_ticks_msec()
	var before_events := event_total()
	var before_results := results.size()
	var is_practice: bool = session.practice_mode
	var finger := 0 if source == "touch" else -1
	var point := Vector2.ZERO
	var direction_before := Vector2.ZERO
	var partial := {}
	var live_tail := {}
	var catch_state := {}
	var before := clock.snapshot()
	var assisted: bool = before.assisted
	var delta := 1.0 / 120.0 if source == "keyboard" else Route.DT
	if source == "keyboard":
		hold(KEY_E, true)
	else:
		tap("spin_right", finger)
		point = CottonView.stick_to_design(Route.target(before, rejoin))
		board_pointer(point, finger, true)
	var state := before
	for tick in ceili(120.0 / delta) + 1:
		if state.ended or state.uniform and (not rejoin or state.rejoins > 0):
			break
		var target := Route.target(state, rejoin)
		if source == "keyboard":
			var difference := target - Vector2(state.stick.x, state.stick.z)
			var direction := Vector2(signf(difference.x) if absf(difference.x) >= 0.5 else 0.0,
				signf(difference.y) if absf(difference.y) >= 0.5 else 0.0)
			for code: Key in DIRECTIONS:
				var basis: Vector2 = DIRECTIONS[code]
				if direction.dot(basis) != direction_before.dot(basis):
					hold(code, direction.dot(basis) > 0.0)
			direction_before = direction
		else:
			point = CottonView.stick_to_design(target)
			board_pointer(point, finger, true, true)
		before = state
		state = clock.step(delta)
		if rejoin and live_tail.is_empty() and not state.tail.is_empty() and state.tail.near_break:
			var tail: Dictionary = state.tail
			check(tail.tension >= 80.0 and tail.length > tail.rest_length and tail.receiver_band == 2 - tail.anchor_band
				and tail.receiver_band != tail.anchor_band, label + " live near-break tension and distinct receiving band")
			live_tail = {"elapsed": state.elapsed, "tension": tail.tension, "length": tail.length,
				"rest_length": tail.rest_length, "anchor_band": tail.anchor_band, "receiver_band": tail.receiver_band}
			await capture_board(label + "-near-break")
		if rejoin and catch_state.is_empty() and state.rejoins > before.rejoins:
			var tail: Dictionary = before.tail
			check(not tail.is_empty() and state.material.player > before.material.player and state.omega > 0.0,
				label + " real spinning opposite-end catch deposits material")
			catch_state = {"elapsed": state.elapsed, "anchor_band": tail.get("anchor_band", -1),
				"receiver_band": tail.get("receiver_band", -1), "player_mass_before": before.material.player,
				"player_mass_after": state.material.player, "feedback": state.feedback}
			check(catch_state.receiver_band == 2 - catch_state.anchor_band and catch_state.receiver_band != catch_state.anchor_band,
				label + " actual catch was on the other outer band")
			await capture_board(label + "-opposite-catch")
		if partial.is_empty() and state.elapsed >= 4.0:
			partial = {"elapsed": state.elapsed, "quality": state.quality, "bands": state.bands, "material": state.material}
			check(state.material.player > 1.0 and not state.uniform and state.quality[0].mass != state.quality[2].mass,
				label + " genuine partial deposits make uneven bands")
			await capture_board(label + "-partial")
		if tick % roundi(1.0 / delta) == 0:
			await frames(1)
	var ready: bool = not state.ended and state.uniform and state.participated and state.rejoins == int(rejoin)
	check(ready and not partial.is_empty() and (not rejoin or not catch_state.is_empty())
		and (label != "rejoin" or not live_tail.is_empty()),
		label + " must reach genuine participation, expected rejoin, and all three quality thresholds before F")
	if ready:
		await capture_board(label + "-ready")
		if source == "keyboard":
			hold(KEY_F, true)
		else:
			board_pointer(point, finger, false)
			tap("finish", finger)
		clock.step(0.0)
	if source == "keyboard":
		for code: Key in DIRECTIONS:
			if direction_before.dot(DIRECTIONS[code]) > 0.0:
				hold(code, false)
		hold(KEY_E, false)
		if ready:
			hold(KEY_F, false)
	elif not ready and main.session != null:
		board_pointer(point, finger, false)
	await frames(6)
	var terminal := clock.snapshot()
	var score := 500 if rejoin else 400
	var success: bool = (terminal.ended and terminal.success and terminal.devil == rejoin and terminal.ordinary_eligible
		and terminal.score == score and terminal.rejoins == int(rejoin) and terminal.held_commands.is_empty())
	check(success and main.session == null and results.size() == before_results + 1,
		label + " bounded route must finish exactly once with score %d, actual %d after %.3fs" % [score, terminal.score, terminal.elapsed])
	if results.size() == before_results + 1:
		var result: Dictionary = results.back()
		check(result.game_id == GAME and result.success and result.devil == rejoin and result.practice == is_practice
			and result.ordinary_eligible == not is_practice and result.score == score and result.assisted == assisted,
			label + " actual Main result metadata")
	var report := {"label": label, "source": source, "parsed_events": event_total() - before_events,
		"simulated_seconds": clock.simulated, "session_elapsed": terminal.elapsed, "wall_seconds": (Time.get_ticks_msec() - time_started) / 1000.0,
		"variant": terminal.variant, "assisted": assisted, "practice": is_practice, "score": terminal.score,
		"rejoins": terminal.rejoins, "quality": terminal.quality, "bands": terminal.bands, "partial": partial, "near_break": live_tail, "catch": catch_state}
	routes.append(report)
	print("NATIVE_COTTON_ROUTE ", JSON.stringify(report))
	await capture(label + "-result")
	return success and main.session == null

func participate(source: String) -> bool:
	var finger := 0 if source == "touch" else -1
	tap("spin_right", finger)
	board_pointer(CottonView.stick_to_design(Vector2(24, 56)), finger, true)
	var state := clock.snapshot()
	for tick in 16:
		state = clock.step(0.25)
		if state.participated:
			break
	return state.participated and state.material.player >= 1.0 and state.travel >= 6.0 and state.spin_travel >= 0.5

func pause_and_cancel(label: String, finger: int) -> void:
	var before_results := results.size()
	var moving := clock.snapshot()
	check(moving.omega > 0.0 and moving.participated, "actual spin and participation before pause")
	await key(KEY_ESCAPE)
	var frozen := clock.snapshot()
	check(session.paused and is_zero_approx(frozen.omega) and frozen.held_commands.is_empty() and frozen.bands == moving.bands,
		"actual Esc pauses and clears the latch without erasing cotton")
	check(clock.step(0.25) == frozen, "paused Session freezes time and physical state")
	board_pointer(CottonView.stick_to_design(Vector2(24, 56)), finger, false)
	await capture(label)
	await activate(session.minigame_hud, "LeaveButton")
	await activate(session.minigame_hud, "ConfirmAction")
	check(main.session == null and results.size() == before_results, "actual HUD leave cancels without completed result")

func run_retake(devil: bool) -> void:
	await activate(main.overlay, "InviteRules")
	check(not Progress.has_attempted_game(GAME), "selected kiosk starts before any actual cotton attempt")
	await activate(main.overlay, "KioskRetakeDevil" if devil else "KioskRetakeOrdinary")
	if not await bind_session():
		return
	check(session.practice_mode, "actual selected Main retake practice")
	check(await participate("touch" if devil else "mouse"), "real selected practice moves, spins and deposits")
	await pause_and_cancel("retake-practice-cancel", 0 if devil else -1)
	var panel: Control = main.retake_panel
	check(panel != null and main.modal_kind == "retake" and main.retake_target == {"id": GAME, "devil": devil}
		and owned_cards().is_empty(), "actual selected practice exit returns to retake with no awarded card")
	if panel == null:
		return
	check(panel._valid and panel._props.size() == 3, "existing cotton prop vocabulary and actual lesson source")
	await capture("retake-demonstration")
	await activate(panel, "RetakeNext")
	await activate(panel, "DecorationChoice")
	await activate(panel, "FramingChoice")
	await activate(panel, "DistanceChoice")
	check(panel.current_step == 1 and panel._decoration != 0 and panel._framing != 1 and panel._distance != 1, "actual retake arrangement changes props, framing, and distance")
	await capture("retake-arranged")
	await activate(panel, "RetakeNext")
	await capture("retake-shutter-preview")
	var preview: Image = panel._viewport.get_texture().get_image()
	var shutter_images: Array[Image] = []
	panel.capture_requested.connect(func(image: Image): shutter_images.append(image))
	await activate(panel, "RetakeShutter")
	await frames(8)
	check(shutter_images.size() == 1, "actual enabled shutter emitted one GPU Image")
	if shutter_images.size() != 1:
		return
	var photograph := shutter_images[0]
	var gpu_path := output.path_join("retake-arranged-subviewport.png")
	check(photograph.get_size() == Vector2i(1280, 720) and photograph.save_png(gpu_path) == OK, "raw arranged retake GPU pixels")
	captures.append(gpu_path.get_file())
	check(preview != null and preview.get_size() == photograph.get_size() and preview.get_data() == photograph.get_data(),
		"actual shutter pixels equal the arranged camera preview before pressing the shutter")
	var target := DEVIL if devil else ORDINARY
	var record: Dictionary = Progress.photos.get(target, {}).duplicate(true)
	check(panel._saved and owned_cards().keys() == [target] and record.get("acquisition_method") == "retake"
		and not record.get("challenge_earned", true) and Progress.coins == admission_coins + 40
		and Progress.wardrobe_rewarded_games.count(GAME) == 1 and Progress.achievements.has(ACHIEVEMENT), "actual shutter grants only selected card, truthful retake provenance and one +40")
	var paths := photo_files(target, Vector2i(1280, 720))
	if record.get("original_frames", []).size() != 1 or record.get("frames", []).size() != 1:
		check(false, "shutter saves exactly one original and one thumbnail")
		return
	var stored := Image.load_from_file(record.original_frames[0])
	if stored == null:
		return
	stored.convert(Image.FORMAT_RGBA8)
	var comparison := photograph.duplicate() as Image
	comparison.convert(Image.FORMAT_RGBA8)
	var equal_pixels := stored.get_size() == comparison.get_size() and stored.get_data() == comparison.get_data()
	check(equal_pixels, "persisted original equals actual arranged GPU shutter pixels")
	retake_proof = {"target": target, "initial": record, "files": paths, "gpu_capture": gpu_path, "equal_original_pixels": equal_pixels,
		"choices": {"decoration": panel._decoration, "framing": panel._framing, "distance": panel._distance}}
	await capture("retake-saved")
	await activate(panel, "RetakeClose")
	await key(KEY_E)
	if not invitation("physical E after selected retake"):
		return
	if not await start_first_entry(false) or not await solve("touch" if devil else "mouse", devil, "matching-challenge"):
		return
	var earned: Dictionary = Progress.photos.get(target, {})
	check(earned.get("acquisition_method") == "retake" and earned.get("challenge_earned") == devil
		and earned.get("original_frames") == record.original_frames and earned.get("frames") == record.frames
		and photo_files(target, Vector2i(1280, 720)) == paths and Progress.coins == admission_coins + 40,
		"later real matching challenge preserves retake original/thumbnail paths and SHA, method and single receipt")
	check(owned_cards().size() == (2 if devil else 1), "only a genuine later devil result may add the ordinary card")
	if devil:
		var ordinary: Dictionary = Progress.photos.get(ORDINARY, {})
		check(not ordinary.is_empty() and ordinary.get("acquisition_method", "gameplay") == "gameplay" and ordinary.get("original_frames", []) != earned.original_frames,
			"ordinary gameplay is stored independently from the protected devil retake")
	retake_proof["after_challenge"] = earned.duplicate(true)

func owned_cards() -> Dictionary:
	var owned := {}
	for id in [ORDINARY, DEVIL]:
		if Progress.photos.has(id):
			owned[id] = Progress.photos[id]
	return owned

func photo_files(id: String, original_size: Vector2i) -> Dictionary:
	var record: Dictionary = Progress.photos.get(id, {})
	var originals: Array = record.get("original_frames", [])
	var thumbs: Array = record.get("frames", [])
	check(not originals.is_empty() and originals.size() == thumbs.size(), "matching original/thumbnail counts: " + id)
	var files := {}
	for group in [[originals, original_size], [thumbs, Vector2i(320, 180)]]:
		for path: String in group[0]:
			var image := Image.load_from_file(path)
			check(image != null and image.get_size() == group[1], "saved original or thumbnail decodes at required dimensions: " + path)
			files[path] = FileAccess.get_sha256(path)
	return files

func record_gameplay(label: String) -> Dictionary:
	var hashes := {}
	for id in owned_cards():
		hashes[id] = photo_files(id, requested)
	gameplay_photos.append({"label": label, "files": hashes, "coins": Progress.coins})
	return hashes

func provenance_path() -> String:
	return OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("native-originals.json")

func profile_receipt() -> Dictionary:
	var hashes := {}
	for id in owned_cards():
		var size := Vector2i(1280, 720) if Progress.photos[id].get("acquisition_method") == "retake" else requested
		hashes[id] = photo_files(id, size)
	return {"photos": Progress.photos.duplicate(true), "hashes": hashes, "coins": Progress.coins, "region": Progress.current_region,
		"achievement": Progress.achievements.has(ACHIEVEMENT), "reward_receipts": Progress.wardrobe_rewarded_games.count(GAME),
		"lesson_seen": Progress.has_seen_tutorial(GAME), "attempted": Progress.has_attempted_game(GAME)}

func read_profile() -> void:
	var writer = JSON.parse_string(FileAccess.get_file_as_string(provenance_path()))
	check(writer is Dictionary and writer.get("mode") in ["suite", "retake-ordinary", "retake-devil"]
		and writer.get("profile") is Dictionary, "new process reads writer provenance receipt and mode")
	if not writer is Dictionary or not writer.get("profile") is Dictionary:
		return
	var expected: Dictionary = writer.profile
	var actual := profile_receipt()
	# JSON decodes all numeric atoms as floats. Compare persisted fields with their intended types.
	check(actual.photos == expected.photos and actual.hashes == expected.hashes, "separate process exact acquired IDs, photo paths, SHA and full provenance")
	check(actual.coins == int(expected.coins) and actual.coins == 160 and actual.reward_receipts == int(expected.reward_receipts)
		and actual.reward_receipts == 1 and actual.region == expected.region and actual.region == "candy"
		and actual.lesson_seen and expected.lesson_seen and actual.attempted and expected.attempted
		and actual.achievement and expected.achievement and not owned_cards().is_empty(), "separate process exact region, tutorial, attempt, achievement and coin receipt")
	var cards := owned_cards()
	var ordinary: Dictionary = cards.get(ORDINARY, {})
	var devil: Dictionary = cards.get(DEVIL, {})
	check(ordinary.get("game_id") == GAME and not ordinary.get("devil", true)
		and ordinary.get("acquisition_method", "gameplay") == ("retake" if writer.mode == "retake-ordinary" else "gameplay")
		and not ordinary.get("challenge_earned", false), "separate process exact ordinary ID, method and provenance")
	if writer.mode == "retake-ordinary":
		check(cards.keys() == [ORDINARY], "separate process retains just the selected ordinary card")
	else:
		check(cards.keys() == [ORDINARY, DEVIL] and devil.get("game_id") == GAME and devil.get("devil", false)
			and devil.get("challenge_earned", false)
			and devil.get("acquisition_method", "gameplay") == ("retake" if writer.mode == "retake-devil" else "gameplay"),
			"separate process exact ordinary and devil IDs, method and challenge proof")
	await open_book("TicketAction2", "restart-album")

func open_book(action: String, label: String) -> void:
	if not main.modal_kind.is_empty():
		await key(KEY_ESCAPE)
	await key(KEY_M)
	check(main.modal_kind == "ticket", "actual world ticket before " + label)
	await activate(main.overlay, action)
	check(main.modal_kind == ("achievements" if action == "TicketAction3" else "album"), "actual opened " + label)
	if action == "TicketAction3":
		var stamps: Control = main.overlay.find_child("MinigameStampGrid", true, false)
		check(stamps != null and stamps.get_child_count() == Catalog.definitions("candy").size(), "actual stamp book lists all factory games")
		var stamp := await find_book_tile("AchievementStamp_" + ACHIEVEMENT, "AchievementNextPage")
		check(stamp != null and visible_copy(stamp).contains("棉糖捲風") and visible_copy(stamp).contains("已蓋章"), "actual page displays the earned cotton stamp")
		await capture(label)
	else:
		if Progress.photos.has(ORDINARY):
			await capture_album_tile(ORDINARY, label)
		if Progress.photos.has(DEVIL):
			await activate(main.overlay, "AlbumTab_devil")
			await capture_album_tile(DEVIL, label + "-devil")

func capture_album_tile(id: String, label: String) -> void:
	var tile := await find_book_tile("AlbumPhoto_" + id, "AlbumNextPage")
	check(tile != null and visible_copy(tile).contains("棉糖捲風"), "actual album page displays the fixed cotton photo " + id)
	var book: Control = null
	for item in main.overlay.find_children("*", "Control", true, false):
		if item.get_script() == Book:
			book = item
			break
	check(book != null, "actual collection book control is present")
	if book != null:
		var decoded: Texture2D = book._saved_texture(id)
		check(decoded != null and decoded.get_size() == Vector2(320, 180), "actual book decodes saved thumbnail " + id)
	await capture(label)

func find_book_tile(tile_name: String, next_name: String) -> Control:
	for page in 5:
		var tile := main.overlay.find_child(tile_name, true, false) as Control
		if tile != null and tile.is_visible_in_tree():
			return tile
		var next := main.overlay.find_child(next_name, true, false) as Button
		if next == null or next.disabled:
			break
		await press_button(next)
	return null

func event_total() -> int:
	var total := 0
	for count: int in events.values():
		total += count
	return total

func screen_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func clip_for(control: Control) -> Rect2:
	var clip := get_viewport().get_visible_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			clip = clip.intersection(screen_rect(ancestor))
		ancestor = ancestor.get_parent()
	return clip

func rect_data(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func visible_copy(node: Node) -> String:
	var copy: String = node.text if node is Label and node.is_visible_in_tree() else ""
	for child in node.get_children():
		copy += "\n" + visible_copy(child)
	return copy

func check_layout(label: String, root: Node, active_group: Control = null) -> void:
	var entries: Array[Dictionary] = []
	collect_layout(label, root, active_group, entries)
	check(not entries.is_empty(), label + " actual active text and buttons measured")
	layouts.append({"capture": label.trim_suffix("-hud") + ".png", "root": str(root.name), "leaves": entries})

func collect_layout(label: String, root: Node, active_group: Control, entries: Array[Dictionary]) -> void:
	for child in root.get_children():
		if str(child.name).begins_with("TutorialCopyGroup") and child != active_group:
			continue
		if child is Control and not child.is_visible_in_tree():
			continue
		if child is Button or child is Label or child is RichTextLabel:
			var rect := screen_rect(child)
			var clip := clip_for(child)
			var fits := clip.grow(0.5).encloses(rect)
			var text_fits := true
			var abbreviated := false
			if child is Button:
				var room: Vector2 = child.size - child.get_theme_stylebox("normal").get_minimum_size()
				var font: Font = child.get_theme_font("font")
				var point_size: int = child.get_theme_font_size("font_size")
				var lines: PackedStringArray = child.text.split("\n")
				for line in lines:
					text_fits = text_fits and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x <= room.x + 0.5
				text_fits = text_fits and font.get_height(point_size) * lines.size() <= room.y + 1.0
			elif child is Label:
				var line_height: float = child.get_line_height()
				text_fits = child.get_line_count() * line_height <= child.size.y + 1.0 and child.get_visible_line_count() == child.get_line_count()
				if child.autowrap_mode == TextServer.AUTOWRAP_OFF and child.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
					for line in child.text.split("\n"):
						text_fits = text_fits and child.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x <= child.size.x + 0.5
				elif child.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and is_instance_valid(main.tutorial_panel) and child == main.tutorial_panel._image_alt:
					abbreviated = child.get_theme_font("font").get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x > child.size.x + 0.5
			else:
				text_fits = child.get_content_height() <= child.size.y + 1.0
			check(fits and text_fits, "%s %s bounds=%s text_fits=%s clip=%s rect=%s text=%s" % [label, child.name, fits, text_fits, clip, rect, child.text])
			entries.append({"name": str(child.name), "text": child.text, "rect": rect_data(rect), "clip": rect_data(clip),
				"bounds_fit": fits, "text_fits": text_fits and not abbreviated, "abbreviated_inline": abbreviated})
		collect_layout(label, child, active_group, entries)

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "write receipt " + path)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func finish() -> void:
	print("COTTON_NATIVE_CHECKS ", checks, " checks, ", failures.size(), " failures")
	write_json(output.path_join("cotton-evidence.json"), {"checks": checks, "parsed_events": events, "layouts": layouts, "lessons": lessons,
		"routes": routes, "gameplay_photo_history": gameplay_photos, "retake": retake_proof, "near_far": near_far, "profile": profile_receipt(),
		"viewport": [requested.x, requested.y], "ui_scale": Paper.text_scale(), "reduced_motion": Paper.reduced_motion(),
		"mode": mode, "wall_seconds_before_shutdown": (Time.get_ticks_msec() - started) / 1000.0, "failures": failures})
	await super.finish()
