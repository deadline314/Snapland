extends SceneTree
## 接飛碟 rules: the catch ring, the tower, fumbles, missed plates, pies, escalation, variants and full simulated rounds.

const Game = preload("res://game/minigames/arcade/plate_catch_driver.gd")
const Base = preload("res://game/minigames/arcade/arcade_driver.gd")
const Session = preload("res://game/minigames/session.gd")
const STEP := 1.0 / 60.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	_countdown_demonstrates_the_idea()
	_catching_builds_the_tower()
	_grabbing_at_nothing_drops_a_plate()
	_a_missed_plate_topples_the_tower()
	_pies_must_be_let_through()
	_plates_come_faster_and_in_pairs()
	_variants_change_the_throwing()
	_plays_full_rounds_through_the_session()
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: plate catch ring, tower, fumbles, topples, pies, escalation, variants, bronze and gold rounds")
	quit(0 if failures.is_empty() else 1)


func _countdown_demonstrates_the_idea() -> void:
	var game := _round("standard", false)
	_check(game.stage == "ready" and game.flying.size() == 1 and game.tower == 0 and game.thresholds == [250, 600, 950],
		"a round opens with one demonstration plate in the air and its medal lines declared")
	for tick in int(Base.READY_SECONDS / STEP) - 2:
		_tap(game, KEY_SPACE)
		game.step(STEP)
	_check(game.tower == 1 and game.flying.is_empty() and game.score == 0, "the clown catches the demonstration plate by himself; presses do nothing yet")
	_advance(game, 0.1)
	_check(game.stage == "play" and game.tower == 0 and game.flying.is_empty() and game.mood == "play", "play starts with an empty head and nothing in the air")


func _catching_builds_the_tower() -> void:
	var game := _playing("standard")
	var plate := _next_plate(game)
	_check(not plate.is_empty() and plate.kind == "plate" and absf(plate.flight - Game.FLIGHT_EARLY) < 0.02, "the first throw is a slow plate")
	_advance_to(game, float(plate.arrival) - 0.2)
	_tap(game, KEY_SPACE)
	_check(game.tower == 0 and game.score == 0 and game.flying.size() >= 1, "pressing too early grabs at nothing")
	game.fumble_at = -99.0
	_advance_to(game, float(plate.arrival))
	_tap(game, KEY_SPACE)
	_check(game.tower == 1 and game.caught == 1 and game.perfects == 1 and game.score == Game.CATCH_POINTS + Game.PERFECT_BONUS,
		"a plate caught right in the ring is perfect: %d points" % (Game.CATCH_POINTS + Game.PERFECT_BONUS))
	plate = _next_plate(game)
	_advance_to(game, float(plate.arrival) + 0.08)
	_tap(game, KEY_SPACE)
	_check(game.tower == 2 and game.perfects == 1 and game.score == 15 + Game.CATCH_POINTS + Game.STACK_BONUS,
		"a late catch still counts and the tower pays two points a plate")
	var tall := _playing("standard")
	tall.tower = 30
	var high := _next_plate(tall)
	_advance_to(tall, float(high.arrival))
	_tap(tall, KEY_SPACE)
	_check(tall.score == Game.CATCH_POINTS + Game.STACK_BONUS * Game.STACK_BONUS_CAP + Game.PERFECT_BONUS and tall.best_tower == 31,
		"the tower bonus stops growing at ten plates")


func _grabbing_at_nothing_drops_a_plate() -> void:
	var game := _playing("standard")
	game.tower = 3
	_tap(game, KEY_SPACE)
	_check(game.tower == 2 and game.mistakes == 0 and not game.snapshot().word_good, "grabbing at nothing drops the top plate")
	_tap(game, KEY_SPACE)
	_check(game.tower == 2, "the hands are busy for a moment after a fumble, so mashing loses one plate at a time")
	_advance(game, Game.FUMBLE_SECONDS + 0.02)
	_tap(game, KEY_SPACE)
	_check(game.tower == 1, "then they are free again")


func _a_missed_plate_topples_the_tower() -> void:
	var game := _playing("standard")
	game.tower = 6
	var plate := _next_plate(game)
	_advance_to(game, float(plate.arrival) + Game.CATCH_WINDOW + 0.03)
	_check(game.mood == "topple" and game.tower == 0 and game.fallen == 6 and game.fall_reason == "miss" and game.fall_side == plate.side
		and game.mistakes == 0 and game.topples == 1 and game.flying.is_empty(), "a plate nobody catches brings the whole tower down; the first time is free")
	_tap(game, KEY_SPACE)
	_check(game.tower == 0 and game.fumble_at < 0.0, "the dazed clown ignores the button")
	_advance(game, Game.TOPPLE_SECONDS - 0.1)
	_check(game.mood == "topple" and game.flying.is_empty(), "nothing is thrown while he sees stars")
	_advance(game, 0.2)
	_check(game.mood == "play", "then the act resumes")
	plate = _next_plate(game)
	_advance_to(game, float(plate.arrival) + Game.CATCH_WINDOW + 0.03)
	_check(game.topples == 2 and game.mistakes == 1, "later topples are mistakes")
	var helped := _round("standard", true)
	_advance(helped, Base.READY_SECONDS + 0.05)
	plate = _next_plate(helped)
	_check(absf(plate.flight - Game.FLIGHT_EARLY * Base.ASSIST_WINDOW) < 0.03, "assist throws slower plates")
	_advance_to(helped, float(plate.arrival) + Game.CATCH_WINDOW * 1.4)
	_tap(helped, KEY_SPACE)
	_check(helped.tower == 1, "and widens the catch window")


func _pies_must_be_let_through() -> void:
	var game := _playing("pies")
	_advance_empty(game, game.round_seconds * 0.3)
	game.tower = 4
	var pie := _next_kind(game, "pie")
	_check(not pie.is_empty(), "custard pies join once the round warms up")
	game.flying = [pie]
	var before := game.score
	_advance_to(game, float(pie.arrival) + Game.CATCH_WINDOW + 0.02)
	_check(game.pies_dodged == 1 and game.score == before + Game.PIE_DODGE_POINTS and game.mood == "play" and game.tower == 4,
		"letting a pie fly past is worth a few points")
	var eaten := _playing("pies")
	_advance_empty(eaten, eaten.round_seconds * 0.3)
	eaten.tower = 5
	pie = _next_kind(eaten, "pie")
	eaten.flying = [pie]
	_advance_to(eaten, float(pie.arrival))
	_tap(eaten, KEY_SPACE)
	_check(eaten.mood == "topple" and eaten.fall_reason == "pie" and eaten.fallen == 5 and eaten.mistakes == 1 and eaten.pies_eaten == 1,
		"grabbing a pie means a face full of cream and the tower comes down, mistake or not")
	var early := _playing("pies")
	var kinds := {}
	while early.heat() < Game.PIE_FROM_HEAT - 0.02:
		for thing: Dictionary in early.flying:
			kinds[thing.kind] = true
		early.flying.clear()
		_advance(early, STEP)
	_check(not kinds.has("pie"), "no pies before the round warms up")


func _plates_come_faster_and_in_pairs() -> void:
	var game := _playing("standard")
	var flights: Array[float] = []
	var pairs_early := 0
	var pairs_late := 0
	var launches := 0
	while game.stage == "play":
		game.flying.clear()
		game._next_launch = minf(game._next_launch, game.play_time)
		game.step(STEP)
		if game.flying.size() > 0:
			launches += 1
			flights.append(float(game.flying[0].flight))
			if game.flying.size() == 2:
				_check(game.flying[0].side != game.flying[1].side and float(game.flying[1].arrival) - float(game.flying[0].arrival) >= Game.PAIR_GAP - 0.001,
					"a pair comes from both wings and lands a beat apart")
				if game.heat() < Game.PAIR_FROM_HEAT:
					pairs_early += 1
				else:
					pairs_late += 1
	_check(flights[0] > 1.6 and flights[flights.size() - 1] < 1.0 and launches > 100, "plates fly in faster as the round goes on (%.2f s to %.2f s)" % [flights[0], flights[flights.size() - 1]])
	_check(pairs_early == 0 and pairs_late > 10, "pairs only come in the second part of the round")
	var paced := _playing("standard")
	var arrivals: Array[float] = []
	while paced.stage == "play":
		for thing: Dictionary in paced.flying:
			if not arrivals.has(float(thing.arrival)):
				arrivals.append(float(thing.arrival))
		paced.tower = 1
		for thing in paced.flying.duplicate():
			if paced.clock >= float(thing.arrival):
				paced.flying.erase(thing)
		paced.step(STEP)
	arrivals.sort()
	var closest := 9.0
	for index in range(1, arrivals.size()):
		closest = minf(closest, arrivals[index] - arrivals[index - 1])
	_check(arrivals.size() > 40 and closest > Game.CATCH_WINDOW * 2.5, "no two things ever reach the ring inside one catch window (closest %.2f s)" % closest)


func _variants_change_the_throwing() -> void:
	var ids: Array = []
	for row: Dictionary in Game.new().variants:
		ids.append(row.id)
	_check(ids == ["standard", "pies", "pairs", "high"], "four variants are declared")
	var counts := {}
	for variant_id: String in ids:
		var game := _playing(variant_id)
		var pies := 0
		var pairs := 0
		var apex := 0.0
		while game.stage == "play":
			if game.flying.size() == 2:
				pairs += 1
			for thing: Dictionary in game.flying:
				pies += int(thing.kind == "pie")
				apex = maxf(apex, float(thing.apex))
			game.flying.clear()
			game._next_launch = minf(game._next_launch, game.play_time)
			game.step(STEP)
		counts[variant_id] = [pies, pairs, apex]
	_check(counts.pies[0] > counts.standard[0] * 1.4, "the pie party throws many more pies (%d against %d)" % [counts.pies[0], counts.standard[0]])
	_check(counts.pairs[1] > counts.standard[1] * 1.4, "the pairs variant throws many more pairs (%d against %d)" % [counts.pairs[1], counts.standard[1]])
	_check(counts.high[2] > 200.0 and counts.standard[2] <= 170.0, "high throws loop far higher")


func _plays_full_rounds_through_the_session() -> void:
	var session := Session.new()
	root.add_child(session)
	session.set_process(false)
	var lines: Array = []
	var gold_scores: Array[int] = []
	for variant_id: String in ["standard", "pies", "pairs", "high"]:
		# Gold: catch every plate as it meets the ring, never touch a pie.
		var gold := _play(session, variant_id, false, 0.0, 0, false)
		lines = gold.score_summary.thresholds
		gold_scores.append(gold.score)
		_check(gold.success and gold.devil and gold.ordinary_eligible and gold.score >= lines[2] and gold.score_summary.medal == 3
			and gold.score_summary.rows.size() == 1 and gold.mistakes == 0, "clean catching earns gold in the %s variant (score %d)" % [variant_id, gold.score])
	# Bronze: a little late every time and lets every fifth plate drop.
	var bronze := _play(session, "standard", false, 0.07, 5, false)
	_check(bronze.success and not bronze.devil and bronze.ordinary_eligible and bronze.score >= lines[0] and bronze.score < lines[1]
		and bronze.score_summary.medal == 1 and bronze.mistakes > 0, "late, clumsy catching still earns bronze (score %d)" % bronze.score)
	var masher := _mash(session)
	_check(not masher.success and masher.score < lines[0], "mashing the button earns nothing (score %d)" % masher.score)
	var helped := _play(session, "standard", true, 0.0, 0, false)
	_check(helped.success and helped.assisted and not helped.devil and helped.score_summary.medal == 3, "an assisted gold round never awards the devil sticker (score %d)" % helped.score)
	print("plate catch scores: gold %s, bronze %d, masher %d, assisted %d" % [gold_scores, bronze.score, masher.score, helped.score])
	session.free()


## Play a whole round through Session input: press `late` seconds after each
## plate reaches the ring, skip every `drop_every`-th plate, and grab pies when told to.
func _play(session: Session, variant_id: String, assisted: bool, late: float, drop_every: int, grab_pies: bool) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-052", assisted)
	var game: Game = session.active_driver
	game.round_seed = _seed_for(variant_id)
	session.reset_round()
	_run_session(session, Base.READY_SECONDS + 0.05)
	var seen := 0
	var handled := {}
	while not session.ended and game.stage == "play":
		for thing: Dictionary in game.flying.duplicate():
			var key := float(thing.arrival)
			if handled.has(key) or game.clock < key + late - STEP * 0.5:
				continue
			handled[key] = true
			if thing.kind == "pie" and not grab_pies:
				continue
			seen += 1
			if thing.kind == "plate" and drop_every > 0 and seen % drop_every == 0:
				continue
			_session_key(session, KEY_SPACE, true)
			_session_key(session, KEY_SPACE, false)
		_run_session(session, STEP)
	for tick in 600:
		if session.ended:
			break
		session._process(STEP)
	session.finished.disconnect(capture)
	_check(session.ended and results.size() == 1 and game.clock < 60.0, "a round finishes by itself inside a minute")
	if results.is_empty():
		return {"score_summary": {"thresholds": [0, 0, 0], "rows": [{"amount": -1}], "medal": -1}, "score": -1, "success": false,
			"devil": false, "ordinary_eligible": false, "assisted": false, "mistakes": 0}
	return results[0]


func _mash(session: Session) -> Dictionary:
	var results: Array[Dictionary] = []
	var capture := func(result: Dictionary) -> void: results.append(result)
	session.finished.connect(capture)
	session.start("game-052", false)
	var game: Game = session.active_driver
	game.round_seed = _seed_for("standard")
	session.reset_round()
	while not session.ended:
		_session_key(session, KEY_SPACE, true)
		_run_session(session, 0.06)
		_session_key(session, KEY_SPACE, false)
		_run_session(session, 0.06)
	session.finished.disconnect(capture)
	return results[0] if not results.is_empty() else {"success": true, "score": 99999}


func _next_plate(game: Game) -> Dictionary:
	return _next_kind(game, "plate")


## Step until something of `kind` is in the air and return the earliest such flight.
func _next_kind(game: Game, kind: String) -> Dictionary:
	for tick in 3000:
		for thing: Dictionary in game.flying:
			if thing.kind == kind:
				return thing
		for thing in game.flying.duplicate():
			if thing.kind != kind:
				game.flying.erase(thing)
		game.step(STEP)
	return {}


## Let time pass with nothing ever reaching the clown.
func _advance_empty(game: Game, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game.flying.clear()
		game.step(minf(left, STEP))
		left -= STEP


func _advance_to(game: Base, moment: float) -> void:
	while game.clock < moment - STEP * 0.5:
		game.step(minf(STEP, moment - game.clock))


func _run_session(session: Session, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not session.ended:
		session._process(minf(left, STEP))
		left -= STEP


func _session_key(session: Session, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	session._unhandled_input(key)


func _round(variant_id: String, assisted: bool) -> Game:
	var game := Game.new()
	game.round_seed = _seed_for(variant_id)
	game.reset(assisted, "noon")
	return game


func _playing(variant_id: String) -> Game:
	var game := _round(variant_id, false)
	_advance(game, Base.READY_SECONDS + 0.05)
	return game


## First seed whose round uses the named variant.
func _seed_for(variant_id: String) -> int:
	for round_seed in 200:
		var game := Game.new()
		game.round_seed = round_seed
		game.reset(false, "noon")
		if game.variant.id == variant_id:
			return round_seed
	failures.append("no seed produced variant " + variant_id)
	return 0


func _advance(game: Base, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game.step(minf(left, STEP))
		left -= STEP


func _press(game: Base, code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	game.handle_input(key, Vector2.ZERO)


func _tap(game: Base, code: int) -> void:
	_press(game, code, true)
	_press(game, code, false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
