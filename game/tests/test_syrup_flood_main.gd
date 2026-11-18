extends Node

const Route = preload("res://game/tests/test_syrup_flood_session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Release = preload("res://game/tests/audio_playback_release.gd")
var main: Node
var failures: Array[String] = []

func _ready() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Syrup Main requires an absolute isolated save")
		get_tree().quit(1)
		return
	get_tree().create_timer(85.0).timeout.connect(func(): push_error("Syrup Main watchdog"); get_tree().quit(1))
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	check(Catalog.find("game-027").get("mode", "") == "syrup_flood", "game-027 must be delivered before Syrup Main integration can run")
	if not failures.is_empty():
		await _finish()
		return
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames()
	check(main.definitions.size() == 12 and Catalog.all_definitions().size() == 30, "welcome keeps twelve and delivered island has 30")
	check(Catalog.identity("game-027") == {"id":"game-027", "mode":"syrup_flood", "zone":"candy", "local_index":3, "photo_id":"photo-candy-game-3", "devil_photo_id":"photo-candy-devil-3", "achievement_id":"ACH_GAME_027"}, "third candy card has fixed local3 and global027 identities")
	main._practice_for_retake("game-027", true)
	check(main.session == null and not Progress.has_attempted_game("game-027"), "locked candy retake cannot bypass admission")
	if main.session != null: main._cancel_game(false)
	# Synthetic admission context only: six welcome cards and opening seen; no027 state/results/rewards seeded.
	print("SYNTHETIC ADMISSION: six welcome cards and opening seen")
	for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
	check(main._travel_to_region("candy"), "six distinct global ordinary cards admit candy")
	await _frames()
	var admission_cards: Dictionary = Progress.photos.duplicate(true)
	Progress.photos.clear()
	check(main._can_access_game("game-027"), "saved current candy region retains legacy recovery without six cards")
	Progress.photos = admission_cards
	check(main.world._point_by_id("game-027").get("id", "") == "game-027" and main.world._point_by_id("game-026").get("id", "") == "game-026" and main.world._point_by_id("game-025").get("id", "") == "game-025", "factory preserves all three actual entrances")
	main.world.player.position = Vector3(7, main.world.GROUND_Y, -6)
	main.world.player.velocity = Vector3.ZERO
	for i in 3: await get_tree().physics_frame
	check(main.world.nearest.get("id", "") == "game-027", "actual factory footing selects the physical third entrance")
	main.world.interact()
	check(main.modal_kind == "game_info", "factory interaction opens real game invitation")
	main._show_game_rules("game-027")
	check(_text(main.overlay).contains("糖果工廠"), "rules name the candy region")
	var rules_next: Button = main.overlay.find_child("GameRulesExtraDetailsNext", true, false)
	check(rules_next != null, "rules expose the participation page")
	if rules_next != null:
		var rules_pager: Control=main.overlay.find_child("GameRulesExtraDetails",true,false)
		for page in int(rules_pager.get_meta("page_count")):
			if main.overlay.find_child("RulesNote1",true,false)!=null: break
			rules_next.pressed.emit()
	check(_text(main.overlay).contains("參與操作") and _text(main.overlay).contains("未操作"), "rules require actual participation and explain idle exclusion")
	main._close()
	main._show_map()
	var games_button = main.overlay.find_child("RegionGamesButton", true, false)
	check(games_button is Button, "factory map exposes regional game entry page")
	if games_button != null: games_button.pressed.emit()
	var action = main.overlay.find_child("HarborGamegame-027", true, false)
	check(action is Button, "factory map offers delivered syrup flood")
	if action != null: action.pressed.emit()
	check(main.modal_kind == "game_info", "map routes through normal invitation")
	main._request_game_start("game-027", false)
	await _frames()
	check(is_instance_valid(main.tutorial_panel) and main.tutorial_target == "game-027", "first entry opens syrup flood lesson")
	main._tutorial_start("game-027")
	await _frames()
	check(Progress.has_seen_tutorial("game-027") and main.session != null, "lesson saves and launches027")
	if main.session == null:
		await _finish()
		return
	main.session.set_process(false)
	Route.advance(main.session, 76.0)
	check(main.session == null and not Progress.photos.has("photo-candy-game-3"), "idle timeout awards no card")
	var initial_coins: int = Progress.coins
	main._launch_game("game-027", false)
	main.session.set_process(false)
	Route.key(main.session, KEY_SPACE)
	Route.key(main.session, KEY_SPACE, false)
	Route.tap(main.session, KEY_SPACE)
	Route.advance(main.session, 76.0)
	check(main.session == null and Progress.normal_count_for_zone("candy") == 1 and Progress.devil_count("candy") == 0, "participated timeout earns only candy ordinary")
	check(_text(main.overlay).contains("普通拍貼已收藏") and Progress.achievements.has("ACH_GAME_027") and Progress.coins == initial_coins + 40, "result, achievement and single40-coin receipt reflect ordinary")
	var coins: int = Progress.coins
	var ordinary: Dictionary = Progress.photos.get("photo-candy-game-3", {}).duplicate(true)
	main._launch_game("game-027", false, true)
	check(Route.solve(main.session, true), "real three-tank practice route")
	check(main.session == null and Progress.coins == coins and not Progress.photos.has("photo-candy-devil-3"), "practice awards nothing")
	main._launch_game("game-027", false)
	check(Route.solve(main.session), "real three-tank ordinary route")
	check(Progress.coins == coins and Progress.photos["photo-candy-game-3"] == ordinary, "repeat ordinary preserves first record and receipt")
	main._launch_game("game-027", true)
	check(Route.solve(main.session, true), "real assisted cold plug route")
	check(main.session == null and Progress.devil_count("candy") == 1 and Progress.coins == coins and Progress.photos["photo-candy-devil-3"].challenge_earned, "assisted devil awards once without duplicate coins")
	main._launch_game("game-027", false)
	Route.key(main.session, KEY_SPACE)
	Route.key(main.session, KEY_SPACE, false)
	Route.tap(main.session, KEY_SPACE)
	main.session._leave_from_hud()
	check(main.session == null and Progress.coins == coins and Progress.normal_count_for_zone("candy") == 1, "cancel cannot duplicate awards")
	check(not Progress.photos.has("photo-candy-game-1") and not Progress.photos.has("photo-candy-devil-1") and not Progress.photos.has("photo-harbor-game-12"), "027 never grants first candy or existing harbor cards")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.current_region == "candy" and Progress.has_seen_tutorial("game-027") and Progress.achievements.has("ACH_GAME_027") and Progress.normal_count_for_zone("candy") == 1 and Progress.devil_count("candy") == 1 and Progress.coins == coins, "saved restart retains candy identity, tutorial, cards and receipt")
	for devil in [false,true]: await _retake_after_reset(devil)
	await _finish()

func _retake_after_reset(devil: bool) -> void:
	var photo_id := "photo-candy-devil-3" if devil else "photo-candy-game-3"
	var other_id := "photo-candy-game-3" if devil else "photo-candy-devil-3"
	Progress.reset_progress()
	Progress.intro_seen = true
	for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
	main._close()
	await _frames()
	check(main._travel_to_region("candy"), "fresh retake fixture reenters candy after profile reset")
	await _frames()
	main._practice_for_retake("game-027", devil)
	check(main.session != null and main.session.practice_mode, "actual candy practice records a retake attempt")
	if main.session == null: return
	main.session._leave_from_hud()
	check(main.modal_kind == "retake" and main.retake_target == {"id":"game-027", "devil":devil}, "practice cancel restores selected candy retake")
	if main.retake_panel == null: return
	var panel: Control = main.retake_panel
	check(panel._valid and panel._props.size() == 3 and not panel._next.disabled, "candy retake has a valid real set before image persistence")
	if not panel._valid: return
	panel._next.pressed.emit()
	panel._next.pressed.emit()
	check(panel.current_step == 2 and not panel._shutter.disabled, "candy retake reaches the enabled real shutter before fixture capture")
	if panel.current_step != 2 or panel._shutter.disabled: return
	# Synthetic image fixture verifies PNG I/O only; actual GPU capture/provenance belongs to Task4.
	print("SYNTHETIC PHOTO: PNG I/O fixture after actual selected retake reaches shutter")
	var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	image.set_pixel(10, 10, Color.BLUE)
	panel._awaiting_result = true
	var before: int = Progress.coins
	main._retake_capture(image, panel, main.retake_generation, "game-027", devil)
	var record: Dictionary = Progress.photos.get(photo_id, {}).duplicate(true)
	check(record.get("acquisition_method", "") == "retake" and not record.get("challenge_earned", true) and not Progress.photos.has(other_id), "selected retake grants only the requested card with honest provenance")
	check(record.get("frames", []).size() == 1 and record.get("original_frames", []).size() == 1 and Progress.coins == before + 40 and Progress.achievements.has("ACH_GAME_027"), "retake saves thumbnail/original and global027 first-card receipt")
	var original_path := str(record.get("original_frames", [""])[0])
	var original := Image.load_from_file(original_path)
	check(original != null and original.get_size() == image.get_size() and original.get_data() == image.get_data(), "synthetic PNG I/O preserves full resolution and source pixels")
	var original_hash := FileAccess.get_sha256(original_path)
	main._close()
	main._show_album()
	await _frames()
	var book = _book(main.overlay)
	check(book != null and book._entries().size() == 6, "candy album exposes six real local entries")
	if book != null:
		for detail_devil in [false,true]:
			var entry: Dictionary = book._game_entry(Catalog.find("game-027"),Catalog.identity("game-027"),detail_devil)
			check(str(entry.instructions).contains("糖果工廠 · 固定遊戲亭：糖漿分洪") and not str(entry.instructions).contains("迎賓大道"), "both candy card details name the real factory")
			if not detail_devil: check(str(entry.instructions).contains("參與操作"), "candy ordinary card details require actual participation")
		check(book._saved_texture(photo_id) != null and book._thumbnail_decode_count > 0, "candy saved card uses validated game-photo decoding")
	main._close()
	main._launch_game("game-027", devil)
	check(Route.solve(main.session, devil), "real challenge after retake earns proof")
	var earned: Dictionary = Progress.photos.get(photo_id, {})
	check((earned.get("challenge_earned", false) == devil) and earned.get("frames", []) == record.get("frames", []) and earned.get("original_frames", []) == record.get("original_frames", []) and earned.get("acquisition_method", "") == "retake" and Progress.coins == before + 40, "real challenge preserves retake originals and first provenance without new money")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.photos.get(photo_id, {}) == earned and Progress.has_attempted_game("game-027") and FileAccess.get_sha256(original_path) == original_hash, "reload keeps retake photos byte-identical, actual proof and attempt")

func _frames() -> void:
	for i in 4: await get_tree().process_frame

func _text(node: Node) -> String:
	var result := str(node.text) if node is Label else ""
	for child in node.get_children(): result += "\n" + _text(child)
	return result

func _book(node: Node) -> Node:
	if node.get_script() == preload("res://game/ui/collection_book_panel.gd"): return node
	for child in node.get_children():
		var found := _book(child)
		if found != null: return found
	return null

func _finish() -> void:
	if is_instance_valid(main):
		main.quitting = true
		var playbacks: Array[WeakRef] = Release.capture(main.audio)
		main.audio.shutdown()
		main.queue_free()
		await _frames()
		check(await Release.wait_for_release(get_tree(), playbacks), "audio backend releases stopped playbacks before exit")
	for message in failures: push_error(message)
	print("PASS: syrup Main factory entry, three real filled closed tanks, fixed rewards, selected retake originals and reload" if failures.is_empty() else "FAIL: syrup Main")
	get_tree().quit(0 if failures.is_empty() else 1)
