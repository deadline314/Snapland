extends Node
## Fail stickers: the arcade fail hook, capture once per game, storage caps,
## the album tab and that collections and thresholds stay untouched.

const MAIN_SCENE := preload("res://game/main.tscn")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Book = preload("res://game/ui/collection_book_panel.gd")
const Viewer = preload("res://game/ui/fail_replay_viewer.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")

var failures: Array[String] = []
var progress: Node
var main: Node


func _ready() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	call_deferred("_run")


func _run() -> void:
	progress = get_tree().root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.save_progress()
	_base_hook_marks_the_first_fail()
	_every_arcade_game_reaches_its_fail()
	_progress_keeps_one_per_game_within_caps()
	_saves_load_with_and_without_the_field()
	await _main_captures_once_per_game()
	await _album_tab_lists_and_replays()
	if is_instance_valid(main):
		main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		await get_tree().process_frame
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: fail sticker hook, capture once per game, caps, album tab and untouched thresholds")
	get_tree().quit(0 if failures.is_empty() else 1)


func _base_hook_marks_the_first_fail() -> void:
	var game: RefCounted = Base.new()
	game.round_seed = 1
	game.reset(false, "noon")
	_step(game, Base.READY_SECONDS + 0.5)
	_check(float(game.snapshot().fail_at) < 0.0, "a round starts without a fail moment")
	game.funny_fail("哈", false)
	var first: float = game.fail_at
	_step(game, 0.05)
	_check(first > 0.0 and game.mistakes == 0 and game.snapshot().fail_at == first, "a free fail beat is marked without costing a mistake")
	_step(game, 1.0)
	game.funny_fail("又來", true)
	_check(game.fail_at == first and game.mistakes == 1, "only the first fail of a round is kept; later ones still count")
	game.reset(false, "noon")
	_check(game.fail_at < 0.0, "a new round forgets the fail moment")
	_step(game, Base.READY_SECONDS + 0.5)
	game.add_mistake("")
	_check(game.fail_at > 0.0, "games that only report mistakes still mark a fail moment")
	game.reset(false, "noon")
	game.funny_fail("demo", false)
	_check(game.fail_at < 0.0, "the countdown demo never counts as a fail")


func _every_arcade_game_reaches_its_fail() -> void:
	for definition: Dictionary in Catalog.all_definitions():
		if not bool(definition.get("arcade", false)):
			continue
		var failed := false
		for pattern in ["idle", "mash", "hold", "arrows", "keep"]:
			var game: RefCounted = (load("res://game/minigames/arcade/%s_driver.gd" % definition.mode) as Script).new()
			game.round_seed = 4
			game.reset(false, "noon")
			var tick := 0
			while not game.snapshot().ended and float(game.snapshot().fail_at) < 0.0:
				if pattern == "mash" and tick % 2 == 0:
					_key(game, KEY_SPACE, true)
					_key(game, KEY_SPACE, false)
				elif pattern == "hold" and tick % 20 == 0:
					_key(game, KEY_SPACE, tick % 40 == 0)
				elif pattern == "keep" and tick == 0:
					_key(game, KEY_SPACE, true)
				elif pattern == "arrows" and tick % 3 == 0:
					var arrow: Key = [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_SPACE][(tick / 3) % 5]
					_key(game, arrow, true)
					_key(game, arrow, false)
				game.step(0.05)
				tick += 1
			failed = failed or float(game.snapshot().fail_at) >= 0.0
		_check(failed, "%s reaches its fail moment through the shared hook" % definition.id)


func _progress_keeps_one_per_game_within_caps() -> void:
	progress.reset_progress()
	var normal: int = progress.normal_count()
	var state := {"clock": 3.5, "fail_at": 3.2, "at": Vector2(4, 5), "parts": [1, 2]}
	_check(progress.record_fail_sticker("game-049", "", state), "the first fail of a game is kept")
	_check(not progress.record_fail_sticker("game-049", "", {"fail_at": 9.0}), "later fails of the same game change nothing")
	_check(progress.fail_replay("game-049") == state, "the replay state comes back exactly, vectors included")
	_check(not progress.record_fail_sticker("game-001", "", state), "only arcade games keep fail stickers")
	_check(not progress.record_fail_sticker("nope", "", state), "unknown games are refused")
	var huge := {"fail_at": 1.0, "blob": "x".repeat(progress.MAX_FAIL_REPLAY_CHARS)}
	_check(progress.record_fail_sticker("game-050", "C:/missing/fail.png", huge) and progress.fail_stickers["game-050"] == {"frame": "", "replay": ""}, "oversized replays and missing pictures are dropped, the sticker stays")
	_check(progress.normal_count() == normal and progress.devil_count("circus") == 0 and progress.photos.is_empty(), "fail stickers never count as stickers or toward thresholds")
	var saved: Dictionary = progress.fail_stickers.duplicate(true)
	for index in progress.MAX_FAIL_STICKERS:
		progress.fail_stickers["filler-%d" % index] = {"frame": "", "replay": ""}
	_check(not progress.record_fail_sticker("game-061", "", state), "the album stops growing at its cap")
	progress.fail_stickers = saved
	progress.save_progress()


func _saves_load_with_and_without_the_field() -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	progress.load_progress()
	_check(progress.fail_stickers.size() == 2 and progress.fail_replay("game-049").at == Vector2(4, 5), "fail stickers survive a reload")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	on_disk.erase("fail_stickers")
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.fail_stickers.is_empty() and progress.coins == int(on_disk.coins), "an old save without fail stickers loads unchanged")
	on_disk["fail_stickers"] = {"game-049": {"frame": 3}, "game-050": {"frame": "", "replay": ""}}
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.fail_stickers.keys() == ["game-050"], "damaged fail stickers are dropped one by one")
	progress.reset_progress()
	progress.intro_seen = true
	progress.save_progress()


func _main_captures_once_per_game() -> void:
	for zone in ["welcome", "harbor", "candy"]:
		for index in range(1, 11):
			progress.photos["photo-%s-game-%d" % [zone, index]] = {"game_id": "seed"}
	progress.save_progress()
	var normal: int = progress.normal_count()
	get_window().size = Vector2i(1280, 720)
	main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	for _frame in 3:
		await get_tree().process_frame
	var played := 0
	for id in ["game-049", "game-062"]:
		main._launch_game(id, false)
		_check(main.session != null and main.session.has_signal("funny_failed"), "%s opens in a session that reports fails" % id)
		var reported: Array = []
		main.session.funny_failed.connect(func(game_id: String, _state: Dictionary) -> void: reported.append(game_id))
		_play_until_fail(main.session)
		_check(reported == [id] and progress.fail_stickers.has(id), "%s keeps its first fail as a sticker" % id)
		_check(not progress.fail_replay(id).is_empty() and float(progress.fail_replay(id).fail_at) >= 0.0, "%s stores a replayable picture state" % id)
		main.session._finish(false)
		_check(main.overlay.find_child("FailStickerSaved", true, false) != null, "the result card says a fail sticker was saved")
		main._close()
		played += 1
	var kept: Dictionary = progress.fail_stickers.duplicate(true)
	main._launch_game("game-049", false)
	_play_until_fail(main.session)
	main.session._finish(false)
	_check(progress.fail_stickers == kept and main.overlay.find_child("FailStickerSaved", true, false) == null, "failing the same game again keeps the first sticker")
	main._close()
	main._launch_game("game-073", false)
	main.session.set_practice_mode(true)
	_play_until_fail(main.session)
	_check(not progress.fail_stickers.has("game-073"), "practice rounds keep no fail sticker")
	main._cancel_game(false)
	_check(played == 2 and progress.normal_count() == normal, "fail stickers leave the sticker count and thresholds unchanged")


func _album_tab_lists_and_replays() -> void:
	main._show_album("circus")
	await get_tree().process_frame
	var tab := main.overlay.find_child("AlbumTab_fail", true, false) as Button
	_check(tab != null and tab.visible and tab.text.ends_with("1 / %d" % _arcade_count("circus")), "the circus album shows a fail sticker tab with its count")
	var normal_tab := main.overlay.find_child("AlbumTab_normal", true, false) as Button
	var normal_text := normal_tab.text
	tab.pressed.emit()
	await get_tree().process_frame
	var tile := main.overlay.find_child("AlbumPhoto_fail-game-049", true, false) as Button
	_check(tile != null and tile.get_index() == 0, "the collected fail sticker leads its zone's page")
	_check(tile != null and (tile.find_child("AlbumPhotoStatus", true, false) as Label).text == "已收藏 · 可重播", "a collected fail sticker offers its replay")
	_check(main.overlay.find_child("AlbumPhoto_fail-game-050", true, false) != null, "games without a fail yet still show their empty slot")
	_check(normal_tab.text == normal_text, "the ordinary tab count is unchanged")
	tile.pressed.emit()
	await get_tree().process_frame
	var viewer: Node = main.overlay.find_child("FailReplayViewer", true, false)
	_check(viewer != null and viewer.find_child("FailReplayClose", true, false) != null, "choosing it opens the replay viewer with a way back")
	if viewer != null:
		viewer._close()
	await get_tree().process_frame
	main._close()
	main._show_album("welcome")
	await get_tree().process_frame
	tab = main.overlay.find_child("AlbumTab_fail", true, false) as Button
	_check(tab != null and not tab.visible, "zones without arcade games hide the tab")
	main._close()
	var live := Viewer.new()
	live.setup("測試", null, {"fail_at": 1.0, "clock": 1.0}, null, null)
	_check(not live.can_replay(), "a missing picture falls back to the still")
	live.free()


func _arcade_count(zone: String) -> int:
	var count := 0
	for definition: Dictionary in Catalog.definitions(zone):
		if bool(definition.get("arcade", false)):
			count += 1
	return count


func _play_until_fail(session: Control) -> void:
	var tick := 0
	for _step_index in 1200:
		if session == null or not is_instance_valid(session) or session.ended or float(session.active_driver.fail_at) >= 0.0:
			break
		if tick % 2 == 0:
			_key(session.active_driver, KEY_SPACE, true)
			_key(session.active_driver, KEY_SPACE, false)
		session._process(0.05)
		tick += 1
	if is_instance_valid(session) and not session.ended:
		session._process(0.05)


func _key(game: RefCounted, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	game.handle_input(event, Vector2.ZERO)


func _step(game: RefCounted, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game.step(0.05)
		left -= 0.05


func _write(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
