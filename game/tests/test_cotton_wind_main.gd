extends Node

const Round = preload("res://game/tests/test_cotton_wind_session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Lessons = preload("res://game/ui/tutorial_catalog.gd")
const Book = preload("res://game/ui/collection_book_panel.gd")
const Keys = preload("res://game/tests/retake_native_route.gd")
const RulesLayout = preload("res://game/tests/native_game_rules_layout_review.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
const Release = preload("res://game/tests/audio_playback_release.gd")
const GAME := "game-030"
const MODE := "cotton_wind"
const ORDINARY := "photo-candy-game-6"
const DEVIL := "photo-candy-devil-6"
const ACHIEVEMENT := "ACH_GAME_030"

var main: Node
var checks := 0
var failures := 0

func _ready() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	get_tree().create_timer(90.0).timeout.connect(func(): push_error("Cotton Main watchdog"); get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	check(Catalog.identity(GAME) == {"id": GAME, "mode": MODE, "zone": "candy", "local_index": 6,
		"photo_id": ORDINARY, "devil_photo_id": DEVIL, "achievement_id": ACHIEVEMENT}, "fixed sixth factory identity")
	if failures:
		await _finish()
		return
	check(Catalog.find(MODE) == Catalog.find(GAME) and Catalog.find("game-033").is_empty(),
		"mode lookup resolves delivered game 30 while game 33 remains unavailable")
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames()
	main._practice_for_retake(GAME, true)
	check(main.session == null and not Progress.has_attempted_game(GAME), "locked retake cannot bypass the factory gate")
	print("COTTON SYNTHETIC ADMISSION: six welcome cards, opening seen")
	for index in range(1, 7):
		Progress.grant_photo("photo-welcome-game-%d" % index)
	check(main._travel_to_region("candy"), "the six admission cards open the real factory")
	await _frames()
	await _check_entries()
	if not _invitation():
		await _finish()
		return
	await _check_rules()
	if not await _open_lesson():
		await _finish()
		return
	_check_rewards()
	await _check_book()
	for devil: bool in [false, true]:
		await _check_retake_io(devil)
	await _finish()

func _check_entries() -> void:
	var world: Node3D = main.world
	var capsule := world.player.get_child(0) as CollisionShape3D
	var shape := capsule.shape as CapsuleShape3D
	var stations := [Vector2(0, -9), Vector2(-5, 2), Vector2(7, -6), Vector2(7, -1), Vector2(10.5, -0.8), Vector2(6.5, 10)]
	for index in stations.size():
		var id := "game-%03d" % (25 + index)
		var point: Vector2 = stations[index]
		var expected := Vector3(point.x, world.GROUND_Y, point.y)
		check(world._point_by_id(id).get("position") == expected, "factory preserves station coordinates for " + id)
		world.player.position = expected
		world.player.velocity = Vector3.ZERO
		for frame in 4:
			await get_tree().physics_frame
		var feet := capsule.global_position - Vector3.UP * shape.height * 0.5
		check(world.player.is_on_floor() and feet.distance_to(expected) < 0.02 and world.nearest.get("id") == id,
			"real physics supports controlled footing and the nearest E point at " + id)
	var query := PhysicsRayQueryParameters3D.create(Vector3(6.5, 0.8, 10), Vector3(6.5, -1.0, 10))
	query.exclude = [world.player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and absf(hit.position.y - world.GROUND_Y) < 0.001, "real floor collision under the cotton station")
	print("COTTON CONTROLLED STATION placement=(6.5,0.2,10) body_origin=%s feet=%s collision=%s nearest=%s" %
		[world.player.position, capsule.global_position - Vector3.UP * shape.height * 0.5, hit.get("position"), world.nearest.get("id")])
	await Keys.key(get_viewport(), KEY_E)
	check(_invitation(), "a viewport E event at the real selected station opens its invitation")

func _invitation() -> bool:
	var title := main.overlay.find_child("InviteTitle", true, false) as Label
	return main.modal_kind == "game_info" and title != null and title.is_visible_in_tree() and title.text == "棉糖捲風"

func _check_rules() -> void:
	get_window().size = Vector2i(800, 600)
	Paper.set_text_scale(1.25)
	Progress.settings["ui_scale"] = 1.25
	Progress.settings["reduced_motion"] = true
	var rules := main.overlay.find_child("InviteRules", true, false) as Button
	await Keys.activate(rules)
	await _frames()
	var pager := main.overlay.find_child("GameRulesExtraDetails", true, false) as Control
	check(pager != null and int(pager.get_meta("page_count", 0)) == 7, "seven rules pages open from the invitation")
	if pager != null:
		var copy := ""
		for page in int(pager.get_meta("page_count")):
			await _frames()
			var problems := RulesLayout.inspect_layout(main)
			check(problems.is_empty(), "800×600 at 1.25 rules page %d fits: %s" % [page + 1, problems])
			copy += _visible_text(main.overlay)
			if page + 1 < int(pager.get_meta("page_count")):
				main.overlay.find_child("GameRulesExtraDetailsNext", true, false).pressed.emit()
		check(copy.contains("120 秒") and copy.contains("0.5 弧度") and copy.contains("另一外段") and copy.contains("只用另一支棒"),
			"rules distinguish the deadline, actual participation, rejoin and separate helper")
	main._close()
	get_window().size = Vector2i(1280, 720)
	Progress.settings["ui_scale"] = 1.0
	Paper.set_text_scale(1.0)

func _open_lesson() -> bool:
	main._show_map()
	var games := main.overlay.find_child("RegionGamesButton", true, false) as Button
	check(games != null, "the factory map exposes its games")
	if games == null:
		return false
	games.pressed.emit()
	await _frames()
	var grid := main.overlay.find_child("RegionalGameEntriesGrid", true, false) as GridContainer
	var action := main.overlay.find_child("HarborGame" + GAME, true, false) as Button
	check(grid != null and grid.get_child_count() == Catalog.definitions("candy").size() and action != null, "factory map exposes all delivered games")
	if action == null:
		return false
	await Keys.activate(action)
	check(_invitation(), "focused map entry opens the matching invitation")
	if not _invitation():
		return false
	var start := main.overlay.find_child("InviteStart", true, false) as Button
	await Keys.activate(start)
	await _frames()
	var panel: Control = main.tutorial_panel
	check(is_instance_valid(panel) and main.tutorial_target == GAME and Lessons.new().lesson_ids().size() == Catalog.all_definitions().size() + 1,
		"first entry opens cotton among the delivered park/game lessons")
	if not is_instance_valid(panel):
		return false
	for step in 3:
		await _frames()
		var texture: Texture2D = panel._image.texture
		check(texture != null and texture.resource_path == "res://assets/ui/tutorials/game-030-step-%02d.png" % (step + 1),
			"lesson step %d uses its actual supplied workbench PNG" % (step + 1))
		if step < 2:
			panel.next_step()
	await Keys.activate(panel._start_button)
	check(Progress.has_seen_tutorial(GAME) and main.session != null and main.session.presentation_mode == MODE
		and Progress.has_attempted_game(GAME), "lesson start saves seen/attempt state and opens the current mode")
	return main.session != null

func _check_rewards() -> void:
	var initial_coins := Progress.coins
	main.session.set_process(false)
	Round.key(main.session, KEY_R, true)
	Round.key(main.session, KEY_R, false)
	Round.advance(main.session, 121.0)
	check(main.session == null and not Progress.photos.has(ORDINARY) and not Progress.achievements.has(ACHIEVEMENT)
		and Progress.coins == initial_coins, "helper-only deadline awards nothing")
	var session := _launch(false)
	check(Round.participate(session).participated, "ordinary timeout first deposits material through real movement and spin")
	Round.advance(session, 121.0)
	var ordinary: Dictionary = Progress.photos.get(ORDINARY, {}).duplicate(true)
	check(main.session == null and ordinary.get("game_id") == GAME and not ordinary.get("devil", true) and not Progress.photos.has(DEVIL)
		and _visible_text(main.overlay).contains("普通拍貼已收藏"), "formal participated timeout collects only the ordinary factory card")
	check(Progress.achievements.has(ACHIEVEMENT) and Progress.coins == initial_coins + 40 and Progress.wardrobe_rewarded_games.count(GAME) == 1,
		"ordinary collection grants fixed achievement and one 40-point receipt")
	var practice := Round.play(_launch(true, true), "touch", true)
	check(practice.success and practice.rejoins == 1 and not Progress.photos.has(DEVIL) and Progress.coins == initial_coins + 40,
		"an actual practice rejoin and confirmation awards nothing")
	var repeated := Round.play(_launch(false), "mouse", false)
	check(repeated.success and repeated.score == 400 and Progress.photos.get(ORDINARY) == ordinary and Progress.coins == initial_coins + 40,
		"real ordinary success preserves the first card and receipt")
	var devil := Round.play(_launch(true), "touch", true)
	check(devil.success and devil.score == 500 and devil.rejoins == 1 and Progress.photos.get(DEVIL, {}).get("challenge_earned", false)
		and Progress.photos[DEVIL].get("game_id") == GAME and Progress.photos[DEVIL].get("acquisition_method", "gameplay") == "gameplay",
		"real rejoin and F award the fixed devil card with honest game provenance")
	session = _launch(false)
	check(Round.participate(session).participated, "cancelled formal run actually participates")
	session.minigame_hud.leave_requested.emit()
	check(main.session == null and Progress.normal_count_for_zone("candy") == 1 and Progress.devil_count("candy") == 1
		and Progress.coins == initial_coins + 40 and Progress.wardrobe_rewarded_games.count(GAME) == 1,
		"cancel and existing cards leave counts and receipt unchanged")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.current_region == "candy" and Progress.has_seen_tutorial(GAME) and Progress.has_attempted_game(GAME)
		and Progress.achievements.has(ACHIEVEMENT) and Progress.photos.get(ORDINARY) == ordinary
		and Progress.photos.get(DEVIL, {}).get("challenge_earned", false) and Progress.coins == initial_coins + 40,
		"isolated save reload retains the real results and honest provenance")
	check(not Progress.photos.has("photo-candy-game-1") and not Progress.photos.has("photo-candy-devil-5")
		and not Progress.photos.has("photo-harbor-game-12"), "cotton cannot award adjacent factory or harbor cards")

func _launch(assist: bool, practice := false) -> Control:
	main._launch_game(GAME, assist, practice)
	var session: Control = main.session
	session.set_process(false)
	return session

func _check_book() -> void:
	main._show_achievements()
	await _frames()
	var stamps := main.overlay.find_child("MinigameStampGrid", true, false) as GridContainer
	check(stamps != null and stamps.get_child_count() == Catalog.definitions("candy").size() and _visible_text(main.overlay).contains("棉糖捲風"), "factory stamp book shows sixth regional entry")
	main._close()
	main._show_ticket()
	var available := Catalog.definitions("candy").size()
	check(_visible_text(main.overlay).contains("%d / 12" % available) and _visible_text(main.overlay).contains("其餘 %d 款準備中" % (12 - available)), "ticket states actual availability")
	main.overlay.find_child("TicketAction7", true, false).pressed.emit()
	await _frames()
	var lessons := main.overlay.find_child("CandyTutorialChoices", true, false) as GridContainer
	check(lessons != null and lessons.get_child_count() == Catalog.definitions("candy").size() and lessons.find_child("CandyTutorial_" + GAME, true, false) != null,
		"factory ticket guide lists all available lessons")
	main._close()
	main._show_album()
	await _frames()
	var book := _find_book(main.overlay)
	check(book != null and book._definitions.size() == Catalog.definitions("candy").size() and book._definitions[5] == Catalog.all_definitions()[29]
		and book._definitions[5].id == GAME and book._entries().size() == Catalog.definitions("candy").size(),
		"existing collection book maps global row 30 to the sixth factory card")
	if book != null:
		var ordinary: Dictionary = book._game_entry(Catalog.find(GAME), Catalog.identity(GAME), false)
		var devil: Dictionary = book._game_entry(Catalog.find(GAME), Catalog.identity(GAME), true)
		check(ordinary.id == ORDINARY and ordinary.instructions.contains("參與操作") and ordinary.instructions.contains("糖果工廠 · 固定遊戲亭：棉糖捲風")
			and devil.id == DEVIL and devil.instructions.contains("實際技巧已達成"), "both card instructions identify the correct kiosk and earned proof")
	main._close()

func _check_retake_io(devil: bool) -> void:
	var photo_id := DEVIL if devil else ORDINARY
	var other_id := ORDINARY if devil else DEVIL
	Progress.reset_progress()
	Progress.intro_seen = true
	for index in range(1, 7):
		Progress.grant_photo("photo-welcome-game-%d" % index)
	await _frames()
	check(main._travel_to_region("candy"), "fresh isolated retake fixture opens factory")
	await _frames()
	main._practice_for_retake(GAME, devil)
	check(main.session != null and main.session.practice_mode and Progress.has_attempted_game(GAME), "real practice enables the selected retake")
	if main.session == null:
		return
	main.session.minigame_hud.leave_requested.emit()
	var panel: Control = main.retake_panel
	check(is_instance_valid(panel) and main.retake_target == {"id": GAME, "devil": devil}
		and panel._valid and panel._props.size() == 3, "selected 030 retake opens the real set with three existing props")
	if not is_instance_valid(panel) or not panel._valid:
		return
	panel._next.pressed.emit()
	panel._next.pressed.emit()
	check(panel.current_step == 2 and not panel._shutter.disabled, "selected retake reaches its actual enabled shutter")
	var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	image.set_pixel(10, 10, Color.BLUE)
	var initial_coins := Progress.coins
	print("COTTON SYNTHETIC PNG STORAGE I/O: inject image at capture signal for ", photo_id)
	panel.capture_requested.emit(image)
	var record: Dictionary = Progress.photos.get(photo_id, {}).duplicate(true)
	check(record.get("acquisition_method") == "retake" and not record.get("challenge_earned", true) and not Progress.photos.has(other_id)
		and Progress.coins == initial_coins + 40 and Progress.achievements.has(ACHIEVEMENT), "retake I/O grants just the selected card and first receipt")
	if record.get("original_frames", []).size() != 1 or record.get("frames", []).size() != 1:
		check(false, "retake persists both expected PNG sizes")
		return
	var original_path: String = record.original_frames[0]
	var original := Image.load_from_file(original_path)
	var thumbnail := Image.load_from_file(record.frames[0])
	var original_hash := FileAccess.get_sha256(original_path)
	check(original != null and original.get_size() == Vector2i(1280, 720) and original.get_data() == image.get_data()
		and thumbnail != null and thumbnail.get_size() == Vector2i(320, 180), "synthetic I/O preserves original pixels and creates a bounded thumbnail")
	main._close()
	main._show_album()
	await _frames()
	var book := _find_book(main.overlay)
	var decoded: Texture2D = book._saved_texture(photo_id) if book != null else null
	check(decoded != null and decoded.get_size() == Vector2(320, 180), "album decodes the correct stored thumbnail")
	main._close()
	var outcome := Round.play(_launch(devil), "mouse", devil)
	var earned: Dictionary = Progress.photos.get(photo_id, {})
	check(outcome.success and outcome.rejoins == int(devil) and earned.get("challenge_earned", false) == devil
		and earned.get("acquisition_method") == "retake" and earned.get("frames") == record.frames
		and earned.get("original_frames") == record.original_frames and Progress.coins == initial_coins + 40,
		"actual replay keeps selected retake provenance, paths and first receipt")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.photos.get(photo_id) == earned and FileAccess.get_sha256(original_path) == original_hash
		and Progress.wardrobe_rewarded_games.count(GAME) == 1, "reload keeps retake bytes and achievement receipt")
	print("COTTON RETAKE I/O receipt ", JSON.stringify({"photo": photo_id, "original_sha256": original_hash, "thumbnail_sha256": FileAccess.get_sha256(record.frames[0])}))

func _find_book(node: Node) -> Control:
	if node.get_script() == Book:
		return node
	for child in node.get_children():
		var found := _find_book(child)
		if found != null:
			return found
	return null

func _visible_text(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree():
		return ""
	var result := str(node.text) if node is Label else ""
	for child in node.get_children():
		result += "\n" + _visible_text(child)
	return result

func _frames() -> void:
	for frame in 4:
		await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func _finish() -> void:
	if is_instance_valid(main):
		main.quitting = true
		var playbacks := Release.capture(main.audio)
		main.audio.shutdown()
		main.queue_free()
		await _frames()
		check(await Release.wait_for_release(get_tree(), playbacks), "audio teardown releases backend playbacks")
	print("Cotton wind Main: %d checks, %d failures" % [checks, failures])
	get_tree().quit(int(failures != 0))
