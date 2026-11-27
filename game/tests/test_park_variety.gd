extends Node
## Today's recommended booths and the arcade marathon: rules, coins, saves and the main flow.

const MAIN_SCENE := preload("res://game/main.tscn")
const ParkVariety = preload("res://game/core/park_variety.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Session = preload("res://game/minigames/session.gd")

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
	_daily_picks_are_stable_and_spread()
	_medals_share_one_scale()
	_daily_bonus_pays_each_tier_once()
	_saves_load_with_and_without_the_new_fields()
	_marathon_rules()
	await _marathon_flow()
	if is_instance_valid(main):
		main.audio.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		await get_tree().process_frame
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: daily picks, doubled medal coins, arcade marathon flow and saves")
	get_tree().quit(0 if failures.is_empty() else 1)


func _daily_picks_are_stable_and_spread() -> void:
	var everything := ParkVariety.opened_games(999)
	var today := ParkVariety.daily_picks("2026-11-27", everything)
	_check(today.size() == 3 and today == ParkVariety.daily_picks("2026-11-27", everything.duplicate()), "the same day always gives the same three booths")
	var reversed := everything.duplicate()
	reversed.reverse()
	_check(today == ParkVariety.daily_picks("2026-11-27", reversed), "the picks do not depend on the order booths are listed in")
	var zones := {}
	for id in today:
		zones[Catalog.identity(id).zone] = true
	_check(zones.size() == 3, "three open zones give three different zones")
	var changed := 0
	for day in ["2026-11-28", "2026-11-29", "2026-11-30", "2026-12-01"]:
		if ParkVariety.daily_picks(day, everything) != today:
			changed += 1
	_check(changed >= 3, "other days recommend other booths")
	var welcome_only := ParkVariety.opened_games(0)
	_check(welcome_only.size() == 12 and ParkVariety.daily_picks("2026-11-27", welcome_only).size() == 3, "a new player still gets three booths from the one open zone")
	_check(ParkVariety.opened_games(0, true).is_empty() and not ParkVariety.opened_games(30, true).is_empty(), "arcade booths open with their zones")
	_check(ParkVariety.today().length() == 10, "today is a calendar date key")


func _medals_share_one_scale() -> void:
	_check(ParkVariety.medal_of({"success": true, "score_summary": {"arcade": true, "medal": 2}}) == 2, "arcade games report their own medal")
	_check(ParkVariety.medal_of({"success": true, "devil": false}) == 1 and ParkVariety.medal_of({"success": true, "devil": true}) == 3 and ParkVariety.medal_of({"success": false}) == 0, "other booths count a clear as bronze and a devil clear as gold")


func _daily_bonus_pays_each_tier_once() -> void:
	progress.reset_progress()
	var coins: int = progress.coins
	var normal: int = progress.normal_count()
	var bronze: Dictionary = progress.record_daily_pick_medal("game-049", 1, "2026-11-27")
	_check(int(bronze.coins) == 20 and progress.coins == coins + 20, "a recommended bronze pays twice the medal coins")
	_check(int(progress.record_daily_pick_medal("game-049", 1, "2026-11-27").coins) == 0, "the same tier pays once a day")
	var gold: Dictionary = progress.record_daily_pick_medal("game-049", 3, "2026-11-27")
	_check(int(gold.coins) == 120 and progress.coins == coins + 140, "climbing to gold pays silver and gold once each, doubled")
	_check(int(progress.record_daily_pick_medal("game-050", 1, "2026-11-27").coins) == 20, "each booth keeps its own tiers")
	_check(int(progress.record_daily_pick_medal("game-049", 1, "2026-11-28").coins) == 20 and progress.daily_bonus.paid.size() == 1, "a new day starts fresh and forgets yesterday")
	_check(progress.normal_count() == normal and progress.photos.is_empty(), "the bonus never grants a sticker")


func _saves_load_with_and_without_the_new_fields() -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	progress.load_progress()
	_check(progress.daily_bonus.get("day", "") == "2026-11-28", "today's paid tiers survive a reload")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	on_disk.erase("daily_bonus")
	on_disk.erase("field_records")
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.daily_bonus.is_empty() and progress.field_records.is_empty() and progress.coins == int(on_disk.coins), "an old save without the new fields loads unchanged")
	on_disk["daily_bonus"] = {"day": 7, "paid": "x"}
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.daily_bonus.is_empty(), "a damaged daily record is dropped")


func _marathon_rules() -> void:
	var arcade := ParkVariety.opened_games(999, true)
	var games := ParkVariety.marathon_games(arcade, 11)
	_check(games.size() == 5 and games == ParkVariety.marathon_games(arcade, 11), "a marathon is five seeded arcade games")
	var repeats := false
	for index in range(1, games.size()):
		repeats = repeats or games[index] == games[index - 1]
	_check(not repeats, "no game plays twice in a row")
	_check(ParkVariety.marathon_games(["game-049"], 3).size() == 5, "one open arcade game still makes a full marathon")
	var full: RefCounted = (load("res://game/minigames/arcade/%s_driver.gd" % Catalog.find(games[0]).mode) as Script).new()
	full.reset(false, "noon")
	var short := ParkVariety.marathon_driver(games[0])
	short.reset(false, "noon")
	_check(is_equal_approx(short.round_seconds, full.round_seconds * ParkVariety.MARATHON_ROUND_SCALE) and short.thresholds[0] < full.thresholds[0], "marathon rounds and medal lines are shortened by the shared scale")
	short.reset(false, "noon")
	_check(is_equal_approx(short.round_seconds, full.round_seconds * ParkVariety.MARATHON_ROUND_SCALE), "repeated rounds do not shrink twice")
	var lines := ParkVariety.marathon_lines(games)
	var expected := 0
	for id in games:
		var driver := ParkVariety.marathon_driver(id)
		driver.reset(false, "noon")
		expected += int(driver.thresholds[0])
	_check(lines[0] == expected and lines[0] < lines[1] and lines[1] < lines[2], "marathon medal lines add up the shortened game lines")
	_check(ParkVariety.marathon_medal(lines[1], lines) == 2 and ParkVariety.marathon_medal(0, lines) == 0, "the total earns one medal")


func _marathon_flow() -> void:
	progress.reset_progress()
	progress.intro_seen = true
	for zone in ["welcome", "harbor", "candy"]:
		for index in range(1, 11):
			progress.photos["photo-%s-game-%d" % [zone, index]] = {"game_id": "seed"}
	progress.save_progress()
	var photos_before: int = progress.photos.size()
	get_window().size = Vector2i(1280, 720)
	main = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	for _frame in 3:
		await get_tree().process_frame
	_check(main.world.daily_pick_ribbons.size() == 3, "the world keeps three pick ribbons")
	main._show_ticket()
	var start := main.overlay.find_child("MarathonStartButton", true, false) as Button
	_check(start != null and main.overlay.find_child("DailyPicksLine", true, false) != null, "the ticket shows today's picks and the marathon entry")
	start.pressed.emit()
	_check(main.marathon.games.size() == 5 and main.session != null and main.session.game_id == main.marathon.games[0], "starting the marathon opens its first game")
	var coins: int = progress.coins
	for round_index in 5:
		var driver: RefCounted = main.session.active_driver
		var expected := ParkVariety.marathon_driver(main.session.game_id)
		expected.reset(false, "noon")
		_check(is_equal_approx(driver.round_seconds, expected.round_seconds) and driver.round_seconds <= 30.0, "game %d runs on the shortened clock" % (round_index + 1))
		if round_index == 0:
			_run_session(3.0)
			driver.add_score(100000)
		_run_session(40.0)
		if round_index < 4:
			_check(main.modal_kind == "marathon" and main.marathon.index == round_index + 1, "a slim card follows game %d" % (round_index + 1))
			_check((main.overlay.find_child("MarathonRunningTotal", true, false) as Label).text == "目前總分 %d" % int(main.marathon.total), "the card shows the running total")
			(main.overlay.find_child("MarathonNextGame", true, false) as Button).pressed.emit()
	_check(main.modal_kind == "marathon_result" and main.marathon.is_empty(), "the fifth game ends on one result card")
	var record: Dictionary = progress.field_records.get(ParkVariety.MARATHON_RECORD, {})
	_check(int(record.get("best", 0)) >= 50000 and int(record.get("medal", 0)) == 3, "the best total and medal are kept: %s" % record)
	_check(progress.coins == coins + 70 * ParkVariety.MARATHON_COIN_SCALE, "the first gold pays every medal tier once")
	_check(progress.photos.size() == photos_before, "the marathon never grants stickers")
	main._close()
	main._start_marathon()
	_run_session(3.0)
	main.session.active_driver.add_score(100000)
	_run_session(40.0)
	(main.overlay.find_child("MenuBackButton", true, false) as Button).pressed.emit()
	_check(main.marathon.is_empty() and main.session == null and main.modal_kind == "", "giving up on the card returns to the park")
	main._start_marathon()
	main.session._leave_from_hud()
	_check(main.marathon.is_empty() and main.session == null, "giving up mid-game returns to the park")
	main._start_marathon()
	for _round in 5:
		_run_session(3.0)
		main.session.active_driver.add_score(100000)
		_run_session(40.0)
		var next := main.overlay.find_child("MarathonNextGame", true, false) as Button
		if next != null:
			next.pressed.emit()
	_check(progress.coins == coins + 70 * ParkVariety.MARATHON_COIN_SCALE, "medals already earned pay nothing again")
	progress.load_progress()
	_check(int(progress.field_records.get(ParkVariety.MARATHON_RECORD, {}).get("medal", 0)) == 3, "the marathon record survives a reload")
	main._close()


func _run_session(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and main.session != null and not main.session.ended:
		main.session._process(0.25)
		left -= 0.25


func _write(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
