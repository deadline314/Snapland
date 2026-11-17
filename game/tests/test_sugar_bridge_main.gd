extends Node

const Route = preload("res://game/tests/test_sugar_bridge_session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Release = preload("res://game/tests/audio_playback_release.gd")
var main: Node
var failures: Array[String] = []

func _ready() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Sugar Main requires an absolute isolated save")
		get_tree().quit(1)
		return
	get_tree().create_timer(85.0).timeout.connect(func(): push_error("Sugar Main watchdog"); get_tree().quit(1))
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	check(Catalog.find("game-025").get("mode", "") == "sugar_bridge", "game-025 must be delivered before Sugar Main integration can run")
	if not failures.is_empty():
		await _finish()
		return
	get_window().size = Vector2i(1280, 720)
	Progress.reset_progress()
	Progress.intro_seen = true
	main = load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames()
	check(main.definitions.size() == 12 and Catalog.all_definitions().size() == 28, "welcome keeps twelve and delivered island has28")
	check(Catalog.identity("game-025") == {"id":"game-025", "mode":"sugar_bridge", "zone":"candy", "local_index":1, "photo_id":"photo-candy-game-1", "devil_photo_id":"photo-candy-devil-1", "achievement_id":"ACH_GAME_025"}, "first candy card has fixed local1 and global025 identities")
	main._practice_for_retake("game-025", true)
	check(main.session == null and not Progress.has_attempted_game("game-025"), "locked candy retake cannot bypass admission")
	if main.session != null: main._cancel_game(false)
	# Admission fixture only; all target-game results below use actual Session input.
	for i in range(1, 6): Progress.grant_photo("photo-welcome-game-%d" % i)
	Progress.grant_photo("photo-harbor-game-1")
	check(main._travel_to_region("candy"), "six distinct global ordinary cards admit candy")
	await _frames()
	var admission_cards: Dictionary = Progress.photos.duplicate(true)
	Progress.photos.clear()
	check(main._can_access_game("game-025"), "saved current candy region retains legacy recovery without six cards")
	Progress.photos = admission_cards
	check(main.world._point_by_id("game-025").get("id", "") == "game-025", "factory has a real sugar bridge entrance")
	main._interact("game-025", "拉糖橋")
	check(main.modal_kind == "game_info", "factory interaction opens real game invitation")
	main._show_game_rules("game-025")
	check(_text(main.overlay).contains("糖果工廠"), "rules name candy region")
	main._close()
	main._show_map()
	var games_button = main.overlay.find_child("RegionGamesButton", true, false)
	check(games_button is Button, "factory map exposes regional game entry page")
	if games_button != null: games_button.pressed.emit()
	var action = main.overlay.find_child("HarborGamegame-025", true, false)
	check(action is Button, "factory map offers delivered sugar bridge")
	if action != null: action.pressed.emit()
	check(main.modal_kind == "game_info", "map routes through normal invitation")
	main._request_game_start("game-025", false)
	await _frames()
	check(is_instance_valid(main.tutorial_panel) and main.tutorial_target == "game-025", "first entry opens sugar material lesson")
	main._tutorial_start("game-025")
	await _frames()
	check(Progress.has_seen_tutorial("game-025") and main.session != null, "lesson saves and launches025")
	if main.session == null:
		await _finish()
		return
	main.session.set_process(false)
	Route.advance(main.session, 151.0)
	check(main.session == null and not Progress.photos.has("photo-candy-game-1"), "idle timeout awards no card")
	main._launch_game("game-025", false)
	main.session.set_process(false)
	Route.tap(main.session, KEY_ENTER)
	Route.advance(main.session, 151.0)
	check(main.session == null and Progress.normal_count_for_zone("candy") == 1 and Progress.devil_count("candy") == 0, "participated timeout earns only candy ordinary")
	check(_text(main.overlay).contains("普通拍貼已收藏") and Progress.achievements.has("ACH_GAME_025"), "result and first-card achievement reflect saved ordinary")
	var coins: int = Progress.coins
	var ordinary: Dictionary = Progress.photos.get("photo-candy-game-1", {}).duplicate(true)
	main._launch_game("game-025", false, true)
	check(Route.solve(main.session, true), "real practice sling and transport route")
	check(main.session == null and Progress.coins == coins and not Progress.photos.has("photo-candy-devil-1"), "practice awards nothing")
	main._launch_game("game-025", false)
	check(Route.solve(main.session), "real ordinary long bridge route")
	check(Progress.coins == coins and Progress.photos["photo-candy-game-1"] == ordinary, "repeat ordinary preserves first record and receipt")
	main._launch_game("game-025", true)
	check(Route.solve(main.session, true), "real assisted same-band sling route")
	check(main.session == null and Progress.devil_count("candy") == 1 and Progress.coins == coins and Progress.photos["photo-candy-devil-1"].challenge_earned, "assisted devil awards once without duplicate coins")
	main._launch_game("game-025", false)
	Route.tap(main.session, KEY_ENTER)
	main.session._leave_from_hud()
	check(main.session == null and Progress.coins == coins and Progress.normal_count_for_zone("candy") == 1, "cancel cannot duplicate awards")
	check(not Progress.photos.has("photo-candy-game-2") and not Progress.photos.has("photo-harbor-game-12"), "025 never grants the other candy or existing harbor cards")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.current_region == "candy" and Progress.has_seen_tutorial("game-025") and Progress.achievements.has("ACH_GAME_025") and Progress.normal_count_for_zone("candy") == 1 and Progress.devil_count("candy") == 1 and Progress.coins == coins, "saved restart retains candy identity, tutorial, cards and receipt")
	await _retake_after_reset()
	await _finish()

func _retake_after_reset() -> void:
	Progress.reset_progress()
	Progress.intro_seen = true
	for i in range(1, 7): Progress.grant_photo("photo-welcome-game-%d" % i)
	main._close()
	await _frames()
	check(main._travel_to_region("candy"), "fresh retake fixture reenters candy after profile reset")
	await _frames()
	main._practice_for_retake("game-025", true)
	check(main.session != null and main.session.practice_mode, "actual candy practice records a retake attempt")
	if main.session == null: return
	main.session._leave_from_hud()
	check(main.modal_kind == "retake" and main.retake_target == {"id":"game-025", "devil":true}, "practice cancel restores selected candy retake")
	if main.retake_panel == null: return
	# Valid image fixture tests persistence; native evidence separately proves the rendered shutter.
	var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	var panel: Control = main.retake_panel
	check(panel._valid and panel._props.size() == 3 and not panel._next.disabled, "candy retake has a valid real set before image persistence")
	if not panel._valid: return
	panel._next.pressed.emit()
	panel._next.pressed.emit()
	check(panel.current_step == 2 and not panel._shutter.disabled, "candy retake reaches the enabled real shutter before fixture capture")
	panel._awaiting_result = true
	var before: int = Progress.coins
	main._retake_capture(image, panel, main.retake_generation, "game-025", true)
	var record: Dictionary = Progress.photos.get("photo-candy-devil-1", {}).duplicate(true)
	check(record.get("acquisition_method", "") == "retake" and not record.get("challenge_earned", true) and not Progress.photos.has("photo-candy-game-1"), "selected retake grants only devil with honest provenance")
	check(record.get("frames", []).size() == 1 and record.get("original_frames", []).size() == 1 and Progress.coins == before + 40 and Progress.achievements.has("ACH_GAME_025"), "retake saves thumbnail/original and global025 first-card receipt")
	main._close()
	main._show_album()
	await _frames()
	var book = _book(main.overlay)
	check(book != null and book._entries().size() == 4, "candy album exposes four real local entries")
	if book != null:
		for devil in [false,true]:
			var entry: Dictionary = book._game_entry(Catalog.find("game-025"),Catalog.identity("game-025"),devil)
			check(str(entry.instructions).contains("糖果工廠 · 固定遊戲亭：拉糖橋") and not str(entry.instructions).contains("迎賓大道"), "both candy card details name the real factory")
			if not devil: check(str(entry.instructions).contains("參與操作"), "candy ordinary card details require actual participation")
		check(book._saved_texture("photo-candy-devil-1") != null and book._thumbnail_decode_count > 0, "candy saved card uses validated game-photo decoding")
	main._close()
	main._launch_game("game-025", true)
	check(Route.solve(main.session, true), "real challenge after retake earns proof")
	var earned: Dictionary = Progress.photos.get("photo-candy-devil-1", {})
	check(earned.get("challenge_earned", false) and earned.get("frames", []) == record.get("frames", []) and earned.get("original_frames", []) == record.get("original_frames", []) and earned.get("acquisition_method", "") == "retake" and Progress.coins == before + 40, "real challenge preserves retake originals and first provenance without new money")
	Progress._reset_memory()
	Progress.load_progress()
	check(Progress.photos.get("photo-candy-devil-1", {}) == earned and Progress.has_attempted_game("game-025"), "reload keeps retake photos, actual proof and attempt")

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
	print("PASS: sugar Main candy entry, tutorial, real results, fixed rewards, selected retake originals and reload" if failures.is_empty() else "FAIL: sugar Main")
	get_tree().quit(0 if failures.is_empty() else 1)
