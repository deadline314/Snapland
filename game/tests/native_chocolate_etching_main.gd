extends "res://game/tests/native_sugar_bridge_main.gd"
## Actual Main GPU and parsed-input proof with controlled factory admission.
const Catalog = preload("res://game/core/game_catalog.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Bench = preload("res://game/minigames/chocolate_etching_view.gd")
const Route = preload("res://game/tests/test_chocolate_etching_driver.gd").Route
const ViewChecks = preload("res://game/tests/test_chocolate_etching_view.gd")
const GAME := "game-029"
const ORDINARY := "photo-candy-game-5"
const DEVIL := "photo-candy-devil-5"
const ACHIEVEMENT := "ACH_GAME_029"

var checks := 0
var events := {}
var layouts: Array[Dictionary] = []
var lessons: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var gameplay_photos: Array[Dictionary] = []
var retake_proof := {}
var admission_coins := 0
var clock: SessionClock
var board_transform := Transform2D.IDENTITY

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
			var before: float = snapshot().elapsed
			session._process(delta)
			simulated += float(snapshot().elapsed) - before
		return snapshot()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func completion_marker() -> String:
	return "PASS: native chocolate Main parsed input, measured gears, GPU originals and restart"

func _run() -> void:
	review_game_id = GAME
	output = OS.get_environment("CHOCOLATE_CAPTURE_DIR")
	mode = OS.get_environment("CHOCOLATE_REVIEW_MODE")
	var dimensions := OS.get_environment("CHOCOLATE_REVIEW_SIZE").split("x")
	if dimensions.size() == 2:
		requested = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if (DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path()
		or not output.is_absolute_path() or requested not in [Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(800, 600)]
		or mode not in ["suite", "retake-ordinary", "retake-devil", "read"]):
		push_error("Native chocolate requires GPU, isolated paths, and an explicit supported mode and size")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Input.use_accumulated_input = false
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
		for card in range(1, 7):
			Progress.grant_photo("photo-welcome-game-%d" % card)
		print("SYNTHETIC ADMISSION ONLY: six welcome cards, intro/prologue seen, isolated viewport settings")
		check(Progress.set_current_region("candy"), "six admission cards enable candy")
		admission_coins = Progress.coins
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(8)
	check(get_viewport().get_visible_rect().size == Vector2(requested), "actual window viewport")
	check(Paper.text_scale() == (1.25 if requested.x == 800 else 1.0) and Paper.reduced_motion() == (requested.x == 800), "actual accessibility settings")
	check(Catalog.identity(GAME) == {"id": GAME, "mode": "chocolate_etching", "zone": "candy", "local_index": 5,
		"photo_id": ORDINARY, "devil_photo_id": DEVIL, "achievement_id": ACHIEVEMENT} and Catalog.all_definitions().size() == 29, "fixed chocolate identity and actual delivered count")
	if mode == "read":
		await read_profile()
		await finish()
		return
	check(owned_cards().is_empty() and not Progress.achievements.has(ACHIEVEMENT), "fresh writer begins with zero chocolate cards and no achievement")
	if await enter_station():
		if mode == "suite":
			await run_suite()
		else:
			await run_retake(mode == "retake-devil")
		await open_book("TicketAction2", "album")
		await open_book("TicketAction3", "achievement-book")
		for card in range(1, 5):
			check(not Progress.photos.has("photo-candy-game-%d" % card) and not Progress.photos.has("photo-candy-devil-%d" % card), "chocolate never grants older factory cards")
		check(Progress.coins == admission_coins + 40 and Progress.wardrobe_rewarded_games.count(GAME) == 1 and Progress.achievements.has(ACHIEVEMENT), "exact one 40-coin fixed achievement receipt")
		check(Progress.save_progress(), "writer saves actual progress")
		write_json(provenance_path(), profile_receipt())
	await finish()

func parse(event: InputEvent, design_point: Vector2 = Vector2.ZERO) -> bool:
	if not event is InputEventKey:
		if main.session != null:
			board_transform = session.presentation.get_global_transform_with_canvas()
		event.position = board_transform * design_point
		if event is InputEventMouse:
			event.global_position = event.position
	var category := event.get_class()
	events[category] = int(events.get(category, 0)) + 1
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if not event is InputEventKey and main.session != null:
		clock.step(1.0 / 120.0)
	return true

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		parse(event)
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
		check(signs.size() == 1 and signs[0].is_visible_in_tree() and signs[0].text == "工廠遊戲 5／12", "real current physical factory sign")
		await capture("factory-visible-sign")
	print("CONTROLLED ACTOR PLACEMENT: (10.5,GROUND_Y,-0.8) station")
	await place_actor(Vector2(10.5, -0.8))
	check(main.world.nearest.get("id", "") == GAME, "actual physical nearest chocolate entrance")
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
	check(grid != null and grid.get_child_count() == 5, "actual regional map lists five factory games")
	await capture("map-entries")
	await activate(main.overlay, "HarborGame" + GAME)
	if not invitation("focused map action"):
		return false
	return await start_first_entry(true)

func start_first_entry(all_pages: bool) -> bool:
	await activate(main.overlay, "InviteStart")
	check(is_instance_valid(main.tutorial_panel) and main.tutorial_target == GAME, "actual first entry opens the chocolate lesson")
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
	var visible_invite: bool = main.modal_kind == "game_info" and title != null and title.is_visible_in_tree() and title.text == "巧克力蝕刻"
	check(visible_invite, source + " opens the visible chocolate invitation")
	return visible_invite

func read_rules() -> void:
	var pager: Control = main.overlay.find_child("GameRulesExtraDetails", true, false)
	check(pager != null and pager.get_meta("page_count", 0) == 5, "five actual rules pages")
	if pager == null:
		return
	var copy := ["本局目標", "操作方式", "小惡魔", "參與操作", "輔助遊玩"]
	for page in 5:
		check(pager.get_meta("page_index", -1) == page and visible_copy(pager).contains(copy[page]), "ordered rules page " + copy[page])
		var label := "rules-%d" % (page + 1)
		await capture(label)
		check_layout(label, main.overlay)
		if page < 4:
			await activate(main.overlay, "GameRulesExtraDetailsNext")

func read_lessons() -> void:
	var panel: Control = main.tutorial_panel
	for slide in 3:
		var texture: Texture2D = panel._image.texture
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
			lessons.append({"capture": label + ".png", "image": texture.resource_path if texture != null else "", "semantic_indices": semantic, "copy": visible_copy(group)})
		check(covered == range(panel._copy_sections.size()), "every semantic section covered exactly once for slide %d" % (slide + 1))
		if slide < 2:
			await press_button(panel._next_button)

func bind_session() -> bool:
	session = main.session
	check(is_instance_valid(session) and session.game_id == GAME and session.presentation_mode == "chocolate_etching", "real Main chocolate Session and View")
	if not is_instance_valid(session):
		return false
	session.set_process(false)
	session.presentation.grab_focus()
	session.finished.connect(func(result: Dictionary): results.append(result.duplicate(true)))
	clock = SessionClock.new(session)
	check(session.presentation.has_focus(), "actual board focus")
	return true

func new_route(source: String) -> Route:
	var state := clock.snapshot()
	return Route.new(source, state.assisted, state.variant, clock, parse)

func advance(seconds: float) -> void:
	var remaining := seconds
	var steps := 0
	while remaining > 1.0e-8 and main.session != null:
		var delta := minf(0.25, remaining)
		clock.step(delta)
		remaining -= delta
		steps += 1
		if steps % 40 == 0:
			await frames(1)

func capture_board(label: String) -> void:
	clock.step(0.0)
	session._refresh_hud(true)
	await capture(label)
	check_layout(label + "-hud", session.minigame_hud)
	var bench: Control = session.presentation
	var viewport := get_viewport().get_visible_rect()
	var problems := ViewChecks.layout_errors(bench, viewport)
	check(problems.is_empty(), "%s actual Main board bounds/text: %s" % [label, problems])
	check_layout(label, bench)
	var custom_controls := {}
	for command_name in Bench.COMMANDS:
		var button: Button = bench.get_node(command_name.capitalize())
		var screen: Rect2 = screen_rect(button)
		check(button.get_rect().is_equal_approx(Bench.button_rect(command_name)) and clip_for(button).grow(0.01).encloses(screen), "transformed board and hit rectangle " + command_name)
		custom_controls[command_name] = rect_data(screen)
	check(custom_controls.size() == 12, "all twelve actual custom controls")
	layouts.append({"capture": label + ".png", "custom_controls": custom_controls, "bench": rect_data(screen_rect(bench)), "errors": problems})

func run_suite() -> void:
	await exercise_material()
	await key(KEY_ESCAPE)
	await activate(session.minigame_hud, "RetryButton")
	await activate(session.minigame_hud, "ConfirmAction")
	session.presentation.grab_focus()
	clock = SessionClock.new(session)
	check(clock.snapshot().elapsed == 0.0 and not clock.snapshot().participated, "actual HUD retry resets material and time")
	if not await solve("keyboard", false, "ordinary"):
		return
	check(owned_cards().keys() == [ORDINARY] and Progress.coins == admission_coins + 40, "ordinary route first card only and +40")
	var first := record_gameplay("ordinary")
	if not await launch_from_result("再玩一次") or not await solve("pointer", true, "devil"):
		return
	var devil_photos := record_gameplay("devil")
	check(devil_photos.get(ORDINARY, {}) != first.get(ORDINARY, {}) and devil_photos.get(ORDINARY, {}) == devil_photos.get(DEVIL, {}), "actual later gameplay refreshes the shared latest originals")
	if not await launch_from_result("輔助重試") or not await solve("touch", true, "assisted-ai", true):
		return
	var assisted_photos := record_gameplay("assisted-ai")
	check(assisted_photos.get(ORDINARY, {}) != devil_photos.get(ORDINARY, {}) and Progress.photos[DEVIL].challenge_earned, "real assisted device events preserve devil proof and refresh latest gameplay")
	if not await launch_from_result("再玩一次"):
		return
	var route := new_route("pointer")
	var center: Vector2 = clock.snapshot().source_centers[0]
	route.trace(PackedVector2Array([center - Vector2(20, 0), center + Vector2(20, 0)]), false)
	check(clock.snapshot().participated and not clock.snapshot().parts[0].freed, "timeout has a genuine open cut and no freed gear")
	await capture_board("timeout-participated-cut")
	var before := results.size()
	await advance(240.0)
	await frames(6)
	var timed := clock.snapshot()
	check(results.size() == before + 1 and main.session == null and timed.ended and not timed.success and not timed.devil
		and timed.ordinary_eligible and timed.score == 0 and is_equal_approx(timed.elapsed, 240.0), "honest participated natural 240s timeout")
	if results.size() == before + 1:
		var result: Dictionary = results.back()
		check(result.game_id == GAME and not result.success and not result.devil and not result.practice
			and result.ordinary_eligible and result.score == 0, "actual Main reports qualified failure and zero score at timeout")
	routes.append({"label": "timeout", "elapsed": timed.elapsed, "simulated_seconds": clock.simulated, "score": timed.score, "ordinary_eligible": timed.ordinary_eligible, "success": timed.success})
	await capture("timeout-result")
	var prior_photos := profile_receipt()
	if not await launch_from_result("練習操作"):
		return
	check(session.practice_mode, "actual GUI selected practice")
	if not await solve("pointer", true, "practice"):
		return
	check(profile_receipt() == prior_photos, "successful practice preserves cards, provenance, achievement and coins")
	if not await launch_from_result("再練一次"):
		return
	await pause_and_cancel("pause-cancel")
	check(profile_receipt() == prior_photos, "actual paused cancel preserves rewards and photos")

func exercise_material() -> void:
	var route := new_route("keyboard")
	var initial := clock.snapshot()
	route.tap("select")
	check(clock.snapshot().selected == 1 and session.presentation.has_focus(), "Tab selects second gear and retains actual board focus")
	route.select(0)
	route.tap("deep")
	route.tap("deep")
	check(clock.snapshot().depth == 1.0, "parsed depth controls reach deep cut")
	var pointer_route := new_route("pointer")
	var points: PackedVector2Array = clock.snapshot().selected_guides[0]
	pointer_route.trace(points)
	var deep := clock.snapshot()
	check(deep.selected_strokes.size() == 1 and deep.participated, "genuine deep closed heat trace")
	route.tap("undo")
	check(clock.snapshot().selected_strokes.is_empty() and clock.snapshot().elapsed >= deep.elapsed, "actual X undoes committed heat without refunding time")
	route.tap("shallow")
	route.tap("shallow")
	points = clock.snapshot().selected_guides[0]
	pointer_route.trace(points)
	pointer_route.tap("fold")
	var connected := clock.snapshot()
	check(connected.depth == initial.depth and connected.selected_strokes.size() == 1 and not connected.parts[0].freed and connected.feedback.contains("未切透"), "single half-depth contour remains attached")
	await capture_board("shallow-still-connected")
	pointer_route.trace(points)
	pointer_route.tap("fold")
	var folded := clock.snapshot()
	check(folded.parts[0].freed and folded.selected_strokes.size() == 2 and not folded.parts[0].removed_outline.is_empty()
		and not folded.parts[0].outline.is_empty() and folded.parts[0].strength >= maxf(6.0, 0.35 * folded.parts[0].teeth * 4)
		and absf(deep.selected_strokes[0].points[0].distance_to(points[0])) > 0.5, "shallow retrace produces actual remaining material and measured wheel thickness")
	await capture_board("shallow-retrace-folded-hole")
	route.tap("undo")
	check(not clock.snapshot().parts[0].freed and clock.snapshot().selected_strokes.size() == 2 and clock.snapshot().elapsed >= folded.elapsed, "undo restores real material and retains submitted traces")
	await capture_board("undo-restored-material")
	routes.append({"label": "material", "deep": deep.depth, "retrace_depth": folded.depth, "strokes": folded.selected_strokes.size(),
		"strength": folded.parts[0].strength, "outline_points": folded.parts[0].outline.size(), "removed_outline_points": folded.parts[0].removed_outline.size()})

func launch_from_result(text: String) -> bool:
	var match_button: Button
	for button: Button in main.modal_footer.find_children("*", "Button", true, false):
		if button.text == text:
			match_button = button
			break
	await press_button(match_button)
	return await bind_session()

func solve(source: String, idler: bool, label: String, helper := false) -> bool:
	var route := new_route(source)
	var initial := clock.snapshot()
	var before_events := event_total()
	var before_results := results.size()
	var is_practice: bool = session.practice_mode
	if helper:
		route.tap("helper")
		var clamped := clock.snapshot()
		check(initial.assisted and clamped.helper and clamped.helper_clamp is Vector2 and not clamped.participated
			and clamped.selected_strokes.is_empty(), "actual assisted AI clamps only, no trace or participation")
		await capture_board(label + "-clamp")
	if not route.craft(idler):
		check(false, label + " genuine outline could not fold: " + JSON.stringify(route.diagnostic(clock.snapshot())))
		return false
	var material := clock.snapshot()
	check(material.parts[3].freed == idler and material.parts[0].freed and material.parts[1].freed and material.parts[2].freed, label + " genuine freed count and leftover idler condition")
	if idler:
		await capture_board(label + "-leftover-idler-hole")
	route.arrange(idler)
	var arranged := clock.snapshot()
	var contacts := [Vector2i(0, 1), Vector2i(1, 3), Vector2i(2, 3)] if idler else [Vector2i(0, 1), Vector2i(1, 2)]
	check(arranged.connections == contacts, label + " actual measured placement topology")
	route.command("tool", true)
	route.advance(0.75)
	var rotating := clock.snapshot()
	route.drive_angles = rotating.parts.map(func(part): return part.angle)
	check(rotating.output_travel > 1.0 and (rotating.output_omega < 0.0 if idler else rotating.output_omega > 0.0)
		and arranged.parts[0].angle != rotating.parts[0].angle and arranged.parts[2].angle != rotating.parts[2].angle, label + " actual gears rotate and output direction matches topology")
	await capture_board(label + "-output-rotation")
	for i in 18:
		if clock.snapshot().ended:
			break
		clock.step(0.25)
	route.command("tool", false)
	await frames(6)
	var terminal := clock.snapshot()
	var standard := 500 if idler else 400
	var success: bool = terminal.ended and terminal.success and terminal.devil == idler and terminal.ordinary_eligible and terminal.score == standard and terminal.output_travel >= TAU - 1.0e-8
	check(success and main.session == null and results.size() == before_results + 1, label + " genuine natural timed output and Main result")
	if results.size() == before_results + 1:
		var result := results.back() as Dictionary
		check(result.game_id == GAME and result.success and result.devil == idler and result.practice == is_practice
			and result.ordinary_eligible == not is_practice and result.score == standard, label + " Main result metadata")
	var report := route.result(terminal)
	report.merge({"label": label, "parsed_events": event_total() - before_events, "simulated_seconds": clock.simulated,
		"output_omega": rotating.output_omega, "mid_turn": rotating.output_travel, "practice": is_practice})
	routes.append(report)
	print("NATIVE_CHOCOLATE_ROUTE ", JSON.stringify(report))
	await capture(label + "-result")
	return success and main.session == null

func pause_and_cancel(label: String) -> void:
	var route := new_route("pointer")
	var center: Vector2 = clock.snapshot().source_centers[0]
	var start := Bench.board_to_design(center)
	route.pointer(start, true)
	route.motion(Bench.board_to_design(center + Vector2(20, 0)))
	check(clock.snapshot().cutting and clock.snapshot().current_stroke.size() > 1, "actual pointer has a live cut preview")
	await key(KEY_ESCAPE)
	var frozen := clock.snapshot()
	check(session.paused and not frozen.cutting and frozen.current_stroke.is_empty() and frozen.selected_strokes.is_empty(), "actual Esc pauses and drops uncommitted cut")
	await advance(0.25)
	check(clock.snapshot() == frozen, "paused Session freezes actual material and time")
	route.pointer(start, false)
	await capture(label)
	await activate(session.minigame_hud, "LeaveButton")
	await activate(session.minigame_hud, "ConfirmAction")
	check(main.session == null, "actual HUD leave confirmation cancels round")

func run_retake(devil: bool) -> void:
	await activate(main.overlay, "InviteRules")
	check(not Progress.has_attempted_game(GAME), "selected kiosk starts before any actual chocolate attempt")
	await activate(main.overlay, "KioskRetakeDevil" if devil else "KioskRetakeOrdinary")
	if not await bind_session():
		return
	check(session.practice_mode, "actual selected Main retake practice")
	var route := new_route("touch" if devil else "pointer")
	var center: Vector2 = clock.snapshot().source_centers[0]
	route.trace(PackedVector2Array([center - Vector2(10, 0), center + Vector2(10, 0)]), false)
	check(clock.snapshot().participated, "real selected practice cut")
	await key(KEY_ESCAPE)
	await activate(session.minigame_hud, "LeaveButton")
	await activate(session.minigame_hud, "ConfirmAction")
	var panel: Control = main.retake_panel
	check(panel != null and main.modal_kind == "retake" and main.retake_target == {"id": GAME, "devil": devil}
		and owned_cards().is_empty(), "actual selected practice exit returns to retake with no awarded card")
	if panel == null:
		return
	check(panel._valid and panel._props.size() == 3, "existing chocolate prop vocabulary and actual lesson source")
	await capture("retake-demonstration")
	await activate(panel, "RetakeNext")
	await activate(panel, "DecorationChoice")
	await activate(panel, "FramingChoice")
	await activate(panel, "DistanceChoice")
	check(panel.current_step == 1 and panel._decoration != 0 and panel._framing != 1 and panel._distance != 1, "actual retake arrangement changes props, framing, and distance")
	await capture("retake-arranged")
	await activate(panel, "RetakeNext")
	await capture("retake-shutter-preview")
	var photograph: Image = panel._viewport.get_texture().get_image()
	photograph.convert(Image.FORMAT_RGBA8)
	var gpu_path := output.path_join("retake-arranged-subviewport.png")
	check(photograph.get_size() == Vector2i(1280, 720) and photograph.save_png(gpu_path) == OK, "raw arranged retake GPU pixels")
	captures.append(gpu_path.get_file())
	await activate(panel, "RetakeShutter")
	await frames(8)
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
	stored.convert(Image.FORMAT_RGBA8)
	check(stored.get_size() == photograph.get_size() and stored.get_data() == photograph.get_data(), "persisted original equals actual arranged GPU pixels")
	retake_proof = {"target": target, "initial": record, "files": paths, "gpu_capture": gpu_path, "equal_original_pixels": stored.get_data() == photograph.get_data()}
	await capture("retake-saved")
	await activate(panel, "RetakeClose")
	await key(KEY_E)
	if not invitation("physical E after selected retake"):
		return
	if not await start_first_entry(false) or not await solve("touch" if devil else "pointer", devil, "matching-challenge"):
		return
	var earned: Dictionary = Progress.photos.get(target, {})
	check(earned.get("acquisition_method") == "retake" and earned.get("challenge_earned") == devil
		and earned.get("original_frames") == record.original_frames and earned.get("frames") == record.frames
		and photo_files(target, Vector2i(1280, 720)) == paths and Progress.coins == admission_coins + 40,
		"later real matching challenge preserves retake original/thumbnail paths and SHA, method and single receipt")
	check(owned_cards().size() == (2 if devil else 1), "only a genuine later devil result may add the ordinary card")
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
	var expected = JSON.parse_string(FileAccess.get_file_as_string(provenance_path()))
	check(expected is Dictionary, "new process reads writer provenance receipt")
	if not expected is Dictionary:
		return
	var actual := profile_receipt()
	# JSON decodes all numeric atoms as floats. Compare persisted fields with their intended types.
	check(actual.photos == expected.photos and actual.hashes == expected.hashes, "separate process exact acquired IDs, photo paths, SHA and full provenance")
	check(actual.coins == int(expected.coins) and actual.coins == 160 and actual.reward_receipts == int(expected.reward_receipts)
		and actual.reward_receipts == 1 and actual.region == expected.region and actual.region == "candy"
		and actual.lesson_seen and expected.lesson_seen and actual.attempted and expected.attempted
		and actual.achievement and expected.achievement and not owned_cards().is_empty(), "separate process exact region, tutorial, attempt, achievement and coin receipt")
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
		check(stamps != null and stamps.get_child_count() == 5, "actual stamp book lists five factory games")
		var stamp := await find_book_tile("AchievementStamp_" + ACHIEVEMENT, "AchievementNextPage")
		check(stamp != null and visible_copy(stamp).contains("巧克力蝕刻") and visible_copy(stamp).contains("已蓋章"), "actual page displays the earned chocolate stamp")
		await capture(label)
	else:
		await capture_album_tile(ORDINARY, label)
		if Progress.photos.has(DEVIL):
			await activate(main.overlay, "AlbumTab_devil")
			await capture_album_tile(DEVIL, label + "-devil")

func capture_album_tile(id: String, label: String) -> void:
	var tile := await find_book_tile("AlbumPhoto_" + id, "AlbumNextPage")
	check(tile != null and visible_copy(tile).contains("巧克力蝕刻"), "actual album page displays the fixed chocolate photo " + id)
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
			else:
				text_fits = child.get_content_height() <= child.size.y + 1.0
			check(fits and text_fits, "%s %s bounds=%s text_fits=%s clip=%s rect=%s text=%s" % [label, child.name, fits, text_fits, clip, rect, child.text])
			entries.append({"name": str(child.name), "text": child.text, "rect": rect_data(rect), "clip": rect_data(clip),
				"bounds_fit": fits, "text_fits": text_fits})
		collect_layout(label, child, active_group, entries)

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "write receipt " + path)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func finish() -> void:
	write_json(output.path_join("chocolate-evidence.json"), {"checks": checks, "parsed_events": events, "layouts": layouts, "lessons": lessons,
		"routes": routes, "gameplay_photo_history": gameplay_photos, "retake": retake_proof, "profile": profile_receipt(),
		"viewport": [requested.x, requested.y], "ui_scale": Paper.text_scale(), "reduced_motion": Paper.reduced_motion(),
		"mode": mode, "wall_seconds_before_shutdown": (Time.get_ticks_msec() - started) / 1000.0, "failures": failures})
	await super.finish()
